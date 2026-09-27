extends TestCase
## M2: AtmosphereController – prototype mode unchanged, time-driven keyframe blending (§3.4).

const PROTO := "res://src/world/art_prototype/art_prototype.tscn"
const DIR := "res://data/atmosphere/"
const DEFAULT_MINUTES: Array[int] = [0, 330, 540, 1110, 1260]

var day: AtmospherePreset
var night: AtmospherePreset
var dawn: AtmospherePreset
var dusk: AtmospherePreset
var lamp: OmniLight3D


func before_each() -> void:
	day = load(DIR + "day.tres")
	night = load(DIR + "night.tres")
	dawn = load(DIR + "dawn.tres")
	dusk = load(DIR + "dusk.tres")


# --- prototype mode ---

func test_defaults_match_contract() -> void:
	var atmo := AtmosphereController.new()
	assert_false(atmo.time_driven)
	assert_eq(Array(atmo.blend_minutes), DEFAULT_MINUTES)
	assert_eq(atmo.blend_presets.size(), 0)
	atmo.free()


func test_controller_has_no_compile_time_autoload_dependency() -> void:
	# Builder scripts run with -s load this class before autoloads exist as identifiers.
	var source := FileAccess.get_file_as_string("res://src/world/atmosphere/atmosphere_controller.gd")
	for line: String in source.split("\n"):
		var code := line.strip_edges()
		if code.begins_with("#"):
			continue
		for autoload_name: String in ["TimeManager.", "EventBus.", "GameState.", "SaveManager.", "UIState."]:
			assert_false(code.contains(autoload_name), "uses %s directly: %s" % [autoload_name, code])


func test_prototype_apply_and_cycle() -> void:
	var atmo := _make([day, night])
	var changed: Array = []
	atmo.preset_changed.connect(func(p: AtmospherePreset) -> void: changed.append(p))
	await wait_frames(1)
	assert_eq(atmo.current_index, 0)
	_assert_applied(atmo, day, "ready applies preset 0")
	atmo.cycle()
	assert_eq(atmo.current_index, 1)
	assert_true(atmo.current() == night)
	_assert_applied(atmo, night, "cycle -> night")
	atmo.cycle()
	_assert_applied(atmo, day, "cycle wraps")
	atmo.apply(1)
	assert_eq(changed, [day, night, day, night], "preset_changed per apply (incl. _ready)")


func test_prototype_mode_ignores_clock() -> void:
	var atmo := _make([day, night])
	await wait_frames(1)
	TimeManager.load_state({"day": 1, "minute_of_day": 1300})
	atmo._process(0.1)
	await wait_frames(2)
	_assert_applied(atmo, day, "fixed preset stays")


func test_art_prototype_scene_unchanged() -> void:
	var scene := (load(PROTO) as PackedScene).instantiate()
	var atmo := scene.get_node("Atmosphere") as AtmosphereController
	assert_false(atmo.time_driven, "prototype is not time-driven")
	assert_eq(atmo.presets.size(), 2)
	assert_eq(atmo.presets[0].resource_path, DIR + "day.tres")
	assert_eq(atmo.presets[1].resource_path, DIR + "night.tres")
	tree.root.add_child(scene)
	await wait_frames(1)
	assert_true(atmo.current() == atmo.presets[0])
	assert_eq(atmo.sun.light_color, day.sun_color)
	assert_true(atmo.sun.rotation_degrees.is_equal_approx(day.sun_rotation_deg), "sun rotation")
	atmo.cycle()
	assert_eq(atmo.sun.light_color, night.sun_color)
	assert_almost(atmo.world_environment.environment.fog_density, night.fog_density)
	atmo.apply(0)  # the Environment is a shared sub-resource of the cached scene
	scene.queue_free()


# --- time-driven blending ---

func test_keyframes_reproduce_presets_exactly() -> void:
	var atmo := _make_blend([night, dawn, day, dusk, night])
	await wait_frames(1)
	var keys := [night, dawn, day, dusk, night]
	for i: int in DEFAULT_MINUTES.size():
		var blended := atmo.blend_at(DEFAULT_MINUTES[i])
		assert_eq(_fields(blended), _fields(keys[i]), "keyframe %d" % DEFAULT_MINUTES[i])
		assert_true(atmo.apply_time(DEFAULT_MINUTES[i]))
		_assert_applied(atmo, keys[i], "applied keyframe %d" % DEFAULT_MINUTES[i])


func test_midpoint_interpolation() -> void:
	var atmo := _make_blend([night, dawn, day, dusk, night])
	await wait_frames(1)
	var mid := atmo.blend_at(435.0)  # halfway dawn (330) -> day (540)
	var expected := _fields(dawn)
	for key: String in expected:
		var a: Variant = dawn.get(key)
		var b: Variant = day.get(key)
		if a is float:
			assert_almost(mid.get(key), (float(a) + float(b)) * 0.5, 0.00001, key)
		elif a is Color:
			assert_true((mid.get(key) as Color).is_equal_approx((a as Color).lerp(b, 0.5)), key)
	var rot := mid.sun_rotation_deg
	assert_almost(rot.x, -29.0, 0.0001, "pitch midway -16 -> -42")
	assert_almost(rot.y, 6.0, 0.0001, "yaw midway 62 -> -50 (shortest path through south)")
	assert_eq(mid.display_name, day.display_name, "names switch at the midpoint")
	var quarter := atmo.blend_at(330.0 + 52.5)
	assert_almost(quarter.sun_energy, lerpf(dawn.sun_energy, day.sun_energy, 0.25), 0.00001)
	assert_almost(quarter.warm_light_scale, lerpf(dawn.warm_light_scale, day.warm_light_scale, 0.25), 0.00001)
	assert_eq(quarter.display_name, dawn.display_name)


func test_sun_takes_shortest_angle() -> void:
	var atmo := _make_blend([night, dawn, day, dusk, night])
	await wait_frames(1)
	var mid := atmo.blend_at(1185.0)  # halfway dusk (1110) -> night (1260)
	# dusk yaw -76 -> night yaw 160: shortest way is -124° (west over north), not +236°.
	assert_almost(wrapf(mid.sun_rotation_deg.y, -180.0, 180.0), -138.0, 0.0001)
	assert_almost(mid.sun_rotation_deg.x, -35.0, 0.0001)
	var late := atmo.blend_at(1259.9)
	assert_almost(wrapf(late.sun_rotation_deg.y - night.sun_rotation_deg.y, -180.0, 180.0), 0.0, 0.2, "arrives at the moon angle")


func test_wrap_over_midnight() -> void:
	var a := _preset(Color(0.2, 0.2, 0.2), 0.0, 10.0)
	var b := _preset(Color(1.0, 0.6, 0.2), 1.0, 90.0)
	var atmo := _make_blend([a, b], PackedInt32Array([360, 1080]))
	await wait_frames(1)
	var cases := {0.0: 0.5, 1080.0: 0.0, 1260.0: 0.25, 200.0: 560.0 / 720.0, 1440.0: 0.5, -60.0: 300.0 / 720.0, 359.9: 0.99986}
	for minute: float in cases:
		var t: float = cases[minute]
		var blended := atmo.blend_at(minute)
		assert_almost(blended.sun_energy, lerpf(b.sun_energy, a.sun_energy, t), 0.0001, "minute %s" % minute)
		assert_true(blended.sun_color.is_equal_approx(b.sun_color.lerp(a.sun_color, t)), "color at %s" % minute)
	assert_eq(_fields(atmo.blend_at(360.0)), _fields(a))
	var between := atmo.blend_at(720.0)  # inside a -> b
	assert_almost(between.sun_energy, 0.5, 0.0001)


func test_constant_night_between_last_and_first_keyframe() -> void:
	var atmo := _make_blend([night, dawn, day, dusk, night])
	await wait_frames(1)
	for minute: float in [1260.0, 1350.0, 1439.9]:
		assert_eq(_fields(atmo.blend_at(minute)), _fields(night), "minute %s" % minute)


func test_single_keyframe_is_constant() -> void:
	var atmo := _make_blend([dusk], PackedInt32Array([600]))
	await wait_frames(1)
	for minute: float in [0.0, 600.0, 1200.0]:
		assert_eq(_fields(atmo.blend_at(minute)), _fields(dusk))


func test_time_driven_follows_clock_with_threshold() -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": 540})
	var cfg := TimeManager.config.duplicate() as TimeConfig
	cfg.seconds_per_game_minute = 0.5
	TimeManager.config = cfg
	var atmo := _make_blend([night, dawn, day, dusk, night])
	var changed: Array = []
	atmo.preset_changed.connect(func(p: AtmospherePreset) -> void: changed.append(p))
	await wait_frames(1)
	_assert_applied(atmo, day, "ready applies the current time")
	assert_eq(_fields(atmo.current()), _fields(day), "current() is the blend")
	TimeManager.load_state({"day": 1, "minute_of_day": 1110})
	atmo._process(0.0)
	_assert_applied(atmo, dusk, "follows a time jump")
	var marker := Color(1, 0, 1)
	atmo.sun.light_color = marker
	TimeManager.running = true
	TimeManager._process(0.1)  # 1110.2: below the re-apply step
	atmo._process(0.0)
	assert_eq(atmo.sun.light_color, marker, "no re-apply below 0.25 game minutes")
	TimeManager._process(0.05)  # 1110.3
	atmo._process(0.0)
	TimeManager.running = false
	assert_ne(atmo.sun.light_color, marker, "re-applied after 0.25 game minutes")
	assert_true(atmo.sun.light_color.is_equal_approx(atmo.blend_at(1110.3).sun_color))
	assert_eq(changed, [], "blending does not emit preset_changed")


func test_warm_lights_follow_blend() -> void:
	var atmo := _make_blend([night, dawn, day, dusk, night])
	await wait_frames(1)
	atmo.apply_time(1185.0)
	var scale := lerpf(dusk.warm_light_scale, night.warm_light_scale, 0.5)
	assert_almost(float(lamp.get_meta("scale")), scale, 0.00001)
	assert_almost(lamp.light_energy, 2.0 * scale, 0.00001)
	assert_true(lamp.visible)


func test_invalid_blend_setup_warns_and_falls_back() -> void:
	var atmo := _make([day, night], true)
	atmo.blend_presets = [night, day]  # 2 presets for 5 default minutes
	await wait_frames(1)
	_assert_applied(atmo, day, "falls back to the fixed preset")
	assert_false(atmo.apply_time(600.0))
	atmo._process(0.0)
	atmo.blend_minutes = PackedInt32Array([600, 300])
	assert_false(atmo.apply_time(600.0), "minutes must ascend")
	atmo.blend_minutes = PackedInt32Array([300, 1440])
	assert_false(atmo.apply_time(600.0), "minutes must be < 1440")
	atmo.blend_minutes = PackedInt32Array([300, 900])
	assert_true(atmo.apply_time(600.0))


# --- data (ART STYLE LOCK) ---

func test_dawn_and_dusk_presets() -> void:
	assert_eq(dawn.display_name, "Morgendämmerung")
	assert_eq(dusk.display_name, "Abenddämmerung")
	# Dawn: pale light (no saturated hue), cool ambient, lanterns fading.
	assert_true(dawn.sun_color.s < 0.3 and dawn.sun_color.v > 0.85, "pale dawn sun")
	assert_true(dawn.ambient_color.b > dawn.ambient_color.r, "cool dawn ambient")
	assert_true(dawn.sun_energy < day.sun_energy)
	# Dusk: amber sun, violet-blue ambient, lanterns begin to glow.
	assert_true(dusk.sun_color.r > dusk.sun_color.g and dusk.sun_color.g > dusk.sun_color.b, "amber dusk sun")
	var hue := dusk.sun_color.h * 360.0
	assert_true(hue > 20.0 and hue < 45.0, "dusk sun hue near candle amber (#F2A93B ≈ 36°): %f" % hue)
	assert_true(dusk.ambient_color.b > dusk.ambient_color.r and dusk.ambient_color.r >= dusk.ambient_color.g, "violet-blue ambient")
	assert_true(dusk.ambient_color.s < 0.45, "no saturated cold colour (reserved for the supernatural)")
	for p: AtmospherePreset in [dawn, dusk]:
		assert_true(p.warm_light_scale > day.warm_light_scale and p.warm_light_scale < night.warm_light_scale, p.display_name + " lantern level")
		assert_true(p.ambient_energy >= 0.5, p.display_name + " stays readable")
		assert_true(p.sun_rotation_deg.x < -10.0 and p.sun_rotation_deg.x > -25.0, p.display_name + " low sun")
	assert_true(dusk.warm_light_scale > dawn.warm_light_scale, "lanterns glow more at dusk than at dawn")
	assert_true(dawn.sun_rotation_deg.y > 0.0, "sun rises in the east")
	assert_true(dusk.sun_rotation_deg.y < day.sun_rotation_deg.y, "sun sets in the west")


# --- Phase 3: deep night (P4, docs/PHASE3_DESIGN.md §1.4, §2.8) ---

func test_approved_presets_unchanged() -> void:
	# ART STYLE LOCK: day/night/dawn/dusk are approved – byte-identical to Gate G2.
	var approved := {
		"day": "8f9abdf863d1353fdbcaeceaf2a64779",
		"night": "7710841af1d742427c54a2f9108ce216",
		"dawn": "c0bce99ce8c1725b287094d3e40c3d0b",
		"dusk": "0af2f68e49c20f8d36ef0a999a9aeb87",
	}
	for id: String in approved:
		assert_eq(FileAccess.get_md5(DIR + id + ".tres"), approved[id], id + ".tres unchanged")


func test_deep_night_preset() -> void:
	var deep := load(DIR + "deep_night.tres") as AtmospherePreset
	assert_not_null(deep)
	assert_eq(deep.display_name, "Tiefe Nacht")
	assert_almost(deep.sun_energy, 0.45, 0.0001, "moon 0.45")
	assert_almost(deep.fog_density, 0.018, 0.0001)
	assert_almost(deep.volumetric_fog_density, 0.04, 0.0001)
	assert_true(deep.sun_rotation_deg.is_equal_approx(night.sun_rotation_deg), "moon does not move between night and deep night")
	# More fog, colder and darker than the approved night – still readable.
	assert_true(deep.fog_density > night.fog_density and deep.volumetric_fog_density > night.volumetric_fog_density, "more fog")
	assert_true(deep.sun_energy < night.sun_energy)
	var target := Color("#1F2A3A")
	assert_true(_rgb_distance(deep.ambient_color, target) < _rgb_distance(night.ambient_color, target), "ambient towards #1F2A3A")
	assert_true(deep.ambient_color.b > deep.ambient_color.r, "cold ambient")
	assert_true(deep.ambient_energy >= 0.5, "stays readable")
	var albedo := deep.volumetric_fog_albedo
	assert_true(albedo.g > albedo.r and albedo.b > albedo.r and albedo.s < 0.35, "pale blue-green fog")
	assert_true(deep.saturation <= night.saturation)
	assert_almost(deep.warm_light_scale, night.warm_light_scale, 0.0001, "lanterns stay warm (contrast to the ghosts)")


func test_contract_keyframes_with_deep_night() -> void:
	var deep := load(DIR + "deep_night.tres") as AtmospherePreset
	var keys: Array[AtmospherePreset] = [deep, deep, night, dawn, day, day, dusk, night, deep]
	var minutes := PackedInt32Array([0, 180, 270, 330, 480, 1020, 1140, 1260, 1350])
	var atmo := _make_blend(keys, minutes)
	await wait_frames(1)
	for i: int in minutes.size():
		assert_eq(_fields(atmo.blend_at(minutes[i])), _fields(keys[i]), "keyframe %d" % minutes[i])
	for minute: float in [1350.0, 1439.0, 30.0, 179.9]:
		assert_eq(_fields(atmo.blend_at(minute)), _fields(deep), "deep night holds 22:30 … 03:00 (%s)" % minute)
	var mid := atmo.blend_at(225.0)  # 03:00 → 04:30 back to night
	assert_almost(mid.fog_density, lerpf(deep.fog_density, night.fog_density, 0.5), 0.00001)
	var evening := atmo.blend_at(1305.0)  # 21:00 → 22:30 into deep night
	assert_almost(evening.volumetric_fog_density, lerpf(night.volumetric_fog_density, deep.volumetric_fog_density, 0.5), 0.00001)
	assert_true(evening.sun_rotation_deg.is_equal_approx(night.sun_rotation_deg), "no moon sweep")
	for minute: float in [540.0, 900.0]:
		assert_eq(_fields(atmo.blend_at(minute)), _fields(day), "day unchanged (%s)" % minute)
	atmo.apply_time(60.0)
	_assert_applied(atmo, deep, "applied at 01:00")


# --- helpers ---

func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()



func _make(fixed: Array[AtmospherePreset], time_driven: bool = false) -> AtmosphereController:
	var root := Node3D.new()
	var env_node := WorldEnvironment.new()
	env_node.environment = Environment.new()
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	lamp = OmniLight3D.new()
	lamp.set_meta("base_energy", 2.0)
	lamp.add_to_group("warm_lights")
	root.add_child(lamp)
	var atmo := AtmosphereController.new()
	atmo.presets = fixed
	atmo.world_environment = env_node
	atmo.sun = sun
	atmo.time_driven = time_driven
	root.add_child(atmo)
	tree.root.add_child.call_deferred(root)
	return atmo


func _make_blend(keys: Array[AtmospherePreset], minutes: PackedInt32Array = PackedInt32Array(DEFAULT_MINUTES)) -> AtmosphereController:
	var atmo := _make([], true)
	atmo.blend_presets = keys
	atmo.blend_minutes = minutes
	return atmo


func _preset(color: Color, energy: float, yaw: float) -> AtmospherePreset:
	var p := AtmospherePreset.new()
	p.sun_color = color
	p.sun_energy = energy
	p.sun_rotation_deg = Vector3(-30, yaw, 0)
	return p


## Script fields of a preset (name -> value).
func _fields(p: AtmospherePreset) -> Dictionary:
	var out := {}
	for prop: Dictionary in p.get_property_list():
		var usage: int = prop.usage
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			out[prop.name] = p.get(prop.name)
	return out


func _assert_applied(atmo: AtmosphereController, p: AtmospherePreset, label: String) -> void:
	var env := atmo.world_environment.environment
	var ok := atmo.sun.light_color.is_equal_approx(p.sun_color) \
			and is_equal_approx(atmo.sun.light_energy, p.sun_energy) \
			and atmo.sun.rotation_degrees.is_equal_approx(p.sun_rotation_deg) \
			and is_equal_approx(atmo.sun.shadow_opacity, p.sun_shadow_opacity) \
			and env.background_color.is_equal_approx(p.background_color) \
			and env.ambient_light_color.is_equal_approx(p.ambient_color) \
			and is_equal_approx(env.ambient_light_energy, p.ambient_energy) \
			and env.fog_light_color.is_equal_approx(p.fog_color) \
			and is_equal_approx(env.fog_density, p.fog_density) \
			and is_equal_approx(env.volumetric_fog_density, p.volumetric_fog_density) \
			and env.volumetric_fog_albedo.is_equal_approx(p.volumetric_fog_albedo) \
			and env.volumetric_fog_emission.is_equal_approx(p.volumetric_fog_emission) \
			and is_equal_approx(env.tonemap_exposure, p.exposure) \
			and is_equal_approx(env.glow_intensity, p.glow_intensity) \
			and is_equal_approx(env.adjustment_saturation, p.saturation) \
			and is_equal_approx(lamp.light_energy, 2.0 * p.warm_light_scale)
	assert_true(ok, "%s: scene does not match '%s'" % [label, p.display_name])
