shader_type spatial;
render_mode vertex_lighting, cull_disabled;

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_north: source_color, repeat_enable, filter_nearest; // +X face
uniform sampler2D texture_bottom: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_west: source_color, repeat_enable, filter_nearest;  // +Z face
uniform sampler2D texture_east: source_color, repeat_enable, filter_nearest;  // -Z face
uniform sampler2D texture_south: source_color, repeat_enable, filter_nearest; // -X face
uniform int faces: hint_enum("One", "Two", "Three");
uniform bool is_transparent;

uniform vec3 corner_offset = vec3(0.5);

varying vec3 block_pos;
varying vec3 block_normal;

void vertex() {
	block_pos = VERTEX + corner_offset;
	block_normal = NORMAL;
}

void fragment() {
	vec3 n = block_normal;
	vec3 a = abs(n);
	vec3 albedo;
	//v tex;
	//if (faces == 0) {
		//tex = texture_top
	//}
	if (a.x >= a.y && a.x >= a.z) {
		vec2 uv = 1.0 - block_pos.zy;
		albedo = (n.x > 0.0) ? texture(texture_north, uv).rgb : texture(texture_south, uv).rgb;
	} else if (a.y >= a.z) {
		vec2 uv = 1.0 - block_pos.xz;
		albedo = (n.y > 0.0) ? texture(texture_top, uv).rgb : texture(texture_bottom, uv).rgb;
	} else {
		vec2 uv = 1.0 - block_pos.xy;
		albedo = (n.z > 0.0) ? texture(texture_west, uv).rgb : texture(texture_east, uv).rgb;
	}
	ALBEDO = albedo;
	ALPHA_SCISSOR_THRESHOLD = is_transparent ? 0.5 : 0.0;
}
