# scripts/data/block_def.gd
class_name BlockDef
extends Resource

@export var id: StringName
@export var mesh_name: String       # the item name inside terrain_mesh_library
@export var drop_id: StringName     # an ItemDef id; empty = drops nothing
@export var hardness: float = 1.0      # seconds to break bare-handed; -1 = unbreakable
@export var tool_kind: StringName      # &"pickaxe", &"axe", &"shovel", or empty
