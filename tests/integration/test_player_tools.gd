extends TestCase
## G7 Runde 2 (Werkzeuge: "Dasselbe für die anderen Werkzeuge"): axe (felling / clearing), pickaxe
## (quarry, ore, workstone), hammer (stations, building, grave markers), chisel (mason) and saw
## (workbench) are their own meshes – on the rig's "tool" bone like the shovel, the chisel on arm_l.
## They live hidden in the tool bag, appear when the draw clip's fist reaches the bag, are held in
## their work loop (chips + the cue in step at the bite) and disappear again when stowed; the shovel
## stays on the back meanwhile. Cancelling stows, loading and changing rooms reset at once.
## Positions are read from the real skeleton after AnimationPlayer.advance (no rendering).

const SCENE := "res://src/entities/player/player.tscn"
const GK := "res://assets/models/characters/ph_chr_gravekeeper.glb"
const DT := 1.0 / 30.0
## Rest-model fist centres (tools/blender/asset_character.py FIST, Godot axes).
const FIST_R := Vector3(-0.31, 0.718, 0.212)
const FIST_L := Vector3(0.31, 0.718, 0.212)
## The right fist leads (the tool follows it): on the handle line; the left fist slides to the
## reachable point (rigid arms) and may lose it a little at the turn of the swing.
const ON_HANDLE := 0.02
const ON_HANDLE_LEFT := 0.08
const BELT := ["Axe", "Pickaxe", "Hammer", "Saw", "Chisel"]
## clip -> tool kind, the meshes it shows, its beat cue
const WORK := {
	&"chop": [&"axe", ["Axe"], &"chop"],
	&"pick": [&"pickaxe", ["Pickaxe"], &"pick_stone"],
	&"hammer": [&"hammer", ["Hammer"], &"hammer"],
	&"chisel": [&"chisel", ["Hammer", "Chisel"], &"chisel"],
	&"saw": [&"saw", ["Saw"], &"saw"],
}

var _p: Player


func after_each() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if is_instance_valid(_p):
		_p.cancel_timed_action()
		_p.free()
	_p = null


# --- asset / data -------------------------------------------------------------------------

func test_tools_are_their_own_nodes() -> void:
	var scene := (load(GK) as PackedScene).instantiate()
	for mesh_name: String in BELT:
		var m := scene.find_child(mesh_name, true, false) as MeshInstance3D
		assert_not_null(m, "%s mesh" % mesh_name)
		if m == null:
			continue
		assert_true(m.get_parent() is BoneAttachment3D, "%s on a BoneAttachment3D" % mesh_name)
		assert_eq((m.get_parent() as BoneAttachment3D).bone_name, "arm_l" if mesh_name == "Chisel" else "tool", mesh_name)
		assert_null(m.skin, "%s not skinned into the body" % mesh_name)
	for marker: String in ["axe_edge", "pick_tip", "hammer_face", "saw_teeth", "chisel_edge"]:
		assert_not_null(scene.find_child(marker, true, false), "marker %s" % marker)
	scene.free()


func test_tool_meshes_are_sparing() -> void:
	# the whole figure stays within 12 000 tris (test_assets_characters); the tools take little of it
	var scene := (load(GK) as PackedScene).instantiate()
	var total := 0
	for mesh_name: String in BELT:
		var m := scene.find_child(mesh_name, true, false) as MeshInstance3D
		if m != null:
			total += _tris(m.mesh)
	assert_true(total > 0 and total <= 160, "belt tools %d tris" % total)
	scene.free()


func test_clips_and_config() -> void:
	var scene := (load(GK) as PackedScene).instantiate()
	var ap := scene.get_node("AnimationPlayer") as AnimationPlayer
	var cfg := _cfg()
	for clip: StringName in WORK:
		var kind: StringName = WORK[clip][0]
		assert_eq(cfg.held_tools.get(clip), kind, "%s held with %s" % [clip, kind])
		assert_true(ap.has_animation(clip), "clip %s" % clip)
		assert_ne(ap.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s loops" % clip)
		for clips: Dictionary in [cfg.draw_clips, cfg.stow_clips, cfg.stow_walk_clips]:
			var one: StringName = clips.get(kind, &"")
			assert_true(ap.has_animation(one), "%s: clip %s" % [kind, one])
			if ap.has_animation(one):
				assert_eq(ap.get_animation(one).loop_mode, Animation.LOOP_NONE, "%s one-shot" % one)
		assert_true(cfg.bite_at.has(clip), "%s: bite" % clip)
		assert_eq(cfg.beat_cues.get(clip), WORK[clip][2], "%s: cue" % clip)
		assert_eq(Array(cfg.tool_meshes.get(kind, PackedStringArray())), WORK[clip][1], "%s meshes" % kind)
	for draw: StringName in cfg.draw_show_at:
		assert_true(cfg.draw_show_at[draw] > 0.1 and cfg.draw_show_at[draw] < 0.7, "%s shows mid-draw" % draw)
	scene.free()


func test_every_action_uses_its_tool() -> void:
	var want := {&"axe": &"chop", &"pickaxe": &"pick", &"shovel": &"dig"}
	for dir: String in ["res://data/clearables", "res://data/gather"]:
		for f: String in DirAccess.get_files_at(dir):
			if not f.ends_with(".tres"):
				continue
			var data := load(dir.path_join(f))
			var kind: StringName = data.get(&"tool_kind")
			var clip: StringName = data.get(&"animation")
			assert_ne(clip, &"dig_bare", "%s: no empty-handed digging any more" % f)
			if want.has(kind):
				assert_eq(clip, want[kind], "%s (%s)" % [f, kind])
			else:
				assert_false(clip in [&"chop", &"pick", &"dig"], "%s: no tool, no tool clip (%s)" % [f, clip])
	assert_eq((load("res://data/clearables/fence_gap.tres") as Resource).get(&"animation"), &"hammer", "fence: hammer")
	for gate: String in ["gate_church", "gate_east", "gate_small"]:
		assert_eq((load("res://data/clearables/%s.tres" % gate) as Resource).get(&"animation"), &"interact", "%s: by hand" % gate)
	assert_eq(ToolAnimConfig.clip_for(&"station_workbench"), &"saw")
	assert_eq(ToolAnimConfig.clip_for(&"station_forge"), &"hammer")
	assert_eq(ToolAnimConfig.clip_for(&"station_mason"), &"chisel")
	assert_eq(ToolAnimConfig.clip_for(&"stone_carve"), &"chisel")
	assert_eq(ToolAnimConfig.clip_for(&"build_site"), &"hammer")
	assert_eq(ToolAnimConfig.clip_for(&"building_upgrade"), &"hammer")
	assert_eq(ToolAnimConfig.clip_for(&"grave_marker"), &"hammer")
	assert_eq(ToolAnimConfig.clip_for(&"station_loom"), &"interact", "the loom: by hand")
	assert_eq(ToolAnimConfig.clip_for(&"station_pult", &"x"), &"x", "unknown keys keep the caller's clip")


# --- in the game -------------------------------------------------------------------------

func test_at_rest_only_the_shovel_shows() -> void:
	_p = await _player()
	_tick(1)
	assert_true(_visible("Shovel"), "shovel on the back")
	for mesh_name: String in BELT:
		assert_false(_visible(mesh_name), "%s in the bag" % mesh_name)


func test_chop_draws_holds_and_stows_the_axe() -> void:
	_p = await _player()
	var done := [false]
	assert_true(_p.start_timed_action("Erle fällen", 60, func() -> void: done[0] = true, true, &"chop"))
	_tick(1)
	var anim := _anim()
	assert_eq(anim.current_animation, &"axe_draw", "draws first")
	assert_eq(_p.held_tool(), &"axe")
	assert_false(_visible("Axe"), "still in the bag at the start of the draw")
	assert_true(_shovel_on_back(), "the shovel stays on the back")
	_tick_until(func() -> bool: return _visible("Axe"), 0.5)
	var pos := anim.current_animation_position / anim.current_animation_length
	assert_eq(anim.current_animation, &"axe_draw")
	# shown in the step that passed the mark (the clip has advanced one more step since)
	var late := 2.0 * DT / anim.current_animation_length
	assert_true(pos >= _cfg().draw_show_at[&"axe_draw"] and pos <= _cfg().draw_show_at[&"axe_draw"] + late + 0.01,
			"appears when the fist is at the bag (%.2f)" % pos)
	_tick_until(func() -> bool: return anim.current_animation == &"chop", 1.0)
	assert_eq(_p._animator.phase, PlayerAnimator.ToolPhase.HOLD)
	var checked := 0
	while _p.is_busy() and checked < 200:
		_tick(1)
		checked += 1
		if _p.is_busy() and anim.current_animation == &"chop":
			assert_true(_fist_off(FIST_R, "arm_r") < ON_HANDLE, "right fist on the haft (%.3f)" % _fist_off(FIST_R, "arm_r"))
			assert_true(_fist_off(FIST_L, "arm_l") < ON_HANDLE_LEFT, "left fist on the haft (%.3f)" % _fist_off(FIST_L, "arm_l"))
			assert_true(_visible("Axe") and _visible("Shovel"), "axe in the hands, shovel on the back")
			assert_true(_shovel_on_back(), "shovel follows the spine, not the tool bone")
	assert_true(done[0], "the action finished")
	assert_eq(anim.current_animation, &"axe_stow", "puts it back")
	_tick_until(func() -> bool: return not _visible("Axe"), 0.5)
	pos = anim.current_animation_position / anim.current_animation_length
	late = 2.0 * DT / anim.current_animation_length
	assert_true(pos >= _cfg().stow_hide_at[&"axe_stow"] and pos <= _cfg().stow_hide_at[&"axe_stow"] + late + 0.01,
			"disappears at the bag (%.2f)" % pos)
	_tick_until(func() -> bool: return _p.held_tool() == &"", 1.0)
	assert_eq(anim.current_animation, &"idle")
	_tick(1)
	assert_true(_tool_bone_at_rest(), "tool bone back on the back")
	assert_true(_shovel_at_home(), "shovel on its own bone again")


func test_pick_with_both_fists_on_the_haft() -> void:
	_p = await _player()
	_p.start_timed_action("Erz abbauen", 60, func() -> void: pass, true, &"pick")
	var anim := _anim()
	_tick_until(func() -> bool: return anim.current_animation == &"pick", 1.0)
	assert_true(_visible("Pickaxe") and not _visible("Axe"))
	var lowest := INF
	for i: int in 40:
		_tick(1)
		assert_true(_fist_off(FIST_R, "arm_r") < ON_HANDLE, "right fist on the haft")
		assert_true(_fist_off(FIST_L, "arm_l") < ON_HANDLE_LEFT, "left fist on the haft (%.3f)" % _fist_off(FIST_L, "arm_l"))
		lowest = minf(lowest, _marker("pick_tip").y - _p.global_position.y)
	assert_true(lowest < 0.35, "the pick comes down to the rock (%.2f m)" % lowest)


func test_hammer_chisel_and_saw_show_their_meshes() -> void:
	_p = await _player()
	for clip: StringName in [&"hammer", &"chisel", &"saw"]:
		_p.start_timed_action("Arbeiten", 60, func() -> void: pass, true, clip)
		var anim := _anim()
		_tick_until(func() -> bool: return anim.current_animation == clip, 1.5)
		assert_eq(anim.current_animation, clip, "%s held" % clip)
		_tick(12)  # past the draw -> hold cross-fade
		for mesh_name: String in BELT:
			assert_eq(_visible(mesh_name), mesh_name in WORK[clip][1], "%s: %s" % [clip, mesh_name])
		assert_true(_fist_off(FIST_R, "arm_r") < ON_HANDLE, "%s: right fist on the handle" % clip)
		_p.cancel_timed_action()
		_tick_until(func() -> bool: return _p.held_tool() == &"", 1.0)
		_tick(1)
		for mesh_name: String in BELT:
			assert_false(_visible(mesh_name), "%s: %s back in the bag" % [clip, mesh_name])


func test_chisel_strikes_on_the_chisel() -> void:
	_p = await _player()
	_p.start_timed_action("Inschrift", 60, func() -> void: pass, true, &"chisel")
	var anim := _anim()
	_tick_until(func() -> bool: return anim.current_animation == &"chisel", 1.5)
	var nearest := INF
	for i: int in 20:
		_tick(1)
		nearest = minf(nearest, _marker("hammer_face").distance_to(_marker("chisel_edge")))
	assert_true(nearest < 0.3, "the hammer comes down onto the chisel (%.2f m from its edge)" % nearest)


func test_cancel_by_walking_stows_while_walking() -> void:
	_p = await _player()
	_p.start_timed_action("Erle fällen", 60, func() -> void: pass, true, &"chop")
	var anim := _anim()
	_tick_until(func() -> bool: return anim.current_animation == &"chop", 1.0)
	Input.action_press(&"move_right")
	_tick(1)
	assert_false(_p.is_busy(), "moving cancels")
	assert_eq(anim.current_animation, &"axe_stow_walk")
	_tick_until(func() -> bool: return _p.held_tool() == &"", 1.5)
	assert_eq(anim.current_animation, &"walk", "walks on")
	_tick(1)
	assert_false(_visible("Axe"))
	assert_true(_tool_bone_at_rest() and _shovel_at_home())


func test_load_and_room_change_reset_at_once() -> void:
	_p = await _player()
	for change: Callable in [func() -> void: _p.load_state(_p.save_state()),
			func() -> void: _p.set_in_interior(true, &"hut"), func() -> void: _p.set_region(&"graveyard")]:
		_p.start_timed_action("Erz abbauen", 60, func() -> void: pass, true, &"pick")
		_tick_until(func() -> bool: return _anim().current_animation == &"pick", 1.0)
		_tick(5)
		assert_true(_visible("Pickaxe"))
		_p.cancel_timed_action()
		change.call()
		assert_eq(_p.held_tool(), &"")
		_settle()
		assert_false(_visible("Pickaxe"), "back in the bag at once")
		assert_true(_visible("Shovel") and _shovel_at_home(), "shovel back on its bone")
		assert_true(_tool_bone_at_rest())
		_tick(1)
		assert_ne(_anim().current_animation, &"pick_stow", "no stow after a reset")
	_p.set_in_interior(false)


func test_switching_tools_mid_stow() -> void:
	_p = await _player()
	_p.start_timed_action("Erle fällen", 60, func() -> void: pass, true, &"chop")
	_tick_until(func() -> bool: return _anim().current_animation == &"chop", 1.0)
	_p.cancel_timed_action()
	_tick(2)
	assert_eq(_anim().current_animation, &"axe_stow")
	_p.start_timed_action("Grab ausheben", 60, func() -> void: pass, true, &"dig")
	_tick(1)
	assert_eq(_p.held_tool(), &"shovel")
	assert_false(_visible("Axe"), "the axe is gone when the shovel is drawn")
	assert_true(_shovel_at_home(), "the shovel is on its bone for digging")


func test_work_cue_in_step_with_the_bite() -> void:
	for clip: StringName in [&"chop", &"pick", &"hammer"]:
		_p = await _player()
		Audio.reset()
		Audio.enabled = true
		var cue: StringName = WORK[clip][2]
		assert_true(_p.syncs_work_cue(clip), "%s syncs" % clip)
		assert_eq(_p.beat_cue(clip), cue)
		# the label would say something else ("durchschneiden" -> snip): the tool's cue wins
		_p.start_timed_action("Dornenhecke durchschneiden", 60, func() -> void: pass, true, clip)
		assert_false(cue in Audio.played, "%s: no sound before the bite" % clip)
		var anim := _anim()
		_tick_until(func() -> bool: return cue in Audio.played, 2.5)
		assert_true(cue in Audio.played, "%s: the bite sounds %s" % [clip, cue])
		assert_eq(anim.current_animation, clip)
		# heard in the step that passed the bite (the clip has advanced one more step since)
		var pos := anim.current_animation_position / anim.current_animation_length
		var late := 2.0 * DT / anim.current_animation_length
		assert_true(pos >= _cfg().bite_at[clip] - 0.01 and pos <= _cfg().bite_at[clip] + late + 0.01,
				"%s at the bite (%.2f)" % [clip, pos])
		_p.cancel_timed_action()
		Audio.reset()
		_p.free()
	_p = null


func test_chips_at_the_bite() -> void:
	for clip: StringName in [&"chop", &"pick"]:
		_p = await _player()
		_p.start_timed_action("Arbeiten", 60, func() -> void: pass, true, clip)
		var node := NodePath("Chips_" + String(clip))
		_tick_until(func() -> bool: return _p.get_node_or_null(node) != null, 3.0)
		var chips := _p.get_node_or_null(node) as CPUParticles3D
		assert_not_null(chips, "%s: chips" % clip)
		if chips != null:
			assert_true(chips.one_shot and chips.emitting)
			assert_true(chips.amount <= 8, "sparing")
			var anim := _anim()
			var pos := anim.current_animation_position / anim.current_animation_length
			assert_almost(pos, _cfg().bite_at[clip], 0.08, "%s at the bite (%.2f)" % [clip, pos])
		_p.cancel_timed_action()
		_p.free()
	_p = null


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


func _tick(n: int) -> void:
	for i: int in n:
		_p._physics_process(DT)
		_anim().advance(DT)
	_attachments()


## Bone attachments follow the skeleton on its (deferred) update – stepped by hand here.
func _attachments() -> void:
	for a: Node in _p.model.find_children("*", "BoneAttachment3D", true, false):
		(a as BoneAttachment3D).on_skeleton_update()


func _tick_until(cond: Callable, max_sec: float) -> void:
	var t := 0.0
	while not cond.call() and t < max_sec:
		_tick(1)
		t += DT


func _settle() -> void:
	_anim().advance(0.0)
	_attachments()


func _visible(mesh_name: String) -> bool:
	var n := _p.model.find_child(mesh_name, true, false) as Node3D
	return n != null and n.visible


func _marker(marker: String) -> Vector3:
	var n := _p.model.find_child(marker, true, false) as Node3D
	return n.global_position if n != null else Vector3.INF


## Skeleton-space position of a rest-model point carried by `bone` in the current pose.
func _posed(bone: String, rest_point: Vector3) -> Vector3:
	var sk := _sk()
	var i := sk.find_bone(bone)
	return sk.get_bone_global_pose(i) * (sk.get_bone_global_rest(i).affine_inverse() * rest_point)


## Distance of a fist centre from the handle line (the tool bone's head along its Y axis).
func _fist_off(fist: Vector3, arm: String) -> float:
	var f := _posed(arm, fist)
	var pose := _sk().get_bone_global_pose(_sk().find_bone("tool"))
	var d := pose.basis.y.normalized()
	var r := f - pose.origin
	return (r - d * r.dot(d)).length()


func _tool_bone_at_rest() -> bool:
	var sk := _sk()
	var i := sk.find_bone("tool")
	var pose := sk.get_bone_pose(i)
	var rest := sk.get_bone_rest(i)
	return pose.origin.distance_to(rest.origin) < 0.01 and \
			pose.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()) < 0.02


func _shovel_node() -> Node3D:
	return _p.model.find_child("Shovel", true, false) as Node3D


func _shovel_at_home() -> bool:
	var s := _shovel_node()
	return s != null and s.get_parent() is BoneAttachment3D and (s.get_parent() as BoneAttachment3D).bone_name == "tool"


## The shovel sits where the spine carries the tool bone at rest (its place on the back).
func _shovel_on_back() -> bool:
	if _shovel_at_home():
		return _tool_bone_at_rest()
	var sk := _sk()
	var s := _shovel_node()
	var tool := sk.find_bone("tool")
	var want := sk.global_transform * sk.get_bone_global_pose(sk.get_bone_parent(tool)) * sk.get_bone_rest(tool) * s.transform
	return s.global_transform.origin.distance_to(want.origin) < 0.01


func _tris(mesh: Mesh) -> int:
	var tris := 0
	for s: int in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		tris += (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris
