extends TestCase
## P5 (docs/PHASE9_DESIGN.md §2.5, §10): the gentleman with the case in the real world from the Phase-8 end states
## (v7 fixtures) – three runs over his two visits: Fenner (questions, the bribe refused, the case to Fenner),
## Handel with the ledger (anatomist8: a specimen at Quast's price × 1.5, the ledger after the main chain for 40,
## piety −8, no card), Ilse; the Lambert variants of K3 through slot_p8_day63_letgo. The Stranger node is added here
## (W-Welt hangs it into the world in W2); the chain's choice actions come from the q_case fixture (P1 delivers
## data/quests).

const TIMEOUT := 300.0
var TEST_SAVES := TestCase.user_dir("test_stranger_chain")
const SLOT := 7
const OPEN_DAY := 63

var stranger: Stranger
var events: Array = []


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	events.clear()
	EventBus.stranger_event.connect(_on_event)


func after_each() -> void:
	EventBus.stranger_event.disconnect(_on_event)
	UIState.clear()
	TestCase.remove_user_dir(TEST_SAVES)


func _start(fixture: String, main_ending: StringName = &"") -> void:
	assert_eq(Phase9Fixtures.install_save_v7(fixture, TEST_SAVES, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, fixture + " loads")
	TimeManager.running = false
	GameState.set_flag(&"p9_open", true)
	GameState.set_flag(&"p9_open_day", OPEN_DAY)
	var systems := _world().get_node("Systems")
	_without_world_phase9(systems)
	if main_ending != &"":
		var q := Phase9Fixtures.ending(main_ending)
		systems.add_child(q)
	stranger = Stranger.new()
	stranger.name = "Stranger"
	stranger.quest_data = Phase9Fixtures.quest(&"q_case")
	systems.add_child(stranger)


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _inv() -> Inventory:
	return _world().get_player().inventory


func _rel() -> Relationships:
	return tree.get_first_node_in_group(&"relationships") as Relationships


func _piety() -> int:
	return GameState.get_stat(&"piety")


## Time passes the way the game passes it: the systems hear time_tick.
func _at(day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	await wait_frames(1)


func test_fenner_over_two_visits() -> void:
	await _start("slot_p8_day63_kindly")
	await _at(64, 900)
	assert_false(stranger.here(), "not before p9_open_day + 2")
	await _at(65, 860)
	assert_true(stranger.present(&"graveyard"), "outside the gate")
	assert_eq(events.slice(0, 2), [[&"arrived", "village"], [&"arrived", "gate"]])
	assert_eq(stranger.question(), "Wie tief graben Sie im Frost?")
	var coins := _inv().count(&"coin")
	stranger.answer(&"frank")
	assert_eq(_inv().count(&"coin"), coins + 1)
	assert_false(stranger.offers(_inv()).is_empty(), "K2: what he wants to buy")
	await _at(70, 860)
	assert_eq(stranger.visit_now(), 2)
	var piety := _piety()
	stranger.bribe(false, _inv())
	assert_eq([stranger.bribe_state(), _piety()], [&"refused", piety])
	var journal := tree.get_first_node_in_group(&"journal")
	if journal.call(&"clue_by_id", &"c_q_case_lorenz") != null:
		assert_true(journal.call(&"has_clue", &"c_q_case_lorenz"), "K3: he admits it (data/journal/clues – P6)")
	await _at(71, 600)
	assert_eq(stranger.case_holder(), &"inn")
	assert_true(stranger.take_case(_inv()))
	assert_true(stranger.give_case(&"fenner", _inv()))
	var rel := _rel()
	rel.meet(&"mayor")
	rel.meet(&"surgeon")
	var fenner := rel.value(&"mayor")
	var quast := rel.value(&"surgeon")
	var rep := GameState.get_stat(&"reputation")
	assert_eq(stranger.resolve_block_reason(&"fenner"), "")
	stranger.resolve(&"fenner")
	assert_true(stranger.gone() and GameState.flag_on(&"case_end_fenner"))
	assert_eq([rel.value(&"mayor") - fenner, rel.value(&"surgeon") - quast], [mini(4, 100 - fenner), maxi(-6, -quast)],
			"Fenner +4, Quast −6")
	assert_eq(GameState.get_stat(&"reputation") - rep, mini(3, 100 - rep), "Ruf +3 (capped at 100)")
	await _at(75, 860)
	assert_false(stranger.here(), "he never comes again")
	assert_eq(stranger.offers(_inv()), [] as Array[Dictionary])


func test_deal_with_the_ledger_from_the_anatomist() -> void:
	await _start("slot_p8_day63_anatomist", &"away")
	await _at(65, 860)
	assert_true(GameState.flag_on(&"anatomy_known"))
	var specimens := tree.get_first_node_in_group(&"specimens") as Specimens
	var uid := ""
	for u: String in specimens.held():
		if _inv().has_uid(u) and specimens.sell_block_reason(u, _inv()) == "":
			uid = u
			break
	if uid != "":
		var quast := specimens.sale_price(uid)
		var coins := _inv().count(&"coin")
		var offer: Array = stranger.offers(_inv()).filter(func(d: Dictionary) -> bool: return d.id == &"so_specimen")
		assert_eq(offer[0].price, roundi(quast * 1.5), "Quast's price × 1.5")
		assert_true(stranger.sell(&"so_specimen", _inv()))
		assert_eq(_inv().count(&"coin") - coins, roundi(quast * 1.5))
	if not _inv().has(&"lorenz_ledger_2"):
		_inv().add_item(&"lorenz_ledger_2", 1)
	await _at(72, 860)
	var ids: Array = stranger.offers(_inv()).map(func(d: Dictionary) -> StringName: return d.id)
	assert_true(ids.has(&"so_kladde"), "the ledger after the main chain")
	var piety := _piety()
	var coins := _inv().count(&"coin")
	assert_true(stranger.sell(&"so_kladde", _inv()))
	assert_eq([_inv().count(&"coin") - coins, _piety() - piety, GameState.flag_on(&"kladde_sold")], [40, maxi(-8, -100 - piety), true])
	stranger.resolve(&"deal")
	assert_eq([stranger.ending(), _inv().count(&"case_card"), GameState.flag_on(&"case_end_deal")], [&"deal", 0, true],
			"sold the ledger: no card")


func test_ilse() -> void:
	await _start("slot_p8_day63_kindly")
	GameState.set_flag(&"trader_known", true)
	await _at(72, 860)
	var piety := _piety()
	stranger.resolve(&"ilse")
	assert_eq([stranger.ending(), _piety() - piety, GameState.flag_on(&"case_end_ilse")], [&"ilse", mini(2, 100 - piety), true])
	assert_eq(events.back(), [&"left", "ilse"])
	await _at(73, 860)
	assert_false(stranger.here(), "gone in the morning")


func test_lambert_variants() -> void:
	await _start("slot_p8_day63_letgo")
	assert_true(stranger.recognized(), "c_n_robber: you know who he is")
	assert_eq(stranger.k3_variant(), &"let_go", "Lambert greets through Veit")
	assert_true(LetterRules.pool_ok((Database.letter(&"lg_lambert") as LetterData).conditions, tree), "lg_lambert in the pool")


func test_kindly_does_not_know_him_yet() -> void:
	await _start("slot_p8_day63_kindly")
	var robber := tree.get_first_node_in_group(&"night_robber")
	var fate := StringName(str(robber.call(&"fate"))) if robber != null else &""
	assert_eq(stranger.k3_variant(), fate if fate in [&"let_go", &"reported"] else &"")
	var journal := tree.get_first_node_in_group(&"journal")
	assert_eq(stranger.recognized(), bool(journal.call(&"has_clue", &"c_n_robber")))
	GameState.set_flag(&"q_confide_surgeon", true)
	assert_true(stranger.recognized(), "Quast told you (H5)")


func _on_event(kind: StringName, detail: String) -> void:
	events.append([kind, detail])


## W2 (W-Welt): the world carries the four Phase-9 systems now – this test brings its own (as in W1), so the world's are
## taken out first (the world as the test was written against).
static func _without_world_phase9(systems: Node) -> void:
	for n: String in ["Quests", "WhoKnows", "Letters", "Stranger"]:
		var node := systems.get_node_or_null(n)
		if node != null:
			systems.remove_child(node)
			node.free()
