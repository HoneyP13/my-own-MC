shader_type spatial;
render_mode cull_disabled;

// Cube-shaped blocks with cut-out transparency (leaves, glass, ...).

// Positive values pull the vertices inward along their normals (it shrinks the mesh).
uniform float grow_amount: hint_range(0.0, 2.0) = 0.0;
uniform sampler2D albedo_texture: source_color, repeat_enable, filter_nearest;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	VERTEX -= NORMAL * grow_amount;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 a = abs(world_normal);
	vec2 uv = (a.x >= a.y && a.x >= a.z) ? 1.0 - world_pos.zy
			: (a.y >= a.z)               ? 1.0 - world_pos.xz
			:                              1.0 - world_pos.xy;
	vec4 c = texture(albedo_texture, uv); // one lookup gives both colour and alpha

	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
