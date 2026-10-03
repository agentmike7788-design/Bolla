extends TestCase
## P1 (docs/PHASE7_DESIGN.md §2.2, §3.4, §10): ScheduleResolver.entry_at(…, day) – today_flag entries
## count only while the GameState flag equals `day` and win a tie of start_minute; day -1 (every call
## before Phase 7) skips them, so Osric's and Ilse's schedules stay bit-identical; ScheduleEntry.region
## is data for the Npc (the resolver does not filter it). Fixtures: tests/fixtures/phase7/schedules.

const FLAG := &"linden_consecration_day"


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _entry(start: int, flag: StringName = &"", region: StringName = &"village", travel: int = 0) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.start_minute = start
	e.travel_minutes = travel
	e.today_flag = flag
	e.region = region
	return e


func _schedule(entries: Array[ScheduleEntry]) -> NpcSchedule:
	var s := NpcSchedule.new()
	s.npc_id = &"test"
	s.entries = entries
	return s


func test_today_flag_entries_skipped_without_day() -> void:
	var plain := _entry(480)
	var special := _entry(520, FLAG, &"")
	var s := _schedule([plain, special])
	GameState.set_flag(FLAG, 42)
	assert_eq(ScheduleResolver.entry_at(s, 600), plain, "day -1 skips today_flag entries")
	assert_eq(ScheduleResolver.entry_at(s, 600, -1), plain)


func test_today_flag_counts_only_on_its_day() -> void:
	var plain := _entry(480)
	var special := _entry(520, FLAG, &"")
	var s := _schedule([plain, special])
	assert_eq(ScheduleResolver.entry_at(s, 600, 42), plain, "flag missing")
	GameState.set_flag(FLAG, 42)
	assert_eq(ScheduleResolver.entry_at(s, 600, 42), special, "flag == day")
	assert_eq(ScheduleResolver.entry_at(s, 600, 41), plain, "the day before")
	assert_eq(ScheduleResolver.entry_at(s, 600, 43), plain, "the day after")
	assert_eq(ScheduleResolver.entry_at(s, 500, 42), plain, "before the special entry starts")
	GameState.set_flag(FLAG, true)
	assert_eq(ScheduleResolver.entry_at(s, 600, 1), plain, "a bool flag is no day")
	GameState.set_flag(FLAG, 42.0)
	assert_eq(ScheduleResolver.entry_at(s, 600, 42), special, "a float day (JSON) counts")


func test_valid_today_entry_wins_a_tie() -> void:
	var special := _entry(480, FLAG, &"")
	var plain := _entry(480)
	var s := _schedule([special, plain])
	GameState.set_flag(FLAG, 7)
	assert_eq(ScheduleResolver.entry_at(s, 500, 7), special, "same start: the today entry wins, even earlier in the array")
	assert_eq(ScheduleResolver.entry_at(s, 500, 8), plain, "not today: the plain entry")
	# Two plain entries keep the old rule (the later array entry wins).
	var a := _entry(600)
	var b := _entry(600)
	assert_eq(ScheduleResolver.entry_at(_schedule([a, b]), 700, 7), b)


func test_today_entry_over_midnight_and_latest() -> void:
	var plain := _entry(300)
	var special := _entry(1300, FLAG, &"")
	var s := _schedule([plain, special])
	GameState.set_flag(FLAG, 5)
	assert_eq(ScheduleResolver.entry_at(s, 100, 5), special, "before the first start: the latest valid entry of the day")
	assert_eq(ScheduleResolver.entry_at(s, 100, 6), plain, "latest skips the invalid special entry")


func test_only_today_entries_without_their_day() -> void:
	var s := _schedule([_entry(100, FLAG, &"")])
	assert_null(ScheduleResolver.entry_at(s, 200, 3), "nothing valid → null (no warning)")


func test_old_schedules_bit_identical() -> void:
	for id: StringName in [&"carter", &"trader"]:
		var sched := Database.schedule(id) as NpcSchedule
		assert_not_null(sched, String(id))
		for minute: int in range(0, 1440, 7):
			var old := ScheduleResolver.entry_at(sched, minute)
			assert_eq(ScheduleResolver.entry_at(sched, minute, 40), old, "%s @%d day 40" % [id, minute])
			assert_eq(ScheduleResolver.entry_at(sched, minute, -1), old, "%s @%d day -1" % [id, minute])


func test_priest_fixture_consecration_day() -> void:
	var priest := Phase7Fixtures.schedule(&"priest")
	assert_not_null(priest)
	GameState.set_flag(FLAG, 42)
	var normal := ScheduleResolver.entry_at(priest, 9 * 60 + 30, 41)
	assert_eq([normal.region, normal.today_flag], [&"village", &""], "09:30 on another day: the church door")
	var up := ScheduleResolver.entry_at(priest, 9 * 60 + 30, 42)
	assert_eq([up.region, up.today_flag, up.path], [&"", FLAG, PackedStringArray(["linden_spot"])], "09:30 on the day: at the Lindenacker")
	assert_eq(ScheduleResolver.entry_at(priest, 8 * 60 + 50, 42).path[0], "road_end", "08:40–09:20 up the coach road")
	var back := ScheduleResolver.entry_at(priest, 11 * 60 + 40, 42)
	assert_eq([back.region, back.today_flag], [&"village", &""], "from 11:30 as usual")
	# The region is data for the Npc only: the resolver returns entries of every region.
	assert_eq(ScheduleResolver.entry_at(priest, 600, -1).region, &"village")


func test_carter_fixture_village_entries_fit_his_home_times() -> void:
	var data := Database.schedule(&"carter") as NpcSchedule
	var fixture := Phase7Fixtures.schedule(&"carter")
	var graveyard: Array[ScheduleEntry] = []
	for e: ScheduleEntry in fixture.entries:
		if e.region == &"":
			graveyard.append(e)
	# W-Welt (W1 note): carter_schedule.tres holds the 7 village entries as well – its graveyard
	# routine (no region) is the reference.
	var data_graveyard := NpcSchedule.new()
	for e: ScheduleEntry in data.entries:
		if e.region == &"":
			data_graveyard.entries.append(e)
	assert_eq(graveyard.size(), data_graveyard.entries.size(), "the graveyard entries stay")
	assert_eq(fixture.entries.size(), data.entries.size(), "the data = the fixture")
	for minute: int in range(0, 1440, 5):
		var e := ScheduleResolver.entry_at(fixture, minute, 40)
		var old := ScheduleResolver.entry_at(data_graveyard, minute, 40)
		if e.region == &"village":
			assert_false(old.visible, "@%d: a village entry only while he is 'home' on the graveyard" % minute)
		else:
			assert_eq([e.start_minute, e.path, e.visible], [old.start_minute, old.path, old.visible], "@%d graveyard unchanged" % minute)
