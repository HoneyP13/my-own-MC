# scripts/data/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName          # "dirt", "coal_ore", "pickaxe"; never changes
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 64
@export var on_use: Use
@export var on_use_value: int = 0

enum Use { NONE, FEED_PLAYER, BUCKET }
## Right-click with this item selected. Return true if it did something.
func use_on_block(_world: Node, _hit: VoxelRaycast.Hit) -> bool:
	if on_use == Use.FEED_PLAYER:
		var player = get_local_scene().find_child("Player")
		player.feast(on_use_value, true)
		return true
	else:
		return false
