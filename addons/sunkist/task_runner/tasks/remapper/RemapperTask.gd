@tool
extends PythonTask

@export var remap: ColorRemap


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/remapper/remapper.py"


func _get_python_arguments() -> Array:
	return [
		Task.TEMP_DIR_PATH,
		itinerary.serialize()
	]


func _validate_args() -> void:
	validate_itinerary(itinerary)


func _save_args(result: Dictionary) -> void:
	result.merge({
		&"itinerary": itinerary.serialize(),
	})

func _load_args(data: Dictionary) -> void:
	itinerary = TaskItinerary.new()
	itinerary.deserialize(data[&"itinerary"])


func _reset() -> void:
	$v_box_container/content/split/source/preview.clear()
	$v_box_container/content/split/target/preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	$v_box_container/content/split/source/preview.value = bus.get_value("output", "source_preview", "")
	$v_box_container/content/split/target/preview.value = bus.get_value("output", "target_preview", "")
