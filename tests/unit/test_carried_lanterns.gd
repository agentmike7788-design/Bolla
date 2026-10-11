extends TestCase
## G8 Runde 2 (Lichtgang, „die Laternen sind nur Leuchtpunkte"): the carried lanterns (CarriedLanterns) on real
## figures (Npc + the exported model): the lantern mesh shows in lantern_walk / lantern_idle and joins the group,
## at most pool_size real lights (no shadow) for the nearest lanterns, a fake spot for every visible lantern, flame /
## glass / light / spot in step, the swing about the bail while walking, the candles' share (GraveCare) and the
## browser values (RendererInfo.force).

const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const MODELS := ["res://assets/models/characters/ph_chr_v_priest.glb", "res://assets/models/characters/ph_chr_mourner_w_a.glb",
		"res://assets/models/characters/ph_chr_mourner_m_b.glb", "res://assets/models/characters/ph_chr_v_grocer.glb",
		"res://assets/models/characters/ph_chr_v_smith.glb", "res://assets/models/characters/ph_chr_peddler.glb",
		"res://assets/models/characters/ph_chr_apprentice.glb"]

## A world with waypoints (Npc looks for get_waypoint up its parents).
class LanternWorld extends Node3D:
	func get_waypoint(id: StringName) -> Vector3:
		var m := get_node_or_null(NodePath("Waypoints/" + String(id))) as Node3D
		return m.global_position if m != null else Vector3.ZERO

	func get_waypoint_facing(_id: StringName) -> float:
		return 0.0


var world: Node3D
var pool: CarriedLanterns


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(TimeManager.day, 1050)
	RendererInfo.force = 0
	world = LanternWorld.new()
	world.name = "LanternWorld"
	var holder := Node3D.new()
	holder.name = "Waypoints"
	world.add_child(holder)
	tree.root.add_child(world)
	pool = CarriedLanterns.new()
	world.add_child(pool)
	pool.set_process(false)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	RendererInfo.force = -1
	GameState.reset()
	TimeManager.reset()


## A figure (model `model`) standing at `pos` all day playing `anim`.
func _npc(id: String, model: String, pos: Vector3, anim: StringName) -> Npc:
	var wp := Marker3D.new()
	wp.name = "wp_" + id
	wp.position = pos
	world.get_node("Waypoints").add_child(wp)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	npc.model = load(model) as PackedScene
	var sched := NpcSchedule.new()
	sched.npc_id = npc.npc_id
	sched.display_name = id
	var e := ScheduleEntry.new()
	e.path = PackedStringArray([String(wp.name)])
	e.animation = anim
	sched.entries = [e]
	npc.schedule = sched
	world.add_child(npc)
	return npc


static func _lantern(npc: Npc) -> MeshInstance3D:
	for n: Node in npc.get_tree().get_nodes_in_group(CarriedLanterns.GROUP):
		if npc.is_ancestor_of(n):
			return n as MeshInstance3D
	return null


func test_lantern_mesh_shows_with_the_lantern_clips_and_joins_the_group() -> void:
	for i: int in MODELS.size():
		var model: String = MODELS[i]
		var name := "lantern" if model.ends_with("apprentice.glb") else "lantern_prop"
		for clip: StringName in [&"lantern_idle", &"lantern_walk", &"idle"]:
			var npc := _npc("f%d_%s" % [i, clip], model, Vector3(i * 2.0, 0, 0), clip)
			await wait_frames(1)
			npc.refresh()
			var lantern := _lantern(npc)
			assert_not_null(lantern, "%s: the lantern mesh is a carried lantern" % model.get_file())
			assert_eq(npc.prop_shown(name), clip != &"idle", "%s: %s shows in %s" % [model.get_file(), name, clip])
			assert_true(npc.animation_player().has_animation(clip), "%s has %s" % [model.get_file(), clip])
			npc.free()
	# Lambert's hooded lantern is no carried lantern (a lit slit, no light)
	var robber := _npc("robber", "res://assets/models/characters/ph_chr_robber.glb", Vector3.ZERO, &"idle")
	await wait_frames(1)
	assert_null(_lantern(robber), "the hooded lantern gives no light")


func test_pool_lights_only_the_nearest_lanterns_and_every_lantern_gets_a_spot() -> void:
	var npcs: Array[Npc] = []
	for i: int in 7:
		npcs.append(_npc("p%d" % i, MODELS[i], Vector3(3.0 + i * 3.0, 0, 0), &"lantern_idle"))
	await wait_frames(2)
	pool.settle()
	var n := pool.config.pool_for(false)
	assert_true(n >= 4 and n <= 6, "4–6 pool lights (%d)" % n)
	assert_eq(pool.visible_lanterns().size(), 7, "seven lanterns in view")
	assert_eq(pool.lights_in_use(), n, "≤ N real lights")
	assert_eq(pool.spot_count(), 7, "a fake light spot under every lantern")
	for i: int in 7:
		var light := pool.light_of(_lantern(npcs[i]))
		assert_eq(light != null, i < n, "p%d: a pool light only for the %d nearest" % [i, n])
		if light != null:
			assert_false(light.shadow_enabled, "pool lights cast no shadow")
			assert_true(light.light_energy > 0.0, "the light shines")
			assert_true(light.global_position.distance_to(pool.lantern_center(_lantern(npcs[i]))) < 0.01, "the light sits in the glass")
	# the focus moves to the far end: the lights follow
	var player := Node3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.global_position = Vector3(24.0, 0, 0)
	pool.settle()
	assert_eq(pool.lights_in_use(), n)
	assert_not_null(pool.light_of(_lantern(npcs[6])), "the nearest lantern now has a light")
	assert_null(pool.light_of(_lantern(npcs[0])), "the far one lost it")
	# a lantern put away (idle): no light, no spot
	for npc: Npc in npcs:
		npc.schedule.entries[0].animation = &"idle"
		npc.refresh()
	pool.settle()
	assert_eq(pool.lights_in_use(), 0)
	assert_eq(pool.spot_count(), 0)


func test_flame_glass_light_and_spot_flicker_in_step() -> void:
	var npc := _npc("k", MODELS[0], Vector3(1.0, 0, 0), &"lantern_idle")
	await wait_frames(2)
	pool.settle()
	var lantern := _lantern(npc)
	var flame: ShaderMaterial = null
	var glass: ShaderMaterial = null
	for s: int in lantern.mesh.get_surface_count():
		var m := lantern.get_surface_override_material(s) as ShaderMaterial
		if m == null:
			continue
		if m.resource_name == "mat_emissive_warm":
			flame = m
		elif m.resource_name == "mat_lantern_glass":
			glass = m
	assert_not_null(flame, "the flame has its own material (mat_emissive_warm, the flame shader)")
	assert_not_null(glass, "the glass has its own material (mat_lantern_glass)")
	if flame == null or glass == null:
		return
	assert_almost(float(flame.get_shader_parameter(&"flicker_amount")), 0.0, 0.0001, "the CPU drives the flicker")
	var light := pool.light_of(lantern)
	var cfg := pool.config
	var ks: Array[float] = []
	for step: int in 6:
		pool._process(0.13)
		var k_flame := float(flame.get_shader_parameter(&"glow_energy")) / cfg.flame_energy
		var k_glass := float(glass.get_shader_parameter(&"glow_energy")) / cfg.glass_energy
		var k_light := light.light_energy / (cfg.light_energy * pool._warm_scale())
		assert_almost(k_flame, k_glass, 0.0001, "flame and glass in step")
		assert_almost(k_flame, k_light, 0.0001, "flame and pool light in step")
		ks.append(k_flame)
	var lo := ks.min() as float
	var hi := ks.max() as float
	assert_true(hi - lo > 0.005, "it flickers (%.3f…%.3f)" % [lo, hi])


func test_the_lantern_swings_while_walking() -> void:
	var npc := _npc("w", MODELS[1], Vector3(1.0, 0, 0), &"lantern_walk")
	await wait_frames(2)
	npc.refresh()
	var lantern := _lantern(npc)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(1.0, 12.0, 12.0)
	cam.current = true
	pool.settle()
	var rest: Transform3D = pool._track(lantern).rest
	var anim := npc.animation_player()
	anim.play(&"lantern_walk")
	var angles: Array[float] = []
	for f: int in 8:
		anim.seek(anim.current_animation_length * f / 8.0, true)
		pool._process(0.016)
		angles.append(rad_to_deg(lantern.transform.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion())))
	assert_true((angles.max() as float) > 3.0, "it swings while walking (%s)" % str(angles))
	assert_true((angles.max() as float) <= pool.config.swing_degrees + 0.5, "but not wildly")


func test_candles_give_up_their_share() -> void:
	var care := GraveCare.new()
	world.add_child(care)
	for i: int in 7:
		_npc("c%d" % i, MODELS[i], Vector3(3.0 + i * 3.0, 0, 0), &"lantern_idle")
	await wait_frames(2)
	pool.settle()
	var used := care._lantern_lights_in_use()
	assert_eq(used, mini(pool.lights_in_use(), GraveCare.LIGHT_POOL_SIZE - pool.config.candle_pool_min),
			"the candle pool shrinks by the lantern lights in use")
	assert_true(GraveCare.LIGHT_POOL_SIZE - used >= pool.config.candle_pool_min, "a few candle lights stay")
	assert_true(GraveCare.LIGHT_POOL_SIZE - used + pool.lights_in_use() <= GraveCare.LIGHT_POOL_SIZE,
			"candles + lanterns never more lights than the candles alone had (§9 budget)")


func test_browser_values_come_from_the_config() -> void:
	var cfg := load(CarriedLanterns.CONFIG_PATH) as LanternLightConfig
	assert_not_null(cfg, "data/config/fx/carried_lanterns.tres")
	assert_true(cfg.pool_for(true) >= 1 and cfg.pool_for(true) <= cfg.pool_for(false), "the browser has no more pool lights")
	world.free()
	RendererInfo.force = 1
	world = Node3D.new()
	tree.root.add_child(world)
	pool = CarriedLanterns.new()
	world.add_child(pool)
	await wait_frames(1)
	assert_eq(pool.pool_size(), cfg.pool_for(true), "Compatibility: pool_size_compat")


## §9 (Lichtgang ≤ +0,5 ms script time per frame): the whole pool with 16 carried lanterns walking.
func test_sixteen_lanterns_stay_cheap() -> void:
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(12.0, 14.0, 14.0)
	cam.current = true
	for i: int in 16:
		_npc("b%d" % i, MODELS[i % MODELS.size()], Vector3((i % 8) * 2.5, 0, (i / 8) * 3.0), &"lantern_walk")
	await wait_frames(2)
	pool.settle()
	assert_eq(pool.visible_lanterns().size(), 16)
	for i: int in 20:
		pool._process(0.016)
	var t0 := Time.get_ticks_usec()
	var frames := 200
	for i: int in frames:
		pool._process(0.016)
	var per_frame := float(Time.get_ticks_usec() - t0) / frames / 1000.0
	print("[CarriedLanterns] 16 lanterns: %.3f ms per frame (incl. a re-rank every %.1f s)" % [per_frame, pool.config.rank_interval])
	assert_true(per_frame < 0.5, "16 lanterns ≤ 0.5 ms per frame (%.3f ms)" % per_frame)
	assert_eq(pool.lights_in_use(), pool.pool_size())
	assert_eq(pool.spot_count(), 16)
