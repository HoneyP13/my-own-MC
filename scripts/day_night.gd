class_name DayNight
extends Node
## Time of day, the sun and moon, and the sky colours.
##
## One day is DAY_LENGTH real seconds. `time / DAY_LENGTH` (called t below) runs 0..1:
##     t = 0.00  sunrise        t = 0.25  noon
##     t = 0.50  sunset         t = 0.75  midnight
## A single DirectionalLight3D plays both the sun and the moon: it travels across the sky during
## the day, fades out as it touches the horizon, and comes back as a dim blue moon on the other
## side. Fading to zero BEFORE the swap means you never see the shadows snap to a new direction.

signal phase_changed(new_phase: Phase)

enum Phase { DAWN, DAY, DUSK, NIGHT }

const DAY_LENGTH := 1200.0    # 20 minutes, like the game you're cloning
const SUN_ENERGY := 1.0
const MOON_ENERGY := 0.07
const MORNING := 0.02         # where "skip to morning" puts the clock

@export var time_scale := 1.0
## Set true to freeze the clock (the /time command can use it).
var paused := false
var time := 0.08 * DAY_LENGTH    # new worlds start just after sunrise
var day_count := 0
var phase := Phase.DAY

var env: Environment
var sun: DirectionalLight3D
var _world: Node
var _colour_timer := 0.0

# Sky colours over the day, as (t, colour) stops. The first and last stop match so it loops cleanly.
var _sky_top := _make_gradient(
	[0.0, 0.06, 0.25, 0.44, 0.5, 0.56, 0.75, 0.92, 1.0],
	[Color(0.38, 0.4, 0.62), Color(0.32, 0.58, 0.95), Color(0.25, 0.5, 0.95), Color(0.33, 0.54, 0.9),
	 Color(0.36, 0.32, 0.55), Color(0.04, 0.05, 0.15), Color(0.01, 0.015, 0.05), Color(0.04, 0.05, 0.15),
	 Color(0.38, 0.4, 0.62)])
var _sky_horizon := _make_gradient(
	[0.0, 0.07, 0.25, 0.43, 0.5, 0.57, 0.75, 0.92, 1.0],
	[Color(0.95, 0.6, 0.4), Color(0.7, 0.8, 0.95), Color(0.75, 0.85, 1.0), Color(0.7, 0.8, 0.95),
	 Color(0.95, 0.5, 0.3), Color(0.1, 0.1, 0.2), Color(0.03, 0.04, 0.09), Color(0.1, 0.1, 0.2),
	 Color(0.95, 0.6, 0.4)])


func setup(p_env: Environment, p_sun: DirectionalLight3D = null) -> void:
	env = p_env
	_world = get_parent()
	sun = p_sun
	if sun == null:
		var found := _world.find_children("*", "DirectionalLight3D", true, false)
		if not found.is_empty():
			sun = found[0]
	if sun == null:    # the scene has no sun at all, so make one
		sun = DirectionalLight3D.new()
		sun.shadow_enabled = true
		add_child(sun)
	_apply(true)


func _process(delta: float) -> void:
	if paused or _world.player.is_game_paused:
		return
	time += delta * time_scale
	if time >= DAY_LENGTH:
		time -= DAY_LENGTH
		day_count += 1
	_apply(false)


# --- Public API -------------------------------------------------------------------

## 0..1, see the table at the top.
func fraction() -> float:
	return time / DAY_LENGTH


func set_time_fraction(t: float) -> void:
	time = fposmod(t, 1.0) * DAY_LENGTH
	_apply(true)


## What sleeping in a bed does.
func skip_to_morning() -> void:
	if fraction() > MORNING:
		day_count += 1
	time = MORNING * DAY_LENGTH
	_apply(true)


func is_night() -> bool:
	return phase == Phase.NIGHT


## Dawn counts as daytime: zombies burn from the first light.
func is_daytime() -> bool:
	return phase == Phase.DAWN or phase == Phase.DAY


## "6:00" at sunrise, "12:00" at noon, "0:00" at midnight.
func get_clock_string() -> String:
	var hours := fposmod(fraction() * 24.0 + 6.0, 24.0)
	return "%d:%02d" % [int(hours), int((hours - floorf(hours)) * 60.0)]


func to_dict() -> Dictionary:
	return {"time": time, "day": day_count}


func from_dict(d: Dictionary) -> void:
	time = d.get("time", time)
	day_count = d.get("day", day_count)
	_apply(true)


# --- Applying the time to the scene ---------------------------------------------------

func _apply(force_colours: bool) -> void:
	var t := fraction()
	_update_phase(t)

	# Where the light is. h is how high the SUN is: +1 overhead, 0 on the horizon, -1 straight below.
	var h := sin(t * TAU)
	var arc := fposmod(t * TAU, PI)    # day: the sun's arc. night: the moon's arc (same maths, other half)
	sun.rotation = Vector3(-arc, deg_to_rad(-35.0), 0.0)
	var sun_amount := smoothstep(0.0, 0.3, h)
	var moon_amount := smoothstep(0.0, 0.3, -h)
	sun.light_energy = SUN_ENERGY * sun_amount + MOON_ENERGY * moon_amount
	sun.light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.97, 0.9), smoothstep(0.0, 0.5, h)) \
		if h > 0.0 else Color(0.55, 0.65, 1.0)
	sun.visible = sun.light_energy > 0.002    # no point paying for shadows while it's off

	# The sky gets repainted a few times a second, not every frame: changing a sky material
	# makes the engine re-process it, and nobody can see the difference.
	_colour_timer -= get_process_delta_time()
	if not force_colours and _colour_timer > 0.0:
		return
	_colour_timer = 0.25
	if env == null:
		return
	var daylight := smoothstep(-0.15, 0.3, h)
	env.ambient_light_energy = lerpf(0.3, 1.0, daylight)
	var top: Color = _sky_top.sample(t)
	var horizon: Color = _sky_horizon.sample(t)
	if env.background_mode == Environment.BG_COLOR:
		env.background_color = top.lerp(horizon, 0.5)
	elif env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		var m: ProceduralSkyMaterial = env.sky.sky_material
		m.sky_top_color = top
		m.sky_horizon_color = horizon
		m.ground_horizon_color = horizon
		m.ground_bottom_color = top.darkened(0.5)
	else:
		env.background_energy_multiplier = lerpf(0.06, 1.0, daylight)    # a texture sky: just dim it


func _update_phase(t: float) -> void:
	var p := Phase.NIGHT
	if t < 0.05 or t >= 0.94:
		p = Phase.DAWN
	elif t < 0.45:
		p = Phase.DAY
	elif t < 0.55:
		p = Phase.DUSK
	if p != phase:
		phase = p
		phase_changed.emit(p)


# Gradient has no "wrap-around" and takes parallel arrays, so this keeps the table above readable.
static func _make_gradient(offsets: Array, colours: Array) -> GradientSampler:
	return GradientSampler.new(offsets, colours)


class GradientSampler extends RefCounted:
	var _g := Gradient.new()

	func _init(offsets: Array, colours: Array) -> void:
		_g.offsets = PackedFloat32Array(offsets)
		_g.colors = PackedColorArray(colours)

	func sample(t: float) -> Color:
		return _g.sample(t)
