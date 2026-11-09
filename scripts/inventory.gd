extends Control

@onready var inventory: GridContainer = $Inventory/MarginContainer/VBoxContainer/Inventory





func _ready() -> void: pass


func _on_mouse(area: int, slot: int, is_hovered: bool) -> void:
	var s : ColorRect
	match area:
		3: s = inventory.get_child(slot)
	s.color = Color(1.0, 1.0, 1.0) if is_hovered else Color(0.576, 0.576, 0.576)
