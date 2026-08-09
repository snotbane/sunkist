import argparse
import configparser
import os
import re
import subprocess
import sys
import time

SUPPORTED_EXTS = [".png"]
attempts: int = 0
progress: int = 0
bytes_reduced: int = 0


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

			# bus_set("output", "target_preview", f"\"{self.path}\"")
			progress += 1
			bus_set("output", "progress", progress)


		except Exception as e:
			sys.stderr.write(f"\nError processing {self.path}: {e}")
			# bus_set("output", "target_preview", f"\"\"")

		finally:

			self._cleanup()



	def _process(self):
		global bytes_reduced

		file_size_prior = os.path.getsize(self.source)

		process = subprocess.Popen([args.optipng_path, "-o7", "-out", self.source, self.source], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

		while process.poll() is None:
			if bus_get("input", "stop"):
				process.kill()
				sys.exit(1)
			time.sleep(0.25)

		file_size_after = os.path.getsize(self.path)

		bytes_reduced += file_size_prior - file_size_after
		bus_set("output", "bytes", bytes_reduced)


	def _cleanup(self):
		pass


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("bus_path", type=str)
	parser.add_argument("itinerary", type=str_to_itinerary)

	parser.add_argument("optipng_path", type=str)

	args = parser.parse_args()

	bus_path = args.bus_path
	bus = configparser.ConfigParser()
	bus.read(bus_path)
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
