shader_type spatial;
render_mode cull_back, vertex_lighting;

// A different texture for each of the six faces (furnace, etc.).

uniform sampler2D texture_north: source_color, repeat_enable, filter_nearest; // +X face
uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_west: source_color, repeat_enable, filter_nearest;  // +Z face
uniform sampler2D texture_south: source_color, repeat_enable, filter_nearest; // -X face
uniform sampler2D texture_bottom: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_east: source_color, repeat_enable, filter_nearest;  // -Z face

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 n = world_normal;
	vec3 a = abs(n);
	vec3 albedo;
	if (a.x >= a.y && a.x >= a.z) {
		vec2 uv = 1.0 - world_pos.zy;
		albedo = (n.x > 0.0) ? texture(texture_north, uv).rgb : texture(texture_south, uv).rgb;
	} else if (a.y >= a.z) {
		vec2 uv = 1.0 - world_pos.xz;
		albedo = (n.y > 0.0) ? texture(texture_top, uv).rgb : texture(texture_bottom, uv).rgb;
	} else {
		vec2 uv = 1.0 - world_pos.xy;
		albedo = (n.z > 0.0) ? texture(texture_west, uv).rgb : texture(texture_east, uv).rgb;
	}
	ALBEDO = albedo;
}
