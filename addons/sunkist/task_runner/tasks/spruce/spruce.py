import argparse
import configparser
import os
import re
import sys
import time
from PIL import Image, ImageChops


SUPPORTED_EXTS = [".png", ".jpg", ".jpeg"]
attempts: int = 0
progress: int = 0
temp_dir: str


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


class Rect:
	def __init__(self, *args):
		if len(args) == 4 and all(isinstance(arg, int) for arg in args):
			self.x, self.y, self.w, self.h = args
		elif len(args) == 2 and all(isinstance(arg, tuple) and len(arg) == 2 for arg in args):
			(self.x, self.y), (self.w, self.h) = args
		else:
			raise TypeError("Expected 4 integers or 2 (x, y) tuples")


	def __repr__(self):
		return f"Rect({self.x}, {self.y} ... {self.w}, {self.h})"


	@property
	def xy(self) -> tuple[int, int]:
		return (self.x, self.y)
	@xy.setter
	def xy(self, value: tuple[int, int]):
		self.x = value[0]
		self.y = value[1]


	@property
	def size(self) -> tuple[int, int]:
		return (self.w, self.h)
	@size.setter
	def size(self, value: tuple[int, int]):
		self.w = value[0]
		self.h = value[1]


	@property
	def r(self) -> int:
		return self.x + self.w
	@r.setter
	def r(self, value):
		self.w = value - self.x


	@property
	def b(self) -> int:
		return self.y + self.h
	@b.setter
	def b(self, value):
		self.h = value - self.y


	@property
	def rb(self) -> tuple[int, int]:
		return (self.r, self.b)
	@rb.setter
	def rb(self, value: tuple[int, int]):
		self.r = value[0]
		self.b = value[1]


	@property
	def area(self) -> int:
		return self.w * self.h


	## Returns true if the other Rect is completely inside self
	def contains(self, other) -> bool:
		if not isinstance(other, Rect):
			raise TypeError("Expected a Rect instance")
		return (
			self.x <= other.x and self.y <= other.y and
			self.r >= other.r and self.b >= other.b
		)

	## Returns true if the Rects touch at all
	def overlaps(self, other) -> bool:
		if not isinstance(other, Rect):
			raise TypeError("Expected a Rect instance")
		return not (
			self.r <= other.x or self.x >= other.r or
			self.b <= other.y or self.y >= other.b
		)

	def union(self, other):
		result = Rect(min(self.x, other.x), min(self.y, other.y), max(self.r, other.r), max(self.b, other.b))
		result.r = result.w
		result.b = result.h
		return result


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
		## Initialize bitmap

		r, g, b, a = self.source_image.split()
		a_pix = a.load()
		w, h = self.source_image.size
		bitmap : Image.Image = Image.new("1", self.source_image.size)
		bitmap_pix = bitmap.load()

		## Cull pixels below opacity threshold in bitmap

		for x in range(w):
			for y in range(h):
				bitmap_pix[x, y] = 0 if a_pix[x, y] <= args.island_opacity else 1  # pyright: ignore[reportOptionalSubscript]

		bitmap_original = bitmap.copy()

		## Cull pixel islands below area threshold in bitmap

		if args.island_size < w * h:
			pixels_visited : set = set()
			island_bitmaps : set = set()

			def flood_fill(x, y):
				stack = [(x, y)]
				island_pixels = []

				while stack:
					px, py = stack.pop()
					if (px, py) in pixels_visited or px < 0 or py < 0 or px >= w or py >= h:
						continue
					if bitmap_pix[px, py] == 0: # pyright: ignore[reportOptionalSubscript]
						continue

					pixels_visited.add((px, py))
					island_pixels.append((px, py))

					stack.extend([(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)])
				return island_pixels

			# for x, y in range(w, h):
			for x in range(w):
				for y in range(h):
					if (x, y) in pixels_visited or bitmap_pix[x, y] == 0: continue # pyright: ignore[reportOptionalSubscript]

					island_pixels = flood_fill(x, y)
					if not island_pixels: continue

					min_x = min(p[0] for p in island_pixels)
					max_x = max(p[0] for p in island_pixels)
					min_y = min(p[1] for p in island_pixels)
					max_y = max(p[1] for p in island_pixels)
					island_rect = Rect(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
					if island_rect.area < args.island_size: continue

					island_bitmaps = island_bitmaps.union(island_pixels)

			for x in range(w):
				for y in range(h):
					bitmap_pix[x, y] = 1 if (x, y) in island_bitmaps else 0 # pyright: ignore[reportOptionalSubscript]

		## Merge bitmap and original alpha

		mask = bitmap.convert("L")
		mask_pix = mask.load()

		for x in range(w):
			for y in range(h):
				a_pix[x, y] = min(mask_pix[x, y], a_pix[x, y]) # pyright: ignore[reportOptionalSubscript]

		self.target_image = Image.merge("RGBA", (r, g, b, a))
		self.target_image.save(self.temp_target)

		## Commit final image

		changes_exist : bool = False
		if not args.itinerary.overwrite:
			changes = ImageChops.difference(bitmap, bitmap_original)
			changes_exist = changes.getbbox()

			if changes_exist:
				changes.save(self.temp_diff)

		if changes_exist:
			bus_set("output", "target_bitmap", f"\"{self.temp_diff}\"")
			bus_set("output", "target_preview", f"\"{self.temp_target}\"")

		else:
			self.target_image.save(self.path)

			bus_set("output", "target_bitmap", f"\"\"")
			bus_set("output", "target_preview", f"\"\"")

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

	parser.add_argument("island_opacity", type=int)
	parser.add_argument("island_size", type=int)

	args = parser.parse_args()

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
