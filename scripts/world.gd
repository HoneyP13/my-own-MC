extends Node3D

const SAVE_PATH := "user://world_save.dat"
const SAVE_VERSION := 2
const WORLD_RADIUS_CHUNKS := 3   # world is (2*3)x(2*3) chunks = 96x96 blocks. Raise it later.
const NEIGHBORS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]

enum World { OVERWORLD }
var dimension := World.OVERWORLD
var generator: TerrainGenerator
var world_seed := 0
var _broken := {}   # cells the player has dug out, so we never "refill" them
const MIN_BUILD_HEIGHT := 0
const MAX_BUILD_HEIGHT := 64
const SEA_LEVEL := 10

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var grid_map: GridMap = $Terrain
@onready var fluids_map: GridMap = $Fluids
@onready var object_info: Label = $HUD/DebugInfo/object_info
@onready var save_quit_button: Button = $HUD/MenuBG/PauseMenu/Save
@onready var respawn_button: Button = $HUD/DeathScreen/CenterContainer/VBoxContainer/resume
@onready var death_quit_button: Button = $HUD/DeathScreen/CenterContainer/VBoxContainer/quit

var is_debug_enabled : bool = false
var spawnpoint : Vector3

const PIG_SCENE := preload("res://scenes/pig.tscn")
const CHICKEN_SCENE := preload("res://scenes/chicken.tscn")
const COW_SCENE = preload("uid://y4kxawccfa18")
const SHEEP_SCENE = preload("uid://r3pfy4dfhvjo")

func _ready() -> void:
	player.hit_pressed.connect(_on_player_hit_pressed)
	player.use_pressed.connect(_on_player_use_pressed)
	player.select_pressed.connect(_on_player_select_pressed)
	player.drop_item_pressed.connect(_on_player_drop_item_pressed)
	save_quit_button.pressed.connect(_on_save_quit_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	death_quit_button.pressed.connect(get_tree().quit)
	if fluids_map.mesh_library == null:
		fluids_map.mesh_library = preload("uid://bt86017oxii2w")
	_setup_water_surface()
	if not load_game():
		world_seed = randi()
		generator = TerrainGenerator.new(world_seed, SEA_LEVEL)
		generate_world()
	for b in Registry.blocks.values():
		if grid_map.mesh_library.find_item_by_name(b.mesh_name) == GridMap.INVALID_CELL_ITEM:
			push_warning("Block '%s': no mesh '%s' in terrain library" % [b.id, b.mesh_name])
	spawn_mobs.call_deferred()
	_setup_outline()
	_setup_crack()

var outline: MeshInstance3D

func _setup_outline() -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 8:
		var a := (Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1) - Vector3.ONE * 0.5) * 1.005
		for bit in [1, 2, 4]:
			if i & bit == 0:
				var j: int = i | bit
				var b := (Vector3(j & 1, (j >> 1) & 1, (j >> 2) & 1) - Vector3.ONE * 0.5) * 1.005
				im.surface_add_vertex(a)
				im.surface_add_vertex(b)
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_set_material(0, mat)
	outline = MeshInstance3D.new()
	outline.mesh = im
	outline.visible = false
	add_child(outline)

func _setup_water_surface() -> void:
	var lib := fluids_map.mesh_library
	if lib.find_item_by_name("water_surface") != GridMap.INVALID_CELL_ITEM: return
	var water_id := lib.find_item_by_name("water")
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	plane.material = lib.get_item_mesh(water_id).material
	var id := lib.get_last_unused_item_id()
	lib.create_item(id)
	lib.set_item_name(id, "water_surface")
	lib.set_item_mesh(id, plane)
	lib.set_item_mesh_transform(id, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)))
	lib.set_item_mesh(water_id, null)   # interior water: logic only, nothing drawn

@onready var env: Environment = $Environment.environment

func fluid_at(pos: Vector3) -> StringName:
	var local := fluids_map.to_local(pos)
	var cell := fluids_map.local_to_map(local)
	var item := fluids_map.get_cell_item(cell)
	if item == GridMap.INVALID_CELL_ITEM: return &""
	match fluids_map.mesh_library.get_item_name(item):
		"lava": return &"lava"
		"water": return &"water"
		"water_surface":
			return &"water" if local.y - cell.y < 0.9 else &""   # above the plane = out of the water
	return &""

func _update_fog() -> void:
	var f := fluid_at(player.get_eye_position())
	env.fog_enabled = f != &""
	if f == &"water":
		env.fog_light_color = Color(0.1, 0.3, 0.6); env.fog_density = 0.08
	elif f == &"lava":
		env.fog_light_color = Color(0.9, 0.3, 0.05); env.fog_density = 0.6

const MOB_COUNT := 12
const ATTACK_DAMAGE := 2

func spawn_mobs() -> void:
	var half := WORLD_RADIUS_CHUNKS * TerrainGenerator.CHUNK_SIZE
	var spawned := 0
	for _try in 300:
		if spawned >= MOB_COUNT: break
		var x := randi_range(-half, half - 1)
		var z := randi_range(-half, half - 1)
		var h := generator.height_at(x, z)
		if h <= SEA_LEVEL + 1 or generator.has_tree(x, z): continue
		var mob: Mob
		var f = randf()
		if f < 0.25: mob = CHICKEN_SCENE.instantiate()
		elif f < 0.5: mob = COW_SCENE.instantiate()
		elif f < 0.75: mob = SHEEP_SCENE.instantiate()
		else: mob = PIG_SCENE.instantiate()
		add_child(mob)
		mob.global_position = Vector3(x + 0.5, h + 1.5, z + 0.5)
		spawned += 1

func _raycast_mobs() -> Dictionary:
	var from := player.get_eye_position()
	var to := from + player.get_look_direction() * player.reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 2)   # mask: layer 2 only
	return get_world_3d().direct_space_state.intersect_ray(q)

func _on_save_quit_pressed() -> void:
	save_game()
	var save_icon : Image
	await RenderingServer.frame_post_draw
	save_icon = player.get_viewport().get_texture().get_image()
	Global.save_icons.append(save_icon)
	Global.save_capture()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# --- Dying and respawning ---------------------------------------------------

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player: entered_void = true
	
func _on_void_body_exited(body: Node3D) -> void:
	if body == player: entered_void = false

var entered_void : bool = false
var hurt_timer := 0.0
const LAVA_DAMAGE := 2
const LAVA_INTERVAL := 0.5
const STARVING_DAMAGE := 1
const STARVING_INTERVAL := 5.0

func _process(delta: float) -> void:
	if player.is_game_paused: return
	var t := get_targeted_block()
	outline.visible = t != null and hud.ui_state == hud.UIState.PLAYING
	if outline.visible:
		outline.global_position = grid_map.to_global(grid_map.map_to_local(t.cell))
	_update_breaking(delta)
	_update_fog()
	_tick_furnaces(delta)
	var in_lava := fluid_at(player.global_position) == &"lava" \
		or fluid_at(player.global_position + Vector3.DOWN * 0.8) == &"lava"
	if (entered_void or in_lava or player.is_starving) and not player.is_dead and player.can_be_hurt:
		player.taking_damage = true
		hurt_timer += delta
		var interval := LAVA_INTERVAL if in_lava else STARVING_INTERVAL if player.is_starving else 0.8
		if hurt_timer >= interval:
			hurt_timer = 0.0
			player.hurt(LAVA_DAMAGE if in_lava else STARVING_DAMAGE if player.is_starving else 5)
	else:
		hurt_timer = 0.0
		player.taking_damage = false

func _on_character_body_3d_player_died() -> void:
	hud.set_ui_state(hud.UIState.DEAD)

func _on_respawn_pressed() -> void:
	if hud.ui_state != hud.UIState.DEAD: return
	player.respawn(spawnpoint)
	hud.set_ui_state(hud.UIState.PLAYING)

func _on_player_is_dead_changed(is_true: bool) -> void:
	if is_true: _on_character_body_3d_player_died()

# --- Targeting blocks -------------------------------------------------------

func get_targeted_block() -> VoxelRaycast.Hit:
	return VoxelRaycast.cast_ray(grid_map, player.get_eye_position(), player.get_look_direction(), player.reach)

func _on_player_hit_pressed() -> void:
	var mob := _mob_in_front(get_targeted_block())
	if mob != null:
		mob.hurt(ATTACK_DAMAGE, player.global_position)

var furnaces := {}  # Vector3i -> {slots=[input,fuel,output], burn, burn_max, cook}

func _tick_furnaces(delta: float) -> void:   # call from _process
	for cell in furnaces:
		var f = furnaces[cell]
		var s: Array = f.slots
		var out_id = hud.SMELTING.get(s[0].id) if s[0] else null
		var can: bool = out_id != null and (s[2] == null or (s[2].id == out_id \
			and s[2].count < Registry.get_item(out_id).max_stack))
		if f.burn <= 0.0 and can and s[1] != null and hud.FUEL.has(s[1].id):
			f.burn = hud.FUEL[s[1].id]; f.burn_max = f.burn
			s[1].count -= 1
			if s[1].count <= 0: s[1] = null
		if f.burn > 0.0:
			f.burn -= delta
			f.cook = f.cook + delta if can else 0.0
			if f.cook >= 10.0:
				f.cook = 0.0
				s[0].count -= 1
				if s[0].count <= 0: s[0] = null
				if s[2] == null: s[2] = {"id": out_id, "count": 1}
				else: s[2].count += 1
		else:
			f.cook = 0.0

func _on_player_use_pressed() -> void:
	var target := get_targeted_block()
	var hit_block : BlockDef
	if target != null: hit_block = _block_for_item(target.item)
	if hit_block != null and hit_block.id == &"crafting_table" and not player.is_crouching:
		hud.set_ui_state(hud.UIState.CONTAINER)
		return
	if hit_block != null and hit_block.id == &"furnace" and not player.is_crouching:
		if not furnaces.has(target.cell):
			furnaces[target.cell] = {"slots": [null, null, null], "burn": 0.0, "burn_max": 0.0, "cook": 0.0}
		hud.open_furnace(furnaces[target.cell].slots)
		return
	if target != null:
		if target.place_cell.y < MIN_BUILD_HEIGHT:
			hud._chat_print("Cannot build below Y:0")
			return
		if target.place_cell.y > MAX_BUILD_HEIGHT:
			hud._chat_print("Cannot build above Y:64")
			return
	if hud.held_item == null: return
	if target == null:
		if Registry.get_item(hud.held_item.id).on_use != ItemDef.Use.FEED_PLAYER:
			return
	var def := Registry.get_item(hud.held_item.id)
	if def == null: return
	if def.use_on_block(self, target) and def is BlockItemDef:
		_consume_held_item()

func _consume_held_item() -> void:
	var slot = hud.current_hotbar_slot
	hud.hotbar[slot].count -= 1
	if hud.hotbar[slot].count <= 0:
		hud.hotbar[slot] = null
	hud.refresh_slots()

func place_block(block_id: StringName, hit: VoxelRaycast.Hit) -> bool:
	var block: BlockDef = Registry.get_block(block_id)
	if block == null: return false
	var item_id := grid_map.mesh_library.find_item_by_name(block.mesh_name)
	var cell := hit.place_cell
	if item_id == GridMap.INVALID_CELL_ITEM: return false
	if grid_map.get_cell_item(cell) != GridMap.INVALID_CELL_ITEM: return false
	if _cell_overlaps_player(cell): return false
	var orientation := 0
	match block_id:
		&"log": orientation = _log_orientation(hit.normal)
		&"chest", &"furnace": orientation = _facing_orientation()
	grid_map.set_cell_item(cell, item_id, orientation)
	return true

func _facing_orientation() -> int:
	var yaw := roundf(player.look_rotation.y / (PI / 2.0)) * (PI / 2.0)
	return grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, yaw))

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
	var block: BlockDef = Registry.blocks_by_mesh.get(grid_map.mesh_library.get_item_name(target.item))
	if block == null: return
	var def := Registry.get_item(block.id)
	if def == null: return
	hud.hotbar[hud.current_hotbar_slot] = {"id": block.id, "count": def.max_stack}
	hud.refresh_slots()

func _on_player_drop_item_pressed() -> void:
	#var item_id := grid_map.mesh_library.find_item_by_name(hud.held_item)
	#if item_id == GridMap.INVALID_CELL_ITEM: return
	hud.hotbar[hud.current_hotbar_slot] = null
	hud.refresh_slots()

func _cell_overlaps_player(cell: Vector3i) -> bool:
	var center := grid_map.to_global(grid_map.map_to_local(cell))
	var cell_box := AABB(center - Vector3.ONE * 0.5, Vector3.ONE)
	var player_box := AABB(player.global_position - Vector3(0.4, 0.9, 0.4), Vector3(0.8, 1.8, 0.8))
	return cell_box.intersects(player_box)

func world_to_cell(world_pos: Vector3) -> Vector3i:
	return grid_map.local_to_map(grid_map.to_local(world_pos))

const CRACK_STAGES := 10
const NO_CELL := Vector3i(0, -999999, 0)
const TOOL_SPEED := {"wooden": 2.0, "stone": 4.0, "iron": 6.0, "diamond": 8.0, "golden": 12.0}

var _break_cell := NO_CELL
var _break_progress := 0.0
var _break_cooldown := 0.0
var _crack: MeshInstance3D
var _crack_mat: ShaderMaterial
var _crack_textures: Array[ImageTexture] = []

func _setup_crack() -> void:
	# Random pixels get darker as the stage goes up. Swap in your own textures here later.
	var order := range(256)
	order.shuffle()
	var rank := PackedInt32Array()
	rank.resize(256)
	for k in 256:
		rank[order[k]] = k
	for s in CRACK_STAGES:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var limit := int(256 * 0.55 * (s + 1) / CRACK_STAGES)
		for i in 256:
			if rank[i] < limit:
				img.set_pixel(i % 16, i / 16, Color(0, 0, 0, 0.65))
		_crack_textures.append(ImageTexture.create_from_image(img))

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform sampler2D crack_tex : filter_nearest, repeat_disable;
varying vec3 p;
varying vec3 n;
void vertex() { p = VERTEX + vec3(0.5); n = NORMAL; }
void fragment() {
	vec3 a = abs(n);
	vec2 uv = (a.x >= a.y && a.x >= a.z) ? p.zy : ((a.y >= a.z) ? p.xz : p.xy);
	vec4 c = texture(crack_tex, uv);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
	_crack_mat = ShaderMaterial.new()
	_crack_mat.shader = shader
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.003
	_crack = MeshInstance3D.new()
	_crack.mesh = box
	_crack.material_override = _crack_mat
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack.visible = false
	add_child(_crack)

func _block_for_item(item: int) -> BlockDef:
	return Registry.blocks_by_mesh.get(grid_map.mesh_library.get_item_name(item))

## Seconds needed to break `block` with whatever is in the player's hand.
func _break_time(block: BlockDef) -> float:
	if player.current_gamemode == player.Gamemode.CREATIVE: return 0.0
	var speed := 1.0
	var held = hud.held_item
	if held != null:
		var parts := String(held.id).split("_", false, 1)   # "stone_pickaxe" -> ["stone", "pickaxe"]
		if parts.size() == 2 and StringName(parts[1]) == block.tool_kind and TOOL_SPEED.has(parts[0]):
			speed = TOOL_SPEED[parts[0]]
	return block.hardness / speed

func _mob_in_front(target: VoxelRaycast.Hit) -> Mob:
	var mob_hit := _raycast_mobs()
	if mob_hit.is_empty(): return null
	var d := player.get_eye_position().distance_to(mob_hit.position)
	if target == null or d < target.distance:
		return mob_hit.collider as Mob
	return null

func _stop_breaking() -> void:
	_break_cell = NO_CELL
	_break_progress = 0.0
	_crack.visible = false

func _update_breaking(delta: float) -> void:
	_break_cooldown = maxf(_break_cooldown - delta, 0.0)
	var holding : bool = Input.is_action_pressed(player.input_hit) and player.mouse_captured \
		and hud.ui_state == hud.UIState.PLAYING
	var t: VoxelRaycast.Hit = get_targeted_block() if holding else null
	if t == null or _mob_in_front(t) != null:
		_stop_breaking()
		return
	var block := _block_for_item(t.item)
	if block == null or block.hardness < 0.0:
		_stop_breaking()
		return
	if t.cell != _break_cell:
		_break_cell = t.cell
		_break_progress = 0.0
	if _break_cooldown > 0.0: return
	_break_progress += delta
	var needed := _break_time(block)
	if _break_progress >= needed:
		_break_block(t.cell, block)
		_stop_breaking()
		_break_cooldown = 0.25
		return
	_crack.global_position = grid_map.to_global(grid_map.map_to_local(t.cell))
	var stage := clampi(int(_break_progress / needed * CRACK_STAGES), 0, CRACK_STAGES - 1)
	_crack_mat.set_shader_parameter("crack_tex", _crack_textures[stage])
	_crack.visible = true

func _break_block(cell: Vector3i, block: BlockDef) -> void:
	var tiers := [&"wooden", &"stone", &"iron", &"diamond"]
	grid_map.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
	_broken[cell] = true
	_reveal_neighbors(cell)
	if block.id == &"furnace" and furnaces.has(cell):
		for stack in furnaces[cell].slots:
			if stack != null: hud.add_item(stack.id, stack.count)
		furnaces.erase(cell)
	if block.drop_id != &"" and randi() % 100 < block.drop_chance:
		hud.add_item(block.drop_id)
	if block.drop_id_2 != &"" and randi() % 100 < block.drop_chance_2:
		hud.add_item(block.drop_id_2)

# --- Save / load ------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"terrain": _pack_grid(grid_map),
		"fluids": _pack_grid(fluids_map),
		"player_pos": player.global_position,
		"player_look": player.look_rotation,
		"gamemode": player.current_gamemode,
		"hotbar": hud.hotbar,
		"player_health": player.health,
		"player_hunger": player.hunger,
		"slot": hud.current_hotbar_slot,
		"inventory": hud.inventory,
		"seed": world_seed,
		"broken": _pack_broken(),
		"furnaces": furnaces,
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
	
	world_seed = data["seed"]
	generator = TerrainGenerator.new(world_seed, SEA_LEVEL)
	_unpack_broken(data["broken"])
	_unpack_grid(grid_map, data["terrain"])
	_unpack_grid(fluids_map, data["fluids"])

	spawnpoint = generator.find_spawn()
	furnaces = data.get("furnaces", {})
	player.velocity = Vector3.ZERO
	player.global_position = data["player_pos"]
	player.look_rotation = data["player_look"]
	player.health = data["player_health"]
	player.hunger = data["player_hunger"]
	player.rotate_look(Vector2.ZERO)  # re-applies look_rotation to the body and head
	player.current_gamemode = data["gamemode"]

	hud.hotbar = data["hotbar"]
	hud.inventory = data["inventory"]
	hud.current_hotbar_slot = data["slot"]
	hud.refresh_slots()
	return true

func generate_world() -> void:
	grid_map.clear()
	fluids_map.clear()
	_broken.clear()
	for cx in range(-WORLD_RADIUS_CHUNKS, WORLD_RADIUS_CHUNKS):
		for cz in range(-WORLD_RADIUS_CHUNKS, WORLD_RADIUS_CHUNKS):
			generator.generate_chunk(Vector2i(cx, cz), grid_map, fluids_map)
	spawnpoint = generator.find_spawn()
	player.velocity = Vector3.ZERO
	player.global_position = spawnpoint
	furnaces.clear()

func _pack_broken() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c: Vector3i in _broken:
		out.append(c.x); out.append(c.y); out.append(c.z)
	return out

func _unpack_broken(packed: PackedInt32Array) -> void:
	_broken.clear()
	for i in range(0, packed.size(), 3):
		_broken[Vector3i(packed[i], packed[i + 1], packed[i + 2])] = true

## Digging exposes cells we skipped when generating. Put the natural terrain back around the hole.
func _reveal_neighbors(cell: Vector3i) -> void:
	for n in NEIGHBORS:
		var c := cell + n
		if c.y < MIN_BUILD_HEIGHT or _broken.has(c): continue
		if grid_map.get_cell_item(c) != GridMap.INVALID_CELL_ITEM: continue
		var block_name := generator.block_at(c.x, c.y, c.z)
		if block_name == &"": continue
		var item := grid_map.mesh_library.find_item_by_name(String(block_name))
		if item != GridMap.INVALID_CELL_ITEM:
			grid_map.set_cell_item(c, item)

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
