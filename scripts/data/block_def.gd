# scripts/data/block_def.gd
class_name BlockDef
extends Resource

@export var id: StringName
@export var mesh_name: String       # the item name inside terrain_mesh_library
@export var hardness: float = 1.0
@export var drop_id: StringName     # an ItemDef id; empty = drops nothing
