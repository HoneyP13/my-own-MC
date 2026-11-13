# scripts/data/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName          # "dirt", "coal_ore", "pickaxe"; never changes
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 64
@export var on_use: Use
@export var on_use_value: int = 0

enum Use { NONE, FEED_PLAYER, FEED_MOB, BUCKET, SLEEP, GIVE_EFFECT, ATTACK_DAMAGE, PROJECTILE, PROTECTION }
## Right-click with this item selected. Return true if it did something.
func use_on_block(_world: Node, _hit: VoxelRaycast.Hit) -> bool:
	if on_use == Use.FEED_PLAYER:
		_world.player.feast(on_use_value, true)
		return true
	elif on_use == Use.BUCKET:
		if _world.fluid_at(_hit.cell) == &"lava" or _world.fluid_at(_hit.cell) == &"water":
			if _world.hud.held_item.id == &"bucket":
				if _world.hud.held_item.count > 1:
					var items = _world.hud.held_item
					items.count -= 1
					_world.hud.held_item.count = 1
					_world.hud.held_item.id = &"lava_bucket" if _world.fluid_at(_hit.cell) == &"lava" else &"water_bucket"
					_world.hud.add_item(items.id,items.count)
				else:
					_world.hud.held_item.id = &"lava_bucket" if _world.fluid_at(_hit.cell) == &"lava" else &"water_bucket"
				_world.fluids_map.set_cell(_hit.cell, GridMap.INVALID_CELL_ITEM)
				return true
			else:
				return false
		else:
			return false
	else:
		return false
