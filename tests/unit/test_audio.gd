extends TestCase
## Audio (G7 Änderungsrunde 1): buses, the cue catalogue against the files on disk, every data
## reference (events, actions, profiles, steps, music, emitters) resolvable, the manager answering
## EventBus signals, region / room / hour switching the soundscape and music, footstep surfaces,
## the user volume setting saved and loaded (user settings file, not the save game), voice
## budget, UI hooks – all on the headless dummy driver without engine errors.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const INTERIOR_DIR := "res://data/config/interiors"
const REGION_DIR := "res://data/config/regions"
const PHASES: PackedStringArray = ["dawn", "day", "dusk", "night"]
const DAY_MINUTE := 600
const NIGHT_MINUTE := 1350

var _dir: String = ""
var _default_path: String = ""


func before_each() -> void:
	_default_path = Audio.config.settings_path
	Audio.reset()
	Audio.enabled = true


func after_each() -> void:
	Audio.reset()
	Audio.config.settings_path = _default_path
	Audio.load_settings()
	if _dir != "":
		TestCase.remove_user_dir(_dir)


# --- structure ---------------------------------------------------------------------------

func test_buses_present() -> void:
	for bus: StringName in AudioConfig.BUSES:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "bus %s" % bus)
	for bus: StringName in [&"Music", &"Ambience", &"SFX", &"UI"]:
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), &"Master", "%s → Master" % bus)
	var sfx := AudioServer.get_bus_index(&"SFX")
	assert_true(AudioServer.get_bus_effect_count(sfx) > 0 and AudioServer.get_bus_effect(sfx, 0) is AudioEffectReverb,
			"room reverb on SFX")


func test_every_cue_has_existing_files() -> void:
	assert_true(Audio.cue_ids().size() >= 80, "catalogue loaded (%d cues)" % Audio.cue_ids().size())
	for id: StringName in Audio.cue_ids():
		var c := Audio.cue(id)
		assert_false(c.streams.is_empty(), "cue %s has streams" % id)
		assert_has([&"Music", &"Ambience", &"SFX", &"UI"], c.bus, "cue %s bus" % id)
		for s: AudioStream in c.streams:
			assert_not_null(s, "stream of %s" % id)
			if s == null:
				continue
			var path := s.resource_path
			assert_true(path.get_file().begins_with("ph_") and path.ends_with(".ogg"), "placeholder ogg %s" % path)
			assert_true(FileAccess.file_exists(path), "file %s of %s" % [path, id])


func test_every_data_reference_resolves() -> void:
	var refs: Dictionary[StringName, String] = {}
	var map := Audio.event_map
	for key: String in map.signal_cues:
		for c: String in map.signal_cues[key].split(",", false):
			refs[StringName(c.strip_edges())] = "signal " + key
	for word: String in map.action_keywords:
		refs[map.action_keywords[word]] = "action " + word
	for anim: StringName in map.action_animation_cues:
		refs[map.action_animation_cues[anim]] = "animation %s" % anim
	for d: Dictionary in [map.panel_open_cues, map.panel_close_cues]:
		for p: StringName in d:
			if d[p] != &"":
				refs[d[p]] = "panel %s" % p
	for c: StringName in [map.panel_open, map.panel_close, map.button_press, map.button_hover, map.page_cue,
			map.pickup_cue, map.putdown_cue, map.corpse_pickup_cue, map.corpse_putdown_cue]:
		refs[c] = "event map"
	var cfg := Audio.config
	for s: StringName in cfg.step_cues:
		refs[cfg.step_cues[s]] = "step %s" % s
	for ctx: StringName in cfg.music_tracks:
		for t: String in cfg.music_tracks[ctx]:
			refs[StringName(t)] = "music %s" % ctx
	for e: Dictionary in cfg.emitters + cfg.spot_emitters:
		refs[StringName(e["cue"])] = "emitter"
	refs[cfg.cart_cue] = "cart"
	refs[cfg.bell_cue] = "bell"
	for pid: StringName in Audio.profile_ids():
		var p := Audio.profile(pid)
		refs[p.bed] = "bed of %s" % pid
		for spot: Dictionary in p.spots:
			refs[StringName(spot["cue"])] = "spot of %s" % pid
	for id: StringName in refs:
		assert_true(Audio.has_cue(id), "cue '%s' (%s) exists" % [id, refs[id]])


func test_event_map_signals_exist_on_event_bus() -> void:
	for key: String in Audio.event_map.signal_cues:
		var sig := key.get_slice("@", 0)
		assert_true(EventBus.has_signal(sig), "EventBus.%s" % sig)
	assert_true(Audio.events.connected_signals().size() >= 40, "signals wired")


func test_every_place_has_a_soundscape() -> void:
	var cfg := Audio.config
	for f: String in ResourceLoader.list_directory(REGION_DIR):
		var rc := load(REGION_DIR.path_join(f)) as RegionConfig
		if rc == null:
			continue
		for phase: String in PHASES:
			var key := "%s/%s" % [rc.region_id, phase]
			assert_true(cfg.outdoor_profiles.has(key), "outdoor profile %s" % key)
			assert_not_null(Audio.profile(cfg.outdoor_profiles.get(key, &"")), "profile for %s" % key)
	var rooms: Array[StringName] = [&"hut"]
	for f: String in ResourceLoader.list_directory(INTERIOR_DIR):
		if f.ends_with(".tres"):
			rooms.append(StringName(f.get_basename()))
	for room: StringName in rooms:
		assert_not_null(Audio.profile(cfg.room_profiles.get(room, &"")), "room profile %s" % room)
		assert_true(cfg.room_surfaces.has(room), "room floor %s" % room)
	for zone: Dictionary in cfg.zone_profiles:
		assert_not_null(Audio.profile(StringName(zone["profile"])), "zone profile %s" % zone["profile"])
	assert_not_null(Audio.profile(cfg.title_profile), "title profile")


func test_loops_and_one_shots_flagged() -> void:
	for id: StringName in [&"amb_graveyard_day", &"amb_crypt", &"loop_brook", &"cart_roll"]:
		assert_true(Audio.cue(id).loop, "%s loops" % id)
		var s := Audio.stream_for(Audio.cue(id)) as AudioStreamOggVorbis
		assert_true(s != null and s.loop, "%s stream loops" % id)
	for id: StringName in [&"dig", &"mus_day", &"ui_click", &"owl"]:
		assert_false(Audio.cue(id).loop, "%s plays once" % id)


# --- events ------------------------------------------------------------------------------

func test_manager_answers_event_bus_signals() -> void:
	EventBus.payment_received.emit(3, "test")
	assert_has(Audio.played, &"coins")
	EventBus.ghost_spoke.emit("g1", &"content", "…")
	assert_has(Audio.played, &"ghost_content")
	EventBus.ghost_spoke.emit("g2", &"restless", "…")
	assert_has(Audio.played, &"ghost_restless")
	EventBus.ghost_spoke.emit("g3", &"calm", "…")
	assert_has(Audio.played, &"ghost_appear", "plain key is the fallback")
	EventBus.workshop_job_changed.emit(&"forge", &"iron_bar", &"started")
	assert_eq(Audio.played.back(), &"bellows", "two conditions win over one")
	EventBus.workshop_job_changed.emit(&"workbench", &"cross", &"started")
	assert_eq(Audio.played.back(), &"hammer")
	EventBus.notification_requested.emit("x", &"warning")
	assert_eq(Audio.played.back(), &"ui_error")
	EventBus.chapter_completed.emit(&"six_pits")
	assert_eq(Audio.played.back(), &"chapter")
	EventBus.corpse_buried.emit("c1", "g1")
	assert_eq(Audio.played.back(), &"dirt_pour")


func test_settling_after_load_is_silent() -> void:
	Audio.settle(5.0)
	EventBus.payment_received.emit(3, "test")
	assert_false(&"coins" in Audio.played, "no event sounds while a load replays its state")


func test_timed_action_repeats_work_cue() -> void:
	EventBus.timed_action_started.emit("Grab ausheben", 2.0)
	assert_eq(Audio.events.work_cue(), &"dig")
	assert_eq(Audio.played.back(), &"dig")
	EventBus.timed_action_finished.emit(true)
	assert_eq(Audio.events.work_cue(), &"")


func test_action_keywords() -> void:
	var ev := Audio.events
	assert_eq(ev.cue_for_action("Erle fällen", &"dig"), &"chop")
	assert_eq(ev.cue_for_action("Altarkerze herstellen", &"interact"), &"saw", "Kerze is no ore")
	assert_eq(ev.cue_for_action("Erz abbauen", &"dig"), &"pick_stone")
	assert_eq(ev.cue_for_action("Du ziehst das Tuch über sie und arbeitest, ohne hinzusehen.", &"interact"), &"anatomy_tool")
	assert_eq(ev.cue_for_action("Inschrift", &"interact"), &"chisel")
	assert_eq(ev.cue_for_action("Gestalteten Stein setzen", &"interact"), &"stone_set")
	assert_eq(ev.cue_for_action("???", &"dig"), &"dig", "animation fallback")


func test_morgue_table_hook_plays() -> void:
	Audio.play_hook(&"anatomy_tool")
	assert_eq(Audio.played.back(), &"anatomy_tool")


func test_buttons_and_panels_are_hooked() -> void:
	var button := Button.new()
	tree.root.add_child(button)
	button.pressed.emit()
	assert_eq(Audio.played.back(), &"ui_click")
	var panel := UIPanel.new()
	panel.panel_id = &"chest"
	tree.root.add_child(panel)
	panel.visible = true
	assert_eq(Audio.played.back(), &"chest_open")
	panel.visible = false
	assert_eq(Audio.played.back(), &"chest_close")
	button.queue_free()
	panel.queue_free()


func test_cooldown_and_voice_budget() -> void:
	assert_true(Audio.play(&"ui_hover"))
	assert_false(Audio.play(&"ui_hover"), "hover cooldown")
	for i in 20:
		Audio.play(&"step_grass")
	assert_true(Audio.voices.playing_count(&"step_grass") <= Audio.cue(&"step_grass").max_voices, "per-cue voices")
	assert_true(Audio.voices.total_playing() <= Audio.config.pool_2d + Audio.config.pool_3d + Audio.config.pool_ui)
	assert_false(Audio.play(&"no_such_cue"), "unknown cue")
	Audio.enabled = false
	assert_false(Audio.play(&"dig"), "disabled")


# --- context -----------------------------------------------------------------------------

func test_region_room_and_hour_switch_the_soundscape() -> void:
	var player := await add_scene(PLAYER_SCENE) as Player
	TimeManager.set_time(TimeManager.day, DAY_MINUTE)
	player.global_position = Vector3(0, 0, 0)
	player.set_region(&"graveyard")
	assert_eq(Audio.ambience.profile_id, &"graveyard_day")
	assert_eq(Audio.wanted_music(), &"day")
	player.global_position = Vector3(0, 0, 400)
	player.set_region(&"village")
	assert_eq(Audio.ambience.profile_id, &"village_day", "region change switches the bed")
	assert_eq(Audio.wanted_music(), &"village")
	player.set_in_interior(true, &"inn")
	assert_eq(Audio.ambience.profile_id, &"inn", "room bed")
	player.set_in_interior(true, &"crypt")
	assert_eq(Audio.ambience.profile_id, &"crypt")
	var sfx := AudioServer.get_bus_index(&"SFX")
	assert_true(AudioServer.is_bus_effect_enabled(sfx, 0), "crypt reverb on")
	player.set_in_interior(false)
	assert_false(AudioServer.is_bus_effect_enabled(sfx, 0), "reverb off outside")
	TimeManager.set_time(TimeManager.day, NIGHT_MINUTE)
	player.global_position = Vector3(0, 0, 0)
	player.set_region(&"graveyard")
	assert_eq(Audio.ambience.profile_id, &"graveyard_night")
	assert_eq(Audio.wanted_music(), &"night")
	TimeManager.set_time(TimeManager.day + 1, DAY_MINUTE)
	player.global_position = Vector3(-7.0, 0, -16.0)
	Audio.refresh_context()
	assert_eq(Audio.ambience.profile_id, &"forest_edge", "Holunderwinkel is the forest edge")
	assert_true(Audio.ambience.bed_playing(), "bed plays")
	player.queue_free()
	await wait_frames(1)
	Audio.refresh_context()
	assert_eq(Audio.ambience.profile_id, &"", "no player, no title: silence")


func test_music_plays_and_rests() -> void:
	var player := await add_scene(PLAYER_SCENE) as Player
	TimeManager.set_time(TimeManager.day, DAY_MINUTE)
	player.set_region(&"graveyard")
	assert_eq(Audio.music.context, &"day")
	assert_eq(Audio.music.state, AudioMusic.State.WAIT, "a rest before the first piece")
	assert_true(Audio.music.play_now())
	assert_eq(Audio.music.current_cue, &"mus_day")
	TimeManager.set_time(TimeManager.day, NIGHT_MINUTE)
	Audio.refresh_context()
	assert_eq(Audio.music.state, AudioMusic.State.FADE, "context change fades out")
	player.queue_free()


func test_footstep_surfaces() -> void:
	var cfg := Audio.config
	assert_eq(AudioSurfaces.surface_at(cfg, &"graveyard", Vector2(10, -5)), &"grass")
	assert_eq(AudioSurfaces.surface_at(cfg, &"graveyard", Vector2(0, 4)), &"stone", "gravel path")
	assert_eq(AudioSurfaces.surface_at(cfg, &"graveyard", Vector2(3.3, 19)), &"earth", "cart road")
	assert_eq(AudioSurfaces.surface_at(cfg, &"graveyard", Vector2(26, 0)), &"stone", "Am Bruch")
	assert_eq(AudioSurfaces.surface_at(cfg, &"village", Vector2(-26, 1.5)), &"wood", "bridge")
	assert_eq(AudioSurfaces.surface_at(cfg, &"village", Vector2(0, -3)), &"stone", "well square")
	assert_eq(AudioSurfaces.surface_at(cfg, &"village", Vector2(6, 8)), &"earth", "lane")
	assert_eq(AudioSurfaces.room_surface(cfg, &"crypt"), &"stone")
	assert_eq(AudioSurfaces.room_surface(cfg, &"inn"), &"wood")
	var world := Audio.world
	assert_eq(world.step_cue(&"wood"), &"step_wood")
	assert_eq(world.step_cue(&"unknown"), &"step_grass", "fallback")


func test_bell_rings_on_the_hour() -> void:
	var player := await add_scene(PLAYER_SCENE) as Player
	Audio.world.ring_bell(12)
	await wait_frames(2)
	assert_has(Audio.played, &"church_bell")
	Audio.played.clear()
	Audio.world.reset()
	Audio.world.ring_bell(13)
	await wait_frames(2)
	assert_false(&"church_bell" in Audio.played, "only at bell hours")
	player.queue_free()


# --- settings ----------------------------------------------------------------------------

func test_volume_setting_saved_and_loaded() -> void:
	_dir = TestCase.user_dir("test_audio")
	var path := _dir.path_join("settings.cfg")
	Audio.load_settings(path)
	assert_almost(Audio.get_volume(&"Music"), Audio.config.default_volumes[&"Music"], 0.001, "defaults without file")
	Audio.set_volume(&"Music", 0.3)
	Audio.set_volume(&"SFX", 0.0)
	assert_true(FileAccess.file_exists(path), "written to the settings file")
	var bus := AudioServer.get_bus_index(&"Music")
	assert_almost(AudioServer.get_bus_volume_db(bus), linear_to_db(0.3), 0.01)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "0 mutes")
	Audio.volumes[&"Music"] = 1.0
	Audio.load_settings(path)
	assert_almost(Audio.get_volume(&"Music"), 0.3, 0.001, "loaded back")
	assert_almost(Audio.get_volume(&"SFX"), 0.0, 0.001)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_true(cfg.has_section(AudioSettings.SECTION), "own [audio] section")
	assert_false(path.contains("save"), "not in the save slot")


func test_pause_menu_volume_sliders() -> void:
	_dir = TestCase.user_dir("test_audio_menu")
	var path := _dir.path_join("settings.cfg")
	Audio.load_settings(path)
	var menu := PauseMenu.new()
	tree.root.add_child(menu)
	menu.open({})
	menu.sound_button.pressed.emit()
	assert_true(menu.volume_box.is_visible_in_tree(), "sliders shown")
	assert_eq(menu.volume_box.sliders.size(), AudioConfig.BUSES.size(), "one slider per bus")
	assert_almost(menu.volume_box.sliders[&"Music"].value, roundf(Audio.get_volume(&"Music") * 100.0), 0.01)
	menu.volume_box.sliders[&"Music"].value = 40.0
	assert_almost(Audio.get_volume(&"Music"), 0.4, 0.001)
	assert_true(FileAccess.file_exists(path), "saved at once")
	menu.close()
	menu.queue_free()
