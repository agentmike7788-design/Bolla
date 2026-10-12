extends "res://src/world/village/village_shots_phase8.gd"
## G8 Runde 5 (user: „bitte die bekannten probleme mal fixen" – Quasts Gutachten, docs/reviews/phase8_round5/ui_fixes.md):
## Quast's surgery panel open and during the expertise (30 Min). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_quast.gd \
##       -- --out=/abs/dir [--tag=vorher|nachher] [--suffix=_web]
## From the Phase-7 end state (saves_v6/slot_p7_day53_neighbor, real SaveManager) the clock runs to day 54, 10:00 (Quast
## in his surgery by his schedule); the gravekeeper stands at the counter in the room. A dead of the graveyard gives
## him a heart in a jar (Specimens.harvest with its inputs in the pack). The panel opens the way Quast's dialogue
## opens it (&"anatomist" with the speaker), „Gutachten" is pressed, the player and his clip are stepped at 60 Hz to
## 70 % of the work:
##   <out>/quast_<tag><suffix>.jpg, <out>/quast_<tag>_arbeit<suffix>.jpg

const STEP := 1.0 / 60.0
const SHOT_DAY := 54
const SHOT_MINUTE := 600
const ORGAN := &"heart"
const CONTAINER := &"jar"
## Where the gravekeeper waits: this far from Quast towards the camera (+Z).
const NEAR := 1.5


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--suffix="):
			_suffix = arg.trim_prefix("--suffix=")
		elif arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--tag=vorher|nachher] [--suffix=_web]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v6(FIXTURE_V6)
	_advance_to(world, SHOT_DAY, SHOT_MINUTE)
	var clock := root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var inv := player.get(&"inventory") as Node
	# the heart of a dead from the graveyard, in a jar (the harvest's inputs given first)
	var manager := world.get_node(^"Systems/CorpseManager")
	var record: Object = manager.call(&"spawn_corpse", null, Transform3D.IDENTITY, &"ground")
	var specimens := get_first_node_in_group(&"specimens")
	var cfg: Object = specimens.call(&"get_config")
	_give(inv, Dictionary((load("res://src/systems/anatomy/specimen_rules.gd") as GDScript).call(&"harvest_inputs", ORGAN, CONTAINER, cfg)))
	root.get_node(^"GameState").call(&"set_flag", cfg.get(&"known_flag"), true)
	var uid := String(specimens.call(&"harvest", String(record.get(&"id")), ORGAN, CONTAINER, inv))
	print("[ShotsQuast] specimen '%s'" % uid)
	# into the surgery, Quast placed by his schedule, the gravekeeper in front of him
	var room := _room(&"surgery")
	if player.get(&"region_id") != VILLAGE:
		player.call(&"set_region", VILLAGE)
	player.global_transform = room.call(&"spawn_transform")
	player.call(&"set_in_interior", true, &"surgery")
	root.get_node(^"EventBus").emit_signal(&"time_tick", SHOT_DAY, SHOT_MINUTE)
	var npc := world.get_node(^"Regions/Village").find_child("npc_surgeon", true, false) as Node3D
	npc.call(&"refresh")
	for i: int in 3:
		await process_frame
	# on the camera's side of him (+Z), as the work sheets of round 4 stand the gravekeeper
	var spot := npc.global_position + Vector3(0.25, 0.0, NEAR)
	spot.y = player.global_position.y
	var d := npc.global_position - spot
	player.global_transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), spot)
	rig.set(&"target", player)
	rig.call(&"set_distance", float(room.call(&"room_config").get(&"camera_distance")))
	rig.call(&"snap")
	ui.visible = true
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	root.get_node(^"EventBus").emit_signal(&"ui_panel_requested", &"anatomist", {"speaker": npc, "inventory": inv, "player": player})
	for i: int in SETTLE_FRAMES:
		await process_frame
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await process_frame
	var panel: Object = ui.call(&"get_panel", &"anatomist")
	var rect: Rect2 = (panel as Control).get_global_rect()
	print("[ShotsQuast] canvas %s panel %s docked=%s" % [root.get_visible_rect().size, rect, panel.get(&"dock_right")])
	_save_shot(_out.path_join("quast_%s%s.jpg" % [_tag, _suffix]))
	var rows: Dictionary = panel.get(&"rows")
	var button := (rows.get(uid, {}) as Dictionary).get("expertise") as BaseButton
	if button == null or button.disabled:
		push_warning("[ShotsQuast] no expertise to start: %s" % (button.tooltip_text if button != null else "no row"))
		quit(1)
		return
	print("[ShotsQuast] pressing '%s'" % button.text)
	button.pressed.emit()
	var action: Object = player.get(&"_action")
	var duration := float(action.get(&"duration")) if action != null else 0.0
	var t := 0.0
	while t < duration * 0.7:
		player.call(&"_physics_process", STEP)
		anim.advance(STEP)
		t += STEP
	for i: int in SETTLE_FRAMES:
		await process_frame
	print("[ShotsQuast] +%.1f s of %.1f busy=%s panel_visible=%s clip=%s" % [t, duration, player.call(&"is_busy"), (panel as Control).visible,
			anim.current_animation])
	_save_shot(_out.path_join("quast_%s_arbeit%s.jpg" % [_tag, _suffix]))
	while bool(player.call(&"is_busy")):
		player.call(&"_physics_process", STEP)
		anim.advance(STEP)
	for i: int in SETTLE_FRAMES:
		await process_frame
	_save_shot(_out.path_join("quast_%s_danach%s.jpg" % [_tag, _suffix]))
	clock.call(&"emit_refresh")
	quit()


func _save_shot(path: String) -> void:
	root.get_texture().get_image().save_jpg(path, 0.9)
	print("[ShotsQuast] ", path)
