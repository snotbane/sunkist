shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

instance uniform vec4 modulate : source_color = vec4(1.0);
instance uniform float _popout_depth;

uniform bool unique_backface = false;

uniform vec4 emission_color : source_color = vec4(1.0);
instance uniform float emission_strength = 1.0;

uniform float ao_shadow_power = 4.0;
uniform float ao_light_scale : hint_range(0.0, 1.0) = 1.0;

uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;

uniform float normal_scale : hint_range(0.0, 1.0) = 0.5;


uniform sampler2D _r_a : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 _r_a_rect;
uniform vec2 _r_a_offset;

uniform sampler2D _l_a : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 _l_a_rect;

uniform sampler2D _r_e : source_color, filter_linear_mipmap_anisotropic, hint_default_black;
uniform vec4 _r_e_rect;

uniform sampler2D _l_e : source_color, filter_linear_mipmap_anisotropic, hint_default_black;
uniform vec4 _l_e_rect;

uniform sampler2D _r_m : filter_linear_mipmap_anisotropic, hint_default_black;
uniform vec4 _r_m_rect;

uniform sampler2D _l_m : filter_linear_mipmap_anisotropic, hint_default_black;
uniform vec4 _l_m_rect;

uniform sampler2D _r_n : filter_linear_mipmap_anisotropic, hint_normal;
uniform vec4 _r_n_rect;

uniform sampler2D _l_n : filter_linear_mipmap_anisotropic, hint_normal;
uniform vec4 _l_n_rect;


vec4 atlas(vec2 uv, sampler2D tex, vec4 rect, vec2 offset) {
	vec2 size = vec2(textureSize(tex, 0));
	rect.xy += offset;
	rect = rect / vec4(size, size);
	return texture(tex, uv * rect.zw + rect.xy);
}


vec4 paper_swap(vec4 a, vec4 b, bool front_facing) {
	return (!front_facing && unique_backface) ? b : a;
}

void vertex() {
	vec3 NORMAL_WORLD = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 VERTEX_WORLD = (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - VERTEX_WORLD);
	bool is_front_face = dot(NORMAL_WORLD, view_direction) > 0.0;
	float front_face_scalar = (is_front_face ? 1.0 : -1.0);
	//NORMAL *= front_face_scalar;
	VERTEX += NORMAL * front_face_scalar * _popout_depth;
}


void fragment() {	
	vec4 paper_color = paper_swap(atlas(UV, _r_a, _r_a_rect, _r_a_offset), atlas(UV, _l_a, _l_a_rect, vec2(0)), FRONT_FACING);
	ALBEDO = paper_color.rgb * modulate.rgb;
	ALPHA = paper_color.a * modulate.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	vec4 paper_emission = paper_swap(atlas(UV, _r_e, _r_e_rect, vec2(0)), atlas(UV, _l_e, _l_e_rect, vec2(0)), FRONT_FACING);
	EMISSION = paper_emission.rgb * paper_emission.a * emission_color.rgb * emission_strength;

	vec4 paper_custom = paper_swap(atlas(UV, _r_m, _r_m_rect, vec2(0)), atlas(UV, _l_m, _l_m_rect, vec2(0)), FRONT_FACING);
	ROUGHNESS = paper_custom.r * roughness;
	METALLIC = paper_custom.b * metallic;

	AO = pow(1.0 - paper_custom.g, ao_shadow_power);
	AO_LIGHT_AFFECT = ao_light_scale;

	vec4 paper_normal = paper_swap(atlas(UV, _r_n, _r_n_rect, vec2(0)), atlas(UV, _l_n, _l_n_rect, vec2(0)), FRONT_FACING);
	NORMAL_MAP = paper_normal.rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
