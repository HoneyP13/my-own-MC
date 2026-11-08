shader_type spatial;
render_mode cull_back, vertex_lighting;

// One texture on every face of the block.

uniform sampler2D texture_2d: source_color, repeat_enable, filter_nearest;

// World-space position and face normal, worked out once per vertex instead of once per pixel.
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	// Block faces point exactly along one world axis, so just project the texture from that axis.
	// (One texture lookup per pixel instead of three blended ones.)
	vec3 a = abs(world_normal);
	vec2 uv = (a.x >= a.y && a.x >= a.z) ? 1.0 - world_pos.zy
			: (a.y >= a.z)               ? 1.0 - world_pos.xz
			:                              1.0 - world_pos.xy;
	ALBEDO = texture(texture_2d, uv).rgb;
}
