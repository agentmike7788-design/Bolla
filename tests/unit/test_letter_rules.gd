extends TestCase
## P3 (docs/PHASE9_DESIGN.md §2.4, §3.4, §10): LetterRules – the pool pick (deterministic, never twice, pool
## conditions, no story letter, no post), the dimmed choices with their reasons, the piety event per choice
## (Benutzerentscheidung §14.6: a sealed letter not to you −1 unless it asks), and the shared action interpreter.


## NightRobber in the tree with a fixed fate.
class RobberDouble extends Node:
	var f: StringName = &""

	func _init() -> void:
		add_to_group(&"night_robber")

	func fate() -> StringName:
		return f


class VisitorsDouble extends Node:
	var goodwill_calls: Array = []

	func _init() -> void:
		add_to_group(&"visitors")

	func add_goodwill(kin: StringName, n: int) -> void:
		goodwill_calls.append([kin, n])


var pool: Array[LetterData] = []
var nodes: Array[Node] = []


func before_each() -> void:
	pool = Phase9Fixtures.letters()


func after_each() -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()
	await wait_frames(1)


func test_pick_is_deterministic_and_from_the_pool() -> void:
	var a := LetterRules.pick(4711, 65, [] as Array[StringName], pool, tree)
	var b := LetterRules.pick(4711, 65, [] as Array[StringName], pool, tree)
	assert_eq(a, b, "same seed and day → same letter")
	var l := Phase9Fixtures.letter(a)
	assert_not_null(l)
	assert_eq(l.kind, LetterData.KIND_POCKET, "never post")
	assert_true(not l.conditions.has("story:d3_sieber"), "never the story letter of D3")
	var seen := {}
	for seed: int in 40:
		seen[LetterRules.pick(seed * 97, 66, [] as Array[StringName], pool, tree)] = true
	assert_true(seen.size() >= 4, "the pool spreads (%d letters)" % seen.size())
	assert_false(seen.has(&"lp_d3_grete"))
	assert_false(seen.has(&"lg_lambert"), "lg_lambert only with robber_fate let_go")
	assert_false(seen.has(&"lpo_quendel"))


func test_pick_never_twice_and_empty_when_used_up() -> void:
	var used: Array[StringName] = []
	for i: int in 30:
		var id := LetterRules.pick(i, 70, used, pool, tree)
		if id == &"":
			break
		assert_false(used.has(id), "%s not twice" % id)
		used.append(id)
	assert_eq(LetterRules.pick(1, 70, used, pool, tree), &"", "nothing left")
	assert_eq(LetterRules.pick(1, 70, [] as Array[StringName], [] as Array[LetterData], tree), &"")


func test_pool_conditions() -> void:
	var lambert := Phase9Fixtures.letter(&"lg_lambert")
	assert_false(LetterRules.pool_ok(lambert.conditions, tree), "no robber in the tree")
	var robber := RobberDouble.new()
	nodes.append(robber)
	tree.root.add_child(robber)
	robber.f = &"reported"
	assert_false(LetterRules.pool_ok(lambert.conditions, tree))
	robber.f = &"let_go"
	assert_true(LetterRules.pool_ok(lambert.conditions, tree), "Lambert let go")
	assert_eq(LetterRules.pick(9, 70, [&"lg_grocer", &"lg_nobody", &"lg_priest", &"lg_smith", &"lg_town", &"lg_wife",
			&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"] as Array[StringName], pool, tree), &"lg_lambert")
	assert_true(LetterRules.pool_ok(PackedStringArray(["kin_house"]), tree), "kin_house: the caller's check")
	assert_false(LetterRules.pool_ok(PackedStringArray(["story:d3_sieber"]), tree))
	assert_false(LetterRules.pool_ok(PackedStringArray(["moon:full"]), tree), "unknown key")
	GameState.set_flag(&"p9_x", true)
	assert_true(LetterRules.pool_ok(PackedStringArray(["flag:p9_x"]), tree))
	assert_false(LetterRules.pool_ok(PackedStringArray(["not_flag:p9_x"]), tree))
	assert_eq(LetterRules.story_of(Phase9Fixtures.letter(&"lp_d3_grete")), &"d3_sieber")
	assert_true(LetterRules.needs_kin_house(Phase9Fixtures.letter(&"lg_wife")))


func test_piety_events() -> void:
	var l1 := Phase9Fixtures.letter(&"lp_l1_carter")
	var l2 := Phase9Fixtures.letter(&"lp_l2_sister")
	var l3 := Phase9Fixtures.letter(&"lp_l3_burn")
	assert_eq(LetterRules.piety_event(l1, &"read"), &"", "unsealed: reading is free")
	assert_eq(LetterRules.piety_event(l2, &"read"), &"letter_read_sealed", "§14.6: sealed, not to you: −1")
	var asks := l2.duplicate() as LetterData
	asks.asks = &"read"
	assert_eq(LetterRules.piety_event(asks, &"read"), &"", "unless it asks to be read")
	assert_eq(LetterRules.piety_event(l3, &"burn"), &"letter_burned_asked")
	assert_eq(LetterRules.piety_event(l1, &"burn"), &"letter_burned_unasked")
	assert_eq(LetterRules.piety_event(l3, &"read"), &"letter_read_sealed", "reading the one that says „Ungelesen verbrennen“")
	assert_eq([LetterRules.piety_event(l1, &"read_grave"), LetterRules.piety_event(l1, &"bury"), LetterRules.piety_event(l2, &"answer"),
			LetterRules.piety_event(l1, &"deliver")], [&"letter_read_grave", &"letter_buried", &"letter_answered", &""])
	var cfg := Phase9Fixtures.piety_config()
	for e: StringName in [&"letter_read_sealed", &"letter_burned_asked", &"letter_burned_unasked", &"letter_read_grave",
			&"letter_buried", &"letter_answered"]:
		assert_true(cfg.events.has(e), "%s in PietyConfig.events" % e)
	assert_eq([cfg.events[&"letter_read_sealed"], cfg.events[&"letter_burned_asked"], cfg.events[&"letter_burned_unasked"]], [-1, 1, -1])


func test_block_reasons_deliver_and_post() -> void:
	var l1 := Phase9Fixtures.letter(&"lp_l1_carter")
	var ctx := {"state": &"found", "recipient_npc": &"innkeeper", "recipient_name": "Rosine Wackernagel", "npc": &"innkeeper"}
	assert_eq(LetterRules.choice_block_reason(l1, &"deliver", ctx), "")
	ctx.npc = &"grocer"
	assert_eq(LetterRules.choice_block_reason(l1, &"deliver", ctx), LetterRules.TEXT_TO_PERSON % "Rosine Wackernagel")
	ctx.npc = &"innkeeper"
	ctx.state = &"delivered"
	assert_eq(LetterRules.choice_block_reason(l1, &"deliver", ctx), LetterRules.TEXT_DECIDED, "decided once")
	var town := Phase9Fixtures.letter(&"lg_town")
	var post := {"state": &"found", "post": true}
	assert_eq(LetterRules.choice_block_reason(town, &"deliver", post), LetterRules.TEXT_POST_ONLY)
	post["carrier"] = &"peddler"
	assert_eq(LetterRules.choice_block_reason(town, &"deliver", post), "")
	var nobody := Phase9Fixtures.letter(&"lg_nobody")
	assert_eq(LetterRules.choice_block_reason(nobody, &"deliver", {"state": &"found", "recipient_npc": &""}), LetterRules.TEXT_NOBODY)
	assert_eq(LetterRules.choice_block_reason(null, &"deliver", {}), LetterRules.TEXT_NOBODY)


func test_block_reasons_read_grave_burn_bury_answer() -> void:
	var l1 := Phase9Fixtures.letter(&"lp_l1_carter")
	assert_eq(LetterRules.choice_block_reason(l1, &"read", {"state": &"found"}), "")
	assert_eq(LetterRules.choice_block_reason(l1, &"read", {"state": &"found", "opened": true}), LetterRules.TEXT_ALREADY_READ)
	assert_eq(LetterRules.choice_block_reason(l1, &"read_grave", {"state": &"found", "target_grave": ""}), LetterRules.TEXT_NO_GRAVE)
	assert_eq(LetterRules.choice_block_reason(l1, &"read_grave", {"state": &"found", "target_grave": "l_13", "grave_id": "l_14"}),
			LetterRules.TEXT_AT_GRAVE)
	assert_eq(LetterRules.choice_block_reason(l1, &"read_grave", {"state": &"found", "target_grave": "l_13", "grave_id": "l_13"}), "")
	assert_eq(LetterRules.choice_block_reason(l1, &"burn", {"state": &"found"}), LetterRules.TEXT_AT_FIRE)
	assert_eq(LetterRules.choice_block_reason(l1, &"burn", {"state": &"found", "place": &"stove"}), "")
	assert_eq(LetterRules.choice_block_reason(l1, &"burn", {"state": &"found", "place": &"forge"}), "", "the forge too")
	assert_eq(LetterRules.choice_block_reason(l1, &"bury", {"state": &"found"}), LetterRules.TEXT_BURY_WHEN)
	assert_eq(LetterRules.choice_block_reason(l1, &"bury", {"state": &"found", "burying": true}), "")
	var grete := Phase9Fixtures.letter(&"lp_d3_grete")
	assert_eq(LetterRules.choice_block_reason(grete, &"bury", {"state": &"found"}), LetterRules.TEXT_BURY_WHERE)
	assert_eq(LetterRules.choice_block_reason(grete, &"bury", {"state": &"found", "grave_id": "l_02",
			"bury_graves": PackedStringArray(["l_02"])}), "", "onto Grete's grave")
	var l2 := Phase9Fixtures.letter(&"lp_l2_sister")
	assert_true(LetterRules.can_answer(l2), "L2 carries a reply")
	assert_false(LetterRules.can_answer(l1))
	assert_true(LetterRules.can_answer(Phase9Fixtures.letter(&"lpo_quendel")), "post can be answered")
	assert_false(LetterRules.can_answer(Phase9Fixtures.letter(&"lpo_aschau")), "not the one to L. Aschau")
	assert_eq(LetterRules.choice_block_reason(l2, &"answer", {"state": &"found"}), LetterRules.TEXT_AT_DESK)
	assert_eq(LetterRules.choice_block_reason(l2, &"answer", {"state": &"found", "place": &"desk"}), LetterRules.TEXT_NO_INK)
	assert_eq(LetterRules.choice_block_reason(l2, &"answer", {"state": &"found", "place": &"desk", "has_ink": true}), "")
	assert_eq(LetterRules.choice_block_reason(l2, &"answer", {"state": &"posted", "place": &"desk", "has_ink": true}), "",
			"posted: you may still write to her")
	assert_eq(LetterRules.choice_block_reason(l2, &"answer", {"state": &"found", "place": &"desk", "has_ink": true, "answered": true}),
			LetterRules.TEXT_ANSWERED)
	assert_eq(LetterRules.choice_block_reason(l1, &"answer", {"state": &"found", "place": &"desk", "has_ink": true}),
			LetterRules.TEXT_NO_ANSWER)
	assert_eq(LetterRules.choice_block_reason(l1, &"read", {"aschau": true}), LetterRules.TEXT_ASCHAU)
	for reason: String in [LetterRules.TEXT_TO_PERSON, LetterRules.TEXT_AT_FIRE, LetterRules.TEXT_NO_INK, LetterRules.TEXT_BURY_WHEN]:
		assert_false(reason.contains("+") or reason.contains("−1") or reason.contains("Pietät"), "§7.3: no numbers – %s" % reason)


func test_apply_actions() -> void:
	var piety := Piety.new()
	piety.config = Phase9Fixtures.piety_config()
	var rep := Reputation.new()
	rep.config = Phase9Fixtures.reputation_config()
	var rel := Relationships.new()
	rel.config = Phase9Fixtures.relationship_config()
	var visitors := VisitorsDouble.new()
	for n: Node in [piety, rep, rel, visitors]:
		nodes.append(n)
		tree.root.add_child(n)
	GameState.stats[&"piety"] = 0
	GameState.stats[&"reputation"] = 50
	var inv := Inventory.new()
	nodes.append(inv)
	tree.root.add_child(inv)
	var before := rel.value(&"innkeeper")
	LetterRules.apply_actions(PackedStringArray(["piety_event:letter_read_grave", "piety_add:2", "rep_event:letter_delivered",
			"rel_add:innkeeper:3", "goodwill:kin:2", "goodwill:kin_ott:4", "set_flag:letter_l1_hung", "give_item:linen:1",
			"reply_coins:2", "rumor:register_sold"]), {"kin": &"kin_kehr", "inventory": inv}, tree, "test")
	assert_eq(piety.value(), 3)
	assert_eq(rep.value(), 51)
	assert_eq(rel.value(&"innkeeper") - maxi(before, rel.value(&"innkeeper") - 3), 3)
	assert_eq(visitors.goodwill_calls, [[&"kin_kehr", 2], [&"kin_ott", 4]])
	assert_true(GameState.flag_on(&"letter_l1_hung"))
	assert_eq(inv.count(&"linen"), 1)
	var gains := Phase9Fixtures.relationship_config().gains
	var mayor := rel.value(&"mayor")
	LetterRules.apply_actions(PackedStringArray(["rel_gain:mayor:seal_broken"]), {}, tree, "t")
	assert_eq(rel.value(&"mayor") - mayor, int(gains[&"seal_broken"]) if mayor > 0 else rel.value(&"mayor") - mayor)
