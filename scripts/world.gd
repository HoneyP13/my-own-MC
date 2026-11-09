extends Node3D

const SAVE_PATH := "user://world_save.dat"
const SAVE_VERSION := 1

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var grid_map: GridMap = $Terrain
@onready var fluids_map: GridMap = $Fluids
@onready var object_info: Label = $HUD/DebugInfo/object_info
@onready var save_quit_button: Button = $HUD/MenuBG/PauseMenu/Save
@onready var respawn_button: Button = $HUD/DeathScreen/CenterContainer/VBoxContainer/resume
@onready var death_quit_button: Button = $HUD/DeathScreen/CenterContainer/VBoxContainer/quit

var is_debug_enabled : bool = false
var spawnpoint := Vector3(0, 5, 0)


func _ready() -> void:
	player.hit_pressed.connect(_on_player_hit_pressed)
	player.use_pressed.connect(_on_player_use_pressed)
	player.select_pressed.connect(_on_player_select_pressed)
	player.drop_item_pressed.connect(_on_player_drop_item_pressed)
	save_quit_button.pressed.connect(_on_save_quit_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	death_quit_button.pressed.connect(get_tree().quit)
	load_game()


func _on_save_quit_pressed() -> void:
	save_game()
	get_tree().quit()


# --- Dying and respawning ---------------------------------------------------

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player: player.die()


func _on_character_body_3d_player_died() -> void:
	hud.set_ui_state(hud.UIState.DEAD)


func _on_respawn_pressed() -> void:
	if hud.ui_state != hud.UIState.DEAD: return
	player.respawn(spawnpoint)
	hud.set_ui_state(hud.UIState.PLAYING)


# --- Targeting blocks -------------------------------------------------------

func get_targeted_block() -> VoxelRaycast.Hit:
	return VoxelRaycast.cast_ray(grid_map, player.get_eye_position(), player.get_look_direction(), player.reach)


func _on_player_hit_pressed() -> void:
	var target := get_targeted_block()
	if target == null or grid_map.mesh_library.get_item_name(target.item) == "bedrock" : return
	object_info.set_text(str(target.cell, " ", target.normal, " ", target.place_cell))
	grid_map.set_cell_item(target.cell, GridMap.INVALID_CELL_ITEM)


func _on_player_use_pressed() -> void:
	var target := get_targeted_block()
	if target == null or hud.held_item == null: return
	object_info.set_text(str(target.cell, " ", target.normal, " ", target.place_cell))
	
	var item_id := grid_map.mesh_library.find_item_by_name(hud.held_item)
	if item_id == GridMap.INVALID_CELL_ITEM: return
	
	var cell := target.place_cell
	if grid_map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM: return  # ray started inside a block
	if _cell_overlaps_player(cell): return
	
	var orientation := 0
	if hud.held_item == "log":
		orientation = _log_orientation(target.normal)
	grid_map.set_cell_item(cell, item_id, orientation)


## Orientation index that points a log's end caps along the clicked face.
## Both caps use the same texture, so we only care about the axis, not the sign.
func _log_orientation(normal: Vector3i) -> int:
	var b := Basis.IDENTITY                       # clicked top/bottom: upright
	if normal.x != 0:
		b = Basis(Vector3.BACK, PI / 2.0)         # clicked an X face: lay it along X
	elif normal.z != 0:
		b = Basis(Vector3.RIGHT, PI / 2.0)        # clicked a Z face: lay it along Z
	return grid_map.get_orthogonal_index_from_basis(b)


func _on_player_select_pressed() -> void:
	var target := get_targeted_block()
	if target == null: return
	object_info.set_text(str(target.cell, " ", target.normal, " ", target.place_cell))

	var item_name := grid_map.mesh_library.get_item_name(target.item)
	if item_name == "": return
	hud.hotbar[hud.current_hotbar_slot] = item_name
	hud.rebuild_hotbar()


func _on_player_drop_item_pressed() -> void:
	#var item_id := grid_map.mesh_library.find_item_by_name(hud.held_item)
	#if item_id == GridMap.INVALID_CELL_ITEM: return
	hud.hotbar[hud.current_hotbar_slot] = null
	hud.rebuild_hotbar()



func _cell_overlaps_player(cell: Vector3i) -> bool:
	var center := grid_map.to_global(grid_map.map_to_local(cell))
	var cell_box := AABB(center - Vector3.ONE * 0.5, Vector3.ONE)
	var player_box := AABB(player.global_position - Vector3(0.4, 0.9, 0.4), Vector3(0.8, 1.8, 0.8))
	return cell_box.intersects(player_box)


func world_to_cell(world_pos: Vector3) -> Vector3i:
	return grid_map.local_to_map(grid_map.to_local(world_pos))


# --- Save / load ------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"terrain": _pack_grid(grid_map),
		"fluids": _pack_grid(fluids_map),
		"player_pos": player.global_position,
		"player_look": player.look_rotation,
		"hotbar": hud.hotbar,
		"slot": hud.current_hotbar_slot,
		"inventory": hud.inventory,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Couldn't save: " + error_string(FileAccess.get_open_error()))
		return
	f.store_var(data)


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != SAVE_VERSION:
		push_warning("Save file missing or from another version, ignoring it.")
		return false

	_unpack_grid(grid_map, data["terrain"])
	_unpack_grid(fluids_map, data["fluids"])

	player.velocity = Vector3.ZERO
	player.global_position = data["player_pos"]
	player.look_rotation = data["player_look"]
	player.rotate_look(Vector2.ZERO)  # re-applies look_rotation to the body and head

	hud.hotbar = data["hotbar"]
	hud.inventory = data["inventory"]
	hud.current_hotbar_slot = data["slot"]
	hud.rebuild_hotbar()
	return true


# Each cell is stored as 5 ints: x, y, z, item, orientation
func _pack_grid(grid: GridMap) -> PackedInt32Array:
	var out := PackedInt32Array()
	for cell in grid.get_used_cells():
		out.append(cell.x)
		out.append(cell.y)
		out.append(cell.z)
		out.append(grid.get_cell_item(cell))
		out.append(grid.get_cell_item_orientation(cell))
	return out


func _unpack_grid(grid: GridMap, packed: PackedInt32Array) -> void:
	grid.clear()
	for i in range(0, packed.size(), 5):
		grid.set_cell_item(Vector3i(packed[i], packed[i + 1], packed[i + 2]), packed[i + 3], packed[i + 4])


func _on_player_is_dead_changed(is_true: bool) -> void:
	pass # Replace with function body.
