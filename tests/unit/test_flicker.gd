extends TestCase
## G7 round 1 (fire and candles flicker): FlickerProfile is deterministic per seed and stays in its
## brightness band; every profile in data/config/fx keeps lights at ≥ 60 % of their energy; FlickerLight
## headless scales its owner's base energy inside that band, flickers out of step per instance,
## resolves its profile from the role / name, holds still while hidden and spawns embers only for
## stove / forge; the number of flickering lights per room stays bounded.

const PROFILES := ["candle", "lantern", "stove", "forge", "window"]
const PROFILE_PATH := "res://data/config/fx/%s.tres"
const ROOM_SCENE := "res://src/world/interiors/%s_interior.tscn"
const MAX_FLICKER_PER_ROOM := 8


func test_profiles_are_deterministic_and_banded() -> void:
	for id: String in PROFILES:
		var p := load(PROFILE_PATH % id) as FlickerProfile
		assert_not_null(p, id)
		if p == null:
			continue
		var band := p.band()
		assert_true(band.x >= 0.6, "%s: never below 60 %% (%.2f)" % [id, band.x])
		assert_true(band.y <= 1.4, "%s: never above 140 %% (%.2f)" % [id, band.y])
		var lo := INF
		var hi := -INF
		for k: int in 600:
			var t := k * 0.05
			var f := p.factor(17, t)
			assert_almost(f, p.factor(17, t), 0.0, "%s: same seed, same value" % id)
			lo = minf(lo, f)
			hi = maxf(hi, f)
		assert_true(lo >= band.x - 0.0001 and hi <= band.y + 0.0001, "%s inside its band (%.2f…%.2f)" % [id, lo, hi])
		assert_true(hi - lo > p.amplitude * 0.5, "%s: it really flickers (%.2f)" % [id, hi - lo])


func test_seeds_flicker_out_of_step() -> void:
	var p := load(PROFILE_PATH % "candle") as FlickerProfile
	var diff := 0.0
	for k: int in 200:
		diff += absf(p.factor(1, k * 0.1) - p.factor(2, k * 0.1))
	assert_true(diff / 200.0 > 0.02, "two candles do not pulse in step (%.3f)" % (diff / 200.0))


func test_flicker_light_scales_the_base_energy_headless() -> void:
	var a := _light("Light_candle", Vector3(1, 1, 1))
	var b := _light("Light_candle_2", Vector3(3, 1, 2))
	assert_eq(a.profile, load(PROFILE_PATH % "candle"), "candle profile by name")
	var band := a.profile.band()
	var seen_a: Array[float] = []
	var seen_b: Array[float] = []
	for i: int in 30:
		await tree.process_frame
		seen_a.append(a.light_energy)
		seen_b.append(b.light_energy)
	for e: float in seen_a:
		assert_true(e >= 2.0 * band.x - 0.001 and e <= 2.0 * band.y + 0.001, "energy %.2f inside 2.0 × band" % e)
	assert_ne(seen_a, seen_b, "per-instance seed")
	a.visible = false
	var held := a.light_energy
	for i: int in 5:
		await tree.process_frame
	assert_eq(a.light_energy, held, "hidden: no per-frame work")
	assert_null(a.get_node_or_null("Embers"), "no embers on a candle")
	var stove := _light("Light_stove", Vector3(5, 1, 5))
	assert_eq(stove.profile, load(PROFILE_PATH % "stove"))
	assert_not_null(stove.get_node_or_null("Embers"), "sparks at the stove")
	for l: Node in [a, b, stove]:
		l.free()


func test_old_script_path_still_flickers() -> void:
	var l: Node3D = OmniLight3D.new()
	l.name = "Light_lantern"
	l.set_script(load("res://src/world/atmosphere/flicker_light.gd"))
	l.set_meta(&"base_energy", 1.0)
	tree.root.add_child(l)
	await tree.process_frame
	assert_true(l is FlickerLight, "the old path is a FlickerLight")
	assert_eq((l as FlickerLight).profile, load(PROFILE_PATH % "lantern"))
	l.free()


func test_flickering_lights_per_room_are_bounded() -> void:
	for id: String in ["inn", "surgery", "office", "crypt", "chapel", "shed"]:
		var room := (load(ROOM_SCENE % id) as PackedScene).instantiate() as Node3D
		var n := room.find_children("*", "Light3D", true, false).filter(func(x: Node) -> bool: return x is FlickerLight).size()
		assert_true(n <= MAX_FLICKER_PER_ROOM, "%s: ≤ %d flickering lights (%d)" % [id, MAX_FLICKER_PER_ROOM, n])
		room.free()


func _light(light_name: String, at: Vector3) -> FlickerLight:
	var l: Node3D = OmniLight3D.new()
	l.name = light_name
	l.position = at
	l.set_script(load("res://src/world/fx/flicker_light.gd"))
	l.set_meta(&"base_energy", 2.0)
	tree.root.add_child(l)
	return l as FlickerLight
