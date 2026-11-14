class_name TerrainGenerator
extends RefCounted
## Deterministic, noise-based terrain. Same seed -> same world.
##
## Everything is a pure function of (x, y, z) and the seed, so block_at() can answer "what would
## natural terrain be here?" for ANY cell at ANY time. That's what lets us leave buried blocks out
## of the GridMap (they'd never be seen) and put them back when the player digs next to them.
##
## Step 1 of the plan: this writes into your existing GridMaps, one 16x16 column-chunk at a time.
## In step 2 the same height_at() / block_at() will feed chunk meshes instead of a GridMap.

const CHUNK_SIZE := 16
const MAX_HEIGHT := 64
const TREE_RADIUS := 2   # leaves reach this far from the trunk

var world_seed: int
var sea_level: int

var _continent := FastNoiseLite.new()   # big hills and valleys
var _detail := FastNoiseLite.new()      # small bumps
var _height_cache := {}                 # Vector2i -> int (cleared when we move to streaming chunks)
var _item_ids := {}                     # block name -> MeshLibrary item id

const BIOME_FREQ := 0.02   # your world is only 96x96, so this is fairly small. Lower it when you add streaming.
var _temperature := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _biome_cache := {}   # Vector2i -> StringName

func _init(p_seed: int = 0, p_sea_level: int = 10) -> void:
	world_seed = p_seed
	sea_level = p_sea_level
	_continent.seed = p_seed
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent.frequency = 0.012
	_detail.seed = p_seed + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.06
	_temperature.seed = p_seed + 2
	_temperature.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_temperature.frequency = BIOME_FREQ
	_moisture.seed = p_seed + 3
	_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture.frequency = BIOME_FREQ


func biome_at(x: int, z: int) -> StringName:
	var key := Vector2i(x, z)
	if _biome_cache.has(key): return _biome_cache[key]
	var t := _temperature.get_noise_2d(x, z)
	var m := _moisture.get_noise_2d(x, z)
	var b := &"plains"
	if t < -0.2: b = &"snowy"
	elif t > 0.2 and m < 0.15: b = &"desert"
	elif m > 0.2: b = &"forest"
	_biome_cache[key] = b
	return b


## Cheap integer hash -> 0..2^31. Used for ores, plants and trees so they're repeatable.
func _hash(x: int, y: int, z: int, salt: int) -> int:
	var h := x * 374761393 + y * 668265263 + z * 1013904223 + (salt + world_seed) * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## Height of the top solid block in column (x, z).
func height_at(x: int, z: int) -> int:
	var key := Vector2i(x, z)
	if _height_cache.has(key):
		return _height_cache[key]
	var n := _continent.get_noise_2d(x, z) * 14.0 + _detail.get_noise_2d(x, z) * 3.0
	var h := clampi(sea_level + 3 + roundi(n), 2, MAX_HEIGHT - 12)
	_height_cache[key] = h
	return h


## Natural terrain at a cell: a block name, or &"" for air. Does NOT include trees or plants.
func block_at(x: int, y: int, z: int) -> StringName:
	if y < 0:
		return &""
	if y == 0:
		return &"bedrock"
	var h := height_at(x, z)
	if y > h:
		return &""
	var biome := biome_at(x, z)
	var sandy := h <= sea_level + 1 or biome == &"desert"
	if y == h:
		if h < sea_level:   # lake bed
			var r := _hash(x, 0, z, 41) % 100
			if r < 12: return &"clay_block"
			if r < 24: return &"gravel"
			return &"sand"
		if sandy: return &"sand"
		return &"snow_block" if biome == &"snowy" else &"grass_block"
	if y > h - 4:
		return &"sand" if sandy else &"dirt"
	const ORES := [   # block, max_y, chance per 1000, hash salt, min surface height above sea level
		[&"diamond_ore",       6,  4, 21, -99],
		[&"emerald_ore",      24,  5, 23,   8],
		[&"ruby_ore",          9,  4, 29, -99],
		[&"gold_ore",         10,  8, 19, -99],
		[&"lapis_lazuli_ore", 14, 10, 31, -99],
		[&"redstone_ore",     10, 16, 37, -99],
		[&"iron_ore",         18, 18, 17, -99],
		[&"coal_ore",         40, 25,  7, -99],
	]
	for o in ORES:
		if y <= o[1] and h - sea_level >= o[4] and _hash(x >> 1, y >> 1, z >> 1, o[3]) % 1000 < o[2] and _hash(x, y, z, o[3] + 100) % 100 < 70:
			return o[0]
	return &"stone"


func has_tree(x: int, z: int) -> bool:
	if height_at(x, z) <= sea_level + 1: return false
	var odds := 70
	match biome_at(x, z):
		&"desert": return false
		&"forest": odds = 22
		&"snowy": odds = 120
	return _hash(x, 0, z, 11) % odds == 0

func tree_trunk_height(x: int, z: int) -> int:
	return 4 + _hash(x, 0, z, 13) % 2


func _tree_logs(x: int, z: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var base := height_at(x, z) + 1
	for i in tree_trunk_height(x, z):
		out.append(Vector3i(x, base + i, z))
	return out


func _tree_leaves(x: int, z: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var t := tree_trunk_height(x, z)
	var base := height_at(x, z) + 1
	for dy in range(t - 2, t + 2):
		var r := 2 if dy < t else 1
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if dy < t and absi(dx) == 2 and absi(dz) == 2: continue    # rounded corners
				if dy == t + 1 and absi(dx) + absi(dz) > 1: continue       # plus-shaped tip
				out.append(Vector3i(x + dx, base + dy, z + dz))
	return out


## Writes one chunk (a CHUNK_SIZE x CHUNK_SIZE column, chunk.y is the Z index) into the GridMaps.
## Buried cells are skipped: a cell is only placed if at least one neighbour is air.
func generate_chunk(chunk: Vector2i, terrain: GridMap, fluids: GridMap) -> void:
	var water_id := GridMap.INVALID_CELL_ITEM
	if fluids.mesh_library != null:
		water_id = fluids.mesh_library.find_item_by_name("water")

	var x0 := chunk.x * CHUNK_SIZE
	var z0 := chunk.y * CHUNK_SIZE

	for x in range(x0, x0 + CHUNK_SIZE):
		for z in range(z0, z0 + CHUNK_SIZE):
			var h := height_at(x, z)

			# A cell at height y has air beside it only if y is above the lowest neighbouring column,
			# and the top cell always has air above it. Everything below that is buried.
			var lowest := mini(
				mini(height_at(x - 1, z), height_at(x + 1, z)),
				mini(height_at(x, z - 1), height_at(x, z + 1)))
			for y in range(mini(lowest + 1, h), h + 1):
				_place(terrain, Vector3i(x, y, z), block_at(x, y, z))

			# Water fills lakes up to sea level.
			var surface_id := fluids.mesh_library.find_item_by_name("water_surface")
			for y in range(h + 1, sea_level + 1):
				fluids.set_cell_item(Vector3i(x, y, z), surface_id if y == sea_level else water_id)
			if h < sea_level and biome_at(x, z) == &"snowy":
				_place(terrain, Vector3i(x, sea_level, z), &"ice_block")
			if h > sea_level + 1:
				_decorate(terrain, x, z, h, biome_at(x, z))
				# Trees. Look a little outside the chunk so trees on the border aren't cut in half; each chunk
				# only writes the cells that are inside it, so neighbouring chunks agree with each other.
				var trees: Array[Vector2i] = []
				for tx in range(x0 - TREE_RADIUS, x0 + CHUNK_SIZE + TREE_RADIUS):
					for tz in range(z0 - TREE_RADIUS, z0 + CHUNK_SIZE + TREE_RADIUS):
						if has_tree(tx, tz):
							trees.append(Vector2i(tx, tz))

				var tree_blocks := {}   # Vector3i -> StringName
				for t in trees:
					for c in _tree_leaves(t.x, t.y):
						tree_blocks[c] = &"leaves"
				for t in trees:
					for c in _tree_logs(t.x, t.y):
						tree_blocks[c] = &"log"     # logs overwrite leaves

				for c: Vector3i in tree_blocks:
					if c.x < x0 or c.x >= x0 + CHUNK_SIZE or c.z < z0 or c.z >= z0 + CHUNK_SIZE: continue
					if block_at(c.x, c.y, c.z) != &"": continue    # never overwrite terrain
					_place(terrain, c, tree_blocks[c])


## A dry, tree-free column near the origin to spawn on.
func find_spawn() -> Vector3:
	for r in 64:
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				if maxi(absi(x), absi(z)) != r: continue
				var h := height_at(x, z)
				if h > sea_level + 1 and not has_tree(x, z):
					return Vector3(x + 0.5, h + 2.5, z + 0.5)
	return Vector3(0.5, MAX_HEIGHT, 0.5)

func _decorate(terrain: GridMap, x: int, z: int, h: int, biome: StringName) -> void:
	var above := Vector3i(x, h + 1, z)
	var r := _hash(x, 1, z, 17) % 100
	match biome:
		&"plains", &"forest":
			if r < 1: _place(terrain, above, &"blue_flower")
			elif r < 8: _place(terrain, above, &"short_grass")
			elif r < 10: _place(terrain, above, &"red_flower")
			elif _hash(x, 4, z, 53) % 300 == 0: _place(terrain, above, &"pumpkin")
		&"desert":
			if _hash(x, 2, z, 43) % 70 == 0:
				for i in 1 + _hash(x, 3, z, 47) % 3:
					_place(terrain, above + Vector3i(0, i, 0), &"cactus")



func _place(terrain: GridMap, cell: Vector3i, block_name: StringName) -> void:
	if block_name == &"":
		return
	if not _item_ids.has(block_name):
		_item_ids[block_name] = terrain.mesh_library.find_item_by_name(String(block_name))
	var id: int = _item_ids[block_name]
	if id != GridMap.INVALID_CELL_ITEM:
		terrain.set_cell_item(cell, id)
