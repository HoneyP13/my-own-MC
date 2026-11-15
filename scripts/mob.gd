class_name Mob
extends CharacterBody3D

@export var mob_id: StringName
@export var max_health: int
@export var walking_speed: float
@export var running_speed: float = walking_speed
@export var drop_id: StringName
@export var behavior: Behavior
@export var model_node : Node3D
@export var head_pivot : Node3D
@export var FL_pivot : Node3D
@export var FR_pivot : Node3D
@export var BL_pivot : Node3D
@export var BR_pivot : Node3D
# If behavior is Roam, then Flee when attacked
enum Behavior { ROAM, FLEE, HUNT, ATTACK, CHASE, FOLLOW } 
## ROAM: Passive mobs that FLEE once attacked. Hostile mobs HUNT the player, and attack on sight
## They can also CHASE the player if they are near or in line of sight. Pets will FOLLOW their owner, and teleport if needed
var health : int
var _dir := Vector3.ZERO
var _timer := 0.0
var _knockback := Vector3.ZERO
var _lava_timer := 0.0
@onready var world := get_parent()


func _ready() -> void:
	health = max_health
	collision_layer = 2   # mobs live on layer 2 so attack rays can target only them
	collision_mask = 1    # and they collide with terrain


func _physics_process(delta: float) -> void:
	if global_position.y < -20.0: queue_free(); return
	if world.player.is_game_paused: return
	if not is_on_floor(): velocity += get_gravity() * delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.5, 4.0)
		if randf() < 0.4:
			_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_dir = Vector3(cos(a), 0, sin(a))
	velocity.x = _dir.x * walking_speed + _knockback.x
	velocity.z = _dir.z * walking_speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 20.0 * delta)
	if _dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-_dir.x, -_dir.z), minf(delta * 8.0, 1.0))
		if is_on_wall() and is_on_floor(): velocity.y = 8.0   # hop up one block
	_animate_legs(delta)
	move_and_slide()
	if world.fluid_at(global_position) == &"lava":
		_lava_timer -= delta
		if _lava_timer <= 0.0:
			_lava_timer = 0.5
			hurt(2, global_position)
	if world.fluid_at(global_position) == &"water": velocity.y = 4.0

func hurt(amount: int, from: Vector3) -> void:
	if _dead: return
	_flash_red()
	behavior = Behavior.FLEE # for like, 15 seconds, then back to Roam
	health -= amount
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 6.0
	velocity.y = 4.0
	if health <= 0:
		if drop_id != &"": world.spawn_drop(drop_id, 1, global_position + Vector3.UP * 0.5)
		_die()


var _walk_phase := 0.0

func _animate_legs(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_walk_phase += delta * speed * 4.0
	var amount := clampf(speed / maxf(walking_speed, 0.01), 0.0, 1.0)
	var swing := sin(_walk_phase) * 0.6 * amount
	var targets := {FL_pivot: swing, BR_pivot: swing, FR_pivot: -swing, BL_pivot: -swing}
	for leg in targets:
		if leg != null:
			leg.rotation.x = lerpf(leg.rotation.x, targets[leg], minf(delta * 20.0, 1.0))

static var _hurt_overlay: StandardMaterial3D

func _flash_red() -> void:
	if _hurt_overlay == null:
		_hurt_overlay = StandardMaterial3D.new()
		_hurt_overlay.albedo_color = Color(1, 0, 0, 0.4)
		_hurt_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hurt_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var parts := model_node.find_children("*", "MeshInstance3D", true, false)
	for p in parts: p.material_overlay = _hurt_overlay
	await get_tree().create_timer(0.2).timeout
	for p in parts:
		if is_instance_valid(p): p.material_overlay = null


var _dead := false

func _die() -> void:
	_dead = true
	if drop_id != &"": world.spawn_drop(drop_id, 1, global_position + Vector3.UP * 0.5)
	collision_layer = 0                 # can't be hit or blocked while falling over
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(model_node, "rotation:z", PI / 2.0, 0.3)
	tw.tween_callback(queue_free)
