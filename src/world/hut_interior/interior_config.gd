class_name InteriorConfig
extends Resource
## Interior room values (the hut: data/config/interior_config.tres, docs §11; Phase 6 §4.8: the
## rooms of the buildings data/config/interiors/<room_id>.tres): portal fade, interior
## camera profile, the interior lights and ambient by night / by day, the stove fire and the
## chest size. InteriorLighting blends night → day with daylight(minute) (keyframes below).

@export_group("Portal")
## Whole black fade (out + in) when entering / leaving the hut; the teleport is at its midpoint.
@export var fade_seconds: float = 0.5

@export_group("Camera")
@export var camera_distance: float = 9.0
@export var camera_zoom_min: float = 7.0
@export var camera_zoom_max: float = 11.0

@export_group("Daylight")
## Minute-of-day keyframes (ascending, 0..1439) and the daylight share 0 (night) .. 1 (day)
## at each, linear in between and wrapping over midnight (same holds as the outdoor mood).
@export var daylight_minutes: PackedInt32Array = [0, 240, 330, 480, 1020, 1140, 1260]
@export var daylight_values: PackedFloat32Array = [0.0, 0.0, 0.45, 1.0, 1.0, 0.45, 0.0]
## Below this daylight share the hanging lantern casts its shadow.
@export var lantern_shadow_below: float = 0.5

@export_group("Windows")
@export var window_night_color: Color = Color("#8fa2d0")
@export var window_night_energy: float = 0.35
@export var window_day_color: Color = Color("#ffe2b0")
@export var window_day_energy: float = 1.3
@export var window_range: float = 3.5

@export_group("Hanging lantern")
@export var lantern_color: Color = Color("#ffae55")
@export var lantern_night_energy: float = 1.1
@export var lantern_day_energy: float = 0.3
@export var lantern_range: float = 5.0

@export_group("Candles")
@export var candle_color: Color = Color("#ffa040")
@export var candle_night_energy: float = 0.5
@export var candle_day_energy: float = 0.0
@export var candle_range: float = 2.2

@export_group("Stove fire")
## Part of warm_lights: energy = stove_night_energy × max(warm scale, stove_day_energy / night).
@export var stove_color: Color = Color("#ff8a3c")
@export var stove_night_energy: float = 3.0
@export var stove_day_energy: float = 1.6
@export var stove_range: float = 6.0
@export var stove_flicker: float = 0.18

@export_group("Fill light")
## G7 round 1 (light): soft fill lights of a room (layout "fill_lights" [x, y, z], no shadow) – the warm
## "room light" a painted interior has: faces, furniture and floor readable by day and night in both
## renderers (the Compatibility renderer has no SSIL / SDFGI bounce). 0 energy = none (hut, Phase 6).
@export var fill_night_color: Color = Color("#ffcf9a")
@export var fill_night_energy: float = 0.0
@export var fill_day_color: Color = Color("#fff0d8")
@export var fill_day_energy: float = 0.0
@export var fill_range: float = 7.0
@export var fill_attenuation: float = 0.8

@export_group("Ambient & sun")
@export var ambient_night_color: Color = Color(0.2, 0.26, 0.42)
@export var ambient_night_energy: float = 0.35
@export var ambient_day_color: Color = Color(0.62, 0.58, 0.52)
@export var ambient_day_energy: float = 0.55
@export var background_color: Color = Color(0.02, 0.018, 0.016)
@export var sun_day_color: Color = Color(1.0, 0.93, 0.8)
@export var sun_day_energy: float = 0.9
@export var sun_night_color: Color = Color(0.55, 0.65, 0.9)
@export var sun_night_energy: float = 0.08
@export var exposure: float = 1.0

@export_group("Fog")
## Phase 6 §4.8: cold air in the crypt (depth fog of the room's Environment, not volumetric).
@export var fog_enabled: bool = false
@export var fog_color: Color = Color("#8a98a8")
@export var fog_density: float = 0.0
## W3 art QA (G6): the fog's own light by day / at night (Environment.fog_light_energy, blended with
## daylight like the ambient). The depth fog lights what it covers – 1.0 at night made the crypt a
## milky grey; the fog never covers the background (fog_sky_affect 0: the void around a room stays
## the background colour, not a light grey).
@export var fog_day_energy: float = 1.0
@export var fog_night_energy: float = 1.0
## Phase 6 §4.8: the "window" light role is the stair shaft (crypt).
@export var shaft_role_as_window: bool = false

@export_group("Chest")
@export var chest_slots: int = 16


## Daylight share 0..1 at a (fractional) minute of day.
func daylight(minute_f: float) -> float:
	var count := mini(daylight_minutes.size(), daylight_values.size())
	if count == 0:
		return 1.0
	if count == 1:
		return daylight_values[0]
	var m := fposmod(minute_f, 1440.0)
	var i := count - 1
	for k: int in count:
		if float(daylight_minutes[k]) <= m:
			i = k
	var j := (i + 1) % count
	var start := float(daylight_minutes[i])
	var span := fposmod(float(daylight_minutes[j]) - start, 1440.0)
	if span <= 0.0:
		return daylight_values[i]
	return lerpf(daylight_values[i], daylight_values[j], clampf(fposmod(m - start, 1440.0) / span, 0.0, 1.0))


## The game's config (Database "interior_config"), else the defaults above.
static func resolve(config: InteriorConfig = null) -> InteriorConfig:
	if config != null:
		return config
	var tree := Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null(^"Database") if tree != null else null
	var found: Resource = db.call(&"config", &"interior_config") if db != null else null
	return found as InteriorConfig if found is InteriorConfig else InteriorConfig.new()


## Phase 6 (§3.5): the config of the room `room_id` (Database.interior_config – missing →
## interior_config), else the defaults above. Looked up at runtime (tool scripts compile this
## before the autoloads exist).
static func for_room(room_id: StringName) -> InteriorConfig:
	var tree := Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null(^"Database") if tree != null else null
	var found: Resource = db.call(&"interior_config", room_id) if db != null and db.has_method(&"interior_config") else null
	return found as InteriorConfig if found is InteriorConfig else resolve(null)
