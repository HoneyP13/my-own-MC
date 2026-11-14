shader_type spatial;
render_mode vertex_lighting;

uniform sampler2D albedo_texture: source_color, repeat_enable, filter_nearest;

uniform bool is_transparent;

varying vec3 block_pos;
varying vec3 block_normal;

void vertex() {
	block_pos = VERTEX;
	block_normal = NORMAL;
}

void fragment() {
	vec3 n = block_normal;
	vec3 a = abs(n);
	vec3 albedo;
	texture(albedo_texture, block_pos.yx).rgb;
	ALBEDO = albedo;
	ALPHA_SCISSOR_THRESHOLD = is_transparent ? 0.5 : 0.0;
}
