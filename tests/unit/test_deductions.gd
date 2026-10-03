extends TestCase
## P8 (docs/PHASE7_DESIGN.md §1.6, §2.6.5, §3.4, §10): DeductionRules and Systems/Deductions – the cards
## per dead person (finding cards, revealed finds, teachings), needs_any / needs_all, 2–3 cards and a
## cause → „Deuten"; wrong: no consequence, not counted, as often as one likes; right: once (clue,
## revealed_cause, stat, cause_deduced); d_still_heart → c_v_still_heart („Verbrennt es"); d_moor confirms
## the shown cause; the required story insight needs no specimen; save / load.

class ManagerDouble extends CorpseManager:
	func _ready() -> void:
		pass

	func put(r: CorpseRecord) -> void:
		_records[r.id] = r


class JournalDouble extends JournalManager:
	var clues: Array = []

	func _ready() -> void:
		pass

	func add_clue(id: StringName, corpse_id: String = "", _silent: bool = false) -> bool:
		clues.append([id, corpse_id])
		return true


var world: Node
var manager: ManagerDouble
var deductions: Deductions
var lectures: Lectures
var journal: JournalDouble
var deduced: Array = []


func before_each() -> void:
	GameState.reset()
	world = Node.new()
	world.name = "DeductionWorld"
	manager = ManagerDouble.new()
	world.add_child(manager)
	deductions = Deductions.new()
	deductions.deductions = Phase7Fixtures.deductions()
	world.add_child(deductions)
	lectures = Phase7Fixtures.lecture_night(3)
	world.add_child(lectures)
	journal = JournalDouble.new()
	world.add_child(journal)
	tree.root.add_child(world)
	deduced.clear()
	EventBus.cause_deduced.connect(_on_deduced)


func after_each() -> void:
	EventBus.cause_deduced.disconnect(_on_deduced)
	if is_instance_valid(world):
		world.free()
	GameState.reset()


func _on_deduced(corpse_id: String, cause: StringName) -> void:
	deduced.append([corpse_id, cause])


func _corpse(id: String, cause: StringName, hidden: StringName = &"", finds: Array[StringName] = []) -> CorpseRecord:
	var r := Phase4Fixtures.corpse([], cause)
	r.id = id
	r.hidden_cause = hidden
	r.finds_revealed = finds
	manager.put(r)
	return r


func _cards(list: Array) -> PackedStringArray:
	return PackedStringArray(list)


func test_matches_needs_any_and_needs_all() -> void:
	var arsenic := Phase7Fixtures.deduction(&"d_arsenic")
	assert_true(DeductionRules.matches(arsenic, _cards(["b_white_stomach", "l_stomach"]), &"arsenic"))
	assert_true(DeductionRules.matches(arsenic, _cards(["b_pale_liver", "l_stomach"]), &"arsenic"), "either finding")
	assert_true(DeductionRules.matches(arsenic, _cards(["b_pale_liver", "l_stomach", "l_lung"]), &"arsenic"), "more cards do not hurt")
	assert_false(DeductionRules.matches(arsenic, _cards(["l_stomach", "l_lung"]), &"arsenic"), "needs_any missing")
	assert_false(DeductionRules.matches(arsenic, _cards(["b_white_stomach", "b_pale_liver"]), &"arsenic"), "needs_all missing")
	assert_false(DeductionRules.matches(arsenic, _cards(["b_white_stomach", "l_stomach"]), &"poisoned"), "wrong cause")
	assert_false(DeductionRules.matches(null, _cards([]), &"arsenic"))
	var drink := Phase7Fixtures.deduction(&"d_drink")
	assert_true(DeductionRules.matches(drink, _cards(["b_hard_liver", "l_liver"]), &"drink"), "needs_any empty")
	assert_eq(DeductionRules.find(Phase7Fixtures.deductions(), _cards(["b_dry_lungs", "l_lung"]), &"dead_before_water").id, &"d_dry_lungs")
	assert_null(DeductionRules.find(Phase7Fixtures.deductions(), _cards(["b_dry_lungs", "l_lung"]), &"drowned_millpond"))


func test_cards_per_dead_person() -> void:
	_corpse("c_1", &"fever", &"arsenic", [&"f_cause_fever"] as Array[StringName])
	assert_false(deductions.can_deduce("c_1"), "no finding card yet")
	deductions.add_card("c_1", &"b_white_stomach")
	deductions.add_card("c_1", &"b_white_stomach")
	assert_true(deductions.can_deduce("c_1"))
	assert_eq(deductions.cards("c_1"), _cards(["b_white_stomach", "f_cause_fever", "l_lung", "l_liver"]),
			"findings + finds + teachings")
	assert_eq(deductions.cards("c_2"), _cards(["l_lung", "l_liver"]), "teachings for everybody")
	assert_false(deductions.can_deduce("c_2"))


func test_right_deduction_once_with_clue_cause_and_stat() -> void:
	var r := _corpse("c_1", &"fever", &"arsenic")
	deductions.add_card("c_1", &"b_white_stomach")
	lectures.learn(&"l_stomach")
	var res := deductions.deduce("c_1", _cards(["b_white_stomach", "l_stomach"]), &"arsenic")
	assert_eq([res.ok, res.cause, res.clue], [true, &"arsenic", &"c_v_arsenic"])
	assert_eq(r.revealed_cause, &"arsenic", "the death notice: gedeutet: Arsenik")
	assert_eq(journal.clues, [[&"c_v_arsenic", "c_1"]])
	assert_eq(GameState.get_stat(&"deductions"), 1)
	assert_eq(deduced, [["c_1", &"arsenic"]])
	assert_eq(deductions.deduced("c_1"), _cards(["d_arsenic"]))
	var again := deductions.deduce("c_1", _cards(["b_white_stomach", "l_stomach"]), &"arsenic")
	assert_true(again.ok and again.repeat)
	assert_eq([GameState.get_stat(&"deductions"), journal.clues.size(), deduced.size()], [1, 1, 1], "once")


func test_wrong_deduction_costs_nothing() -> void:
	var r := _corpse("c_1", &"fever", &"arsenic")
	deductions.add_card("c_1", &"b_white_stomach")
	lectures.learn(&"l_stomach")
	for i: int in 5:
		var res := deductions.deduce("c_1", _cards(["b_white_stomach", "l_stomach"]), &"fever")
		assert_eq([res.ok, res.text], [false, "Das passt nicht zusammen."])
	assert_eq(deductions.deduce("c_1", _cards(["b_white_stomach"]), &"arsenic").ok, false, "at least two cards")
	assert_eq(deductions.deduce("c_1", _cards(["b_white_stomach", "l_stomach", "l_lung", "l_liver"]), &"arsenic").ok, false,
			"at most three")
	assert_eq(deductions.deduce("c_1", _cards(["b_pale_liver", "l_stomach"]), &"arsenic").ok, false, "only own cards")
	assert_eq([r.revealed_cause, GameState.get_stat(&"deductions"), journal.clues, deduced], [&"", 0, [], []], "no trace")
	assert_eq(deductions.deduced("c_1"), PackedStringArray())


func test_still_heart_leads_to_burn_it() -> void:
	var r := _corpse("c_1", &"old_age", &"", [&"f_mark"] as Array[StringName])
	deductions.add_card("c_1", &"b_still_heart")
	assert_false(deductions.deduce("c_1", _cards(["b_still_heart", "l_heart", "f_mark"]), &"unexplained").ok, "l_heart unknown")
	lectures.learn(&"l_heart")
	var res := deductions.deduce("c_1", _cards(["b_still_heart", "l_heart", "f_mark"]), &"unexplained")
	assert_eq([res.ok, res.clue, r.revealed_cause], [true, &"c_v_still_heart", &"unexplained"])
	var burn := Phase7Fixtures.insight(&"i_burn_it")
	assert_has(burn.requires, &"c_v_still_heart", "„Verbrennt es\" = the deduced still heart + the warning letter")


func test_moor_confirms_the_shown_cause() -> void:
	var r := _corpse("c_1", &"drowned_millpond", &"", [&"f_cause_drowned_millpond"] as Array[StringName])
	deductions.add_card("c_1", &"b_moor_eyes")
	lectures.learn(&"l_eyes")
	var res := deductions.deduce("c_1", _cards(["b_moor_eyes", "l_eyes", "f_cause_drowned_millpond"]), &"drowned_millpond")
	assert_eq([res.ok, res.deduction, res.clue], [true, &"d_moor", &""], "the shown cause is accepted")
	assert_eq(r.revealed_cause, &"", "only confirmed, nothing revealed")
	var moor := _corpse("c_2", &"moor_cold", &"", [&"f_cause_moor_cold"] as Array[StringName])
	deductions.add_card("c_2", &"b_moor_eyes")
	assert_true(deductions.deduce("c_2", _cards(["b_moor_eyes", "l_eyes", "f_cause_moor_cold"]), &"moor_cold").ok)
	assert_eq(moor.revealed_cause, &"")
	assert_false(deductions.deduce("c_2", _cards(["b_moor_eyes", "l_eyes", "f_cause_moor_cold"]), &"fever").ok)


func test_dry_lungs_reveal_the_true_cause() -> void:
	var r := _corpse("c_1", &"drowned_millpond", &"dead_before_water")
	deductions.add_card("c_1", &"b_dry_lungs")
	var res := deductions.deduce("c_1", _cards(["b_dry_lungs", "l_lung"]), &"dead_before_water")
	assert_eq([res.ok, res.clue, r.revealed_cause], [true, &"c_v_dry_lungs", &"dead_before_water"])


func test_the_required_insight_needs_no_specimen() -> void:
	var anatomy_clues: Array = []
	for d: DeductionData in Phase7Fixtures.deductions():
		if d.clue_id != &"":
			anatomy_clues.append(d.clue_id)
	var deathbook := Phase7Fixtures.insight(&"i_deathbook")
	for c: StringName in deathbook.requires:
		assert_false(anatomy_clues.has(c), "i_deathbook needs no deduction: " + String(c))
	for d: DeductionData in Phase7Fixtures.deductions():
		var real := Database.deduction(d.id) as DeductionData
		assert_not_null(real, String(d.id))
		if real != null:
			assert_eq([real.cause_id, real.clue_id, real.reveals_cause], [d.cause_id, d.clue_id, d.reveals_cause], String(d.id))


func test_real_still_heart_also_for_hagedorn() -> void:
	# D1 Wiebke Hagedorn carries f_d1_mark instead of f_mark (§2.9): the data accept either.
	var real := Database.deduction(&"d_still_heart") as DeductionData
	assert_true(DeductionRules.matches(real, _cards(["b_still_heart", "l_heart", "f_mark"]), &"unexplained"))
	assert_true(DeductionRules.matches(real, _cards(["b_still_heart", "l_heart", "f_d1_mark"]), &"unexplained"))
	assert_false(DeductionRules.matches(real, _cards(["b_still_heart", "l_heart"]), &"unexplained"), "a mark is needed")


func test_cause_list() -> void:
	var list := DeductionRules.cause_list(Phase7Fixtures.corpse_tables())
	assert_eq(list.size(), 11, "seven causes + arsenic, dead_before_water, drink, unexplained")
	assert_eq(list.slice(7), [&"arsenic", &"dead_before_water", &"drink", &"unexplained"] as Array[StringName])


func test_save_load() -> void:
	_corpse("c_1", &"fever", &"arsenic")
	deductions.add_card("c_1", &"b_white_stomach")
	lectures.learn(&"l_stomach")
	deductions.deduce("c_1", _cards(["b_white_stomach", "l_stomach"]), &"arsenic")
	var state := deductions.save_state()
	assert_eq(state, {"cards": {"c_1": ["b_white_stomach"]}, "done": {"c_1": ["d_arsenic"]}})
	var back := Deductions.new()
	back.load_state(JSON.parse_string(JSON.stringify(state)) as Dictionary)
	assert_eq(back.save_state(), state)
	back.load_state({"cards": {"c_1": [1, "b_x", "b_x"]}, "done": "broken"})
	assert_eq(back.save_state(), {"cards": {"c_1": ["b_x"]}, "done": {}}, "tolerant")
	back.free()
	var fresh := Deductions.new()
	assert_eq(fresh.save_state(), {})
	fresh.free()
