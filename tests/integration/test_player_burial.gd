extends TestCase
## G7 Runde 2 (Bestatten, „Beim Bestatten soll er die Leiche sichtbar ins Grab legen und nicht so
## auf den Boden"): at an open grave the gravekeeper steps to the pit's long side, lays the carried
## dead onto the pit floor (corpse_lower, corpse_down), stands a moment in silence (mourn), then
## fills the grave with the shovel – the earth rises with each throw, the last throw ends the
## action and the plot shows its fresh mound. Never beside the pit. Cancelling puts the dead back
## into his arms, loading / changing rooms at once; the game logic (minutes, records) is unchanged.
## Runs in the generated world (real plots, corpse models, colliders); the player is stepped by hand.

const WORLD := "res://src/world/graveyard/graveyard.tscn"
const DT := 1.0 / 30.0
## The pit's inner wall ring (plot-local half extents, asset_props_slice.PIT_RINGS: 0.47 × 0.97 m)
## and its floor height (3–4 cm above the ground).
const WALL_X := 0.47
const WALL_Z := 0.97
const FLOOR_Y := 0.032
## The pit rim's crest (m above the ground): outside the pit the dead never comes lower.
const RIM_Y := 0.09

var world: WorldRoot
var player: Player


func before_each() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	player = world.get_player()
	player.set_physics_process(false)


func after_each() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if is_instance_valid(player):
		player.cancel_timed_action()
	Audio.reset()
	if is_instance_valid(world):
		tree.root.remove_child(world)
		world.free()
	world = null
	player = null


# --- data & clips ------------------------------------------------------------------------

func test_clips_and_config() -> void:
	var cfg := _cfg()
	var anim := player._anim
	for clip: StringName in [cfg.burial_lower_clip, cfg.burial_mourn_clip, cfg.burial_step_clip, cfg.burial_fill_clip]:
		assert_true(anim.has_animation(clip), "clip %s" % clip)
	assert_almost(anim.get_animation(cfg.burial_lower_clip).length, cfg.burial_lower_seconds, 0.04, "lowering = its stage")
	assert_almost(anim.get_animation(cfg.burial_mourn_clip).length, cfg.burial_silence_seconds, 0.04, "silence = its stage")
	assert_eq(anim.get_animation(cfg.burial_lower_clip).loop_mode, Animation.LOOP_NONE)
	assert_eq(anim.get_animation(cfg.burial_mourn_clip).loop_mode, Animation.LOOP_NONE)
	assert_true(cfg.burial_lower_seconds >= 1.5 and cfg.burial_lower_seconds <= 2.0, "1.5–2 s lowering")
	assert_eq(cfg.burial_fill_scales.size(), cfg.burial_throws - 1, "one earth step per throw, the last = the mound")
	assert_eq(cfg.burial_sink.size(), cfg.burial_throws - 1)
	var seconds := cfg.burial_seconds(anim)
	assert_true(seconds > 5.0 and seconds < 10.0, "burial sequence %.1f s" % seconds)


# --- the burial --------------------------------------------------------------------------

func test_lays_the_dead_into_the_pit_and_fills_it() -> void:
	await _bury_and_check("plot_01")


func test_lindenacker_plot() -> void:
	world.graveyard.unlock_section(&"linden")
	await _bury_and_check("l_01")


func test_open_grave_with_the_spoil_at_the_foot() -> void:
	world.graveyard.unlock_section(&"linden")
	await _bury_and_check("l_04")


func test_lifted_old_grave_reburied() -> void:
	assert_true(world.graveyard.lift_old("old_01"), "old grave lifted")
	await _bury_and_check("old_01")


func test_game_minutes_unchanged() -> void:
	var plot := await _ready_plot("plot_03")
	var minutes := GravePlot._bury_minutes(player)
	var before := TimeManager.total_minutes()
	plot.interact(player)
	assert_true(player.is_busy())
	assert_true(player._action.duration > player.actions.real_seconds_for(minutes), "the bar follows the sequence")
	_run_to_end()
	assert_eq(TimeManager.total_minutes() - before, minutes, "same game minutes as before")


func test_never_beside_the_pit() -> void:
	var plot := await _ready_plot("plot_01")
	plot.interact(player)
	var node := player.carried
	while player.is_busy():
		_tick(1)
		if not is_instance_valid(node) or not node.is_inside_tree() or player._animator.burial.stage == PlayerBurial.Stage.STEP:
			continue
		var box := _box(node, plot)
		var inside := box.position.x >= -WALL_X and box.end.x <= WALL_X and box.position.z >= -WALL_Z and box.end.z <= WALL_Z
		assert_true(inside or box.position.y > RIM_Y, "outside the pit only in the air (%s)" % box)
		if not inside and box.position.y <= RIM_Y:
			return


func test_cancel_puts_the_dead_back_into_the_arms() -> void:
	var plot := await _ready_plot("plot_01")
	plot.interact(player)
	var node := player.carried
	_tick_until(func() -> bool: return player._animator.burial.stage == PlayerBurial.Stage.SILENCE, 5.0)
	assert_false(node.transform.is_equal_approx(Transform3D.IDENTITY), "in the pit")
	Input.action_press(&"move_right")
	_tick(1)
	Input.action_release(&"move_right")
	assert_false(player.is_busy(), "moving cancels")
	_tick(45)
	assert_eq(player.carried, node, "still carried")
	assert_true(node.transform.is_equal_approx(Transform3D.IDENTITY), "back in his arms")
	assert_eq(world.graveyard.get_grave("plot_01").state, GraveRecord.State.DUG, "still open")


func test_cancel_while_filling_takes_the_earth_away() -> void:
	var plot := await _ready_plot("plot_01")
	plot.interact(player)
	var burial := player._animator.burial
	_tick_until(func() -> bool: return burial.throws >= 1, 8.0)
	_tick(8)
	assert_not_null(burial.fill_node(), "earth in the pit")
	player.cancel_timed_action()
	_tick(1)
	assert_null(plot.get_node(^"Visual").get_node_or_null(PlayerBurial.FILL_NODE), "no earth left")
	assert_eq(world.graveyard.get_grave("plot_01").state, GraveRecord.State.DUG)
	_tick(45)
	assert_true(player.carried.transform.is_equal_approx(Transform3D.IDENTITY), "back in his arms")


func test_load_mid_burial_restores_the_saved_state() -> void:
	var plot := await _ready_plot("plot_01")
	var saved := SaveManager.collect_state()
	var corpse_id := player.carried_id
	plot.interact(player)
	_tick_until(func() -> bool: return player._animator.burial.throws >= 1, 8.0)
	SaveManager.apply_state(saved)
	await tree.process_frame
	assert_false(player.is_busy())
	assert_eq(player.carried_id, corpse_id, "carried again")
	assert_true(player.carried.transform.is_equal_approx(Transform3D.IDENTITY), "in his arms")
	assert_eq(world.graveyard.get_grave("plot_01").state, GraveRecord.State.DUG)
	assert_null(plot.get_node(^"Visual").get_node_or_null(PlayerBurial.FILL_NODE), "no earth")
	assert_false(player._animator.burial.is_active())
	var again := SaveManager.collect_state()
	assert_eq(JSON.stringify(again.get("nodes", {}).get("corpse_manager")), JSON.stringify(saved.get("nodes", {}).get("corpse_manager")),
			"corpses roundtrip")
	assert_eq(JSON.stringify(again.get("nodes", {}).get("graveyard")), JSON.stringify(saved.get("nodes", {}).get("graveyard")),
			"graves roundtrip")


func test_changing_rooms_mid_burial() -> void:
	var plot := await _ready_plot("plot_01")
	plot.interact(player)
	_tick_until(func() -> bool: return player._animator.burial.stage == PlayerBurial.Stage.LOWER, 2.0)
	_tick(20)
	player.cancel_timed_action()
	player.set_in_interior(true, &"hut")
	assert_true(player.carried.transform.is_equal_approx(Transform3D.IDENTITY), "in his arms at once")
	assert_false(player._animator.burial.is_active())
	player.set_in_interior(false)


func test_sounds_corpse_down_then_dirt_pour_in_step() -> void:
	var plot := await _ready_plot("plot_01")
	Audio.reset()
	Audio.enabled = true
	plot.interact(player)
	var burial := player._animator.burial
	_tick_until(func() -> bool: return burial.stage == PlayerBurial.Stage.SILENCE, 5.0)
	assert_true(&"corpse_down" in Audio.played, "laid down softly")
	assert_false(&"dirt_pour" in Audio.played, "no pouring before the shovel")
	_tick_until(func() -> bool: return burial.throws >= 1, 6.0)
	assert_true(&"dirt_pour" in Audio.played, "pours with the throw")
	var downs := Audio.played.count(&"corpse_down")
	_run_to_end()
	_tick(3)
	assert_eq(Audio.played.count(&"corpse_down"), downs, "no second putdown when the grave closes")
	Audio.enabled = false


func test_instant_burial_still_works() -> void:
	var plot := await _ready_plot("plot_01")
	player.instant_actions = true
	plot.interact(player)
	assert_eq(world.graveyard.get_grave("plot_01").state, GraveRecord.State.FILLED)
	assert_false(is_instance_valid(player.carried))
	player.instant_actions = false


# --- helpers -----------------------------------------------------------------------------

func _bury_and_check(id: String) -> void:
	var plot := await _ready_plot(id)
	var cfg := _cfg()
	var corpse_id := player.carried_id
	plot.interact(player)
	assert_true(player.is_busy(), "%s: burial started" % id)
	var burial := player._animator.burial
	assert_true(burial.is_active(), "%s: presentation" % id)
	var node := player.carried
	# (a) to the long side
	_tick_until(func() -> bool: return burial.stage != PlayerBurial.Stage.STEP, 2.0)
	var stand := plot.to_local(player.global_position)
	assert_true(absf(stand.x) > WALL_X + 0.2 or absf(stand.z) > WALL_Z + 0.2, "%s: beside the pit, not in it (%s)" % [id, stand])
	assert_eq(player._anim.current_animation, cfg.burial_lower_clip, "%s: lowers" % id)
	# (b) laid onto the pit floor
	_tick_until(func() -> bool: return burial.stage == PlayerBurial.Stage.SILENCE, 3.0)
	_tick(1)
	assert_eq(player._anim.current_animation, cfg.burial_mourn_clip, "%s: silence" % id)
	assert_eq(player.carried, node, "%s: still the carried node (nothing reparented)" % id)
	var box := _box(node, plot)
	assert_true(box.position.x >= -WALL_X and box.end.x <= WALL_X, "%s: across inside the walls (%s)" % [id, box])
	assert_true(box.position.z >= -WALL_Z and box.end.z <= WALL_Z, "%s: lengthwise inside the walls (%s)" % [id, box])
	assert_almost(box.position.y, FLOOR_Y, 0.02, "%s: on the pit floor (%.3f)" % [id, box.position.y])
	assert_true(box.size.y < 0.4, "%s: lying flat (%.2f m high)" % [id, box.size.y])
	var head := (plot.global_basis.inverse() * node.global_basis * Vector3.RIGHT).normalized()
	assert_true(head.dot(Vector3.FORWARD) > 0.95, "%s: head at the marker end (%s)" % [id, head])
	# (d) filled in steps
	var heights: Array[float] = []
	var floor_y: Array[float] = [box.position.y]
	for n: int in range(1, cfg.burial_throws):
		_tick_until(func() -> bool: return burial.throws >= n, 4.0)
		_tick(20)
		var fill := burial.fill_node()
		assert_not_null(fill, "%s: earth after throw %d" % [id, n])
		if fill == null:
			return
		assert_eq(fill.get_parent(), plot.get_node(^"Visual"), "%s: in the pit's visual" % id)
		heights.append(fill.scale.y)
		floor_y.append(_box(node, plot).position.y)
		assert_almost(fill.scale.y, cfg.burial_fill_scales[n - 1], 0.03, "%s: step %d" % [id, n])
		assert_true(is_instance_valid(node) and node.visible, "%s: the dead stays visible in the grave" % id)
	for i: int in range(1, heights.size()):
		assert_true(heights[i] > heights[i - 1], "%s: the earth rises" % id)
	for i: int in range(1, floor_y.size()):
		assert_true(floor_y[i] < floor_y[i - 1], "%s: the dead settles into the earth" % id)
	_run_to_end()
	assert_eq(world.graveyard.get_grave(id).state, GraveRecord.State.FILLED, "%s: buried" % id)
	assert_eq(world.corpse_manager.get_record(corpse_id).location, CorpseRecord.LOCATION_BURIED)
	assert_false(is_instance_valid(player.carried), "%s: hands free" % id)
	await tree.process_frame
	assert_null(plot.get_node(^"Visual").get_node_or_null(PlayerBurial.FILL_NODE), "%s: the mound as before" % id)
	assert_eq(plot.active_collision_roles(), PackedStringArray([GravePlot.ROLE_MOUND]))
	assert_false(burial.is_active())


## Digs `id`, spawns a corpse and puts it into the player's arms next to the plot.
func _ready_plot(id: String) -> GravePlot:
	var plot := world.get_node_by_layout_id(id) as GravePlot
	if world.graveyard.get_grave(id).state == GraveRecord.State.EMPTY:
		world.graveyard.dig(id)
	var manager := world.corpse_manager
	var record := manager.spawn_corpse(null, plot.global_transform, &"ground")
	player.global_position = plot.to_global(Vector3(-1.4, 0.0, 0.6))
	manager.pick_up(record.id, player)
	for i: int in 3:
		await tree.physics_frame
	player.global_position = plot.to_global(Vector3(-1.4, 0.0, 0.6))
	assert_true(plot.can_interact(player), "%s: [E] Bestatten" % id)
	return plot


func _cfg() -> ToolAnimConfig:
	return Database.config(&"tool_anim_config") as ToolAnimConfig


func _tick(n: int) -> void:
	for i: int in n:
		player._physics_process(DT)
		player._anim.advance(DT)


func _tick_until(cond: Callable, max_sec: float) -> void:
	var t := 0.0
	while not cond.call() and t < max_sec:
		_tick(1)
		t += DT


func _run_to_end() -> void:
	var t := 0.0
	while player.is_busy() and t < 15.0:
		_tick(1)
		t += DT
	_tick(1)


## Plot-local bounds of the corpse node's meshes.
static func _box(node: Node3D, plot: Node3D) -> AABB:
	var out := [null]
	_merge(node, plot.global_transform.affine_inverse(), out)
	return out[0] if out[0] != null else AABB()


static func _merge(n: Node, to_plot: Transform3D, out: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree():
		var mi := n as MeshInstance3D
		var a := to_plot * mi.global_transform * mi.get_aabb()
		out[0] = a if out[0] == null else (out[0] as AABB).merge(a)
	for c: Node in n.get_children():
		_merge(c, to_plot, out)
