extends TestCase
## P4 (docs/PHASE9_DESIGN.md §2.2.1, §2.2.2, §3.4, §10): LightRules – the dates of the list from the records of
## slot_p8_day63_kindly (death = arrival − 1, light = death − 21; D2 from night_paths.deaths.np_ott), S1 / S3 before game
## day 1 counted back (StoneCalendar unchanged), e_dorn fixed, a missing dead → substitute date (earliest_day − 22),
## the open light p9_open_day − 12, Johann's death light + 21 and the deadline light + 17; names (Kaspar with
## i_not_lorenz). Phase9Fixtures.list_records + doubles.


class CorpsesDouble extends Node:
	var recs: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return recs


class JournalDouble extends Node:
	var insights: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_insight(id: StringName) -> bool:
		return insights.has(id)


var corpses: CorpsesDouble
var paths: NightPaths
var journal: JournalDouble
var list: LightListData
var cfg: WhoKnowsConfig


func before_each() -> void:
	GameState.reset()
	corpses = CorpsesDouble.new()
	corpses.recs = Phase9Fixtures.list_records()
	paths = NightPaths.new()
	paths.path_data = Phase8Fixtures.night_paths()
	paths.load_state({"observed": [], "deaths": {"np_ott": 58}, "last_total": 0})
	journal = JournalDouble.new()
	for n: Node in [corpses, paths, journal]:
		tree.root.add_child(n)
	list = Phase9Fixtures.light_list()
	cfg = Phase9Fixtures.who_knows_config()


func after_each() -> void:
	for n: Node in [corpses, paths, journal]:
		n.free()
	GameState.reset()


func _e(id: StringName) -> LightEntryData:
	for e: LightEntryData in list.entries:
		if e.id == id:
			return e
	return null


func test_light_days_from_the_kindly_records() -> void:
	assert_eq(LightRules.light_day(_e(&"e_quendel"), tree, cfg), -16, "S1: arrival 6 → death 5 → −16 (before game day 1)")
	assert_eq(LightRules.light_day(_e(&"e_wernstein"), tree, cfg), -9, "S3: 13 → 12 → −9")
	assert_eq(LightRules.light_day(_e(&"e_hagedorn"), tree, cfg), 26, "D1: 48 → 47 → 26")
	assert_eq(LightRules.light_day(_e(&"e_ott"), tree, cfg), 37, "D2: night_paths.deaths.np_ott 58 → 37")
	assert_eq(LightRules.light_day(_e(&"e_dorn"), tree, cfg), LightRules.NO_DAY, "e_dorn: fixed")
	assert_eq(LightRules.death_of(&"d2_ott", tree), 58)


func test_d2_without_night_paths_uses_the_flag_then_the_arrival() -> void:
	paths.load_state({"deaths": {}})
	assert_eq(LightRules.light_day(_e(&"e_ott"), tree, cfg), 37, "arrival 59 − 1 = 58")
	GameState.set_flag(&"ott_dead", 57)
	assert_eq(LightRules.light_day(_e(&"e_ott"), tree, cfg), 36, "the death flag (calendar day) before the arrival")


func test_date_texts_also_before_game_day_one() -> void:
	assert_eq(LightRules.entry_text(_e(&"e_dorn"), tree, cfg), "2. Julmond 1833")
	assert_eq(LightRules.entry_text(_e(&"e_quendel"), tree, cfg), "16. Scheiding 1834", "3. Gilbhart − 17 days")
	assert_eq(LightRules.entry_text(_e(&"e_wernstein"), tree, cfg), "23. Scheiding 1834")
	assert_eq(LightRules.entry_text(_e(&"e_hagedorn"), tree, cfg), "28. Gilbhart 1834")
	assert_eq(LightRules.entry_text(_e(&"e_ott"), tree, cfg), "8. Nebelung 1834")
	assert_eq(LightRules.date_text(0), "2. Gilbhart 1834")
	assert_eq(LightRules.date_text(-2), "30. Scheiding 1834", "a month boundary")
	assert_eq(LightRules.date_text(-276), "30. Julmond 1833", "a year back (3. Gilbhart − 277 days)")
	assert_eq(LightRules.date_text(51), StoneCalendar.date_text(51, Database.config(&"stone_config") as StoneConfig), "day ≥ 1: StoneCalendar")
	assert_eq(StoneCalendar.date_text(-16, Database.config(&"stone_config") as StoneConfig), "3. Gilbhart 1834", "StoneCalendar stays (clamps)")


func test_open_light_death_and_deadline() -> void:
	assert_eq(LightRules.open_light_day(63, cfg), 51, "§2.2.2: p9_open_day − 12")
	assert_eq(LightRules.death_day(51, cfg), 72, "light + 21 = 13. Julmond")
	assert_eq(LightRules.decide_day(51, cfg), 68, "light + 17 = B6")
	assert_eq(LightRules.date_text(51), "22. Nebelung 1834")
	assert_eq(LightRules.date_text(72), "13. Julmond 1834")
	assert_eq([LightRules.open_light_day(0, cfg), LightRules.death_day(LightRules.NO_DAY, cfg), LightRules.decide_day(LightRules.NO_DAY, cfg)],
			[LightRules.NO_DAY, LightRules.NO_DAY, LightRules.NO_DAY])
	assert_eq(LightRules.light_day(_e(&"e_open"), tree, cfg), LightRules.NO_DAY, "Phase 9 closed")
	GameState.set_flag(&"p9_open_day", 63)
	assert_eq(LightRules.light_day(_e(&"e_open"), tree, cfg), 51, "from p9_open_day")
	GameState.set_flag(&"q_light_day", 50)
	assert_eq(LightRules.light_day(_e(&"e_open"), tree, cfg), 50, "q_light_day wins")
	assert_eq(LightRules.entry_text(_e(&"e_open"), tree, cfg), "21. Nebelung 1834")
	GameState.set_flag(&"q_light_day", "x")
	assert_eq(LightRules.flag_day(&"q_light_day"), LightRules.NO_DAY, "a damaged flag is no day")


func test_missing_dead_and_graves_and_names() -> void:
	corpses.recs = corpses.recs.filter(func(r: CorpseRecord) -> bool: return r.story_id != &"s1_quendel")
	assert_eq(LightRules.light_day(_e(&"e_quendel"), tree, cfg), LightRules.NO_DAY, "never delivered")
	assert_eq(LightRules.substitute_day(_e(&"e_quendel")), 6 - 22, "earliest_day − 22")
	assert_eq(LightRules.entry_text(_e(&"e_quendel"), tree, cfg), LightRules.date_text(-16), "the substitute date")
	assert_eq(LightRules.grave_of(_e(&"e_quendel"), tree), "", "not on the hill")
	assert_eq(LightRules.grave_of(_e(&"e_ott"), tree), "l_12")
	assert_eq(LightRules.grave_of(_e(&"e_open"), tree), "")
	var hagedorn := LightRules.record_of(&"d1_hagedorn", tree)
	hagedorn.location = CorpseRecord.LOCATION_TABLE
	assert_eq(LightRules.grave_of(_e(&"e_hagedorn"), tree), "", "delivered, not buried")
	assert_eq(LightRules.light_day(_e(&"e_hagedorn"), tree, cfg), 26, "the date stays")
	assert_eq(LightRules.entry_name(_e(&"e_dorn"), tree), LightRules.MOOR_NAME, "without i_not_lorenz")
	journal.insights.append(&"i_not_lorenz")
	var kaspar := LightRules.record_of(&"s5_moor", tree)
	kaspar.display_name = "Kaspar Dorn"
	assert_eq(LightRules.entry_name(_e(&"e_dorn"), tree), "Kaspar Dorn")
	assert_eq(LightRules.entry_name(_e(&"e_open"), tree), "")
	assert_eq(LightRules.light_day(null, tree, cfg), LightRules.NO_DAY)
	assert_eq(LightRules.entry_text(null, tree, cfg), "")
