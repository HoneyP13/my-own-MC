class_name MobSpawner
extends Node
## Spawns hostile mobs around the player, and removes them again when they're far away.
##
## There's no per-block light level in the game (yet), so "dark enough to spawn" is approximated:
##   * out in the open: only at night
##   * under at least CAVE_DEPTH solid blocks (a cave, a mine, a sealed room under a hill): always
##   * under a thin cover (a tree canopy, a one-block roof): same as in the open, only at night
## That means a tunnel you dig yourself will spawn zombies in it, even at noon, like the real game.
## Placing torches won't stop that until you add block light. That's the natural next feature.

const CHECK_INTERVAL := 2.0
const MAX_HOSTILE := 8          # the world is only 96x96, so keep this small
const ATTEMPTS_PER_CHECK := 6
const MIN_DISTANCE := 12.0      # never spawn closer than this
const MAX_DISTANCE := 32.0
const FAR_DISTANCE := 32.0      # beyond this, mobs may vanish (a little each check)
const DESPAWN_DISTANCE := 56.0  # beyond this they always vanish
const CAVE_DEPTH := 4
## (id, weight). Zombies twice as common as creepers.
const TABLE: Array = [[&"zombie", 2], [&"creeper", 1]]

var enabled := true
var world: Node3D
var _timer := CHECK_INTERVAL


func setup(p_world: Node3D) -> void:
	world = p_world


func _process(delta: float) -> void:
	if not enabled or world.player.is_dead or world.player.is_game_paused:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	_despawn_far()
	if world.player.can_be_hurt:    # no point filling a creative-mode world with things that can't hurt you
		_try_spawn()


func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("hostile").size() >= MAX_HOSTILE:
		return
	var p: Vector3 = world.player.global_position
	for _attempt in ATTEMPTS_PER_CHECK:
		var angle := randf() * TAU
		var dist := randf_range(MIN_DISTANCE, MAX_DISTANCE)
		var x := floori(p.x + cos(angle) * dist)
		var z := floori(p.z + sin(angle) * dist)
		if not world.in_world_bounds(x, z):
			continue
		var y: int = world.find_standing_y(x, z, floori(p.y))
		if y == world.NO_Y:
			continue
		var cell := Vector3i(x, y, z)
		var pos := Vector3(x + 0.5, y + 0.5, z + 0.5)
		if world.fluid_at(pos) != &"" or not _is_dark(cell):
			continue
		world.spawn_mob(_pick(), pos)
		return    # one per check, so a night doesn't start with a crowd


func _is_dark(cell: Vector3i) -> bool:
	var dn: DayNight = world.day_night
	if dn == null:
		return false
	return dn.is_night() or world.cover_depth(cell) >= CAVE_DEPTH


func _pick() -> StringName:
	var total := 0
	for row: Array in TABLE:
		total += row[1]
	var roll := randi() % total
	for row: Array in TABLE:
		roll -= row[1]
		if roll < 0:
			return row[0]
	return TABLE[0][0]


func _despawn_far() -> void:
	var p: Vector3 = world.player.global_position
	var dn: DayNight = world.day_night
	for m: Mob in get_tree().get_nodes_in_group("hostile"):
		var d := m.global_position.distance_to(p)
		if d > DESPAWN_DISTANCE:
			m.queue_free()
		elif d > FAR_DISTANCE and randf() < 0.15:
			m.queue_free()
		elif d > 20.0 and dn != null and dn.is_daytime() and randf() < 0.25 \
				and world.is_sky_exposed(m.global_position + Vector3.UP * 1.8):
			m.queue_free()    # creepers don't burn, so they just wander off when the sun's up
