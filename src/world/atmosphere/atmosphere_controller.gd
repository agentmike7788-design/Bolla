class_name AtmosphereController
extends Node
## Applies AtmospherePreset resources to the scene's sun, environment and warm lights.
## Prototype mode: apply(index)/cycle() switch between `presets`.
## time_driven: follows TimeManager.get_minute_f() and blends `blend_presets` between the
## keyframe minutes in `blend_minutes` (wrapping over midnight).

signal preset_changed(preset: AtmospherePreset)

const MINUTES_PER_DAY := 1440.0

@export var presets: Array[AtmospherePreset] = []
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D
@export_group("Time of day")
## Follow the game clock instead of the fixed `presets`.
@export var time_driven := false
## Keyframe moods, one per entry of blend_minutes (e.g. night, dawn, day, dusk, night).
@export var blend_presets: Array[AtmospherePreset] = []
## Keyframe minute-of-day per blend preset, strictly ascending within 0..1439.
@export var blend_minutes: PackedInt32Array = [0, 330, 540, 1110, 1260]
## Re-apply only after the clock moved at least this many game minutes.
@export var reapply_step_minutes: float = 0.25
@export_group("Season")
## W3 (G8, decision E8-1 for the user): the November days get short – from game day season_from_day to
## season_full_day the keyframe minutes move by up to season_shift (one value per keyframe, minutes; dusk earlier,
## dawn later). The presets themselves are untouched (ART STYLE LOCK). 0 / empty = no season (bit-identical).
@export var season_from_day: int = 0
@export var season_full_day: int = 0
@export var season_shift: PackedInt32Array = []

var current_index: int = 0

var _blend: AtmospherePreset
var _applied_minute: float = NAN
var _blend_warned: bool = false


func _ready() -> void:
	if time_driven and _blend_valid():
		apply_time(_clock_minute())
	elif not presets.is_empty():
		apply(0)


func _process(_delta: float) -> void:
	if not time_driven:
		return
	var minute := _clock_minute()
	if is_nan(_applied_minute) or absf(minute - _applied_minute) >= reapply_step_minutes:
		apply_time(minute)


func cycle() -> void:
	if presets.is_empty():
		return
	apply((current_index + 1) % presets.size())


## The fixed preset shown in prototype mode, or the current blend when time-driven.
func current() -> AtmospherePreset:
	if time_driven and _blend != null:
		return _blend
	return presets[current_index]


func apply(index: int) -> void:
	current_index = index
	var p := presets[index]
	_apply_values(p)
	preset_changed.emit(p)


## Applies the blended mood for a (fractional) minute of day. Returns false if the
## blend setup is invalid (warned once).
func apply_time(minute_f: float) -> bool:
	if not _blend_valid():
		return false
	_blend = blend_at(minute_f, _blend)
	_applied_minute = minute_f
	_apply_values(_blend)
	return true


## Blend of the two keyframes around `minute_f`: colors and floats lerp, *_deg vectors
## take the shortest angle per axis, other fields come from the nearer keyframe.
## Writes into `into` (or a new preset). Keyframe minutes reproduce their preset exactly.
func blend_at(minute_f: float, into: AtmospherePreset = null) -> AtmospherePreset:
	var out := into if into != null else AtmospherePreset.new()
	if not _blend_valid():
		return out
	var m := fposmod(minute_f, MINUTES_PER_DAY)
	var keys := keyframe_minutes(_clock_day())
	var count := keys.size()
	var i := count - 1
	for k: int in count:
		if float(keys[k]) <= m:
			i = k
	var j := (i + 1) % count
	var start := float(keys[i])
	var span := fposmod(float(keys[j]) - start, MINUTES_PER_DAY)
	if span <= 0.0:
		span = MINUTES_PER_DAY
	var t := clampf(fposmod(m - start, MINUTES_PER_DAY) / span, 0.0, 1.0)
	_lerp_preset(blend_presets[i], blend_presets[j], t, out)
	return out


## The keyframe minutes on game day `day`: blend_minutes moved by the season (blend_minutes unchanged without a
## season, before season_from_day or when the shift would break the strict order).
func keyframe_minutes(day: int) -> PackedInt32Array:
	if season_from_day <= 0 or season_full_day <= season_from_day or season_shift.size() != blend_minutes.size() \
			or day <= season_from_day:
		return blend_minutes
	var f := clampf(float(day - season_from_day) / float(season_full_day - season_from_day), 0.0, 1.0)
	var out := PackedInt32Array()
	for k: int in blend_minutes.size():
		var v := blend_minutes[k] + roundi(season_shift[k] * f)
		if v < 0 or v >= int(MINUTES_PER_DAY) or (k > 0 and v <= out[k - 1]):
			return blend_minutes
		out.append(v)
	return out


func _clock_day() -> int:
	var clock := get_node_or_null(^"/root/TimeManager") if is_inside_tree() else null
	return int(clock.get(&"day")) if clock != null else 0


## TimeManager.get_minute_f(), looked up at runtime so tool scripts (-s) that load this
## class before the autoloads exist still compile it.
func _clock_minute() -> float:
	var clock := get_node_or_null(^"/root/TimeManager")
	return float(clock.call(&"get_minute_f")) if clock != null else 0.0


func _apply_values(p: AtmospherePreset) -> void:
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	sun.rotation_degrees = p.sun_rotation_deg
	sun.shadow_opacity = p.sun_shadow_opacity
	var env := world_environment.environment
	env.background_color = p.background_color
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.volumetric_fog_density = p.volumetric_fog_density
	env.volumetric_fog_albedo = p.volumetric_fog_albedo
	env.volumetric_fog_emission = p.volumetric_fog_emission
	env.tonemap_exposure = p.exposure
	env.glow_intensity = p.glow_intensity
	env.adjustment_saturation = p.saturation
	for node: Node in get_tree().get_nodes_in_group("warm_lights"):
		var light := node as Light3D
		light.set_meta("scale", p.warm_light_scale)
		light.light_energy = float(light.get_meta("base_energy", 1.0)) * p.warm_light_scale
		light.visible = light.light_energy > 0.01


func _lerp_preset(a: AtmospherePreset, b: AtmospherePreset, t: float, out: AtmospherePreset) -> void:
	for prop: Dictionary in a.get_property_list():
		var usage: int = prop.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var key: StringName = prop.name
		var va: Variant = a.get(key)
		var vb: Variant = b.get(key)
		match typeof(va):
			TYPE_FLOAT:
				out.set(key, lerpf(va as float, vb as float, t))
			TYPE_COLOR:
				out.set(key, (va as Color).lerp(vb as Color, t))
			TYPE_VECTOR3:
				if String(key).ends_with("_deg"):
					out.set(key, _lerp_angles_deg(va as Vector3, vb as Vector3, t))
				else:
					out.set(key, (va as Vector3).lerp(vb as Vector3, t))
			_:
				out.set(key, va if t < 0.5 else vb)


## Per-axis shortest-path interpolation of Euler angles in degrees (exact `a` at t = 0).
func _lerp_angles_deg(a: Vector3, b: Vector3, t: float) -> Vector3:
	return Vector3(
		a.x + wrapf(b.x - a.x, -180.0, 180.0) * t,
		a.y + wrapf(b.y - a.y, -180.0, 180.0) * t,
		a.z + wrapf(b.z - a.z, -180.0, 180.0) * t)


func _blend_valid() -> bool:
	var ok := not blend_presets.is_empty() and blend_presets.size() == blend_minutes.size()
	for k: int in blend_minutes.size():
		if not ok:
			break
		ok = blend_presets[k] != null and blend_minutes[k] >= 0 and blend_minutes[k] < int(MINUTES_PER_DAY) \
				and (k == 0 or blend_minutes[k] > blend_minutes[k - 1])
	if not ok and not _blend_warned:
		_blend_warned = true
		push_warning("[Atmosphere] time_driven needs one preset per keyframe and strictly ascending minutes 0..1439")
	return ok
