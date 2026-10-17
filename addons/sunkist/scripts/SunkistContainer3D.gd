## Generates a [MeshInstance3D] that combines [Sunkist2D]s from a specified scene and combines them into a single rendered 3D sprite. Sunkist!
@tool
@icon("res://addons/sunkist/ui/icons/layers_3d.svg")
class_name SunkistContainer3D
extends Node3D

const PREVIEW_CANVAS_MATERIAL := preload("res://addons/sunkist/materials/mat_sunkist_canvas.tres")


signal size_changed
signal preview_changed
signal material_changed


@export
var size := Vector2.ZERO:
	set(value):
		size = value
		_refresh_position()


@export_range(0.0001, 1.0, 0.0001, "or_greater", "prefer_slider")
var pixel_size: float = 0.001:
	set(value):
		pixel_size = value
		_refresh_position()


@export
var material_template: SunkistMaterial:
	set(value):
		if material_template:
			material_template.changed.disconnect(material_changed.emit)

		material_template = value

		if material_template:
			material_template.changed.connect(material_changed.emit)

		material_changed.emit()


@export_subgroup("Preview", "_preview_")

@export_custom(PROPERTY_HINT_GROUP_ENABLE, "")
var _preview_enabled: bool = false:
	set(value):
		_preview_enabled = value
		preview_changed.emit()

		if not Engine.is_editor_hint(): return

		_canvas_meshinst.visible = _preview_enabled


@export
var _preview_mirrored: bool = false:
	set(value):
		_preview_mirrored = value
		preview_changed.emit()


@export
var _preview_component: int = 0:
	set(value):
		_preview_component = value
		preview_changed.emit()


var _canvas_meshinst: MeshInstance3D


func _init() -> void:
	if Engine.is_editor_hint():
		_canvas_meshinst = MeshInstance3D.new()
		_canvas_meshinst.mesh = QuadMesh.new()
		_canvas_meshinst.mesh.surface_set_material(0, PREVIEW_CANVAS_MATERIAL)
		_canvas_meshinst.visible = false
		add_child(_canvas_meshinst, false, INTERNAL_MODE_FRONT)


func _get_configuration_warnings() -> PackedStringArray:
	var result: PackedStringArray

	if size == Vector2.ZERO:
		result.push_back("SunkistContainer3D must have its size set greater than (0, 0). Set it to the bounding box size made up of all sprites.")

	return result


func _refresh_position() -> void:
	position = Vector3(size.x, -size.y, 0.0) * pixel_size * -0.5

	if Engine.is_editor_hint():
		_canvas_meshinst.mesh.size = size * pixel_size
		_canvas_meshinst.position = Vector3(size.x, -size.y, 0.0) * pixel_size * 0.5

	size_changed.emit()
