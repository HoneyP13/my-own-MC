class_name BiomeTint
extends RefCounted
## Minecraft's grass, leaves and plants are drawn in grey and coloured in-game: the colour comes from
## grass.png / foliage.png, looked up by the biome's temperature and rainfall. This file is the
## "which temperature and rainfall is it HERE?" half; the shaders (tinted_cutout.gdshader and
## tinted_grass_block.gdshader) do the colormap lookup.
##
## How it works: we bake a small texture covering the whole world, one pixel per block column,
## red = temperature, green = rainfall (both 0..1), from the same noise your TerrainGenerator already
## uses for biomes. Every tint material gets that texture, and each block looks up its own pixel.
##
## Call BiomeTint.setup() once the generator exists (see world.gd). Do it again if you make a new generator.

static var _texture: ImageTexture
static var _origin := Vector2.ZERO
static var _size := Vector2.ONE


## Temperature and rainfall (both 0..1) for a block column.
## If your TerrainGenerator ever gets its own climate_at(x, z) -> Vector2 (say, when you add more biomes), that wins.
static func climate_at(gen: TerrainGenerator, x: int, z: int) -> Vector2:
	if gen.has_method("climate_at"):
		return gen.climate_at(x, z)
	var t: float = gen._temperature.get_noise_2d(x, z)    # -1..1, same noise biome_at() uses
	var m: float = gen._moisture.get_noise_2d(x, z)
	# Chosen so your biomes land on Minecraft's: typical plains (t~0, m~0) = plains green #91BD59,
	# forest = deeper green, below the snow line = cold grey-green, hot and dry = yellow desert grass.
	var temperature := clampf(0.8 + (t * 2.0 if t < 0.0 else t * 0.6), 0.0, 1.0)
	var rainfall := clampf(0.4 + m, 0.0, 1.0)
	return Vector2(temperature, rainfall)


## One pixel per block column, covering x and z from -half_world to +half_world.
static func build_image(gen: TerrainGenerator, half_world: int) -> Image:
	var width := half_world * 2
	var img := Image.create(width, width, false, Image.FORMAT_RG8)
	for px in width:
		for pz in width:
			var c := climate_at(gen, px - half_world, pz - half_world)
			img.set_pixel(px, pz, Color(c.x, c.y, 0.0))
	return img


## Build the climate texture and give it to every tint material found in these MeshLibraries.
## Returns how many materials were set up (0 means no material is using a tint shader yet).
static func setup(gen: TerrainGenerator, libraries: Array, half_world: int) -> int:
	_texture = ImageTexture.create_from_image(build_image(gen, half_world))
	_origin = Vector2(-half_world, -half_world)
	_size = Vector2(half_world * 2, half_world * 2)
	var done := {}
	for lib: MeshLibrary in libraries:
		for id in lib.get_item_list():
			var mesh := lib.get_item_mesh(id)
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as ShaderMaterial
				if mat != null and not done.has(mat) and apply(mat):
					done[mat] = true
	if done.is_empty():
		push_warning("BiomeTint: no material uses a tint shader yet (tinted_cutout / tinted_grass_block), so nothing is being tinted.")
	return done.size()


## Give one material the climate texture. Does nothing (returns false) if its shader isn't a tint shader.
## Handy for materials made later, like on a mob or a dropped item.
static func apply(mat: ShaderMaterial) -> bool:
	if _texture == null or mat.shader == null:
		return false
	var uses_it := false
	for u: Dictionary in mat.shader.get_shader_uniform_list():
		if u["name"] == "climate_map":
			uses_it = true
	if not uses_it:
		return false
	mat.set_shader_parameter("climate_map", _texture)
	mat.set_shader_parameter("climate_origin", _origin)
	mat.set_shader_parameter("climate_size", _size)
	return true
