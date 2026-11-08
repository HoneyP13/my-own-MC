shader_type spatial;
render_mode cull_back, depth_draw_always, vertex_lighting;

// Top / side / bottom textures (grass block, etc.).

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_side: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_bottom: source_color, repeat_enable, filter_nearest;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 a = abs(world_normal);
	vec3 albedo;
	if (a.y > a.x && a.y > a.z) {
		vec2 uv = 1.0 - world_pos.xz;
		albedo = (world_normal.y > 0.0) ? texture(texture_top, uv).rgb : texture(texture_bottom, uv).rgb;
	} else if (a.x >= a.z) {
		albedo = texture(texture_side, 1.0 - world_pos.zy).rgb;
	} else {
		albedo = texture(texture_side, 1.0 - world_pos.xy).rgb;
	}
	ALBEDO = albedo;
}
