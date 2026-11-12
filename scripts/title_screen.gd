extends Control

@onready var title_screen: CenterContainer = $TitleScreen
@onready var saves: MarginContainer = $Saves
@onready var world_options: HBoxContainer = $Saves/WorldOptions
@onready var texture_rect: TextureRect = $Saves/PanelContainer/HBoxContainer/TextureRect

enum UI { MAIN, SAVES, SETTINGS, EDIT }
var ui_state := UI.MAIN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$BG.show()
	title_screen.show()
	#var dir = DirAccess.open("user://save_icon.png")
	#if dir:
	texture_rect.texture = load("res://save_icon.png")
	texture_rect.size = Vector2i(128, 128)
	

func set_ui_state(s: UI):
	match s:
		UI.MAIN, UI.SAVES:
			title_screen.visible = true if ui_state == UI.SAVES else false
			saves.visible = true if ui_state == UI.MAIN else false
			ui_state = s

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ui_state == UI.SAVES:
		set_ui_state(UI.MAIN)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_singleplayer_pressed() -> void:
	set_ui_state(UI.SAVES)


func _on_quit_pressed() -> void:
	get_tree().quit()
