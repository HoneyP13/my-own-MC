class_name Mob
extends CharacterBody3D

@export var mob_id: StringName
@export var max_health: int
@export var walking_speed: float
@export var running_speed: float = walking_speed
@export var drop_id: StringName
@export var behavior: Behavior
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
		rotation.y = atan2(-_dir.x, -_dir.z)
		if is_on_wall() and is_on_floor(): velocity.y = 8.0   # hop up one block
	move_and_slide()
	if world.fluid_at(global_position) == &"lava":
		_lava_timer -= delta
		if _lava_timer <= 0.0:
			_lava_timer = 0.5
			hurt(2, global_position)

func hurt(amount: int, from: Vector3) -> void:
	behavior = Behavior.FLEE # for like, 15 seconds, then back to Roam
	health -= amount
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 6.0
	velocity.y = 4.0
	if health <= 0:
		if drop_id != &"": world.hud.add_item(drop_id)
		queue_free()
