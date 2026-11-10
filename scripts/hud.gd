extends CanvasLayer

## Which screen is up. This is the ONE place that answers "what's on screen right now?".
## Every panel's visibility, the mouse capture and the pause flag are all worked out from it,
## so they can never disagree with each other. See set_ui_state() / _refresh_ui().
enum UIState { PLAYING, INVENTORY, CHAT, PAUSED, SETTINGS, DEAD }
enum SlotArea { INVENTORY, HOTBAR }

@onready var world: Node3D = $".."
@onready var player: Player = $"../Player"
@onready var health_bar: HBoxContainer = %HealthBar
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
var cursor_item = null          # item name the mouse is holding, or null
var cursor_icon: TextureRect

const SLOT_NORMAL := Color(0.576, 0.576, 0.576)
const SLOT_HOVER := Color(1, 1, 1)
const ICON_SIZE := Vector2(56, 56)
const FULL_HEART = preload("uid://blntmmpygjof2")
const HALF_HEART = preload("uid://cyfclxjq2w87m")
const EMPTY_HEART = preload("uid://d0j2n8w1nl812")

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
		hot_bar_parent.get_child(i).color = Color(1, 1, 1, 1) if i == current_hotbar_slot else Color(1, 1, 1, 0.5)
var inventory : Array

const FLUIDS_MESH_LIBRARY = preload("uid://bt86017oxii2w")
const TERRAIN_MESH_LIBRARY = preload("uid://dgqqtmwpwy6eu")


func _init() -> void:
	hotbar.resize(9)
	inventory.resize(27)


func _ready() -> void:
	player.scrolled.connect(_on_player_scrolled)
	player.open_menu.connect(_on_open_menu)
	player.open_inventory.connect(_on_open_inventory)
	player.open_chat.connect(_on_open_chat)
	player.open_debug_info.connect(_on_open_debug_info)
	_setup_inventory_slots()
	refresh_slots()
	_refresh_ui()


func _setup_inventory_slots() -> void:
	for i in inv.get_child_count():
		_wire_slot(inv.get_child(i), SlotArea.INVENTORY, i)
	for i in inv_hot_bar.get_child_count():
		_wire_slot(inv_hot_bar.get_child(i), SlotArea.HOTBAR, i)

	cursor_icon = TextureRect.new()
	cursor_icon.size = Vector2(56, 56)
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block clicks on slots
	cursor_icon.visible = false
	add_child(cursor_icon)  # added last, so it draws on top


func _wire_slot(slot: ColorRect, area: int, index: int) -> void:
	slot.gui_input.connect(_on_slot_gui_input.bind(area, index))
	slot.mouse_entered.connect(func(): slot.color = SLOT_HOVER)
	slot.mouse_exited.connect(func(): slot.color = SLOT_NORMAL)


func _on_slot_gui_input(event: InputEvent, area: int, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed): return
	var slots: Array = inventory if area == SlotArea.INVENTORY else hotbar
	match event.button_index:
		MOUSE_BUTTON_LEFT: _left_click(slots, index)
		MOUSE_BUTTON_RIGHT: _right_click(slots, index)
		_: return
	refresh_slots()


func _left_click(slots: Array, i: int) -> void:
	var slot = slots[i]
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


func _icon_for(stack: StringName) -> Texture2D:
	return Registry.get_item(stack).icon


func _return_cursor_item() -> void:
	if cursor_item == null: return
	var stack = cursor_item
	cursor_item = null
	add_item(stack.id, stack.count)   # merges into existing stacks, then empty slots


# ---------------------------------------------------------------------------------------------
# UI state
# ---------------------------------------------------------------------------------------------

## Switch to a different screen. This is the only function that changes ui_state.
func set_ui_state(new_state: UIState) -> void:
	var old_state := ui_state
	ui_state = new_state
	_refresh_ui()
	if old_state == UIState.INVENTORY and new_state != UIState.INVENTORY:
		_return_cursor_item()
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
		var arg_1
		match cmd:
			"help":
				if parts.size() == 1:
					_chat_print("Available commands: /clear, /give")
				else:
					arg_1 = parts[1] if parts.size() > 1 else ""
					match arg_1:
						"clear":
							_chat_print("Usage: /clear (clears chat history)")
						"give":
							_chat_print("Usage: /give(self) [item] [amount]")
						_:
							_chat_print("Unknown command: \"" + cmd + "\"")
			"clear":
				chat_history.clear()
			"1hp": # New temp secret command, because I can't get the cube to work
				player.hurt(19)
			"give":
				var item_id := StringName(parts[1]) if parts.size() > 1 else &""
				if Registry.get_item(item_id) == null:
					_chat_print("Unknown item: " + str(item_id))
				else:
					var amount := int(parts[2]) if parts.size() > 2 else 1
					add_item(item_id, amount)
					_chat_print("Gave %s: %d %s" % [player.username, amount, item_id])
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
	var full_bar : int = player.FULL_HEALTH / 2
	var hearts : float = hp / 2
	for i in full_bar:
		var icon : TextureRect = health_bar.get_child(i)
		if hearts == 0.0: icon.texture = EMPTY_HEART
		elif hearts < 1.0 and hearts > 0.0: icon.texture = HALF_HEART
		elif hearts >= 1.0: icon.texture = FULL_HEART
		hearts -= 1.0
