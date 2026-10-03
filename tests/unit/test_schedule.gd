extends TestCase
## M4: ScheduleResolver (entry_at, progress, arrival_minute) and the carter's routine data (§1, §2.5, §3.4).

const CARTER_PATH := "res://data/npc/carter_schedule.tres"
const CORPSE_TABLES_FIXTURE := "res://tests/fixtures/corpse_tables_fixture.tres"
const CORPSE_TABLES_DATA := "res://data/corpses/corpse_tables.tres"
const WAYPOINTS: PackedStringArray = ["road_end", "road_mid", "gate_outside", "dropoff", "evening_spot"]
## Carter model animations (§8, ph_chr_carter).
const CARTER_ANIMATIONS: Array[StringName] = [&"idle", &"walk", &"push_cart", &"talk"]


func _entry(start: int, travel: int = 0, activity: StringName = &"idle") -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.start_minute = start
	e.travel_minutes = travel
	e.activity = activity
	return e


func _schedule(entries: Array[ScheduleEntry]) -> NpcSchedule:
	var s := NpcSchedule.new()
	s.npc_id = &"test_npc"
	s.entries = entries
	return s


func _carter() -> NpcSchedule:
	return load(CARTER_PATH) as NpcSchedule


## Phase 7 (W-Welt, W1 note): carter_schedule.tres also holds Osric's 7 village entries (region
## village, §2.2); the graveyard routine checked here is the entries without a region.
func _graveyard_entries() -> Array[ScheduleEntry]:
	var out: Array[ScheduleEntry] = []
	for e: ScheduleEntry in _carter().entries:
		if e.region == &"":
			out.append(e)
	return out


func _carter_entry(start: int) -> ScheduleEntry:
	for e: ScheduleEntry in _graveyard_entries():
		if e.start_minute == start:
			return e
	return null


# --- entry_at ---

func test_entry_at_picks_last_started_entry() -> void:
	var a := _entry(0, 0, &"a")
	var b := _entry(420, 0, &"b")
	var c := _entry(1080, 0, &"c")
	var s := _schedule([a, b, c])
	assert_eq(ScheduleResolver.entry_at(s, 0), a, "exactly at start")
	assert_eq(ScheduleResolver.entry_at(s, 419), a)
	assert_eq(ScheduleResolver.entry_at(s, 420), b, "start minute is inclusive")
	assert_eq(ScheduleResolver.entry_at(s, 1079), b)
	assert_eq(ScheduleResolver.entry_at(s, 1080), c)
	assert_eq(ScheduleResolver.entry_at(s, 1439), c)


func test_entry_at_does_not_need_sorted_entries() -> void:
	var a := _entry(600, 0, &"a")
	var b := _entry(60, 0, &"b")
	var c := _entry(1200, 0, &"c")
	var s := _schedule([a, b, c])
	assert_eq(ScheduleResolver.entry_at(s, 100), b)
	assert_eq(ScheduleResolver.entry_at(s, 700), a)
	assert_eq(ScheduleResolver.entry_at(s, 1300), c)
	assert_eq(s.entries[0], a, "resource order is left untouched")


func test_entry_at_wraps_to_last_entry_before_midnight() -> void:
	var a := _entry(360, 0, &"morning")
	var b := _entry(1290, 0, &"night")
	var c := _entry(720, 0, &"noon")
	var s := _schedule([a, b, c])
	assert_eq(ScheduleResolver.entry_at(s, 0), b, "00:00 still belongs to the 21:30 entry")
	assert_eq(ScheduleResolver.entry_at(s, 359), b)
	assert_eq(ScheduleResolver.entry_at(s, 360), a)


func test_entry_at_normalizes_minute() -> void:
	var a := _entry(0, 0, &"a")
	var b := _entry(600, 0, &"b")
	var s := _schedule([a, b])
	assert_eq(ScheduleResolver.entry_at(s, 1440), a, "1440 = 00:00 next day")
	assert_eq(ScheduleResolver.entry_at(s, 1440 + 700), b)
	assert_eq(ScheduleResolver.entry_at(s, -1), b, "-1 = 23:59")


func test_entry_at_single_entry_always_active() -> void:
	var only := _entry(500)
	var s := _schedule([only])
	for t: int in [0, 499, 500, 1439]:
		assert_eq(ScheduleResolver.entry_at(s, t), only, "t=%d" % t)


func test_entry_at_equal_starts_later_entry_wins() -> void:
	var first := _entry(300, 0, &"first")
	var second := _entry(300, 0, &"second")
	var s := _schedule([first, second])
	assert_eq(ScheduleResolver.entry_at(s, 300), second)
	assert_eq(ScheduleResolver.entry_at(s, 100), second, "also when wrapping")


func test_entry_at_skips_null_entries() -> void:
	var a := _entry(100, 0, &"a")
	var s := NpcSchedule.new()
	s.entries.append(null)
	s.entries.append(a)
	assert_eq(ScheduleResolver.entry_at(s, 200), a)
	assert_eq(ScheduleResolver.entry_at(s, 50), a)


func test_entry_at_without_entries_returns_null() -> void:
	assert_null(ScheduleResolver.entry_at(null, 400))
	assert_null(ScheduleResolver.entry_at(NpcSchedule.new(), 400))


# --- progress ---

func test_progress_linear_and_clamped() -> void:
	var e := _entry(420, 40)
	assert_almost(ScheduleResolver.progress(e, 420.0), 0.0)
	assert_almost(ScheduleResolver.progress(e, 430.0), 0.25)
	assert_almost(ScheduleResolver.progress(e, 440.5), 20.5 / 40.0)
	assert_almost(ScheduleResolver.progress(e, 460.0), 1.0)
	assert_almost(ScheduleResolver.progress(e, 599.9), 1.0, 0.0001, "stays arrived")


func test_progress_zero_or_negative_travel_is_arrived() -> void:
	assert_almost(ScheduleResolver.progress(_entry(460, 0), 460.0), 1.0)
	assert_almost(ScheduleResolver.progress(_entry(460, 0), 300.0), 1.0)
	assert_almost(ScheduleResolver.progress(_entry(460, -5), 461.0), 1.0)


func test_progress_wraps_over_midnight() -> void:
	var late := _entry(1430, 20)
	assert_almost(ScheduleResolver.progress(late, 1435.0), 0.25)
	assert_almost(ScheduleResolver.progress(late, 5.0), 0.75, 0.0001, "15 minutes after start, past midnight")
	assert_almost(ScheduleResolver.progress(late, 1440.0), 0.5, 0.0001, "1440 = midnight")
	assert_almost(ScheduleResolver.progress(late, 20.0), 1.0)


func test_progress_before_start_wraps_to_arrived() -> void:
	# Queried before its start the entry is the one from yesterday → long arrived.
	var e := _entry(1260, 30)
	assert_almost(ScheduleResolver.progress(e, 10.0), 1.0)
	assert_almost(ScheduleResolver.progress(e, 1259.5), 1.0)


func test_progress_without_entry() -> void:
	assert_almost(ScheduleResolver.progress(null, 100.0), 0.0)


# --- arrival_minute ---

func test_arrival_minute() -> void:
	assert_eq(ScheduleResolver.arrival_minute(_entry(420, 40)), 460)
	assert_eq(ScheduleResolver.arrival_minute(_entry(460, 0)), 460, "no travel = start")
	assert_eq(ScheduleResolver.arrival_minute(_entry(1430, 20)), 10, "wraps over midnight")
	assert_eq(ScheduleResolver.arrival_minute(_entry(1420, 20)), 0)
	assert_eq(ScheduleResolver.arrival_minute(_entry(300, -10)), 300, "negative travel counts as 0")


func test_arrival_minute_without_entry() -> void:
	assert_eq(ScheduleResolver.arrival_minute(null), -1)


# --- carter data ---

func test_carter_schedule_loads_with_identity() -> void:
	var s := _carter()
	assert_not_null(s, CARTER_PATH)
	assert_eq(s.npc_id, &"carter")
	assert_eq(s.display_name, "Osric Faulhaber")
	assert_eq(_graveyard_entries().size(), 9, "the graveyard routine")
	assert_eq(s.entries.size(), 16, "+ 7 village entries (Phase 7)")
	assert_eq(Database.schedule(&"carter"), s, "registered in Database by npc_id")


func test_carter_morning_arrival_matches_delivery_minute() -> void:
	var walk_in := ScheduleResolver.entry_at(_carter(), 420)
	assert_eq(walk_in.start_minute, 420, "07:00 entry")
	var arrival := ScheduleResolver.arrival_minute(walk_in)
	assert_eq(arrival, 460)
	assert_eq(arrival, CorpseTables.new().delivery_minute, "CorpseTables default")
	assert_eq(arrival, (load(CORPSE_TABLES_FIXTURE) as CorpseTables).delivery_minute, "fixture")
	if ResourceLoader.exists(CORPSE_TABLES_DATA):
		assert_eq(arrival, (load(CORPSE_TABLES_DATA) as CorpseTables).delivery_minute, "game data")
	assert_eq(ScheduleResolver.entry_at(_carter(), arrival).dialogue_id, &"carter", "talkable on arrival")


func test_carter_entries_sorted_unique_and_in_range() -> void:
	var last := -1
	for e: ScheduleEntry in _graveyard_entries():
		assert_true(e.start_minute > last, "ascending, unique start %d" % e.start_minute)
		assert_true(e.start_minute >= 0 and e.start_minute < 1440)
		assert_true(e.travel_minutes >= 0)
		last = e.start_minute
	assert_eq(_graveyard_entries()[0].start_minute, 0, "day starts with an entry at 00:00")


func test_carter_paths_use_known_waypoints() -> void:
	for e: ScheduleEntry in _graveyard_entries():
		assert_false(e.path.is_empty(), "entry %d has a path" % e.start_minute)
		for wp: String in e.path:
			assert_has(WAYPOINTS, wp, "entry %d" % e.start_minute)
		assert_has(CARTER_ANIMATIONS, e.animation, "entry %d" % e.start_minute)


func test_carter_paths_are_continuous() -> void:
	# Each phase starts where the previous one ended (wrapping over midnight).
	var entries := _graveyard_entries()
	for i: int in entries.size():
		var prev := entries[i - 1] if i > 0 else entries[entries.size() - 1]
		var cur := entries[i]
		assert_eq(cur.path[0], prev.path[prev.path.size() - 1], "entry %d starts at the end of %d" % [cur.start_minute, prev.start_minute])
		if cur.travel_minutes == 0:
			assert_eq(cur.path.size(), 1, "stationary entry %d has one waypoint" % cur.start_minute)
		else:
			assert_true(cur.path.size() >= 2, "walk %d has a route" % cur.start_minute)


func test_carter_phases_over_the_day() -> void:
	var s := _carter()
	var expect := {
		0: [&"home", false, false, &""],
		419: [&"home", false, false, &""],
		420: [&"walk", true, true, &""],
		459: [&"walk", true, true, &""],
		460: [&"idle", true, true, &"carter"],
		599: [&"idle", true, true, &"carter"],
		600: [&"walk", true, true, &""],
		640: [&"home", false, false, &""],
		1079: [&"home", false, false, &""],
		1080: [&"walk", true, false, &""],
		1110: [&"smoke", true, false, &"carter"],
		1259: [&"smoke", true, false, &"carter"],
		1260: [&"walk", true, false, &""],
		1290: [&"home", false, false, &""],
		1439: [&"home", false, false, &""],
	}
	for t: int in expect:
		var e := ScheduleResolver.entry_at(s, t)
		var want: Array = expect[t]
		assert_eq(e.activity, want[0], "activity at %d" % t)
		assert_eq(e.visible, want[1], "visible at %d" % t)
		assert_eq(e.with_cart, want[2], "cart at %d" % t)
		assert_eq(e.dialogue_id, want[3], "dialogue at %d" % t)


func test_carter_specific_entries() -> void:
	var walk_in := _carter_entry(420)
	assert_eq(walk_in.path, PackedStringArray(["road_end", "road_mid", "gate_outside", "dropoff"]))
	assert_eq(walk_in.travel_minutes, 40)
	assert_eq(walk_in.animation, &"push_cart")
	var at_dropoff := _carter_entry(460)
	assert_eq(at_dropoff.path, PackedStringArray(["dropoff"]))
	assert_eq(at_dropoff.animation, &"idle")
	var walk_out := _carter_entry(600)
	assert_eq(walk_out.path, PackedStringArray(["dropoff", "gate_outside", "road_mid", "road_end"]))
	assert_eq(walk_out.travel_minutes, 40)
	assert_eq(walk_out.animation, &"push_cart")
	assert_eq(ScheduleResolver.arrival_minute(walk_out), 640)
	var evening_in := _carter_entry(1080)
	assert_eq(evening_in.path, PackedStringArray(["road_end", "road_mid", "evening_spot"]))
	assert_eq(evening_in.travel_minutes, 30)
	assert_eq(ScheduleResolver.arrival_minute(evening_in), 1110)
	var smoke := _carter_entry(1110)
	assert_eq(smoke.path, PackedStringArray(["evening_spot"]))
	assert_eq(smoke.animation, &"talk")
	var evening_out := _carter_entry(1260)
	assert_eq(evening_out.path, PackedStringArray(["evening_spot", "road_mid", "road_end"]))
	assert_eq(evening_out.travel_minutes, 30)
	assert_eq(ScheduleResolver.arrival_minute(evening_out), 1290)


func test_carter_arrivals_match_next_phase() -> void:
	# Every walk ends exactly when the next phase begins.
	var entries := _graveyard_entries()
	for i: int in entries.size():
		var e := entries[i]
		if e.travel_minutes == 0:
			continue
		var next := entries[(i + 1) % entries.size()]
		assert_eq(ScheduleResolver.arrival_minute(e), next.start_minute, "walk %d" % e.start_minute)


func test_carter_hidden_phases_have_no_dialogue_or_cart() -> void:
	for e: ScheduleEntry in _graveyard_entries():
		if not e.visible:
			assert_eq(e.activity, &"home")
			assert_eq(e.dialogue_id, &"")
			assert_false(e.with_cart)
			assert_eq(e.path, PackedStringArray(["road_end"]))
		if e.dialogue_id != &"":
			assert_eq(e.travel_minutes, 0, "only talkable while standing (%d)" % e.start_minute)
			assert_not_null(Database.dialogue(e.dialogue_id), "dialogue %s exists" % e.dialogue_id)


func test_carter_progress_along_morning_walk() -> void:
	var s := _carter()
	var e := ScheduleResolver.entry_at(s, 440)
	assert_almost(ScheduleResolver.progress(e, 440.0), 0.5)
	assert_almost(ScheduleResolver.progress(ScheduleResolver.entry_at(s, 500), 500.0), 1.0, 0.0001, "standing")
