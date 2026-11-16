extends Control

@onready var title_screen: CenterContainer = $TitleScreen
@onready var saves: MarginContainer = $Saves
@onready var world_options: HBoxContainer = $Saves/WorldOptions
@onready var texture_rect: TextureRect = $Saves/PanelContainer/Button/HBoxContainer/TextureRect
@onready var play: Button = $Saves/WorldOptions/Button
@onready var edit: Button = $Saves/WorldOptions/Button2
@onready var create: Button = $Saves/WorldOptions/Button3
@onready var bg: Panel = $BG

enum UI { MAIN, SAVES, SETTINGS, EDIT }
var ui_state := UI.MAIN
var save_names: Array
var selected_world = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_ui_state(UI.MAIN)
	if FileAccess.file_exists("user://save_icon.png"):
		texture_rect.texture = ImageTexture.create_from_image(Image.load_from_file("user://save_icon.png"))
	texture_rect.size = Vector2i(128, 128)
	

func set_ui_state(s: UI):
	var old_state := ui_state
	match s:
		UI.MAIN, UI.SAVES, UI.EDIT:
			title_screen.visible = false if s != UI.MAIN else true
			saves.visible = true if s != UI.MAIN else false
			create.visible = true if s == UI.SAVES else false
			play.visible = true if s == UI.EDIT else false
			edit.visible = true if s == UI.EDIT else false
	ui_state = s

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ui_state != UI.MAIN:
		set_ui_state(UI.MAIN)
	if event.is_action_pressed("fullscreen toggle"):
		var f : bool = Global.settings["fullscreen"]
		get_window().mode = Window.MODE_WINDOWED if f else Window.MODE_FULLSCREEN
		Global.settings["fullscreen"] = false if f else true


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_singleplayer_pressed() -> void:
	set_ui_state(UI.SAVES)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_world_button_toggled(toggled_on: bool) -> void:
	selected_world = "World 1"
	Global.save_path = "user://world_save.dat"
	set_ui_state(UI.EDIT if toggled_on else UI.SAVES)
