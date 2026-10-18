extends TestCase
## W-Ton, Phase 9 (docs/PHASE9_DESIGN.md §8.3, §10): every new cue present (placeholder, WAV/QOA one-shots, the quill a
## Vorbis loop), small, at its target loudness and in its place in the mix (paper under the old work cues, the stranger's
## bell no louder than the gate bell, the motif under the chapter); Sieber's door knocks with the Phase-8 knock_door
## (unchanged); no new music, no new fixed emitters, voice pools and web settings unchanged, nothing created while
## playing; the mapping as data (labels of the desk, stove and grave, the letters' states, sealed letters, the large
## requests by prefix, the chain's motif, the chapter); the quill loop runs exactly as long as the writing; the
## stranger's bell at the gate bell, the sheet at the gate board, his case and hat, the watchman's lantern and bell at him.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const QUALITY := preload("res://tests/unit/test_audio_quality.gd")
const LOUDNESS_TOLERANCE := 4.5
const WINDOW := 6.0

## Every new Phase-9 cue: bus, loop, variants.
const P9_CUES := {
	&"letter_unfold": [&"SFX", false, 3], &"letter_seal_break": [&"SFX", false, 2], &"quill_scratch": [&"SFX", true, 1],
	&"paper_burn": [&"SFX", false, 2], &"book_page": [&"SFX", false, 3], &"soil_handful": [&"SFX", false, 3],
	&"case_latch": [&"SFX", false, 2], &"notice_sheet": [&"SFX", false, 2], &"gate_bell_short": [&"SFX", false, 1],
	&"lantern_creak": [&"SFX", false, 2], &"watchman_bell": [&"SFX", false, 1], &"motif_when": [&"SFX", false, 1],
	&"chapter_when": [&"SFX", false, 1],
}
## The contract's list (§8.3); knock_door is the Phase-8 cue.
const CONTRACT := [&"letter_unfold", &"letter_seal_break", &"quill_scratch", &"paper_burn", &"knock_door", &"case_latch",
	&"soil_handful", &"gate_bell_short", &"notice_sheet"]
const POOLS := Vector3i(12, 10, 4)
## Largest file of a new cue (bytes, before Godot's QOA import) and all of them together.
const MAX_FILE := 800 * 1024
const MAX_TOTAL := 4 * 1024 * 1024


class FakeWorld extends Node3D:
	func get_waypoint(id: StringName) -> Vector3:
		var m := get_node_or_null(NodePath("Waypoints/" + String(id))) as Node3D
		return m.global_position if m != null else Vector3.ZERO


var world: FakeWorld
var player: Player


func before_each() -> void:
	Audio.reset()
	Audio.enabled = true
	world = FakeWorld.new()
	world.name = "P9AudioWorld"
	var wps := Node3D.new()
	wps.name = "Waypoints"
	world.add_child(wps)
	tree.root.add_child(world)


func after_each() -> void:
	EventBus.timed_action_finished.emit(false)
	tree.paused = false
	if is_instance_valid(world):
		world.free()
	player = null
	Audio.reset()


func _player(pos: Vector3 = Vector3.ZERO) -> Player:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	player.global_position = pos
	player.set_region(&"graveyard")
	return player


func _npc(id: String, pos: Vector3) -> Npc:
	var wp := Marker3D.new()
	wp.name = "wp_" + id
	wp.position = pos
	world.get_node("Waypoints").add_child(wp)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	var entries: Array[ScheduleEntry] = [ScheduleBuilder.stay(StringName(wp.name), 0, &"idle", &"test")]
	npc.schedule = ScheduleBuilder.build(entries)
	world.add_child(npc)
	return npc


func _count(id: StringName) -> int:
	var n := 0
	for c: StringName in Audio.played:
		if c == id:
			n += 1
	return n


# --- catalogue ---------------------------------------------------------------------------------

func test_every_new_cue_present_as_placeholder() -> void:
	for id: StringName in P9_CUES:
		var c := Audio.cue(id)
		assert_not_null(c, "cue %s" % id)
		if c == null:
			continue
		assert_eq(c.bus, P9_CUES[id][0], "%s bus" % id)
		assert_eq(c.loop, P9_CUES[id][1], "%s loop" % id)
		assert_eq(c.streams.size(), P9_CUES[id][2], "%s variants" % id)
		for s: AudioStream in c.streams:
			assert_true(s.resource_path.get_file().begins_with("ph_"), "placeholder %s" % s.resource_path)
			if c.loop:
				assert_true(s is AudioStreamOggVorbis, "%s: loop is Vorbis" % id)
			else:
				assert_true(s is AudioStreamWAV and (s as AudioStreamWAV).format == AudioStreamWAV.FORMAT_QOA,
						"%s: one-shot is WAV → QOA" % id)
	for id: StringName in CONTRACT:
		assert_true(Audio.has_cue(id), "§8.3 cue %s" % id)
	assert_eq(Audio.cue(&"knock_door").streams.size(), 2, "Phase-8 knock_door unchanged (Sieber's door uses it)")


func test_new_files_are_small_and_short() -> void:
	var total := 0
	for id: StringName in P9_CUES:
		for s: AudioStream in Audio.cue(id).streams:
			var f := FileAccess.open(s.resource_path, FileAccess.READ)
			assert_not_null(f, "file %s" % s.resource_path)
			if f == null:
				continue
			var size := f.get_length()
			total += size
			assert_true(size <= MAX_FILE, "%s small (%d kB)" % [s.resource_path.get_file(), size / 1024])
			assert_true(s.get_length() <= 8.5, "%s short (%.1f s)" % [s.resource_path.get_file(), s.get_length()])
	assert_true(total <= MAX_TOTAL, "all new files %d kB" % (total / 1024))
	assert_true(Audio.cue(&"quill_scratch").streams[0].get_length() <= 5.0, "a short loop")


func test_new_cues_play_at_their_target_loudness() -> void:
	var rate := AudioServer.get_mix_rate()
	for id: StringName in P9_CUES:
		var c := Audio.cue(id)
		if c == null:
			continue
		var energy := 0.0
		for s: AudioStream in c.streams:
			var x := QUALITY._mono(QUALITY._decode(s, minf(s.get_length(), WINDOW) if not c.loop else WINDOW))
			energy += pow(10.0, QUALITY._loudness(x, rate, c.loop) / 10.0)
		var game := 10.0 * log(energy / c.streams.size()) / log(10.0) + c.volume_db
		assert_true(absf(game - c.target_lufs) <= LOUDNESS_TOLERANCE, "%s plays at %.1f LUFS (target %.1f)" % [id, game, c.target_lufs])


func test_place_in_the_mix() -> void:
	var work := Audio.cue(&"cloth").target_lufs
	for id: StringName in [&"letter_unfold", &"letter_seal_break", &"book_page", &"soil_handful", &"quill_scratch"]:
		assert_true(Audio.cue(id).target_lufs <= work - 2.9, "%s under the old work cues (%.0f)" % [id, Audio.cue(id).target_lufs])
	assert_true(Audio.cue(&"book_page").target_lufs <= -33.0, "turning pages is quiet")
	assert_true(Audio.cue(&"quill_scratch").target_lufs <= Audio.cue(&"quill").target_lufs - 3.0, "the long writing under the short quill")
	assert_true(Audio.cue(&"gate_bell_short").target_lufs <= Audio.cue(&"gate_bell").target_lufs, "his pull not louder than the bell")
	assert_true(Audio.cue(&"motif_when").target_lufs < Audio.cue(&"chapter_when").target_lufs, "the motif under the chapter")
	assert_true(Audio.cue(&"lantern_creak").target_lufs <= -36.0, "the lantern barely heard")
	assert_true(Audio.cue(&"watchman_bell").target_lufs <= Audio.cue(&"watchman_call").target_lufs + 3.0, "the hand bell no shout")
	assert_true(Audio.cue(&"motif_when").cooldown >= 10.0 and Audio.cue(&"watchman_bell").cooldown >= 10.0, "sparing")


func test_ranges_no_new_music_and_no_new_emitters() -> void:
	for id: StringName in P9_CUES:
		var c := Audio.cue(id)
		if c.positional:
			assert_true(c.max_distance > 0.0 and c.max_distance <= 70.0, "%s reach %.0f m" % [id, c.max_distance])
	assert_eq(Audio.cue(&"gate_bell_short").max_distance, Audio.cue(&"gate_bell").max_distance, "heard as far as the gate bell")
	assert_true(Audio.cue(&"lantern_creak").max_distance <= 16.0)
	var cfg := Audio.config
	assert_eq(cfg.emitters.size(), 4, "no new fixed loop emitters")
	assert_eq(cfg.npc_loop_voices, 2, "no new walk-loop players")
	for ctx: StringName in cfg.music_tracks:
		for t: String in cfg.music_tracks[ctx]:
			assert_false(Audio.cue(StringName(t)) != null and StringName(t) in P9_CUES, "no new music (%s)" % t)
	for id: StringName in P9_CUES:
		assert_ne(Audio.cue(id).bus, &"Music", "%s not on the music bus" % id)


func test_voice_pools_and_web_settings_unchanged() -> void:
	var cfg := Audio.config
	assert_eq(Vector3i(cfg.pool_2d, cfg.pool_3d, cfg.pool_ui), POOLS, "no new voice pool size")
	assert_eq(Audio.voices.find_children("Voice3D_*", "", false, false).size(), POOLS.y)
	assert_eq(Audio.voices.find_children("Voice2D_*", "", false, false).size(), POOLS.x)
	assert_eq(Audio.voices.find_children("VoiceUI_*", "", false, false).size(), POOLS.z)
	assert_eq(Audio.events.find_children("WorkLoop", "AudioStreamPlayer", false, false).size(), 1, "one work-loop player")
	assert_eq(str(ProjectSettings.get_setting("audio/driver/driver.web", "")), "ScriptProcessor")
	assert_eq(int(ProjectSettings.get_setting("audio/driver/output_latency.web", 0)), 150)
	assert_eq(int(ProjectSettings.get_setting("audio/general/default_playback_type.web", -1)), 0)


# --- the mapping ---------------------------------------------------------------------------------

func test_work_labels_of_desk_stove_and_grave() -> void:
	var ev := Audio.events
	assert_eq(ev.cue_for_action(Desk.LABEL_KLADDE, Desk.ANIM_READ_BOOK), &"book_page")
	assert_eq(ev.cue_for_action(Desk.LABEL_REGISTER_LIST, Desk.ANIM_READ_BOOK), &"book_page")
	assert_eq(ev.cue_for_action(Desk.LABEL_NAMELESS, Desk.ANIM_WRITE), &"quill_scratch")
	assert_eq(ev.cue_for_action(Desk.LABEL_ANSWER, Desk.ANIM_WRITE), &"quill_scratch")
	assert_eq(ev.cue_for_action(Stove.LABEL_BURN, Stove.ANIM_BURN), &"paper_burn")
	assert_eq(ev.cue_for_action(GravePlot.LABEL_DATE, GravePlot.ANIM_KNEEL_READ), &"book_page")
	assert_eq(ev.cue_for_action(GravePlot.LABEL_READ_LETTER, GravePlot.ANIM_READ_ALOUD), &"letter_unfold")
	assert_eq(ev.cue_for_action(GravePlot.LABEL_LAY_LETTER, GravePlot.ANIM_KNEEL), &"letter_unfold")
	assert_eq(ev.cue_for_action(GravePlot.LABEL_BURY_LETTER, GravePlot.ANIM_KNEEL), &"letter_unfold")
	assert_eq(ev.cue_for_action(GravePlot.LABEL_SOIL, GravePlot.ANIM_TAKE_SOIL), &"soil_handful")
	assert_eq(ev.cue_for_action("", &"write_letter"), &"quill_scratch", "the clip alone")
	assert_eq(ev.cue_for_action("", &"take_soil"), &"soil_handful")
	# older labels unchanged
	assert_eq(ev.cue_for_action(Desk.LABEL_COPY, Desk.ANIM_COPY), &"cloth")
	assert_eq(ev.cue_for_action("Grab ausheben", &"dig"), &"dig")
	assert_eq(ev.cue_for_action("Grabkerze anzünden", &"interact"), &"match_strike")


func test_wildcard_conditions() -> void:
	assert_true(AudioEvents.value_matches("hrl_crosses", "hrl_*"))
	assert_false(AudioEvents.value_matches("hr_lenz_stone", "hrl_*"))
	assert_true(AudioEvents.value_matches("hrl_", "hrl_*"))
	assert_true(AudioEvents.value_matches("offered", "offered"))
	assert_false(AudioEvents.value_matches("offered*", "offered"), "no wildcard without the star")
	var ev := Audio.events
	assert_eq(Array(ev.cues_for(&"hill_request_changed", [&"hrl_crosses", &"accepted"])), ["notice_sheet"])
	assert_eq(Array(ev.cues_for(&"hill_request_changed", [&"hrv_bridge_stones", &"accepted"])), ["notice_sheet"])
	assert_true(ev.cues_for(&"hill_request_changed", [&"hr_lenz_stone", &"accepted"]).is_empty(), "small requests unchanged")
	assert_eq(StringName(ev.positional_for(&"hill_request_changed", [&"hrl_widow_wood", &"offered"]).get("cue", &"")), &"notice_sheet")
	assert_true(ev.positional_for(&"hill_request_changed", [&"hr_lenz_stone", &"offered"]).is_empty())
	assert_true(ev.positional_for(&"hill_request_changed", [&"hrv_paul_day", &"offered"]).is_empty(), "the village board has no group: only on accepting")


func test_letters_door_case_chain_and_chapter() -> void:
	var ev := Audio.events
	assert_eq(Array(ev.cues_for(&"letter_changed", ["u1", &"lp_l1_wife", &"read"])), ["letter_unfold"])
	for sealed: StringName in [&"lp_l2_sister", &"lp_l3_burn", &"lpo_ott", &"lg_priest", &"oq_fenner_seal"]:
		assert_eq(Array(ev.cues_for(&"letter_changed", ["u2", sealed, &"read"])), ["letter_seal_break"], "%s sealed" % sealed)
	assert_true(ev.cues_for(&"letter_changed", ["u3", &"lp_l1_wife", &"delivered"]).is_empty(), "delivered: only the HUD note")
	assert_eq(Array(ev.cues_for(&"notification_requested", [WhoKnows.TEXT_LETTER_POSTED, &"info"])), ["letter_unfold"],
			"the letter slipped into the Siebers' door")
	assert_eq(Array(ev.cues_for(&"notification_requested", ["Etwas anderes.", &"info"])), ["ui_notify"])
	assert_eq(Array(ev.cues_for(&"dialogue_requested", [&"sieber_door", null])), ["knock_door"], "knocking at the Siebers'")
	assert_eq(Array(ev.cues_for(&"dialogue_requested", [&"osric", null])), ["ui_open"], "other dialogues unchanged")
	assert_eq(Array(ev.cues_for(&"stranger_event", [&"case", "opened"])), ["case_latch"])
	assert_eq(Array(ev.cues_for(&"quest_changed", [&"q_who_knows", &"h1", &"opened"])), ["motif_when"])
	assert_eq(Array(ev.cues_for(&"quest_changed", [&"q_who_knows", &"h6", &"ended"])), ["motif_when"])
	assert_true(ev.cues_for(&"quest_changed", [&"q_who_knows", &"h2", &"step"]).is_empty(), "sparing: not every step")
	assert_true(ev.cues_for(&"quest_changed", [&"q_letters", &"", &"opened"]).is_empty(), "only the main chain")
	assert_eq(Array(ev.cues_for(&"light_entry_changed", [&"e_sieber", &"marked"])), ["motif_when"])
	assert_eq(Array(ev.cues_for(&"chapter_completed", [&"who_knows_when"])), ["chapter_when"])
	assert_eq(Array(ev.cues_for(&"chapter_completed", [&"who_comes_up"])), ["chapter_who"], "older chapters unchanged")
	assert_eq(Audio.event_map.panel_open_cues.get(&"stranger", &""), &"case_latch", "his panel: the case opens")
	assert_eq(Audio.event_map.panel_open_cues.get(&"letter", &""), &"ui_page")


func test_letter_read_plays_once() -> void:
	EventBus.letter_changed.emit("u9", &"lp_l2_sister", &"read")
	assert_eq(_count(&"letter_seal_break"), 1)
	assert_false(&"letter_unfold" in Audio.played, "the seal, not both at once")
	EventBus.chapter_completed.emit(&"who_knows_when")
	assert_eq(Audio.played.back(), &"chapter_when")


# --- the quill loop ------------------------------------------------------------------------------

func test_quill_loop_runs_while_writing() -> void:
	EventBus.timed_action_started.emit(Desk.LABEL_NAMELESS, 10.0)
	assert_eq(Audio.events.work_cue(), &"quill_scratch")
	assert_eq(Audio.events.work_loop_cue(), &"quill_scratch", "the loop runs")
	var loop := Audio.events.get_node("WorkLoop") as AudioStreamPlayer
	assert_true(loop.playing and loop.bus == &"SFX")
	assert_eq(_count(&"quill_scratch"), 1)
	await wait_frames(4)
	assert_eq(_count(&"quill_scratch"), 1, "no repeat timer for a loop")
	assert_eq(Audio.voices.playing_count(&"quill_scratch"), 0, "not on a pool voice")
	tree.paused = true
	await wait_frames(2)
	assert_false(loop.playing, "the pen rests under the pause menu")
	assert_false(loop.stream_paused, "stopped, not stream-paused")
	tree.paused = false
	await wait_frames(2)
	assert_true(loop.playing, "writes on")
	EventBus.timed_action_finished.emit(true)
	assert_false(loop.playing, "stops with the action")
	assert_eq(Audio.events.work_loop_cue(), &"")


func test_quill_loop_waits_for_the_load_to_settle_and_resets() -> void:
	Audio.settle(5.0)
	EventBus.timed_action_started.emit(Desk.LABEL_ANSWER, 10.0)
	var loop := Audio.events.get_node("WorkLoop") as AudioStreamPlayer
	await wait_frames(2)
	assert_false(loop.playing, "silent while a load settles")
	Audio.reset()
	assert_false(loop.playing)
	assert_eq(Audio.events.work_loop_cue(), &"")


func test_burning_and_soil_are_one_shots() -> void:
	EventBus.timed_action_started.emit(Stove.LABEL_BURN, 1.0)
	assert_eq(Audio.played.back(), &"paper_burn")
	assert_eq(Audio.events.work_loop_cue(), &"", "no loop")
	EventBus.timed_action_finished.emit(true)
	EventBus.timed_action_started.emit(GravePlot.LABEL_SOIL, 1.0)
	assert_eq(Audio.played.back(), &"soil_handful")
	EventBus.timed_action_finished.emit(true)


# --- at their source ----------------------------------------------------------------------------

func test_stranger_rings_the_gate_bell_once_at_the_bell() -> void:
	_player(Vector3.ZERO)
	var args := [&"arrived", "gate"]
	var rule := Audio.events.positional_for(&"stranger_event", args)
	assert_eq(StringName(rule.get("cue", &"")), &"gate_bell_short")
	assert_false(Audio.world.play_event(rule, args), "no bell in the world: silent (the HUD line tells)")
	var bell := Node3D.new()
	bell.add_to_group(&"gate_bell")
	world.add_child(bell)
	bell.global_position = Vector3(8, 0, 3)
	assert_true(Audio.world.play_event(rule, args))
	assert_eq(Audio.voices.playing_count(&"gate_bell_short"), 1, "positional, at the bell")
	assert_true(Audio.events.positional_for(&"stranger_event", [&"arrived", "village"]).is_empty(), "the village: no bell")


func test_sheet_at_the_gate_board() -> void:
	_player(Vector3.ZERO)
	var board := Node3D.new()
	board.add_to_group(&"notice_board")
	world.add_child(board)
	board.global_position = Vector3(5, 0, -4)
	EventBus.hill_request_changed.emit(&"hrl_crosses", &"offered")
	assert_eq(Audio.voices.playing_count(&"notice_sheet"), 1, "pinned up at the board")


func test_stranger_case_and_hat_on_his_animations() -> void:
	var w := Audio.world
	assert_eq(StringName(w.anim_rule(&"stranger", &"wait_gate").get("enter", &"")), &"case_latch", "the case set down")
	assert_eq(StringName(w.anim_rule(&"stranger", &"wait_gate").get("leave", &"")), &"case_latch", "and taken up")
	assert_eq(StringName(w.anim_rule(&"stranger", &"tip_hat").get("enter", &"")), &"cloth")
	assert_eq(StringName(w.anim_rule(&"stranger", &"write_notebook").get("cue", &"")), &"quill")
	assert_true(w.anim_rule(&"smith", &"wait_gate").is_empty(), "only his")
	assert_eq(StringName(w.anim_rule(&"kin_sieber_v", &"show_mark").get("enter", &"")), &"cloth")


func test_watchman_lantern_and_bell_at_him() -> void:
	_player(Vector3.ZERO)
	var spots: Array[Dictionary] = []
	for e: Dictionary in Audio.config.spot_emitters:
		if StringName(e.get("npc", &"")) == &"watchman":
			spots.append(e)
	assert_eq(spots.size(), 2, "lantern and hand bell")
	var cues: Array = spots.map(func(e: Dictionary) -> StringName: return StringName(e["cue"]))
	assert_has(cues, &"lantern_creak")
	assert_has(cues, &"watchman_bell")
	for e: Dictionary in spots:
		assert_eq(StringName(e["region"]), &"village")
		assert_null(Audio.world.spot_position(e), "%s: no watchman, no sound" % e["cue"])
	var watchman := _npc("watchman", Vector3(6, 0, 2))
	await wait_frames(2)
	for e: Dictionary in spots:
		var at: Variant = Audio.world.spot_position(e)
		assert_true(at is Vector3, "%s at him" % e["cue"])
		if at is Vector3:
			assert_true((at as Vector3).distance_to(watchman.global_position) < 2.0)
	watchman.global_position = Vector3(80, 0, 0)
	assert_null(Audio.world.spot_position(spots[0]), "beyond the lantern's reach: silent")
	for e: Dictionary in Audio.config.spot_emitters:
		if not e.has("npc"):
			assert_true(Audio.world.spot_position(e) is Vector3, "fixed spots unchanged")


func test_nothing_created_while_playing() -> void:
	_player(Vector3.ZERO)
	await wait_frames(2)
	var before := Audio.find_children("*", "", true, false).size()
	for id: StringName in P9_CUES:
		if not Audio.cue(id).loop:
			Audio.play(id, Vector3(2, 0, 2) if Audio.cue(id).positional else null)
	EventBus.timed_action_started.emit(Desk.LABEL_NAMELESS, 10.0)
	await wait_frames(2)
	EventBus.timed_action_finished.emit(true)
	assert_eq(Audio.find_children("*", "", true, false).size(), before, "no nodes created while playing")
