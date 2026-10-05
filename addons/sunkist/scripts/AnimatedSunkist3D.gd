@tool
class_name AnimatedSunkist3D
extends AnimatedSprite3D

## If enabled, this will use a clone of an ancestor's [member SunkistContainer3D.material_template].
@export var use_container_template: bool = true:
	set(value):
		use_container_template = value

		if sunkist_parent:
			if use_container_template and not sunkist_parent.material_changed.is_connected(_refresh_material):
				sunkist_parent.material_changed.connect(_refresh_material)
				_refresh_material()
			elif sunkist_parent.material_changed.is_connected(_refresh_material):
				sunkist_parent.material_changed.disconnect(_refresh_material)


## This will set an instance shader parameter which ensures the sprite will stay in its proper depth, even when facing the opposite direction. Represented as an [int] value for simplicity, but actually translates to a [float] value.
@export_range(-128, 128, 1, "or_greater", "or_less") var popout_layer: int = 0:
	get: return get_instance_shader_parameter(&"_popout_depth") * 10_000
	set(value): set_instance_shader_parameter(&"_popout_depth", 0.00_01 * value)

## This value is directly linked to [member centered], but it also calls [member _size_changed] when set. Always use this instead of [member centered].
@export
var centered_smart: bool = true:
	get: return centered
	set(value):
		centered = value
		_size_changed()

@onready var sunkist_parent: SunkistContainer3D = Sunkist3D.get_sunkist_ancestor(self)


var _was_editable := true


var current_frame_texture: Texture2D:
	get: return sprite_frames.get_frame_texture(animation, frame)


func _ready() -> void:
	if sunkist_parent:
		sunkist_parent.material_changed.connect(_refresh_material)
		sunkist_parent.size_changed.connect(_size_changed)

	if Engine.is_editor_hint() and material_override == null:
		material_override = SunkistMaterial.new()

	sprite_frames_changed.connect(_sprite_frames_changed)
	animation_changed.connect(_texture_changed)
	frame_changed.connect(_texture_changed)

	_refresh_material()


func _sprite_frames_changed() -> void:
	_texture_changed()


func _refresh_material() -> void:
	if sunkist_parent and sunkist_parent.material_template:
		material_override = sunkist_parent.material_template.duplicate()

	_texture_changed()


func _texture_changed() -> void:
	material_override.texture = current_frame_texture
	_size_changed()


func _size_changed() -> void:
	if sunkist_parent:
		pixel_size = sunkist_parent.pixel_size

	set_position_to_texture_offset(material_override.texture)


func set_position_to_texture_offset(texture: SunkistTexture) -> void:
	if centered:
		offset = Vector2.ZERO
	elif texture:
		offset = Vector2.UP * texture.get_size().y + texture.offset_default * Sunkist3D.OFFSET_FLIP
