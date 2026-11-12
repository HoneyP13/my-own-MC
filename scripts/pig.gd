class_name Mob
extends CharacterBody3D

@export var max_health := 10
@export var speed := 2.0
@export var drop_id: StringName = &"raw_meat"

var health := max_health
var _dir := Vector3.ZERO
var _timer := 0.0
var _knockback := Vector3.ZERO
@onready var world := get_parent()


func _ready() -> void:
	collision_layer = 2   # mobs live on layer 2 so attack rays can target only them
	collision_mask = 1    # and they collide with terrain


func _physics_process(delta: float) -> void:
	if global_position.y < -20.0: queue_free(); return
	if not is_on_floor(): velocity += get_gravity() * delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.5, 4.0)
		if randf() < 0.4:
			_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_dir = Vector3(cos(a), 0, sin(a))
	velocity.x = _dir.x * speed + _knockback.x
	velocity.z = _dir.z * speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 20.0 * delta)
	if _dir != Vector3.ZERO:
		rotation.y = atan2(-_dir.x, -_dir.z)
		if is_on_wall() and is_on_floor(): velocity.y = 8.0   # hop up one block
	move_and_slide()
	if world.fluid_at(global_position) == &"lava":
		hurt(1, global_position)

func hurt(amount: int, from: Vector3) -> void:
	health -= amount
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 6.0
	velocity.y = 4.0
	if health <= 0:
		if drop_id != &"": world.hud.add_item(drop_id)
		queue_free()
