extends TestCase
## M2: TimeManager – config, real-time ticking, advance/set_time, pauses, save/load (§3.4).

const CONFIG_PATH := "res://data/config/time_config.tres"

var events: Array = []


func before_each() -> void:
	events.clear()
	EventBus.time_tick.connect(_on_tick)
	EventBus.hour_changed.connect(_on_hour)
	EventBus.day_started.connect(_on_day)
	EventBus.time_skipped.connect(_on_skipped)


func after_each() -> void:
	EventBus.time_tick.disconnect(_on_tick)
	EventBus.hour_changed.disconnect(_on_hour)
	EventBus.day_started.disconnect(_on_day)
	EventBus.time_skipped.disconnect(_on_skipped)
	tree.paused = false


# --- config & reset ---

func test_config_comes_from_data_with_contract_values() -> void:
	var cfg := TimeManager.config
	assert_not_null(cfg)
	assert_eq(cfg.resource_path, CONFIG_PATH, "loaded via Database")
	assert_almost(cfg.seconds_per_game_minute, 0.5)
	assert_eq(cfg.start_day, 1)
	assert_eq(cfg.start_minute, 390)
	assert_eq(cfg.night_start_minute, 1260)
	assert_eq(cfg.night_end_minute, 330)
	assert_eq(cfg.rest_until_minute, 1080)
	assert_eq(cfg.sleep_from_minute, 1080)
	assert_eq(cfg.wake_minute, 360)


func test_reset_restores_start_values() -> void:
	TimeManager.running = true
	TimeManager.push_pause(&"x")
	TimeManager.advance(500)
	_tick_real(0.3)
	TimeManager.config = _config(0.5)
	TimeManager.reset()
	assert_eq(TimeManager.day, 1)
	assert_eq(TimeManager.minute_of_day, 390)
	assert_false(TimeManager.running)
	assert_false(TimeManager.paused)
	assert_almost(TimeManager.get_minute_f(), 390.0, 0.0, "accumulator cleared")
	assert_eq(TimeManager.config.resource_path, CONFIG_PATH, "reset re-reads the data config")


func test_process_mode_inherits_tree_pause() -> void:
	assert_eq(TimeManager.process_mode, Node.PROCESS_MODE_INHERIT)


# --- real-time ticking ---

func test_not_running_does_not_tick() -> void:
	TimeManager.running = false
	TimeManager._process(10.0)
	assert_eq(TimeManager.minute_of_day, 390)
	assert_eq(events, [])


func test_ticks_every_game_minute() -> void:
	TimeManager.config = _config(0.5)
	TimeManager.running = true
	TimeManager._process(0.25)
	assert_eq(events, [], "half a minute: no tick yet")
	assert_almost(TimeManager.get_minute_f(), 390.5)
	TimeManager._process(0.25)
	assert_eq(events, [["tick", 1, 391]])
	events.clear()
	TimeManager._process(1.6)  # 3 more minutes + 0.1 s
	assert_eq(events, [["tick", 1, 392], ["tick", 1, 393], ["tick", 1, 394]], "one tick per minute")
	assert_almost(TimeManager.get_minute_f(), 394.2, 0.001)


func test_ticking_crosses_hour_and_midnight() -> void:
	TimeManager.config = _config(0.5)
	TimeManager.load_state({"day": 1, "minute_of_day": 1439})
	TimeManager.running = true
	TimeManager._process(0.5)
	assert_eq(events, [["day", 2], ["hour", 2, 0], ["tick", 2, 0]])
	events.clear()
	TimeManager.load_state({"day": 2, "minute_of_day": 419})
	TimeManager._process(0.5)
	assert_eq(events, [["hour", 2, 7], ["tick", 2, 420]], "no time_skipped for single minutes")


func test_pause_blocks_ticking_and_freezes_fraction() -> void:
	TimeManager.config = _config(0.5)
	TimeManager.running = true
	TimeManager._process(0.2)
	TimeManager.push_pause(&"modal")
	TimeManager._process(5.0)
	assert_eq(events, [])
	assert_almost(TimeManager.get_minute_f(), 390.4, 0.0001)
	TimeManager.pop_pause(&"modal")
	TimeManager._process(0.3)
	assert_eq(events, [["tick", 1, 391]])


func test_pause_from_tick_listener_stops_rest_of_frame() -> void:
	TimeManager.config = _config(0.5)
	TimeManager.running = true
	var pauser := func(_d: int, _m: int) -> void: TimeManager.push_pause(&"action")
	EventBus.time_tick.connect(pauser)
	TimeManager._process(2.0)
	EventBus.time_tick.disconnect(pauser)
	assert_eq(events, [["tick", 1, 391]], "clock stops right after the pausing tick")
	TimeManager.pop_pause(&"action")
	TimeManager._process(0.0)
	assert_eq(events.size(), 1, "the rest of the paused frame is not replayed")


func test_real_frames_tick() -> void:
	TimeManager.config = _config(0.02)
	TimeManager.running = true
	var start := Time.get_ticks_msec()
	while _ticks().size() < 3 and Time.get_ticks_msec() - start < 400:
		await tree.process_frame
	TimeManager.running = false
	var ticks := _ticks()
	assert_true(ticks.size() >= 3, "ticks in real frames: %d" % ticks.size())
	for i: int in ticks.size():
		assert_eq(ticks[i], ["tick", 1, 391 + i])


func test_paused_tree_stops_clock() -> void:
	TimeManager.config = _config(0.01)
	TimeManager.running = true
	tree.paused = true
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 120:
		await tree.process_frame
	assert_eq(events, [], "SceneTree pause stops the clock")
	tree.paused = false
	TimeManager.running = false


# --- pauses ---

func test_pause_reasons_are_a_set() -> void:
	assert_false(TimeManager.paused)
	TimeManager.push_pause(&"modal")
	TimeManager.push_pause(&"action")
	assert_true(TimeManager.paused)
	TimeManager.pop_pause(&"modal")
	assert_true(TimeManager.paused, "action still active")
	TimeManager.pop_pause(&"action")
	assert_false(TimeManager.paused)
	TimeManager.push_pause(&"modal")
	TimeManager.push_pause(&"modal")
	TimeManager.pop_pause(&"modal")
	assert_false(TimeManager.paused, "same reason twice needs one pop")
	TimeManager.pop_pause(&"unknown")
	assert_false(TimeManager.paused, "popping an unknown reason is a no-op")
	TimeManager.push_pause(&"a")
	TimeManager.push_pause(&"b")
	TimeManager.clear_pauses()
	assert_false(TimeManager.paused)


func test_ui_modal_pauses_clock() -> void:
	UIState.push_modal(&"inventory")
	assert_true(TimeManager.paused)
	UIState.pop_modal(&"inventory")
	assert_false(TimeManager.paused)


# --- advance ---

func test_advance_one_minute() -> void:
	TimeManager.advance(1)
	assert_eq(events, [["tick", 1, 391]])
	assert_eq(TimeManager.minute_of_day, 391)


func test_advance_across_hours() -> void:
	TimeManager.advance(100)  # 06:30 -> 08:10
	assert_eq(events, [["hour", 1, 7], ["hour", 1, 8], ["skip", 390, 490], ["tick", 1, 490]])
	assert_eq(TimeManager.format_clock(), "08:10")


func test_advance_from_full_hour_does_not_repeat_it() -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": 420})
	TimeManager.advance(60)
	assert_eq(events, [["hour", 1, 8], ["skip", 420, 480], ["tick", 1, 480]])
	events.clear()
	TimeManager.advance(59)
	assert_eq(events, [["skip", 480, 539], ["tick", 1, 539]], "no boundary before 09:00")


func test_advance_across_midnight() -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": 1410})
	TimeManager.advance(60)
	assert_eq(events, [["day", 2], ["hour", 2, 0], ["skip", 1410, 1470], ["tick", 2, 30]])
	assert_eq(TimeManager.day, 2)
	assert_eq(TimeManager.minute_of_day, 30)
	assert_eq(TimeManager.total_minutes(), 1470)


@warning_ignore("integer_division")
func test_advance_multiple_days_in_chronological_order() -> void:
	TimeManager.advance(3 * 1440)  # day 1 06:30 -> day 4 06:30
	var expected: Array = []
	for total: int in range(420, 3 * 1440 + 390 + 1, 60):
		var d := total / 1440 + 1
		if total % 1440 == 0:
			expected.append(["day", d])
		expected.append(["hour", d, (total % 1440) / 60])
	expected.append(["skip", 390, 3 * 1440 + 390])
	expected.append(["tick", 4, 390])
	assert_eq(events, expected)
	assert_eq(_count("day"), 3)
	assert_eq(_count("hour"), 72)
	assert_eq(_count("skip"), 1)
	assert_eq(_count("tick"), 1)
	assert_eq(TimeManager.day, 4)


func test_listeners_see_boundary_time_during_advance() -> void:
	var seen: Array = []
	var on_hour := func(d: int, h: int) -> void: seen.append([d, h, TimeManager.day, TimeManager.minute_of_day])
	var on_day := func(d: int) -> void: seen.append([d, TimeManager.day, TimeManager.minute_of_day])
	var on_tick := func(d: int, m: int) -> void: seen.append(["tick", d, m, TimeManager.day, TimeManager.minute_of_day])
	EventBus.hour_changed.connect(on_hour)
	EventBus.day_started.connect(on_day)
	EventBus.time_tick.connect(on_tick)
	TimeManager.load_state({"day": 1, "minute_of_day": 1380})
	TimeManager.advance(150)
	EventBus.hour_changed.disconnect(on_hour)
	EventBus.day_started.disconnect(on_day)
	EventBus.time_tick.disconnect(on_tick)
	assert_eq(seen, [[2, 2, 0], [2, 0, 2, 0], [2, 1, 2, 60], ["tick", 2, 90, 2, 90]])


func test_advance_zero_or_negative_does_nothing() -> void:
	TimeManager.advance(0)
	TimeManager.advance(-15)
	assert_eq(events, [])
	assert_eq(TimeManager.minute_of_day, 390)


func test_advance_works_while_paused() -> void:
	TimeManager.push_pause(&"action")
	TimeManager.advance(30)
	assert_eq(TimeManager.minute_of_day, 420)
	assert_eq(events, [["hour", 1, 7], ["skip", 390, 420], ["tick", 1, 420]])
	assert_true(TimeManager.paused, "advance does not lift pauses")


func test_advance_keeps_running_fraction() -> void:
	TimeManager.config = _config(0.5)
	TimeManager.running = true
	TimeManager._process(0.25)
	TimeManager.advance(10)
	assert_almost(TimeManager.get_minute_f(), 400.5)


# --- set_time ---

func test_set_time_forward_same_day() -> void:
	TimeManager.set_time(1, 600)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 600])
	assert_eq(events, [["hour", 1, 7], ["hour", 1, 8], ["hour", 1, 9], ["hour", 1, 10], ["skip", 390, 600], ["tick", 1, 600]])


func test_set_time_earlier_means_next_day() -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": 1200})  # 20:00
	TimeManager.set_time(1, 360)  # sleep until 06:00
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(events.back(), ["tick", 2, 360])
	assert_has(events, ["day", 2])
	assert_has(events, ["skip", 1200, 1440 + 360])


func test_set_time_after_midnight_stays_on_day() -> void:
	TimeManager.load_state({"day": 2, "minute_of_day": 120})  # 02:00
	TimeManager.set_time(2, 360)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(_count("day"), 0)


func test_set_time_several_days_ahead() -> void:
	TimeManager.set_time(3, 390)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [3, 390])
	assert_eq(_count("day"), 2)
	assert_eq(_count("tick"), 1)


func test_set_time_to_now_is_noop() -> void:
	TimeManager.set_time(1, 390)
	assert_eq(events, [])
	TimeManager.set_time(0, 390)  # earlier day, same clock time: already there
	assert_eq(events, [])


func test_set_time_wraps_invalid_minute() -> void:
	TimeManager.set_time(1, 1440 + 400)  # warns, treated as 06:40
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 400])


# --- queries ---

func test_minutes_until() -> void:
	assert_eq(TimeManager.minutes_until(460), 70)
	assert_eq(TimeManager.minutes_until(390), 0)
	assert_eq(TimeManager.minutes_until(360), 1410, "wraps to tomorrow")
	assert_eq(TimeManager.minutes_until(0), 1050)
	TimeManager.load_state({"day": 1, "minute_of_day": 1439})
	assert_eq(TimeManager.minutes_until(0), 1)


func test_total_minutes() -> void:
	assert_eq(TimeManager.total_minutes(), 390)
	TimeManager.load_state({"day": 3, "minute_of_day": 10})
	assert_eq(TimeManager.total_minutes(), 2 * 1440 + 10)


func test_is_night_wraps_over_midnight() -> void:
	var cases := {0: true, 329: true, 330: false, 720: false, 1259: false, 1260: true, 1439: true}
	for minute: int in cases:
		TimeManager.load_state({"day": 1, "minute_of_day": minute})
		assert_eq(TimeManager.is_night(), cases[minute], "minute %d" % minute)


func test_is_night_non_wrapping_interval() -> void:
	var cfg := _config(0.5)
	cfg.night_start_minute = 60
	cfg.night_end_minute = 120
	TimeManager.config = cfg
	for minute: int in [59, 60, 119, 120]:
		TimeManager.load_state({"day": 1, "minute_of_day": minute})
		assert_eq(TimeManager.is_night(), minute == 60 or minute == 119, "minute %d" % minute)
	cfg.night_end_minute = 60
	assert_false(TimeManager.is_night(), "empty interval")


func test_format_clock() -> void:
	var cases := {0: "00:00", 5: "00:05", 460: "07:40", 780: "13:00", 1439: "23:59"}
	for minute: int in cases:
		TimeManager.load_state({"day": 1, "minute_of_day": minute})
		assert_eq(TimeManager.format_clock(), cases[minute])


func test_emit_refresh_sends_one_tick() -> void:
	TimeManager.load_state({"day": 5, "minute_of_day": 777})
	TimeManager.emit_refresh()
	assert_eq(events, [["tick", 5, 777]])


# --- save / load ---

func test_save_and_load_state_silent() -> void:
	TimeManager.advance(2 * 1440 + 123)
	var data := TimeManager.save_state()
	assert_eq(data, {"day": 3, "minute_of_day": 513})
	TimeManager.reset()
	events.clear()
	TimeManager.config = _config(0.5)
	TimeManager.running = true
	TimeManager._process(0.3)
	TimeManager.running = false
	TimeManager.load_state(JSON.to_native(JSON.from_native(data)))
	assert_eq(events, [], "load_state emits nothing")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [3, 513])
	assert_almost(TimeManager.get_minute_f(), 513.0, 0.0, "accumulator cleared")


func test_load_state_sanitizes_values() -> void:
	TimeManager.load_state({"day": -4, "minute_of_day": 5000})
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 1439])
	TimeManager.load_state({})
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 390], "missing keys -> config start")


# --- helpers ---

func _config(seconds_per_minute: float) -> TimeConfig:
	var cfg := TimeManager.config.duplicate() as TimeConfig
	cfg.seconds_per_game_minute = seconds_per_minute
	return cfg


func _tick_real(seconds: float) -> void:
	TimeManager._process(seconds)


func _ticks() -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == "tick")


func _count(kind: String) -> int:
	return events.filter(func(e: Array) -> bool: return e[0] == kind).size()


func _on_tick(d: int, m: int) -> void:
	events.append(["tick", d, m])


func _on_hour(d: int, h: int) -> void:
	events.append(["hour", d, h])


func _on_day(d: int) -> void:
	events.append(["day", d])


func _on_skipped(from_total: int, to_total: int) -> void:
	events.append(["skip", from_total, to_total])
