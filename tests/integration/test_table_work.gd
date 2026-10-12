extends TestCase
## G8 Runde 3 (user: „annimationen fehlen", „die leichen preperation annimation fehlen auch"): the work at the crypt
## table in the real world. New game, Osric's first dead carried down and laid on the crypt table; every table action
## started the way the panel starts it (MorgueTable._start_work) plays its own clip from tool_anim_config (never the
## generic reach), the gravekeeper steps to his work spot – the long side away from the camera, the head end for the
## head work – facing the table, the small tool comes out of the bag and goes back, the step ends with the action.

const TIMEOUT := 300.0
const STEP := 1.0 / 60.0
## table key -> clip, tool kind (&"" = bare hands)
const WORK := {
	&"examine": [&"table_examine", &""], &"exam_all": [&"table_examine", &""],
	&"exam_hands": [&"table_examine", &""], &"exam_wounds": [&"table_examine", &""],
	&"exam_clothing": [&"table_search", &""], &"exam_pockets": [&"table_search", &""],
	&"wash": [&"table_wash", &"washcloth"], &"organ": [&"table_cut", &"scalpel"],
	&"lay_out": [&"table_comb", &"comb"], &"balm": [&"table_smoke", &"juniper"],
	&"dress_shroud": [&"table_shroud", &"linen"], &"dress_gown": [&"table_shroud", &"linen"],
	&"harvest_hair": [&"table_snip", &"shears"], &"harvest_teeth": [&"table_pull", &"pliers"],
}
const HEAD_WORK: Array[StringName] = [&"lay_out", &"harvest_hair", &"harvest_teeth"]

var saves_dir := TestCase.user_dir("test_table_work")
var world: WorldRoot
var player: Player
var table: MorgueTable


func before_each() -> void:
	SaveManager.save_dir = saves_dir


func after_each() -> void:
	if player != null:
		player.cancel_timed_action()
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_every_table_action_has_its_own_clip() -> void:
	for key: StringName in WORK:
		assert_eq(MorgueTable.clip_for(key), WORK[key][0], "morgue_%s → %s" % [key, WORK[key][0]])
		assert_ne(MorgueTable.clip_for(key), MorgueTable.ANIM, "%s: not the generic reach" % key)


func test_table_work_in_the_crypt() -> void:
	await _setup()
	var anim := _anim()
	assert_not_null(anim, "the rig")
	for key: StringName in WORK:
		var clip: StringName = WORK[key][0]
		var kind: StringName = WORK[key][1]
		assert_true(anim.has_animation(clip), "rig clip %s" % clip)
		_reset_player()
		var want := table.work_stand(player, clip)
		assert_true(table.call(&"_start_work", player, "Arbeiten", 600, func() -> void: pass, key), "%s starts" % key)
		assert_eq(player._action.animation, clip, "%s plays %s" % [key, clip])
		assert_true(player.is_stepping(), "%s: he steps to his work spot" % key)
		var drawn := false
		for i: int in 150:
			_advance()
			drawn = drawn or (kind != &"" and player.held_tool() == kind)
		assert_false(player.is_stepping(), "%s: the step is over" % key)
		assert_almost(player.global_position.distance_to(want.origin), 0.0, 0.01, "%s: at the work spot" % key)
		var to_table := table.slot_transform().origin - player.global_position
		to_table.y = 0.0
		var facing := player.global_basis.z
		if key in HEAD_WORK:
			assert_almost(player.global_position.distance_to(_head(table) + _axis(table) * _cfg().table_head_distance) , 0.0, 0.02,
					"%s: at the head end" % key)
			assert_true(facing.dot(-_axis(table)) > 0.98, "%s: facing down the body" % key)
		else:
			var off := absf((player.global_position - table.slot_transform().origin).dot(_normal(table)))
			assert_almost(off, _cfg().table_stand_distance, 0.01, "%s: at the long side" % key)
			assert_true(facing.dot(to_table.normalized()) > 0.9, "%s: facing the table" % key)
		if kind != &"":
			assert_true(drawn, "%s: the %s out of the bag" % [key, kind])
			assert_true(anim.current_animation == clip, "%s: works with the tool (%s)" % [key, anim.current_animation])
			assert_true(_shown(kind), "%s: the %s shows in his hand" % [key, kind])
		else:
			assert_eq(player.held_tool(), &"", "%s: bare hands" % key)
		player.cancel_timed_action()
		for i: int in 60:
			_advance()
		assert_eq(player.held_tool(), &"", "%s: everything back in its place" % key)
		if kind != &"":
			assert_false(_shown(kind), "%s: the %s back in the bag" % [key, kind])


## G8 Runde 4 (user: „ja soll etwas länger dauern"): with its real game minutes every table action's bar runs long
## enough for the draw and at least two cycles of its clip (≥ table_real_seconds_min); the game minutes are unchanged,
## and an action elsewhere keeps the short bar.
func test_table_work_lasts_a_few_cycles() -> void:
	await _setup()
	var anim := _anim()
	var cfg := _cfg()
	for key: StringName in [&"exam_hands", &"wash", &"lay_out", &"harvest_hair", &"dress_shroud"]:
		var clip: StringName = WORK[key][0]
		_reset_player()
		assert_true(table.call(&"_start_work", player, "Arbeiten", 10, func() -> void: pass, key), "%s starts" % key)
		var action: Player.TimedAction = player._action
		assert_eq(action.minutes, 10, "%s: the game minutes stay" % key)
		assert_true(action.duration >= cfg.table_real_seconds_min - 0.001, "%s: %.2f s ≥ the minimum" % [key, action.duration])
		var in_clip := 0.0
		var t := 0.0
		while player.is_busy() and t < 10.0:
			_advance()
			t += STEP
			if anim.current_animation == clip:
				in_clip += STEP
		assert_false(player.is_busy(), "%s: done" % key)
		assert_almost(t, action.duration, 0.05, "%s: the bar's real seconds" % key)
		var cycles := in_clip / anim.get_animation(clip).length
		assert_true(cycles >= 1.9, "%s: %.2f cycles of %s seen" % [key, cycles, clip])
		for i: int in 60:
			_advance()
	# elsewhere (not at the table) the bar stays short
	_reset_player()
	assert_true(player.start_timed_action("Woanders", 10, func() -> void: pass, false, &"place_low"))
	assert_almost(player._action.duration, Database.config(&"action_config").real_seconds_for(10), 0.001, "other actions unchanged")
	player.cancel_timed_action()


func test_the_far_side_from_the_camera() -> void:
	await _setup()
	var cam := tree.root.get_camera_3d()
	assert_not_null(cam)
	var centre := table.slot_transform().origin
	var stand := table.work_stand(player, &"table_wash")
	var cam_side := (cam.global_position - centre).dot(_normal(table))
	var his_side := (stand.origin - centre).dot(_normal(table))
	assert_true(cam_side * his_side < 0.0, "he works on the side away from the camera (towards the viewer)")


func _setup() -> void:
	await SaveManager.new_game()
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	TimeManager.running = false
	var manager := world.corpse_manager
	var record := manager.try_daily_delivery(1)
	manager.get_corpse_node(record.id).interact(player)
	var door := BuildingDoor.find(tree, &"crypt")
	door.interact(player)
	for i: int in 120:
		if player.interior_id == &"crypt":
			break
		await tree.process_frame
	table = InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	table.interact(player)
	assert_eq(table.corpse_id, record.id, "the dead on the crypt table")
	player.set_physics_process(false)
	await tree.process_frame


func _reset_player() -> void:
	player.cancel_timed_action()
	player.reset_tool()
	var room := InteriorRoom.find(tree, &"crypt") as Node3D
	player.global_transform = Transform3D(Basis.IDENTITY, room.global_transform * Vector3(0.95, 0.0, 0.6))


func _advance() -> void:
	player._physics_process(STEP)
	var anim := _anim()
	if anim != null:
		anim.advance(STEP)


func _anim() -> AnimationPlayer:
	return player.get(&"_anim") as AnimationPlayer


func _shown(kind: StringName) -> bool:
	var animator := player.get(&"_animator") as PlayerAnimator
	return animator.props.is_shown(ToolProps.SCENE_PREFIX + String(kind))


static func _cfg() -> ToolAnimConfig:
	return Database.config(&"tool_anim_config") as ToolAnimConfig


static func _axis(t: MorgueTable) -> Vector3:
	var x := t.slot_transform().basis.x
	return Vector3(x.x, 0.0, x.z).normalized()


static func _normal(t: MorgueTable) -> Vector3:
	var a := _axis(t)
	return Vector3(-a.z, 0.0, a.x)


static func _head(t: MorgueTable) -> Vector3:
	var o := t.slot_transform().origin
	return Vector3(o.x, 0.0, o.z) + _axis(t) * _cfg().table_head_offset
