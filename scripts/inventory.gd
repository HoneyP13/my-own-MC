extends Control

var is_holding_items : bool = false
var held_item_name : String

enum Area { ARMOR = 1, CRAFTING, INVENTORY, HOTBAR, CRAFT_RESULT }

const HOVER_COLOR := Color(1.0, 1.0, 1.0)
const NORMAL_COLOR := Color(0.576, 0.576, 0.576)

const ROW := "Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/"

const TERRAIN_MESH_LIBRARY = preload("uid://dgqqtmwpwy6eu")
const ITEM_MESH_LIBRARY = preload("uid://clhu5qdjmtbqa")

@onready var hud: CanvasLayer = $".."
@onready var armor_slots: VBoxContainer = get_node(ROW + "ArmorSlots")
@onready var crafting_slots: GridContainer = get_node(ROW + "InventoryCrafting")
@onready var craft_result: ColorRect = get_node(ROW + "CraftResult")
@onready var inventory: GridContainer = $Inventory/MarginContainer/VBoxContainer/Inventory
@onready var hotbar: HBoxContainer = $Inventory/MarginContainer/VBoxContainer/HotBar

# Area -> Array of slot ColorRects, filled in _ready()
var slots := {}


func _ready() -> void:
	slots = {
		Area.ARMOR: armor_slots.get_children(),
		Area.CRAFTING: crafting_slots.get_children(),
		Area.INVENTORY: inventory.get_children(),
		Area.HOTBAR: hotbar.get_children(),
		Area.CRAFT_RESULT: [craft_result],
	}
	for area in slots:
		for i in slots[area].size():
			var slot: Control = slots[area][i]
			slot.mouse_entered.connect(_on_mouse.bind(area, i, true))
			slot.mouse_exited.connect(_on_mouse.bind(area, i, false))

func _process(_delta: float) -> void:
	if is_holding_items and hud.UIState == hud.UIState.INVENTORY:
		var item : ColorRect = get_node(NodePath("%"+held_item_name))
		item.set_global_position(InputEventMouseMotion.screen_relative)
	#elif is_holding_items and hud.UIState != hud.UIState.INVENTORY: <- Ideally, drop the item.
		
	 


func _on_mouse(area: Area, slot: int, is_hovered: bool) -> void:
	var s: ColorRect = slots[area][slot]
	s.color = HOVER_COLOR if is_hovered else NORMAL_COLOR
	if is_hovered and Input.is_action_just_pressed("hit"): grab_stack(area, slot)



func grab_stack(area: Area, slot: int):
	var s: ColorRect = slots[area][slot]
	var item_name
	if not is_holding_items and s.get_child(0) == null: return
	item_name = s.get_child(0).name
	if is_holding_items and s.get_child(0) != null:
		switch_stack(area, slot, item_name, held_item_name)
		return
	elif is_holding_items and s.get_child(0) == null:
		place_stack(area, slot)
		return
	for old in s.get_children():
		old.queue_free()
	if item_name != null:
		var item := TextureRect.new()
		item.name = item_name
		item.size = Vector2(56, 56)
		item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(item_name))
		held_item_name = item_name
		item.unique_name_in_owner = true
		item.top_level = true
		is_holding_items = true



func place_stack(area: Area, slot: int):
	var s: ColorRect = slots[area][slot]
	var item_name
	#if TERRAIN_MESH_LIBRARY / ITEM_MESH_LIBRARY
	item_name = s.get_child(0).name
	if item_name != null:
		var item := TextureRect.new()
		item.name = item_name
		item.size = Vector2(56, 56)
		item.position = Vector2(4, 4)
		item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(item_name))
		s.add_child(item)
		var ghost : ColorRect = get_node(NodePath("%"+held_item_name))
		ghost.queue_free()
		is_holding_items = false


func switch_stack(area: Area, slot: int, hovered_item: String, held_item: String):
	var s: ColorRect = slots[area][slot]
	for old in s.get_children():
		old.queue_free()
	if hovered_item != null:
		var item := TextureRect.new()
		item.name = held_item
		item.size = Vector2(56, 56)
		item.position = Vector2(4, 4)
		item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(held_item))
		s.add_child(item)
		var hover : ColorRect = get_node(NodePath("%"+held_item_name))
		hover.name = hovered_item
		hover.size = Vector2(56, 56)
		hover.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(hovered_item))
		held_item_name = hovered_item
