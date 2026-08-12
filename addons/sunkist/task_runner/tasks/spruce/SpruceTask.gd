@tool
extends PythonTask

@export_group("Spot Clearing", "spot_")

## This feature searches for spots (areas of opaque pixels) in the image and removes them.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var spot_enabled: bool = true:
	set(value):
		if spot_enabled == value: return

		refresh_comment_if_default()
		spot_enabled = value
		validate_args()

## Pixels with an opacity higher than this value will be considered part of an island (spot), and contribute to that island's [member spot_size].
@export_range(0, 255, 1)
var spot_opacity: int = 0:
	set(value):
		if spot_opacity == value: return

		refresh_comment_if_default()
		spot_opacity = value
		validate_args()


## Islands (spots) with a larger rectangular area than this will be included in the final image. Islands with a smaller rectangular area than this will be discarded.
@export_range(0, 512, 1, "or_greater")
var spot_size: int = 256:
	set(value):
		if spot_size == value: return

		refresh_comment_if_default()
		spot_size = value
		validate_args()


## Color used in the diff map. This has no effect on the final image; purely for assistance.
@export var spot_hint := Color.RED


@export_group("Hole Filling", "hole_")

## This feature searches for holes (areas of transparent pixels) in the image and fills them via interpolating surrounding pixel colors.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var hole_enabled: bool = true:
	set(value):
		if hole_enabled == value: return

		refresh_comment_if_default()
		hole_enabled = value
		validate_args()


## Pixels with an opacity lower than this value will be considered part of a hole.
@export_range(0, 255, 1)
var hole_opacity: int = 255:
	set(value):
		if hole_opacity == value: return

		refresh_comment_if_default()
		hole_opacity = value
		validate_args()


## Holes with a rectangular area smaller than this value will be filled. Holes with a rectangular area greater than this value will be ignored.
@export_range(0, 512, 1, "or_greater")
var hole_size: int = 256:
	set(value):
		if hole_size == value: return

		refresh_comment_if_default()
		hole_size = value
		validate_args()


## Color used in the diff map. This has no effect on the final image; purely for assistance.
@export var hole_hint := Color.GREEN


@export_group("Feather Cleanup", "feather_")

## This feature fixes stray colors that exist between transparent pixels and any colors in [member feather_palette], removing them from the image.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var feather_enabled: bool = true:
	set(value):
		if feather_enabled == value: return

		refresh_comment_if_default()
		feather_enabled = value
		validate_args()


## Colors designated as lineart.
@export var feather_palette: ColorPalette


## Color used in the diff map. This has no effect on the final image; purely for assistance.
@export var feather_hint := Color.BLUE


func _get_python_script_path() -> String:
	return "res://addons/sunkist/task_runner/tasks/spruce/spruce.py"


func _get_default_comment() -> String:
	var result := "%s : %spx / %sa" % [
		super._get_default_comment(),
		spot_size,
		spot_opacity,
	]

	return result


func _validate_args() -> void:
	super._validate_args()


func _get_python_arguments() -> Array:
	return [
		spot_enabled,
		spot_opacity,
		spot_size,
		spot_hint,
		hole_enabled,
		hole_opacity,
		hole_size,
		hole_hint,
		feather_enabled,
		feather_palette,
		feather_hint,
	]


func _save_args(result: Dictionary) -> void:
	super._save_args(result)

	result.merge({
		&"spot_enabled": spot_enabled,
		&"spot_opacity": spot_opacity,
		&"spot_size": spot_size,
		&"spot_hint": spot_hint.to_html(),
		&"hole_enabled": hole_enabled,
		&"hole_opacity": hole_opacity,
		&"hole_size": hole_size,
		&"hole_hint": hole_hint.to_html(),
		&"feather_enabled": feather_enabled,
		&"feather_palette": serialize_palette(feather_palette),
		&"feather_hint": feather_hint.to_html(),
	})


func _load_args(data: Dictionary) -> void:
	super._load_args(data)

	spot_enabled = data[&"spot_enabled"]
	spot_opacity = data[&"spot_opacity"]
	spot_size = data[&"spot_size"]
	spot_hint = Color.html(data[&"spot_hint"])
	hole_enabled = data[&"hole_enabled"]
	hole_opacity = data[&"hole_opacity"]
	hole_size = data[&"hole_size"]
	hole_hint = Color.html(data[&"hole_hint"])
	feather_enabled = data[&"feather_enabled"]
	feather_palette = deserialize_palette(data[&"feather_palette"])
	feather_hint = Color.html(data[&"feather_hint"])


func _reset() -> void:
	%source_preview.clear()
	%target_preview.clear()
	%diff_preview.clear()


func _bus_poll() -> void:
	super._bus_poll()

	%source_preview.value = bus.get_value("output", "source_preview", "")
	%target_preview.value = bus.get_value("output", "target_preview", "")
	%diff_preview.value = bus.get_value("output", "target_bitmap", "")
