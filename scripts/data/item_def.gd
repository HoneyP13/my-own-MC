# scripts/data/item_def.gd
class_name ItemDef
extends Resource

@export var id: StringName          # "dirt", "coal_ore", "pickaxe"; never changes
@export var display_name: String
@export var icon: Texture2D
@export var max_stack: int = 64
@export var item_type: Type
@export var attributes: Dictionary[Attr, float]
@export var give_effect: Dictionary[Effects, float]
@export var tags: Array[Tag]

enum Type { NONE, TOOL, WEAPON, ARMOR, FOOD, FARMABLE_CONSUMABLE, CROP, PROJECTILE, CONTAINER,
WORKBENCH, COMPOSTABLE, SPAWN_EGG, POTION }
enum Attr { DURABILITY, ATTACK_DAMAGE, ARMOR, HUNGER, SATURATION, SATURATION_BOOST, TOUGHNESS }
enum Effects { NONE, ABSORPTION, UNLUCK, BAD_OMEN, BLINDNESS, BREATH_OF_THE_NAUTILUS, CONDUIT_POWER,
DARKNESS, DOLPHINS_GRACE, FATAL_POISON, FIRE_RESISTANCE, FREEZING, GLOWING, HASTE, HEALTH_BOOST,
HERO_OF_THE_VILLAGE, HUNGER, INFESTED, INSTANT_DAMAGE, INSTANT_HEALTH, INVISIBILITY, JUMP_BOOST,
LEVITATION, LUCK, MINING_FATIGUE, NAUSEA, NIGHT_VISION, OOZING, POISON, RAID_OMEN, REGENERATION,
RESISTANCE, SATURATION, SLOWNESS, SLOW_FALLING, SPEED, STRENGTH, TRIAL_OMEN, WATER_BREATHING,
WEAKNESS, WEAVING, WIND_CHARGED, WITHER}
enum Tag { ACACIA_LOGS, ANVIL, ARMADILLO_FOOD, ARROWS, AXES, AXOLOTL_FOOD, BAMBOO_BLOCKS, BANNERS,
BARS, BEACON_PAYMENT_ITEMS, BEDS, BEE_FOOD, BIRCH_LOGS, BOATS, BOOK_CLONING_TARGET, BOOKSHELF_BOOKS,
BREAKS_DECORATED_POTS, BREWING_POTION_INPUTS, BUNDLES, BUTTONS, CAMEL_FOOD, CAMEL_HUSK_FOOD, CANDLES,
CAT_COLLAR_DYES, CAT_FOOD, CAULDRON_CAN_REMOVE_DYE, CHAINS, CHERRY_LOGS, CHEST_ARMOR, CHEST_BOATS,
CHICKEN_FOOD, CLONABLE_MAPS, CLUSTER_MAX_HARVESTABLES, COAL_ORES, COALS, COMPASSES,
COMPLETES_FIND_TREE_TUTORIAL, CONCRETE, CONCRETE_POWDERS, CONCRETE_SLABS, CONCRETE_STAIRS, COPPER,
COPPER_CHESTS, COPPER_GOLEM_STATUES, COPPER_ORES, COPPER_TOOL_MATERIALS, COW_FOOD,
CREEPER_DROP_MUSIC_DISCS, CREEPER_IGNITERS, CRIMSON_STEMS, CUSHIONS, DAMPENS_VIBRATIONS,
DARK_OAK_LOGS, DECORATED_POT_INGREDIENTS, DECORATED_POT_SHERDS, DIAMOND_ORES, DIAMOND_TOOL_MATERIALS,
DIRT, DOORS, DOUSES_CAMPFIRES, DROWNED_PREFERRED_WEAPONS, DUPLICATES_ALLAYS, DYES, EGGS, EMERALD_ORES,
EXTENDABLE_MAPS, FENCE_GATES, FENCES, FISHES, FLOWERS, FOOT_ARMOR, FOX_FOOD, FREEZE_IMMUNE_WEARABLES,
FROG_FOOD, FROSTBITE_PREFFERED_WEAPONS, FURNACE_FUEL_BOTTOM_TAKEABLE, FURNACE_MINECART_FUEL}
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
