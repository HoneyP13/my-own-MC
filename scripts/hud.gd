extends CanvasLayer

## Which screen is up. This is the ONE place that answers "what's on screen right now?".
## Every panel's visibility, the mouse capture and the pause flag are all worked out from it,
## so they can never disagree with each other. See set_ui_state() / _refresh_ui().
enum UIState { PLAYING, INVENTORY, CHAT, PAUSED, SETTINGS, DEAD, CONTAINER, FURNACE }
enum SlotArea { ARMOR, CRAFTING, RESULT, INVENTORY, HOTBAR, CHEST, FUEL, INPUT, OUTPUT, CRAFTING_TABLE }

@onready var world: Node3D = $".."
@onready var player: Player = $"../Player"
@onready var health_bar: HBoxContainer = %HealthBar
@onready var hunger_bar: HBoxContainer = %HungerBar
@onready var hud_hot_bar: Control = %GameplayHUD
@onready var hot_bar_parent: HBoxContainer = %HotBar
@onready var inventory_menu: Panel = %InventoryMenu
@onready var player_window: PanelContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/PlayerWindow
@onready var armor_slots: VBoxContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/ArmorSlots
@onready var inventory_crafting: GridContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/InventoryCrafting
@onready var craft_result: TextureRect = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/CraftResult
@onready var inv: GridContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/Inventory
@onready var inv_hot_bar: HBoxContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/HotBar
@onready var menu_bg: PanelContainer = %MenuBG
@onready var pause_menu: VBoxContainer = %PauseMenu
@onready var settings_menu: PanelContainer = %SettingsMenu
@onready var debug_info: VBoxContainer = $DebugInfo
@onready var chat: VBoxContainer = %Chat
@onready var chat_history: RichTextLabel = %ChatHistory
@onready var type_interface: LineEdit = %TypeInterface
@onready var death_screen: PanelContainer = %DeathScreen

var ui_state : UIState = UIState.PLAYING
var cursor_item = null          # item name the mouse is holding, or null
var cursor_icon: TextureRect

const HELMET_SLOT_HINT = preload("uid://boytvciuq1c8g")
const HELMET_HOVER_HINT = preload("uid://jc8ylrfom8mn")
const CHESTPLATE_SLOT_HINT = preload("uid://c6wv1gb2gsvra")
const CHESTPLATE_HOVER_HINT = preload("uid://bpb25e81u1ud6")
const LEGGINGS_SLOT_HINT = preload("uid://6un28ehnxl1f")
const LEGGINGS_HOVER_HINT = preload("uid://c4xehnjsyf7wq")
const BOOTS_SLOT_HINT = preload("uid://le7sxt7k6owg")
const BOOTS_HOVER_HINT = preload("uid://cdyle6uqtpdey")

const SLOT_NORMAL := preload("uid://j01ee113mi0m")
const SLOT_HOVER := preload("uid://ddsjvo8b3cuwi")
const ICON_SIZE := Vector2(56, 56)

const FULL_HEART = preload("uid://djyw2tavut04a")
const HALF_HEART = preload("uid://7l7eaqncaxjt")
const EMPTY_HEART = preload("uid://b5cis83cjqupe")

const FULL_SHANK = preload("uid://cq2wuxythsc3")
const HALF_SHANK = preload("uid://b0x815uer06mj")
const EMPTY_SHANK = preload("uid://b7t3cmr3ptk7o")

const RECIPES := [
	{"result": &"plank", "count": 4, "ingredients": {&"log": 1}},
	{"result": &"red_wool", "count": 1, "ingredients": {&"white_wool": 1, &"red_dye": 1}},
	{"result": &"green_wool", "count": 1, "ingredients": {&"white_wool": 1, &"green_dye": 1}},
	{"result": &"blue_wool", "count": 1, "ingredients": {&"white_wool": 1, &"blue_dye": 1}},
	{"result": &"cyan_wool", "count": 1, "ingredients": {&"white_wool": 1, &"cyan_dye": 1}},
	{"result": &"magenta_wool", "count": 1, "ingredients": {&"white_wool": 1, &"magenta_dye": 1}},
	{"result": &"yellow_wool", "count": 1, "ingredients": {&"white_wool": 1, &"yellow_dye": 1}},
	{"result": &"black_wool", "count": 1, "ingredients": {&"white_wool": 1, &"black_dye": 1}},
	{"result": &"gray_wool", "count": 1, "ingredients": {&"white_wool": 1, &"gray_dye": 1}},
	{"result": &"light_gray_wool", "count": 1, "ingredients": {&"white_wool": 1, &"light_gray_dye": 1}},
	{"result": &"white_wool", "count": 1, "ingredients": {&"string": 4}},
	{"result": &"orange_wool", "count": 1, "ingredients": {&"white_wool": 1, &"orange_dye": 1}},
	{"result": &"pink_wool", "count": 1, "ingredients": {&"white_wool": 1, &"pink_dye": 1}},
	{"result": &"light_blue_wool", "count": 1, "ingredients": {&"white_wool": 1, &"light_blue_dye": 1}},
	{"result": &"brown_wool", "count": 1, "ingredients": {&"white_wool": 1, &"brown_dye": 1}},
	{"result": &"pink_dye", "count": 2, "ingredients": {&"red_dye": 1, &"white_dye": 1}},
	{"result": &"orange_dye", "count": 2, "ingredients": {&"red_dye": 1, &"yellow_dye": 1}},
	{"result": &"light_blue_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"white_dye": 1}},
	{"result": &"light_gray_dye", "count": 2, "ingredients": {&"gray_dye": 1, &"white_dye": 1}},
	{"result": &"gray_dye", "count": 2, "ingredients": {&"black_dye": 1, &"white_dye": 1}},
	{"result": &"lime_dye", "count": 2, "ingredients": {&"green_dye": 1, &"white_dye": 1}},
	{"result": &"light_blue_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"white_dye": 1}},
	{"result": &"cyan_dye", "count": 2, "ingredients": {&"blue_dye": 1, &"green_dye": 1}},
	{"result": &"magenta_dye", "count": 2, "ingredients": {&"pink_dye": 1, &"purple_dye": 1}},
	{"result": &"stick", "count": 4, "ingredients": {&"plank": 2}},
	{"result": &"torch", "count": 4, "ingredients": {&"coal": 1, &"stick": 1}},
	{"result": &"snow_block", "count": 1, "ingredients": {&"snowball": 4}},
	{"result": &"crafting_table", "count": 1, "ingredients": {&"plank": 4}},
	{"result": &"wooden_pickaxe", "count": 1, "ingredients": [{&"plank": 1}, {&"plank": 1}, {&"plank": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_axe", "count": 1, "ingredients": [{&"plank": 1}, {&"plank": 1}, null, {&"plank": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_shovel", "count": 1, "ingredients": [null, {&"plank": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wooden_sword", "count": 1, "ingredients": [null, {&"plank": 1}, null, null, {&"plank": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"wood_block", "count": 3, "ingredients": {&"log": 4}},
	{"result": &"wooden_hoe", "count": 1, "ingredients": [null, {&"plank": 1}, {&"plank": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"redstone_torch", "count": 1, "ingredients": {&"redstone_dust": 1, &"stick": 1}},
	{"result": &"furnace", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1}]},
	{"result": &"hay_bale", "count": 1, "ingredients": [{&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}]},
	{"result": &"redstone_block", "count": 1, "ingredients": [{&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}, {&"redstone_dust": 1}]},
	{"result": &"bed", "count": 1, "ingredients": [{&"white_wool": 1}, {&"white_wool": 1}, {&"white_wool": 1}, {&"plank": 1}, {&"plank": 1}, {&"plank": 1}]},
	{"result": &"bread", "count": 1, "ingredients": [{&"wheat": 1}, {&"wheat": 1}, {&"wheat": 1}]},
	{"result": &"diamond_block", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}]},
	{"result": &"coal_block", "count": 1, "ingredients": [{&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}, {&"coal": 1}]},
	{"result": &"fence", "count": 3, "ingredients": [{&"plank": 1}, {&"stick": 1}, {&"plank": 1}, {&"plank": 1}, {&"stick": 1}, {&"plank": 1}]},
	#{"result": &"lever", "count": 1, "ingredients": {&"stick": 1, &"cobblestone": 1}},
	{"result": &"stone_pickaxe", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, {&"cobblestone": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_shovel", "count": 1, "ingredients": [null, {&"cobblestone": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_sword", "count": 1, "ingredients": [null, {&"cobblestone": 1}, null, null, {&"cobblestone": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_axe", "count": 1, "ingredients": [{&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"cobblestone": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"stone_hoe", "count": 1, "ingredients": [null, {&"cobblestone": 1}, {&"cobblestone": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_pickaxe", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_shovel", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_sword", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, null, null, {&"iron_ingot": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_axe", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"iron_hoe", "count": 1, "ingredients": [null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_pickaxe", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_shovel", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_sword", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, null, null, {&"gold_ingot": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_axe", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"golden_hoe", "count": 1, "ingredients": [null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_pickaxe", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1,}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_shovel", "count": 1, "ingredients": [null, {&"diamond": 1}, null, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_sword", "count": 1, "ingredients": [null, {&"diamond": 1}, null, null, {&"diamond": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_axe", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"diamond_hoe", "count": 1, "ingredients": [null, {&"diamond": 1}, {&"diamond": 1}, null, {&"stick": 1,}, null, null, {&"stick": 1,}, null]},
	{"result": &"fishing_rod", "count": 1, "ingredients": [{&"stick": 1}, null, null, {&"string": 1}, {&"stick": 1}, null, {&"string": 1}, null, {&"stick": 1}]},
	#{"result": &"flint_and_steel", "count": 1, "ingredients": {&"flint": 1, &"iron_ingot": 1}},
	#{"result": &"leather_cap", "count": 1, "ingredients": [{&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	#{"result": &"leather_tunic", "count": 1, "ingredients": [{&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}]},
	#{"result": &"leather_pants", "count": 1, "ingredients": [{&"leather": 1}, {&"leather": 1}, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	#{"result": &"leather_boots", "count": 1, "ingredients": [{&"leather": 1}, null, {&"leather": 1}, {&"leather": 1}, null, {&"leather": 1}]},
	#{"result": &"iron_helmet", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	#{"result": &"iron_hchestplate", "count": 1, "ingredients": [{&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}]},
	#{"result": &"iron_hleggings", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	#{"result": &"iron_hboots", "count": 1, "ingredients": [{&"iron_ingot": 1}, null, {&"iron_ingot": 1}, {&"iron_ingot": 1}, null, {&"iron_ingot": 1}]},
	#{"result": &"golden_helmet", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	#{"result": &"golden_chestplate", "count": 1, "ingredients": [{&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	#{"result": &"golden_leggings", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	#{"result": &"golden_boots", "count": 1, "ingredients": [{&"gold_ingot": 1}, null, {&"gold_ingot": 1}, {&"gold_ingot": 1}, null, {&"gold_ingot": 1}]},
	#{"result": &"diamond_helmet", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	#{"result": &"diamond_chestplate", "count": 1, "ingredients": [{&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}]},
	#{"result": &"diamond_leggings", "count": 1, "ingredients": [{&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	#{"result": &"diamond_boots", "count": 1, "ingredients": [{&"diamond": 1}, null, {&"diamond": 1}, {&"diamond": 1}, null, {&"diamond": 1}]},
	#{"result": &"golden_apple", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"apple": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	{"result": &"redstone_dust", "count": 9, "ingredients": {&"redstone_block": 1}},
	{"result": &"diamond", "count": 9, "ingredients": {&"diamond_block": 1}},
	{"result": &"gold_ingot", "count": 9, "ingredients": {&"gold_block": 1}},
	{"result": &"iron_ingot", "count": 9, "ingredients": {&"iron_block": 1}},
	{"result": &"gold_block", "count": 1, "ingredients": [{&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}, {&"gold_ingot": 1}]},
	{"result": &"iron_block", "count": 1, "ingredients": [{&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}, {&"iron_ingot": 1}]},
	#{"result": &"tnt", "count": 1, "ingredients": [{&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}]},
	#{"result": &"slime_block", "count": 1, "ingredients": [{&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}, {&"": 1}]},
	{"result": &"red_dye", "count": 4, "ingredients": {&"red_flower": 1}},
	{"result": &"blue_dye", "count": 4, "ingredients": {&"blue_flower": 1}},
	{"result": &"purple_dye", "count": 4, "ingredients": {&"red_dye": 1, &"blue_dye": 1}},
	{"result": &"blue_ice", "count": 1, "ingredients": [{&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}, {&"ice_block": 1}]},
] # TODO: I forgot packed ice existed, so eventually replace ice blocks with it in the blue ice recipe
# TODO: add the ability to smelt gold and iron armor / tools into nuggets, once added, and output an empty bucket if lava bucket was used as fuel source.
const SMELTING := {&"iron_ore": &"iron_ingot", &"gold_ore": &"gold_ingot",
	&"raw_meat": &"cooked_meat", &"cobblestone": &"stone", &"sand": &"glass_block", &"diamond_ore": &"diamond", }
const FUEL := {&"lava_bucket": 1000.0, &"coal_block": 800.0, &"coal": 80.0, &"charcoal": 80.0, &"log": 15.0, &"plank": 15.0, &"wooden_axe": 10.0, &"wooden_sword": 10.0, &"wooden_shovel": 10.0, &"wooden_hoe": 10.0, &"wooden_pickaxe": 10.0, &"crafting_table": 15.0, &"fishing_rod": 15.0, &"stick": 5.0}  # burn seconds

var furnace_slots : Array = [null, null, null]
var hotbar : Array
signal current_hotbar_slot_changed(slot: int)
var current_hotbar_slot : int = 0:
	set(value):
		current_hotbar_slot = value
		current_hotbar_slot_changed.emit(current_hotbar_slot)
# Always reflects the selected slot
var held_item:
	get:
		return hotbar[current_hotbar_slot]

func _on_player_scrolled(is_up: bool) -> void:
	current_hotbar_slot = wrapi(current_hotbar_slot + (-1 if is_up else 1), 0, hotbar.size())

func _on_current_hotbar_slot_changed(_slot: int) -> void:
	_update_hotbar_highlight()

func _update_hotbar_highlight() -> void:
	for i in hot_bar_parent.get_child_count():
		hot_bar_parent.get_child(i).texture = SLOT_HOVER if i == current_hotbar_slot else SLOT_NORMAL
var inventory: Array
var inv_craft_grid: Array
var inv_craft_result
var player_armor: Array
var table_craft_grid: Array
var craft_grid: Array          # whichever grid is active right now
var craft_width := 2
var table_menu: Panel
var table_grid: GridContainer
var table_result: TextureRect
var table_inv: GridContainer
var table_hotbar: HBoxContainer
var furnace_menu: Panel
var smelting_fuel: TextureRect
var smelting_ingredient: TextureRect
var smelting_result: TextureRect
var furnace_inv: GridContainer
var furnace_hotbar: HBoxContainer

const FLUIDS_MESH_LIBRARY = preload("uid://bt86017oxii2w")
const TERRAIN_MESH_LIBRARY = preload("uid://dgqqtmwpwy6eu")

func _init() -> void:
	player_armor.resize(4)
	inv_craft_grid.resize(4)
	table_craft_grid.resize(9)
	craft_grid = inv_craft_grid
	inventory.resize(27)
	hotbar.resize(9)

func _ready() -> void:
	player.scrolled.connect(_on_player_scrolled)
	player.open_menu.connect(_on_open_menu)
	player.open_inventory.connect(_on_open_inventory)
	player.open_chat.connect(_on_open_chat)
	player.open_debug_info.connect(_on_open_debug_info)
	_build_table_menu()
	_build_furnace_menu()
	_setup_inventory_slots()
	refresh_slots()
	_refresh_ui()
	for r in RECIPES:
		if Registry.get_item(r.result) == null:
			push_warning("Recipe result '%s' has no item def" % r.result)

func _make_slot() -> TextureRect:
	var s := TextureRect.new()
	s.custom_minimum_size = Vector2(64, 64)
	s.texture = SLOT_NORMAL
	return s

func _build_table_menu() -> void:
	table_menu = Panel.new()
	table_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	table_menu.visible = false
	add_child(table_menu)
	table_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	table_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var window := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.333, 0.333, 0.333)
	window.add_theme_stylebox_override("panel", sb)
	center.add_child(window)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 48)
	vbox.add_child(top)
	table_grid = GridContainer.new()
	table_grid.columns = 3
	top.add_child(table_grid)
	for i in 9:
		var s := _make_slot()
		table_grid.add_child(s)
		_wire_slot(s, SlotArea.CRAFTING_TABLE, i)
	table_result = _make_slot()
	table_result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(table_result)
	_wire_slot(table_result, SlotArea.RESULT, 0)

	table_inv = GridContainer.new()
	table_inv.columns = 9
	vbox.add_child(table_inv)
	for i in 27:
		var s := _make_slot()
		table_inv.add_child(s)
		_wire_slot(s, SlotArea.INVENTORY, i)

	table_hotbar = HBoxContainer.new()
	table_hotbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(table_hotbar)
	for i in 9:
		var s := _make_slot()
		table_hotbar.add_child(s)
		_wire_slot(s, SlotArea.HOTBAR, i)

func _build_furnace_menu() -> void:
	furnace_menu = Panel.new()
	furnace_menu.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	furnace_menu.visible = false
	add_child(furnace_menu)
	furnace_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	furnace_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var window := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.333, 0.333, 0.333)
	window.add_theme_stylebox_override("panel", sb)
	center.add_child(window)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 48)
	vbox.add_child(top)
	var interface := VBoxContainer.new()
	interface.add_theme_constant_override("separation", 48)
	top.add_child(interface)
	smelting_ingredient = _make_slot()
	_wire_slot(smelting_ingredient, SlotArea.INPUT, 0)
	smelting_ingredient.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	interface.add_child(smelting_ingredient)
	smelting_fuel = _make_slot()
	_wire_slot(smelting_fuel, SlotArea.FUEL, 1)
	smelting_fuel.size_flags_vertical = Control.SIZE_SHRINK_END
	interface.add_child(smelting_fuel)
	smelting_result = _make_slot()
	smelting_result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(smelting_result)
	_wire_slot(smelting_result, SlotArea.OUTPUT, 2)

	furnace_inv = GridContainer.new()
	furnace_inv.columns = 9
	vbox.add_child(furnace_inv)
	for i in 27:
		var s := _make_slot()
		furnace_inv.add_child(s)
		_wire_slot(s, SlotArea.INVENTORY, i)

	furnace_hotbar = HBoxContainer.new()
	furnace_hotbar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(furnace_hotbar)
	for i in 9:
		var s := _make_slot()
		furnace_hotbar.add_child(s)
		_wire_slot(s, SlotArea.HOTBAR, i)

func open_furnace(slots: Array) -> void:
	furnace_slots = slots   # same array reference, so edits write through to world.furnaces
	set_ui_state(UIState.FURNACE)

func _setup_inventory_slots() -> void:
	for i in armor_slots.get_child_count():
		_wire_slot(armor_slots.get_child(i), SlotArea.ARMOR, i)
	for i in inventory_crafting.get_child_count():
		_wire_slot(inventory_crafting.get_child(i), SlotArea.CRAFTING, i)
	_wire_slot(craft_result, SlotArea.RESULT, 0)
	for i in inv.get_child_count():
		_wire_slot(inv.get_child(i), SlotArea.INVENTORY, i)
	for i in inv_hot_bar.get_child_count():
		_wire_slot(inv_hot_bar.get_child(i), SlotArea.HOTBAR, i)

	cursor_icon = TextureRect.new()
	cursor_icon.size = Vector2(56, 56)
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block clicks on slots
	cursor_icon.visible = false
	add_child(cursor_icon)  # added last, so it draws on top

func _wire_slot(slot: TextureRect, area: int, index: int) -> void:
	slot.gui_input.connect(_on_slot_gui_input.bind(area, index))
	slot.mouse_entered.connect(func(): slot.texture = HELMET_HOVER_HINT if slot.name == "HelmetSlot" else CHESTPLATE_HOVER_HINT if slot.name == "TorsoSlot" else LEGGINGS_HOVER_HINT if slot.name == "PantsSlot" else BOOTS_HOVER_HINT if slot.name == "BootsSlot" else SLOT_HOVER)
	slot.mouse_exited.connect(func(): slot.texture = HELMET_SLOT_HINT if slot.name == "HelmetSlot" else CHESTPLATE_SLOT_HINT if slot.name == "TorsoSlot" else LEGGINGS_SLOT_HINT if slot.name == "PantsSlot" else BOOTS_SLOT_HINT if slot.name == "BootsSlot" else SLOT_NORMAL)

var is_shift_pressed : bool = false
func _on_slot_gui_input(event: InputEvent, area: int, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed): return
	var slots: Array
	is_shift_pressed = true if event.is_pressed() and event.keycode == KEY_SHIFT else false
	if area == SlotArea.RESULT or area == SlotArea.OUTPUT:
		if event.button_index == MOUSE_BUTTON_LEFT: _take_result()
		refresh_slots()
		return
	if area == SlotArea.INPUT or area == SlotArea.FUEL: slots = furnace_slots
	if area == SlotArea.ARMOR: slots = player_armor # TODO: Fix this
	if area == SlotArea.CRAFTING: slots = inv_craft_grid
	if area == SlotArea.INVENTORY: slots = inventory
	if area == SlotArea.HOTBAR: slots = hotbar
	if area == SlotArea.CRAFTING_TABLE: slots = table_craft_grid
	if cursor_item != null:
		if area == SlotArea.INPUT and not SMELTING.has(cursor_item.id): return
		if area == SlotArea.FUEL and not FUEL.has(cursor_item.id): return
	match event.button_index:
		MOUSE_BUTTON_LEFT: _left_click(slots, index)
		MOUSE_BUTTON_RIGHT: _right_click(slots, index)
		_: return
	refresh_slots()

func _left_click(slots: Array, i: int) -> void:
	var slot = slots[i]
	if is_shift_pressed and slot != null:
		var def := Registry.get_item(slot.id)
		var amount = slot.count
		if def == null: return
		for spots in (hotbar if slots == hotbar else inventory):
			for item in spots.size():
				var s = spots[item]
				if s != null and s.id == slot.id and s.count < def.max_stack:
					var moved := mini(def.max_stack - s.count, amount)
					s.count += moved
					amount -= moved
					if amount == 0:
						slot = null
						refresh_slots()
						return
		for spots in (hotbar if slots == hotbar else inventory):
			for item in spots.size():
				if spots[item] == null:
					var moved := mini(def.max_stack, amount)
					spots[item] = {"id": item.id, "count": moved}
					amount -= moved
					if amount == 0:
						slot = null
						refresh_slots()
						return
				else: return
		refresh_slots()
	# Same item on both sides: pour the cursor stack into the slot, up to the stack limit.
	if slot != null and cursor_item != null and slot.id == cursor_item.id:
		var max_stack := Registry.get_item(slot.id).max_stack
		var moved := mini(max_stack - slot.count, cursor_item.count)
		slot.count += moved
		cursor_item.count -= moved
		if cursor_item.count <= 0: cursor_item = null
		return
	# Otherwise swap.
	slots[i] = cursor_item
	cursor_item = slot

func _right_click(slots: Array, i: int) -> void:
	var slot = slots[i]
	if cursor_item == null:
		# Pick up half (rounded up).
		if slot == null: return
		var half := ceili(slot.count / 2.0)
		cursor_item = {"id": slot.id, "count": half}
		slot.count -= half
		if slot.count <= 0: slots[i] = null
	else:
		# Drop a single item into an empty slot or onto a matching stack.
		if slot == null:
			slots[i] = {"id": cursor_item.id, "count": 1}
		elif slot.id == cursor_item.id and slot.count < Registry.get_item(slot.id).max_stack:
			slot.count += 1
		else:
			return
		cursor_item.count -= 1
		if cursor_item.count <= 0: cursor_item = null

var craft_output = null   # {"id":..., "count":...} or null
func _grid_ids(grid: Array) -> Array:
	var out := []
	for s in grid:
		out.append(s.id if s != null else &"")
	return out

func _pattern_ids(pattern: Array) -> Array:
	var out := []
	for e in pattern:
		out.append(e.keys()[0] if e != null else &"")
	return out

## Crops an id grid to its filled area, so shapes match wherever they sit in the grid.
@warning_ignore("integer_division")
func _trimmed(ids: Array, width: int) -> Dictionary:
	var height := ids.size() / width
	var min_x := width
	var max_x := -1
	var min_y := height
	var max_y := -1
	for i in ids.size():
		if ids[i] == &"": continue
		min_x = mini(min_x, i % width)
		max_x = maxi(max_x, i % width)
		min_y = mini(min_y, i / width)
		max_y = maxi(max_y, i / width)
	if max_x < 0: return {}
	var out := []
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			out.append(ids[y * width + x])
	return {"w": max_x - min_x + 1, "h": max_y - min_y + 1, "ids": out}

func _find_recipe() -> Dictionary:
	var ids := _grid_ids(craft_grid)
	var shape := _trimmed(ids, craft_width)
	if shape.is_empty(): return {}
	var have := {}
	for id in ids:
		if id != &"": have[id] = have.get(id, 0) + 1
	for r in RECIPES:
		if r.ingredients is Dictionary:                 # shapeless
			var need: Dictionary = r.ingredients
			if need.size() != have.size(): continue
			var ok := true
			for id in need:
				if have.get(id, 0) != need[id]:
					ok = false
					break
			if ok: return r
		else:                                           # shaped (3x3 pattern)
			var pat := _trimmed(_pattern_ids(r.ingredients), 3)
			if pat.w == shape.w and pat.h == shape.h and pat.ids == shape.ids:
				return r
	return {}

func _take_result() -> void:
	match ui_state:
		UIState.INVENTORY, UIState.CONTAINER:
			if craft_output == null: return
			var max_stack := Registry.get_item(craft_output.id).max_stack
			if cursor_item == null:
				cursor_item = craft_output.duplicate()
			elif cursor_item.id == craft_output.id and cursor_item.count + craft_output.count <= max_stack:
				cursor_item.count += craft_output.count
			else:
				return
			for i in craft_grid.size():
				if craft_grid[i] != null:
					craft_grid[i].count -= 1
					if craft_grid[i].count <= 0: craft_grid[i] = null
		UIState.FURNACE:
			var out = furnace_slots[2]
			if out == null: return
			var max_stack := Registry.get_item(out.id).max_stack
			if cursor_item == null:
				cursor_item = out
				furnace_slots[2] = null
			elif cursor_item.id == out.id and cursor_item.count + out.count <= max_stack:
				cursor_item.count += out.count
				furnace_slots[2] = null

func _return_cursor_item() -> void:
	if cursor_item != null:
		var stack = cursor_item
		cursor_item = null
		add_item(stack.id, stack.count)
	for grid in [inv_craft_grid, table_craft_grid]:
		for i in grid.size():
			if grid[i] != null:
				add_item(grid[i].id, grid[i].count)
				grid[i] = null
	refresh_slots()

func _update_craft_result() -> void:
	var r := _find_recipe()
	var ok := not r.is_empty() and Registry.get_item(r.result) != null
	craft_output = {"id": r.result, "count": r.count} if ok else null

func _process(_delta: float) -> void:
	if cursor_icon.visible:
		cursor_icon.position = get_viewport().get_mouse_position() - cursor_icon.size / 2.0

func add_item(item_id: StringName, amount: int = 1) -> void:
	var def := Registry.get_item(item_id)
	if def == null:
		push_warning("No item defined for '%s'" % item_id)
		return
	# 1) top up an existing stack (hotbar first, then inventory)
	for slots in [hotbar, inventory]:
		for i in slots.size():
			var s = slots[i]
			if s != null and s.id == item_id and s.count < def.max_stack:
				var moved := mini(def.max_stack - s.count, amount)
				s.count += moved
				amount -= moved
				if amount == 0:
					refresh_slots()
					return
	# 2) otherwise use empty slots
	for slots in [hotbar, inventory]:
		for i in slots.size():
			if slots[i] == null:
				var moved := mini(def.max_stack, amount)
				slots[i] = {"id": item_id, "count": moved}
				amount -= moved
				if amount == 0:
					refresh_slots()
					return
	refresh_slots()   # inventory full: leftovers are lost for now

func refresh_slots() -> void:
	_update_craft_result()
	rebuild_hotbar()
	update_inventory()
	cursor_icon.visible = cursor_item != null
	for child in cursor_icon.get_children():
		child.queue_free()
	if cursor_item != null:
		cursor_icon.texture = _icon_for(cursor_item.id)
		if cursor_item.count > 1:
			cursor_icon.add_child(_make_count_label(cursor_item.count))

## Draws one stack (or nothing) into a slot: icon, plus a count in the corner when count > 1.
func _fill_slot(slot: Control, stack) -> void:
	for old in slot.get_children():
		old.queue_free()
	if stack == null: return
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = ICON_SIZE
	icon.position = Vector2(4, 4)
	icon.texture = _icon_for(stack.id)
	slot.add_child(icon)
	if stack.count > 1:
		slot.add_child(_make_count_label(stack.count))

func _make_count_label(count: int) -> Label:
	var label := Label.new()
	label.text = str(count)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

func rebuild_hotbar() -> void:
	for i in hot_bar_parent.get_child_count():
		_fill_slot(hot_bar_parent.get_child(i), hotbar[i])
	_update_hotbar_highlight()

func update_inventory() -> void:
	for i in inv.get_child_count():
		_fill_slot(inv.get_child(i), inventory[i])
	for i in inv_hot_bar.get_child_count():
		_fill_slot(inv_hot_bar.get_child(i), hotbar[i])
	for i in armor_slots.get_child_count():
		_fill_slot(armor_slots.get_child(i), player_armor[i])
	for i in inventory_crafting.get_child_count():
		_fill_slot(inventory_crafting.get_child(i), inv_craft_grid[i])
	_fill_slot(craft_result, craft_output)
	for i in table_grid.get_child_count():
		_fill_slot(table_grid.get_child(i), table_craft_grid[i])
	for i in table_inv.get_child_count():
		_fill_slot(table_inv.get_child(i), inventory[i])
	for i in table_hotbar.get_child_count():
		_fill_slot(table_hotbar.get_child(i), hotbar[i])
	_fill_slot(table_result, craft_output)
	for i in furnace_inv.get_child_count():
		_fill_slot(furnace_inv.get_child(i), inventory[i])
	for i in furnace_hotbar.get_child_count():
		_fill_slot(furnace_hotbar.get_child(i), hotbar[i])
	_fill_slot(smelting_ingredient, furnace_slots[0])
	_fill_slot(smelting_fuel, furnace_slots[1])
	_fill_slot(smelting_result, furnace_slots[2])

func _icon_for(stack: StringName) -> Texture2D:
	return Registry.get_item(stack).icon

# ---------------------------------------------------------------------------------------------
# UI state
# ---------------------------------------------------------------------------------------------

func set_ui_state(new_state: UIState) -> void:
	var old_state := ui_state
	ui_state = new_state
	craft_grid = table_craft_grid if new_state == UIState.CONTAINER else inv_craft_grid
	craft_width = 3 if new_state == UIState.CONTAINER else 2
	_refresh_ui()
	var was_crafting := old_state == UIState.INVENTORY or old_state == UIState.CONTAINER or old_state == UIState.FURNACE
	var is_crafting := new_state == UIState.INVENTORY or new_state == UIState.CONTAINER or new_state == UIState.FURNACE
	if was_crafting and not is_crafting:
		_return_cursor_item()
	if old_state == UIState.CHAT and new_state != UIState.CHAT:
		type_interface.release_focus()
	player.set_menu_open(new_state != UIState.PLAYING)
	player.set_game_paused(new_state == UIState.PAUSED or new_state == UIState.SETTINGS)
	refresh_slots()

## Show exactly the panels that belong to the current state, and hide the rest.
func _refresh_ui() -> void:
	var s := ui_state
	hud_hot_bar.visible = s != UIState.INVENTORY and s != UIState.DEAD and s != UIState.CONTAINER and s != UIState.FURNACE
	inventory_menu.visible = s == UIState.INVENTORY
	chat.visible = s == UIState.CHAT
	menu_bg.visible = s == UIState.PAUSED or s == UIState.SETTINGS
	pause_menu.visible = s == UIState.PAUSED
	settings_menu.visible = s == UIState.SETTINGS
	death_screen.visible = s == UIState.DEAD
	# The debug overlay (toggled with the debug key) hides behind the inventory and pause menus.
	debug_info.visible = world.is_debug_enabled and (s == UIState.PLAYING or s == UIState.CHAT or s == UIState.DEAD)
	table_menu.visible = s == UIState.CONTAINER
	furnace_menu.visible = s == UIState.FURNACE

## Inventory key. Opens the inventory while playing, closes it again, and does nothing anywhere else.
func _on_open_inventory() -> void:
	match ui_state:
		UIState.PLAYING: set_ui_state(UIState.INVENTORY)
		UIState.INVENTORY, UIState.CONTAINER, UIState.FURNACE: set_ui_state(UIState.PLAYING)

## Escape key (also used by the Resume button): back out of whatever is open.
func _on_open_menu() -> void:
	match ui_state:
		UIState.PLAYING: set_ui_state(UIState.PAUSED)
		UIState.INVENTORY, UIState.CHAT, UIState.PAUSED, UIState.CONTAINER, UIState.FURNACE: set_ui_state(UIState.PLAYING)
		UIState.SETTINGS: set_ui_state(UIState.PAUSED) # back to the pause menu
		# DEAD: Escape does nothing. You have to hit Respawn.

func _on_open_debug_info() -> void:
	world.is_debug_enabled = not world.is_debug_enabled
	_refresh_ui()

func _on_open_chat(is_command: bool) -> void:
	if ui_state != UIState.PLAYING: return
	set_ui_state(UIState.CHAT)
	if is_command:
		type_interface.text = "/"
		type_interface.caret_column = 1
	type_interface.grab_focus()

func _on_resume_pressed() -> void:
	if ui_state == UIState.PAUSED: set_ui_state(UIState.PLAYING)

func _on_settings_pressed() -> void:
	if ui_state == UIState.PAUSED: set_ui_state(UIState.SETTINGS)

# ---------------------------------------------------------------------------------------------
# Chat
# ---------------------------------------------------------------------------------------------

func _on_type_interface_text_submitted(new_text: String) -> void:
	if new_text == "": return

	if new_text.begins_with("/"):
		var parts := new_text.substr(1).to_lower().split(" ", false)
		var cmd := parts[0] if parts.size() > 0 else ""
		var arg_1
		match cmd:
			"help":
				if parts.size() == 1:
					_chat_print("Available commands: /clear, /give, /gamemode")
				else:
					arg_1 = parts[1] if parts.size() > 1 else ""
					match arg_1:
						"clear":
							_chat_print("Usage: /clear (clears chat history)")
						"give":
							_chat_print("Usage: /give(self) [item] [amount]")
						"gamemode":
							_chat_print("Usage: /gamemode s (survival) / c (creative)")
						_:
							_chat_print("Unknown command: \"" + cmd + "\"")
			"clear":
				chat_history.clear()
			"give":
				var item_id := StringName(parts[1]) if parts.size() > 1 else &""
				if Registry.get_item(item_id) == null:
					_chat_print("Unknown item: " + str(item_id))
				else:
					var amount := maxi(1, int(parts[2])) if parts.size() > 2 else 1
					add_item(item_id, amount)
					_chat_print("Gave %s: %d %s" % [player.username, amount, item_id])
			"gamemode":
				arg_1 = parts[1] if parts.size() > 1 else ""
				match arg_1:
					"c", "creative":
						player.current_gamemode = player.Gamemode.CREATIVE
					"s", "survival":
						player.current_gamemode = player.Gamemode.SURVIVAL
			_:
				_chat_print("Unknown command: \"/" + cmd + "\"")
	else:
		_chat_print(str(player.username) + " > " + new_text)

	type_interface.clear()

## Adds one line to the chat. add_text() shows the text exactly as typed, whereas append_text()
## would treat things like [b] as formatting tags.
func _chat_print(line: String) -> void:
	chat_history.add_text(line)
	chat_history.newline()

func _on_player_is_dead_changed(is_true: bool) -> void:
	set_ui_state(UIState.DEAD if is_true else UIState.PLAYING)

func _on_player_health_changed(hp: int) -> void:
	var full_bar : float = player.FULL_HEALTH / 2.0
	var hearts : float = hp / 2.0
	for i in int(full_bar):
		var icon : TextureRect = health_bar.get_child(i)
		if hearts < 1.0 and hearts > 0.0: icon.texture = HALF_HEART
		elif hearts <= 0.0: icon.texture = EMPTY_HEART
		elif hearts >= 1.0: icon.texture = FULL_HEART
		hearts -= 1.0

func _on_player_hunger_changed(hunger: int) -> void:
	var full_bar : float = player.FULL_HEALTH / 2.0
	var shanks : float = hunger / 2.0
	var difference := full_bar - shanks
	for i in int(full_bar):
		var icon : TextureRect = hunger_bar.get_child(i)
		if difference < 1.0 and difference > 0.0: icon.texture = HALF_SHANK
		elif difference >= 1.0: icon.texture = EMPTY_SHANK
		elif difference <= 0.0: icon.texture = FULL_SHANK
		difference -= 1.0

func _on_player_current_gamemode_changed(Gamemode: Variant) -> void:
	health_bar.visible = false if Gamemode == player.Gamemode.CREATIVE else true
	hunger_bar.visible = false if Gamemode == player.Gamemode.CREATIVE else true
	player.can_freefly = true if Gamemode == player.Gamemode.CREATIVE else false
	if player.freeflying: player.disable_freefly()
