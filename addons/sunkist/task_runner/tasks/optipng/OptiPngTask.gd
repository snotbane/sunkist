## Runs OptiPNG on images. This automatically uses the best (slowest) setting. [url=https://optipng.sourceforge.net/optipng-7.9.1.man1.html]OptiPNG Documentation[/url]
@tool
extends PythonTask

static func bytes_to_string(bytes: int) -> String:
	const SIZE_KB := 1024
	const SIZE_MB := SIZE_KB * 1024
	const SIZE_GB := SIZE_MB * 1024

	if bytes < SIZE_KB:
		return str(bytes) + " B"

	if bytes < SIZE_MB:
		return "%.2f KB" % (float(bytes) / SIZE_KB)

	if bytes < SIZE_GB:
		return "%.2f MB" % (float(bytes) / SIZE_MB)

	return "%.2f GB" % (float(bytes) / SIZE_GB)


@export var optipng_path: String:
	get:
		if not TaskRunner.inst: return ""
		return TaskRunner.inst.get_meta(&"optipng_path", "")
	set(value):
		if is_node_ready():
			TaskRunner.inst.set_meta(&"optipng_path", value)
			TaskRunner.inst.save_settings()

		validate_args()


var _bytes_reduced: int
var bytes_reduced: int:
	get: return _bytes_reduced
	set(value):
		if _bytes_reduced == value: return
		_bytes_reduced = value

		%bytes_reduced_label.text = "%s reduced" % [bytes_to_string(_bytes_reduced)]


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/optipng/optipng.py"


# func _get_default_comment() -> String:
# 	return super._get_default_comment()


func _validate_args() -> void:
	validate_file_path(optipng_path, true, "optipng_path")

	super._validate_args()


func _get_python_arguments() -> Array:
	return [
		optipng_path,
	]


func _save_args(result: Dictionary) -> void:
	super._save_args(result)

	result.merge({
		&"optipng_path": optipng_path,
	})


# func _load_args(data: Dictionary) -> void:
# 	super._load_args(data)


func _reset() -> void:
	bytes_reduced = 0
	%source_preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	bytes_reduced = bus.get_value("output", "bytes", 0)
	%source_preview.value = bus.get_value("output", "source_preview", "")
