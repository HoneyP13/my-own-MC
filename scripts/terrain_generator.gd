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


func _init(p_seed: int = 0, p_sea_level: int = 10) -> void:
	world_seed = p_seed
	sea_level = p_sea_level
	_continent.seed = p_seed
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent.frequency = 0.012
	_detail.seed = p_seed + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.06


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
	var beach := h <= sea_level + 1
	if y == h:
		return &"sand" if beach else &"grass_block"
	if y > h - 4:
		return &"sand" if beach else &"dirt"
	if _hash(x, y, z, 7) % 100 < 2:
		return &"coal_ore"
	return &"stone"


func has_tree(x: int, z: int) -> bool:
	return height_at(x, z) > sea_level + 1 and _hash(x, 0, z, 11) % 70 == 0


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
				
			# Grass tufts and flowers
			if h > sea_level + 1:
				var r := _hash(x, 1, z, 17) % 100
				if r < 1:
					_place(terrain, Vector3i(x, h + 1, z), &"blue_flower")
				elif r < 8:
					_place(terrain, Vector3i(x, h + 1, z), &"short_grass")
				elif r < 10:
					_place(terrain, Vector3i(x, h + 1, z), &"red_flower")

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


func _place(terrain: GridMap, cell: Vector3i, block_name: StringName) -> void:
	if block_name == &"":
		return
	if not _item_ids.has(block_name):
		_item_ids[block_name] = terrain.mesh_library.find_item_by_name(String(block_name))
	var id: int = _item_ids[block_name]
	if id != GridMap.INVALID_CELL_ITEM:
		terrain.set_cell_item(cell, id)
