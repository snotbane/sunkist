@tool
extends PythonTask

@export var remap: ColorRemap

## This value determines how many [member remap.source.colors] are treated as global. Global colors are evaluated if a non-palette pixel has only one palette neighbor. Primarily used for lineart colors.
@export_range(0, 10, 1, "or_greater") var global_colors = 0:
	set(value):
		if global_colors == value: return

		refresh_comment_if_default()
		global_colors = value
		validate_args()


## This value determines how far each pixel should reach to find neighbors that belong to the palette. Higher values are less efficient, and not necessarily more accurate. Fine tune to get a good balance, based on your image resolution. A good value is usually double the size of the line art's brush feather size.
@export_range(0, 10, 1, "or_greater") var neighbor_radius = 2:
	set(value):
		if neighbor_radius == value: return

		refresh_comment_if_default()
		neighbor_radius = value
		validate_args()


## This value controls the quality of the final remap result. Linearly increases computation time; logarithmically increases accuracy. Try to set this as high as you can tolerate for production. Use lower values to test out palettes.
@export_range(0, 1000, 10, "or_greater") var blend_iterations = 100:
	set(value):
		if blend_iterations == value: return

		refresh_comment_if_default()
		blend_iterations = value
		validate_args()


## If enabled, this will check neighbors on ALL pixels, even pixels that already match a palette color. This VASTLY increases computation time, but will correct blended/feathered pixels that happen to fall on palette colors.
@export var calculate_all: bool = false:
	set(value):
		if calculate_all == value: return

		refresh_comment_if_default()
		calculate_all = value
		validate_args()


## If a file with this suffix exists, add it to the green channel of the resulting image.
@export var occlusion_suffix: String = "o":
	set(value):
		if occlusion_suffix == value: return

		refresh_comment_if_default()
		occlusion_suffix = value
		validate_args()


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/remapper/remapper.py"


func _get_python_arguments() -> Array:
	return [
		remap.serialize(),
		global_colors,
		neighbor_radius,
		blend_iterations,
		calculate_all,
		occlusion_suffix,
	]


func _validate_args() -> void:
	validate_itinerary(itinerary)


func _save_args(result: Dictionary) -> void:
	super._save_args(result)

	result.merge({
		&"remap": remap.serialize(),
		&"global_colors": global_colors,
		&"neighbor_radius": neighbor_radius,
		&"blend_iterations": blend_iterations,
		&"occlusion_suffix": occlusion_suffix,
	})

func _load_args(data: Dictionary) -> void:
	super._load_args(data)

	remap = ColorRemap.new()
	remap.deserialize(data[&"remap"])

	global_colors = data[&"global_colors"]
	neighbor_radius = data[&"neighbor_radius"]
	blend_iterations = data[&"blend_iterations"]
	calculate_all = data[&"calculate_all"]
	occlusion_suffix = data[&"occlusion_suffix"]


func _reset() -> void:
	$v_box_container/content/split/source/preview.clear()
	$v_box_container/content/split/target/preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	$v_box_container/content/split/source/preview.value = bus.get_value("output", "source_preview", "")
	$v_box_container/content/split/target/preview.value = bus.get_value("output", "target_preview", "")
