extends TestCase
## P6 (docs/PHASE4_DESIGN.md §2.12, §3.4, §5.1, §10): JournalRules (exact linking, open
## questions, ready insights, piety tier) and JournalManager (clues with the counter of the dead
## and the flag clue_<id>, linking, renaming S5, the derived death notes, the quiet rebuild from
## the records, save / load, the UI context API) against the Phase-4 fixtures; the real journal
## data (data/journal/**) against the contract.


## CorpseManager double (group corpse_manager): records() + notify_changed log.
class FakeCorpses extends Node:
	var list: Array[CorpseRecord] = []
	var changed: Array[String] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return list

	func notify_changed(id: String) -> void:
		changed.append(id)


var notes: Array = []
var found: Array = []
var unlocked: Array = []


func before_each() -> void:
	notes.clear()
	found.clear()
	unlocked.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.clue_found.connect(_on_clue)
	EventBus.insight_unlocked.connect(_on_insight)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.clue_found.disconnect(_on_clue)
	EventBus.insight_unlocked.disconnect(_on_insight)


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_clue(id: StringName, corpse_id: String) -> void:
	found.append([id, corpse_id])


func _on_insight(id: StringName) -> void:
	unlocked.append(id)


# --- helpers ----------------------------------------------------------------------------------

func _journal() -> JournalManager:
	var j := JournalManager.new()
	j.clue_data = Phase4Fixtures.clues()
	j.insight_data = Phase4Fixtures.insights()
	j.find_data = Phase4Fixtures.finds()
	tree.root.add_child(j)
	return j


func _corpses(records: Array[CorpseRecord] = []) -> FakeCorpses:
	var c := FakeCorpses.new()
	c.list = records
	tree.root.add_child(c)
	return c


func _rec(id: String, finds: Array[StringName], arrival: int = 460, story: StringName = &"") -> CorpseRecord:
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, arrival)
	r.id = id
	r.display_name = "Tote " + id
	r.finds_revealed = finds
	r.story_id = story
	return r


func _ids(list: Array[InsightData]) -> Array[StringName]:
	var out: Array[StringName] = []
	for i: InsightData in list:
		out.append(i.id)
	return out


func _found(ids: Array) -> Dictionary:
	var out := {}
	for id: Variant in ids:
		out[id] = true
	return out


func _add_all(j: JournalManager, ids: Array[StringName]) -> void:
	for id: StringName in ids:
		j.add_clue(id)


# --- JournalRules -----------------------------------------------------------------------------

func test_match_insight_needs_the_exact_set() -> void:
	var all := Phase4Fixtures.insights()
	assert_eq(JournalRules.match_insight([&"c_warning_letter", &"c_page_1"], all, {}), &"i_warnings")
	assert_eq(JournalRules.match_insight([&"c_page_1", &"c_warning_letter"], all, {}), &"i_warnings", "order irrelevant")
	assert_eq(JournalRules.match_insight([&"c_page_1", &"c_mark_healed", &"c_mark"], all, {}), &"i_marked", "three clues")
	assert_eq(JournalRules.match_insight([&"c_warning_letter", &"c_page_1", &"c_mark"], all, {}), &"", "superset ✗")
	assert_eq(JournalRules.match_insight([&"c_page_1"], all, {}), &"", "subset ✗")
	assert_eq(JournalRules.match_insight([&"c_page_1", &"c_page_1"], all, {}), &"", "duplicates ✗")
	assert_eq(JournalRules.match_insight([], all, {}), &"")
	assert_eq(JournalRules.match_insight([&"c_warning_letter", &"c_page_1"], all, {&"i_warnings": 4}), &"", "already linked")
	assert_eq(JournalRules.match_insight([&"c_warning_letter", &"c_page_1"], all, {"i_warnings": 4}), &"", "String keys too")
	assert_eq(JournalRules.match_insight([&"c_letter_late", &"c_page_1"], all, {}), &"i_still_writing",
			"c_page_1 serves three insights")


func test_open_questions_from_one_found_clue() -> void:
	var all := Phase4Fixtures.insights()
	assert_eq(JournalRules.open_questions({}, all, {}), [] as Array[InsightData])
	assert_eq(_ids(JournalRules.open_questions(_found([&"c_page_1"]), all, {})), [&"i_warnings", &"i_marked", &"i_still_writing"] as Array[StringName])
	assert_eq(_ids(JournalRules.open_questions(_found([&"c_page_1"]), all, {&"i_marked": 1})), [&"i_warnings", &"i_still_writing"] as Array[StringName])
	assert_eq(_ids(JournalRules.open_questions(_found([&"c_elder_key"]), all, {})), [&"i_kranich"] as Array[StringName], "optional too")


func test_ready_insights_need_every_clue() -> void:
	var all := Phase4Fixtures.insights()
	assert_eq(_ids(JournalRules.ready_insights(_found([&"c_mark", &"c_page_1"]), all, {})), [] as Array[StringName])
	var f := _found([&"c_mark", &"c_page_1", &"c_mark_healed", &"c_warning_letter"])
	assert_eq(_ids(JournalRules.ready_insights(f, all, {})), [&"i_warnings", &"i_marked"] as Array[StringName])
	assert_eq(_ids(JournalRules.ready_insights(f, all, {&"i_warnings": 5})), [&"i_marked"] as Array[StringName])


func test_piety_tier_rule() -> void:
	var cfg := Phase4Fixtures.piety_config()
	var table := {-100: &"hardhearted", -60: &"hardhearted", -59: &"callous", -20: &"callous", -19: &"matter_of_fact",
			19: &"matter_of_fact", 20: &"considerate", 59: &"considerate", 60: &"devout", 100: &"devout"}
	for value: int in table:
		assert_eq(JournalRules.piety_tier(value, cfg), table[value], "piety %d" % value)
		assert_eq(JournalRules.piety_tier(value), table[value], "defaults %d" % value)
	assert_eq(JournalRules.PIETY_TIERS, PietyRules.TIERS, "same ids as PietyRules")


# --- clues ------------------------------------------------------------------------------------

func test_add_clue_first_time() -> void:
	var j := _journal()
	TimeManager.day = 3
	assert_true(j.add_clue(&"c_mark", "corpse_0003"))
	assert_true(j.has_clue(&"c_mark"))
	assert_true(GameState.get_flag(&"clue_c_mark"), "flag clue_<id> for dialogue conditions")
	assert_eq(j.clue_count(&"c_mark"), 1)
	assert_eq(j.clue_day(&"c_mark"), 3)
	assert_eq(j.unread(), [&"c_mark"] as Array[StringName])
	assert_eq(found, [[&"c_mark", "corpse_0003"]])
	assert_eq(notes, [["Ins Merkbuch: Das Dreistrich-Zeichen", &"info"]])


func test_add_clue_again_only_counts_new_dead() -> void:
	var j := _journal()
	j.add_clue(&"c_mark", "corpse_0003")
	assert_false(j.add_clue(&"c_mark", "corpse_0003"), "already there")
	assert_eq(j.clue_count(&"c_mark"), 1, "the same dead is not counted twice")
	assert_false(j.add_clue(&"c_mark", "corpse_0007"))
	assert_eq(j.clue_count(&"c_mark"), 2, "(2 Tote)")
	assert_false(j.add_clue(&"c_mark"))
	assert_eq(j.clue_count(&"c_mark"), 2, "no corpse → no count")
	assert_eq(found.size(), 1, "clue_found only the first time")
	assert_eq(notes.size(), 1)
	assert_eq(j.clues(), [&"c_mark"] as Array[StringName])


func test_add_clue_silent_and_unknown() -> void:
	var j := _journal()
	assert_true(j.add_clue(&"c_warning_letter", "corpse_0004", true))
	assert_true(GameState.has_flag(&"clue_c_warning_letter"), "silent still sets the flag")
	assert_eq([found, notes, j.unread()], [[], [], [] as Array[StringName]], "silent: no signal, note, unread mark")
	assert_false(j.add_clue(&"c_nope", "x"))
	assert_false(j.has_clue(&"c_nope"))
	assert_false(GameState.has_flag(&"clue_c_nope"))


func test_talk_clue_counts_no_dead() -> void:
	var j := _journal()
	j.add_clue(&"c_trader_lorenz")
	assert_eq(j.clue_count(&"c_trader_lorenz"), 0)
	assert_eq(j.clue_cards()[0].kind, &"talk")


func test_clues_in_data_order() -> void:
	var j := _journal()
	_add_all(j, [&"c_page_list", &"c_mark", &"c_trader_note", &"c_page_1"])
	assert_eq(j.clues(), [&"c_mark", &"c_page_1", &"c_page_list", &"c_trader_note"] as Array[StringName])


# --- linking ----------------------------------------------------------------------------------

func test_try_link_exact_set_in_any_order() -> void:
	var j := _journal()
	TimeManager.day = 7
	_add_all(j, [&"c_warning_letter", &"c_page_1", &"c_mark"])
	notes.clear()
	assert_eq(j.try_link([&"c_page_1", &"c_warning_letter"]), &"i_warnings", "wrong order ✓")
	assert_true(j.has_insight(&"i_warnings"))
	assert_eq(j.insights(), [&"i_warnings"] as Array[StringName])
	assert_true(GameState.get_flag(&"insight_warnings"), "flag for Osric's dialogue")
	assert_eq(unlocked, [&"i_warnings"])
	assert_eq(notes, [["Erkenntnis: Wer die Warnbriefe schrieb", &"reward"]])
	assert_true(j.is_unread(&"i_warnings"))
	assert_eq(j.insight_pages()[0].day, 7)
	assert_eq(j.try_link([&"c_page_1", &"c_warning_letter"]), &"", "only once")
	assert_eq(unlocked.size(), 1)


func test_try_link_wrong_costs_nothing() -> void:
	var j := _journal()
	_add_all(j, [&"c_warning_letter", &"c_page_1", &"c_mark"])
	var before := j.save_state()
	var flags := GameState.flags.duplicate()
	notes.clear()
	assert_eq(j.try_link([&"c_warning_letter", &"c_page_1", &"c_mark"]), &"", "superset ✗")
	assert_eq(j.try_link([&"c_mark", &"c_warning_letter"]), &"", "no story")
	assert_eq(j.try_link([&"c_page_1"]), &"")
	assert_eq(j.try_link([]), &"")
	assert_eq(j.save_state(), before, "not counted, nothing changed")
	assert_eq(GameState.flags, flags)
	assert_eq([notes, unlocked], [[], []])
	assert_ne(JournalManager.LINK_FAIL_TEXT, "", "the panel shows the fail text")


func test_try_link_needs_found_clues() -> void:
	var j := _journal()
	j.add_clue(&"c_warning_letter")
	assert_eq(j.try_link([&"c_warning_letter", &"c_page_1"]), &"", "c_page_1 not found yet")


func test_not_lorenz_renames_s5() -> void:
	var s5 := _rec("corpse_0019", [&"f_s5_coat", &"f_s5_buckle", &"f_s5_hands", &"f_s5_list"], 26380, &"s5_moor")
	s5.display_name = "Lorenz Aschau (?)"
	var other := _rec("corpse_0018", [], 25000)
	var corpses := _corpses([s5, other])
	var j := _journal()
	assert_eq(j.people()[0].name, "Lorenz Aschau (?)", "before the insight")
	_add_all(j, [&"c_soft_hands", &"c_buckle", &"c_page_list"])
	assert_eq(j.try_link([&"c_page_list", &"c_soft_hands", &"c_buckle"]), &"i_not_lorenz")
	assert_eq(s5.display_name, "Kaspar Dorn", "record renamed (§2.11 step 6)")
	assert_eq(corpses.changed, ["corpse_0019"], "through CorpseManager.notify_changed")
	assert_eq(other.display_name, "Tote corpse_0018")
	assert_true(GameState.get_flag(&"insight_not_lorenz"))
	assert_eq(j.people()[0].name, "Kaspar Dorn")


func test_open_and_ready_through_the_manager() -> void:
	var j := _journal()
	assert_eq(j.open_question_cards(), [] as Array[Dictionary])
	j.add_clue(&"c_page_1")
	var cards := j.open_question_cards()
	assert_eq(cards.size(), 3)
	assert_eq(cards[0], {"id": &"i_warnings", "question": "Wer warnt die Toten?", "found": 1, "needed": 2, "optional": false})
	assert_eq(j.ready_insights(), [] as Array[InsightData])
	j.add_clue(&"c_warning_letter")
	assert_eq(_ids(j.ready_insights()), [&"i_warnings"] as Array[StringName], "objective line")
	j.try_link([&"c_warning_letter", &"c_page_1"])
	assert_eq(j.ready_insights(), [] as Array[InsightData])
	assert_eq(j.open_question_cards().size(), 2)


# --- the dead (derived) -----------------------------------------------------------------------

func test_people_are_derived_newest_first() -> void:
	var a := _rec("corpse_0001", [&"f_cause_fever"], 460)
	a.age = 44
	a.grave_id = "plot_01"
	a.dress = &"gown"
	a.washed = true
	a.laid_out = true
	var b := _rec("corpse_0002", [&"f_letter"], 1900)
	b.finds_lost = [&"f_mark"]
	b.harvested = [&"hair"]
	_corpses([a, b])
	var j := _journal()
	var people := j.people()
	assert_eq(people.size(), 2)
	assert_eq(people[0].corpse_id, "corpse_0002", "newest first")
	assert_eq(people[0].day, 2)
	assert_eq(people[1].day, 1)
	assert_eq(people[1].age, 44)
	assert_eq([people[1].washed, people[1].dress, people[1].laid_out, people[1].grave_id], [true, &"gown", true, "plot_01"])
	assert_eq(people[1].finds[0].text, Phase4Fixtures.find(&"f_cause_fever").text)
	assert_eq(people[0].finds[0].clue, &"c_warning_letter")
	assert_eq(people[0].lost[0].text, Phase4Fixtures.find(&"f_mark").lost_text, "lost find with its lost text")
	assert_eq(people[0].harvested, [&"hair"] as Array[StringName])
	assert_eq(people[1].heard, "")
	EventBus.ghost_spoke.emit("plot_01", &"content", "Es ist warm hier unten.")
	assert_eq(j.people()[1].heard, "Es ist warm hier unten.", "heard line on the death note")
	assert_true(j.people()[1].heard_any)
	assert_eq(j.save_state().clues, {}, "people are not saved")


func test_people_without_corpse_manager() -> void:
	assert_eq(_journal().people(), [] as Array[Dictionary])


# --- sync / save ------------------------------------------------------------------------------

func test_sync_from_records_is_quiet_and_idempotent() -> void:
	var records: Array[CorpseRecord] = [
		_rec("corpse_0003", [&"f_mark", &"f_cause_fever"], 3340),
		_rec("corpse_0004", [&"f_cause_fever", &"f_valuables", &"f_letter"], 4800),
		_rec("corpse_0010", [&"f_tattoo", &"f_mark"], 13400),
	]
	_corpses(records)
	var j := _journal()
	assert_eq(j.sync_from_records(), 3)
	assert_eq(j.clues(), [&"c_mark", &"c_warning_letter", &"c_anchor_snake"] as Array[StringName])
	assert_eq([j.clue_count(&"c_mark"), j.clue_count(&"c_warning_letter"), j.clue_count(&"c_anchor_snake")], [2, 1, 1])
	assert_eq(j.clue_day(&"c_mark"), 3, "day of the first record")
	assert_eq([found, notes, j.unread()], [[], [], [] as Array[StringName]], "quiet")
	for id: StringName in j.clues():
		assert_true(GameState.has_flag(StringName("clue_" + String(id))))
	var state := j.save_state()
	assert_eq(j.sync_from_records(), 0, "idempotent")
	assert_eq(j.save_state(), state)


func test_sync_counts_a_live_clue_once() -> void:
	var r := _rec("corpse_0003", [&"f_mark"], 3340)
	_corpses([r])
	var j := _journal()
	j.add_clue(&"c_mark", "corpse_0003")
	j.sync_from_records()
	assert_eq(j.clue_count(&"c_mark"), 1, "CorpseCare + sync of the same corpse")


func test_save_load_round_trip() -> void:
	var j := _journal()
	TimeManager.day = 6
	_add_all(j, [&"c_warning_letter", &"c_page_1"])
	j.add_clue(&"c_mark", "corpse_0003")
	j.add_clue(&"c_mark", "corpse_0005")
	j.try_link([&"c_warning_letter", &"c_page_1"])
	j.mark_read([&"c_page_1"])
	var state := j.save_state()
	assert_eq(state.clues["c_mark"], {"day": 6, "corpse": "corpse_0003", "count": 2}, "§5.1 format")
	assert_eq(state.insights, {"i_warnings": 6})
	assert_eq(state.unread, ["c_warning_letter", "c_mark", "i_warnings"])
	var text := JSON.stringify(JSON.from_native(state))
	var k := _journal()
	k.load_state(JSON.to_native(JSON.parse_string(text)))
	assert_eq(k.save_state(), state, "round trip through JSON")
	assert_eq(k.clue_count(&"c_mark"), 2)
	assert_true(k.has_insight(&"i_warnings"))
	assert_eq(k.unread_count(), 3)
	k.add_clue(&"c_mark", "corpse_0003")
	assert_eq(k.clue_count(&"c_mark"), 2, "the saved first corpse is remembered")


func test_post_load_keeps_the_saved_count() -> void:
	var records: Array[CorpseRecord] = [_rec("corpse_0003", [&"f_mark"]), _rec("corpse_0005", [&"f_mark"]), _rec("corpse_0009", [&"f_mark"])]
	_corpses(records)
	var j := _journal()
	j.load_state({"clues": {"c_mark": {"day": 3, "corpse": "corpse_0003", "count": 3}}, "insights": {}, "unread": []})
	j.post_load()
	assert_eq(j.clue_count(&"c_mark"), 3, "records already counted in the save are not added again")
	records.append(_rec("corpse_0012", [&"f_mark"]))
	j.post_load()
	assert_eq(j.clue_count(&"c_mark"), 4)


func test_load_is_tolerant() -> void:
	var j := _journal()
	j.load_state({})
	assert_eq(j.save_state(), {"clues": {}, "insights": {}, "unread": []})
	j.load_state({"clues": {"c_mark": "kaputt", "c_page_1": {"day": "x", "count": -3}}, "insights": [1], "unread": ["c_page_1", 7, "c_nope"]})
	assert_eq(j.clues(), [&"c_page_1"] as Array[StringName], "damaged entry skipped")
	assert_eq(j.clue_count(&"c_page_1"), 0)
	assert_eq(j.unread(), [&"c_page_1"] as Array[StringName], "unread only for known entries")
	j.load_state({"clues": [], "insights": {"i_warnings": 4.0}, "unread": "x"})
	assert_eq(j.insights(), [&"i_warnings"] as Array[StringName])


func test_load_replaces_everything() -> void:
	var j := _journal()
	j.add_clue(&"c_mark")
	j.load_state({"clues": {}, "insights": {}, "unread": []})
	assert_false(j.has_clue(&"c_mark"))
	assert_eq(j.unread(), [] as Array[StringName])


# --- UI context -------------------------------------------------------------------------------

func test_panel_context_and_pages() -> void:
	var j := _journal()
	assert_eq(j.panel_context(), {"page": &"people", "journal": j})
	assert_eq(j.panel_context(&"clues").page, &"clues")
	assert_eq(j.panel_context(&"nonsense").page, &"people")
	assert_eq(JournalManager.PAGES, [&"people", &"clues", &"insights", &"self"] as Array[StringName])
	j.add_clue(&"c_mark", "corpse_0003")
	var card: Dictionary = j.clue_cards()[0]
	assert_eq([card.id, card.title, card.kind, card.count, card.unread], [&"c_mark", "Das Dreistrich-Zeichen", &"mark", 1, true])
	j.mark_read([&"c_mark"])
	assert_false(j.clue_cards()[0].unread)
	assert_eq(j.unread_count(), 0)


func test_self_page_has_no_number() -> void:
	var j := _journal()
	j.piety_config = Phase4Fixtures.piety_config()
	GameState.stats[&"piety"] = 64
	GameState.stats[&"prepared"] = 9
	GameState.stats[&"utilized"] = 2
	var page := j.self_page()
	assert_eq(page.tier, &"devout")
	assert_eq(page.label, "Andächtig")
	assert_eq([page.prepared, page.utilized, page.insights, page.insights_total], [9, 2, 0, 5])
	assert_false(page.has("piety"), "the value itself is never shown (§7)")
	GameState.stats[&"piety"] = -70
	assert_eq(j.self_page().label, "Hartherzig")


# --- real data (data/journal/**) --------------------------------------------------------------

func test_real_clues_match_the_contract() -> void:
	# Phase 6 (P3): c_crypt_draft is checked in test_ossuary.gd.
	var clues: Array = Database.clues().filter(func(c: ClueData) -> bool: return c.id != &"c_crypt_draft")
	assert_eq(clues.size(), 18, "18 clues (§2.12)")
	var ids: Array[StringName] = []
	for c: ClueData in clues:
		ids.append(c.id)
		var fixture := Phase4Fixtures.clue(c.id)
		assert_not_null(fixture, String(c.id))
		if fixture == null:
			continue
		assert_eq([c.kind, c.order], [fixture.kind, fixture.order], String(c.id))
		assert_true(c.kind in ClueData.KINDS, String(c.id))
		assert_true(c.title.length() > 3 and c.text.length() >= 40, "%s has a real text" % c.id)
		assert_false(c.text.contains("TODO") or c.text.contains("<"), String(c.id))
	assert_eq(ids, Phase4Fixtures.CLUE_IDS, "data order = contract order")
	for id: StringName in [&"c_trader_note", &"c_trader_lorenz", &"c_trader_marked"]:
		assert_eq((Database.clue(id) as ClueData).text, Phase4Fixtures.clue(id).text, "%s: Ilse's words (§2.6)" % id)
	assert_true((Database.clue(&"c_page_list") as ClueData).text.contains("Unter dem Birkenhang ist es nicht still."))


func test_real_insights_match_the_contract() -> void:
	var insights: Array = Database.insights()
	assert_eq(insights.size(), 6, "5 + 1 optional")
	var optional := 0
	for i: InsightData in insights:
		var fixture := Phase4Fixtures.insight(i.id)
		assert_not_null(fixture, String(i.id))
		if fixture == null:
			continue
		var a := i.requires.duplicate()
		var b := fixture.requires.duplicate()
		a.sort()
		b.sort()
		assert_eq(a, b, "%s requires" % i.id)
		assert_true(i.requires.size() >= 2 and i.requires.size() <= 3)
		for id: StringName in i.requires:
			assert_not_null(Database.clue(id), "%s → %s" % [i.id, id])
		assert_eq([i.sets_flag, i.optional, i.rename_story, i.rename_to, i.title, i.question],
				[fixture.sets_flag, fixture.optional, fixture.rename_story, fixture.rename_to, fixture.title, fixture.question], String(i.id))
		assert_true(i.text.length() >= 60, String(i.id))
		if i.optional:
			optional += 1
	assert_eq(optional, 1, "i_kranich")
	var nl := Database.insight(&"i_not_lorenz") as InsightData
	assert_true(nl.text.contains("Kaspar Dorn") and nl.text.contains("Er lebt"), "finale: Nicht Lorenz – er lebt (§14.4)")


func test_every_clue_has_a_source() -> void:
	# From a find (fixture finds), from the elder section, or from Ilse (note at the door, dialogue).
	var from_finds := {}
	for f: FindData in Phase4Fixtures.finds():
		if f.clue_id != &"":
			from_finds[f.clue_id] = true
	var trader := load("res://data/dialogue/trader.tres") as DialogueData
	var from_dialogue := {}
	for n: DialogueNode in trader.nodes:
		for a: String in n.actions:
			if a.begins_with("add_clue:"):
				from_dialogue[StringName(a.get_slice(":", 1))] = true
	for id: StringName in Phase4Fixtures.CLUE_IDS:
		var ok := from_finds.has(id) or from_dialogue.has(id) or id in [&"c_six_pits", &"c_trader_note"]
		assert_true(ok, "%s can be found" % id)
	assert_true(from_dialogue.has(&"c_trader_lorenz") and from_dialogue.has(&"c_trader_marked"))


func test_real_data_links_every_insight() -> void:
	var j := JournalManager.new()
	tree.root.add_child(j)
	for c: ClueData in Database.clues():
		j.add_clue(c.id)
	var linked: Array[StringName] = []
	for i: InsightData in Database.insights():
		linked.append(j.try_link(i.requires))
	assert_eq(linked, [&"i_warnings", &"i_marked", &"i_ferry", &"i_still_writing", &"i_not_lorenz", &"i_kranich"] as Array[StringName])
	assert_eq(j.self_page().insights_total, 5)
