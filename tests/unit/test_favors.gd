extends TestCase
## Phase 8 (P4, docs/PHASE8_DESIGN.md §2.4 „Gefallen & Gegengefallen", §3.4, §10): FavorRules + the favours
## of Friendship – only after step 3, once per 5 days, every effect (Rosine's shield, Esch's iron / loaned
## mortsafe, Theres' order at Hanne's price, Lenz' prayer, Fenner's night watchman, Quast's medicine,
## Liesel's corpse wash), the return favour the day after (friend order, 3 days): returned +4, unreturned
## −6 and 7 days rest; save / load. Doubles for relationships, reputation, mood, the player, the graves,
## the crypt table and CorpseCare.

const COIN := &"coin"


class RelDouble extends Relationships:
	var vals: Dictionary = {}

	func value(npc_id: StringName) -> int:
		return int(vals.get(npc_id, 0))

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		vals[npc_id] = clampi(value(npc_id) + delta, 0, 100)
		return value(npc_id)


class RepDouble extends Reputation:
	var calls: Array = []

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


class LifeDouble extends Node:
	var moods: Dictionary = {}

	func _init() -> void:
		add_to_group(&"npc_life")

	func mood(npc_id: StringName) -> StringName:
		return moods.get(npc_id, &"plain")

	func check_goal() -> bool:
		return false


class PlayerDouble extends Node:
	var inventory: Inventory

	func _init() -> void:
		add_to_group(&"player")


class GravesDouble extends Node:
	var graves: Dictionary = {}

	func _init() -> void:
		add_to_group(&"graveyard")

	func get_grave(id: String) -> GraveRecord:
		return graves.get(id)


class TableDouble extends Node:
	var corpse_id: String = ""

	func _init() -> void:
		add_to_group(&"morgue_table")


class CareDouble extends Node:
	var records: Dictionary = {}
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"corpse_care")

	func get_record(id: String) -> CorpseRecord:
		return records.get(id)

	func wash(id: String, _inv: Inventory) -> bool:
		calls.append(["wash", id])
		(records[id] as CorpseRecord).washed = true
		return true

	func dress(id: String, kind: StringName, inv: Inventory) -> bool:
		if not inv.remove_item(&"burial_gown" if kind == &"gown" else &"shroud", 1):
			return false
		calls.append(["dress", id, kind])
		(records[id] as CorpseRecord).shrouded = true
		return true


var friendship: Friendship
var orders: Orders
var rel: RelDouble
var rep: RepDouble
var life: LifeDouble
var player: PlayerDouble
var graves: GravesDouble
var favor_changes: Array = []
var _nodes: Array[Node] = []
var _day: int
var _minute: int
var _flags: Dictionary
var _stats: Dictionary
var _injected: Array[StringName] = []


func before_each() -> void:
	_day = TimeManager.day
	_minute = TimeManager.minute_of_day
	_flags = GameState.flags.duplicate(true)
	_stats = GameState.stats.duplicate(true)
	for id: StringName in Phase8Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase8Fixtures.item(id)
			_injected.append(id)
	TimeManager.day = 60
	TimeManager.minute_of_day = 600
	Phase8Fixtures.p8_open(null, 53).free()
	orders = Orders.new()
	orders.config = Phase8Fixtures.orders_config()
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	friendship = Friendship.new()
	friendship.relationship_config = Phase8Fixtures.relationship_config()
	friendship.peddler_shop = Phase8Fixtures.shop(&"peddler")
	for s: FriendStoryData in Phase8Fixtures.friend_stories():
		friendship.story_table[s.npc_id] = s
	for f: FavorData in Phase8Fixtures.favors():
		friendship.favor_table[f.id] = f
	var full := {}
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		full[String(npc)] = 3
	friendship.load_state({"steps": full})
	rel = RelDouble.new()
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		rel.vals[npc] = 75
	rep = RepDouble.new()
	life = LifeDouble.new()
	player = PlayerDouble.new()
	player.inventory = Phase7Fixtures.inv_with()
	player.add_child(player.inventory)
	graves = GravesDouble.new()
	_nodes = [orders, friendship, rel, rep, life, player, graves]
	for n: Node in _nodes:
		tree.root.add_child(n)
	favor_changes.clear()
	EventBus.favor_changed.connect(_on_favor)


func after_each() -> void:
	EventBus.favor_changed.disconnect(_on_favor)
	for n: Node in _nodes:
		n.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	TimeManager.day = _day
	TimeManager.minute_of_day = _minute
	GameState.flags.clear()
	GameState.flags.merge(_flags)
	GameState.stats.clear()
	GameState.stats.merge(_stats)


func _on_favor(npc_id: StringName, favor_id: StringName, state: StringName) -> void:
	favor_changes.append([npc_id, favor_id, state])


func _inv() -> Inventory:
	return player.inventory


func _add(n: Node) -> void:
	_nodes.append(n)
	tree.root.add_child(n)


# --- FavorRules ------------------------------------------------------------------------------------

func test_rules_story_cooldown_lock_owed_mood() -> void:
	var f := Phase8Fixtures.favor(&"fav_smith")
	assert_eq(FavorRules.block_reason(null, {}), FavorRules.TEXT_NO_FAVOR)
	assert_eq(FavorRules.block_reason(f, {"done": 2, "day": 60}), FavorRules.TEXT_STORY, "after step 3 only")
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60}), "")
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60, "favor_day": 56}), FavorRules.TEXT_COOLDOWN_ONE)
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60, "favor_day": 57}), FavorRules.TEXT_COOLDOWN % 2)
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 61, "favor_day": 56}), "", "five days later")
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60, "locked_until": 61}), FavorRules.TEXT_LOCKED)
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60, "owed": true}), FavorRules.TEXT_OWED)
	assert_eq(FavorRules.block_reason(f, {"done": 3, "day": 60, "mood": &"cross"}), FavorRules.TEXT_MOOD)
	assert_eq([FavorRules.offer_day(f, 60), FavorRules.deadline_day(f, 61)], [61, 64], "the day after, 3 days")
	var pick := FavorRules.pick_return(f, 61)
	assert_true(f.return_orders.has(pick))
	assert_eq(FavorRules.pick_return(f, 61), pick, "deterministic")
	var other: StringName = f.return_orders[0] if pick == f.return_orders[1] else f.return_orders[1]
	assert_eq(FavorRules.pick_return(f, 61, [pick]), other, "a running one is skipped")
	assert_eq(FavorRules.choice(f, &"").choice, &"iron_fittings", "first choice")
	assert_eq([FavorRules.choice(f, &"steel_rod").amount, FavorRules.choice(f, &"mortsafe_loan").amount], [1, 10])
	assert_false(FavorRules.choice(f, &"gold").ok)
	assert_eq([FavorRules.night_of(60, 359), FavorRules.night_of(60, 360), FavorRules.night_of(60, 1300)], [59, 60, 60])


# --- effects -----------------------------------------------------------------------------------------

func test_rosine_shield_once_within_five_days() -> void:
	assert_false(friendship.favor_shield_active())
	assert_true(friendship.use_favor(&"innkeeper"))
	assert_eq(favor_changes, [[&"innkeeper", &"fav_innkeeper", &"used"]])
	assert_eq(GameState.get_stat(&"favors_used"), 1)
	assert_true(friendship.favor_shield_active())
	assert_false(friendship.consume_shield(&"wish_done"), "not talk")
	assert_true(friendship.consume_shield(&"lecture_rumor"), "Rosine talks it small")
	assert_false(friendship.consume_shield(&"visit_neglected"), "once")
	friendship.load_state(friendship.save_state().merged({"shield": 65}, true))
	TimeManager.day = 64
	assert_true(friendship.consume_shield(&"grave_disturbed"))
	friendship.load_state(friendship.save_state().merged({"shield": 65}, true))
	TimeManager.day = 65
	assert_false(friendship.favor_shield_active(), "five days")


func test_esch_iron_and_the_loaned_mortsafe() -> void:
	assert_false(friendship.use_favor(&"smith", &"gold"), "unknown choice")
	assert_true(friendship.use_favor(&"smith"))
	assert_eq(_inv().count(&"iron_fittings"), 3)
	friendship.load_state(friendship.save_state().merged({"favor_day": {}}, true))
	assert_true(friendship.use_favor(&"smith", &"mortsafe_loan"))
	assert_eq(_inv().count(&"mortsafe"), 1, "a mortsafe for 10 days")
	friendship.apply_morning(69)
	assert_eq(_inv().count(&"mortsafe"), 1)
	friendship.apply_morning(70)
	assert_eq(_inv().count(&"mortsafe"), 0, "Esch takes it back")
	friendship.load_state(friendship.save_state().merged({"favor_day": {}, "owed": {}, "return_for": {}}, true))
	assert_true(friendship.use_favor(&"smith", &"steel_rod"))
	assert_eq(_inv().count(&"steel_rod"), 1)


func test_theres_orders_a_ware_at_hannes_price() -> void:
	assert_false(friendship.use_favor(&"grocer"), "which ware?")
	assert_false(friendship.use_favor(&"grocer", &"iron_bar"), "not in Hanne's basket")
	assert_true(friendship.use_favor(&"grocer", &"wax_wreath"))
	assert_eq(friendship.ware_ready(), {}, "the next morning")
	_inv().add_item(COIN, 7)
	assert_false(friendship.take_ware(_inv()))
	TimeManager.day = 61
	assert_eq(friendship.ware_ready().get("price"), 5, "Hanne's price")
	assert_true(friendship.take_ware(_inv()))
	assert_eq([_inv().count(&"wax_wreath"), _inv().count(COIN), GameState.get_stat(&"coins_spent_peddler")], [1, 2, 5])
	assert_false(friendship.take_ware(_inv()), "once")


func test_lenz_prayer_for_three_nights() -> void:
	var g := GraveRecord.new()
	g.id = "l_02"
	g.state = GraveRecord.State.MARKED
	graves.graves["l_02"] = g
	assert_false(friendship.use_favor(&"priest", &"nope"), "a grave of the yard")
	assert_true(friendship.use_favor(&"priest", &"l_02"))
	assert_eq([friendship.prayer_bonus("l_02"), friendship.prayer_bonus("l_03")], [3, 0])
	TimeManager.day = 62
	TimeManager.minute_of_day = 1300
	assert_eq(friendship.prayer_bonus("l_02"), 3, "third night")
	TimeManager.day = 63
	TimeManager.minute_of_day = 200
	assert_eq(friendship.prayer_bonus("l_02"), 3, "still the third night before 06:00")
	TimeManager.minute_of_day = 1300
	assert_eq(friendship.prayer_bonus("l_02"), 0, "three nights")


func test_fenner_night_watchman() -> void:
	assert_false(friendship.night_watch_tonight())
	assert_false(friendship.use_favor(&"mayor", &"59"), "not a past night")
	assert_true(friendship.use_favor(&"mayor", &"61"))
	assert_has(rep.calls, ["event", &"fenner_watch", "Gefallen: Der Nachtwächter"], "Ruf +1")
	assert_false(friendship.night_watch_tonight(), "tonight is night 60")
	TimeManager.day = 61
	TimeManager.minute_of_day = 1320
	assert_true(friendship.night_watch_tonight())
	TimeManager.day = 62
	TimeManager.minute_of_day = 100
	assert_true(friendship.night_watch_tonight(), "02:00 belongs to night 61")
	TimeManager.minute_of_day = 1320
	assert_false(friendship.night_watch_tonight())


func test_quast_medicine() -> void:
	assert_true(friendship.use_favor(&"surgeon"))
	assert_eq(_inv().count(&"fever_tincture"), 2)
	assert_false(friendship.use_favor(&"surgeon"), "cooldown")
	assert_eq(friendship.favor_block_reason(&"surgeon"), FavorRules.TEXT_OWED, "the return favour comes first")


func test_liesel_corpse_wash_at_the_crypt_table() -> void:
	assert_false(friendship.use_favor(&"washer"), "no dead on the table")
	var table := TableDouble.new()
	var care := CareDouble.new()
	var r := Phase5Fixtures.corpse(64, &"old_age", &"", 0)
	care.records[r.id] = r
	table.corpse_id = r.id
	_add(table)
	_add(care)
	_inv().add_item(&"shroud", 1)
	TimeManager.minute_of_day = 700
	assert_true(friendship.use_favor(&"washer"))
	assert_eq(friendship.wash_pending().day, 61, "after 09:40 – tomorrow morning")
	friendship.apply_minute(61, 600)
	assert_eq(care.calls, [], "visible 60 minutes")
	friendship.apply_minute(61, 640)
	assert_eq(care.calls, [["wash", r.id], ["dress", r.id, &"shroud"]], "washed and dressed with your shroud")
	assert_eq(friendship.wash_pending(), {})


# --- return favours ------------------------------------------------------------------------------------

func test_return_favour_returned_plus_four() -> void:
	assert_true(friendship.use_favor(&"smith"))
	friendship.apply_morning(60)
	assert_eq(friendship.favor_owed(&"smith"), &"", "not the same day")
	friendship.apply_morning(61)
	var id := friendship.favor_owed(&"smith")
	assert_true(Phase8Fixtures.favor(&"fav_smith").return_orders.has(id), "one of the pool")
	assert_eq(orders.state(id), Orders.STATE_ACCEPTED, "a friend order")
	assert_eq(orders.active_count(&""), 0, "no Phase-7 order")
	var o := orders.order_data(id)
	for item: StringName in o.items:
		_inv().add_item(item, o.items[item])
	TimeManager.day = 62
	assert_true(orders.turn_in(id, _inv()))
	assert_eq(rel.value(&"smith"), 79, "+4")
	assert_eq(favor_changes.back(), [&"smith", &"fav_smith", &"returned"])
	assert_eq(friendship.favor_owed(&"smith"), &"")
	assert_eq(GameState.get_stat(&"favors_returned"), 1)
	TimeManager.day = 65
	assert_eq(friendship.favor_block_reason(&"smith"), "", "five days after the favour")


func test_return_favour_unreturned_minus_six_and_rest() -> void:
	assert_true(friendship.use_favor(&"surgeon"))
	friendship.apply_morning(61)
	var id := friendship.favor_owed(&"surgeon")
	assert_ne(id, &"")
	friendship.apply_morning(63)
	assert_eq(orders.state(id), Orders.STATE_ACCEPTED, "3 days")
	TimeManager.day = 64
	friendship.apply_morning(64)
	assert_eq(orders.state(id), Orders.STATE_FAILED)
	assert_eq(rel.value(&"surgeon"), 69, "−6")
	assert_eq(favor_changes.back(), [&"surgeon", &"fav_surgeon", &"unreturned"])
	TimeManager.day = 70
	assert_eq(friendship.favor_block_reason(&"surgeon"), FavorRules.TEXT_LOCKED, "the favour rests 7 days")
	TimeManager.day = 71
	assert_eq(friendship.favor_block_reason(&"surgeon"), "")
	assert_true(friendship.use_favor(&"surgeon"), "the failed order may run again later")
	friendship.apply_morning(72)
	assert_eq(orders.state(friendship.favor_owed(&"surgeon")), Orders.STATE_ACCEPTED)


func test_save_load_mid_return_favour() -> void:
	assert_true(friendship.use_favor(&"innkeeper"))
	friendship.apply_morning(61)
	var saved := friendship.save_state()
	var other := Friendship.new()
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.save_state(), saved)
	assert_eq(other.favor_owed(&"innkeeper"), friendship.favor_owed(&"innkeeper"))
	other.free()
