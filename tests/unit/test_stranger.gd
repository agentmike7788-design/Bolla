extends TestCase
## P5 (docs/PHASE9_DESIGN.md §2.5, §3.3, §3.4, §5.1, §10): Stranger – Cornelius Brenneisen's visits (p9_open_day + 2,
## every 5 days for 3 days, the gate bell once), never inside the cemetery, the questions (coin, piety once), the
## offers with their conditions (soil only from a fresh grave, the register extract with the talk two days later,
## specimens × 1.5), the bribe, the case (holder, looking inside, Fenner), the three endings with their consequences,
## the ledger only after the main chain (40, piety −8), no appearance after the end, save / load.

const OPEN_DAY := 63


class QuestsDouble extends Node:
	var notes_list: Array = []
	var chosen: Array = []
	var accept_choice: bool = false
	var main_ending: StringName = &""

	func _init() -> void:
		add_to_group(&"quests")

	func note(key: StringName, arg: String) -> void:
		notes_list.append([key, arg])

	func choose(q: StringName, s: StringName, c: StringName) -> bool:
		chosen.append([q, s, c])
		return accept_choice

	func ending(q: StringName) -> StringName:
		return main_ending if q == &"q_who_knows" else &""


class PietyDouble extends Node:
	var total: int = 0
	var events_cfg: Dictionary = {}

	func _init() -> void:
		add_to_group(&"piety")

	func event(kind: StringName, _reason: String) -> void:
		total += int(events_cfg.get(kind, 0))

	func change(delta: int, _reason: String) -> void:
		total += delta


class RepDouble extends Node:
	var events: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"reputation")

	func event(kind: StringName, _reason: String) -> void:
		events.append(kind)


class JournalDouble extends Node:
	var clues: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		return true

	func has_clue(id: StringName) -> bool:
		return clues.has(id)


class LifeDouble extends Node:
	var events: Array = []

	func _init() -> void:
		add_to_group(&"npc_life")

	func note_event(event: StringName, npcs: Array[StringName] = []) -> void:
		events.append([event, npcs])


class GraveyardDouble extends Node:
	var list: Array[GraveRecord] = []

	func _init() -> void:
		add_to_group(&"graveyard")

	func graves() -> Array[GraveRecord]:
		return list

	func get_grave(id: String) -> GraveRecord:
		for g: GraveRecord in list:
			if g.id == id:
				return g
		return null


class CorpseDouble extends Node:
	var list: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in list:
			if r.id == id:
				return r
		return null


class SpecimensDouble extends Node:
	var sold: Array[String] = []
	var quast_price: int = 6

	func _init() -> void:
		add_to_group(&"specimens")

	func held() -> PackedStringArray:
		return PackedStringArray(["sp_0001"]) if not sold.has("sp_0001") else PackedStringArray()

	func sell_block_reason(uid: String, inv: Inventory) -> String:
		return "" if inv.has_uid(uid) else "gone"

	func sale_price(_uid: String) -> int:
		return quast_price

	func sell(uid: String, inv: Inventory) -> int:
		inv.remove_uid(uid)
		inv.add_item(&"coin", quast_price)
		sold.append(uid)
		return quast_price


class OrdersDouble extends Node:
	var completed: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"orders")

	func state(_id: StringName) -> StringName:
		return &"accepted"

	func complete(id: StringName) -> void:
		completed.append(id)


class PlayerInv extends Node:
	var inventory: Inventory

	func _init() -> void:
		add_to_group(&"player")


var world: Node
var stranger: Stranger
var quests: QuestsDouble
var piety: PietyDouble
var rep: RepDouble
var rel: Relationships
var journal: JournalDouble
var life: LifeDouble
var graveyard: GraveyardDouble
var corpses: CorpseDouble
var specimens: SpecimensDouble
var orders: OrdersDouble
var inv: Inventory
var events: Array = []
var notes: Array = []


func before_each() -> void:
	events.clear()
	notes.clear()
	EventBus.stranger_event.connect(_on_event)
	EventBus.notification_requested.connect(_on_note)
	world = Node.new()
	stranger = Stranger.new()
	stranger.config = Phase9Fixtures.stranger_config()
	for o: StrangerOfferData in Phase9Fixtures.stranger_offers():
		stranger.offer_table[o.id] = o
	stranger.quest_data = Phase9Fixtures.quest(&"q_case")
	quests = QuestsDouble.new()
	piety = PietyDouble.new()
	piety.events_cfg = Phase9Fixtures.piety_config().events
	rep = RepDouble.new()
	rel = Relationships.new()
	rel.config = Phase9Fixtures.relationship_config()
	journal = JournalDouble.new()
	life = LifeDouble.new()
	graveyard = GraveyardDouble.new()
	corpses = CorpseDouble.new()
	specimens = SpecimensDouble.new()
	orders = OrdersDouble.new()
	inv = Inventory.new()
	var player := PlayerInv.new()
	player.inventory = inv
	for n: Node in [stranger, quests, piety, rep, rel, journal, life, graveyard, corpses, specimens, orders, inv, player]:
		world.add_child(n)
	tree.root.add_child(world)
	GameState.set_flag(&"p9_open", true)
	GameState.set_flag(&"p9_open_day", OPEN_DAY)
	await wait_frames(1)


func after_each() -> void:
	EventBus.stranger_event.disconnect(_on_event)
	EventBus.notification_requested.disconnect(_on_note)
	world.queue_free()
	await wait_frames(1)


func _at(day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	stranger.apply_morning(day)
	stranger.apply_minute(day, minute)


func _grave(id: String, buried_day: int) -> void:
	var g := GraveRecord.new()
	g.id = id
	g.state = GraveRecord.State.MARKED
	g.corpse_id = "corpse_" + id
	graveyard.list.append(g)
	var r := CorpseRecord.new()
	r.id = g.corpse_id
	r.buried_day = buried_day
	r.location = CorpseRecord.LOCATION_BURIED
	r.grave_id = id
	corpses.list.append(r)


# --- visits -------------------------------------------------------------------------------------

func test_not_before_p9_open() -> void:
	GameState.set_flag(&"p9_open", false)
	_at(65, 900)
	assert_false(stranger.present(&"graveyard"))
	assert_eq(stranger.visit_days(), PackedInt32Array())
	assert_eq(events, [])


func test_visits_and_the_gate_bell() -> void:
	_at(64, 900)
	assert_false(stranger.here())
	_at(65, 600)
	assert_eq(events, [[&"arrived", "village"]])
	assert_true(stranger.present(&"village"))
	assert_false(stranger.present(&"graveyard"), "not inside the cemetery – not at the gate yet")
	stranger.apply_minute(65, 849)
	TimeManager.set_time(65, 850)
	stranger.apply_minute(65, 850)
	assert_true(stranger.present(&"graveyard"), "outside the gate")
	assert_eq(events.back(), [&"arrived", "gate"])
	assert_has(notes, Stranger.TEXT_GATE)
	stranger.apply_minute(65, 860)
	assert_eq(notes.count(Stranger.TEXT_GATE), 1, "the bell once a day")
	_at(66, 900)
	assert_eq(notes.count(Stranger.TEXT_GATE), 2, "every visit day")
	_at(68, 900)
	assert_false(stranger.here())
	_at(70, 900)
	assert_eq(stranger.save_state().visits, [65, 70])
	assert_eq(stranger.visit_now(), 2)


func test_questions_coin_and_piety_once() -> void:
	_at(65, 870)
	assert_eq(stranger.question(), "Wie tief graben Sie im Frost?")
	stranger.answer(&"frank")
	assert_eq([inv.count(&"coin"), GameState.get_stat(&"stranger_coins"), GameState.get_stat(&"stranger_talks")], [1, 1, 1])
	assert_eq(quests.notes_list, [[&"stranger_answered", "frank"]])
	assert_eq(stranger.question(), "", "one question per visit")
	stranger.answer(&"frank")
	assert_eq(inv.count(&"coin"), 1)
	_at(70, 870)
	assert_eq(stranger.question(), Phase9Fixtures.stranger_config().questions[1], "a new one")
	stranger.answer(&"refuse")
	assert_eq(piety.total, 1, "„Die Toten haben ein Recht auf Ruhe.“")
	_at(75, 870)
	stranger.answer(&"refuse")
	assert_eq(piety.total, 1, "piety only once")
	_at(80, 870)
	stranger.answer(&"evade")
	assert_eq(stranger.answers(), [&"frank", &"refuse", &"refuse", &"evade"] as Array[StringName])
	assert_eq(events.filter(func(e: Array) -> bool: return e[0] == &"asked").size(), 4)
	_at(68, 870)
	stranger.answer(&"frank")
	assert_eq(stranger.answers().size(), 4, "not between visits")


# --- offers -------------------------------------------------------------------------------------

func test_offers_only_while_here_and_their_conditions() -> void:
	_at(64, 870)
	assert_eq(stranger.offers(inv), [] as Array[Dictionary])
	assert_false(stranger.offers_seen())
	_at(65, 870)
	var offers := stranger.offers(inv)
	assert_eq(offers.map(func(o: Dictionary) -> StringName: return o.id), [&"so_register", &"so_soil"],
			"no specimens without anatomy, no ledger before the main chain")
	assert_eq(offers[1].reason, StrangerRules.TEXT_NO_FRESH)
	assert_eq(quests.notes_list, [[&"stranger_offers_seen", ""]])
	stranger.offers(inv)
	assert_eq(quests.notes_list.size(), 1, "K2 noted once")
	GameState.set_flag(&"anatomy_known", true)
	quests.main_ending = &"away"
	var ids: Array = stranger.offers(inv).map(func(o: Dictionary) -> StringName: return o.id)
	assert_eq(ids, [&"so_kladde", &"so_register", &"so_soil", &"so_specimen"])
	assert_eq(stranger.offers(inv)[0].price, 40)


func test_soil_from_a_fresh_grave_only() -> void:
	_grave("l_14", 62)
	_grave("l_13", 58)
	_at(65, 870)
	assert_false(stranger.soil_offered("l_14"), "only after he asked (K2)")
	stranger.offers(inv)
	assert_true(stranger.soil_offered("l_14"))
	assert_false(stranger.soil_offered("l_13"), "7 days: not fresh")
	assert_eq(stranger.soil_block_reason("l_13", inv), Stranger.TEXT_SOIL_FRESH)
	assert_eq(stranger.offers(inv)[1].reason, StrangerRules.TEXT_SOIL, "a fresh grave waits")
	assert_true(stranger.take_soil("l_14", inv))
	assert_eq(inv.count(&"soil_pouch"), 1)
	assert_false(stranger.take_soil("l_14", inv), "once per grave")
	assert_eq(stranger.soil_block_reason("l_14", inv), Stranger.TEXT_SOIL_TAKEN)
	assert_true(stranger.sell(&"so_soil", inv))
	assert_eq([inv.count(&"soil_pouch"), inv.count(&"coin"), piety.total, stranger.sold(&"so_soil")], [0, 3, -1, 1])
	assert_eq(events.back(), [&"sold", "so_soil"])
	assert_false(stranger.sell(&"so_soil", inv), "no soil left")
	_at(70, 600)
	assert_false(stranger.soil_offered("l_14"), "day 70: the grave is 8 days old")


func test_register_and_the_talk_two_days_later() -> void:
	stranger.offer_table = {}
	inv.add_item(&"register_extract", 1)
	_at(65, 870)
	rel.meet(&"priest")
	rel.meet(&"mayor")
	var lenz := rel.value(&"priest")
	var fenner := rel.value(&"mayor")
	assert_true(stranger.sell(&"so_register", inv))
	assert_eq([inv.count(&"coin"), piety.total], [10, -3])
	assert_eq(rel.value(&"priest"), lenz, "not at once")
	_at(66, 600)
	assert_eq(rel.value(&"priest"), lenz)
	_at(67, 600)
	assert_eq([rel.value(&"priest") - lenz, rel.value(&"mayor") - fenner], [-4, -2], "Rosine tells it two days later")
	assert_eq(rep.events, [&"register_sold_rumor"] as Array[StringName])
	assert_eq(life.events.back()[0], &"register_sold", "Gerede register_sold")
	assert_eq(stranger.save_state().rumors, [])


func test_specimen_at_one_and_a_half_times_quasts_price() -> void:
	stranger.offer_table = {}
	GameState.set_flag(&"anatomy_known", true)
	inv.add_unique(&"specimen_jar", "sp_0001")
	_at(65, 870)
	var o: Array = stranger.offers(inv).filter(func(d: Dictionary) -> bool: return d.id == &"so_specimen")
	assert_eq([o[0].price, o[0].reason], [9, ""])
	assert_true(stranger.sell(&"so_specimen", inv))
	assert_eq(inv.count(&"coin"), 9, "Quast's 6 through Specimens.sell + 3")
	assert_eq(specimens.sold, ["sp_0001"] as Array[String], "the Phase-7 consequences")
	assert_eq(rep.events, [&"visit_specimen_rumor"] as Array[StringName])


func test_bribe() -> void:
	_at(65, 870)
	stranger.bribe(true, inv)
	assert_eq([inv.count(&"coin"), piety.total, GameState.flag_on(&"case_bribe")], [15, -3, true])
	assert_true(journal.clues.has(&"c_q_case_lorenz"))
	stranger.bribe(false, inv)
	assert_eq(stranger.bribe_state(), &"accepted", "once")
	assert_eq(events.back(), [&"bribed", "yes"])


# --- case ---------------------------------------------------------------------------------------------

func test_the_case() -> void:
	_at(70, 600)
	assert_eq(stranger.case_holder(), &"")
	_at(71, 600)
	assert_eq(stranger.case_holder(), &"inn", "forgotten at the Holderkrug on the second day of the second visit")
	assert_has(notes, Stranger.TEXT_CASE_INN)
	assert_true(stranger.take_case(inv))
	assert_eq([stranger.case_holder(), inv.count(&"stranger_case")], [&"player", 1])
	assert_true(stranger.open_case(inv))
	assert_true(journal.clues.has(&"c_q_case_list") and GameState.flag_on(&"case_opened"))
	assert_false(stranger.open_case(inv), "once")
	TimeManager.set_time(71, 830)
	assert_false(stranger.give_case(&"stranger", inv), "on his way up to the gate he is nowhere to hand it to")
	TimeManager.set_time(71, 880)
	assert_true(stranger.give_case(&"stranger", inv))
	assert_eq([stranger.case_holder(), inv.count(&"stranger_case"), inv.count(&"coin")], [&"stranger", 0, 0], "opened: no tip")
	assert_eq(orders.completed, [&"oq_case_return"] as Array[StringName])


func test_case_unopened_tip_and_to_fenner() -> void:
	_at(71, 880)
	stranger.take_case(inv)
	assert_true(stranger.give_case(&"stranger", inv))
	assert_eq(inv.count(&"coin"), 2, "Botenlohn 2")
	var other := Stranger.new()
	other.config = stranger.config
	world.add_child(other)
	other.load_state({"case": "player"})
	inv.add_item(&"stranger_case", 1)
	assert_true(other.give_case(&"fenner", inv))
	assert_eq(other.resolve_block_reason(&"fenner"), "", "the proof leads straight to Fenner")


# --- endings ---------------------------------------------------------------------------------------------

func test_resolve_fenner() -> void:
	_at(65, 870)
	assert_eq(stranger.resolve_block_reason(&"fenner"), Stranger.TEXT_RESOLVE_NOT_YET)
	stranger.resolve(&"fenner")
	assert_false(stranger.gone())
	_at(72, 870)
	assert_eq(stranger.resolve_block_reason(&"fenner"), "", "the last day of his second visit")
	rel.meet(&"mayor")
	rel.meet(&"surgeon")
	var fenner := rel.value(&"mayor")
	var quast := rel.value(&"surgeon")
	stranger.resolve(&"fenner")
	assert_eq(quests.chosen, [[&"q_case", &"k5", &"fenner"]])
	assert_eq([stranger.gone(), stranger.ending(), GameState.flag_on(&"case_end_fenner")], [true, &"fenner", true])
	assert_eq(rep.events, [&"case_reported"] as Array[StringName], "Ruf +3")
	assert_eq([rel.value(&"mayor") - fenner, rel.value(&"surgeon") - quast], [4, -6])
	assert_eq(events.back(), [&"expelled", "fenner"])
	assert_true(stranger.present(&"graveyard"), "this afternoon he is still walked over the bridge")
	_at(75, 870)
	assert_false(stranger.here(), "never again")
	assert_eq(stranger.offers(inv), [] as Array[Dictionary])
	stranger.resolve(&"deal")
	assert_eq(stranger.ending(), &"fenner", "one ending")


func test_resolve_deal_with_and_without_the_ledger() -> void:
	quests.accept_choice = true
	_at(72, 870)
	stranger.resolve(&"deal")
	assert_eq(inv.count(&"case_card"), 1, "„Falls Sie es sich überlegen.“")
	assert_eq(rep.events, [] as Array[StringName], "the chain ran the actions (no second time)")
	var other := Stranger.new()
	other.config = stranger.config
	other.offer_table = stranger.offer_table
	world.add_child(other)
	quests.main_ending = &"stay"
	inv.add_item(&"lorenz_ledger_2", 1)
	other.apply_morning(72)
	var kladde: Array = other.offers(inv).filter(func(d: Dictionary) -> bool: return d.id == &"so_kladde")
	assert_eq([kladde[0].price, kladde[0].reason], [40, ""])
	assert_true(other.sell(&"so_kladde", inv))
	assert_eq([inv.count(&"lorenz_ledger_2"), inv.count(&"coin"), piety.total, GameState.flag_on(&"kladde_sold")], [0, 40, -8, true])
	other.resolve(&"deal")
	assert_eq(inv.count(&"case_card"), 1, "sold the ledger: no card")


func test_resolve_ilse() -> void:
	_at(72, 870)
	assert_eq(stranger.resolve_block_reason(&"ilse"), Stranger.TEXT_RESOLVE_ILSE)
	GameState.set_flag(&"trader_known", true)
	stranger.resolve(&"ilse")
	assert_eq([stranger.ending(), piety.total, GameState.flag_on(&"case_end_ilse")], [&"ilse", 2, true])
	assert_eq(events.back(), [&"left", "ilse"])


func test_he_leaves_after_the_last_visit() -> void:
	_at(82, 600)
	assert_false(stranger.gone())
	_at(83, 600)
	assert_true(stranger.gone())
	assert_eq(events.back(), [&"left", ""])
	_at(85, 870)
	assert_false(stranger.here())


func test_save_load() -> void:
	stranger.offer_table = {}
	_grave("l_14", 64)
	inv.add_item(&"register_extract", 1)
	_at(65, 870)
	stranger.answer(&"frank")
	stranger.offers(inv)
	stranger.take_soil("l_14", inv)
	stranger.sell(&"so_register", inv)
	var saved := stranger.save_state()
	assert_eq([saved.visits, saved.answers, saved.sold, saved.case, saved.ending], [[65], ["frank"], {"register": 1}, "", ""])
	assert_eq(saved.rumors, [{"event": "register_sold", "day": 65}])
	var other := Stranger.new()
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(JSON.stringify(other.save_state()), JSON.stringify(saved), "round trip identical")
	other.load_state({"ending": "hanged", "case": "moon", "visits": "often", "sold": [1, 2], "rumors": [{"event": "x"}, 3]})
	assert_eq([other.gone(), other.case_holder(), other.save_state().visits, other.save_state().sold, other.save_state().rumors],
			[false, &"", [], {}, []])
	other.load_state({"visits": [65, 70], "answers": ["frank"], "sold": {"soil": 1}, "bribe": "", "case": "inn", "ending": "",
			"rumors": [{"event": "register_sold", "day": 68}]})
	assert_eq([other.case_holder(), other.sold(&"so_soil"), other.gone()], [&"inn", 1, false], "§5.1 as written")
	other.free()


func _on_event(kind: StringName, detail: String) -> void:
	events.append([kind, detail])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
