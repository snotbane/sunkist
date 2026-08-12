# pyright: reportOptionalSubscript=false
import argparse
import configparser
import os
import re
import shutil
import subprocess
import sys
import time
from PIL import Image

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

		self.temp_source = os.path.join(os.path.dirname(args.bus_path), os.path.basename(self.source))
		self.temp_sdf = os.path.join(os.path.dirname(args.bus_path), f"{self.source_name}_s{self.ext}")
		self.temp_normal = os.path.join(os.path.dirname(args.bus_path), f"{self.source_name}_n{self.ext}")


	def __str__(self):
		return self.path


	def process(self):
		global attempts
		global progress

		try:
			attempts += 1
			bus_set("output", "attempts", attempts)
			bus_set("output", "source_preview", f"\"{self.source}\"")
			os.makedirs(os.path.dirname(self.path), exist_ok = True)
			os.makedirs(os.path.dirname(self.temp_source), exist_ok = True)

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
		shutil.copyfile(self.source, self.temp_source)

		process = subprocess.Popen(executable=args.laigter_path, args=["--no-gui", "--diffuse", self.temp_source, "--preset", args.laigter_preset, "--normal"], shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

		while process.poll() is None:
			if bus_get("input", "stop"):
				process.kill()
				sys.exit(45) ## ERR_SKIP
			time.sleep(0.25)

		if not os.path.exists(self.temp_normal): raise Exception(f"Normal file '{self.temp_normal}' does not exist and/or was not created.")
		image = Image.open(self.temp_normal)

		source : Image.Image = Image.open(self.source).convert("RGBA")
		image.putalpha(source.getchannel("A"))
		image.save(self.path)


	def _cleanup(self):
		if os.path.exists(self.temp_source):
			os.remove(self.temp_source)

		if os.path.exists(self.temp_sdf):
			os.remove(self.temp_sdf)

		if os.path.exists(self.temp_normal) and self.temp_normal != self.path:
			os.remove(self.temp_normal)


def str_to_itinerary(value: str) -> Itinerary:
	return Itinerary(value)


if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("bus_path", type=str)
	parser.add_argument("itinerary", type=str_to_itinerary)
	parser.add_argument("laigter_path", type=str)
	parser.add_argument("laigter_preset", type=str)
	args = parser.parse_args()

	bus_path = args.bus_path
	bus = configparser.ConfigParser()
	bus.read(bus_path)


	bus_set("output", "attempts", 0)
	bus_set("output", "progress", 0)

	targets = args.itinerary.get_targets()
	bus_set("output", "progress_max", len(targets))

	for target in targets:
		target.process()

	if progress < len(targets):
		sys.stderr.write("\nNot all images were successfully processed.")
		sys.exit(39) ## ERR_SCRIPT_FAILED

	sys.exit(0)
