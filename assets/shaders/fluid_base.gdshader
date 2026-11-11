shader_type spatial;
render_mode vertex_lighting, cull_disabled;

uniform float transparency: hint_range(0.0, 1.0) = 0.0;
uniform bool emissive = false;
uniform sampler2D albedo_texture: source_color, repeat_enable, filter_nearest;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
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
	EMISSION.rgb = emissive ? c.rgb: vec3(0);
	ALPHA -= emissive ? 0.0: transparency;
}
