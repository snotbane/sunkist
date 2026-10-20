@tool
class_name Sunkist3D
extends Sprite3D

const OFFSET_FLIP := Vector2(1.0, -1.0)


static func get_sunkist_container_ancestor(node: Node) -> SunkistContainer3D:
	var result := node.get_parent()
	while result != null and result is not SunkistContainer3D:
		result = result.get_parent()
	return result


## This will set an instance shader parameter which ensures the sprite will stay in its proper depth, even when facing the opposite direction. Represented as an [int] value for simplicity, but actually translates to a [float] value.
@export_range(-128, 128, 1, "or_greater", "or_less")
var popout_layer: int = 0:
	get: return get_instance_shader_parameter(&"_popout_depth") * 10_000
	set(value): set_instance_shader_parameter(&"_popout_depth", 0.00_01 * value)


## If enabled, this node will not be managed by its ancestor's [member SunkistContainer3D.material_changed]. If not the descendant of a [SunkistContainer3D], this has no effect.
@export
var override_container_material: bool = false:
	set(value):
		override_container_material = value

		if sunkist_parent:
			if override_container_material:
				if sunkist_parent.material_changed.is_connected(_refresh_material):
					sunkist_parent.material_changed.disconnect(_refresh_material)
			elif not sunkist_parent.material_changed.is_connected(_refresh_material):
				sunkist_parent.material_changed.connect(_refresh_material)
				_refresh_material()


## This value is directly linked to [member centered], but it also calls [member _size_changed] when set. Always use this instead of [member centered].
@export
var centered_smart: bool = false:
	get: return centered
	set(value):
		centered = value
		_size_changed()


@onready
var sunkist_parent: SunkistContainer3D = Sunkist3D.get_sunkist_container_ancestor(self)


var _was_editable := true


func _init() -> void:
	centered = false


func _ready() -> void:
	if sunkist_parent:
		sunkist_parent.size_changed.connect(_size_changed)
		if not override_container_material:
			sunkist_parent.material_changed.connect(_refresh_material)

	if Engine.is_editor_hint() and material_override == null:
		material_override = SunkistMaterial.new()

	texture_changed.connect(_texture_changed)

	_refresh_material()


func _refresh_material() -> void:
	if sunkist_parent and sunkist_parent.material_template:
		material_override = sunkist_parent.material_template.duplicate()

	_texture_changed()


func _texture_changed() -> void:
	material_override.texture = texture
	_size_changed()


func _size_changed() -> void:
	if sunkist_parent:
		pixel_size = sunkist_parent.pixel_size

	set_position_to_texture_offset(material_override.texture)


func set_position_to_texture_offset(__texture__: SunkistTexture) -> void:
	if centered:
		offset = Vector2.ZERO
	elif __texture__:
		offset = Vector2.UP * __texture__.get_size().y + __texture__.offset_default * Sunkist3D.OFFSET_FLIP
