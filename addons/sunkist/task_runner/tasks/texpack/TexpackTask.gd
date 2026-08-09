@tool
extends PythonTask

## Project name and also the name of the resulting image file(s) and data file.
@export var project_name: String:
	set(value):
		if project_name == value: return

		refresh_comment_if_default()
		project_name = value
		validate_args()


## The max pixel dimensions (square) a target image can be. If an island cannot be placed without expanding the target image beyond this limit, a new target image will be created.
@export_range(1, 65536, 1, "or_greater") var target_size_limit: int = 65536:
	set(value):
		if target_size_limit == value: return

		refresh_comment_if_default()
		target_size_limit = value
		validate_args()


var _target_format := Image.Format.FORMAT_RGBA8
## Target image format. For now, only use RGBA.
@export_storage var target_format := Image.Format.FORMAT_RGBA8:
	get: return _target_format
	set(value):
		if _target_format == value: return

		refresh_comment_if_default()
		_target_format = value
		validate_args()


var _filter_separate: String = r"^"
## File names (excluding extension) matching this regex filter will be separated into different spritesheets. Target files will be named based on this filter. This is primarily used to keep different kinds of sprites together, such as albedo and normal maps. For example, use `-[a-zA-Z]$` to separate files ending with an alphabetic character, like `-n`, `-o`, `-m`, etc. Default: `^` (This will combine all source images into a single spritesheet, because all file names contain this character sequence.)
@export var filter_separate: String = r"^":
	get: return _filter_separate
	set(value):
		if _filter_separate == value: return

		refresh_comment_if_default()
		_filter_separate = value
		validate_args()


## Assigns composition data based on the internal groups of the regex. FOR NOW this only works with this specific pattern, so don't change this.
@export_storage var filter_composite: String = r"((.+?)(?:\-(\d+))?)\-([lr])\-(.)":
	set(value):
		if filter_composite == value: return

		refresh_comment_if_default()
		filter_composite = value
		validate_args()


## If enabled, only the bounding box containing all visible pixels will be included.
## If disabled, include the entire source image.
@export var island_crop: bool = true:
	set(value):
		if island_crop == value: return

		refresh_comment_if_default()
		island_crop = value
		validate_args()


## The space between sprites and image bounds in the final image(s).
@export_range(0, 256, 1, "or_greater") var island_margin: int = 2:
	set(value):
		if island_margin == value: return

		refresh_comment_if_default()
		island_margin = value
		validate_args()


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/sunkist/sunkist_assembly.py"


func _get_default_comment() -> String:
	return "%s.%s : %s" % [
		project_name,
		SunkistSheet.VALID_EXTENSIONS[0],
		super._get_default_comment()
	]


func _validate_args() -> void:
	validate_non_empty_string(project_name, "project_name")
	validate_regex_string(filter_separate, false, "filter_separate")
	validate_regex_string(filter_composite, false, "filter_composite")

	super._validate_args()


func _get_python_arguments() -> Array:
	return [
		project_name,
		target_size_limit,
		"RGBA",
		filter_separate,
		filter_composite,
		island_crop,
		island_margin,
	]


func _save_args(result: Dictionary) -> void:
	super._save_args(result)

	result.merge({
		&"project_name": project_name,
		&"target_size_limit": target_size_limit,
		&"target_format": target_format,
		&"filter_separate": filter_separate,
		&"filter_composite": filter_composite,
		&"island_crop": island_crop,
		&"island_margin": island_margin,
	})


func _load_args(data: Dictionary) -> void:
	super._load_args(data)

	project_name = data[&"project_name"]
	target_size_limit = data[&"target_size_limit"]
	target_format = data[&"target_format"]
	filter_separate = data[&"filter_separate"]
	filter_composite = data[&"filter_composite"]
	island_crop = data[&"island_crop"]
	island_margin = data[&"island_margin"]


func _finish(code: int) -> void:
	if status != SUCCEEDED: return

	for path in target_paths:
		var preview: ImagePreview = $v_box_container/content/previews/source.duplicate(DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		preview.set_value.call_deferred(path)
		$v_box_container/content/previews/targets.add_child(preview)
	$v_box_container/content/previews/targets.columns = ceili(sqrt(target_paths.size()))
	$v_box_container/content/previews/targets.visible = true

	## TODO: refresh SunkistSheet resource


func _reset() -> void:
	$v_box_container/content/previews/source.clear()
	$v_box_container/content/previews/source.visible = true

	for child in $v_box_container/content/previews/targets.get_children():
		child.queue_free()
	target_paths.clear()

var target_paths: PackedStringArray


func _bus_poll() -> void:
	super._bus_poll()

	$v_box_container/content/previews/source.value = bus.get_value("output", "source_preview", "")

	var target_updated: String = bus.get_value("output", "target_updated", "")

	if not target_updated.is_empty() and target_updated not in target_paths:
		target_paths.push_back(target_updated)
