# scripts/data/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName          # "dirt", "coal_ore", "pickaxe"; never changes
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 64
@export var item_type: Type
@export var attributes: Dictionary[Attr, float]
@export var give_effect: Effects

enum Type { NONE, TOOL, WEAPON, ARMOR, FOOD, FARMABLE_CONSUMABLE, CROP, PROJECTILE, CONTAINER, WORKBENCH, COMPOSTABLE }
enum Attr { DURABILITY, ATTACK_DAMAGE, PROTECTION, HUNGER, SATURATION, SATURATION_BOOST, TOUGHNESS }
enum Effects { NONE, POISON, SLOWNESS, BLINDNESS, SPEED, INSTANT_HEALTH }
## Right-click with this item selected. Return true if it did something.
func use_on_block(_world: Node, _hit: VoxelRaycast.Hit) -> bool:
	if item_type == Type.FOOD:
		_world.player.feast(attributes.get(Attr.HUNGER), true)
		return true
	if item_type == Type.TOOL:
		print("Type.TOOL")
		match _world.hud.held_item.id:
			&"wooden_hoe", &"stone_hoe", &"iron_hoe", &"golden_hoe", &"diamond_hoe":
				print(Registry.blocks_by_mesh.get(_world.grid_map.mesh_library.get_item_name(_hit.item)).id)
				match Registry.blocks_by_mesh.get(_world.grid_map.mesh_library.get_item_name(_hit.item)).id:
					&"dirt", &"grass_block", &"mycelium", &"coarse_dirt", &"podzol", &"dirt_path": _world.grid_map.set_cell_item(_hit.cell, _world.grid_map.mesh_library.find_item_by_name(&"farmland")); return true
					&"rooted_dirt": _world.grid_map.set_cell_item(_hit.cell, _world.grid_map.mesh_library.find_item_by_name(&"dirt")); return true
					_: return false
			_: 
				print("none")
				return false
	#elif attributes.has(Use.BUCKET):
		#if _world.fluid_at(_hit.cell) == &"lava" or _world.fluid_at(_hit.cell) == &"water":
			#if _world.hud.held_item.id == &"bucket":
				#if _world.hud.held_item.count > 1:
					#var items = _world.hud.held_item
					#items.count -= 1
					#_world.hud.held_item.count = 1
					#_world.hud.held_item.id = &"lava_bucket" if _world.fluid_at(_hit.cell) == &"lava" else &"water_bucket"
					#_world.hud.add_item(items.id,items.count)
				#else:
					#_world.hud.held_item.id = &"lava_bucket" if _world.fluid_at(_hit.cell) == &"lava" else &"water_bucket"
				#_world.fluids_map.set_cell(_hit.cell, GridMap.INVALID_CELL_ITEM)
				#return true
			#else: return false
		#else: return false
	else: return false
