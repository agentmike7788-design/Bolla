extends TestCase
## P3 (docs/PHASE9_DESIGN.md §2.4, §3.3, §3.4, §5.1, §10): Letters – the assignment at the delivery (only from p9_open,
## forced L1–L3, then the pool for the trait letter, never twice, story / household conditions), the find in the
## pockets, every choice with its consequences (piety per seal / request, relationship, reputation cap 1/day, the
## ghost +1 tonight, the grave gift ≤ +1), the illiterate (reading aloud = delivering), the post for the dead
## (Osric's offsets, only to occupied graves, Hanne's letter to L. Aschau), answers and counter-letters, postage,
## errands E1/E2, save / load. Against the Phase-9 fixtures and test doubles for the foreign systems.

const OPEN_DAY := 63


class CorpseDouble extends Node:
	var list: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return list

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in list:
			if r.id == id:
				return r
		return null


class QuestsDouble extends Node:
	var notes_list: Array = []
	var chosen: Array = []
	var accept_choice: bool = false

	func _init() -> void:
		add_to_group(&"quests")

	func note(key: StringName, arg: String) -> void:
		notes_list.append([key, arg])

	func choose(q: StringName, s: StringName, c: StringName) -> bool:
		chosen.append([q, s, c])
		return accept_choice

	func keys() -> Array:
		return notes_list.map(func(n: Array) -> StringName: return n[0])


class OrdersDouble extends Node:
	var completed: Array[StringName] = []
	var table: Dictionary = {}

	func _init() -> void:
		add_to_group(&"orders")

	func order_data(id: StringName) -> OrderData:
		return table.get(id)

	func state(id: StringName) -> StringName:
		return &"completed" if completed.has(id) else &"accepted"

	func complete(id: StringName) -> void:
		completed.append(id)


class VisitorsDouble extends Node:
	var goodwill_of: Dictionary = {}
	var graves: Dictionary = {}

	func _init() -> void:
		add_to_group(&"visitors")

	func add_goodwill(kin: StringName, n: int) -> void:
		goodwill_of[kin] = int(goodwill_of.get(kin, 0)) + n

	func graves_of(kin: StringName) -> PackedStringArray:
		return graves.get(kin, PackedStringArray())

	func kin_for_grave(_grave_id: String) -> StringName:
		return &""


class WanderersDouble extends Node:
	var days: Array[int] = []

	func _init() -> void:
		add_to_group(&"wanderers")

	func peddler_day(day: int) -> bool:
		return days.has(day)


class LifeDouble extends Node:
	var events: Array = []

	func _init() -> void:
		add_to_group(&"npc_life")

	func note_event(event: StringName, npcs: Array[StringName] = []) -> void:
		events.append([event, npcs])


## Reputation / Piety without the daily drift (TimeManager.set_time starts days): they count the events.
class RepDouble extends Node:
	var events: Array[StringName] = []
	var points: Dictionary = {}

	func _init() -> void:
		add_to_group(&"reputation")

	func event(kind: StringName, _reason: String) -> void:
		events.append(kind)

	func value() -> int:
		var v := 50
		for e: StringName in events:
			v += int(points.get(e, 0))
		return v


class PietyDouble extends Node:
	var total: int = 0
	var events_cfg: Dictionary = {}

	func _init() -> void:
		add_to_group(&"piety")

	func event(kind: StringName, _reason: String) -> void:
		total += int(events_cfg.get(kind, 0))

	func change(delta: int, _reason: String) -> void:
		total += delta

	func value() -> int:
		return total


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


var world: Node
var letters: Letters
var corpses: CorpseDouble
var quests: QuestsDouble
var orders: OrdersDouble
var visitors: VisitorsDouble
var wanderers: WanderersDouble
var life: LifeDouble
var journal: JournalDouble
var piety: PietyDouble
var rep: RepDouble
var rel: Relationships
var inv: Inventory
var changes: Array = []
var notes: Array = []


func before_each() -> void:
	changes.clear()
	notes.clear()
	EventBus.letter_changed.connect(_on_letter)
	EventBus.notification_requested.connect(_on_note)
	world = Node.new()
	world.name = "World"
	letters = Letters.new()
	letters.config = Phase9Fixtures.letters_config()
	letters.letter_table = Phase9Fixtures.letter_table()
	letters.quest_data = Phase9Fixtures.quest(&"q_letters")
	corpses = CorpseDouble.new()
	quests = QuestsDouble.new()
	orders = OrdersDouble.new()
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		orders.table[id] = Phase9Fixtures.order(id)
	visitors = VisitorsDouble.new()
	wanderers = WanderersDouble.new()
	life = LifeDouble.new()
	journal = JournalDouble.new()
	piety = PietyDouble.new()
	piety.events_cfg = Phase9Fixtures.piety_config().events
	rep = RepDouble.new()
	rep.points = Phase9Fixtures.reputation_config().event_points
	rel = Relationships.new()
	rel.config = Phase9Fixtures.relationship_config()
	inv = Inventory.new()
	for n: Node in [letters, corpses, quests, orders, visitors, wanderers, life, journal, piety, rep, rel, inv]:
		world.add_child(n)
	tree.root.add_child(world)
	TimeManager.set_time(OPEN_DAY, 480)
	await wait_frames(1)


func after_each() -> void:
	EventBus.letter_changed.disconnect(_on_letter)
	EventBus.notification_requested.disconnect(_on_note)
	world.queue_free()
	await wait_frames(1)


func _open() -> void:
	GameState.set_flag(&"p9_open", true)
	GameState.set_flag(&"p9_open_day", OPEN_DAY)


func _record(id: String, traits: Array[StringName] = [], story: StringName = &"", seed: int = 1) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = id
	r.seed = seed
	r.traits = traits
	r.story_id = story
	r.display_name = "Tote " + id
	corpses.list.append(r)
	return r


func _buried(r: CorpseRecord, grave: String, day: int) -> CorpseRecord:
	r.location = CorpseRecord.LOCATION_BURIED
	r.grave_id = grave
	r.buried_day = day
	return r


## A found pocket letter `id` (record + item).
func _found(id: StringName, corpse_id: String = "corpse_0050") -> String:
	_open()
	var r := _record(corpse_id)
	r.letter_id = id
	return letters.on_found(corpse_id, inv)


func _choice(uid: String, id: StringName, context: Dictionary) -> Dictionary:
	for c: Dictionary in letters.choices(uid, context):
		if c.id == id:
			return c
	return {}


# --- assignment ------------------------------------------------------------------------------------

func test_assign_only_from_p9_open() -> void:
	var r := _record("corpse_0040", [&"letter"] as Array[StringName])
	letters.assign(r)
	assert_eq(r.letter_id, &"", "before p9_open: the Phase-4 find stays")
	_open()
	letters.assign(r)
	assert_eq(r.letter_id, &"lp_l1_carter")
	letters.assign(r)
	assert_eq(r.letter_id, &"lp_l1_carter", "a record with a letter keeps it")


func test_first_three_deliveries_carry_l1_to_l3_then_the_pool() -> void:
	_open()
	var ids: Array[StringName] = []
	for i: int in 3:
		var r := _record("corpse_%04d" % (40 + i), [] as Array[StringName], &"", 100 + i)
		letters.assign(r)
		ids.append(r.letter_id)
	assert_eq(ids, [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"] as Array[StringName], "forced, even without the trait")
	var plain := _record("corpse_0043", [] as Array[StringName], &"", 200)
	letters.assign(plain)
	assert_eq(plain.letter_id, &"", "after the three: only with the trait letter")
	var seen: Array[StringName] = []
	for i: int in 12:
		var r := _record("corpse_%04d" % (50 + i), [&"letter"] as Array[StringName], &"", 300 + i * 31)
		letters.assign(r)
		if r.letter_id != &"":
			assert_false(seen.has(r.letter_id), "%s never twice" % r.letter_id)
			assert_false(r.letter_id in [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn", &"lp_d3_grete", &"lg_wife", &"lg_lambert"],
					"%s: pool only (no chain, no story, no household, Lambert not let go)" % r.letter_id)
			seen.append(r.letter_id)
	assert_eq(seen.size(), 5, "the five pool letters without conditions, then none")
	var save := letters.save_state()
	assert_eq(save.forced_used, 3)


func test_household_and_story_letters() -> void:
	_open()
	letters.load_state({"forced_used": 3})
	var grete := _record("corpse_0060", [] as Array[StringName], &"d3_sieber")
	letters.assign(grete)
	assert_eq(grete.letter_id, &"lp_d3_grete", "D3 carries „An Grete“")
	var used: Array[StringName] = [&"lg_grocer", &"lg_nobody", &"lg_priest", &"lg_smith", &"lg_town"]
	for id: StringName in used:
		var r := _record("used_" + String(id))
		r.letter_id = id
	var no_house := _record("corpse_0061", [&"letter"] as Array[StringName])
	letters.assign(no_house)
	assert_eq(no_house.letter_id, &"", "lg_wife needs a household")
	var house := _record("corpse_0062", [&"letter"] as Array[StringName])
	house.kin_house = &"house_kehr"
	letters.assign(house)
	assert_eq(house.letter_id, &"lg_wife", "the household of the dead (kin_kehr)")


func test_on_found_hands_the_letter() -> void:
	var uid := _found(&"lp_l1_carter")
	assert_eq(uid, "lt_0001")
	assert_true(inv.has_uid(uid) and inv.uid_item(uid) == &"letter")
	assert_eq([letters.state(uid), letters.letter(uid).id, letters.corpse_of(uid)], [&"found", &"lp_l1_carter", "corpse_0050"])
	assert_eq(letters.on_found("corpse_0050", inv), uid, "idempotent")
	assert_eq(GameState.get_stat(&"letters_found"), 1)
	assert_has(notes, Letters.TEXT_FOUND % "An Rosine Wackernagel, Holderkrug")
	assert_eq(changes, [[uid, &"lp_l1_carter", &"found"]])
	assert_eq(letters.on_found("corpse_9999", inv), "", "unknown corpse")
	var plain := _record("corpse_0051")
	assert_eq(letters.on_found(plain.id, inv), "", "no letter in the pockets")


func test_found_with_a_full_bag_comes_next_morning() -> void:
	var full := Inventory.new()
	world.add_child(full)
	full.add_item(&"stone", 50 * 30)
	_open()
	var r := _record("corpse_0052")
	r.letter_id = &"lg_priest"
	var uid := letters.on_found(r.id, full)
	assert_ne(uid, "")
	assert_false(full.has_uid(uid))
	assert_has(notes, Letters.TEXT_FOUND_NO_ROOM)
	assert_eq(letters.open_uids(), PackedStringArray(), "not in the hand yet")
	var player := Node.new()
	player.set_script(null)
	full.remove_item(&"stone", 50)
	# the morning hands pending letters to the player's bag (group player)
	var p := PlayerInv.new()
	p.inventory = full
	world.add_child(p)
	letters.apply_morning(OPEN_DAY + 1)
	assert_true(full.has_uid(uid), "handed in the morning")
	player.free()


class PlayerInv extends Node:
	var inventory: Inventory

	func _init() -> void:
		add_to_group(&"player")


# --- choices ------------------------------------------------------------------------------------------

func test_deliver_in_person() -> void:
	var uid := _found(&"lp_l1_carter")
	var c := _choice(uid, &"deliver", {"inventory": inv, "npc": &"grocer"})
	assert_eq(c.label, "Zustellen – Rosine im Holderkrug")
	assert_eq(c.reason, LetterRules.TEXT_TO_PERSON % Phase8Texts.person_name(&"innkeeper"), "dimmed with a reason, not a lock")
	assert_false(letters.decide(uid, &"deliver", {"inventory": inv, "npc": &"grocer"}))
	rel.meet(&"innkeeper")
	var before := rel.value(&"innkeeper")
	assert_true(letters.decide(uid, &"deliver", {"inventory": inv, "npc": &"innkeeper"}))
	assert_eq(rel.value(&"innkeeper") - before, 3, "Rosine +3")
	assert_eq(rep.value(), 51, "reputation +1")
	assert_eq([letters.state(uid), inv.has_uid(uid), letters.decided_count(), letters.delivered_count()], [&"delivered", false, 1, 1])
	assert_eq(quests.notes_list, [[&"pocket_decided", uid]])
	assert_eq(life.events, [[&"letter_delivered", [&"innkeeper"] as Array[StringName]]], "the talk of two days (NpcLifeConfig)")
	assert_false(letters.decide(uid, &"burn", {"inventory": inv, "place": &"stove"}), "decided only once")
	assert_eq([GameState.get_stat(&"letters_delivered"), GameState.get_stat(&"letters_decided")], [1, 1])


func test_reputation_at_most_once_a_day_and_standard_relationship() -> void:
	var a := _found(&"lg_priest", "corpse_0070")
	var r := _record("corpse_0071")
	r.letter_id = &"lg_smith"
	var b := letters.on_found(r.id, inv)
	rel.meet(&"priest")
	var priest := rel.value(&"priest")
	assert_true(letters.decide(a, &"deliver", {"npc": &"priest", "inventory": inv}))
	assert_true(letters.decide(b, &"deliver", {"npc": &"smith", "inventory": inv}))
	assert_eq(rep.value(), 51, "Ruf +1 höchstens 1 je Tag")
	assert_eq(rel.value(&"priest") - priest, 3)
	assert_eq(inv.count(&"iron_fittings"), 1, "Esch gives the fittings")
	TimeManager.set_time(OPEN_DAY + 1, 480)
	var r2 := _record("corpse_0072")
	r2.letter_id = &"lg_grocer"
	var c := letters.on_found(r2.id, inv)
	assert_true(letters.decide(c, &"deliver", {"npc": &"grocer", "inventory": inv}))
	assert_eq(rep.value(), 52, "the next day again")


func test_read_yourself_costs_piety_when_sealed_and_is_no_decision() -> void:
	var uid := _found(&"lg_priest")
	assert_eq(letters.visible_text(uid), "", "sealed: only the outside")
	assert_eq(_choice(uid, &"read", {}).label, "Öffnen und lesen")
	assert_true(letters.decide(uid, &"read", {"inventory": inv}))
	assert_eq(piety.value(), -1, "§14.6: a sealed letter not to you −1")
	assert_true(letters.is_opened(uid))
	assert_ne(letters.visible_text(uid), "")
	assert_eq(letters.read_uids(), PackedStringArray([uid]), "the copy stays in the Merkbuch")
	assert_eq([letters.state(uid), letters.decided_count(), inv.has_uid(uid)], [&"found", 0, true], "no decision")
	assert_false(letters.decide(uid, &"read", {"inventory": inv}), "read once")
	assert_eq(changes.back(), [uid, &"lg_priest", &"read"])
	assert_true(letters.decide(uid, &"deliver", {"npc": &"priest", "inventory": inv}), "can still be delivered")
	var open := _found(&"lp_l1_carter", "corpse_0080")
	assert_true(letters.decide(open, &"read", {"inventory": inv}))
	assert_eq(piety.value(), -1, "an unsealed one is free")


func test_burn_asked_and_unasked_and_the_warning_letter() -> void:
	var asked := _found(&"lp_l3_burn", "corpse_0090")
	var c := _choice(asked, &"burn", {})
	assert_eq([c.label, c.reason], ["Verbrennen – Ofen in der Hütte", LetterRules.TEXT_AT_FIRE])
	assert_true(letters.decide(asked, &"burn", {"inventory": inv, "place": &"stove"}))
	assert_eq(piety.value(), 1, "it asked: +1")
	assert_eq([letters.state(asked), GameState.get_stat(&"letters_burned")], [&"burned", 1])
	var unasked := _found(&"lg_priest", "corpse_0091")
	assert_true(letters.decide(unasked, &"burn", {"inventory": inv, "place": &"forge"}))
	assert_eq(piety.value(), 0, "otherwise −1")
	var l3 := _found(&"lp_l3_burn", "corpse_0092")
	assert_true(letters.decide(l3, &"read", {"inventory": inv}))
	assert_eq(piety.value(), -1, "read the one that says ‚unread‘")
	assert_true(journal.clues.has(&"c_warning_letter"), "the warning in the slanted hand")


func test_read_at_the_grave_tonight_and_the_ghost() -> void:
	_open()
	var marthe := _buried(_record("corpse_0006", [] as Array[StringName], &"s1_quendel"), "plot_06", 6)
	var post := Phase9Fixtures.post_waiting(&"lpo_quendel")
	var pl: Letters = post.letters
	pl.free()
	letters.load_state({"next_uid": 2, "records": {"lt_0001": {"id": "lpo_quendel", "corpse": marthe.id, "state": "received",
			"day": OPEN_DAY, "kind": "post"}}})
	inv.add_unique(&"letter", "lt_0001")
	var c := _choice("lt_0001", &"read_grave", {"grave_id": "l_01"})
	assert_eq(c.reason, LetterRules.TEXT_AT_GRAVE)
	assert_true(c.label.begins_with("Am Grab vorlesen – "))
	TimeManager.set_time(OPEN_DAY, 1140)
	assert_true(letters.decide("lt_0001", &"read_grave", {"inventory": inv, "grave_id": "plot_06"}))
	assert_eq(piety.value(), 1)
	assert_eq([letters.state("lt_0001"), inv.has_uid("lt_0001"), letters.decided_count()], [&"read_grave", false, 1])
	assert_true(letters.letter_tonight("plot_06"))
	assert_eq(letters.ghost_bonus("plot_06"), 1, "Geist +1 in dieser Nacht")
	TimeManager.set_time(OPEN_DAY + 1, 120)
	assert_true(letters.letter_tonight("plot_06"), "02:00 still the same night")
	TimeManager.set_time(OPEN_DAY + 1, 1200)
	assert_eq(letters.ghost_bonus("plot_06"), 0, "only that night")
	assert_eq(quests.notes_list.back(), [&"post_decided", "lt_0001"])
	assert_eq(GhostMood.letter_care_key(&"", true), GhostMood.CARE_LETTER)
	assert_eq(GhostMood.letter_care_key(GhostMood.CARE_LIGHTS, true), GhostMood.CARE_LIGHTS, "after the lights")
	assert_eq(GhostMood.letter_care_key(GhostMood.CARE_CANDLE, true), GhostMood.CARE_LETTER, "before the candle")
	assert_eq(GhostMood.letter_care_key(GhostMood.CARE_CANDLE, false), GhostMood.CARE_CANDLE)
	var lines := Phase9Fixtures.ghost_lines()
	assert_true(GhostMood.pick_care_line(lines, GhostMood.CARE_LETTER, 1) in lines.by_letter)
	assert_eq((Database.ghost_lines() as GhostLines).by_letter.size(), 3, "data/ghosts/ghost_lines.tres by_letter (P3)")


func test_bury_with_the_sender_and_onto_grete() -> void:
	var uid := _found(&"lg_nobody", "corpse_0100")
	var c := _choice(uid, &"bury", {})
	assert_eq([c.label, c.reason], ["Mit ins Grab legen", LetterRules.TEXT_BURY_WHEN])
	assert_eq(letters.first_for(&"bury", inv, {"burying": "corpse_0100"}), uid, "carrying the sender to its open grave")
	assert_eq(letters.first_for(&"bury", inv, {"burying": "corpse_0001"}), "", "not another dead")
	assert_true(letters.decide(uid, &"bury", {"inventory": inv, "grave_id": "l_14", "burying": "corpse_0100"}))
	assert_eq([letters.state(uid), piety.value(), letters.ghost_bonus("l_14")], [&"buried", 1, 1], "Geist +1 dauerhaft")
	TimeManager.set_time(OPEN_DAY + 5, 600)
	assert_eq(letters.ghost_bonus("l_14"), 1, "for good")
	assert_eq(GhostMood.letter_bonus(true, true), 2)
	assert_eq(GhostMood.letter_bonus(false, true), GhostMood.LETTER_GIFT_MAX, "≤ +1")
	var d3 := _record("corpse_0110", [] as Array[StringName], &"d3_sieber")
	d3.kin_house = &"house_sieber"
	d3.letter_id = &"lp_d3_grete"
	visitors.graves[&"kin_sieber"] = PackedStringArray(["l_02", "l_16"])
	_buried(d3, "l_16", OPEN_DAY + 5)
	var g := letters.on_found(d3.id, inv)
	var lay := _choice(g, &"bury", {"grave_id": "l_02"})
	assert_eq(lay.reason, "")
	assert_true(str(lay.label).begins_with("Aufs Grab legen – l_02"))
	assert_eq(letters.first_for(&"bury", inv, {"grave_id": "l_16"}), "", "not onto his own")
	assert_true(letters.decide(g, &"bury", {"inventory": inv, "grave_id": "l_02"}))
	assert_eq(piety.value(), 3, "Pietät +2 (letter_buried + 1)")


func test_illiterate_hear_it_read_and_households() -> void:
	_open()
	var r := _record("corpse_0120")
	r.kin_house = &"house_kehr"
	r.letter_id = &"lg_wife"
	var uid := letters.on_found(r.id, inv)
	var c := _choice(uid, &"deliver", {"npc": &"kin_kehr"})
	assert_eq([c.label, c.reason], ["Vorlesen – Martha am Grab", ""])
	assert_true(letters.decide(uid, &"deliver", {"inventory": inv, "npc": &"kin_kehr"}))
	assert_eq(visitors.goodwill_of, {&"kin_kehr": 2}, "Wohlwollen +2")
	assert_true(letters.is_opened(uid), "read aloud")
	assert_eq([letters.state(uid), GameState.get_stat(&"letters_read")], [&"delivered", 1], "counts as delivered")
	assert_eq(piety.value(), 0, "reading to her is free")


func test_lambert_goes_with_veit() -> void:
	letters.letter_table = {}
	var uid := _found(&"lg_lambert")
	var c := _choice(uid, &"deliver", {"npc": &"beggar"})
	assert_eq(c.reason, "")
	assert_true(str(c.label).begins_with("Vorlesen – Veit"), str(c.label))
	assert_true(letters.decide(uid, &"deliver", {"inventory": inv, "npc": &"beggar"}))
	assert_eq(piety.value(), 1, "Pietät +1")


func test_post_to_town_with_postage_and_the_counting_house() -> void:
	letters.letter_table = {}
	var uid := _found(&"lg_town")
	assert_eq(_choice(uid, &"deliver", {}).label, Letters.LABEL_POST)
	assert_eq(letters.post_block_reason(uid, &"peddler", inv), Letters.TEXT_NO_COIN)
	assert_false(letters.give_to_carrier(uid, &"peddler", inv))
	inv.add_item(&"coin", 3)
	assert_eq(letters.post_block_reason(uid, &"moon", inv), LetterRules.TEXT_NOBODY)
	assert_true(letters.decide(uid, &"deliver", {"inventory": inv, "carrier": &"peddler"}))
	assert_eq([inv.count(&"coin"), GameState.get_stat(&"coins_spent_post"), GameState.get_stat(&"coins_spent")], [2, 1, 1])
	assert_eq([letters.state(uid), letters.delivered_count(), letters.decided_count()], [&"posted", 1, 1])
	assert_eq(changes.back(), [uid, &"lg_town", &"posted"])
	var p := PlayerInv.new()
	p.inventory = inv
	world.add_child(p)
	letters.apply_morning(OPEN_DAY + 1)
	assert_eq(inv.count(&"coin"), 2, "the counting house thanks on Hanne's next day")
	wanderers.days.append(OPEN_DAY + 3)
	letters.apply_morning(OPEN_DAY + 2)
	letters.apply_morning(OPEN_DAY + 3)
	assert_eq(inv.count(&"coin"), 4, "2 coins Botenlohn")
	assert_eq(GameState.get_stat(&"post_received"), 1)


func test_answer_and_counter_letter() -> void:
	var uid := _found(&"lp_l2_sister")
	assert_eq(letters.answerable(inv), uid)
	assert_eq(_choice(uid, &"answer", {"place": &"desk"}).reason, LetterRules.TEXT_NO_INK)
	inv.add_item(&"ink", 1)
	inv.add_item(&"coin", 2)
	assert_true(letters.decide(uid, &"answer", {"inventory": inv, "place": &"desk"}))
	assert_eq([inv.count(&"ink"), letters.state(uid), inv.has_uid(uid)], [0, &"answered", false], "the sister's letter goes with it")
	var reply := inv.uids(&"letter_reply")
	assert_eq(reply.size(), 1)
	assert_eq([letters.kind_of(reply[0]), letters.state(reply[0])], [&"reply", &"written"])
	assert_eq(letters.answerable(inv), "", "answered once")
	assert_eq(piety.value(), 0, "piety when it is posted")
	assert_true(letters.give_to_carrier(reply[0], &"carter", inv))
	assert_eq([piety.value(), GameState.get_stat(&"letters_answered"), inv.count(&"coin")], [1, 1, 1])
	assert_eq(quests.notes_list.back(), [&"answer_posted", uid], "L4")
	letters.apply_morning(OPEN_DAY + 1)
	assert_has(notes, Phase9Fixtures.letter(&"lp_l2_sister").reply_text, "the counter-letter the day after")
	assert_eq(changes.back(), [reply[0], &"lp_l2_sister", &"received"])
	assert_eq(letters.decided_count(), 1, "the reply itself is no letter of the pool")


func test_post_for_the_dead_on_the_offsets_only_to_occupied_graves() -> void:
	_open()
	_buried(_record("corpse_0006", [] as Array[StringName], &"s1_quendel"), "plot_06", 6)
	var ida := _record("corpse_0013", [] as Array[StringName], &"s3_wernstein")
	letters.apply_morning(OPEN_DAY + 2)
	assert_eq(inv.uids(&"letter").size(), 0, "nothing before p9_open_day + 3")
	var p := PlayerInv.new()
	p.inventory = inv
	world.add_child(p)
	letters.apply_morning(OPEN_DAY + 3)
	var uids := letters.post_today(OPEN_DAY + 3)
	assert_eq(uids.size(), 1)
	assert_eq([letters.letter(uids[0]).id, letters.state(uids[0]), inv.has_uid(uids[0])], [&"lpo_quendel", &"received", true])
	assert_has(notes, Letters.TEXT_POST % "Tote corpse_0006")
	assert_eq(GameState.get_stat(&"post_received"), 1)
	letters.apply_morning(OPEN_DAY + 3)
	assert_eq(letters.post_today(OPEN_DAY + 3).size(), 1, "idempotent")
	letters.apply_morning(OPEN_DAY + 6)
	assert_eq(letters.post_today(OPEN_DAY + 6).size(), 0, "Ida is not in a grave (S3 unburied)")
	_buried(ida, "h_01", 13)
	letters.apply_morning(OPEN_DAY + 9)
	assert_eq(letters.post_today(OPEN_DAY + 9).size(), 1)
	assert_eq(letters.letter(letters.post_today(OPEN_DAY + 9)[0]).id, &"lpo_wernstein")
	var c := _choice(letters.post_today(OPEN_DAY + 9)[0], &"deliver", {})
	assert_true(c.is_empty(), "no household: not deliverable")


func test_post_to_the_kin_and_the_aschau_letter() -> void:
	_open()
	var ott := _buried(_record("corpse_0036", [] as Array[StringName], &"d2_ott"), "l_12", 59)
	ott.kin_house = &"house_ott"
	letters.load_state({"next_uid": 2, "records": {"lt_0001": {"id": "lpo_ott", "corpse": ott.id, "state": "received", "day": 66,
			"kind": "post"}}, "post_done": [3]})
	inv.add_unique(&"letter", "lt_0001")
	var c := _choice("lt_0001", &"deliver", {"npc": &"kin_ott"})
	assert_eq([c.label, c.reason], ["Den Angehörigen geben – Gesa Ott", ""])
	assert_true(letters.decide("lt_0001", &"deliver", {"inventory": inv, "npc": &"kin_ott"}))
	assert_eq(visitors.goodwill_of, {&"kin_ott": 4}, "Gesa +4")
	# L5: Hanne brings the letter to L. Aschau on her first day after the first answer was posted
	var p := PlayerInv.new()
	p.inventory = inv
	world.add_child(p)
	letters.load_state({"next_uid": 3, "records": {"lt_0002": {"id": "lp_l2_sister", "corpse": "", "state": "posted", "day": 68,
			"kind": "reply"}}, "post_done": [3, 6, 9]})
	wanderers.days.assign([69, 73])
	letters.apply_morning(68)
	assert_eq(inv.uids(&"letter").size(), 0, "not the day of the answer")
	letters.apply_morning(70)
	assert_eq(inv.uids(&"letter").size(), 0, "not Hanne's day")
	letters.apply_morning(73)
	var aschau := inv.uids(&"letter")
	assert_eq(aschau.size(), 1)
	assert_eq(letters.letter(aschau[0]).id, &"lpo_aschau")
	assert_has(notes, Letters.TEXT_ASCHAU)
	var ch := letters.choices(aschau[0], {})
	assert_eq(ch.map(func(d: Dictionary) -> StringName: return d.id), [&"open", &"keep", &"liesel", &"burn"])
	assert_true(letters.decide(aschau[0], &"open", {"inventory": inv}))
	assert_eq(quests.chosen, [[&"q_letters", &"l5", &"open"]])
	assert_eq(piety.value(), -1, "without the chain: the step's actions (−1, the clue)")
	assert_true(journal.clues.has(&"c_q_ferry_letter") and GameState.flag_on(&"lorenz_letter_opened"))
	assert_false(letters.decide(aschau[0], &"burn", {"inventory": inv}), "once")


func test_errands_e1_and_e2() -> void:
	_open()
	var e1 := letters.errand_letter(&"oq_gesa_brother", inv)
	assert_ne(e1, "")
	assert_eq(letters.errand_letter(&"oq_gesa_brother", inv), e1, "one letter per errand")
	assert_eq([letters.kind_of(e1), letters.state(e1), letters.letter(e1).outside], [&"errand", &"carried",
			Letters.ERRAND_OUTSIDE[&"oq_gesa_brother"]])
	assert_eq(_choice(e1, &"deliver", {}).label, Letters.LABEL_POST)
	inv.add_item(&"coin", 2)
	assert_true(letters.give_to_carrier(e1, &"peddler", inv))
	assert_eq([piety.value(), orders.completed, inv.count(&"coin")], [1, [&"oq_gesa_brother"] as Array[StringName], 1],
			"paid the postage herself: +1; the errand is done")
	var again := letters.errand_letter(&"oq_gesa_brother", inv)
	assert_true(letters.ask_postage(again, inv), "asking Gesa")
	assert_eq(inv.count(&"straw_bouquet"), 1, "„Ich hab Strohblumen.“")
	assert_false(letters.ask_postage(again, inv), "once")
	assert_true(letters.give_to_carrier(again, &"carter", inv))
	assert_eq(piety.value(), 1, "asked: no piety")
	var e2 := letters.errand_letter(&"oq_fenner_seal", inv)
	assert_eq(_choice(e2, &"deliver", {"npc": &"priest"}).reason, "")
	assert_eq(letters.post_block_reason(e2, &"peddler", inv), LetterRules.TEXT_NOT_POSTED, "Lenz takes it in person")
	rel.meet(&"mayor")
	var fenner := rel.value(&"mayor")
	assert_true(letters.decide(e2, &"read", {"inventory": inv}))
	assert_eq(rel.value(&"mayor") - fenner, -3, "„Das Siegel ist ab. Ich seh's ja.“")
	assert_eq(piety.value(), 1, "no piety for the notice")
	assert_has(notes, Letters.TEXT_SEAL)
	assert_true(letters.decide(e2, &"deliver", {"inventory": inv, "npc": &"priest"}))
	assert_true(orders.completed.has(&"oq_fenner_seal"))
	assert_eq(letters.decided_count(), 0, "errands are no letters of the chain count")
	GameState.set_flag(&"q_end_public", true)
	var notice := letters.errand_letter(&"oq_fenner_seal", inv)
	assert_eq(letters.letter(notice).text, Letters.TEXT_NOTICE_PUBLIC, "ending C: the proclamation")


func test_save_load_round_trip_and_tolerance() -> void:
	var uid := _found(&"lg_priest")
	TimeManager.set_time(OPEN_DAY, 1300)
	letters.decide(uid, &"read", {"inventory": inv})
	var town := _found(&"lg_town", "corpse_0130")
	inv.add_item(&"coin", 1)
	letters.give_to_carrier(town, &"carter", inv)
	var saved := letters.save_state()
	assert_eq(JSON.parse_string(JSON.stringify(saved)) != null, true, "JSON")
	var other := Letters.new()
	other.letter_table = letters.letter_table
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(JSON.stringify(other.save_state()), JSON.stringify(saved), "round trip identical")
	assert_eq([other.state(uid), other.is_opened(uid), other.state(town)], [&"found", true, &"posted"])
	other.load_state({"next_uid": "x", "records": {"lt_0009": 3, "lt_0010": {"id": "lp_atlantis"}, "lt_0011": {"state": "found"}},
			"replies": [{"uid": "lt_9999"}], "post_done": ["x", 3], "read_night": [1], "buried_graves": [4, "l_01"]})
	assert_eq(other.uids(), PackedStringArray(["lt_0010"]))
	assert_null(other.letter("lt_0010"), "an unknown letter id has no data")
	assert_eq(other.choices("lt_0010", {}), [] as Array[Dictionary])
	assert_false(other.decide("lt_0010", &"burn", {"place": &"stove"}))
	assert_eq(other.save_state().next_uid, 11, "never reuses a uid")
	assert_eq(other.save_state().replies, [])
	other.free()


## The real data/letters (P3): what the leading texts promise beyond the fixtures.
func test_real_letter_data() -> void:
	letters.letter_table = {}
	assert_eq(Database.letters().size(), 16, "11 pocket + 5 post")
	for res: Resource in Database.letters():
		var l := res as LetterData
		assert_true(l.kind in LetterData.KINDS and l.outside != "" and l.text != "" and l.sender != "", String(l.id))
		for c: StringName in l.choice_actions:
			assert_true(c in LetterData.CHOICES, "%s: choice %s" % [l.id, c])
			for a: String in l.choice_actions[c]:
				var key := a.get_slice(":", 0)
				assert_true(key in ["rel_add", "piety_event", "piety_add", "rep_event", "goodwill", "set_flag", "add_clue", "give_item",
						"reply_coins"], "%s: action %s" % [l.id, a])
				if key == "piety_event":
					assert_true(Phase9Fixtures.piety_config().events.has(StringName(a.get_slice(":", 1))), a)
		if l.kind == LetterData.KIND_POST and l.id != &"lpo_aschau":
			assert_ne(l.reply_text, "", "%s: the sender writes back" % l.id)
			assert_ne(l.story_id, &"", String(l.id))
	var uid := _found(&"lp_l1_carter")
	assert_true(letters.decide(uid, &"deliver", {"inventory": inv, "npc": &"innkeeper"}))
	assert_true(GameState.flag_on(&"letter_l1_hung"), "Rosine hangs it behind the bar")
	var r := _record("corpse_0140")
	r.kin_house = &"house_kehr"
	r.letter_id = &"lg_wife"
	var wife := letters.on_found(r.id, inv)
	assert_true(letters.decide(wife, &"deliver", {"inventory": inv, "npc": &"kin_kehr"}))
	assert_true(GameState.flag_on(&"letter_wife_tip"))
	var g := _found(&"lg_grocer", "corpse_0141")
	assert_true(letters.decide(g, &"deliver", {"inventory": inv, "npc": &"grocer"}))
	assert_true(GameState.flag_on(&"letter_grocer_wine"))


func _on_letter(uid: String, id: StringName, state: StringName) -> void:
	changes.append([uid, id, state])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
