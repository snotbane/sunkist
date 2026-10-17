@tool
class_name SunkistMaterial
extends ShaderMaterial

const SHADER: Shader = preload("res://addons/sunkist/shaders/Sunkist3D_Scissor.gdshader")

static var MATERIAL_SUFFIX_REMAP_DEFAULT: PackedStringArray = [
	&"_r_a",
	&"_l_a",
	&"_r_e",
	&"_l_e",
	&"_r_m",
	&"_l_m",
	&"_r_n",
	&"_l_n",
]


@export
var unique_backface: bool = false:
	get: return get_shader_parameter(&"unique_backface")
	set(value):
		set_shader_parameter(&"unique_backface", value)
		emit_changed()


@export
var emission_color: Color = Color.WHITE:
	get: return get_shader_parameter(&"emission_color")
	set(value):
		set_shader_parameter(&"emission_color", value)
		emit_changed()


@export_range(0.0, 1.0, 0.001)
var ao_light_scale: float = 1.0:
	get: return get_shader_parameter(&"ao_light_scale")
	set(value):
		set_shader_parameter(&"ao_light_scale", value)
		emit_changed()


@export
var ao_shadow_power: float = 4.0:
	get: return get_shader_parameter(&"ao_shadow_power")
	set(value):
		set_shader_parameter(&"ao_shadow_power", value)
		emit_changed()


@export_range(0.0, 1.0, 0.001)
var roughness: float = 1.0:
	get: return get_shader_parameter(&"roughness")
	set(value):
		set_shader_parameter(&"roughness", value)
		emit_changed()


@export_range(0.0, 1.0, 0.001)
var specular: float = 1.0:
	get: return get_shader_parameter(&"specular")
	set(value):
		set_shader_parameter(&"specular", value)
		emit_changed()


@export_range(0.0, 1.0, 0.001)
var metallic: float = 1.0:
	get: return get_shader_parameter(&"metallic")
	set(value):
		set_shader_parameter(&"metallic", value)
		emit_changed()


@export_range(0.0, 1.0, 0.001)
var normal_scale: float = 0.5:
	get: return get_shader_parameter(&"normal_scale")
	set(value):
		set_shader_parameter(&"normal_scale", value)
		emit_changed()


var texture: SunkistTexture:
	set(value):
		texture = value
		if texture == null: return

		for i in texture.texture_slots:
			var tex := texture.textures[i]
			set_shader_parameter(MATERIAL_SUFFIX_REMAP_DEFAULT[i], tex)

			if tex is not AtlasTexture: continue

			set_shader_parameter(MATERIAL_SUFFIX_REMAP_DEFAULT[i] + &"_rect", Vector4(
				tex.region.position.x,
				tex.region.position.y,
				tex.region.size.x,
				tex.region.size.y
			))


func _init() -> void:
	shader = SHADER
