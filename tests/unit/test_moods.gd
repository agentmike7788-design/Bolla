extends TestCase
## P1 (docs/PHASE8_DESIGN.md §1.2, §1.5, §2.1.1, §3.4, §10): MoodRules and NpcLife – the daily roll is
## deterministic (day, npc_id) and follows the weights, the precedence rules 1–5, the effects only from
## p8_open (talk +2 / +1 / 0, „gereizt" offers nothing, „[Zuhören]" once per day: 10 min, +3, piety +1),
## the opening (morning rule, v6 at once in post_load, v7 keeps the morning), moods_rolled, the chapter
## check exactly once, save / load. Configs and villagers from tests/fixtures/phase8 (Phase8Fixtures).


class FakeApprentice extends Node:
	var hired := true
	var levels := {}

	func _init() -> void:
		add_to_group(&"apprentice")

	func is_hired() -> bool:
		return hired

	func level(task: StringName) -> int:
		return int(levels.get(task, 0))


class FakeVisitors extends Node:
	var wishes: Array = []

	func _init() -> void:
		add_to_group(&"visitors")

	func save_state() -> Dictionary:
		return {"wishes": wishes}


class FakeFriendship extends Node:
	var steps := 0
	var full := 0

	func _init() -> void:
		add_to_group(&"friendship")

	func steps_total() -> int:
		return steps

	func full_stories() -> int:
		return full


class FakeJournal extends Node:
	var insights: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_insight(id: StringName) -> bool:
		return insights.has(id)


class FakeVillage extends Node:
	var houses := {}

	func _init() -> void:
		add_to_group(&"village")

	func mourning_house(day: int) -> StringName:
		return houses.get(day, &"")

	func villager_present(_npc_id: StringName) -> bool:
		return true


class FakeFestivals extends Node:
	var days := {}

	func _init() -> void:
		add_to_group(&"festivals")

	func fest_day(id: StringName) -> int:
		return int(days.get(id, -1))

	func today() -> StringName:
		for id: StringName in days:
			if int(days[id]) == TimeManager.day:
				return id
		return &""


class FakeNightPaths extends Node:
	var burning_days: Array = []

	func _init() -> void:
		add_to_group(&"night_paths")

	func sick_houses(day: int, _minute: int) -> PackedStringArray:
		return PackedStringArray(["house_ott"]) if burning_days.has(day) else PackedStringArray()


var life: NpcLife
var rel: Relationships
var holder: Node
var rolled: Array = []
var chapters: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.day = 55
	TimeManager.minute_of_day = 600
	holder = Node.new()
	holder.name = "P8MoodWorld"
	tree.root.add_child(holder)
	life = NpcLife.new()
	life.config = Phase8Fixtures.npc_life_config()
	for v: VillagerData in Phase8Fixtures.villagers():
		life.villagers[v.npc_id] = v
	holder.add_child(life)
	rel = Relationships.new()
	rel.config = Phase8Fixtures.relationship_config()
	for v: VillagerData in Phase8Fixtures.villagers():
		rel.villagers[v.npc_id] = v
	holder.add_child(rel)
	rolled.clear()
	chapters.clear()
	EventBus.moods_rolled.connect(_on_rolled)
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.moods_rolled.disconnect(_on_rolled)
	EventBus.chapter_completed.disconnect(_on_chapter)
	holder.free()
	GameState.reset()
	TimeManager.reset()


func _on_rolled(day: int) -> void:
	rolled.append(day)


func _on_chapter(id: StringName) -> void:
	chapters.append(id)


func _open(day: int = 53) -> void:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"name_in_village_complete", true)
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", day)


# --- MoodRules ----------------------------------------------------------------------------------

func test_roll_is_deterministic_and_follows_the_weights() -> void:
	var cfg := Phase8Fixtures.npc_life_config()
	assert_eq(MoodRules.roll(&"smith", 55, cfg), MoodRules.roll(&"smith", 55, cfg), "same day, same mood")
	var counts := {}
	var differs := false
	for day: int in range(1, 2001):
		var m := MoodRules.roll(&"innkeeper", day, cfg)
		assert_true(m in cfg.moods, "a known mood")
		counts[m] = int(counts.get(m, 0)) + 1
		if m != MoodRules.roll(&"priest", day, cfg):
			differs = true
	assert_true(differs, "npc_id goes into the roll")
	for mood: StringName in cfg.mood_weights:
		var share := float(counts.get(mood, 0)) / 2000.0
		assert_almost(share, cfg.mood_weights[mood] / 100.0, 0.04, "§2.1.1 weight of %s (%.3f)" % [mood, share])
	var flat := cfg.duplicate() as NpcLifeConfig
	flat.mood_weights = {&"plain": 0, &"cheerful": 0, &"low": 1, &"cross": 0} as Dictionary[StringName, int]
	assert_eq(MoodRules.roll(&"smith", 9, flat), &"low")
	flat.mood_weights = {} as Dictionary[StringName, int]
	assert_eq(MoodRules.roll(&"smith", 9, flat), &"plain", "no weights → plain")


func test_precedence_rules_one_to_five() -> void:
	var cfg := Phase8Fixtures.npc_life_config()
	var grocer := Phase8Fixtures.villager_data(&"grocer")
	var priest := Phase8Fixtures.villager_data(&"priest")
	var washer := Phase8Fixtures.villager_data(&"washer")
	var mayor := Phase8Fixtures.villager_data(&"mayor")
	var surgeon := Phase8Fixtures.villager_data(&"surgeon")
	var day := 55
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {}, cfg, grocer), &"plain", "no event: the roll")
	# 1 festival day: everyone cheerful – even with a ribbon in the circle.
	var ev := {&"festival": day, &"mourning:house_kehr": day}
	assert_eq(MoodRules.apply_rules(&"low", &"grocer", day, ev, cfg, grocer), &"cheerful", "1 before 2")
	assert_eq(MoodRules.apply_rules(&"cross", &"surgeon", day, {&"festival": day}, cfg, surgeon), &"cheerful", "everyone")
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"festival": day - 1}, cfg, grocer), &"plain", "only today")
	# 2 mourning ribbon in the own circle today or yesterday.
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"mourning:house_kehr": day - 1}, cfg, grocer), &"low", "yesterday")
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"mourning:house_kehr": [day - 5, day]}, cfg, grocer), &"low", "list")
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"mourning:house_brandt": day}, cfg, grocer), &"plain",
			"not her circle")
	assert_eq(MoodRules.apply_rules(&"plain", &"washer", day, {&"mourning:cottage_hagedorn": day}, cfg, washer), &"low",
			"Liesel: both cottages")
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"mourning:house_kehr": day - 2}, cfg, grocer), &"plain", "too old")
	# 3 the own story step yesterday.
	assert_eq(MoodRules.apply_rules(&"low", &"priest", day, {&"step:priest": day - 1}, cfg, priest), &"cheerful")
	assert_eq(MoodRules.apply_rules(&"low", &"priest", day, {&"step:priest": day}, cfg, priest), &"low", "yesterday only")
	assert_eq(MoodRules.apply_rules(&"low", &"priest", day, {&"step:washer": day - 1}, cfg, priest), &"low", "someone else's")
	assert_eq(MoodRules.apply_rules(&"low", &"grocer", day, {&"step:grocer": day - 1, &"mourning:house_kehr": day}, cfg, grocer),
			&"low", "2 before 3")
	# 4 bad talk yesterday: priest / washer (lecture, specimen), mayor (disturbed grave).
	assert_eq(MoodRules.apply_rules(&"plain", &"priest", day, {&"lecture_rumor": day - 1}, cfg, priest), &"cross")
	assert_eq(MoodRules.apply_rules(&"plain", &"washer", day, {&"specimen_sold_villager": day - 1}, cfg, washer), &"cross")
	assert_eq(MoodRules.apply_rules(&"plain", &"mayor", day, {&"lecture_rumor": day - 1}, cfg, mayor), &"plain", "not the mayor")
	assert_eq(MoodRules.apply_rules(&"plain", &"mayor", day, {&"grave_disturbed": day - 1}, cfg, mayor), &"cross")
	assert_eq(MoodRules.apply_rules(&"plain", &"priest", day, {&"grave_disturbed": day - 1}, cfg, priest), &"plain")
	assert_eq(MoodRules.apply_rules(&"plain", &"grocer", day, {&"lecture_rumor": day - 1}, cfg, grocer), &"plain")
	# 5 a sick light: Quast, Lenz, Liesel low.
	for id: StringName in [&"surgeon", &"priest", &"washer"]:
		assert_eq(MoodRules.apply_rules(&"cheerful", id, day, {&"sick_light": day}, cfg, Phase8Fixtures.villager_data(id)), &"low", String(id))
	assert_eq(MoodRules.apply_rules(&"plain", &"smith", day, {&"sick_light": day}, cfg, Phase8Fixtures.villager_data(&"smith")), &"plain")
	assert_eq(MoodRules.apply_rules(&"plain", &"priest", day, {&"lecture_rumor": day - 1, &"sick_light": day}, cfg, priest), &"cross",
			"4 before 5")


# --- NpcLife: moods in the world ----------------------------------------------------------------

func test_mood_from_the_systems_and_effects_only_from_p8_open() -> void:
	var village := FakeVillage.new()
	holder.add_child(village)
	var paths := FakeNightPaths.new()
	holder.add_child(paths)
	var fest := FakeFestivals.new()
	holder.add_child(fest)
	var cfg := Phase8Fixtures.npc_life_config()
	assert_eq(life.mood(&"smith"), MoodRules.roll(&"smith", 55, cfg), "the roll")
	village.houses[54] = &"house_brandt"
	assert_eq(life.mood(&"smith"), &"low", "Brandt's ribbon yesterday: Esch is low")
	paths.burning_days = [55]
	assert_eq(life.mood(&"surgeon"), &"low", "a sick light tonight")
	fest.days[&"fest_kathrein"] = 55
	assert_eq(life.mood(&"smith"), &"cheerful", "festival day")
	assert_eq(life.mood(&"surgeon"), &"cheerful")
	# Before p8_open: no effect – talk +1, nothing blocked, no listening.
	life.set_mood(&"innkeeper", &"cheerful")
	life.set_mood(&"smith", &"cross")
	life.set_mood(&"grocer", &"low")
	assert_false(life.moods_active())
	assert_eq(life.offer_block_reason(&"smith"), "", "before p8_open nothing blocked")
	assert_ne(life.listen_block_reason(&"grocer"), "", "no listening before p8_open")
	rel.meet(&"innkeeper")
	var before := rel.value(&"innkeeper")
	rel.note_talk(&"innkeeper")
	assert_eq(rel.value(&"innkeeper") - before, 1, "before p8_open: +1")
	assert_ne(life.greeting(&"innkeeper"), "", "the greeting may use the mood before")
	_open()
	TimeManager.day = 56
	life.set_mood(&"innkeeper", &"cheerful")
	life.set_mood(&"smith", &"cross")
	life.set_mood(&"priest", &"plain")
	assert_true(life.moods_active())
	for spec: Array in [[&"innkeeper", 2], [&"smith", 0], [&"priest", 1]]:
		rel.meet(spec[0])
		var v := rel.value(spec[0])
		rel.note_talk(spec[0])
		assert_eq(rel.value(spec[0]) - v, spec[1], "§2.1.1 talk %s" % spec[0])
	assert_eq(life.offer_block_reason(&"smith"), "Heute nicht, Totengräber. Morgen.", "gereizt offers nothing")
	assert_eq(life.offer_block_reason(&"priest"), "")
	assert_true(life.greeting(&"smith") in Phase8Fixtures.villager_data(&"smith").mood_lines[&"cross"])
	TimeManager.day = 57
	assert_eq(life.mood(&"smith"), MoodRules.apply_rules(MoodRules.roll(&"smith", 57, cfg), &"smith", 57, life.mood_events(57), cfg,
			life.villager(&"smith")), "the override is for one day")


func test_listen_once_per_day() -> void:
	var piety := Piety.new()
	holder.add_child(piety)
	_open()
	life.set_mood(&"grocer", &"plain")
	assert_eq(life.listen_block_reason(&"grocer"), NpcLife.TEXT_NOT_LOW)
	assert_false(life.listen(&"grocer"))
	life.set_mood(&"grocer", &"low")
	assert_eq(life.listen_block_reason(&"grocer"), "")
	assert_eq(life.listen_block_reason(&"carter"), NpcLife.TEXT_UNKNOWN, "only villagers")
	rel.meet(&"grocer")
	var v := rel.value(&"grocer")
	var p := piety.value()
	var t := TimeManager.total_minutes()
	assert_true(life.listen(&"grocer"))
	assert_eq(TimeManager.total_minutes() - t, 10, "10 minutes")
	assert_eq(rel.value(&"grocer") - v, 3, "relationship +3")
	assert_eq(piety.value() - p, 1, "piety +1")
	assert_eq(GameState.get_stat(&"listens"), 1)
	assert_true(life.listened_today(&"grocer"))
	assert_eq(life.listen_block_reason(&"grocer"), NpcLife.TEXT_LISTENED)
	assert_false(life.listen(&"grocer"), "once per day")
	TimeManager.day += 1
	life.set_mood(&"grocer", &"low")
	assert_eq(life.listen_block_reason(&"grocer"), "", "next day again")


func test_opening_morning_rule_and_moods_rolled() -> void:
	TimeManager.day = 50
	TimeManager.minute_of_day = 1000
	GameState.set_flag(&"village_open", true)
	life.apply_morning(50)
	assert_false(life.is_open(), "without the chapter nothing")
	GameState.set_flag(&"name_in_village_complete", true)
	EventBus.chapter_completed.emit(&"name_in_village")
	life.apply_morning(50)
	assert_false(life.is_open(), "the same evening: not yet")
	TimeManager.day = 51
	TimeManager.minute_of_day = 300
	life.apply_morning(51)
	assert_false(life.is_open(), "05:00: not yet")
	TimeManager.minute_of_day = 360
	life.apply_morning(51)
	assert_true(life.is_open(), "the first minute ≥ 06:00 after the chapter")
	assert_eq([life.open_day(), int(GameState.get_flag(&"p8_open_day"))], [51, 51])
	assert_eq(rolled, [51], "moods_rolled once")
	life.apply_morning(51)
	assert_eq(rolled, [51], "idempotent")
	TimeManager.day = 52
	TimeManager.minute_of_day = 200
	life.apply_morning(52)
	assert_eq(rolled, [51], "before 06:00 no roll")
	TimeManager.minute_of_day = 400
	life.apply_morning(52)
	assert_eq(rolled, [51, 52])
	assert_eq(life.open_day(), 51, "the open day stays")


func test_post_load_v6_opens_at_once_v7_keeps_the_morning() -> void:
	GameState.set_flag(&"name_in_village_complete", true)
	TimeManager.minute_of_day = 1385
	life.load_state({})
	life.post_load()
	assert_true(life.is_open(), "§1.2: a migrated v6 save opens at once, also after 06:00")
	assert_eq(life.open_day(), 55)
	GameState.reset()
	GameState.set_flag(&"name_in_village_complete", true)
	var other := NpcLife.new()
	other.config = Phase8Fixtures.npc_life_config()
	holder.add_child(other)
	other.load_state({"open_day": 0, "events": {}, "goal_done": false})
	other.post_load()
	assert_false(other.is_open(), "a v7 state keeps the morning rule")
	other.apply_morning(55)
	TimeManager.day = 56
	TimeManager.minute_of_day = 360
	other.apply_morning(56)
	assert_true(other.is_open())


func test_check_goal_exactly_once() -> void:
	_open()
	var app := FakeApprentice.new()
	var vis := FakeVisitors.new()
	var fr := FakeFriendship.new()
	var journal := FakeJournal.new()
	for n: Node in [app, vis, fr, journal]:
		holder.add_child(n)
	var panels: Array = []
	var on_panel := func(panel: StringName, ctx: Dictionary) -> void: panels.append([panel, ctx])
	EventBus.ui_panel_requested.connect(on_panel)
	assert_false(life.check_goal())
	app.levels = {&"rake": 1, &"weed": 2}
	for i: int in 5:
		vis.wishes.append({"wish_id": "w_%d" % i, "kin_id": ["kin_kehr", "kin_brandt", "kin_smith"][i % 3], "state": "done"})
	vis.wishes.append({"wish_id": "w_9", "kin_id": "kin_ott", "state": "failed"})
	fr.steps = 6
	fr.full = 1
	var p := life.goal_progress()
	assert_eq([p.hired, p.levels, p.wishes, p.kin, p.steps, p.full, p.insight, p.done, p.total], [true, 2, 5, 3, 6, 1, false, 3, 4])
	assert_false(life.check_goal(), "the insight is missing")
	fr.full = 0
	journal.insights = [&"i_underlined"]
	assert_false(life.check_goal(), "a full story is needed")
	fr.full = 1
	vis.wishes[2].kin_id = "kin_kehr"
	assert_eq(life.goal_progress().kin, 2)
	assert_false(life.check_goal(), "three different kin")
	vis.wishes[2].kin_id = "kin_sieber"
	EventBus.insight_unlocked.emit(&"i_underlined")
	assert_true(GameState.flag_on(&"who_comes_up_complete"), "the signal checks")
	assert_eq(chapters, [&"who_comes_up"])
	assert_false(life.check_goal(), "exactly once")
	assert_eq(chapters.size(), 1)
	assert_eq(panels.size(), 1)
	assert_eq(panels[0][0], &"slice_summary")
	assert_eq(StringName(panels[0][1].variant), &"who_comes_up")
	assert_true(str(panels[0][1].final_line).begins_with("Früher kam nur Osric"))
	EventBus.ui_panel_requested.disconnect(on_panel)
	app.hired = false
	var state := life.save_state()
	assert_true(state.goal_done)


func test_note_event_and_save_load_roundtrip() -> void:
	_open()
	life.note_event(&"wish_done", [&"grocer"] as Array[StringName])
	life.note_event(&"wish_done", [&"innkeeper"] as Array[StringName])
	life.note_event(&"apprentice_hired")
	life.note_chatter(&"ch_well_spin")
	life.set_mood(&"grocer", &"low")
	life.listen(&"grocer")
	var state := life.save_state()
	assert_eq(state.events, {"wish_done": 55, "apprentice_hired": 55})
	assert_eq(state.event_npcs.wish_done, ["grocer", "innkeeper"], "merged on the same day")
	assert_eq(state.listened, {"grocer": 55})
	assert_eq(state.chatter_day, {"ch_well_spin": 55})
	var back := JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(state)))) as Dictionary
	var other := NpcLife.new()
	other.config = Phase8Fixtures.npc_life_config()
	holder.add_child(other)
	other.load_state(back)
	assert_eq(other.save_state(), state, "roundtrip identical")
	assert_true(other.chatter_seen_today(&"ch_well_spin"))
	assert_true(other.listened_today(&"grocer"))
	other.load_state({"events": {"a": "x", "b": 3.0}, "event_npcs": {"b": [1, "smith"], "zz": ["x"]}, "listened": [], "goal_done": 1})
	assert_eq(other.save_state(), {"open_day": 53, "events": {"b": 3}, "event_npcs": {"b": ["smith"]}, "listened": {},
			"chatter_day": {}, "goal_done": false}, "tolerant")
	# Moods are derived, not saved: the same after a load.
	life.set_mood(&"grocer", &"")
	assert_eq(other.mood(&"grocer"), life.mood(&"grocer"))
