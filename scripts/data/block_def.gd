# scripts/data/block_def.gd
class_name BlockDef
extends Resource

@export var id: StringName
@export var mesh_name: String       # the item name inside terrain_mesh_library
@export var drop_min: int = 1
@export var drop_max: int = 1
@export var drop_id: StringName     # an ItemDef id; empty = drops nothing
@export var drop_chance: int = 100
@export var drop_id_2: StringName
@export var drop_chance_2: int
@export var min_exp: int = 0
@export var max_exp: int = 0
@export var hardness: float = 1.0      # seconds to break bare-handed; -1 = unbreakable
@export var tool_kind: StringName      # &"pickaxe", &"axe", &"shovel", or empty
@export var req_tier: StringName
@export var blast_resistance: float = 0
@export var luminous: int = 0
@export var transparent: bool = false
@export var flammable: bool = false
@export var ignite_odds: int = 0
@export var burn_odds: int = 0
@export var waterloggable: bool = false
@export var needs_silk_touch: bool = false # to drop itself
