class_name Friendship
extends Node
## Systems/Friendship (docs/PHASE8_DESIGN.md §2.4, §3.1, §3.3, §3.4, §5.1), groups &"friendship",
## &"saveable": the three-step story of each living villager (FriendStoryData; thresholds 40 / 55 / 70, a
## day between, not when „gereizt"), the friend orders (OrderData.category friend, their own limit in
## Orders), the favours (once per 5 days after step 3) and the return favours (offered the day after,
## 3 days; returned +4, unreturned −6 and 7 days rest).
## Orders.complete (category friend) → note_order_done → the step's reward (Relationships.add, Reputation,
## the flag friend_<npc>_<n>, stats.friend_steps, friend_step_completed, NpcLife.check_goal) or the return
## favour returned. Listeners change nothing; other systems are called through their groups.
## Saved (§5.1): {steps, step_day, favor_day, owed, owed_day, return_for, locked_until, shield, watch_night,
## prayer, loan_until, ware, wash, morning_day}.

const GROUP := &"friendship"
const FAVOR_USED := &"used"
const FAVOR_RETURNED := &"returned"
const FAVOR_UNRETURNED := &"unreturned"
const STEPS := 3
const OPEN_FLAG := &"p8_open"
const ORDERS_GROUP := &"orders"
const RELATIONSHIPS_GROUP := &"relationships"
const REPUTATION_GROUP := &"reputation"
const NPC_LIFE_GROUP := &"npc_life"
const APPRENTICE_GROUP := &"apprentice"
const PLAYER_GROUP := &"player"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_CARE_GROUP := &"corpse_care"
const MORGUE_TABLE_GROUP := &"morgue_table"
const SHOPS_FALLBACK := &"peddler"
const COIN_ITEM := &"coin"
const COIN_REASON_PEDDLER := &"peddler"
const MORTSAFE_ITEM := &"mortsafe"
const MORTSAFE_LOAN := &"mortsafe_loan"
const APPRENTICE_TASKS: Array[StringName] = [&"rake", &"weed", &"water", &"candle"]
const STAT_STEPS := &"friend_steps"
const STAT_FAVORS_USED := &"favors_used"
const STAT_FAVORS_RETURNED := &"favors_returned"
const REASON_STEP := "Geschichte: %s"
const REASON_RETURNED := "Gegengefallen: %s"
const REASON_UNRETURNED := "Gefallen nicht erwidert: %s"
const REASON_FAVOR := "Gefallen: %s"
const TEXT_SHIELD := "Rosine hat das Gerede im Krug kleingeredet."
const TEXT_WASH_DONE := "Liesel hat den Toten gewaschen und eingekleidet."
const TEXT_LOAN_BACK := "Esch hat sein Grabgitter wieder abgeholt."
const TEXT_RETURN := "%s bittet um einen Gegengefallen: %s"
const MINUTES_PER_DAY := 1440
const MORNING_MINUTE := 360

@export var save_id: String = "friendship"
@export var save_order: int = 74

## Stories by npc_id; empty = Database.friend_stories() (tests inject fixtures).
var story_table: Dictionary[StringName, FriendStoryData] = {}
## Favours by id; empty = Database.favors().
var favor_table: Dictionary[StringName, FavorData] = {}
## Gains (friend_step_<n>); null = data/config/relationship_config.tres.
var relationship_config: RelationshipConfig
## The shop whose prices Theres' order uses („zu Hannes Preis"); null = Database.shop(&"peddler").
var peddler_shop: ShopData

var _steps: Dictionary[StringName, int] = {}
var _step_day: Dictionary[StringName, int] = {}
var _favor_day: Dictionary[StringName, int] = {}
## Return favour order per npc and the day it was offered; return_for = the favour day it belongs to.
var _owed: Dictionary[StringName, StringName] = {}
var _owed_day: Dictionary[StringName, int] = {}
var _return_for: Dictionary[StringName, int] = {}
var _locked_until: Dictionary[StringName, int] = {}
## Rosine's shield: active while day < _shield (0 = none).
var _shield: int = 0
## Fenner's night watchman: the night (its evening's day) without robber (0 = none).
var _watch_night: int = 0
## Lenz' prayer {grave, from, until} (nights from … until − 1).
var _prayer: Dictionary = {}
## Esch's loaned mortsafe goes back on this morning (0 = none).
var _loan_until: int = 0
## Theres' order {item, day, price} – in her shop from that morning.
var _ware: Dictionary = {}
## Liesel's corpse wash {day, minute, minutes, corpse}.
var _wash: Dictionary = {}
var _morning_day: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- stories ---------------------------------------------------------------------------------------

## 0…3.
func step_done(npc_id: StringName) -> int:
	return clampi(int(_steps.get(npc_id, 0)), 0, STEPS)


## The story of `npc_id` (story_table / Database) or null.
func story(npc_id: StringName) -> FriendStoryData:
	if not story_table.is_empty():
		return story_table.get(npc_id)
	return Database.friend_story(npc_id) as FriendStoryData


## Ids of the villagers with a story (sorted).
func story_npcs() -> Array[StringName]:
	var out: Array[StringName] = []
	if not story_table.is_empty():
		out.assign(story_table.keys())
	else:
		for s: Variant in Database.friend_stories():
			if s is FriendStoryData:
				out.append((s as FriendStoryData).npc_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## 0 = none (threshold, mood cross, gap).
func offerable_step(npc_id: StringName) -> int:
	return FriendRules.offerable_step(story(npc_id), _ctx(npc_id))


## "" = the next step can be offered; else why not (for the dialogue / the notebook).
func step_block_reason(npc_id: StringName) -> String:
	return FriendRules.step_block_reason(story(npc_id), _ctx(npc_id))


## The order of the next step (the first variant that may be taken); &"" = none.
func step_order(npc_id: StringName) -> StringName:
	var s := story(npc_id)
	var n := step_done(npc_id)
	if s == null or n >= mini(STEPS, s.steps.size()):
		return &""
	return FriendRules.order_for(s.steps[n], _order_ok)


## Takes the order of_*.
func accept_step(npc_id: StringName) -> bool:
	if offerable_step(npc_id) == 0:
		return false
	var id := step_order(npc_id)
	var orders := _first(ORDERS_GROUP)
	if id == &"" or orders == null or not orders.has_method(&"accept"):
		return false
	return bool(orders.call(&"accept", id))


## Orders → the step done → friend_step_completed, the reward; or a return favour returned.
func note_order_done(order_id: StringName) -> void:
	for npc: StringName in story_npcs():
		var n := FriendRules.step_of_order(story(npc), order_id)
		if n > 0 and n == step_done(npc) + 1:
			_complete_step(npc, n)
			return
	for npc: StringName in _owed.keys():
		if _owed[npc] == order_id:
			_returned(npc)
			return


func steps_total() -> int:
	var n := 0
	for npc: StringName in _steps:
		n += step_done(npc)
	return n


func full_stories() -> int:
	var n := 0
	for npc: StringName in _steps:
		if step_done(npc) >= STEPS:
			n += 1
	return n


# --- favours ---------------------------------------------------------------------------------------

## The favour of `npc_id` (its story's favor_id) or null.
func favor(npc_id: StringName) -> FavorData:
	var s := story(npc_id)
	var id := s.favor_id if s != null else StringName("fav_" + String(npc_id))
	if not favor_table.is_empty():
		return favor_table.get(id)
	return Database.favor(id) as FavorData


func favor_block_reason(npc_id: StringName) -> String:
	return FavorRules.block_reason(favor(npc_id), {"done": step_done(npc_id), "day": TimeManager.day,
			"favor_day": int(_favor_day.get(npc_id, 0)), "locked_until": int(_locked_until.get(npc_id, 0)),
			"owed": _owed.has(npc_id) or _pending_return(npc_id), "mood": _mood(npc_id)})


## The return favour `npc_id` waits for (&"" = none).
func favor_owed(npc_id: StringName) -> StringName:
	return _owed.get(npc_id, &"")


## Asks the favour (§2.4); `choice`: Esch iron_fittings | steel_rod | mortsafe_loan, Theres the ware id,
## Lenz the grave id, Fenner the night (its evening's day; &"" = tonight).
func use_favor(npc_id: StringName, choice: StringName = &"") -> bool:
	var f := favor(npc_id)
	if f == null or favor_block_reason(npc_id) != "":
		return false
	if not _apply_favor(f, choice):
		return false
	_favor_day[npc_id] = TimeManager.day
	GameState.add_stat(STAT_FAVORS_USED, 1)
	EventBus.favor_changed.emit(npc_id, f.id, FAVOR_USED)
	return true


## Rosine's „Ein Wort im Krug".
func favor_shield_active() -> bool:
	return _shield > 0 and TimeManager.day < _shield


## The next reputation minus from talk (`event` in the favour's events) falls away – once.
func consume_shield(event: StringName) -> bool:
	if not favor_shield_active():
		return false
	var f := favor(&"innkeeper")
	var events: Variant = f.params.get("events", []) if f != null else []
	if events is Array and not (events.has(event) or events.has(String(event))):
		return false
	_shield = 0
	EventBus.notification_requested.emit(TEXT_SHIELD, &"info")
	return true


## Fenner's night watchman.
func night_watch_tonight() -> bool:
	return _watch_night > 0 and FavorRules.night_of(TimeManager.day, TimeManager.minute_of_day) == _watch_night


## Lenz' „Fürbitte": the ghost bonus of `grave_id` tonight (GhostMood's own item prayer; 0 = none).
func prayer_bonus(grave_id: String) -> int:
	if _prayer.is_empty() or str(_prayer.get("grave", "")) != grave_id:
		return 0
	var night := FavorRules.night_of(TimeManager.day, TimeManager.minute_of_day)
	if night < int(_prayer.get("from", 0)) or night >= int(_prayer.get("until", 0)):
		return 0
	var f := favor(&"priest")
	return int(f.params.get("mood", 3)) if f != null else 3


## Theres' order: {item, day, price} once it is in her shop (day reached), else {}.
func ware_ready() -> Dictionary:
	if _ware.is_empty() or TimeManager.day < int(_ware.get("day", 0)):
		return {}
	return _ware.duplicate()


## Buys Theres' order at Hanne's price (coins out of `inv`, coins_spent peddler); false = none / short.
func take_ware(inv: Inventory) -> bool:
	var ware := ware_ready()
	if ware.is_empty() or inv == null:
		return false
	var price := int(ware.get("price", 0))
	var item := StringName(str(ware.get("item", "")))
	if inv.count(COIN_ITEM) < price or not inv.can_add(item, 1):
		return false
	if price > 0 and not inv.remove_item(COIN_ITEM, price):
		return false
	inv.add_item(item, 1)
	GameState.note_coins_spent(price, COIN_REASON_PEDDLER)
	_ware.clear()
	return true


## Liesel's corpse wash on its way: {day, minute, minutes, corpse} or {}.
func wash_pending() -> Dictionary:
	return _wash.duplicate()


## Offer / let lapse the return favours.
func apply_morning(day: int) -> void:
	if day <= _morning_day:
		return
	_morning_day = day
	var orders := _first(ORDERS_GROUP)
	# Lapsed return favours: −6 and the favour rests.
	for npc: StringName in _owed.keys():
		var f := favor(npc)
		var id: StringName = _owed[npc]
		var st: StringName = orders.call(&"state", id) if orders != null else &""
		if st == Orders.STATE_COMPLETED:
			_returned(npc)
			continue
		if f != null and day >= FavorRules.deadline_day(f, int(_owed_day.get(npc, day))):
			if orders != null and st == Orders.STATE_ACCEPTED:
				orders.call(&"fail", id)
			_unreturned(npc)
	# New return favours: the day after a favour.
	var busy: Array = orders.call(&"active") if orders != null else []
	for npc: StringName in _favor_day.keys():
		var f := favor(npc)
		var used := int(_favor_day[npc])
		if f == null or _owed.has(npc) or int(_return_for.get(npc, -1)) == used or day < FavorRules.offer_day(f, used):
			continue
		_return_for[npc] = used
		var id := FavorRules.pick_return(f, day, busy)
		if id == &"" or orders == null or not bool(orders.call(&"accept_owed", id)):
			continue
		_owed[npc] = id
		_owed_day[npc] = day
		var o := orders.call(&"order_data", id) as OrderData
		EventBus.notification_requested.emit(TEXT_RETURN % [_npc_name(npc), o.title if o != null else String(id)], &"info")
	# Esch's loan goes back.
	if _loan_until > 0 and day >= _loan_until:
		_loan_until = 0
		var inv := _player_inventory()
		if inv != null and inv.remove_item(MORTSAFE_ITEM, 1):
			EventBus.notification_requested.emit(TEXT_LOAN_BACK, &"info")
	if _shield > 0 and day >= _shield:
		_shield = 0
	if not _prayer.is_empty() and day > int(_prayer.get("until", 0)):
		_prayer.clear()


## Liesel's wash ends: the steps „waschen" and „einkleiden" done on the corpse (linen / shroud from the
## player's inventory, CorpseCare). Called every tick.
func apply_minute(day: int, minute: int) -> void:
	if _wash.is_empty():
		return
	var end := (int(_wash.get("day", 0)) - 1) * MINUTES_PER_DAY + int(_wash.get("minute", 0)) + int(_wash.get("minutes", 0))
	if (day - 1) * MINUTES_PER_DAY + minute < end:
		return
	var corpse := str(_wash.get("corpse", ""))
	_wash.clear()
	var care := _first(CORPSE_CARE_GROUP)
	var inv := _player_inventory()
	if care == null or inv == null or corpse == "":
		return
	var done := false
	if care.has_method(&"wash") and bool(care.call(&"wash", corpse, inv)):
		done = true
	if care.has_method(&"dress"):
		for kind: StringName in [&"gown", &"shroud"]:
			if bool(care.call(&"dress", corpse, kind, inv)):
				done = true
				break
	if done:
		EventBus.notification_requested.emit(TEXT_WASH_DONE, &"info")


## §5.1.
func save_state() -> Dictionary:
	return {"steps": _str_int(_steps), "step_day": _str_int(_step_day), "favor_day": _str_int(_favor_day),
			"owed": _str_str(_owed), "owed_day": _str_int(_owed_day), "return_for": _str_int(_return_for),
			"locked_until": _str_int(_locked_until), "shield": _shield, "watch_night": _watch_night,
			"prayer": _prayer.duplicate(), "loan_until": _loan_until, "ware": _ware.duplicate(), "wash": _wash.duplicate(),
			"morning_day": _morning_day}


## Tolerant: steps 0…3, numbers ≥ 0, unknown shapes dropped.
func load_state(data: Dictionary) -> void:
	_steps = _int_dict(data.get("steps"), 0, STEPS)
	_step_day = _int_dict(data.get("step_day"), 0, 1 << 30)
	_favor_day = _int_dict(data.get("favor_day"), 0, 1 << 30)
	_owed_day = _int_dict(data.get("owed_day"), 0, 1 << 30)
	_return_for = _int_dict(data.get("return_for"), 0, 1 << 30)
	_locked_until = _int_dict(data.get("locked_until"), 0, 1 << 30)
	_owed.clear()
	var owed: Variant = data.get("owed")
	if owed is Dictionary:
		for key: Variant in owed:
			var v: Variant = (owed as Dictionary)[key]
			if (v is String or v is StringName) and str(v) != "":
				_owed[StringName(str(key))] = StringName(str(v))
	_shield = maxi(0, _num(data.get("shield"), 0))
	_watch_night = maxi(0, _num(data.get("watch_night"), 0))
	_loan_until = maxi(0, _num(data.get("loan_until"), 0))
	_morning_day = maxi(0, _num(data.get("morning_day"), 0))
	_prayer = _shape(data.get("prayer"), {"grave": "", "from": 0, "until": 0})
	_ware = _shape(data.get("ware"), {"item": "", "day": 0, "price": 0})
	_wash = _shape(data.get("wash"), {"day": 0, "minute": 0, "minutes": 0, "corpse": ""})


# --- internals -------------------------------------------------------------------------------------

func _ctx(npc_id: StringName) -> Dictionary:
	var id := step_order(npc_id)
	var orders := _first(ORDERS_GROUP)
	var running: bool = id != &"" and orders != null and orders.call(&"state", id) == Orders.STATE_ACCEPTED
	var s := story(npc_id)
	if s != null and not running and orders != null:
		var n := step_done(npc_id)
		if n < s.steps.size():
			for other: StringName in s.steps[n].order_ids:
				if orders.call(&"state", other) == Orders.STATE_ACCEPTED:
					running = true
	return {"open": GameState.flag_on(OPEN_FLAG), "done": step_done(npc_id), "value": _rel_value(npc_id),
			"day": TimeManager.day, "step_day": int(_step_day.get(npc_id, 0)), "mood": _mood(npc_id), "running": running,
			"conditions": _condition, "order_ok": _order_ok}


func _complete_step(npc_id: StringName, n: int) -> void:
	var s := story(npc_id)
	var step := s.steps[n - 1] if s != null and n - 1 < s.steps.size() else null
	_steps[npc_id] = n
	_step_day[npc_id] = TimeManager.day
	var title := step.title if step != null else String(npc_id)
	var rel_gain := FriendRules.reward_rel(step, n, _rel_cfg().gains)
	_rel_add(npc_id, rel_gain, REASON_STEP % title)
	if step != null and step.reward_rep != 0:
		var rep := _first(REPUTATION_GROUP)
		if rep != null and rep.has_method(&"change"):
			rep.call(&"change", step.reward_rep, REASON_STEP % title)
	var flag := step.reward_flag if step != null and step.reward_flag != &"" else StringName("friend_%s_%d" % [npc_id, n])
	GameState.set_flag(flag, true)
	GameState.add_stat(STAT_STEPS, 1)
	EventBus.friend_step_completed.emit(npc_id, n)
	var life := _first(NPC_LIFE_GROUP)
	if life != null and life.has_method(&"check_goal"):
		life.call(&"check_goal")


func _returned(npc_id: StringName) -> void:
	var f := favor(npc_id)
	_owed.erase(npc_id)
	_owed_day.erase(npc_id)
	if f == null:
		return
	_rel_add(npc_id, f.returned_rel, REASON_RETURNED % f.label)
	GameState.add_stat(STAT_FAVORS_RETURNED, 1)
	EventBus.favor_changed.emit(npc_id, f.id, FAVOR_RETURNED)


func _unreturned(npc_id: StringName) -> void:
	var f := favor(npc_id)
	_owed.erase(npc_id)
	_owed_day.erase(npc_id)
	if f == null:
		return
	_rel_add(npc_id, f.unreturned_rel, REASON_UNRETURNED % f.label)
	_locked_until[npc_id] = TimeManager.day + f.lock_days
	EventBus.favor_changed.emit(npc_id, f.id, FAVOR_UNRETURNED)


## A favour was used but its return favour is not offered yet (the day after).
func _pending_return(npc_id: StringName) -> bool:
	var used := int(_favor_day.get(npc_id, 0))
	var f := favor(npc_id)
	return used > 0 and f != null and not f.return_orders.is_empty() and int(_return_for.get(npc_id, -1)) != used


func _apply_favor(f: FavorData, choice: StringName) -> bool:
	var day := TimeManager.day
	match f.effect:
		&"rumor_shield":
			_shield = day + maxi(1, int(f.params.get("days", 5)))
			return true
		&"free_iron":
			var c := FavorRules.choice(f, choice)
			var inv := _player_inventory()
			if not bool(c.ok) or inv == null:
				return false
			if c.choice == MORTSAFE_LOAN:
				if inv.add_item(MORTSAFE_ITEM, 1) > 0:
					return false
				_loan_until = day + maxi(1, int(c.amount))
				return true
			return _give(inv, {c.choice: maxi(1, int(c.amount))})
		&"order_ware":
			var price := _ware_price(choice)
			if choice == &"" or price < 0:
				return false
			_ware = {"item": String(choice), "day": day + 1, "price": price}
			return true
		&"prayer":
			if not _prayer_grave_ok(String(choice)):
				return false
			var night := FavorRules.night_of(day, TimeManager.minute_of_day)
			_prayer = {"grave": String(choice), "from": night, "until": night + maxi(1, int(f.params.get("nights", 3)))}
			return true
		&"night_watch":
			var tonight := FavorRules.night_of(day, TimeManager.minute_of_day)
			var night := tonight if choice == &"" else (int(String(choice)) if String(choice).is_valid_int() else -1)
			if night < tonight:
				return false
			_watch_night = night
			var rep := _first(REPUTATION_GROUP)
			var kind := StringName(str(f.params.get("rep_event", "fenner_watch")))
			if rep != null and rep.has_method(&"event"):
				rep.call(&"event", kind, REASON_FAVOR % f.label)
			return true
		&"free_medicine":
			var inv := _player_inventory()
			return inv != null and _give(inv, FavorRules.items(f))
		&"corpse_wash":
			var corpse := _crypt_corpse()
			if corpse == "":
				return false
			var at := int(f.params.get("minute", 580))
			_wash = {"day": day if TimeManager.minute_of_day < at else day + 1, "minute": at,
					"minutes": int(f.params.get("minutes", 60)), "corpse": corpse}
			return true
	return false


func _give(inv: Inventory, items: Dictionary) -> bool:
	if items.is_empty():
		return false
	for item: Variant in items:
		if not inv.can_add(StringName(str(item)), int(items[item])):
			return false
	for item: Variant in items:
		inv.add_item(StringName(str(item)), int(items[item]))
	return true


## Hanne's price of `item` (her ShopData.sells); −1 = she does not carry it.
func _ware_price(item: StringName) -> int:
	var shop := peddler_shop
	if shop == null:
		var f := favor(&"grocer")
		var id := StringName(str(f.params.get("shop", SHOPS_FALLBACK))) if f != null else SHOPS_FALLBACK
		shop = Database.shop(id) as ShopData
	if shop == null or not shop.sells.has(item):
		return -1
	return int(shop.sells[item].get("price", 0))


## An occupied grave (FILLED / MARKED); without a Graveyard any non-empty id.
func _prayer_grave_ok(grave_id: String) -> bool:
	if grave_id == "":
		return false
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"get_grave"):
		return true
	var g := graveyard.call(&"get_grave", grave_id) as GraveRecord
	return g != null and (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED)


## The corpse on a morgue table (the crypt table) with washing or dressing still open; "" = none.
func _crypt_corpse() -> String:
	if not is_inside_tree():
		return ""
	var care := _first(CORPSE_CARE_GROUP)
	for node: Node in get_tree().get_nodes_in_group(MORGUE_TABLE_GROUP):
		var id := str(node.get(&"corpse_id")) if &"corpse_id" in node else ""
		if id == "" or id == "<null>":
			continue
		if care != null and care.has_method(&"get_record"):
			var r := care.call(&"get_record", id) as CorpseRecord
			if r == null or (r.washed and r.shrouded):
				continue
		return id
	return ""


func _condition(cond: String) -> bool:
	var levels := {}
	var apprentice := _first(APPRENTICE_GROUP)
	if apprentice != null and apprentice.has_method(&"level"):
		for task: StringName in APPRENTICE_TASKS:
			levels[task] = int(apprentice.call(&"level", task))
	var own := FriendRules.own_condition(cond, levels)
	if own >= 0:
		return own == 1
	return DialogueConditions.check(cond, {})


## The order variant may be taken: it exists and its requires_flag holds (Liesel 1: insight_not_lorenz).
func _order_ok(order_id: StringName) -> bool:
	var orders := _first(ORDERS_GROUP)
	var o: OrderData = orders.call(&"order_data", order_id) if orders != null else Database.order_data(order_id) as OrderData
	return o != null and (o.requires_flag == &"" or GameState.flag_on(o.requires_flag))


func _mood(npc_id: StringName) -> StringName:
	var life := _first(NPC_LIFE_GROUP)
	return StringName(str(life.call(&"mood", npc_id))) if life != null and life.has_method(&"mood") else &"plain"


func _rel_value(npc_id: StringName) -> int:
	var rel := _first(RELATIONSHIPS_GROUP)
	return int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0


func _rel_add(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(RELATIONSHIPS_GROUP)
	if rel != null and rel.has_method(&"add") and delta != 0:
		rel.call(&"add", npc_id, delta, reason)


func _npc_name(npc_id: StringName) -> String:
	var v := Database.villager(npc_id) if Database.has_method(&"villager") else null
	var n: Variant = v.get(&"display_name") if v != null else null
	return str(n) if n != null and str(n) != "" else String(npc_id)


func _player_inventory() -> Inventory:
	var player := _first(PLAYER_GROUP)
	if player == null:
		return null
	var inv: Variant = player.get(&"inventory")
	return inv as Inventory if inv is Inventory else null


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= MORNING_MINUTE and day > _morning_day:
		apply_morning(day)
	apply_minute(day, minute)


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _rel_cfg() -> RelationshipConfig:
	if relationship_config == null:
		relationship_config = Database.config(&"relationship_config") as RelationshipConfig
		if relationship_config == null:
			relationship_config = RelationshipConfig.new()
	return relationship_config


static func _str_int(d: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in d:
		out[str(key)] = int(d[key])
	return out


static func _str_str(d: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in d:
		out[str(key)] = str(d[key])
	return out


static func _int_dict(raw: Variant, lo: int, hi: int) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = (raw as Dictionary)[key]
			if v is int or v is float:
				out[StringName(str(key))] = clampi(int(v), lo, hi)
	return out


## `raw` with exactly the keys of `template` (types of the template; strings / numbers), {} when empty or
## malformed.
static func _shape(raw: Variant, template: Dictionary) -> Dictionary:
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return {}
	var out := {}
	for key: String in template:
		var v: Variant = (raw as Dictionary).get(key, template[key])
		if template[key] is String:
			out[key] = str(v) if (v is String or v is StringName) else String(template[key])
		else:
			out[key] = maxi(0, int(v)) if (v is int or v is float) else int(template[key])
	return out


static func _num(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
