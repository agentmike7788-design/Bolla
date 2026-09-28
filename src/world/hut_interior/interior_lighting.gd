class_name InteriorLighting
extends Node
## Lights an interior room by the game clock (docs §11, values: InteriorConfig): the window
## glow (cool blue at night, warm by day, no shadow), the hanging lantern (shadow at night),
## the candles (night only), the interior's ambient / background / exposure and its soft sun,
## blended by InteriorConfig.daylight(TimeManager minute). Lights are found by their meta
## "interior_role" (window, lantern, candle) below the InteriorRoom (Phase 6 §3.4: the hut and
## the buildings' rooms, each with its own config – Database.interior_config(room_id); in the
## crypt the window role is the stair shaft). A config with fog_enabled sets the room
## Environment's depth fog (the crypt's cold air, §4.8). The stove fire is a warm light of the
## AtmosphereController (flicker_light.gd, meta min_scale) and not touched here.

const META_ROLE := &"interior_role"
const ROLE_WINDOW := &"window"
const ROLE_LANTERN := &"lantern"
const ROLE_CANDLE := &"candle"
const META_BASE := &"base_energy"
const META_SCALE := &"scale"
## Lights below this energy are hidden (as the AtmosphereController does).
const MIN_VISIBLE_ENERGY := 0.01

## Re-apply only after the clock moved at least this many game minutes.
@export var reapply_step_minutes: float = 0.25

var config: InteriorConfig
var environment: Environment
var sun: DirectionalLight3D
## Daylight share of the last apply (NAN before the first).
var daylight: float = NAN

var _lights: Dictionary[StringName, Array] = {ROLE_WINDOW: [], ROLE_LANTERN: [], ROLE_CANDLE: []}
var _applied_minute: float = NAN


func _ready() -> void:
	var interior := get_parent() as InteriorRoom
	if interior != null:
		config = interior.room_config()
		environment = interior.environment
		sun = interior.get_node_or_null(^"Sun") as DirectionalLight3D
		collect_lights(interior)
	config = InteriorConfig.resolve(config)
	apply_minute(clock_minute())


func _process(_delta: float) -> void:
	var minute := clock_minute()
	if is_nan(_applied_minute) or absf(minute - _applied_minute) >= reapply_step_minutes:
		apply_minute(minute)


## Sorts every Light3D with an interior_role meta below `root` into its role list.
func collect_lights(root: Node) -> void:
	for role: StringName in _lights:
		_lights[role].clear()
	for node: Node in root.find_children("*", "Light3D", true, false):
		var role := StringName(node.get_meta(META_ROLE, &""))
		if _lights.has(role):
			_lights[role].append(node)


func lights(role: StringName) -> Array:
	return _lights.get(role, []).duplicate()


func apply_minute(minute_f: float) -> void:
	_applied_minute = minute_f
	apply_daylight(config.daylight(minute_f))


## Applies the mood for a daylight share t (0 = night, 1 = day).
func apply_daylight(t: float) -> void:
	daylight = clampf(t, 0.0, 1.0)
	var c := config
	for light: Light3D in _lights[ROLE_WINDOW]:
		light.light_color = c.window_night_color.lerp(c.window_day_color, daylight)
		_set_energy(light, lerpf(c.window_night_energy, c.window_day_energy, daylight))
		light.shadow_enabled = false
	for light: Light3D in _lights[ROLE_LANTERN]:
		_set_energy(light, lerpf(c.lantern_night_energy, c.lantern_day_energy, daylight))
		light.shadow_enabled = daylight < c.lantern_shadow_below
	for light: Light3D in _lights[ROLE_CANDLE]:
		_set_energy(light, lerpf(c.candle_night_energy, c.candle_day_energy, daylight))
	if environment != null:
		environment.background_color = c.background_color
		environment.ambient_light_color = c.ambient_night_color.lerp(c.ambient_day_color, daylight)
		environment.ambient_light_energy = lerpf(c.ambient_night_energy, c.ambient_day_energy, daylight)
		environment.tonemap_exposure = c.exposure
		if c.fog_enabled:
			environment.fog_enabled = true
			environment.fog_light_color = c.fog_color
			environment.fog_density = c.fog_density
	if sun != null:
		sun.light_color = c.sun_night_color.lerp(c.sun_day_color, daylight)
		sun.light_energy = lerpf(c.sun_night_energy, c.sun_day_energy, daylight)


## Energy + the metas flicker_light.gd reads (it re-applies them every frame).
static func _set_energy(light: Light3D, energy: float) -> void:
	light.set_meta(META_BASE, energy)
	light.set_meta(META_SCALE, 1.0)
	light.light_energy = energy
	light.visible = energy > MIN_VISIBLE_ENERGY


## TimeManager.get_minute_f(), looked up at runtime (tool scripts compile this before autoloads).
func clock_minute() -> float:
	var clock := get_node_or_null(^"/root/TimeManager")
	return float(clock.call(&"get_minute_f")) if clock != null else 720.0
