extends TestCase
## P2 (docs/PHASE4_DESIGN.md §2.1, §2.2, §10): CorpseExam – candidates (generic / cause / story,
## replacement), revealed vs. lost exactly at min_freshness, locks after dressing, thorough =
## single steps, examined after the first step, traits_revealed, valuables only after pockets,
## next_loss; CorpseCare examination (flags, clues, signals, notify_changed) on fixtures.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"


## CorpseManager with hand-made records (no nodes, no delivery).
class ManagerDouble extends CorpseManager:
	var recs: Dictionary = {}
	var notified: Array[String] = []

	func _ready() -> void:
		pass

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord

	func records() -> Array[CorpseRecord]:
		var out: Array[CorpseRecord] = []
		out.assign(recs.values())
		return out

	func notify_changed(id: String) -> void:
		notified.append(id)


class JournalDouble extends JournalManager:
	var added: Array = []

	func add_clue(id: StringName, corpse_id: String = "", _silent: bool = false) -> bool:
		added.append([id, corpse_id])
		return true


var exam: ExamConfig
var all_finds: Array[FindData]
var manager: ManagerDouble
var journal: JournalDouble
var care: CorpseCare
var steps_done: Array = []


func before_each() -> void:
	exam = Phase4Fixtures.exam_config()
	all_finds = Phase4Fixtures.finds()
	steps_done.clear()
	manager = ManagerDouble.new()
	journal = JournalDouble.new()
	care = CorpseCare.new()
	care.exam_config = exam
	care.prep_config = Phase4Fixtures.prep_config()
	care.utilization_config = Phase4Fixtures.utilization_config()
	care.tables = load(FIXTURE_TABLES) as CorpseTables
	care.finds = all_finds
	for s: StoryCorpseData in Phase4Fixtures.stories():
		care.stories[s.id] = s
	for n: Node in [manager, journal, care]:
		tree.root.add_child(n)
	EventBus.exam_step_done.connect(_on_step)


func after_each() -> void:
	EventBus.exam_step_done.disconnect(_on_step)


func _on_step(id: String, step: StringName, revealed: Array[StringName], lost: Array[StringName]) -> void:
	steps_done.append([id, step, revealed, lost])


func _record(traits: Array[StringName] = [], cause: StringName = &"fever", freshness: float = 1.0, id: String = "corpse_test") -> CorpseRecord:
	var r := Phase4Fixtures.corpse(traits, cause, freshness)
	r.id = id
	r.location = CorpseRecord.LOCATION_TABLE
	manager.recs[id] = r
	return r


func _story_record(story_id: StringName, freshness: float = 1.0) -> CorpseRecord:
	var s := Phase4Fixtures.story(story_id)
	var r := _record(s.traits, s.cause_id, freshness, "corpse_" + String(story_id))
	r.story_id = story_id
	return r


func _ids(finds: Array[FindData]) -> Array:
	var out: Array = []
	for f: FindData in finds:
		out.append(f.id)
	return out


# --- candidates ------------------------------------------------------------------------------

func test_generic_candidates_follow_traits_and_cause() -> void:
	var r := _record([&"valuables", &"letter", &"tattoo", &"strange_wound"], &"poisoned")
	assert_eq(_ids(CorpseExam.candidates(r, &"clothing", all_finds, null, exam)), [])
	assert_eq(_ids(CorpseExam.candidates(r, &"hands", all_finds, null, exam)), [&"f_tattoo"])
	assert_eq(_ids(CorpseExam.candidates(r, &"wounds", all_finds, null, exam)), [&"f_mark", &"f_cause_poisoned"])
	assert_eq(_ids(CorpseExam.candidates(r, &"pockets", all_finds, null, exam)), [&"f_valuables", &"f_letter"])
	var plain := _record([], &"fever", 1.0, "plain")
	assert_eq(_ids(CorpseExam.candidates(plain, &"wounds", all_finds, null, exam)), [&"f_cause_fever"], "only the cause detail")
	assert_eq(_ids(CorpseExam.candidates(plain, &"pockets", all_finds, null, exam)), [])


func test_story_finds_are_added_and_replace_generic_ones() -> void:
	var s1 := _story_record(&"s1_quendel")
	var story := Phase4Fixtures.story(&"s1_quendel")
	assert_eq(_ids(CorpseExam.candidates(s1, &"clothing", all_finds, story, exam)), [&"f_s1_sprig"])
	assert_eq(_ids(CorpseExam.candidates(s1, &"hands", all_finds, story, exam)), [&"f_s1_soil"])
	assert_eq(_ids(CorpseExam.candidates(s1, &"wounds", all_finds, story, exam)), [&"f_mark", &"f_cause_old_age"], "S1 keeps the generic mark")
	assert_eq(_ids(CorpseExam.candidates(s1, &"pockets", all_finds, story, exam)), [&"f_s1_page"])
	var s3 := _story_record(&"s3_wernstein")
	var s3d := Phase4Fixtures.story(&"s3_wernstein")
	assert_eq(_ids(CorpseExam.candidates(s3, &"wounds", all_finds, s3d, exam)), [&"f_cause_poisoned", &"f_s3_mark"], "f_s3_mark replaces f_mark")
	assert_eq(_ids(CorpseExam.candidates(s3, &"pockets", all_finds, s3d, exam)), [&"f_s3_letter"], "f_s3_letter replaces f_letter")
	# Story finds never appear without their story.
	assert_eq(_ids(CorpseExam.candidates(s3, &"pockets", all_finds, null, exam)), [&"f_letter"])


func test_every_story_find_is_reachable() -> void:
	for s: StoryCorpseData in Phase4Fixtures.stories():
		var r := _story_record(s.id)
		var seen: Array = []
		for step: StringName in CorpseRecord.STEPS:
			seen.append_array(_ids(CorpseExam.candidates(r, step, all_finds, s, exam)))
		for fid: StringName in s.finds:
			assert_has(seen, fid, "%s: %s" % [s.id, fid])


# --- resolve ---------------------------------------------------------------------------------

func test_revealed_or_lost_exactly_at_min_freshness() -> void:
	var tattoo: Array[FindData] = [Phase4Fixtures.find(&"f_tattoo")]
	var fine: Array[FindData] = [Phase4Fixtures.find(&"f_cause_fever")]
	var r := _record([&"tattoo"])
	for c: Array in [[0.3, tattoo, true], [0.299999, tattoo, false], [0.6, fine, true], [0.599999, fine, false], [0.0, [Phase4Fixtures.find(&"f_letter")] as Array[FindData], true]]:
		r.freshness = c[0]
		var res := CorpseExam.resolve(r, c[1])
		var id: StringName = (c[1] as Array[FindData])[0].id
		assert_eq(res.revealed, [id] if c[2] else [], "%s at %s revealed" % [id, c[0]])
		assert_eq(res.lost, [] if c[2] else [id], "%s at %s lost" % [id, c[0]])


func test_resolve_skips_known_finds() -> void:
	var r := _record([&"tattoo"])
	r.finds_revealed.append(&"f_tattoo")
	assert_eq(CorpseExam.resolve(r, [Phase4Fixtures.find(&"f_tattoo")] as Array[FindData]), {"revealed": [], "lost": []})


# --- block reasons / steps -------------------------------------------------------------------

func test_block_reasons_and_open_steps() -> void:
	var r := _record()
	assert_eq(CorpseExam.open_steps(r, exam), CorpseRecord.STEPS)
	assert_eq(CorpseExam.block_reason(r, &"clothing", exam), "")
	assert_ne(CorpseExam.block_reason(r, &"nope", exam), "", "unknown step")
	r.exam_done.append(&"hands")
	assert_eq(CorpseExam.block_reason(r, &"hands", exam), "Schon untersucht.")
	r.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(CorpseExam.block_reason(r, &"clothing", exam), "Nach dem Einkleiden nicht mehr zugänglich.")
	assert_eq(CorpseExam.block_reason(r, &"pockets", exam), "Nach dem Einkleiden nicht mehr zugänglich.")
	assert_eq(CorpseExam.block_reason(r, &"wounds", exam), "", "wounds stay possible")
	assert_eq(CorpseExam.open_steps(r, exam), [&"wounds"] as Array[StringName])


func test_minutes_for() -> void:
	assert_eq(CorpseExam.minutes_for(CorpseRecord.STEPS, exam), 45, "§1.2 max 45")
	assert_eq(CorpseExam.minutes_for([&"clothing", &"pockets"] as Array[StringName], exam), 20)
	assert_eq(CorpseExam.minutes_for([] as Array[StringName], exam), 0)


# --- next_loss -------------------------------------------------------------------------------

func test_next_loss_picks_the_first_find_at_risk() -> void:
	# Arrival 07:40 (460), rate 0.05/h: 0.6 at 15:40 (+480 min), 0.3 at 21:40 (+840).
	var r := _record([&"tattoo"])
	var pending: Array[FindData] = [Phase4Fixtures.find(&"f_tattoo"), Phase4Fixtures.find(&"f_cause_fever"), Phase4Fixtures.find(&"f_letter")]
	var loss := CorpseExam.next_loss(r, pending, 460, 0.05, 0.25)
	assert_eq(loss.find_id, &"f_cause_fever")
	assert_eq(loss.minutes, 481, "first minute below 0.6")
	assert_eq(loss.label, "Feine Spuren")
	assert_eq(loss.stage_label, "Welk")
	loss = CorpseExam.next_loss(r, pending, 460 + 500, 0.05, 0.25)
	assert_eq(loss.find_id, &"f_tattoo", "fine traces already gone – the skin mark is next")
	assert_eq(loss.minutes, 840 - 500 + 1)
	assert_eq([loss.label, loss.stage_label], ["Hautzeichen", "Verwesend"])
	assert_eq(CorpseExam.next_loss(r, pending, 460 + 900, 0.05, 0.25), {}, "paper is never lost")
	assert_eq(CorpseExam.next_loss(r, pending, 460, 0.0, 0.25), {}, "no decay")


# --- CorpseCare examination ------------------------------------------------------------------

func test_first_step_sets_examined_and_reveals_its_finds() -> void:
	var r := _record([&"valuables", &"tattoo"], &"fever")
	assert_eq(care.step_block_reason(r.id, &"hands"), "")
	var res := care.exam_step(r.id, &"hands")
	assert_eq(res, {"step": &"hands", "revealed": [&"f_tattoo"], "lost": []})
	assert_true(r.examined, "examined after the first step")
	assert_eq(r.exam_done, [&"hands"] as Array[StringName])
	assert_eq(r.traits_revealed, [&"tattoo"] as Array[StringName])
	assert_false(r.traits_revealed.has(&"valuables"), "valuables only after pockets")
	assert_eq(journal.added, [[&"c_anchor_snake", r.id]])
	assert_eq(steps_done, [[r.id, &"hands", [&"f_tattoo"], []]])
	assert_eq(manager.notified, [r.id])
	assert_eq(care.exam_step(r.id, &"hands"), {}, "no second time")
	assert_eq(care.step_block_reason(r.id, &"hands"), "Schon untersucht.")
	care.exam_step(r.id, &"pockets")
	assert_eq(r.traits_revealed, [&"tattoo", &"valuables"] as Array[StringName])
	assert_eq(r.finds_revealed, [&"f_tattoo", &"f_valuables"] as Array[StringName])


func test_lost_finds_hide_their_trait_and_clue() -> void:
	var r := _record([&"strange_wound"], &"fever", 0.25)
	var res := care.exam_step(r.id, &"wounds")
	assert_eq(res.lost, [&"f_mark", &"f_cause_fever"])
	assert_eq(res.revealed, [])
	assert_eq(r.finds_lost, [&"f_mark", &"f_cause_fever"] as Array[StringName])
	assert_eq(r.traits_revealed.size(), 0, "a lost mark is not a revealed trait")
	assert_eq(journal.added, [], "no clue from a lost find")
	assert_eq(care.find_text(r.id, &"f_mark"), Phase4Fixtures.find(&"f_mark").lost_text, "lost card text")


func test_thorough_equals_single_steps() -> void:
	var a := _record([&"valuables", &"letter", &"tattoo", &"strange_wound"], &"drowned_millpond", 0.45, "a")
	var b := _record([&"valuables", &"letter", &"tattoo", &"strange_wound"], &"drowned_millpond", 0.45, "b")
	assert_eq(care.exam_all_minutes("a"), 45)
	var all := care.exam_all("a")
	assert_eq(all.steps, CorpseRecord.STEPS)
	for step: StringName in CorpseRecord.STEPS:
		care.exam_step("b", step)
	for field: String in ["exam_done", "finds_revealed", "finds_lost", "traits_revealed", "examined"]:
		assert_eq(a.get(field), b.get(field), field)
	assert_eq(all.revealed, b.finds_revealed)
	assert_eq(all.lost, [&"f_cause_drowned_millpond"] as Array[StringName], "fine traces gone at 0.45")
	assert_true(a.is_fully_examined())
	assert_eq(care.exam_all("a"), {}, "nothing open")
	assert_eq(care.exam_all_instant("a"), {})


func test_thorough_after_dressing_only_opens_the_allowed_steps() -> void:
	var r := _record([&"tattoo"])
	care.exam_step(r.id, &"clothing")
	r.dress = CorpseRecord.DRESS_GOWN
	assert_eq(care.open_steps(r.id), [&"hands", &"wounds"] as Array[StringName])
	assert_eq(care.exam_all_minutes(r.id), 25)
	care.exam_all_instant(r.id)
	assert_eq(r.exam_done, [&"clothing", &"hands", &"wounds"] as Array[StringName])
	assert_eq(care.step_block_reason(r.id, &"pockets"), "Nach dem Einkleiden nicht mehr zugänglich.")


func test_story_find_sets_its_flag() -> void:
	var r := _story_record(&"s2_hemmerling")
	care.exam_step(r.id, &"pockets")
	assert_eq(r.finds_revealed, [&"f_s2_key"] as Array[StringName])
	assert_true(GameState.has_flag(&"has_elder_key"))
	assert_eq(journal.added, [[&"c_elder_key", r.id]])
	# S3: the story mark stands in for the generic one and reveals strange_wound.
	var s3 := _story_record(&"s3_wernstein")
	care.exam_step(s3.id, &"wounds")
	assert_has(s3.finds_revealed, &"f_s3_mark")
	assert_false(s3.finds_revealed.has(&"f_mark"))
	assert_eq(s3.traits_revealed, [&"strange_wound"] as Array[StringName])


func test_nothing_noticeable_and_texts() -> void:
	var r := _record([&"letter"], &"fever")
	var res := care.exam_step(r.id, &"clothing")
	assert_eq([res.revealed, res.lost], [[], []], "nothing found")
	assert_eq(exam.nothing_text, "Nichts Auffälliges.")
	care.exam_step(r.id, &"pockets")
	var tables := load(FIXTURE_TABLES) as CorpseTables
	assert_eq(care.find_text(r.id, &"f_letter"), String(tables.get_trait(&"letter").reveal_text), "generic text = reveal_text")
	assert_eq(care.find_text(r.id, &"f_cause_fever"), Phase4Fixtures.find(&"f_cause_fever").text)


func test_care_refuses_unknown_and_buried_corpses() -> void:
	assert_eq(care.exam_step("nobody", &"clothing"), {})
	var r := _record()
	r.location = CorpseRecord.LOCATION_BURIED
	assert_ne(care.step_block_reason(r.id, &"clothing"), "")
	assert_eq(care.exam_step(r.id, &"clothing"), {})
	assert_false(r.examined)
	assert_eq(care.next_loss(r.id), {})


func test_care_next_loss_uses_pending_finds_only() -> void:
	TimeManager.set_time(1, 460)
	var r := _record([&"tattoo"], &"fever")
	r.arrival_total_minutes = TimeManager.total_minutes()
	var loss := care.next_loss(r.id)
	assert_eq(loss.find_id, &"f_cause_fever")
	care.exam_step(r.id, &"wounds")
	loss = care.next_loss(r.id)
	assert_eq(loss.find_id, &"f_tattoo", "resolved finds are not at risk any more")
	care.exam_step(r.id, &"hands")
	assert_eq(care.next_loss(r.id), {})


# --- data/finds ------------------------------------------------------------------------------

## data/finds holds the 28 finds of §2.2 with the fixture rules (texts may be polished); every
## find that can be lost has its own lost text.
func test_data_finds_match_the_contract() -> void:
	var real := Database.finds()
	assert_eq(real.size(), 28)
	for f: FindData in Phase4Fixtures.finds():
		var d := Database.find(f.id) as FindData
		assert_not_null(d, String(f.id))
		if d == null:
			continue
		for prop: String in ["step", "min_freshness", "trait_id", "cause_id", "story_only", "clue_id", "sets_flag"]:
			assert_eq(d.get(prop), f.get(prop), "%s.%s" % [f.id, prop])
		assert_true(d.label != "", "%s label" % f.id)
		if d.min_freshness > 0.0:
			assert_true(d.lost_text.length() >= 30, "%s lost text" % f.id)
		if d.story_only:
			assert_true(d.text != "", "%s text" % f.id)
