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

## These only matter for hostile mobs. Leave them at 0 in the scene and the PRESETS below fill them in.
@export_group("Hostile")
@export var attack_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_cooldown: float = 0.0
@export var sight_range: float = 0.0
@export var burns_in_daylight := false
@export var explodes := false
@export var fuse_time: float = 0.0
@export var explosion_radius: float = 0.0

## ROAM:   passive mobs wander. When hurt they FLEE for a while, then go back to ROAM.
## HUNT:   hostile mobs wander too, but scan for the player. The moment they notice one they CHASE.
## CHASE:  run at the player. Close enough -> ATTACK. Lose them for a few seconds -> back to HUNT.
## ATTACK: zombies strike on a cooldown; creepers stand still and light their fuse.
## FOLLOW: (pets) not written yet, acts like ROAM.
enum Behavior { ROAM, FLEE, HUNT, ATTACK, CHASE, FOLLOW }

## Stats for the hostile mobs, keyed by mob_id. They fill in only what the scene left at 0, so
## anything you set on the scene itself wins. `behavior` is always forced to HUNT for these.
const PRESETS := {
	&"zombie": {
		"max_health": 20, "walking_speed": 1.8, "running_speed": 3.1,
		"attack_damage": 3, "attack_range": 1.7, "attack_cooldown": 1.0,
		"sight_range": 18.0, "burns_in_daylight": true,
	},
	&"creeper": {
		"max_health": 20, "walking_speed": 2.0, "running_speed": 3.0,
		"attack_range": 3.0, "sight_range": 16.0,
		"explodes": true, "fuse_time": 1.5, "explosion_radius": 3.0,
	},
}

const FLEE_TIME := 15.0
const FORGET_TIME := 5.0    # how long a chasing mob keeps going after it loses sight of you

var health : int
var hostile := false
var _dir := Vector3.ZERO
var _timer := 0.0
var _knockback := Vector3.ZERO
var _lava_timer := 0.0
var _flee_from := Vector3.ZERO
var _flee_timer := 0.0
var _attack_timer := 0.0
var _sight_timer := 0.0
var _sees_player := false
var _lost_timer := 0.0
var _burn_timer := 1.0
var _fuse := -1.0    # < 0 means "not lit"
@onready var world := get_parent()


static func is_hostile_id(id: StringName) -> bool:
	return PRESETS.has(id)


func _ready() -> void:
	_apply_preset()
	health = max_health
	collision_layer = 2   # mobs live on layer 2 so attack rays can target only them
	collision_mask = 1    # and they collide with terrain
	add_to_group("mobs")
	if hostile:
		add_to_group("hostile")
	if running_speed <= 0.0:
		running_speed = walking_speed * 1.6


func _apply_preset() -> void:
	if not PRESETS.has(mob_id):
		hostile = behavior == Behavior.HUNT or behavior == Behavior.CHASE or behavior == Behavior.ATTACK
		return
	hostile = true
	behavior = Behavior.HUNT
	var preset: Dictionary = PRESETS[mob_id]
	for key: String in preset:
		if not get(key):    # 0, 0.0 and false all count as "scene didn't set this"
			set(key, preset[key])
	# Scenes tend to copy walking_speed into running_speed, which would make a mob chase you no
	# faster than it wanders. For hostile mobs, "running <= walking" is treated as "not set".
	if running_speed <= walking_speed and preset.has("running_speed"):
		running_speed = maxf(preset["running_speed"], walking_speed * 1.5)


func _physics_process(delta: float) -> void:
	if global_position.y < -20.0: queue_free(); return
	var player: Player = world.player
	if player.is_game_paused: return
	if not is_on_floor(): velocity += get_gravity() * delta
	_attack_timer -= delta

	# A player who can't be hurt (creative, flying, dead) is not a target. Give up at once, otherwise
	# CHASE and ATTACK would hand the mob back and forth every frame while it stands next to them.
	if (behavior == Behavior.CHASE or behavior == Behavior.ATTACK) and not _can_target(player):
		_cancel_fuse()
		behavior = Behavior.HUNT
		_sees_player = false

	var speed := walking_speed
	var face_target := Vector3.ZERO    # where to look when standing still (attacking)
	match behavior:
		Behavior.FLEE:
			speed = running_speed
			_flee_timer -= delta
			var away := global_position - _flee_from
			away.y = 0.0
			_dir = away.normalized() if away.length() > 0.01 else _dir
			if _flee_timer <= 0.0:
				behavior = Behavior.ROAM
		Behavior.CHASE:
			speed = running_speed
			var to_player := _flat_vector_to(player)
			_dir = to_player.normalized()
			_update_awareness(delta, player)
			if _lost_timer <= 0.0:
				behavior = Behavior.HUNT
			elif to_player.length() < _reach() and _vertical_gap(player) < 1.6:
				behavior = Behavior.ATTACK
		Behavior.ATTACK:
			_dir = Vector3.ZERO
			face_target = _flat_vector_to(player)
			_update_awareness(delta, player)
			var close := face_target.length() < _reach() * 1.4 and _vertical_gap(player) < 1.8
			if not _can_target(player) or not close:
				_cancel_fuse()
				behavior = Behavior.CHASE
			elif explodes:
				_tick_fuse(delta)
			elif _attack_timer <= 0.0:
				_melee(player)
		_:    # ROAM, HUNT, FOLLOW
			_wander(delta)
			if hostile:
				_update_awareness(delta, player)
				if _sees_player:
					behavior = Behavior.CHASE
					_lost_timer = FORGET_TIME

	velocity.x = _dir.x * speed + _knockback.x
	velocity.z = _dir.z * speed + _knockback.z
	_knockback = _knockback.move_toward(Vector3.ZERO, 20.0 * delta)
	if _dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-_dir.x, -_dir.z), minf(delta * 8.0, 1.0))
		if is_on_wall() and is_on_floor(): velocity.y = 8.0   # hop up one block
	elif face_target != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-face_target.x, -face_target.z), minf(delta * 10.0, 1.0))
	_animate_legs(delta)
	move_and_slide()
	if world.fluid_at(global_position) == &"lava":
		_lava_timer -= delta
		if _lava_timer <= 0.0:
			_lava_timer = 0.5
			hurt(2, global_position)
	if world.fluid_at(global_position) == &"water": velocity.y = 4.0
	if burns_in_daylight: _burn_in_sun(delta)


func _wander(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(1.5, 4.0)
		if randf() < 0.4:
			_dir = Vector3.ZERO
		else:
			var a := randf() * TAU
			_dir = Vector3(cos(a), 0, sin(a))


# --- Awareness ----------------------------------------------------------------------

func _reach() -> float:
	return attack_range if attack_range > 0.0 else 1.7


## Attacking someone who can't be hurt (creative mode, flying, already dead) is pointless.
func _can_target(player: Player) -> bool:
	return not player.is_dead and player.can_be_hurt and not player.freeflying


func _flat_vector_to(player: Player) -> Vector3:
	var v := player.global_position - global_position
	v.y = 0.0
	return v


func _vertical_gap(player: Player) -> float:
	return absf(player.global_position.y - global_position.y)


## Looking through walls would be cheating, and a physics ray per mob per frame would be wasteful,
## so check four times a second, and only run the (more expensive) line-of-sight test when the
## player is further away than "right behind you".
func _update_awareness(delta: float, player: Player) -> void:
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.25
		_sees_player = false
		if _can_target(player):
			var d := global_position.distance_to(player.global_position)
			if d < sight_range:
				_sees_player = d < 6.0 or world.has_line_of_sight(
					global_position + Vector3.UP * 1.5, player.get_eye_position())
		if _sees_player:
			_lost_timer = FORGET_TIME
	_lost_timer -= delta


# --- Hostile actions ----------------------------------------------------------------

func _melee(player: Player) -> void:
	_attack_timer = attack_cooldown if attack_cooldown > 0.0 else 1.0
	player.hurt(attack_damage)
	if player.has_method("apply_knockback"):
		player.apply_knockback((player.global_position - global_position).normalized(), 6.0)


static var _fuse_overlay: StandardMaterial3D

func _tick_fuse(delta: float) -> void:
	if _fuse < 0.0:
		_fuse = fuse_time
	_fuse -= delta
	var progress := 1.0 - _fuse / maxf(fuse_time, 0.01)    # 0 -> 1 as it nears going off
	model_node.scale = Vector3.ONE * (1.0 + 0.3 * progress)
	if _fuse_overlay == null:
		_fuse_overlay = StandardMaterial3D.new()
		_fuse_overlay.albedo_color = Color(1, 1, 1, 0.55)
		_fuse_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fuse_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flash := fmod(progress * 6.0, 1.0) < 0.5    # blinks faster the longer it burns
	for p in model_node.find_children("*", "MeshInstance3D", true, false):
		p.material_overlay = _fuse_overlay if flash else null
	if _fuse <= 0.0:
		_explode()


func _cancel_fuse() -> void:
	if _fuse < 0.0: return
	_fuse = -1.0
	model_node.scale = Vector3.ONE
	for p in model_node.find_children("*", "MeshInstance3D", true, false):
		p.material_overlay = null


func _explode() -> void:
	_dead = true    # so the blast can't "hurt" the creeper that caused it
	set_physics_process(false)
	world.explode(global_position + Vector3.UP * 0.5, explosion_radius)
	queue_free()


func _burn_in_sun(delta: float) -> void:
	_burn_timer -= delta
	if _burn_timer > 0.0: return
	_burn_timer = 1.0
	var dn = world.day_night
	if dn == null or not dn.is_daytime(): return
	if world.fluid_at(global_position) == &"water": return    # the water puts you out
	if world.is_sky_exposed(global_position + Vector3.UP * 1.8):
		_apply_damage(1, global_position, false)


# --- Damage ----------------------------------------------------------------------------

func hurt(amount: int, from: Vector3) -> void:
	if _dead: return
	_apply_damage(amount, from, true)
	if _dead: return
	if hostile:
		# Provoked: go straight for whoever hit you, even without line of sight.
		if behavior != Behavior.ATTACK: behavior = Behavior.CHASE
		_lost_timer = FORGET_TIME
	else:
		behavior = Behavior.FLEE
		_flee_from = from
		_flee_timer = FLEE_TIME


func _apply_damage(amount: int, from: Vector3, with_knockback: bool) -> void:
	if _dead: return
	_flash_red()
	health -= amount
	if with_knockback:
		var away := global_position - from
		away.y = 0.0
		_knockback = away.normalized() * 6.0
		velocity.y = 4.0
	if health <= 0:
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
	_cancel_fuse()
	if drop_id != &"": world.spawn_drop(drop_id, 1, global_position + Vector3.UP * 0.5)
	collision_layer = 0                 # can't be hit or blocked while falling over
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(model_node, "rotation:z", PI / 2.0, 0.3)
	tw.tween_callback(queue_free)
