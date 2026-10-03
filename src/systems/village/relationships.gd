class_name Relationships
extends Node
## Systems/Relationships (docs/PHASE7_DESIGN.md §2.1, §2.4, §3.1, §3.4, §5.1), groups &"relationships",
## &"saveable": one value 0…100 per villager, the first meeting, talk / gift / remark once per day, the
## specimen deltas. Changes come only from direct calls (meet, add, note_talk, give_gift,
## on_specimen_*); every change emits EventBus.relationship_changed. No decay, nothing per day.
## - First meeting (meet): VillagerData.start_value + the reputation bonus (+ the piety bonus for
##   piety_sensitive villagers) – RelationshipRules.start_value. add / note_talk / give_gift meet first.
## - Only villagers with VillagerData (Database.villager, or `villagers` in tests) have a value; other
##   ids (Osric, Ilse, the council) are ignored.
## - Remarks (Gerede, §2.4): once per villager and day; precedence friend → piety hardhearted / devout →
##   specimens (after REMARK_SPECIMENS_AFTER sold specimens) → reputation tier.

const GROUP := &"relationships"
const REASON_MEET := "Erste Begegnung"
const REASON_TALK := "Gespräch"
const REASON_GIFT := "Geschenk"
const REASON_SPECIMEN_SOLD := "Im Dorf redet man."
const REASON_SPECIMEN_RETURNED := "Zurückgelegt"
const TEXT_GIFT_DISLIKED := "Das brauch ich nicht, aber danke."
const TEXT_GIFT_TODAY := "Für heute hast du schon etwas mitgebracht."
const TEXT_GIFT_MISSING := "Das hast du nicht dabei."
const TEXT_GIFT_UNKNOWN := "Hier nimmt niemand Geschenke an."
const KEY_FRIEND := &"friend"
const KEY_SPECIMENS := &"specimens"
## Piety tiers with their own remark (§2.4: Hartherzig / Andächtig).
const PIETY_REMARK_TIERS: Array[StringName] = [&"hardhearted", &"devout"]
## The „Post vom Hügel" remarks from this many specimens sold (stats.specimens_sold).
const REMARK_SPECIMENS_AFTER := 3
const STAT_GIFTS := &"gifts_given"
const STAT_SPECIMENS_SOLD := &"specimens_sold"

@export var save_id: String = "relationships"
@export var save_order: int = 51

## Rules; null = data/config/relationship_config.tres (resolved lazily).
var config: RelationshipConfig
## Tests: npc_id → VillagerData; empty = Database.villager / Database.villagers().
var villagers: Dictionary[StringName, VillagerData] = {}
## Tests: anatomy rules for the organ-specific sell deltas; null = Database.
var anatomy_config: AnatomyConfig

var _values: Dictionary[StringName, int] = {}
var _met: Array[StringName] = []
## npc_id → game day of the last talk / gift / remark.
var _talk_day: Dictionary[StringName, int] = {}
var _gift_day: Dictionary[StringName, int] = {}
var _remark_day: Dictionary[StringName, int] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func value(npc_id: StringName) -> int:
	return int(_values.get(npc_id, 0))


func tier(npc_id: StringName) -> StringName:
	return RelationshipRules.tier(value(npc_id), config)


func met(npc_id: StringName) -> bool:
	return _met.has(npc_id)


## Ids met so far (first meeting order).
func met_ids() -> Array[StringName]:
	return _met.duplicate()


## RelationshipConfig.gains[kind] (0 if unknown) – for the callers of add (round, donation, …).
func gain(kind: StringName) -> int:
	return int(_cfg().gains.get(kind, 0))


## First contact: the start value (§2.1), relationship_changed. Again / unknown villager → nothing.
func meet(npc_id: StringName) -> void:
	if met(npc_id):
		return
	var data := villager(npc_id)
	if data == null:
		return
	var start := RelationshipRules.start_value(data, _rep_tier(), _piety_tier(), _cfg())
	_met.append(npc_id)
	_values[npc_id] = start
	EventBus.relationship_changed.emit(npc_id, start, tier(npc_id), start, REASON_MEET)


## Clamped 0…100; meets first; relationship_changed (only when the value changes); returns the new value.
func add(npc_id: StringName, delta: int, reason: String) -> int:
	if villager(npc_id) == null and not met(npc_id):
		return value(npc_id)
	meet(npc_id)
	var old := value(npc_id)
	var now := RelationshipRules.clamp_value(old + delta)
	if now != old:
		_values[npc_id] = now
		EventBus.relationship_changed.emit(npc_id, now, tier(npc_id), now - old, reason)
	return now


## +talk once per day (meets first).
func note_talk(npc_id: StringName) -> void:
	if villager(npc_id) == null and not met(npc_id):
		return
	meet(npc_id)
	var day := TimeManager.day
	if int(_talk_day.get(npc_id, -1)) == day:
		return
	_talk_day[npc_id] = day
	add(npc_id, gain(&"talk"), REASON_TALK)


## Talked to `npc_id` today.
func talked_today(npc_id: StringName) -> bool:
	return int(_talk_day.get(npc_id, -1)) == TimeManager.day


func gift_block_reason(npc_id: StringName, item_id: StringName, inv: Inventory) -> String:
	var data := villager(npc_id)
	if data == null:
		return TEXT_GIFT_UNKNOWN
	if not data.gifts_liked.has(item_id):
		return TEXT_GIFT_DISLIKED
	if int(_gift_day.get(npc_id, -1)) == TimeManager.day:
		return TEXT_GIFT_TODAY
	if inv == null or not inv.has(item_id, 1):
		return TEXT_GIFT_MISSING
	return ""


## 1 item gone, +gift, stats.gifts_given; once per villager and day, only liked items.
func give_gift(npc_id: StringName, item_id: StringName, inv: Inventory) -> bool:
	if gift_block_reason(npc_id, item_id, inv) != "":
		return false
	if not inv.remove_item(item_id, 1):
		return false
	_gift_day[npc_id] = TimeManager.day
	GameState.add_stat(STAT_GIFTS, 1)
	add(npc_id, gain(&"gift"), REASON_GIFT)
	return true


## Villagers met on `tier` or higher (chapter: trusted).
func count_at_least(at_least_tier: StringName) -> int:
	var n := 0
	for id: StringName in _met:
		if RelationshipRules.at_least(tier(id), at_least_tier):
			n += 1
	return n


## Once per day; villager_remarked; "" = already said today (or nothing to say).
func remark(npc_id: StringName) -> String:
	var day := TimeManager.day
	if int(_remark_day.get(npc_id, -1)) == day:
		return ""
	var text := remark_text(npc_id, day)
	if text == "":
		return ""
	_remark_day[npc_id] = day
	EventBus.villager_remarked.emit(npc_id, text)
	return text


## The remark of `npc_id` on `day` without marking it said (precedence §2.4).
func remark_text(npc_id: StringName, day: int) -> String:
	var data := villager(npc_id)
	if data == null:
		return ""
	var keys: Array[StringName] = []
	if met(npc_id) and tier(npc_id) == RelationshipRules.TIERS[3]:
		keys.append(KEY_FRIEND)
	var piety := _piety_tier()
	if piety in PIETY_REMARK_TIERS:
		keys.append(StringName("piety_" + String(piety)))
	if GameState.get_stat(STAT_SPECIMENS_SOLD) >= REMARK_SPECIMENS_AFTER:
		keys.append(KEY_SPECIMENS)
	keys.append(StringName("rep_" + String(_rep_tier())))
	keys.append(&"rep_respected")
	for key: StringName in keys:
		var pool: PackedStringArray = data.remarks.get(key, PackedStringArray())
		if not pool.is_empty():
			return pool[posmod(day, pool.size())]
	return ""


## Every villager with specimen_delta (organ given: AnatomyConfig.organs[organ].sell_rel wins for
## priest / washer / oldwoman – eyes and hand weigh more).
func on_specimen_sold(organ: StringName = &"") -> void:
	var sell_rel: Dictionary = {}
	if organ != &"":
		sell_rel = _anatomy().organ(organ).get("sell_rel", {})
	for data: VillagerData in _all_villagers():
		var delta := data.specimen_delta
		if sell_rel.has(data.npc_id):
			delta = int(sell_rel[data.npc_id])
		if delta != 0:
			add(data.npc_id, delta, REASON_SPECIMEN_SOLD)


## Every villager with returned_delta (priest +1, washer +2).
func on_specimen_returned() -> void:
	for data: VillagerData in _all_villagers():
		if data.returned_delta != 0:
			add(data.npc_id, data.returned_delta, REASON_SPECIMEN_RETURNED)


## VillagerData of `npc_id` (null = not a villager).
func villager(npc_id: StringName) -> VillagerData:
	if not villagers.is_empty():
		return villagers.get(npc_id)
	return Database.villager(npc_id) as VillagerData


## {values, met, talk_day, gift_day, remark_day} (§5.1).
func save_state() -> Dictionary:
	var values := {}
	for id: StringName in _values:
		values[String(id)] = _values[id]
	var met_list: Array = []
	for id: StringName in _met:
		met_list.append(String(id))
	return {"values": values, "met": met_list, "talk_day": _days_out(_talk_day), "gift_day": _days_out(_gift_day),
			"remark_day": _days_out(_remark_day)}


## Tolerant: values clamped 0…100, damaged entries dropped, {} = nobody met.
func load_state(data: Dictionary) -> void:
	_values.clear()
	_met.clear()
	var saved: Variant = data.get("values")
	if saved is Dictionary:
		for key: Variant in saved:
			var v: Variant = (saved as Dictionary)[key]
			if v is int or v is float:
				_values[StringName(str(key))] = RelationshipRules.clamp_value(int(v))
	var met_list: Variant = data.get("met")
	if met_list is Array:
		for id: Variant in met_list:
			var sid := StringName(str(id))
			if not _met.has(sid):
				_met.append(sid)
	_talk_day = _days_in(data.get("talk_day"))
	_gift_day = _days_in(data.get("gift_day"))
	_remark_day = _days_in(data.get("remark_day"))


# --- internals ------------------------------------------------------------------------------

func _all_villagers() -> Array[VillagerData]:
	var out: Array[VillagerData] = []
	if not villagers.is_empty():
		for id: StringName in villagers:
			out.append(villagers[id])
		return out
	for res: Resource in Database.villagers():
		var v := res as VillagerData
		if v != null:
			out.append(v)
	return out


func _rep_tier() -> StringName:
	var rep := _system(&"reputation")
	if rep != null and rep.has_method(&"tier"):
		return rep.call(&"tier")
	return ReputationRules.tier(GameState.get_stat(&"reputation"), ReputationRules._cfg(null))


func _piety_tier() -> StringName:
	var piety := _system(&"piety")
	if piety != null and piety.has_method(&"tier"):
		return piety.call(&"tier")
	return PietyRules.tier(GameState.get_stat(&"piety"), PietyRules._cfg(null))


func _system(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _cfg() -> RelationshipConfig:
	if config == null:
		config = RelationshipRules._cfg(null)
	return config


func _anatomy() -> AnatomyConfig:
	if anatomy_config == null:
		anatomy_config = Database.config(&"anatomy_config") as AnatomyConfig
		if anatomy_config == null:
			anatomy_config = AnatomyConfig.new()
	return anatomy_config


static func _days_out(days: Dictionary[StringName, int]) -> Dictionary:
	var out := {}
	for id: StringName in days:
		out[String(id)] = days[id]
	return out


static func _days_in(raw: Variant) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = (raw as Dictionary)[key]
			if v is int or v is float:
				out[StringName(str(key))] = int(v)
	return out
