shader_type spatial;
render_mode cull_disabled;   // plants and leaves are seen from both sides
// For anything Minecraft draws in grey and tints by biome and that has see-through pixels:
// leaves, short grass, tall grass, ferns, vines, leaf litter...
//
// Material setup:
//   albedo_tex  the grey texture (oak_leaves.png, short_grass.png ...)
//   colormap    foliage.png for leaves, grass.png for grass and ferns, dry_foliage.png for leaf litter
//   leave climate_map / climate_origin / climate_size alone: BiomeTint fills them in at runtime
// Spruce and birch leaves have a fixed colour in Minecraft instead of a biome one: tick use_fixed_tint
// and set fixed_tint to  spruce = (0.380, 0.600, 0.380)   birch = (0.502, 0.655, 0.333)
// (that's #619961 and #80A755 divided by 255; plain sRGB numbers, no colour picker on purpose).

uniform sampler2D albedo_tex : filter_nearest, repeat_disable;   // deliberately NOT source_color, see fragment()
uniform sampler2D colormap : filter_linear, repeat_disable;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
uniform bool use_fixed_tint = false;
uniform vec3 fixed_tint = vec3(0.380, 0.600, 0.380);   // spruce by default

uniform sampler2D climate_map : filter_linear, repeat_disable, hint_default_white;
uniform vec2 climate_origin = vec2(-48.0, -48.0);
uniform vec2 climate_size = vec2(96.0, 96.0);

varying vec3 tint;   // the biome colour, in sRGB, the same for every face of a block

vec3 bt_srgb_to_linear(vec3 c) {
	vec3 lo = c / 12.92;
	vec3 hi = pow((c + 0.055) / 1.055, vec3(2.4));
	return mix(hi, lo, step(c, vec3(0.04045)));
}

void vertex() {
	// MODEL_MATRIX[3] is where this block sits in the world, so we colour per block, not per pixel.
	vec2 climate = textureLod(climate_map, (MODEL_MATRIX[3].xz - climate_origin) / climate_size, 0.0).rg;
	float temperature = clamp(climate.x, 0.0, 1.0);
	float rainfall = clamp(climate.y, 0.0, 1.0) * temperature;   // Minecraft's own rule
	// grass.png / foliage.png: x = 1 - temperature, y = 1 - rainfall. The 255 and 0.5 keep us on pixel centres.
	vec2 cm_uv = (vec2(1.0 - temperature, 1.0 - rainfall) * 255.0 + 0.5) / 256.0;
	tint = use_fixed_tint ? fixed_tint : textureLod(colormap, cm_uv, 0.0).rgb;
}

void fragment() {
	// Minecraft multiplies texture * tint on the raw 0..255 values, in sRGB. We do the same (that's why
	// the textures are read without source_color) and convert once at the end, so the colours match.
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = bt_srgb_to_linear(tex.rgb * tint);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 1.0;
}
