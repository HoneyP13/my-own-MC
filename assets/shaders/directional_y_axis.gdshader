shader_type spatial;
render_mode cull_back, vertex_lighting;

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_side: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_front: source_color, repeat_enable, filter_nearest; // local +Z
uniform vec3 corner_offset = vec3(0.5);

varying vec3 block_pos;
varying vec3 block_normal;

void vertex() {
	block_pos = VERTEX + corner_offset;
	block_normal = NORMAL;
}

void fragment() {
	vec3 a = abs(block_normal);
	vec3 albedo;
	if (a.y > a.x && a.y > a.z) {
		albedo = texture(texture_top, 1.0 - block_pos.xz).rgb;
	} else if (a.x > a.z) {
		albedo = texture(texture_side, 1.0 - block_pos.zy).rgb;
	} else if (block_normal.z > 0.0) {
		albedo = texture(texture_front, vec2(block_pos.x, 1.0 - block_pos.y)).rgb;
	} else {
		albedo = texture(texture_side, 1.0 - block_pos.xy).rgb;
	}
	ALBEDO = albedo;
}