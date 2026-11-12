extends Node


var save_icons : Array[Image]


func save_capture() -> void:
	for i in save_icons:
		i.save_png("res://save_icon.png")
