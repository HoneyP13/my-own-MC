# scripts/data/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName          # "dirt", "coal_ore", "pickaxe"; never changes
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 64

## Right-click with this item selected. Return true if it did something.
func use_on_block(_world: Node, _hit: VoxelRaycast.Hit) -> bool:
	return false
