class_name Player
extends CharacterBody3D

@export var username : String
## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = true
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 5.0
## Speed of jump.
@export var jump_velocity : float = 8.0
## How fast do we run?
@export var sprint_speed : float = 7.0
## How fast do we freefly?
@export var freefly_speed : float = 20.0
@export var crouch_speed : float = 2.0
@export var swim_speed : float = 3.0
@export var boat_speed : float = 4.0


@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "strafe left"
## Name of Input Action to move Right.
@export var input_right : String = "strafe right"
## Name of Input Action to move Forward.
@export var input_forward : String = "walk forward"
## Name of Input Action to move Backward.
@export var input_back : String = "walk backward"
## Name of Input Action to Jump.
@export var input_jump : String = "jump"
## Name of Input Action to Sprint.
@export var input_sprint : String = "run"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "debug freefly"
@export var input_crouch : String = "crouch"
@export var input_hit : String = "hit"
@export var input_use : String = "use"
@export var input_open_inventory : String = "open inventory"
@export var input_drop_item : String = "drop item"
@export var input_debug_menu : String = "debug menu"
@export var input_open_chat : String = "open chat"
@export var input_open_command : String = "type command"
@export var input_scroll_up : String = "scroll up"
@export var input_scroll_down : String = "scroll down"
@export var input_select : String = "select block"
@export var input_hide_ui : String = "hide ui"

@export_group("Block Targeting")
## How far (in world units) we can reach to hit/use a block.
@export var reach : float = 5.0

const FULL_HEALTH := 20
const FULL_HUNGER := 20
var health = FULL_HEALTH
var hunger = FULL_HUNGER

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false

var is_moving : bool
## True while any screen (inventory, chat, pause menu, death screen...) is up.
## The world sets this through set_menu_open().
var is_menu_open : bool = false
## True while the pause menu is up. The world sets this through set_game_paused().
var is_game_paused : bool = false
signal is_dead_changed(is_true : bool)
var is_dead : bool = false:
	set(value):
		is_dead = value
		is_dead_changed.emit(is_dead)

## The player only REPORTS what was pressed. The world decides what that means right now
## (e.g. the inventory key closes the inventory, but does nothing on the death screen).
signal open_inventory()
signal open_menu()
signal open_chat(is_command: bool)
signal open_debug_info()
signal player_died()
## Hit / use was pressed while looking around. The world does the targeting (see VoxelRaycast),
## starting from get_eye_position() and looking along get_look_direction().
signal hit_pressed()
signal use_pressed()
signal select_pressed()
signal drop_item_pressed()
signal scrolled(is_up: bool)
enum Gamemode { SURVIVAL, CREATIVE }
signal current_gamemode_changed(Gamemode)
var current_gamemode = Gamemode.SURVIVAL:
	set(value):
		current_gamemode = value
		current_gamemode_changed.emit(current_gamemode)
var can_be_hurt : bool = true
enum { LIQUID, ENTITY, BLOCK }

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var hud: CanvasLayer = $"../HUD"
@onready var world: Node3D = $".."


var is_crouching : bool = false
var crouch_height : float = 1.0
@onready var stand_height : float = collider.shape.height   # 1.8, read from the scene
@onready var head_stand_y : float = head.position.y         # 0.5, read from the scene

func _ready() -> void:
	if username.length() < 4 or username.length() > 18:
		username = "InvalidUser"
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing. React to the click event itself, and let the click that grabs the
	# mouse be only that, so it doesn't also count as a "hit".
	# Only while no screen is up, so clicking around in a menu never grabs the mouse.
	if not mouse_captured and not is_menu_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		capture_mouse()
		return

	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	# Scroll through the hotbar
	if mouse_captured and event.is_action_pressed(input_scroll_up):
		scrolled.emit(true)
	if mouse_captured and event.is_action_pressed(input_scroll_down):
		scrolled.emit(false)
	# Attack, break, use and open
	if mouse_captured and event.is_action_pressed(input_hit):
		hit_pressed.emit()
	if mouse_captured and event.is_action_pressed(input_use):
		use_pressed.emit()
	# Select a block
	if mouse_captured and event.is_action_pressed(input_select):
		select_pressed.emit()
	# Drop an item, but this currently erases it
	if mouse_captured and event.is_action_pressed(input_drop_item):
		drop_item_pressed.emit()
	if mouse_captured and event.is_action_pressed(input_open_chat):
		open_chat.emit(false)
	if mouse_captured and event.is_action_pressed(input_debug_menu):
		open_debug_info.emit()
	if mouse_captured and event.is_action_pressed(input_open_command):
		open_chat.emit(true)

	# These two are always reported (no mouse_captured check), because they have to be able to
	# CLOSE a screen too. The world ignores them when they don't apply.
	if event.is_action_pressed(input_open_inventory):
		open_inventory.emit()
	if event.is_action_pressed("ui_cancel"):
		open_menu.emit()

	# Toggle freefly mode.
	# Use the event itself here, not Input.is_action_just_pressed(): _unhandled_input runs once per
	# event, and "just pressed" stays true for the whole frame, so a mouse move arriving in the same
	# frame as the key press would toggle it twice (on, then straight back off).
	if can_freefly and not is_menu_open and event.is_action_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func _physics_process(delta: float) -> void:
	if is_dead or is_game_paused: return

	# If freeflying, handle freefly and nothing else.
	# (The menu check is nested inside, so opening a screen while flying just stops you moving.
	# Falling through to the gravity code below would drop you through the world, because
	# the collider is switched off while flying.)
	if can_freefly and freeflying:
		if not is_menu_open:
			var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
			var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			motion *= freefly_speed * delta
			move_and_collide(motion)
		return

	# Apply gravity to velocity
	var world := get_parent()
	var fluid: StringName = world.fluid_at(global_position)
	var in_fluid := fluid != &""

	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta * (0.15 if in_fluid else 1.0)
	if in_fluid:
		velocity.y = clampf(velocity.y, -2.0, 4.0)
		if Input.is_action_pressed(input_jump) and not is_menu_open:
			velocity.y = swim_speed
	
	# Apply jumping
	if can_jump and not is_menu_open:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
	
	
	# Hold to crouch; only stand back up if there's room above you
	var want_crouch := Input.is_action_pressed(input_crouch) and not is_menu_open
	if want_crouch and not is_crouching:
		set_crouching(true)
	elif not want_crouch and is_crouching and can_stand():
		set_crouching(false)

	# Modify speed based on sprinting
	# Crouch is checked first so it beats sprint
	if is_crouching:
		move_speed = crouch_speed
	elif can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed
	if in_fluid: move_speed = swim_speed if fluid == &"water" else swim_speed * 0.5
	
	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir and not is_menu_open:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0


	# Use velocity to actually move
	move_and_slide()

var taking_damage := false

var hunger_timer := 0.0
var regen_timer := 0.0
func _process(delta: float) -> void:
	if current_gamemode == Gamemode.CREATIVE: return
	if is_game_paused: return
	elif health < FULL_HEALTH and not is_dead and not taking_damage and is_satiated:
		regen_timer += delta
		if regen_timer >= 3.0:
			regen_timer = 0.0
			hurt(-1)
	elif hunger > 0 and not is_dead:
		hunger_timer += delta
		if hunger_timer >= 50.0:
			hunger_timer = 0.0
			feast(-1)
	else:
		regen_timer = 0.0

# ---------------------------------------------------------------------------------------------
# Things the world asks of the player (the world calls these directly; nothing here is a signal)
# ---------------------------------------------------------------------------------------------

## Where the camera is, in world space. This is where a targeting ray starts.
func get_eye_position() -> Vector3:
	return head.global_position

## The direction we're looking in, in world space (unit length).
## A node looks down its own -Z axis, and the Head carries both the yaw and the pitch.
func get_look_direction() -> Vector3:
	return -head.global_basis.z

## Called by the world whenever a screen opens or closes. Frees the mouse while one is up,
## and grabs it back when you're playing again.
func set_menu_open(is_open: bool) -> void:
	is_menu_open = is_open
	if is_open: release_mouse()
	else: capture_mouse()

## Called by the world while the pause menu is up.
func set_game_paused(paused: bool) -> void:
	is_game_paused = paused

signal health_changed(hp: int)

func hurt(value: int) -> void:
	if value == null or value == 0: return
	if value > 0:
		health = clampi(health - value, 0, FULL_HEALTH)
	if value < 0: # Heals too, I guess
		health = clampi(health + absi(value), 0, FULL_HEALTH)
	health_changed.emit(health)
	if health == 0: die()

signal hunger_changed(value: int)
var is_satiated := true
var is_starving := false
func feast(value: int, item: Variant = null) -> void:
	if value == null or value == 0: return
	if value < 0:
		hunger = clampi(hunger - absi(value), 0, FULL_HUNGER)
	if hunger == FULL_HUNGER: return
	if value > 0:
		hunger = clampi(hunger + value, 0, FULL_HUNGER)
	hunger_changed.emit(hunger)
	if item: world._consume_held_item()
	is_satiated = true if hunger >= 17 else false
	is_starving = true if hunger == 0 else false


## Kill the player. Anything can call this (the void, lava, a health bar hitting zero...).
## The world listens for player_died to show the death screen.
func die() -> void:
	if is_dead: return
	is_dead = true
	velocity = Vector3.ZERO
	hud.inventory.fill(null)
	hud.hotbar.fill(null)
	hud.cursor_item = null
	hud.refresh_slots()
	player_died.emit()

## Bring the player back to life at `pos`.
func respawn(pos: Vector3) -> void:
	velocity = Vector3.ZERO
	global_position = pos
	hurt(-20)
	is_dead = false

func set_crouching(value: bool) -> void:
	is_crouching = value
	var h := crouch_height if value else stand_height
	collider.shape.height = h
	# The capsule is centred on the body, so shift collider + camera to keep your feet planted
	collider.position.y = -(stand_height - h) / 2.0
	head.position.y = head_stand_y - (stand_height - h)

func can_stand() -> bool:
	# Sweep the crouched body upward; if it hits something, there's no headroom
	return not test_move(global_transform, Vector3.UP * (stand_height - crouch_height))

## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false

func _on_is_dead_changed(is_true: bool) -> void:
	if is_true: hud._chat_print(username+" died.")

func _on_current_gamemode_changed(gamemode: Variant) -> void:
	can_be_hurt = false if gamemode == Gamemode.CREATIVE else true
