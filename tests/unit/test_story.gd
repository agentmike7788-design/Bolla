extends TestCase
## Phase 4 (docs/PHASE4_DESIGN.md §2.11, §10): StoryDirector – due_story (order, earliest_day,
## gap, catching up), pending_count, make_record (forced traits from the data), daily_checks
## (key fallback from day 12, idempotent). Uses Phase4Fixtures (S1–S5, story config).

var stories: Array[StoryCorpseData] = []
var cfg: StoryConfig


func before_each() -> void:
	stories = Phase4Fixtures.stories()
	cfg = Phase4Fixtures.story_config()


func test_nothing_due_before_the_first_earliest_day() -> void:
	for day: int in range(1, 6):
		assert_null(StoryDirector.due_story(day, PackedStringArray(), 0, stories, cfg), "day %d" % day)
	assert_eq(StoryDirector.due_story(6, PackedStringArray(), 0, stories, cfg).id, &"s1_quendel")


func test_the_contract_days_of_a_new_game() -> void:
	# §1.3: S1 day 6, S2 day 9, S3 day 13, S4 day 16, S5 day 19 – one per delivery day at most.
	var delivered := PackedStringArray()
	var last := 0
	var arrivals := {}
	for day: int in range(1, 25):
		var story := StoryDirector.due_story(day, delivered, last, stories, cfg)
		if story != null:
			arrivals[story.id] = day
			delivered.append(String(story.id))
			last = day
	assert_eq(arrivals, {&"s1_quendel": 6, &"s2_hemmerling": 9, &"s3_wernstein": 13, &"s4_uhlig": 16, &"s5_moor": 19})


func test_strict_order_and_the_gap() -> void:
	# S1 delivered on day 8 (late): S2 (earliest 9) is due from day 10 = 8 + gap 2.
	var delivered := PackedStringArray(["s1_quendel"])
	assert_null(StoryDirector.due_story(9, delivered, 8, stories, cfg), "gap of 2 days")
	assert_eq(StoryDirector.due_story(10, delivered, 8, stories, cfg).id, &"s2_hemmerling")
	# A later story never overtakes an undelivered earlier one.
	assert_eq(StoryDirector.due_story(30, PackedStringArray(), 0, stories, cfg).id, &"s1_quendel")
	var all := PackedStringArray(["s1_quendel", "s2_hemmerling", "s3_wernstein", "s4_uhlig", "s5_moor"])
	assert_null(StoryDirector.due_story(40, all, 20, stories, cfg), "all delivered")


func test_migrated_saves_catch_up_every_second_day() -> void:
	# §2.11 rule 3: a Phase-3 save on day 14 – S1 at the first delivery day, then every 2 days.
	var delivered := PackedStringArray()
	var last := 0
	var days: Array = []
	for day: int in range(15, 26):
		var story := StoryDirector.due_story(day, delivered, last, stories, cfg)
		if story != null:
			days.append([story.id, day])
			delivered.append(String(story.id))
			last = day
	assert_eq(days, [[&"s1_quendel", 15], [&"s2_hemmerling", 17], [&"s3_wernstein", 19], [&"s4_uhlig", 21], [&"s5_moor", 23]])


func test_gap_follows_the_config() -> void:
	var wide := cfg.duplicate() as StoryConfig
	wide.min_gap_days = 4
	var delivered := PackedStringArray(["s1_quendel"])
	assert_null(StoryDirector.due_story(9, delivered, 6, stories, wide))
	assert_eq(StoryDirector.due_story(10, delivered, 6, stories, wide).id, &"s2_hemmerling")
	assert_eq(StoryDirector.due_story(6, PackedStringArray(), 0, stories, null).id, &"s1_quendel", "null config = defaults")


func test_unsorted_input_is_sorted_by_order() -> void:
	var reversed: Array[StoryCorpseData] = stories.duplicate()
	reversed.reverse()
	assert_eq(StoryDirector.due_story(20, PackedStringArray(), 0, reversed, cfg).id, &"s1_quendel")
	assert_eq(StoryDirector.sorted(reversed)[4].id, &"s5_moor")


func test_pending_count() -> void:
	assert_eq(StoryDirector.pending_count(PackedStringArray(), stories), 5)
	assert_eq(StoryDirector.pending_count(PackedStringArray(["s1_quendel", "s2_hemmerling"]), stories), 3)
	assert_eq(StoryDirector.pending_count(PackedStringArray(["s1_quendel", "unknown"]), stories), 4, "unknown ids do not count")
	var none: Array[StoryCorpseData] = []
	assert_eq(StoryDirector.pending_count(PackedStringArray(), none), 0)


func test_make_record_takes_everything_from_the_data() -> void:
	var s3 := Phase4Fixtures.story(&"s3_wernstein")
	var r := StoryDirector.make_record(s3, 4242)
	assert_eq([r.story_id, r.display_name, r.age, r.cause_id, r.seed], [&"s3_wernstein", "Ida Wernstein", 27, &"poisoned", 4242])
	assert_eq(r.traits, [&"strange_wound", &"letter"] as Array[StringName], "forced traits, no roll")
	assert_eq([r.valuables_coins, r.has_trait(&"valuables")], [0, false], "story corpses carry no valuables")
	assert_almost(r.freshness, 1.0)
	assert_eq(r.id, "", "the manager assigns the id")
	var s5 := StoryDirector.make_record(Phase4Fixtures.story(&"s5_moor"), 1)
	assert_eq([s5.cause_id, s5.traits], [&"moor_cold", [&"strange_wound"] as Array[StringName]])


func test_make_record_is_independent_of_the_seed() -> void:
	var s2 := Phase4Fixtures.story(&"s2_hemmerling")
	var a := StoryDirector.make_record(s2, 1)
	var b := StoryDirector.make_record(s2, 99999)
	for key: String in ["display_name", "age", "cause_id", "traits", "valuables_coins", "story_id"]:
		assert_eq(a.get(key), b.get(key), key)
	a.traits.append(&"tattoo")
	assert_eq(s2.traits.size(), 1, "the record gets a copy of the traits")


func test_make_record_with_coins_adds_the_valuables_trait() -> void:
	var custom := Phase4Fixtures.story(&"s1_quendel").duplicate() as StoryCorpseData
	custom.valuables_coins = 4
	var r := StoryDirector.make_record(custom, 1)
	assert_true(r.has_trait(&"valuables"))
	assert_eq(r.valuables_coins, 4)


func test_daily_checks_key_fallback_from_day_12() -> void:
	for day: int in range(1, 12):
		assert_eq(StoryDirector.daily_checks(day, false, cfg), [] as Array[StringName], "day %d" % day)
	assert_eq(StoryDirector.daily_checks(12, false, cfg), [&"elder_key"] as Array[StringName])
	assert_eq(StoryDirector.daily_checks(20, false, cfg), [&"elder_key"] as Array[StringName], "late (migrated saves)")
	assert_eq(StoryDirector.daily_checks(12, true, cfg), [] as Array[StringName], "idempotent once the key is there")
	assert_eq(StoryDirector.daily_checks(12, false, null), [&"elder_key"] as Array[StringName], "null config = defaults")


func test_real_story_data_matches_the_contract() -> void:
	var real: Array = Database.story_corpses()
	assert_eq(real.size(), 7, "S1–S5 + D1 (Phase 7) + D2 (Phase 8)")
	var ids: Array = []
	var days: Array = []
	for s: StoryCorpseData in real:
		ids.append(s.id)
		days.append(s.earliest_day)
		assert_eq(s.valuables_coins, 0, "%s: no valuables" % s.id)
		assert_ne(s.arrival_note, "", "%s: Osric's line" % s.id)
		var cause: Dictionary = (Database.corpse_tables() as CorpseTables).get_cause(s.cause_id)
		assert_false(cause.is_empty(), "%s: cause %s in the corpse tables" % [s.id, s.cause_id])
	assert_eq(ids, [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor", &"d1_hagedorn", &"d2_ott"])
	assert_eq(days, [6, 9, 13, 16, 19, 1, 1], "D1 waits for village_open_day + 8, D2 for ott_dead instead")
	var cfg_real := Database.config(&"story_config") as StoryConfig
	assert_eq((Database.story_corpse(cfg_real.finale_story) as StoryCorpseData).is_finale, true)


func test_moor_cold_is_never_rolled() -> void:
	var real := Database.corpse_tables() as CorpseTables
	var moor := real.get_cause(&"moor_cold")
	assert_eq([float(moor.weight), float(moor.decay_mult)], [0.0, 0.5])
	for i: int in 300:
		assert_ne(CorpseGenerator.generate(CorpseGenerator.seed_for(i + 1, 0), real, 30).cause_id, &"moor_cold")


# --- Phase 7 (P6, docs/PHASE7_DESIGN.md §2.9, §3.4): D1 Wiebke Hagedorn -----------------------------

const ALL_OLD := ["s1_quendel", "s2_hemmerling", "s3_wernstein", "s4_uhlig", "s5_moor"]


func _with_d1() -> Array[StoryCorpseData]:
	var out := stories.duplicate()
	out.append(Phase7Fixtures.d1_story())
	return out


func _clear_d1_flags() -> void:
	for f: StringName in [&"village_open_day", &"linden_consecrated", &"hagedorn_dead"]:
		GameState.clear_flag(f)


func test_d1_comes_eight_days_after_the_village_opened_only_consecrated() -> void:
	_clear_d1_flags()
	var all := _with_d1()
	var delivered := PackedStringArray(ALL_OLD)
	assert_null(StoryDirector.due_story(60, delivered, 20, all, cfg), "no village_open_day")
	GameState.set_flag(&"village_open_day", 40)
	assert_null(StoryDirector.due_story(60, delivered, 20, all, cfg), "not consecrated")
	GameState.set_flag(&"linden_consecrated", true)
	assert_null(StoryDirector.due_story(47, delivered, 20, all, cfg), "40 + 8 = 48")
	assert_eq(StoryDirector.due_story(48, delivered, 20, all, cfg).id, &"d1_hagedorn")
	assert_eq(StoryDirector.due_story(48, PackedStringArray(ALL_OLD.slice(0, 4)), 20, all, cfg).id, &"s5_moor", "S1–S5 first")
	assert_null(StoryDirector.due_story(48, delivered, 47, all, cfg), "the gap of 2 days still holds")
	assert_eq(StoryDirector.due_flags(48, delivered, 20, all, cfg), [&"hagedorn_dead"] as Array[StringName])
	assert_eq(StoryDirector.due_flags(47, delivered, 20, all, cfg), [] as Array[StringName])
	_clear_d1_flags()


func test_d1_reserves_a_place_only_once_it_can_come() -> void:
	_clear_d1_flags()
	var all := _with_d1()
	var delivered := PackedStringArray(ALL_OLD)
	assert_eq(StoryDirector.pending_count(delivered, all), 0, "Phase-6 games unchanged: no reservation before the consecration")
	GameState.set_flag(&"linden_consecrated", true)
	assert_eq(StoryDirector.pending_count(delivered, all), 1, "one place stays free for Wiebke Hagedorn")
	delivered.append("d1_hagedorn")
	assert_eq(StoryDirector.pending_count(delivered, all), 0)
	_clear_d1_flags()


func test_d1_record_and_data() -> void:
	var d := Database.story_corpse(&"d1_hagedorn") as StoryCorpseData
	assert_not_null(d)
	assert_eq([d.display_name, d.age, d.cause_id, d.section, d.after_days, d.due_flag], ["Wiebke Hagedorn", 81, &"old_age", &"linden", 8, &"hagedorn_dead"])
	var r := StoryDirector.make_record(d, 77)
	assert_true(r.has_trait(&"strange_wound"), "gezeichnet")
	assert_eq(r.story_id, &"d1_hagedorn")
	var mark := Database.find(&"f_d1_mark") as FindData
	assert_eq([mark.trait_id, mark.clue_id, mark.step], [&"strange_wound", &"c_v_hagedorn", &"wounds"], "replaces f_mark (§2.9)")
	assert_almost(mark.min_freshness, 0.3)
	for id: StringName in d.finds:
		assert_true((Database.find(id) as FindData).story_only, String(id))


func test_daily_checks_set_the_due_flag_at_midnight() -> void:
	_clear_d1_flags()
	var manager := CorpseManager.new()
	manager.stories = _with_d1()
	tree.root.add_child(manager)
	manager.load_state({"story_delivered": ALL_OLD, "story_last_day": 20})
	GameState.set_flag(&"village_open_day", 40)
	GameState.set_flag(&"linden_consecrated", true)
	assert_false(StoryDirector.daily_checks(47, true, cfg).has(StoryDirector.CHECK_DUE_FLAG))
	assert_false(GameState.has_flag(&"hagedorn_dead"))
	assert_true(StoryDirector.daily_checks(48, true, cfg).has(StoryDirector.CHECK_DUE_FLAG))
	assert_eq(GameState.get_flag(&"hagedorn_dead"), 48, "her Npc disappears (hide_flag)")
	assert_false(StoryDirector.daily_checks(48, true, cfg).has(StoryDirector.CHECK_DUE_FLAG), "once")
	manager.free()
	_clear_d1_flags()


# --- Phase 8 (P6, docs/PHASE8_DESIGN.md §2.9, §3.4): D2 Gerhard Ott --------------------------------

const ALL_P7 := ["s1_quendel", "s2_hemmerling", "s3_wernstein", "s4_uhlig", "s5_moor", "d1_hagedorn"]


func _with_d2() -> Array[StoryCorpseData]:
	var out := _with_d1()
	out.append(Database.story_corpse(&"d2_ott") as StoryCorpseData)
	return out


func _clear_d2_flags() -> void:
	for f: StringName in [&"p8_open", &"ott_dead"]:
		GameState.clear_flag(f)


func test_d2_data() -> void:
	var d := Database.story_corpse(&"d2_ott") as StoryCorpseData
	assert_not_null(d)
	assert_eq([d.display_name, d.age, d.cause_id, d.traits, d.look, d.order, d.section, d.requires_flag, d.due_flag, d.after_flag],
			["Gerhard Ott", 74, &"old_age", [&"strange_wound"] as Array[StringName], 2, 7, &"linden", &"p8_open", &"ott_dead", &""],
			"§2.9 / W0-Notizen 10")
	assert_eq(d.finds, [&"f_d2_bottle", &"f_d2_wax", &"f_d2_shirt", &"f_d2_mark"] as Array[StringName])
	assert_true(d.arrival_note.begins_with("Der alte Ott.") and d.arrival_note.ends_with("Sie ist immer schon da."), "Osric (§2.9)")
	var mark := Database.find(&"f_d2_mark") as FindData
	assert_eq([mark.trait_id, mark.step, mark.story_only], [&"strange_wound", &"wounds", true], "replaces f_mark")
	assert_almost(mark.min_freshness, 0.3)
	for id: StringName in d.finds:
		var f := Database.find(id) as FindData
		assert_not_null(f, String(id))
		assert_true(f.story_only and f.text.length() > 20, String(id))
	assert_eq([(Database.find(&"f_d2_bottle") as FindData).step, (Database.find(&"f_d2_wax") as FindData).step,
			(Database.find(&"f_d2_shirt") as FindData).step], [&"pockets", &"clothing", &"clothing"])
	var r := StoryDirector.make_record(d, 5)
	assert_true(r.has_trait(&"strange_wound"), "gezeichnet")
	assert_eq([r.story_id, r.valuables_coins], [&"d2_ott", 0], "no valuables")
	assert_true(StoryDirector.waits_for_event(d))
	assert_false(StoryDirector.waits_for_event(Database.story_corpse(&"d1_hagedorn") as StoryCorpseData), "D1 keeps its rule")


func test_d2_comes_the_day_after_ott_dies() -> void:
	_clear_d1_flags()
	_clear_d2_flags()
	GameState.set_flag(&"village_open_day", 40)
	GameState.set_flag(&"linden_consecrated", true)
	var all := _with_d2()
	var delivered := PackedStringArray(ALL_P7)
	assert_null(StoryDirector.due_story(58, delivered, 48, all, cfg), "before p8_open nothing")
	GameState.set_flag(&"p8_open", true)
	for day: int in range(53, 70):
		assert_null(StoryDirector.due_story(day, delivered, 48, all, cfg), "day %d: waits for ott_dead" % day)
	assert_eq(StoryDirector.due_flags(58, delivered, 48, all, cfg), [] as Array[StringName], "the director never sets ott_dead")
	GameState.set_flag(&"ott_dead", 58)  # NightPaths, 02:10 of the death night (B6)
	assert_null(StoryDirector.due_story(58, delivered, 48, all, cfg), "not the same morning")
	assert_eq(StoryDirector.due_story(59, delivered, 48, all, cfg).id, &"d2_ott", "§1.4 B7 / §1.6 +6: the morning after")
	assert_eq(StoryDirector.due_story(61, delivered, 48, all, cfg).id, &"d2_ott", "a later delivery day catches up")
	assert_null(StoryDirector.due_story(59, delivered, 58, all, cfg), "the gap of 2 days still holds")
	assert_eq(StoryDirector.due_story(59, PackedStringArray(ALL_OLD), 20, all, cfg).id, &"d1_hagedorn", "D1 first")
	assert_eq(StoryDirector.due_flags(59, delivered, 48, all, cfg), [] as Array[StringName], "already set by NightPaths")
	GameState.set_flag(&"ott_dead", true)
	assert_eq(StoryDirector.due_story(59, delivered, 48, all, cfg).id, &"d2_ott", "a bare true counts as well")
	_clear_d2_flags()
	_clear_d1_flags()


func test_d2_reserves_a_place_from_p8_open() -> void:
	_clear_d2_flags()
	GameState.set_flag(&"linden_consecrated", true)
	var all := _with_d2()
	var delivered := PackedStringArray(ALL_P7)
	assert_eq(StoryDirector.pending_count(delivered, all), 0, "Phase-7 games unchanged")
	GameState.set_flag(&"p8_open", true)
	assert_eq(StoryDirector.pending_count(delivered, all), 1, "one place in the third row stays free for D2")
	delivered.append("d2_ott")
	assert_eq(StoryDirector.pending_count(delivered, all), 0)
	_clear_d2_flags()
	_clear_d1_flags()


func test_daily_checks_leave_ott_dead_to_the_night() -> void:
	_clear_d1_flags()
	_clear_d2_flags()
	var manager := CorpseManager.new()
	manager.stories = _with_d2()
	tree.root.add_child(manager)
	manager.load_state({"story_delivered": ALL_P7, "story_last_day": 48})
	GameState.set_flag(&"village_open_day", 40)
	GameState.set_flag(&"linden_consecrated", true)
	GameState.set_flag(&"p8_open", true)
	for day: int in range(53, 62):
		assert_false(StoryDirector.daily_checks(day, true, cfg).has(StoryDirector.CHECK_DUE_FLAG), "day %d" % day)
	assert_false(GameState.has_flag(&"ott_dead"), "only NightPaths sets it")
	manager.free()
	_clear_d2_flags()
	_clear_d1_flags()
