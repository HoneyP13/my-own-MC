shader_type spatial;
render_mode vertex_lighting, cull_disabled;

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_north: source_color, repeat_enable, filter_nearest; // +X face
uniform sampler2D texture_bottom: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_west: source_color, repeat_enable, filter_nearest;  // +Z face
uniform sampler2D texture_east: source_color, repeat_enable, filter_nearest;  // -Z face
uniform sampler2D texture_south: source_color, repeat_enable, filter_nearest; // -X face

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
	vec4 c;
	if (a.x >= a.y && a.x >= a.z) {
		vec2 uv = 1.0 - block_pos.zy;
		c = texture(texture_north, uv);
	} else if (n.x > 0.0) {
		vec2 uv = 1.0 - block_pos.zy;
		c = texture(texture_south, uv);
	} else if (a.y >= a.z) {
		vec2 uv = 1.0 - block_pos.xz;
		c = (n.y > 0.0) ? texture(texture_top, uv) : texture(texture_bottom, uv);
	} else {
		vec2 uv = 1.0 - block_pos.xy;
		c = (n.z > 0.0) ? texture(texture_west, uv) : texture(texture_east, uv);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
