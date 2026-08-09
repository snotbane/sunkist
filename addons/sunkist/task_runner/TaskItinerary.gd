@tool
class_name TaskItinerary
extends Resource

static func validate_regex_string(rx: String) -> bool:
	return rx.is_empty() or RegEx.create_from_string(rx).is_valid()


## The location of the source file or folder.
@export_global_dir var source: String:
	set(value):
		if source == value: return

		source = value
		emit_changed()

## The destination of the target file or folder. If unset, use the same directory as [member source].
@export_global_dir var target: String:
	set(value):
		if target == value: return

		target = value
		emit_changed()

var target_safe: String:
	get: return target if target else source


## Include regex filter. Filters to include only files whose names (not including directory or extension) match.
@export var include: String = r"":
	set(value):
		if include == value: return

		include = value
		include_regex.compile(include)

		emit_changed()

var include_regex := RegEx.new()


## Exclude regex filter. Filters to exclude any files whose names (not including directory or extension) match.
@export var exclude: String = r"":
	set(value):
		if exclude == value: return

		exclude = value
		exclude_regex.compile(exclude)

		emit_changed()

var exclude_regex := RegEx.new()

## Pattern which will be removed in the target file name.
@export var rename_filter: String = r"":
	set(value):
		if rename_filter == value: return

		rename_filter = value
		rename_regex.compile(rename_filter)

		emit_changed()

var rename_regex := RegEx.new()


## Text to replace [member rename_filter] with in the target file name. If [member rename_filter] is not specified, this string will be appended to the end.
@export var rename_replace: String = r"":
	set(value):
		if rename_replace == value: return

		rename_replace = value
		emit_changed()


## If enabled, the process will overwrite the target file if it already exists. If disabled, the process will skip any files that already exist.
@export var overwrite: bool = true:
	set(value):
		if overwrite == value: return

		overwrite = value
		emit_changed()


var is_valid: bool:
	get: return validate().is_empty()


func _to_string() -> String:
	var result := "%s >> %s" % [source.get_file(), target.get_file()]

	if include:
		result += " (* /%s/)" % include

	if exclude:
		result += " (- /%s/)" % exclude

	return result


func validate() -> PackedStringArray:
	var result: PackedStringArray

	if source.is_empty():
		result.push_back("Source cannot be blank.")

	if not validate_regex_string(include):
		result.push_back("TaskItinerary :: include :: RegEx filter '%s' is not valid." % include)

	if not validate_regex_string(exclude):
		result.push_back("TaskItinerary :: exclude :: RegEx filter '%s' is not valid." % exclude)

	if not validate_regex_string(rename_filter):
		result.push_back("TaskItinerary :: rename_filter :: RegEx filter '%s' is not valid." % rename_filter)

	return result


func get_as_args() -> Array:
	return [
		source,
		target_safe,
		include,
		exclude,
		rename_filter,
		rename_replace,
		"true" if overwrite else "false"
	]


func serialize() -> String:
	var result := ""

	for arg: String in get_as_args():
		result += "%s\t" % arg

	return PythonTask.value_as_python_argument(result.left(-1))


func deserialize(s: String) -> void:
	var splits := s.split("\t")

	source = splits[0]
	target = splits[1]
	include = splits[2]
	exclude = splits[3]
	rename_filter = splits[4]
	rename_replace = splits[5]
	overwrite = splits[6] == "true"


func save_args() -> Dictionary:
	return {
		&"source": source,
		&"target": target,
		&"include": include,
		&"exclude": exclude,
		&"rename_filter": rename_filter,
		&"rename_replace": rename_replace,
		&"overwrite": overwrite,
	}


func load_args(data: Dictionary) -> void:
	source = data[&"source"]
	target = data[&"target"]
	include = data[&"include"]
	exclude = data[&"exclude"]
	rename_filter = data[&"rename_filter"]
	rename_replace = data[&"rename_replace"]
	overwrite = data[&"overwrite"]
