shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float metallic : hint_range(0.0, 1.0, 0.01) = 0.3;

uniform float uv1_blend_sharpness : hint_range(0.0, 150.0, 0.001) = 16.0;
varying vec3 uv1_power_normal;
varying vec3 uv1_triplanar_pos;

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

group_uniforms top_maps;
uniform sampler2D top : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D top_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float top_roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D top_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float top_normal_scale : hint_range(-16.0, 16.0) = 0.5;

group_uniforms side_maps;
uniform sampler2D side : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D side_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float side_roughness_scale : hint_range(0.0, 2.0) = 1.0;
uniform sampler2D side_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform float side_normal_scale : hint_range(-16.0, 16.0) = 1.0;



void vertex() {
	vec3 normal = NORMAL;

	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = normalize(TANGENT);

	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = normalize(BINORMAL);

	// UV1 Triplanar: Enabled
	uv1_power_normal = pow(abs(NORMAL), vec3(uv1_blend_sharpness));
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	
	uv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset;
	uv1_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D t_side, sampler2D t_top, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(t_side, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(t_top, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(t_side, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

float triplanar_depth(float side_depth, float top_depth, vec3 p_weights) {
	float max_weight = max(max(p_weights.x, p_weights.y), p_weights.z);
	float depth = side_depth * (p_weights.x + p_weights.z) + top_depth * p_weights.y;
	return depth;
}

void fragment() {
	vec4 albedo_tex = triplanar_texture(side, top, uv1_power_normal, uv1_triplanar_pos);

	// Albedo Texture Force sRGB: Enabled
	albedo_tex.rgb = mix(
			pow((albedo_tex.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
			albedo_tex.rgb.rgb * (1.0 / 12.92),
			lessThan(albedo_tex.rgb, vec3(0.04045)));
			
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	
	METALLIC = metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(triplanar_texture(side_roughness, top_roughness, uv1_power_normal, uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * triplanar_depth(side_roughness_scale, top_roughness_scale, uv1_power_normal);

	// Normal Map: Enabled
	NORMAL_MAP = triplanar_texture(side_normal, top_normal, uv1_power_normal, uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = triplanar_depth(side_normal_scale, top_normal_scale, uv1_power_normal);
}
