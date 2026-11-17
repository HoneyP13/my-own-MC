class_name BlockRules
extends RefCounted
## Everything that describes HOW stateful and multi-cell blocks behave lives here, as plain data
## plus a few pure functions. When you add a block with states (a door, a double chest...), this
## is the one file you edit; BlockStates does the work.
##
## !! The mesh names below are what I ASSUMED your terrain MeshLibrary calls things. If yours
## differ, change them here. world.gd warns at startup about any name that isn't in the library.


## Variant meshes in the terrain MeshLibrary -> the id of the block they belong to.
## This is what lets world._block_for_item() turn a "furnace_lit" cell back into the furnace
## BlockDef, so breaking it, right-clicking it and pick-block all keep working.
const VARIANT_MESHES := {
	"furnace_lit": &"furnace",
	"bed_foot": &"bed",
	"bed_head": &"bed",
}

## Blocks made of several cells.
## "parts":  part name -> where that part sits relative to the origin cell, for a block facing -Z
##           (the way the player faces at yaw 0). BlockStates rotates it by the placement yaw.
## "meshes": part name -> mesh name of that part in the terrain MeshLibrary.
## A bed's head is one cell IN FRONT of the foot, so the foot is where you clicked and the head is
## the next cell away from you. Door: parts {bottom: (0,0,0), top: (0,1,0)}. Double chest: left/right.
## "mesh_turns": extra quarter-turns applied to the MESHES only (where the parts sit is unchanged).
## Your bed models are drawn with the head at +Z of the foot (the legs sit at the outer ends), but the
## head cell goes toward -Z, so the meshes are turned 180 degrees (2 quarter-turns) to line up.
const MULTI := {
	&"bed": {
		"parts": {&"foot": Vector3i(0, 0, 0), &"head": Vector3i(0, 0, -1)},
		"meshes": {&"foot": "bed_foot", &"head": "bed_head"},
		"mesh_turns": 2,
	},
}

## Blocks that can hold water in the same cell (the Fluids GridMap is separate from the terrain
## one, so "waterlogging" is just allowing both to be filled at once).
const WATERLOGGABLE: Array[StringName] = [&"fence"]

## Fences connect to any solid block EXCEPT these (and anything that needs support, like torches).
const NOT_FULL: Array[StringName] = [&"bed", &"lever", &"leaves", &"glass", &"chest", &"ice_block"]


static func is_multi(block_id: StringName) -> bool:
	return MULTI.has(block_id)


static func parts(block_id: StringName) -> Array:
	return MULTI[block_id]["parts"].keys()


static func part_mesh(block_id: StringName, part: StringName) -> String:
	return MULTI[block_id]["meshes"][part]


## Quarter-turns to add to the cell orientation of this block's meshes (see MULTI above).
static func mesh_turns(block_id: StringName) -> int:
	return MULTI[block_id].get("mesh_turns", 0)


## Offset of `part` from the origin cell after turning the block `turns` quarter-turns (about Y).
static func part_offset(block_id: StringName, part: StringName, turns: int) -> Vector3i:
	var o: Vector3i = MULTI[block_id]["parts"][part]
	var v := Basis(Vector3.UP, turns * PI / 2.0) * Vector3(o)
	return Vector3i(v.round())


## The block id a variant mesh belongs to, or &"" if `mesh_name` isn't a variant.
static func block_for_mesh(mesh_name: String) -> StringName:
	return VARIANT_MESHES.get(mesh_name, &"")


## Which mesh a cell should show, given its block and its state. Return `base_mesh` for "no variant".
static func mesh_for(block_id: StringName, base_mesh: String, state: Dictionary) -> String:
	match block_id:
		&"furnace":
			return "furnace_lit" if state.get("lit", false) else base_mesh
		&"bed":
			return part_mesh(&"bed", state.get("part", &"foot"))
	return base_mesh


static func fence_connects(neighbor_id: StringName, needs_support: Array) -> bool:
	if neighbor_id == &"fence":
		return true
	return not neighbor_id in NOT_FULL and not neighbor_id in needs_support


## Warn about variant meshes the library doesn't have, so a typo isn't a silent "nothing changes".
static func validate(lib: MeshLibrary) -> void:
	for mesh_name: String in VARIANT_MESHES:
		if lib.find_item_by_name(mesh_name) == GridMap.INVALID_CELL_ITEM:
			push_warning("BlockRules: mesh '%s' (variant of '%s') is not in the terrain library" % [mesh_name, VARIANT_MESHES[mesh_name]])
