# pyright: reportOptionalSubscript=false
import argparse
import configparser
import os
import re
import sys
from PIL import Image, ImageColor

Color4 = tuple[int, int, int, int]
Color3 = tuple[int, int, int]
Color3f = tuple[float, float, float]

SQRT_3 : float = 1.732050808

SUPPORTED_EXTS = [".png", ".jpg", ".jpeg"]
attempts: int = 0
progress: int = 0


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
				self.target
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
						os.path.join(self.target, subdirpath) if subdirpath != "" else self.target
					)
					if not self.overwrite and os.path.exists(image.path): continue

					result.append(image)

			return result

		else:
			sys.stderr.write("Input path is not a valid file nor directory.")
			sys.exit(7) ## ERR_FILE_NOT_FOUND
			return []


def str_to_itinerary(value: str) -> Itinerary:
	return Itinerary(value)


class PaletteRemap:
	def __init__(self, from_str: str) -> None:
		self.sources : set[Color3] = set()
		self.targets : set[Color3] = set()
		self.globals : set[Color3] = set()
		self.palette : dict[Color3, Color3] = {}

		for i in range(len(from_str) // 16):
			ib = i * 16

			a : Color3 = (
				int(from_str[ib +  0 : ib +  2], 16),
				int(from_str[ib +  2 : ib +  4], 16),
				int(from_str[ib +  4 : ib +  6], 16),
				# int(from_str[ib +  6 : ib +  8], 16),
			)

			b : Color3 = (
				int(from_str[ib +  8 : ib + 10], 16),
				int(from_str[ib + 10 : ib + 12], 16),
				int(from_str[ib + 12 : ib + 14], 16),
				# int(from_str[ib + 14 : ib + 16], 16),
			)

			self.sources.add(a)
			self.targets.add(b)

			self.palette[a] = b


	def assign_globals(self):
		i: int = 0
		for k in self.palette:
			if i >= args.global_colors: break
			i += 1

			self.globals.add(k)

		# print(f"globals : {self.globals}")


	def __str__(self) -> str:
		return self.palette.__str__()


def str_to_palette_remap(value: str) -> PaletteRemap:
	return PaletteRemap(value)


class TargetImage:
	def __init__(self, source, target_dir):
		self.source = source
		self.source_name, self.ext = os.path.splitext(os.path.basename(self.source))

		self.target_name = (
			re.sub(args.itinerary.rename_filter, args.itinerary.rename_replace, self.source_name)
			if args.itinerary.rename_filter != None
			else (self.source_name + args.itinerary.rename_replace)
		)

		self.path = os.path.join(target_dir, self.target_name + self.ext)

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

			self._process()

			bus_set("output", "target_preview", f"\"{self.path}\"")
			progress += 1
			bus_set("output", "progress", progress)

		except Exception as e:
			sys.stderr.write(f"\nError processing {self.path}: {e}")
			bus_set("output", "target_preview", f"\"\"")

		finally:
			self._cleanup()

	def _process(self):
		remap : PaletteRemap = args.remap

		_, _, _, a = self.source_image.split()
		a_p = a.load()

		self.target_image = self.source_image.copy().convert("RGB")
		target_p = self.target_image.load()
		w, h = self.target_image.size


		def proximity(a: Color3, b: Color3) -> float:
			rd = (a[0] - b[0]) / 255.0
			gd = (a[1] - b[1]) / 255.0
			bd = (a[2] - b[2]) / 255.0
			dist = (rd * rd + gd * gd + bd * bd) ** 0.5

			return 1.0 - (dist / SQRT_3)

		def palettize(c: Color3, palette: set[Color3]) -> Color3:
			result : Color3 = (255, 255, 255)
			score: float = 0.0
			for k in palette:
				prox = proximity(c, k)
				if prox < score: continue

				score = prox
				result = k

			return result

		def blend(source: Color3, colors: set[Color3]) -> Color3:
			def decompose(query: Color3, palette: set[Color3], iterations: int = args.blend_iterations) -> dict[Color3, float]:
				colors = list(palette)
				n = len(colors)
				if n == 0:
					return {}
				if n == 1:
					return {colors[0]: 1.0}

				# Work in normalised [0, 1] space
				q = (query[0] / 255, query[1] / 255, query[2] / 255)
				ps = [(c[0] / 255, c[1] / 255, c[2] / 255) for c in colors]

				w = [1.0 / n] * n
				lr = 0.1

				for _ in range(iterations):
					# --- forward pass ---
					br = sum(w[i] * ps[i][0] for i in range(n))
					bg = sum(w[i] * ps[i][1] for i in range(n))
					bb = sum(w[i] * ps[i][2] for i in range(n))

					# residual = blend − query
					rr, rg, rb = br - q[0], bg - q[1], bb - q[2]
					if rr * rr + rg * rg + rb * rb < 1e-14:
						break

					# --- gradient step ---
					# ∂L/∂wᵢ = 2 · residual · pᵢ
					for i in range(n):
						g = 2 * (rr * ps[i][0] + rg * ps[i][1] + rb * ps[i][2])
						w[i] -= lr * g

					# --- project onto the probability simplex (clip + renormalise) ---
					total = 0.0
					for i in range(n):
						if w[i] < 0.0:
							w[i] = 0.0
						total += w[i]
					if total > 0.0:
						inv = 1.0 / total
						for i in range(n):
							w[i] *= inv
					else:
						w = [1.0 / n] * n

				return {colors[i]: w[i] for i in range(n) if w[i] > 1e-6}

			weights = decompose(source, colors)

			result : Color3f = (0.0, 0.0, 0.0)
			for c, w in weights.items():
				cmap = remap.palette[c]
				result = (
					result[0] + float(cmap[0]) * w,
					result[1] + float(cmap[1]) * w,
					result[2] + float(cmap[2]) * w,
				)

			return (
				round(result[0]),
				round(result[1]),
				round(result[2]),
			)

		def get_palette_neighbors(center: tuple[int, int], pixels) -> set[Color3]:
			neighbor_counts : dict[Color3, int] = {}

			radius = args.neighbor_radius * 2 + 1
			for ix in range(radius):
				for iy in range(radius):
					## Do not include center
					if ix == iy: continue
					## Reposition actual pixels to look at
					px, py = (
						center[0] + ix - radius // 2,
						center[1] + iy - radius // 2
					)
					## Limit to inside image
					if px < 0 or px >= w or py < 0 or py >= h: continue
					## Limit to non-blank pixels
					if a_p[px, py] == 0: continue

					neighbor = pixels[px, py]

					if neighbor not in remap.palette: continue

					neighbor_counts[neighbor] = neighbor_counts.get(neighbor, 0) + 1

			return set(neighbor_counts.keys())

		## Create palettized image
		palette_image = self.target_image.copy()
		palette_p = palette_image.load()

		for x in range(w):
			for y in range(h):
				if a_p[x, y] == 0: continue

				neighbors = get_palette_neighbors((x, y), target_p)

				if len(neighbors) == 0:
					palette_p[x, y] = palettize(target_p[x, y], set(remap.palette.keys()))

		for x in range(w):
			for y in range(h):
				if a_p[x, y] == 0: continue

				if not args.calculate_all and palette_p[x, y] in remap.palette:
					target_p[x, y] = remap.palette[palette_p[x, y]]
					continue

				neighbors = get_palette_neighbors((x, y), palette_p)
				# assert(len(neighbors) != 0)

				for k in remap.globals:
					neighbors.add(k)

				target_p[x, y] = blend(target_p[x, y], neighbors)

		## Occlusion channel
		occlusion_path : str = os.path.join(os.path.dirname(self.source), self.source_name[:-len(args.occlusion_suffix)] + args.occlusion_suffix + self.ext)
		if args.occlusion_suffix != "" and os.path.exists(occlusion_path):
			occlusion_image : Image.Image = Image.open(occlusion_path).convert("L")
			occ_p = occlusion_image.load()

			for x in range(w):
				for y in range(h):
					if a_p[x, y] == 0: continue

					target_p[x, y] = (
						target_p[x, y][0],
						target_p[x, y][1] + (255 - occ_p[x, y]),
						target_p[x, y][2],
					)

		self.target_image.convert("RGBA")
		self.target_image.putalpha(a)
		self.target_image.save(self.path)


	def _cleanup(self):
		pass


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("bus_path", type=str)
	parser.add_argument("itinerary", type=str_to_itinerary)

	parser.add_argument("remap", type=str_to_palette_remap)
	parser.add_argument("global_colors", type=int)
	parser.add_argument("neighbor_radius", type=int)
	parser.add_argument("blend_iterations", type=int)
	parser.add_argument("calculate_all", type=str_to_bool)
	parser.add_argument("occlusion_suffix", type=str_to_bool)

	args = parser.parse_args()
	args.remap.assign_globals()

	bus_path = args.bus_path
	bus = configparser.ConfigParser()
	bus.read(bus_path)

	bus_set("output", "attempts", 0)
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
