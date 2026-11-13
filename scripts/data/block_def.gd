# scripts/data/block_def.gd
class_name BlockDef
extends Resource

@export var id: StringName
@export var mesh_name: String       # the item name inside terrain_mesh_library
@export var drop_id: StringName     # an ItemDef id; empty = drops nothing
@export var drop_chance: int = 100
@export var drop_id_2: StringName
@export var drop_chance_2: int
@export var hardness: float = 1.0      # seconds to break bare-handed; -1 = unbreakable
@export var tool_kind: StringName      # &"pickaxe", &"axe", &"shovel", or empty
@export var req_tier: StringName
