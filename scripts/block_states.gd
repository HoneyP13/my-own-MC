class_name BlockStates
extends Node
## Per-cell block state for the GridMap world.
##
## A GridMap cell only remembers (item id, orientation). Anything more, like "this furnace is lit",
## "this is the head half of a bed" or "this fence connects north", lives here, in `data`:
##
##     data[Vector3i cell] = { "lit": true }                              # furnace
##     data[Vector3i cell] = { "block": &"bed", "part": &"head",          # one half of a bed
##                             "origin": Vector3i(...), "turns": 1 }
##
## States change what a cell LOOKS like in two ways:
##   1. Variant meshes: the cell's item is swapped for another mesh in the same library
##      ("furnace" <-> "furnace_lit"). The swap is stored in the GridMap itself, so it saves for free.
##   2. Overlays: extra nodes drawn on top (fence arms), rebuilt after loading.
## BlockRules decides which mesh a state maps to; this file just applies it.

var world: Node3D      # world.gd
var grid: GridMap
var data := {}         # Vector3i -> Dictionary
var _overlays := {}    # Vector3i -> Node3D

const SIDES: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.BACK, Vector3i.FORWARD]


func setup(p_world: Node3D) -> void:
	world = p_world
	grid = p_world.grid_map


# --- Reading and writing state -----------------------------------------------

func get_state(cell: Vector3i) -> Dictionary:
	return data.get(cell, {})


func set_state(cell: Vector3i, key: StringName, value: Variant) -> void:
	var s: Dictionary = data.get(cell, {})
	if s.has(key) and s[key] == value:
		return
	s[key] = value
	data[cell] = s
	refresh(cell)


func erase(cell: Vector3i) -> void:
	data.erase(cell)
	_remove_overlay(cell)


func clear() -> void:
	data.clear()
	for n: Node in _overlays.values():
		n.queue_free()
	_overlays.clear()


## For saving. Vector3i / StringName / bool all survive FileAccess.store_var().
func pack() -> Dictionary:
	return data.duplicate(true)


func unpack(saved: Dictionary) -> void:
	clear()
	data = saved.duplicate(true)
	rebuild_overlays()


# --- Turning state into visuals -----------------------------------------------

## Re-pick the mesh and overlays for one cell. Call it after anything that could change how the
## cell looks: its own state, or a neighbour being placed or broken (fences care about that).
func refresh(cell: Vector3i) -> void:
	var item := grid.get_cell_item(cell)
	if item == GridMap.INVALID_CELL_ITEM:
		_remove_overlay(cell)
		return
	var block: BlockDef = world._block_for_item(item)
	if block == null:
		_remove_overlay(cell)
		return

	var want := BlockRules.mesh_for(block.id, block.mesh_name, get_state(cell))
	var want_item := grid.mesh_library.find_item_by_name(want)
	if want_item != GridMap.INVALID_CELL_ITEM and want_item != item:
		grid.set_cell_item(cell, want_item, grid.get_cell_item_orientation(cell))

	if block.id == &"fence":
		_update_fence(cell)
	else:
		_remove_overlay(cell)


func refresh_neighbors(cell: Vector3i) -> void:
	for n: Vector3i in world.NEIGHBORS:
		refresh(cell + n)


## Fence arms are overlays, so after loading a save they have to be rebuilt.
func rebuild_overlays() -> void:
	var fence: BlockDef = Registry.get_block(&"fence")
	if fence == null:
		return
	var id := grid.mesh_library.find_item_by_name(fence.mesh_name)
	if id == GridMap.INVALID_CELL_ITEM:
		return
	for cell: Vector3i in grid.get_used_cells_by_item(id):
		refresh(cell)


# --- Multi-cell blocks -----------------------------------------------------------

func can_place_multi(block_id: StringName, origin: Vector3i, turns: int) -> bool:
	for part: StringName in BlockRules.parts(block_id):
		var c := origin + BlockRules.part_offset(block_id, part, turns)
		if c.y < world.MIN_BUILD_HEIGHT or c.y > world.MAX_BUILD_HEIGHT:
			return false
		if grid.get_cell_item(c) != GridMap.INVALID_CELL_ITEM or world.is_solid_at(c):
			return false
		if world._cell_overlaps_player(c):
			return false
	return true


func place_multi(block_id: StringName, origin: Vector3i, turns: int) -> void:
	# Where the parts go follows `turns`; how the meshes face also includes the block's own mesh_turns.
	var mesh_turns := turns + BlockRules.mesh_turns(block_id)
	var orientation := grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, mesh_turns * PI / 2.0))
	var placed: Array[Vector3i] = []
	for part: StringName in BlockRules.parts(block_id):
		var c := origin + BlockRules.part_offset(block_id, part, turns)
		var item := grid.mesh_library.find_item_by_name(BlockRules.part_mesh(block_id, part))
		if item == GridMap.INVALID_CELL_ITEM:
			push_warning("BlockStates: no mesh for %s/%s" % [block_id, part])
			continue
		grid.set_cell_item(c, item, orientation)
		data[c] = {"block": block_id, "part": part, "origin": origin, "turns": turns}
		placed.append(c)
	for c in placed:
		refresh_neighbors(c)


## Every cell that belongs to the same block as `cell` (just [cell] for ordinary blocks).
func cells_of(cell: Vector3i) -> Array[Vector3i]:
	var s := get_state(cell)
	var out: Array[Vector3i] = [cell]
	if not s.has("origin"):
		return out
	var block_id: StringName = s["block"]
	for part: StringName in BlockRules.parts(block_id):
		var c: Vector3i = s["origin"] + BlockRules.part_offset(block_id, part, s["turns"])
		if c != cell:
			out.append(c)
	return out


# --- Fences ------------------------------------------------------------------------

func _connects(cell: Vector3i) -> bool:
	var item := grid.get_cell_item(cell)
	if item == GridMap.INVALID_CELL_ITEM:
		return false
	var b: BlockDef = world._block_for_item(item)
	return b != null and BlockRules.fence_connects(b.id, world.NEEDS_SUPPORT)


func _update_fence(cell: Vector3i) -> void:
	var mask := 0
	for i in SIDES.size():
		if _connects(cell + SIDES[i]):
			mask |= 1 << i
	var existing: Node3D = _overlays.get(cell)
	if existing != null and existing.get_meta("mask", -1) == mask:
		return
	_remove_overlay(cell)
	if mask == 0:
		return

	var root := Node3D.new()
	root.set_meta("mask", mask)
	add_child(root)
	root.global_position = grid.to_global(grid.map_to_local(cell))
	var mat := _fence_material(cell)
	for i in SIDES.size():
		if mask & (1 << i) == 0:
			continue
		var dir := Vector3(SIDES[i])
		for y in [-0.03, 0.34]:    # the two rails
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(
				0.375 if dir.x != 0.0 else 0.1,
				0.19,
				0.375 if dir.z != 0.0 else 0.1)
			box.material = mat
			bar.mesh = box
			bar.position = dir * 0.3125 + Vector3(0, y, 0)
			root.add_child(bar)
	_overlays[cell] = root


## The arms borrow the fence post's own material, so they match whatever texture you gave it.
func _fence_material(cell: Vector3i) -> Material:
	var mesh := grid.mesh_library.get_item_mesh(grid.get_cell_item(cell))
	if mesh != null and mesh.get_surface_count() > 0:
		var m := mesh.surface_get_material(0)
		if m != null:
			return m
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.55, 0.4, 0.22)
	return fallback


func _remove_overlay(cell: Vector3i) -> void:
	var n: Node = _overlays.get(cell)
	if n != null:
		n.queue_free()
		_overlays.erase(cell)
