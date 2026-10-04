extends TestCase
## G7 Runde 2 ("Wenn er ein Grab aushebt, soll er seine Schaufel vom Rücken nehmen und mit der
## graben"): the shovel is its own node on the rig's "tool" bone. Digging, burying, lifting old
## graves and the shovel clearables / clay draw it from the back (shovel_draw), dig with it in both
## hands (dig) and put it back (shovel_stow, shovel_stow_walk when walking off); everything else
## leaves it on the back. Cancelling stows it, loading and changing rooms put it back at once.
## Positions are read from the real skeleton after AnimationPlayer.advance (no rendering).

const SCENE := "res://src/entities/player/player.tscn"
const GK := "res://assets/models/characters/ph_chr_gravekeeper.glb"
const DT := 1.0 / 30.0
## Rest-model points (Blender model space → Godot: x, z, -y) of tools/blender/asset_character.py:
## the shaft end at the D-grip (SHOVEL_G0), the socket end (SHOVEL_G1) and the fist centres (FIST).
const SHAFT_G0 := Vector3(0.25, 0.49, -0.2)
const SHAFT_G1 := Vector3(-0.34, 1.3, -0.31)
const FIST_R := Vector3(-0.31, 0.718, 0.212)
const FIST_L := Vector3(0.31, 0.718, 0.212)
## A fist on the shaft: its centre this close to the shaft line (m; the fist is ~0.1 m wide).
const ON_SHAFT := 0.04
## The left fist may lose the shaft briefly at the end of the throw (rigid arms).
const ON_SHAFT_LEFT := 0.1

var _p: Player


func after_each() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if is_instance_valid(_p):
		_p.cancel_timed_action()
		_p.free()
	_p = null


# --- asset -------------------------------------------------------------------------------

func test_shovel_is_its_own_node_on_the_tool_bone() -> void:
	var scene := (load(GK) as PackedScene).instantiate()
	var sk := scene.get_node("Armature/Skeleton3D") as Skeleton3D
	var tool := sk.find_bone("tool")
	assert_true(tool >= 0, "tool bone")
	assert_eq(sk.get_bone_name(sk.get_bone_parent(tool)), "spine", "the back carries it")
	var shovel := scene.find_child("Shovel", true, false) as MeshInstance3D
	assert_not_null(shovel, "separate Shovel mesh")
	if shovel != null:
		assert_true(shovel.get_parent() is BoneAttachment3D, "on a BoneAttachment3D")
		assert_eq((shovel.get_parent() as BoneAttachment3D).bone_name, "tool")
		assert_null(shovel.skin, "not skinned into the body")
	var blade := scene.find_child("shovel_blade", true, false) as Node3D
	assert_not_null(blade, "blade marker (earth clods)")
	scene.free()


func test_clips_and_config() -> void:
	var scene := (load(GK) as PackedScene).instantiate()
	var ap := scene.get_node("AnimationPlayer") as AnimationPlayer
	var cfg := Database.config(&"tool_anim_config") as ToolAnimConfig
	assert_not_null(cfg)
	assert_eq(cfg.held_tools.get(&"dig"), &"shovel")
	for clip: StringName in [&"dig", &"shovel_draw", &"shovel_stow", &"shovel_stow_walk", &"dig_bare"]:
		assert_true(ap.has_animation(clip), "clip %s" % clip)
	var draw := ap.get_animation(&"shovel_draw")
	var stow := ap.get_animation(&"shovel_stow")
	assert_true(draw.length >= 0.4 and draw.length <= 0.6, "draw %.2f s" % draw.length)
	assert_true(stow.length >= 0.35 and stow.length <= 0.5, "stow %.2f s" % stow.length)
	assert_eq(draw.loop_mode, Animation.LOOP_NONE)
	assert_eq(stow.loop_mode, Animation.LOOP_NONE)
	assert_eq(ap.get_animation(&"shovel_stow_walk").loop_mode, Animation.LOOP_NONE)
	assert_ne(ap.get_animation(&"dig").loop_mode, Animation.LOOP_NONE, "dig loops")
	assert_eq(cfg.draw_clips[&"shovel"], &"shovel_draw")
	assert_eq(cfg.stow_clips[&"shovel"], &"shovel_stow")
	scene.free()


func test_every_shovel_action_uses_the_shovel_clip() -> void:
	var actions := Database.config(&"action_config") as ActionConfig
	var cfg := Database.config(&"tool_anim_config") as ToolAnimConfig
	for action: StringName in actions.action_tools:
		if actions.action_tools[action] == &"shovel":
			assert_eq(cfg.held_tools.get(GravePlot.ANIM_DIG), &"shovel", "grave %s with the shovel" % action)
	for dir: String in ["res://data/clearables", "res://data/gather"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var data := load(dir.path_join(f))
			var kind: StringName = data.get(&"tool_kind")
			var clip: StringName = data.get(&"animation")
			if kind == &"shovel":
				assert_eq(clip, &"dig", "%s: digs with the shovel" % f)
			elif clip == &"dig" or clip == &"dig_bare":
				assert_eq(clip, &"dig_bare", "%s (%s): no shovel in the hands" % [f, kind])


# --- in the game -------------------------------------------------------------------------

func test_shovel_on_the_back_outside_digging() -> void:
	_p = await _player()
	for clip: StringName in [&"idle", &"walk", &"carry_walk", &"interact", &"dig_bare"]:
		_show(clip, 0.4)
		assert_true(_on_back(), "%s: shovel on the back" % clip)


func test_dig_draws_holds_and_stows() -> void:
	_p = await _player()
	var done := [false]
	assert_true(_p.start_timed_action("Grab ausheben", 60, func() -> void: done[0] = true, true, &"dig"))
	_tick(1)
	var anim := _anim()
	assert_eq(anim.current_animation, &"shovel_draw", "draws first")
	assert_eq(_p.held_tool(), &"shovel")
	assert_true(_on_back(), "still on the back at the start of the draw")
	_tick_until(func() -> bool: return anim.current_animation == &"dig", 1.0)
	assert_eq(_p._animator.phase, PlayerAnimator.ToolPhase.HOLD)
	var checked := 0
	while _p.is_busy() and checked < 200:
		_tick(1)
		checked += 1
		if _p.is_busy() and anim.current_animation == &"dig":
			assert_true(_fist_off(FIST_R, "arm_r") < ON_SHAFT, "right fist on the shaft (%.3f)" % _fist_off(FIST_R, "arm_r"))
			assert_true(_fist_off(FIST_L, "arm_l") < ON_SHAFT_LEFT, "left fist on the shaft (%.3f)" % _fist_off(FIST_L, "arm_l"))
			assert_false(_on_back(), "in the hands while digging")
	assert_true(done[0], "the dig finished")
	assert_eq(anim.current_animation, &"shovel_stow", "puts it back")
	_tick_until(func() -> bool: return _p.held_tool() == &"", 1.0)
	assert_eq(anim.current_animation, &"idle")
	_tick(1)
	assert_true(_on_back(), "back on the back")


func test_bury_and_lift_use_the_same_clip() -> void:
	_p = await _player()
	_p.start_timed_action("Bestatten", 30, func() -> void: pass, true, GravePlot.ANIM_DIG)
	_tick(1)
	assert_eq(_p.held_tool(), &"shovel")


func test_cancel_by_walking_stows_while_walking() -> void:
	_p = await _player()
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	var anim := _anim()
	_tick_until(func() -> bool: return anim.current_animation == &"dig", 1.0)
	Input.action_press(&"move_right")
	_tick(1)
	assert_false(_p.is_busy(), "moving cancels")
	assert_eq(anim.current_animation, &"shovel_stow_walk")
	_tick_until(func() -> bool: return _p.held_tool() == &"", 1.5)
	assert_eq(anim.current_animation, &"walk", "walks on")
	_tick(1)
	assert_true(_on_back())


func test_cancel_during_the_draw_stows() -> void:
	_p = await _player()
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	_tick(4)
	_p.cancel_timed_action()
	_tick(1)
	assert_eq(_anim().current_animation, &"shovel_stow")
	_tick_until(func() -> bool: return _p.held_tool() == &"", 1.0)
	_tick(1)
	assert_true(_on_back())


func test_load_puts_it_back_at_once() -> void:
	_p = await _player()
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	var anim := _anim()
	_tick_until(func() -> bool: return anim.current_animation == &"dig", 1.0)
	_tick(10)
	assert_false(_on_back())
	_p.load_state(_p.save_state())
	assert_false(_p.is_busy())
	assert_eq(_p.held_tool(), &"")
	_settle()
	assert_true(_on_back(), "back at once after loading")
	_tick(1)
	assert_ne(anim.current_animation, &"shovel_stow", "no stow after a load")


func test_changing_rooms_puts_it_back_at_once() -> void:
	_p = await _player()
	for change: Callable in [func() -> void: _p.set_in_interior(true, &"hut"), func() -> void: _p.set_region(&"graveyard")]:
		_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
		_tick(20)
		_p.cancel_timed_action()
		change.call()
		assert_eq(_p.held_tool(), &"")
		_settle()
		assert_true(_on_back())
	_p.set_in_interior(false)


func test_work_cue_in_step_with_the_blade() -> void:
	_p = await _player()
	Audio.reset()
	Audio.enabled = true
	assert_true(_p.syncs_work_cue(&"dig"))
	assert_false(_p.syncs_work_cue(&"dig_bare"), "bare-handed work keeps the timer")
	assert_false(_p.syncs_work_cue(&"interact"))
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	assert_false(&"dig" in Audio.played, "no sound before the blade bites")
	var anim := _anim()
	_tick_until(func() -> bool: return &"dig" in Audio.played, 1.5)
	assert_true(&"dig" in Audio.played, "the bite sounds")
	var pos := anim.current_animation_position / anim.current_animation_length
	assert_eq(anim.current_animation, &"dig")
	assert_almost(pos, _cfg().bite_at[&"dig"], 0.06, "at the bite (%.2f)" % pos)
	_p.cancel_timed_action()
	Audio.reset()


func test_earth_clods_at_the_throw() -> void:
	_p = await _player()
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	var anim := _anim()
	_tick_until(func() -> bool: return _p.get_node_or_null(^"EarthClods") != null, 2.5)
	var clods := _p.get_node_or_null(^"EarthClods") as CPUParticles3D
	assert_not_null(clods, "clods thrown")
	if clods != null:
		assert_true(clods.one_shot and clods.emitting)
		assert_true(clods.amount <= 10, "sparing")
		var pos := anim.current_animation_position / anim.current_animation_length
		assert_almost(pos, _cfg().toss_at[&"dig"], 0.06, "at the throw (%.2f)" % pos)


# --- helpers -----------------------------------------------------------------------------

func _player() -> Player:
	var p := (load(SCENE) as PackedScene).instantiate() as Player
	tree.root.add_child(p)
	p.set_physics_process(false)
	await tree.physics_frame
	return p


func _cfg() -> ToolAnimConfig:
	return Database.config(&"tool_anim_config") as ToolAnimConfig


func _anim() -> AnimationPlayer:
	return _p._anim


func _sk() -> Skeleton3D:
	return _p.model.find_child("Skeleton3D", true, false) as Skeleton3D


## One physics step of the player (animator included) and the animation advanced by DT.
func _tick(n: int) -> void:
	for i: int in n:
		_p._physics_process(DT)
		_anim().advance(DT)


func _tick_until(cond: Callable, max_sec: float) -> void:
	var t := 0.0
	while not cond.call() and t < max_sec:
		_tick(1)
		t += DT


func _settle() -> void:
	_anim().advance(0.0)


func _show(clip: StringName, at: float) -> void:
	var anim := _anim()
	anim.play(clip, 0.0)
	anim.seek(anim.current_animation_length * at, true)


## Skeleton-space position of a rest-model point carried by `bone` in the current pose.
func _posed(bone: String, rest_point: Vector3) -> Vector3:
	var sk := _sk()
	var i := sk.find_bone(bone)
	return sk.get_bone_global_pose(i) * (sk.get_bone_global_rest(i).affine_inverse() * rest_point)


## Distance of a fist centre from the shaft line.
func _fist_off(fist: Vector3, arm: String) -> float:
	var f := _posed(arm, fist)
	var a := _posed("tool", SHAFT_G0)
	var b := _posed("tool", SHAFT_G1)
	var d := (b - a).normalized()
	var r := f - a
	return (r - d * r.dot(d)).length()


## The tool bone sits where the spine carries it (its local pose is the rest pose).
func _on_back() -> bool:
	var sk := _sk()
	var i := sk.find_bone("tool")
	var pose := sk.get_bone_pose(i)
	var rest := sk.get_bone_rest(i)
	return pose.origin.distance_to(rest.origin) < 0.01 and \
			pose.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()) < 0.02
