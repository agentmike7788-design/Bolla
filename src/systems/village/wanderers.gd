class_name Wanderers
extends Node
## Systems/Wanderers (docs/PHASE8_DESIGN.md §2.6.1, §2.6.2, §3.1, §3.4, §5.1), groups &"wanderers", &"saveable",
## save_id wanderers / 76: Veit Ammer (alms once a day → GameState.note_coins_spent(1, &"alms"), piety alms,
## stats.alms_given; c_n_veit after 3 alms on different days or listening + 2 alms) and Hanne Vogelsang (every
## 6th day, day % 6 == 1, from p8_open: 10:00–14:00 at the well, 15:40–16:20 outside the graveyard gate – her
## shop is VillageShops' &"peddler" with one stock for the whole day over both stands; selling to her pays
## „Verkauf an Hanne").
## Both only from p8_open. Presence and places follow the clock (the Npc schedules are P6's, the places
## W-Welt's): Veit sits at the church door 08:00–11:30, on odd days 13:40–16:00 outside the graveyard gate,
## otherwise 13:00–17:00 on the Holder bridge, 18:06–19:30 on the bridge, 21:00–23:30 on the well bench.

const GROUP := &"wanderers"
const BEGGAR := &"beggar"
const PEDDLER := &"peddler"
const PAYMENT_REASON := "Verkauf an Hanne"
const COIN := &"coin"
const ALMS_REASON := &"alms"
const OPEN_FLAG := &"p8_open"
const STAT_ALMS := &"alms_given"
const REASON_ALMS := "Almosen für Veit"
## Places (waypoint ids of W-Welt, §4.3 G1–G2, §4.6 D4–D5).
const PLACE_CHURCH := &"v_church_step"
const PLACE_GATE := &"veit_gate"
const PLACE_BRIDGE := &"v_bridge_sit"
const PLACE_WELL_BENCH := &"v_well_bench"
const PLACE_PEDDLER_WELL := &"v_well_peddler"
const PLACE_PEDDLER_GATE := &"peddler_gate"
## Veit's day: [from, to, place]; odd days the gate replaces the bridge in the afternoon.
const BEGGAR_DAY: Array = [[480, 690, PLACE_CHURCH], [780, 1020, PLACE_BRIDGE], [1086, 1170, PLACE_BRIDGE],
		[1260, 1410, PLACE_WELL_BENCH]]
const BEGGAR_GATE: Array = [820, 960]
## Hanne's day: 09:30 over the bridge, the well 10:00–14:00, the gate 15:40–16:20, then up the forest path.
const PEDDLER_ARRIVE := 570
const PEDDLER_WELL: Array = [600, 840]
const PEDDLER_GATE: Array = [940, 980]
const PEDDLER_LEAVE := 1000
const TEXT_NOT_OPEN := ""
const TEXT_ABSENT := "Veit ist gerade nicht da."
const TEXT_TODAY := "Heute hast du Veit schon etwas gegeben."
const TEXT_NO_COIN := "Du hast keine Münze."

@export var save_id: String = "wanderers"
@export var save_order: int = 76

## Tests: the wanderers (empty = Database.wanderer).
var wanderer_data: Dictionary[StringName, WandererData] = {}

var _alms: int = 0
var _alms_day: int = -1
var _listened: bool = false
var _talks: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## The wanderer is in the world now (by his / her day and the clock; from p8_open).
func present(id: StringName) -> bool:
	return place(id, TimeManager.day, TimeManager.minute_of_day) != &""


## The place (waypoint id) of `id` at (day, minute), &"" = not about (asleep, away, before p8_open).
func place(id: StringName, day: int, minute: int) -> StringName:
	if not GameState.flag_on(OPEN_FLAG):
		return &""
	match id:
		BEGGAR:
			var odd := posmod(day, 2) == 1
			if odd and minute >= int(BEGGAR_GATE[0]) and minute < int(BEGGAR_GATE[1]):
				return PLACE_GATE
			for i: int in BEGGAR_DAY.size():
				var row: Array = BEGGAR_DAY[i]
				if i == 1 and odd:
					continue
				if minute >= int(row[0]) and minute < int(row[1]):
					return row[2]
			return &""
		PEDDLER:
			if not peddler_day(day):
				return &""
			if minute >= int(PEDDLER_WELL[0]) and minute < int(PEDDLER_WELL[1]):
				return PLACE_PEDDLER_WELL
			if minute >= int(PEDDLER_GATE[0]) and minute < int(PEDDLER_GATE[1]):
				return PLACE_PEDDLER_GATE
			if minute >= PEDDLER_ARRIVE and minute < PEDDLER_LEAVE:
				return &"on_the_way"
			return &""
	return &""


## Hanne's day (WandererData every_days / day_rest: day % 6 == 1).
func peddler_day(day: int) -> bool:
	var data := _data(PEDDLER)
	if data == null or data.every_days <= 0:
		return false
	return posmod(day, data.every_days) == data.day_rest


## The next day Hanne comes from `day` on (the journal card „nächster Besuch in 4 Tagen").
func next_peddler_day(day: int) -> int:
	for d: int in range(day, day + 60):
		if peddler_day(d):
			return d
	return -1


## The wanderer's shop sells now: Hanne at one of her two stands (VillageShops.is_open asks this).
func shop_open(shop_id: StringName) -> bool:
	var data := _data(PEDDLER)
	if data == null or data.shop_id != shop_id:
		return false
	var p := place(PEDDLER, TimeManager.day, TimeManager.minute_of_day)
	return p == PLACE_PEDDLER_WELL or p == PLACE_PEDDLER_GATE


## The shop belongs to a wanderer (VillageShops leaves its opening to shop_open).
func has_shop(shop_id: StringName) -> bool:
	var data := _data(PEDDLER)
	return data != null and shop_id != &"" and data.shop_id == shop_id


## "" or why no alms can be given now.
func alms_block_reason(inv: Inventory) -> String:
	var data := _data(BEGGAR)
	if data == null or not GameState.flag_on(OPEN_FLAG):
		return TEXT_ABSENT
	if not present(BEGGAR):
		return TEXT_ABSENT
	if _alms_day == TimeManager.day:
		return TEXT_TODAY
	if inv == null or inv.count(COIN) < maxi(data.alms_coins, 1):
		return TEXT_NO_COIN
	return ""


## coins_spent(1, &"alms"), piety alms, stats.alms_given, maybe c_n_veit.
func give_alms(inv: Inventory) -> bool:
	if alms_block_reason(inv) != "":
		return false
	var data := _data(BEGGAR)
	var coins := maxi(data.alms_coins, 1)
	if not inv.remove_item(COIN, coins):
		return false
	_alms += 1
	_alms_day = TimeManager.day
	GameState.note_coins_spent(coins, ALMS_REASON)
	GameState.add_stat(STAT_ALMS, 1)
	var piety := _first(&"piety")
	if piety != null and piety.has_method(&"event") and data.alms_piety != &"":
		piety.call(&"event", data.alms_piety, REASON_ALMS)
	_check_clue()
	return true


func alms_count() -> int:
	return _alms


## Veit was listened to (NpcLife „[Zuhören]" with Veit, P1/P6): listening + 2 alms also give c_n_veit.
func note_listen(id: StringName) -> void:
	if id != BEGGAR:
		return
	_listened = true
	_check_clue()


## A talk with `id` (Hanne's news rotate: news_index).
func note_talk(id: StringName) -> void:
	_talks[String(id)] = int(_talks.get(String(id), 0)) + 1


## How often the player talked with `id`.
func talks(id: StringName) -> int:
	return int(_talks.get(String(id), 0))


## {alms, alms_day, listened, talks} (§5.1; Hanne's stock lives in VillageShops, saved there).
func save_state() -> Dictionary:
	return {"alms": _alms, "alms_day": _alms_day, "listened": _listened, "talks": _talks.duplicate()}


func load_state(data: Dictionary) -> void:
	var a: Variant = data.get("alms", 0)
	_alms = maxi(0, int(a)) if a is int or a is float else 0
	var d: Variant = data.get("alms_day", -1)
	_alms_day = int(d) if d is int or d is float else -1
	_listened = typeof(data.get("listened")) == TYPE_BOOL and bool(data.get("listened"))
	_talks = {}
	var t: Variant = data.get("talks", {})
	if t is Dictionary:
		for key: Variant in t:
			var v: Variant = (t as Dictionary)[key]
			if v is int or v is float:
				_talks[str(key)] = maxi(0, int(v))


func _check_clue() -> void:
	var data := _data(BEGGAR)
	if data == null or data.clue_id == &"":
		return
	var enough := _alms >= data.alms_for_clue or (_listened and _alms >= data.alms_for_clue - 1)
	if not enough:
		return
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", data.clue_id, "", false)


func _data(id: StringName) -> WandererData:
	if not wanderer_data.is_empty():
		return wanderer_data.get(id)
	return Database.wanderer(id) as WandererData


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
