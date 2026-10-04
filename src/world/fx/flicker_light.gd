class_name FlickerLight
extends Light3D
## Fire light flicker (G7 round 1) for every candle, lantern, stove, forge and night window light –
## OmniLight3D or SpotLight3D. Scales the energy its owner sets (meta "base_energy" × meta "scale",
## never below meta "min_scale": AtmosphereController, InteriorLighting, the hut stove) by
## FlickerProfile.factor(seed, t); the colour wobbles towards the profile's warm shift.
## The profile comes from `profile`, else data/config/fx/<profile_id>.tres, else by the light's role
## (meta interior_role / its name: candle, lantern, stove, forge, window). The seed is per instance
## (from the position unless seed_value ≥ 0), so no two flames flicker in step.
## Cheap: no shadow re-render (only energy / colour change), nothing while hidden (inactive rooms,
## the other region), base energy without per-frame noise beyond the profile's lod_distance.
## The old path src/world/atmosphere/flicker_light.gd extends this script (built scenes keep working).

const GROUP := &"flicker_lights"
const PROFILE_PATH := "res://data/config/fx/%s.tres"
const META_BASE := &"base_energy"
const META_SCALE := &"scale"
const META_MIN_SCALE := &"min_scale"
const META_ROLE := &"interior_role"
const META_PROFILE := &"flicker_profile"
## Seconds between LOD distance checks.
const LOD_CHECK := 0.5
const EMBER_TEXTURE := "res://assets/vfx/ph_vfx_smoke_wisp.png"

## Legacy (scenes built before the profiles): used only when no profile resolves.
@export var amount: float = 0.12
@export var speed: float = 7.0
@export var profile: FlickerProfile
## "" = by role / name.
@export var profile_id: StringName = &""
## −1 = from the light's position.
@export var seed_value: int = -1

var _t: float = 0.0
var _seed: int = 0
var _base_color: Color = Color.WHITE
var _near: bool = true
var _lod_timer: float = 0.0
var _embers: CPUParticles3D
static var _ember_material: StandardMaterial3D


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if profile == null:
		profile = resolve_profile(self)
	_seed = seed_value if seed_value >= 0 else seed_for(self)
	_t = float(_seed % 1000) * 0.137
	_base_color = light_color
	if profile != null and profile.embers > 0 and not bool(get_meta(&"no_embers", false)):
		_embers = make_embers(profile)
		add_child(_embers)
		_embers.emitting = is_visible_in_tree()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _embers != null:
		_embers.emitting = is_visible_in_tree()


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree():
		return
	var base := base_energy()
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = LOD_CHECK
		_near = _camera_near()
	if not _near:
		light_energy = base
		if _embers != null:
			_embers.emitting = false
		return
	if _embers != null and not _embers.emitting:
		_embers.emitting = true
	light_energy = base * energy_factor(_t)
	if profile != null and profile.color_wobble > 0.0:
		var n := profile.signal_at(_seed + 31, _t) * 0.5 + 0.5
		light_color = _base_color.lerp(_base_color * profile.warm_shift, profile.color_wobble * n)


## The owner's energy: base_energy × max(scale, min_scale).
func base_energy() -> float:
	var scale := maxf(float(get_meta(META_SCALE, 1.0)), float(get_meta(META_MIN_SCALE, 0.0)))
	return float(get_meta(META_BASE, 1.0)) * scale


## The flicker factor at time t (profile, else the legacy ±amount noise).
func energy_factor(t: float) -> float:
	if profile != null:
		return profile.factor(_seed, t)
	return 1.0 + FlickerProfile.value_noise(_seed, t * speed * 0.5) * amount


## A few slow sparks rising from the fire (painted: soft round motes, additive, no shadow).
static func make_embers(p: FlickerProfile) -> CPUParticles3D:
	var parts := CPUParticles3D.new()
	parts.name = "Embers"
	parts.amount = p.embers
	parts.lifetime = 1.6
	parts.preprocess = 1.6
	parts.randomness = 0.6
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = p.ember_box * 0.5
	parts.direction = Vector3.UP
	parts.spread = 25.0
	parts.gravity = Vector3(0.0, 0.05, 0.0)
	parts.initial_velocity_min = p.ember_rise * 0.5
	parts.initial_velocity_max = p.ember_rise
	parts.scale_amount_min = 0.5
	parts.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	var c := p.ember_color
	ramp.colors = PackedColorArray([Color(c, 0.0), Color(c, 0.9), Color(c * 0.8, 0.6), Color(c * 0.6, 0.0)])
	parts.color_ramp = ramp
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.fixed_fps = 30
	parts.visibility_range_end = maxf(p.lod_distance, 10.0)
	if _ember_material == null:
		_ember_material = StandardMaterial3D.new()
		_ember_material.resource_name = "mat_fx_ember"
		_ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ember_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_material.vertex_color_use_as_albedo = true
		_ember_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_material.no_depth_test = false
		# soft round motes (the painted smoke wisp), not hard squares
		_ember_material.albedo_texture = load(EMBER_TEXTURE) as Texture2D
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = _ember_material
	parts.mesh = quad
	parts.emitting = true
	return parts


func set_base_color(c: Color) -> void:
	_base_color = c
	light_color = c


func _camera_near() -> bool:
	if profile == null or profile.lod_distance <= 0.0 or not is_inside_tree():
		return true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	return cam.global_position.distance_squared_to(global_position) <= profile.lod_distance * profile.lod_distance


## The profile of `light`: its profile_id / meta flicker_profile, else by role or name.
static func resolve_profile(light: Node) -> FlickerProfile:
	var id := StringName(light.get(&"profile_id")) if light.get(&"profile_id") != null else &""
	if id == &"":
		id = StringName(light.get_meta(META_PROFILE, &""))
	if id == &"":
		id = role_profile_id(light)
	var path := PROFILE_PATH % id
	if ResourceLoader.exists(path):
		return load(path) as FlickerProfile
	return null


## candle · lantern · stove · forge · window, from meta interior_role or the node name.
static func role_profile_id(light: Node) -> StringName:
	var role := String(light.get_meta(META_ROLE, ""))
	var n := String(light.name).to_lower() + " " + role
	if "stove" in n or "fire" in n:
		return &"stove"
	if "ember" in n or "forge" in n:
		return &"forge"
	if "candle" in n or "rite" in n or "eternal" in n:
		return &"candle"
	if "window" in n:
		return &"window"
	return &"lantern"


## A stable per-instance seed from the light's (global) position.
static func seed_for(light: Node3D) -> int:
	var p := light.global_position if light.is_inside_tree() else light.position
	return absi(hash(Vector3i(roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)))) % 1000003
