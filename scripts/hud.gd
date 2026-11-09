extends CanvasLayer

## Which screen is up. This is the ONE place that answers "what's on screen right now?".
## Every panel's visibility, the mouse capture and the pause flag are all worked out from it,
## so they can never disagree with each other. See set_ui_state() / _refresh_ui().
enum UIState { PLAYING, INVENTORY, CHAT, PAUSED, SETTINGS, DEAD }

@onready var world: Node3D = $".."
@onready var player: Player = $"../Player"
@onready var hud_hot_bar: Control = %GameplayHUD
@onready var hot_bar_parent: HBoxContainer = %HotBar
@onready var inventory_menu: Panel = %InventoryMenu
@onready var player_window: PanelContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/PlayerWindow
@onready var armor_slots: VBoxContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/ArmorSlots
@onready var inventory_crafting: GridContainer = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/InventoryCrafting
@onready var craft_result: ColorRect = $InventoryMenu/Inventory/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer2/CraftResult
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


var hotbar := [
	"dirt", "stone", "log", "leaves", null, "cobblestone",
]
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
		hot_bar_parent.get_child(i).color = Color(1, 1, 1, 1) if i == current_hotbar_slot else Color(1, 1, 1, 0.5)
var inventory : Array

const FLUIDS_MESH_LIBRARY = preload("uid://bt86017oxii2w")
const TERRAIN_MESH_LIBRARY = preload("uid://dgqqtmwpwy6eu")

func _init() -> void:
	hotbar.resize(9)
	inventory.resize(27)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.scrolled.connect(_on_player_scrolled)
	player.open_menu.connect(_on_open_menu)
	player.open_inventory.connect(_on_open_inventory)
	player.open_chat.connect(_on_open_chat)
	player.open_debug_info.connect(_on_open_debug_info)
	rebuild_hotbar()
	update_inventory()
	_refresh_ui()


func rebuild_hotbar() -> void:
	for i in hot_bar_parent.get_child_count():
		var slot: ColorRect = hot_bar_parent.get_child(i)
		for old in slot.get_children():
			old.queue_free()
		var item_name = hotbar[i]
		if item_name != null:
			var item := TextureRect.new()
			item.name = item_name
			item.size = Vector2(56, 56)
			item.position = Vector2(4, 4)
			item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(item_name))
			slot.add_child(item)
	_update_hotbar_highlight()	


# ---------------------------------------------------------------------------------------------
# UI state
# ---------------------------------------------------------------------------------------------

## Switch to a different screen. This is the only function that changes ui_state.
func set_ui_state(new_state: UIState) -> void:
	var old_state := ui_state
	ui_state = new_state
	_refresh_ui()
	if old_state == UIState.CHAT and new_state != UIState.CHAT:
		type_interface.release_focus()
	# Tell the player what's going on. Any screen at all frees the mouse and stops it
	# from moving around; only the pause menu actually freezes it.
	player.set_menu_open(new_state != UIState.PLAYING)
	player.set_game_paused(new_state == UIState.PAUSED or new_state == UIState.SETTINGS)


## Show exactly the panels that belong to the current state, and hide the rest.
func _refresh_ui() -> void:
	var s := ui_state
	hud_hot_bar.visible = s != UIState.INVENTORY and s != UIState.DEAD
	inventory_menu.visible = s == UIState.INVENTORY
	chat.visible = s == UIState.CHAT
	menu_bg.visible = s == UIState.PAUSED or s == UIState.SETTINGS
	pause_menu.visible = s == UIState.PAUSED
	settings_menu.visible = s == UIState.SETTINGS
	death_screen.visible = s == UIState.DEAD
	# The debug overlay (toggled with the debug key) hides behind the inventory and pause menus.
	debug_info.visible = world.is_debug_enabled and (s == UIState.PLAYING or s == UIState.CHAT or s == UIState.DEAD)


## Inventory key. Opens the inventory while playing, closes it again, and does nothing anywhere else.
func _on_open_inventory() -> void:
	match ui_state:
		UIState.PLAYING: set_ui_state(UIState.INVENTORY)
		UIState.INVENTORY: set_ui_state(UIState.PLAYING)

func update_inventory() -> void:
	for i in inv.get_child_count():
		var slot: ColorRect = inv.get_child(i)
		for old in slot.get_children():
			old.queue_free()
		var item_name = inventory[i]
		if item_name != null:
			var item := TextureRect.new()
			item.name = item_name
			item.size = Vector2(56, 56)
			item.position = Vector2(4, 4)
			item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(item_name))
			slot.add_child(item)
	for I in inv_hot_bar.get_child_count():
		var slot: ColorRect = inv_hot_bar.get_child(I)
		for old in slot.get_children():
			old.queue_free()
		var item_name = hotbar[I]
		if item_name != null:
			var item := TextureRect.new()
			item.name = item_name
			item.size = Vector2(56, 56)
			item.position = Vector2(4, 4)
			item.texture = TERRAIN_MESH_LIBRARY.get_item_preview(TERRAIN_MESH_LIBRARY.find_item_by_name(item_name))
			slot.add_child(item)



## Escape key (also used by the Resume button): back out of whatever is open.
func _on_open_menu() -> void:
	match ui_state:
		UIState.PLAYING: set_ui_state(UIState.PAUSED)
		UIState.INVENTORY, UIState.CHAT, UIState.PAUSED: set_ui_state(UIState.PLAYING)
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
		match cmd:
			"help":
				_chat_print("Available commands: none")
			_:
				_chat_print("Unknown command: \"" + cmd + "\"")
	else:
		_chat_print("TempUsername > " + new_text)

	type_interface.clear()


## Adds one line to the chat. add_text() shows the text exactly as typed, whereas append_text()
## would treat things like [b] as formatting tags.
func _chat_print(line: String) -> void:
	chat_history.newline()
	chat_history.add_text(line)


func _on_player_is_dead_changed(is_true: bool) -> void:
	set_ui_state(UIState.DEAD if is_true else UIState.PLAYING)
