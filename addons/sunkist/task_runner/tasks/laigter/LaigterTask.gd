@tool
extends PythonTask


## Path of the Laigter executable. See the Laigter documentation on how to install or where to find.
@export_global_file var laigter_path: String:
	get:
		if not TaskRunner.inst: return ""
		return TaskRunner.inst.get_meta(&"laigter_path", "")
	set(value):
		if is_node_ready():
			TaskRunner.inst.set_meta(&"laigter_path", value)
			TaskRunner.inst.save_settings()

		validate_args()


## Path of the Laigter preset file. This must be manually created in the Laigter app.
@export_global_file var preset_path: String:
	set(value):
		if preset_path == value: return

		refresh_comment_if_default()
		preset_path = value
		validate_args()


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/laigter/laigter.py"


func _get_default_comment() -> String:
	return "%s : %s" % [preset_path.get_file(), itinerary]


func _validate_args() -> void:
	validate_file_path(laigter_path, true, "laigter_path")
	validate_file_path(preset_path, true, "preset_path")


func _get_python_arguments() -> Array:
	return [
		itinerary.serialize(),
		laigter_path,
		preset_path,
	]


func _save_args(result: Dictionary) -> void:
	super._save_args(result)
	result.merge({
		&"laigter_path": laigter_path,
		&"preset_path": preset_path,
	})


func _load_args(data: Dictionary) -> void:
	super._load_args(data)
	preset_path = data[&"preset_path"]


func _reset() -> void:
	$v_box_container/content/split/source/preview.clear()
	$v_box_container/content/split/target/preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	$v_box_container/content/split/source/preview.value = bus.get_value("output", "source_preview", "")
	$v_box_container/content/split/target/preview.value = bus.get_value("output", "target_preview", "")
