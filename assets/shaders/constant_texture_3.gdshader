shader_type spatial;
render_mode depth_draw_always, vertex_lighting;

// Top / side / bottom textures (grass block, etc.).

uniform sampler2D texture_top: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_side: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_bottom: source_color, repeat_enable, filter_nearest;
uniform float grow_amount: hint_range(0.0, 2.0) = 0.0;
uniform bool enable_aplha = false;
instance uniform float as_item = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	VERTEX.xz -= NORMAL.xz * grow_amount;
	world_pos = as_item > 0.5 ? VERTEX + vec3(0.5) : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = as_item > 0.5 ? NORMAL : normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 a = abs(world_normal);
	vec3 albedo;
	float alpha;
	if (a.y > a.x && a.y > a.z) {
		vec2 uv = 1.0 - world_pos.xz;
		albedo = (world_normal.y > 0.0) ? texture(texture_top, uv).rgb : texture(texture_bottom, uv).rgb;
		alpha = (enable_aplha) ? (world_normal.y > 0.0) ? texture(texture_top, uv).a : texture(texture_bottom, uv).a: 0.0;
	} else if (a.x >= a.z) {
		vec2 uv = 1.0 - world_pos.zy;
		vec2 uv2 = vec2(world_pos.z, 1.0 - world_pos.y);
		albedo = (world_normal.x > 0.0) ? texture(texture_side, uv).rgb: texture(texture_side, uv2).rgb;
		alpha = (enable_aplha) ? (world_normal.x > 0.0) ? texture(texture_side, uv).a: texture(texture_side, uv2).a: 0.0;
	} else {
		vec2 uv = 1.0 - world_pos.xy;
		vec2 uv2 = vec2(world_pos.x, 1.0 - world_pos.y);
		albedo = (world_normal.z > 0.0) ? texture(texture_side, uv2).rgb: texture(texture_side, uv).rgb;
		alpha = (enable_aplha) ? (world_normal.z > 0.0) ? texture(texture_side, uv2).a: texture(texture_side, uv).a: 0.0;
	}
	ALBEDO = albedo;
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = (enable_aplha) ? 0.5: 0.0;
}
