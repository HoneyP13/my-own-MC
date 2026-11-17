shader_type spatial;
// The grass block: top and the green fringe on the sides are tinted by biome, the dirt is not.
//
// Material setup:
//   top_tex           grass_block_top.png (grey)
//   side_tex          grass_block_side.png
//   side_overlay_tex  grass_block_side_overlay.png (the grey fringe, see-through elsewhere). Best option.
//                     No overlay? Untick use_side_overlay and the fringe is found by its green colour.
//   bottom_tex        dirt.png
//   colormap          grass.png
//   leave climate_map / climate_origin / climate_size alone: BiomeTint fills them in at runtime
// Assumes each face of your block mesh has UVs covering 0..1 (the way a BoxMesh does).

uniform sampler2D top_tex : filter_nearest, repeat_disable;
uniform sampler2D side_tex : filter_nearest, repeat_disable;
uniform sampler2D side_overlay_tex : filter_nearest, repeat_disable, hint_default_transparent;
uniform sampler2D bottom_tex : filter_nearest, repeat_disable;
uniform bool use_side_overlay = true;
uniform sampler2D colormap : filter_linear, repeat_disable;

uniform sampler2D climate_map : filter_linear, repeat_disable, hint_default_white;
uniform vec2 climate_origin = vec2(-48.0, -48.0);
uniform vec2 climate_size = vec2(96.0, 96.0);

varying vec3 tint;
varying vec3 model_normal;

vec3 bt_srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(c, vec3(0.04045)));
}

void vertex() {
	model_normal = NORMAL;
	vec2 climate = textureLod(climate_map, (MODEL_MATRIX[3].xz - climate_origin) / climate_size, 0.0).rg;
	float temperature = clamp(climate.x, 0.0, 1.0);
	float rainfall = clamp(climate.y, 0.0, 1.0) * temperature;
	vec2 cm_uv = (vec2(1.0 - temperature, 1.0 - rainfall) * 255.0 + 0.5) / 256.0;
	tint = textureLod(colormap, cm_uv, 0.0).rgb;
}

void fragment() {
	vec3 col;
	if (model_normal.y > 0.5) {
		col = texture(top_tex, UV).rgb * tint;
	} else if (model_normal.y < -0.5) {
		col = texture(bottom_tex, UV).rgb;
	} else {
		vec4 side = texture(side_tex, UV);
		float fringe;
		vec3 fringe_grey;
		if (use_side_overlay) {
			vec4 ov = texture(side_overlay_tex, UV);
			fringe = ov.a;
			fringe_grey = ov.rgb;
		} else {
			fringe = step(max(side.r, side.b) + 0.02, side.g);   // green pixels = the grass fringe
			fringe_grey = vec3(dot(side.rgb, vec3(0.299, 0.587, 0.114)));
		}
		col = mix(side.rgb, fringe_grey * tint, fringe);
	}
	ALBEDO = bt_srgb_to_linear(col);
	ROUGHNESS = 1.0;
}
