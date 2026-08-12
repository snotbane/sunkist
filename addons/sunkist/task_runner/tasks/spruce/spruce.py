# pyright: reportOptionalSubscript=false
import argparse
import configparser
import os
import re
import sys
import time
from PIL import Image

SQRT_3 : float = 1.732050808
SUPPORTED_EXTS = [".png", ".jpg", ".jpeg"]
attempts: int = 0
progress: int = 0
temp_dir: str

Color3 = tuple[int, int, int]

def str_to_color3(s: str) -> Color3:
	return (
		int(s[0 : 2], 16),
		int(s[2 : 4], 16),
		int(s[4 : 6], 16),
		# int(s[6 : 8], 16),
	)

Color3Palette = set[Color3]

def str_to_color3_palette(s: str) -> Color3Palette:
	result: Color3Palette = set()

	for i in range(len(s) // 8):
		ib = i * 8
		result.add(str_to_color3(s[ib : ib + 8]))

	return result


def color3_distance(a: Color3, b: Color3) -> float:
	rd = (a[0] - b[0]) / 255.0
	gd = (a[1] - b[1]) / 255.0
	bd = (a[2] - b[2]) / 255.0
	dist = (rd * rd + gd * gd + bd * bd) ** 0.5

	return dist / SQRT_3

def color3_proximity(a: Color3, b: Color3) -> float:
	return 1.0 - color3_distance(a, b)

Color4 = tuple[int, int, int, int]

def str_to_color4(s: str) -> Color4:
	return (
		int(s[0 : 2], 16),
		int(s[2 : 4], 16),
		int(s[4 : 6], 16),
		int(s[6 : 8], 16),
	)



def str_to_bool(value: str) -> bool:
    if isinstance(value, bool):
        return value
    val = value.lower()
    if val in ('yes', 'true', 't', '1'):
        return True
    elif val in ('no', 'false', 'f', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')


def bus_get(section: str, key: str):
	bus.read(bus_path)
	if not (bus.has_section(section) and bus.has_option(section, key)): return None

	result = bus.get(section, key)
	try:
		return str_to_bool(result)
	except:
		return result


def bus_set(section: str, key: str, value):
	bus.read(bus_path)
	value = str(value)
	if not bus.has_section(section): bus.add_section(section)
	bus.set(section, key, value)
	with open(bus_path, 'w') as file:
		bus.write(file, space_around_delimiters=False)


class Itinerary:
	def __init__(self, from_str: str) -> None:
		splits = from_str.split("\t")

		self.source = splits[0]
		self.target = splits[1]
		self.include = re.compile(splits[2]) if splits[2] != "" else None
		self.exclude = re.compile(splits[3]) if splits[3] != "" else None
		self.rename_filter = re.compile(splits[4]) if splits[4] != "" else None
		self.rename_replace = splits[5]
		self.overwrite = str_to_bool(splits[6])

		if self.target == "":
			self.target = self.source


	def get_targets(self):
		if os.path.isfile(self.source):
			return [TargetImage(
				self.source,
				self.target,
				""
			)]

		elif os.path.isdir(self.source):
			result = []

			for dirpath, _, files in os.walk(self.source):
				for file in files:
					subdirpath = dirpath[(len(self.source) + 1):]
					name, ext = os.path.splitext(file)
					if not ext.lower() in SUPPORTED_EXTS: continue

					if self.include != None and re.search(self.include, name) == None: continue
					if self.exclude != None and re.search(self.exclude, name) != None: continue

					image = TargetImage(
						os.path.join(dirpath, file),
						os.path.join(self.target, subdirpath) if subdirpath != "" else self.target,
						subdirpath
					)
					# if not self.overwrite and os.path.exists(image.path): continue

					result.append(image)

			return result

		else:
			sys.stderr.write("Input path is not a valid file nor directory.")
			sys.exit(7) ## ERR_FILE_NOT_FOUND
			return []


def str_to_itinerary(value: str) -> Itinerary:
	return Itinerary(value)


class TargetImage:
	def __init__(self, source, target_dir, subdirpath):
		self.source = source
		self.source_name, self.ext = os.path.splitext(os.path.basename(self.source))

		self.target_name = (
			re.sub(args.itinerary.rename_filter, args.itinerary.rename_replace, self.source_name)
			if args.itinerary.rename_filter != None
			else (self.source_name + args.itinerary.rename_replace)
		)

		self.path = os.path.join(target_dir, self.target_name + self.ext)


		self.temp_diff = os.path.join(temp_dir, subdirpath, f"{self.source_name}__diff{self.ext}")
		self.temp_target = os.path.join(temp_dir, subdirpath, f"{self.source_name}__new{self.ext}")

		self.source_image : Image.Image = Image.open(self.source).convert("RGBA")
		self.target_image : Image.Image


	def __str__(self):
		return self.path


	def process(self):
		global progress
		global attempts

		try:
			attempts += 1
			bus_set("output", "attempts", attempts)

			bus_set("output", "source_preview", f"\"{self.source}\"")
			os.makedirs(os.path.dirname(self.path), exist_ok = True)
			os.makedirs(os.path.dirname(self.temp_target), exist_ok = True)

			self._process()

			# bus_set("output", "target_preview", f"\"{self.path}\"")
			progress += 1
			bus_set("output", "progress", progress)

		except Exception as e:
			sys.stderr.write(f"\nError processing {self.path}: {e}")
			bus_set("output", "target_preview", f"\"\"")

		finally:
			self._cleanup()

	def _process(self):
		# if os.path.exists(self.temp_target):
		# 	print(f"Spruce :: Image already has pending changes: '{self.source}'")
		# 	return

		ri, gi, bi, ai = self.source_image.split()
		r = ri.load()
		g = gi.load()
		b = bi.load()
		a = ai.load()
		w, h = self.source_image.size

		diffmap : Image.Image = Image.new("RGBA", self.source_image.size)
		diffmap_p = diffmap.load()

		def add_to_diff(diff, hint: Color4, m: int = 1):
			for x in range(w):
				for y in range(h):
					diffmap_p[x, y] = (
						diffmap_p[x, y][0] + round(float(hint[0]) * diff[x, y] / m),
						diffmap_p[x, y][1] + round(float(hint[1]) * diff[x, y] / m),
						diffmap_p[x, y][2] + round(float(hint[2]) * diff[x, y] / m),
						diffmap_p[x, y][3] + round(float(hint[3]) * diff[x, y] / m),
					)


		def flood(candidate, visited, x, y, area_max):
			stack = [(x, y)]
			area = 0

			while stack:
				px, py = stack.pop()
				if px < 0 or py < 0 or px >= w or py >= h: continue
				if visited[px, py] or not candidate[px, py]: continue

				visited[px, py] = 1
				area += 1

				stack.extend([(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)])

			if area > area_max:
				for x in range(w):
					for y in range(h):
						if not visited[x, y]: continue
						candidate[x, y] = 0


		def _process_spot():
			if args.spot_size >= w * h: return

			candidate_image = Image.new("1", self.source_image.size)
			candidate = candidate_image.load()
			visited_image = Image.new("1", self.source_image.size)
			visited = visited_image.load()

			for x in range(w):
				for y in range(h):
					candidate[x, y] = int(a[x, y] > args.spot_opacity)
					visited[x, y] = 1 - candidate[x, y]

			for x in range(w):
				for y in range(h):
					if visited[x, y]: continue

					flood(candidate, visited, x, y, args.spot_size)

			add_to_diff(candidate, args.spot_hint)

			for x in range(w):
				for y in range(h):
					if not candidate[x, y]: continue

					a[x, y] = 0


		def _process_hole():
			if args.hole_size >= w * h: return

			candidate_image = Image.new("1", self.source_image.size)
			candidate = candidate_image.load()
			visited_image = Image.new("1", self.source_image.size)
			visited = visited_image.load()

			for x in range(w):
				for y in range(h):
					candidate[x, y] = int(a[x, y] < args.hole_opacity)
					visited[x, y] = 1 - candidate[x, y]

			for x in range(w):
				for y in range(h):
					if visited[x, y]: continue

					flood(candidate, visited, x, y, args.hole_size)

			add_to_diff(candidate, args.hole_hint)

			empties = set()
			for x in range(w):
				for y in range(h):
					if not candidate[x, y]: continue

					if a[x, y] == 0:
						empties.add((x, y))

					a[x, y] = 255

			def get_opaque_neighbors(x: int, y: int) -> list[tuple[int, int]]:
				result = []
				for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
					nx, ny = x + dx, y + dy
					if (nx, ny) in empties: continue

					result.append((nx, ny))
				return result

			def get_color_from_neighbors(neighbors) -> Color3:
				samples = []

				for nx, ny in neighbors:
					samples.append((
						r[nx, ny],
						g[nx, ny],
						b[nx, ny],
					))

				if not samples:
					return (0, 0, 0)

				avg_r = round(sum(c[0] for c in samples) / len(samples))
				avg_g = round(sum(c[1] for c in samples) / len(samples))
				avg_b = round(sum(c[2] for c in samples) / len(samples))

				return (avg_r, avg_g, avg_b)

			most_neighbors = 4
			for i in range(most_neighbors):
				modified = set()
				for _, (x, y) in enumerate(empties):
					neighbors = get_opaque_neighbors(x, y)
					if len(neighbors) < most_neighbors - i: continue

					modified.add((x, y))
					color = get_color_from_neighbors(neighbors)
					r[x, y] = color[0]
					g[x, y] = color[1]
					b[x, y] = color[2]

				empties.difference_update(modified)


		def _process_feather():
			return

			distance_threshold = 0.5
			island_size = 64

			candidate_image = Image.new("1", self.source_image.size)
			candidate = candidate_image.load()
			visited_image = Image.new("1", self.source_image.size)
			visited = visited_image.load()

			distance_image = Image.new("L", self.source_image.size)
			distance = distance_image.load()

			palette_color = list(args.feather_palette)[0]

			for x in range(w):
				for y in range(h):
					c: Color3 = (r[x, y], g[x, y], b[x, y])
					dist: float = color3_distance(c, palette_color)
					is_candidate = (
						a[x, y] > 0
						# and a[x, y] < 255
						and c != palette_color
						# and c not in args.feather_palette
						and dist > distance_threshold
					)

					candidate[x, y] = int(is_candidate)
					visited[x, y] = 1 - candidate[x, y]

					if is_candidate:
						distance[x, y] = round(dist * 255)

			for x in range(w):
				for y in range(h):
					if visited[x, y]: continue

					flood(candidate, visited, x, y, island_size)

			add_to_diff(candidate, args.feather_hint, 1)
			# add_to_diff(distance, args.feather_hint, 255)
			add_to_diff(a, args.feather_hint, 1024)

			for x in range(w):
				for y in range(h):
					if not candidate[x, y]: continue

					r[x, y] = palette_color[0]
					g[x, y] = palette_color[1]
					b[x, y] = palette_color[2]


		if args.spot_enabled:
			_process_spot()

		if args.hole_enabled:
			_process_hole()

		if args.feather_enabled:
			_process_feather()

		def get_needs_review() -> bool:
			if args.itinerary.overwrite:
				return False

			for x in range(w):
				for y in range(h):
					if diffmap_p[x, y][3] == 0: continue

					return True

			return False

		self.target_image = Image.merge("RGBA", (ri, gi, bi, ai))

		if get_needs_review():
			diffmap.save(self.temp_diff)

			self.target_image.save(self.temp_target)

			bus_set("output", "target_bitmap", f"\"{self.temp_diff}\"")
			bus_set("output", "target_preview", f"\"{self.temp_target}\"")

		else:
			bus_set("output", "target_bitmap", f"\"\"")
			bus_set("output", "target_preview", f"\"\"")

			self.target_image.save(self.path)

			if os.path.exists(self.temp_target):
				os.remove(self.temp_target)

			if os.path.exists(self.temp_diff):
				os.remove(self.temp_diff)



	def _cleanup(self):
		pass


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("bus_path", type=str)
	parser.add_argument("itinerary", type=str_to_itinerary)

	parser.add_argument("spot_enabled", type=str_to_bool)
	parser.add_argument("spot_opacity", type=int)
	parser.add_argument("spot_size", type=int)
	parser.add_argument("spot_hint", type=str_to_color4)

	parser.add_argument("hole_enabled", type=str_to_bool)
	parser.add_argument("hole_opacity", type=int)
	parser.add_argument("hole_size", type=int)
	parser.add_argument("hole_hint", type=str_to_color4)

	parser.add_argument("feather_enabled", type=str_to_bool)
	parser.add_argument("feather_palette", type=str_to_color3_palette)
	parser.add_argument("feather_hint", type=str_to_color4)

	args = parser.parse_args()

	if args.feather_enabled:
		print("Warning: feather_enabled is true. This feature is not yet implemented.")

	bus_path = args.bus_path
	bus = configparser.ConfigParser()
	bus.read(bus_path)
	temp_dir = os.path.dirname(bus_path)

	bus_set("output", "progress", 0)

	targets = args.itinerary.get_targets()
	bus_set("output", "progress_max", len(targets))

	for target in targets:
		if bus_get("input", "stop"): sys.exit(45) ## ERR_SKIP
		target.process()

	if progress < len(targets):
		sys.stderr.write("\nNot all images were successfully processed.")
		sys.exit(39) ## ERR_SCRIPT_FAILED

	sys.exit(0)
