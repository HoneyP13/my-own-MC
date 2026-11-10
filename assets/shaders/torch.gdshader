shader_type spatial;
render_mode cull_disabled;

// Torches, that's the plan

// Positive values pull the vertices inward along their normals (it shrinks the mesh).
uniform float side_shrink: hint_range(0.0, 2.0) = 0.438;
uniform float top_shrink: hint_range(0.0, 2.0) = 0.438;
uniform sampler2D top_texture: source_color, repeat_enable, filter_nearest;
uniform sampler2D side_texture: source_color, repeat_enable, filter_nearest;
uniform sampler2D bottom_texture: source_color, repeat_enable, filter_nearest;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	VERTEX.xz -= NORMAL.xz * side_shrink;
	VERTEX.y -= NORMAL.y * top_shrink;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	// Blend the X and Z projections by how much the quad faces each axis. The weights are
	// normalised to add up to 1. (The old version divided by 2 after weighting to a total of 3,
	// which made plants 1.5x too bright.)
	vec3 w = pow(abs(world_normal.xzy), vec3(8.0));
	w /= max(w.x + w.z + w.y, 0.00001);

	vec4 tex_x = texture(side_texture, 1.0 - world_pos.zy);
	vec4 tex_y = texture(top_texture, 1.0 - world_pos.zx);
	vec4 tex_z = texture(side_texture, 1.0 - world_pos.xy);
	vec4 c = tex_x * w.x + tex_y * w.z + tex_z * w.y;

	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
