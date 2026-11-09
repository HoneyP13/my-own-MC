extends Control

enum Area { ARMOR = 1, CRAFTING, INVENTORY, HOTBAR, CRAFT_RESULT }

const HOVER_COLOR := Color(1.0, 1.0, 1.0)
const NORMAL_COLOR := Color(0.576, 0.576, 0.576)

const ROW := "Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/"

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


func _on_mouse(area: Area, slot: int, is_hovered: bool) -> void:
	var s: ColorRect = slots[area][slot]
	s.color = HOVER_COLOR if is_hovered else NORMAL_COLOR
