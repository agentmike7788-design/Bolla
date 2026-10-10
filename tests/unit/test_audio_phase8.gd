extends TestCase
## W-Ton, Phase 8 (docs/PHASE8_DESIGN.md §8.3, §10): every new cue present (placeholder, WAV/QOA one-shots,
## Vorbis loops and music) and at its target loudness, the visitors well under the footsteps, the emitter
## ranges (Hanne's bells ≤ 12 m, the robber's spade ≤ 25 m), at most three new emitters, the voice pools and
## the web settings unchanged, nothing created while playing; the mapping as data (every cue and signal it
## names resolves); the Npc animations sound on their beats (not on first sight, not far away, only for the
## named Npc), enter/leave cues, the walk loop follows Hanne and stops, the robber's flight (gravel, wall),
## events at their source (candle, coins on the stone, alms, wage), Jakob whistles only in good spirits; the
## festivals: context fest / lights replaces the music (one music at a time), the inn's bed, short rests,
## the hand bell at the lights 17:40; chapter, night watchman, the new work keywords and the chalk board.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const QUALITY := preload("res://tests/unit/test_audio_quality.gd")
const LOUDNESS_TOLERANCE := 4.5
const WINDOW := 6.0

## Every Phase-8 cue: bus, loop.
const P8_CUES := {
	&"rake_leaves": [&"SFX", false], &"weed_pull": [&"SFX", false], &"water_pour": [&"SFX", false],
	&"barrel_fill": [&"SFX", false], &"match_strike": [&"SFX", false], &"candle_glass": [&"SFX", false],
	&"broom_sweep": [&"SFX", false], &"mortsafe_set": [&"SFX", false], &"cloth_kneel": [&"SFX", false],
	&"flowers_lay": [&"SFX", false], &"mourn_breath": [&"SFX", false], &"coins_stone": [&"SFX", false],
	&"chatter_murmur": [&"SFX", false], &"whistle_tune": [&"SFX", false], &"tin_cup": [&"SFX", false],
	&"wage_tin": [&"SFX", false], &"kiepe_bells": [&"SFX", true], &"kiepe_set": [&"SFX", false],
	&"spade_night": [&"SFX", false], &"run_gravel": [&"SFX", false], &"climb_wall": [&"SFX", false],
	&"knock_door": [&"SFX", false], &"watchman_call": [&"SFX", false], &"chapter_who": [&"SFX", false],
	&"chalk_write": [&"UI", false], &"amb_inn_fest": [&"Ambience", true], &"mus_dance": [&"Music", false],
	&"mus_lights": [&"Music", false],
}
## The G7 voice pools and web settings (§8.3: no new pools; browser build unchanged).
const POOLS := Vector3i(12, 10, 4)


class FakeWorld extends Node3D:
	func get_waypoint(id: StringName) -> Vector3:
		var m := get_node_or_null(NodePath("Waypoints/" + String(id))) as Node3D
		return m.global_position if m != null else Vector3.ZERO


class FakeFestivals extends Node:
	var id: StringName = &""

	func _init() -> void:
		add_to_group(&"festivals")

	func running() -> StringName:
		return id


class FakeApprentice extends Node:
	var value: int = 3

	func _init() -> void:
		add_to_group(&"apprentice")

	func morale() -> int:
		return value


class FakePlot extends Node3D:
	var grave_id: String = ""

	func _init() -> void:
		add_to_group(&"grave_plot")


var world: FakeWorld
var player: Player


func before_each() -> void:
	Audio.reset()
	Audio.enabled = true
	world = FakeWorld.new()
	world.name = "P8AudioWorld"
	var wps := Node3D.new()
	wps.name = "Waypoints"
	world.add_child(wps)
	tree.root.add_child(world)


func after_each() -> void:
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


func _waypoint(id: String, pos: Vector3) -> StringName:
	var wp := Marker3D.new()
	wp.name = id
	wp.position = pos
	world.get_node("Waypoints").add_child(wp)
	return StringName(id)


## An Npc `id` standing at `pos` with animation `anim` (the AnimationPlayer has 1-s looping clips `clips` + idle).
func _npc(id: String, pos: Vector3, anim: StringName, clips: Array[StringName] = []) -> Npc:
	var wp := _waypoint("wp_" + id, pos)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	var model := Node3D.new()
	model.name = "Model"
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	var names: Array[StringName] = clips.duplicate()
	names.append(&"idle")
	if not anim in names:
		names.append(anim)
	for a: StringName in names:
		var clip := Animation.new()
		clip.length = 1.0
		clip.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(a, clip)
	ap.add_animation_library(&"", lib)
	model.add_child(ap)
	npc.add_child(model)
	npc.schedule = _stay(wp, anim)
	world.add_child(npc)
	return npc


func _stay(wp: StringName, anim: StringName) -> NpcSchedule:
	var entries: Array[ScheduleEntry] = [ScheduleBuilder.stay(wp, 0, anim, &"test")]
	return ScheduleBuilder.build(entries)


func _set_anim(npc: Npc, anim: StringName) -> void:
	npc.set_runtime_schedule(_stay(StringName("wp_" + String(npc.npc_id)), anim))


func _ap(npc: Npc) -> AnimationPlayer:
	return npc.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func _count(id: StringName) -> int:
	var n := 0
	for c: StringName in Audio.played:
		if c == id:
			n += 1
	return n


# --- catalogue ---------------------------------------------------------------------------

func test_every_new_cue_present_as_placeholder() -> void:
	for id: StringName in P8_CUES:
		var c := Audio.cue(id)
		assert_not_null(c, "cue %s" % id)
		if c == null:
			continue
		assert_eq(c.bus, P8_CUES[id][0], "%s bus" % id)
		assert_eq(c.loop, P8_CUES[id][1], "%s loop" % id)
		assert_false(c.streams.is_empty(), "%s has files" % id)
		for s: AudioStream in c.streams:
			assert_true(s.resource_path.get_file().begins_with("ph_"), "placeholder %s" % s.resource_path)
			if c.loop or c.bus == &"Music":
				assert_true(s is AudioStreamOggVorbis, "%s: loop / music is Vorbis" % id)
			else:
				assert_true(s is AudioStreamWAV and (s as AudioStreamWAV).format == AudioStreamWAV.FORMAT_QOA,
						"%s: one-shot is WAV → QOA" % id)
	assert_eq(Audio.cue(&"whistle_tune").streams.size(), 3, "three tunes of his own")
	assert_true(Audio.cue(&"water_pour").streams.size() >= 2, "2–3 pouring variants")


func test_new_cues_play_at_their_target_loudness() -> void:
	var rate := AudioServer.get_mix_rate()
	for id: StringName in P8_CUES:
		var c := Audio.cue(id)
		if c == null:
			continue
		var long_form := c.loop or c.bus == &"Music"
		var energy := 0.0
		for s: AudioStream in c.streams:
			var from := 15.0 if c.bus == &"Music" else 0.0       # music: 20 s from inside the piece
			var secs := 20.0 if c.bus == &"Music" else minf(s.get_length(), WINDOW)
			var x := QUALITY._mono(QUALITY._decode(s, secs, from))
			energy += pow(10.0, QUALITY._loudness(x, rate, long_form) / 10.0)
		var game := 10.0 * log(energy / c.streams.size()) / log(10.0) + c.volume_db
		assert_true(absf(game - c.target_lufs) <= LOUDNESS_TOLERANCE, "%s plays at %.1f LUFS (target %.1f)" % [id, game, c.target_lufs])


func test_visitors_far_below_the_steps_and_the_night_spade_muffled() -> void:
	var steps := Audio.cue(&"step_grass").target_lufs
	for id: StringName in [&"cloth_kneel", &"flowers_lay", &"mourn_breath"]:
		assert_true(Audio.cue(id).target_lufs <= steps - 6.0 + 0.01, "%s ≥ 6 dB under the steps" % id)
	assert_true(Audio.cue(&"spade_night").target_lufs < Audio.cue(&"dig").target_lufs, "his spade quieter than ours")
	assert_true(Audio.cue(&"match_strike").target_lufs <= -33.0 and Audio.cue(&"candle_glass").target_lufs <= -33.0, "candle quiet")


func test_emitter_ranges_and_budget() -> void:
	var bells := Audio.cue(&"kiepe_bells")
	assert_true(bells.loop and bells.positional and bells.max_distance <= 12.0, "Hanne's bells ≤ 12 m (%.0f)" % bells.max_distance)
	assert_true(Audio.cue(&"spade_night").max_distance <= 25.0, "spade ≤ 25 m")
	for id: StringName in P8_CUES:
		var c := Audio.cue(id)
		if c.bus == &"SFX" and c.positional:
			assert_true(c.max_distance > 0.0 and c.max_distance <= 30.0, "%s reach %.0f m" % [id, c.max_distance])
	var cfg := Audio.config
	# New emitters: the walk loops (Hanne) – the G7 world emitters are unchanged (4).
	assert_eq(cfg.emitters.size(), 4, "no new fixed emitters")
	assert_true(cfg.npc_loop_voices <= 3, "at most 3 new emitters at once (%d)" % cfg.npc_loop_voices)
	assert_eq(Audio.world.find_children("NpcLoop*", "AudioStreamPlayer3D", false, false).size(), cfg.npc_loop_voices,
			"loop players made once in setup")


func test_voice_pools_and_web_settings_unchanged() -> void:
	var cfg := Audio.config
	assert_eq(Vector3i(cfg.pool_2d, cfg.pool_3d, cfg.pool_ui), POOLS, "no new voice pool size")
	assert_eq(Audio.voices.find_children("Voice3D_*", "", false, false).size(), POOLS.y)
	assert_eq(Audio.voices.find_children("Voice2D_*", "", false, false).size(), POOLS.x)
	assert_eq(Audio.voices.find_children("VoiceUI_*", "", false, false).size(), POOLS.z)
	assert_eq(str(ProjectSettings.get_setting("audio/driver/driver.web", "")), "ScriptProcessor")
	assert_eq(int(ProjectSettings.get_setting("audio/driver/output_latency.web", 0)), 150)
	assert_eq(int(ProjectSettings.get_setting("audio/general/default_playback_type.web", -1)), 0)


func test_mapping_is_data_and_resolves() -> void:
	var cfg := Audio.config
	var refs: Dictionary[StringName, String] = {}
	for anim: StringName in cfg.npc_anim_cues:
		var r: Dictionary = cfg.npc_anim_cues[anim]
		for k: String in ["cue", "enter", "leave"]:
			if r.has(k):
				refs[StringName(r[k])] = "animation %s" % anim
	for npc: StringName in cfg.npc_walk_loops:
		refs[cfg.npc_walk_loops[npc]] = "walk loop %s" % npc
		assert_true(Audio.cue(cfg.npc_walk_loops[npc]).loop, "walk loop of %s loops" % npc)
	for key: String in cfg.positional_cues:
		var r: Dictionary = cfg.positional_cues[key]
		assert_true(EventBus.has_signal(key.get_slice("@", 0)), "EventBus.%s" % key)
		assert_has([&"grave", &"npc", &"group"], StringName(r.get("at", &"")), "%s: source kind" % key)
		refs[StringName(r["cue"])] = "event " + key
	for k: String in ["step_cue", "climb_cue"]:
		refs[StringName(cfg.flight[k])] = "flight"
	refs[StringName(cfg.whistle["cue"])] = "whistle"
	for b: Dictionary in cfg.fest_bells:
		refs[StringName(b["cue"])] = "fest bell"
	for fest: StringName in cfg.fest_contexts:
		var r: Dictionary = cfg.fest_contexts[fest]
		assert_true(cfg.music_tracks.has(StringName(r["music"])), "%s: music context %s" % [fest, r["music"]])
		if r.has("profile"):
			assert_not_null(Audio.profile(StringName(r["profile"])), "%s: profile" % fest)
	assert_eq(Array(cfg.music_tracks[&"fest"]), ["mus_dance"])
	assert_eq(Array(cfg.music_tracks[&"lights"]), ["mus_lights"])
	assert_eq(Audio.profile(&"inn_fest").bed, &"amb_inn_fest", "the fest bed replaces the inn's")
	for id: StringName in refs:
		assert_true(Audio.has_cue(id), "cue '%s' (%s)" % [id, refs[id]])
	for anim: StringName in [&"rake", &"weed", &"water", &"candle", &"kneel", &"lay_flowers", &"dig_night", &"knock"]:
		assert_true(cfg.npc_anim_cues.has(anim), "animation %s sounds" % anim)


func test_beat_crossing() -> void:
	assert_true(AudioWorld.beat_crossed(0.4, 0.6, 0.55))
	assert_false(AudioWorld.beat_crossed(0.56, 0.6, 0.55), "already past")
	assert_true(AudioWorld.beat_crossed(0.9, 0.1, 0.05), "across the wrap")
	assert_true(AudioWorld.beat_crossed(0.9, 0.1, 0.95), "across the wrap, before")
	assert_false(AudioWorld.beat_crossed(0.9, 0.1, 0.5))
	assert_true(AudioWorld.beat_crossed(-1.0, 0.2, 0.0), "a fresh clip sounds its first beat")


# --- Npc animations ----------------------------------------------------------------------

func test_jakob_rakes_on_the_beat_far_away_silent() -> void:
	_player(Vector3.ZERO)
	var jakob := _npc("apprentice", Vector3(3, 0, 0), &"rake", [&"rake"])
	var far := _npc("smith", Vector3(60, 0, 0), &"rake", [&"rake"])
	await wait_frames(2)
	var ap := _ap(jakob)
	assert_eq(jakob.current_animation(), &"rake")
	assert_true(ap.is_playing(), "rake clip runs")
	Audio.played.clear()
	ap.seek(0.4, true)
	_ap(far).seek(0.4, true)
	await wait_frames(1)
	ap.seek(0.62, true)
	_ap(far).seek(0.62, true)
	await wait_frames(1)
	assert_eq(_count(&"rake_leaves"), 1, "one stroke on the beat (0.55)")
	ap.seek(0.3, true)               # wrapped: the next cycle
	await wait_frames(1)
	ap.seek(0.6, true)
	await wait_frames(1)
	assert_eq(_count(&"rake_leaves"), 2, "every cycle")
	assert_true(Audio.voices.playing_count(&"rake_leaves") >= 1, "positional voice")


func test_kneeling_sounds_on_change_not_on_first_sight() -> void:
	_player(Vector3.ZERO)
	var kin := _npc("kin_kehr", Vector3(2, 0, 1), &"kneel", [&"kneel", &"lay_flowers"])
	await wait_frames(3)
	assert_false(&"cloth_kneel" in Audio.played, "already kneeling when seen: no sound")
	_set_anim(kin, &"idle")
	await wait_frames(2)
	assert_has(Audio.played, &"cloth_kneel", "rising")
	Audio.played.clear()
	Audio.voices.stop_all()
	_set_anim(kin, &"lay_flowers")
	await wait_frames(2)
	assert_has(Audio.played, &"cloth_kneel", "bending down to lay the flowers")
	_ap(kin).seek(0.5, true)
	await wait_frames(1)
	_ap(kin).seek(0.7, true)
	await wait_frames(1)
	assert_has(Audio.played, &"flowers_lay", "the bouquet laid down at frame 30")


func test_npc_filter_and_settling() -> void:
	_player(Vector3.ZERO)
	var lambert := _npc("robber", Vector3(4, 0, 0), &"idle", [&"dig_night"])
	var other := _npc("innkeeper", Vector3(-4, 0, 0), &"idle", [&"dig_night"])
	await wait_frames(2)
	_set_anim(other, &"dig_night")
	await wait_frames(1)
	_ap(other).seek(0.1, true)
	await wait_frames(1)
	_ap(other).seek(0.3, true)
	await wait_frames(1)
	assert_false(&"spade_night" in Audio.played, "only the robber's spade")
	_set_anim(lambert, &"dig_night")
	await wait_frames(1)
	_ap(lambert).seek(0.1, true)
	await wait_frames(1)
	_ap(lambert).seek(0.3, true)
	await wait_frames(1)
	assert_has(Audio.played, &"spade_night", "he digs on the beat")
	Audio.played.clear()
	Audio.settle(5.0)
	_set_anim(lambert, &"sit_ground")
	await wait_frames(2)
	assert_false(&"cloth" in Audio.played, "silent while a load settles")


# --- walk loops, flight, whistle ------------------------------------------------------------

func test_walk_loop_follows_hanne_and_stops() -> void:
	_player(Vector3.ZERO)
	var hanne := _npc("peddler", Vector3(5, 0, 0), &"offer", [&"offer"])
	await wait_frames(2)
	assert_eq(Audio.world.npc_loops_playing(), 0, "standing: no bells")
	var walkers: Array[Npc] = [hanne]
	Audio.world._update_npc_loops(walkers)
	assert_eq(Audio.world.npc_loops_playing(), 1, "walking: bells")
	var loop := Audio.world.find_children("NpcLoop*", "AudioStreamPlayer3D", false, false)[0] as AudioStreamPlayer3D
	for p: Node in Audio.world.find_children("NpcLoop*", "AudioStreamPlayer3D", false, false):
		if (p as AudioStreamPlayer3D).playing:
			loop = p as AudioStreamPlayer3D
	assert_true(loop.global_position.distance_to(hanne.global_position) < 1.5, "the loop is at Hanne")
	assert_true(loop.max_distance <= 12.0)
	var none: Array[Npc] = []
	Audio.world._update_npc_loops(none)
	assert_eq(Audio.world.npc_loops_playing(), 0, "stops when she stands")


func test_flight_runs_over_gravel_and_the_wall() -> void:
	_player(Vector3.ZERO)
	var lambert := _npc("robber", Vector3(6, 0, 2), &"idle")
	_waypoint("robber_fence_in", Vector3(6.5, 0, 2))
	await wait_frames(2)
	EventBus.robber_event.emit(&"fled", "g_x")
	assert_true(Audio.world.flight_active(), "flight started")
	assert_eq(Audio.world.flight_step_cue(lambert), &"run_gravel", "his steps run")
	var other := _npc("smith", Vector3(-3, 0, 0), &"idle")
	await wait_frames(2)
	assert_eq(Audio.world.flight_step_cue(other), &"", "only his")
	assert_has(Audio.played, &"cloth", "the startle")
	assert_eq(_count(&"climb_wall"), 1, "over the wall once")
	await wait_frames(3)
	assert_eq(_count(&"climb_wall"), 1, "only once")


func test_whistles_only_in_good_spirits() -> void:
	_player(Vector3.ZERO)
	var system := FakeApprentice.new()
	world.add_child(system)
	var jakob := _npc("apprentice", Vector3(3, 0, 0), &"sweep", [&"sweep"])
	await wait_frames(2)
	system.value = 2
	for i in 60:
		Audio.world._maybe_whistle(jakob)
	assert_false(&"whistle_tune" in Audio.played, "low spirits: no whistling")
	system.value = 5
	for i in 60:
		Audio.world._maybe_whistle(jakob)
	assert_eq(_count(&"whistle_tune"), 1, "good spirits: whistles – at most every 30 s")
	assert_true(Audio.cue(&"whistle_tune").cooldown >= 30.0)


# --- events at their source ---------------------------------------------------------------

func test_candle_at_its_grave() -> void:
	_player(Vector3.ZERO)
	var plot := FakePlot.new()
	plot.grave_id = "g_p8"
	world.add_child(plot)
	plot.global_position = Vector3(4, 0, 4)
	await wait_frames(1)
	EventBus.grave_care_changed.emit("g_none", &"candle", true)
	assert_false(&"candle_glass" in Audio.played, "unknown grave: nothing (no fallback)")
	EventBus.grave_care_changed.emit("g_p8", &"candle", true)
	assert_has(Audio.played, &"candle_glass")
	assert_eq(Audio.voices.playing_count(&"candle_glass"), 1)
	EventBus.grave_care_changed.emit("g_p8", &"candle", false)
	assert_eq(_count(&"candle_glass"), 1, "burning out is silent")


func test_coins_on_the_stone_instead_of_the_purse() -> void:
	_player(Vector3.ZERO)
	EventBus.payment_received.emit(2, "Trinkgeld")
	assert_false(&"coins" in Audio.played, "the tip sounds on the stone, not as payment")
	EventBus.grave_care_changed.emit("g_far", &"tip", false)
	assert_has(Audio.played, &"coins_stone", "taken from the stone (2D when the plot is unknown)")
	EventBus.payment_received.emit(2, "Lohn")
	assert_has(Audio.played, &"coins", "other payments unchanged")


func test_alms_and_wage_in_their_tins() -> void:
	_player(Vector3.ZERO)
	var veit := _npc("beggar", Vector3(3, 0, -2), &"idle")
	await wait_frames(2)
	EventBus.coins_spent.emit(1, &"alms")
	assert_has(Audio.played, &"tin_cup")
	assert_false(&"coins" in Audio.played, "no purse sound")
	assert_eq(Audio.voices.playing_count(&"tin_cup"), 1)
	EventBus.coins_spent.emit(3, &"apprentice")
	assert_has(Audio.played, &"wage_tin")
	EventBus.coins_spent.emit(5, &"village")
	assert_has(Audio.played, &"coins", "other spending unchanged")
	assert_not_null(veit)


func test_chatter_murmurs_at_the_speaker() -> void:
	_player(Vector3.ZERO)
	EventBus.chatter_line.emit(&"ch_a", &"grocer", "…")
	assert_false(&"chatter_murmur" in Audio.played, "speaker not here: silent")
	_npc("grocer", Vector3(4, 0, 0), &"idle")
	await wait_frames(2)
	EventBus.chatter_line.emit(&"ch_a", &"grocer", "…")
	assert_has(Audio.played, &"chatter_murmur")
	EventBus.chatter_line.emit(&"apprentice", &"apprentice", "Fertig!")
	assert_has(Audio.played, &"remark", "Jakob's bubble: the remark cue")


func test_chapter_watchman_and_story_cues() -> void:
	EventBus.chapter_completed.emit(&"who_comes_up")
	assert_eq(Audio.played.back(), &"chapter_who", "own fanfare for „Wer heraufkommt“")
	Audio.voices.stop_all()
	EventBus.chapter_completed.emit(&"six_pits")
	assert_eq(Audio.played.back(), &"chapter", "older chapters unchanged")
	EventBus.robber_event.emit(&"caught", "g1")
	assert_has(Audio.played, &"watchman_call")
	EventBus.wish_changed.emit("w1", &"accepted")
	assert_eq(Audio.played.back(), &"quill")


func test_work_keywords_phase8() -> void:
	var ev := Audio.events
	assert_eq(ev.cue_for_action("Laub harken", &"interact"), &"rake_leaves")
	assert_eq(ev.cue_for_action("Unkraut jäten", &"interact"), &"weed_pull")
	assert_eq(ev.cue_for_action("Blumen gießen", &"water"), &"water_pour")
	assert_eq(ev.cue_for_action("Gießkanne füllen", &"interact"), &"barrel_fill")
	assert_eq(ev.cue_for_action("Grabblumen setzen", &"interact"), &"weed_pull")
	assert_eq(ev.cue_for_action("Wachskranz legen", &"interact"), &"flowers_lay")
	assert_eq(ev.cue_for_action("Grabkerze anzünden", &"interact"), &"match_strike")
	assert_eq(ev.cue_for_action("Grabgitter aufsetzen", &"hammer"), &"mortsafe_set")
	assert_eq(ev.cue_for_action("Grabgitter abnehmen", &"hammer"), &"mortsafe_set")
	assert_eq(ev.cue_for_action("Zeile nachmeißeln", &"interact"), &"chisel")
	assert_eq(ev.cue_for_action("Grab wieder schließen", &"dig"), &"dirt_pour")
	assert_eq(ev.cue_for_action("Gestalteten Stein setzen", &"interact"), &"stone_set", "G7 keywords unchanged")
	assert_eq(ev.cue_for_action("Altarkerze herstellen", &"interact"), &"saw")


func test_chalk_board_panel() -> void:
	var panel := UIPanel.new()
	panel.panel_id = &"apprentice_board"
	tree.root.add_child(panel)
	panel.visible = true
	assert_eq(Audio.played.back(), &"chalk_write")
	panel.queue_free()


# --- festivals ----------------------------------------------------------------------------

func test_fest_context_replaces_the_music_and_the_inn() -> void:
	var fest := FakeFestivals.new()
	world.add_child(fest)
	_player(Vector3.ZERO)
	TimeManager.set_time(TimeManager.day, 1200)
	player.set_in_interior(true, &"inn")
	assert_eq(Audio.ambience.profile_id, &"inn", "an ordinary evening")
	fest.id = &"fest_kathrein"
	Audio.refresh_context()
	assert_eq(Audio.wanted_music(), &"fest", "Kathreintanz: the fiddle replaces the music")
	assert_eq(Audio.music.context, &"fest", "one music at a time")
	assert_eq(Audio.ambience.profile_id, &"inn_fest", "the inn's bed replaced")
	assert_true(Audio.music.play_now())
	assert_eq(Audio.music.current_cue, &"mus_dance")
	Audio.music._on_finished()
	assert_true(Audio.music._wait >= 2.0 and Audio.music._wait <= 5.0, "a breath between the pieces (%.1f s)" % Audio.music._wait)
	player.set_in_interior(false)
	player.set_region(&"village")
	Audio.refresh_context()
	assert_ne(Audio.wanted_music(), &"fest", "outside the inn: the usual music")
	fest.id = &"fest_lights"
	player.set_region(&"graveyard")
	Audio.refresh_context()
	assert_eq(Audio.wanted_music(), &"lights", "Lichtgang: slow strings")
	assert_true(Audio.music.play_now())
	assert_eq(Audio.music.current_cue, &"mus_lights")
	player.set_in_interior(true, &"hut")
	Audio.refresh_context()
	assert_ne(Audio.wanted_music(), &"lights", "not inside the hut")
	fest.id = &""
	player.set_in_interior(false)
	Audio.refresh_context()
	assert_ne(Audio.wanted_music(), &"lights", "after the lights: the usual music")


func test_hand_bell_at_the_lights() -> void:
	var fest := FakeFestivals.new()
	world.add_child(fest)
	_player(Vector3.ZERO)
	TimeManager.set_time(TimeManager.day, 1058)
	await wait_frames(2)
	TimeManager.set_time(TimeManager.day, 1061)
	await wait_frames(2)
	assert_false(&"small_bell" in Audio.played, "no bell without the festival")
	fest.id = &"fest_lights"
	TimeManager.set_time(TimeManager.day + 1, 1058)
	await wait_frames(2)
	TimeManager.set_time(TimeManager.day, 1060)
	await wait_frames(2)
	assert_has(Audio.played, &"small_bell", "17:40: the hand bell")


func test_nothing_created_while_playing() -> void:
	_player(Vector3.ZERO)
	var hanne := _npc("peddler", Vector3(3, 0, 0), &"idle")
	await wait_frames(2)
	var before := Audio.find_children("*", "", true, false).size()
	for id: StringName in P8_CUES:
		if Audio.cue(id).bus != &"Music" and not Audio.cue(id).loop:
			Audio.play(id, Vector3(2, 0, 2))
	var walkers: Array[Npc] = [hanne]
	Audio.world._update_npc_loops(walkers)
	await wait_frames(2)
	assert_eq(Audio.find_children("*", "", true, false).size(), before, "no nodes created while playing")
