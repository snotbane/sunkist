@tool
extends PythonTask

## Pixels with an opacity lower than this value will be discarded.
@export_range(0, 255, 1) var island_opacity: int = 0:
	set(value):
		if island_opacity == value: return

		refresh_comment_if_default()
		island_opacity = value
		validate_args()


## Pixel islands with a larger rectangular area than this will be included in the final image. Pixel islands with a smaller rectangular area than this will be discarded.
@export_range(0, 512, 1, "or_greater") var island_size: int = 256:
	set(value):
		if island_size == value: return

		refresh_comment_if_default()
		island_size = value
		validate_args()


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/spruce/spruce.py"


func _get_default_comment() -> String:
	var result := "%s : %spx / %sa" % [
		super._get_default_comment(),
		island_size,
		island_opacity,
	]

	return result


func _get_python_arguments() -> Array:
	return [
		island_opacity,
		island_size,
	]


func _save_args(result: Dictionary) -> void:
	super._save_args(result)

	result.merge({
		&"island_opacity": island_opacity,
		&"island_size": island_size,
	})


func _load_args(data: Dictionary) -> void:
	super._load_args(data)

	island_opacity = data[&"island_opacity"]
	island_size = data[&"island_size"]


func _reset() -> void:
	%source_preview.clear()
	%target_preview.clear()
	%diff_preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	%source_preview.value = bus.get_value("output", "source_preview", "")
	%target_preview.value = bus.get_value("output", "target_preview", "")
	%diff_preview.value = bus.get_value("output", "target_bitmap", "")
