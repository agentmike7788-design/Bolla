class_name Village
extends Node
## Systems/Village (docs/PHASE7_DESIGN.md §1.2, §1.5, §2.9, §3.1, §3.4, §5.1), groups
## &"village", &"saveable": village_open (morning rule; a migrated v5 save with roof_and_earth_complete
## opens at once in post_load), the consecration of the Lindenacker (price, day, Village.consecrate at
## 10:30 → linden_consecrated, ground_consecrated, ExpansionManager.try_unlock), the round in the
## Holderkrug, the poor box, the mourning ribbon and the chapter „Ein Name im Dorf".
## - Unlock (§1.2): the first minute ≥ intro_minute after unlock_flag was first seen sets open_flag and
##   village_open_day (like Buildings); an empty state (migrated v5) with unlock_flag opens in post_load.
## - Consecration (§2.9): pay_consecration (price by the priest's tier, coins &"consecration") sets
##   linden_consecration_day = tomorrow; at 10:30 of that day (or later, e.g. after sleeping through it)
##   apply_minute calls consecrate().
## - Chapter (§1.5): consecrated, ≥ 6 orders done from ≥ 4 givers, ≥ 3 villagers trusted (relationship
##   ≥ the trusted threshold), insight i_deathbook – checked on order completion (Orders), after the
##   consecration and on relationship_changed / insight_unlocked. Once: goal_flag, chapter_completed,
##   summary panel (variant name_in_village).
## - Mourning ribbon (§2.9, presentation, derived – not saved): the house of the newest unburied corpse
##   delivered since the village opened (deterministic from its arrival day and seed); D1 → her cottage.

const GROUP := &"village"
const FLAG_OPEN := &"village_open"
const FLAG_OPEN_DAY := &"village_open_day"
const FLAG_LINDEN_GRANTED := &"linden_granted"
const FLAG_CONSECRATION_DAY := &"linden_consecration_day"
const FLAG_CONSECRATED := &"linden_consecrated"
const FLAG_HAGEDORN_DEAD := &"hagedorn_dead"
const PRIEST := &"priest"
const MAYOR := &"mayor"
const INNKEEPER := &"innkeeper"
const COUNCIL := &"council"
const COIN_ITEM := &"coin"
const REASON_ROUND := &"round"
const REASON_DONATION := &"donation"
const REASON_CONSECRATION := &"consecration"
const EVENT_DONATION := &"donation"
const STAT_ROUNDS := &"rounds_bought"
const STAT_DONATIONS := &"donations"
const RIBBON_GROUP := &"mourning_ribbon"
const D1_STORY := "d1_hagedorn"
const HAGEDORN_HOUSE := &"cottage_hagedorn"
const INN_WAYPOINT_PREFIX := "v_in_inn"
const SUMMARY_PANEL := &"slice_summary"
const MINUTES_PER_DAY := 1440
const TEXT_OPEN := "Der Kutschweg hinunter führt nach Hollerbrück. Der Wegstein zeigt die Richtung."
const TEXT_PAID := "Pfarrer Lenz kommt morgen gegen halb zehn den Hügel herauf."
const TEXT_PAID_FREE := "Pfarrer Lenz will kein Geld dafür. Er kommt morgen gegen halb zehn."
const TEXT_CONSECRATED := "Der Lindenacker ist geweiht."
const TEXT_ROUND := "Eine Runde für alle. Rosine schenkt aus, und für eine Viertelstunde redet keiner über die Toten."
const TEXT_DONATED := "Die Münzen klirren in der Armenkasse. Fenner schreibt es auf."
const REASON_ROUND_TEXT := "Eine Runde im Holderkrug"
const REASON_DONATION_TEXT := "Spende in die Armenkasse"
const TEXT_NO_COINS := "So viele Münzen hast du nicht."
const TEXT_ROUND_DONE := "Heute hast du schon eine Runde ausgegeben."
const TEXT_DONATION_DONE := "Für heute hast du genug gegeben."
const TEXT_ABSENT := "%s ist nicht da."
const TEXT_ALREADY := "Der Lindenacker ist schon geweiht."
const TEXT_PAID_ALREADY := "Die Weihe ist schon bezahlt."
## Last line of the chapter panel by piety tier (§1.5, 5 variants; default = considerate).
const FINAL_LINES := {
	&"hardhearted": "Unten im Dorf kennen sie jetzt deinen Namen. Sie sagen ihn leise, wie man einen Hund ruft, dem man nicht traut.",
	&"callous": "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel wissen sie, wie schnell deine Hände sind.",
	&"indifferent": "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger.",
	&"considerate": "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger.",
	&"devout": "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel sagen sie ihn, wenn es dunkel wird, und es klingt wie ein Dank.",
}
const FINAL_LINE_DEFAULT := "Unten im Dorf kennen sie jetzt deinen Namen. Oben auf dem Hügel kennen sie ihn schon länger."

@export var save_id: String = "village"
@export var save_order: int = 50

## Rules; null = data/config/village_config.tres (resolved lazily).
var config: VillageConfig
## Relationship thresholds (trusted); null = data/config/relationship_config.tres.
var relationship_config: RelationshipConfig
## Villager ids counted for the chapter; empty = Database.villagers() (or the eight of §2.1).
var villager_ids: Array[StringName] = []

var _open_day: int = 0
var _consecration_paid_day: int = 0
var _round_day: int = 0
var _donation_day: int = 0
var _donation_steps: int = 0
var _goal_done: bool = false
var _ribbon_seen: Dictionary = {}
## Coins earned since the village opened, by kind (payment_received reasons; chapter panel).
var _earned: Dictionary = {}
## total_minutes when unlock_flag was first seen this session (-1 = not yet; not saved).
var _unlock_seen_total: int = -1
## load_state got a Phase-7 state (not the empty {} of a migrated v5 save).
var _loaded_v6: bool = false
var _ribbon_day: int = -1

const DEFAULT_VILLAGERS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer",
		&"oldwoman"]


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.chapter_completed.connect(_on_chapter_completed)
	EventBus.relationship_changed.connect(_on_goal_input.unbind(5))
	EventBus.insight_unlocked.connect(_on_goal_input.unbind(1))
	EventBus.payment_received.connect(_on_payment)
	EventBus.corpse_buried.connect(_on_ribbon_input.unbind(2))
	EventBus.corpse_arrived.connect(_on_ribbon_input.unbind(1))


# --- unlock ---------------------------------------------------------------------------------------

## Flag village_open.
func is_open() -> bool:
	return GameState.flag_on(_cfg().open_flag)


## Idempotent: village_open at the first minute ≥ intro_minute after unlock_flag was first seen.
func apply_morning(day: int) -> void:
	var cfg := _cfg()
	if is_open() or not GameState.flag_on(cfg.unlock_flag):
		return
	var now := TimeManager.total_minutes()
	if day > TimeManager.day:
		now = maxi(now, (day - 1) * MINUTES_PER_DAY + cfg.intro_minute)
	if _unlock_seen_total < 0:
		_unlock_seen_total = now
		return
	if now >= _open_at(_unlock_seen_total, cfg.intro_minute):
		open()


## v5 → open at once (§1.2): an empty state (migrated) with unlock_flag. A v6 state keeps the morning rule.
func post_load() -> void:
	if not is_open() and GameState.flag_on(_cfg().unlock_flag) and not _loaded_v6:
		open()
	_refresh_ribbons(true)


## Sets village_open now (debug, post_load, morning rule). Idempotent.
func open() -> void:
	if is_open():
		return
	GameState.set_flag(_cfg().open_flag, true)
	if _open_day <= 0:
		_open_day = TimeManager.day
	if not GameState.has_flag(FLAG_OPEN_DAY):
		GameState.set_flag(FLAG_OPEN_DAY, _open_day)
	EventBus.notification_requested.emit(TEXT_OPEN, &"info")


## time_tick: end of the consecration, the mourning ribbon.
func apply_minute(day: int, minute: int) -> void:
	var cfg := _cfg()
	if not GameState.flag_on(FLAG_CONSECRATED) and GameState.has_flag(FLAG_CONSECRATION_DAY):
		var due := _num(GameState.get_flag(FLAG_CONSECRATION_DAY), 0)
		if due > 0 and (day > due or (day == due and minute >= cfg.consecration_end_minute)):
			consecrate()
	if day != _ribbon_day:
		_refresh_ribbons(false)


# --- consecration ---------------------------------------------------------------------------------

## By the priest's relationship tier (consecration_price_by_tier; unknown tier = the stranger's).
func consecration_price() -> int:
	var table := _cfg().consecration_price_by_tier
	var t := _tier(PRIEST)
	if table.has(t):
		return int(table[t])
	return int(table.get(&"stranger", 10))


## "" = the consecration can be paid now; else the reason.
func consecration_block_reason(inv: Inventory) -> String:
	if GameState.flag_on(FLAG_CONSECRATED):
		return TEXT_ALREADY
	if _consecration_paid_day > 0 or GameState.has_flag(FLAG_CONSECRATION_DAY):
		return TEXT_PAID_ALREADY
	if inv == null or inv.count(COIN_ITEM) < consecration_price():
		return TEXT_NO_COINS
	return ""


## linden_consecration_day = tomorrow; coins (&"consecration") when the price is above 0.
func pay_consecration(inv: Inventory) -> bool:
	if consecration_block_reason(inv) != "":
		return false
	var price := consecration_price()
	if price > 0:
		if not inv.remove_item(COIN_ITEM, price):
			return false
		GameState.note_coins_spent(price, REASON_CONSECRATION)
	_consecration_paid_day = TimeManager.day
	GameState.set_flag(FLAG_CONSECRATION_DAY, TimeManager.day + 1)
	EventBus.notification_requested.emit(TEXT_PAID if price > 0 else TEXT_PAID_FREE, &"info")
	return true


## linden_consecrated, ground_consecrated, ExpansionManager.try_unlock, check_goal. Once.
func consecrate() -> void:
	if GameState.flag_on(FLAG_CONSECRATED):
		return
	var section := _cfg().consecration_section
	GameState.set_flag(FLAG_CONSECRATED, true)
	EventBus.ground_consecrated.emit(section)
	EventBus.notification_requested.emit(TEXT_CONSECRATED, &"reward")
	var expansion := _first(&"expansion")
	if expansion != null and expansion.has_method(&"try_unlock"):
		expansion.call(&"try_unlock", section)
	check_goal()


# --- round & poor box -----------------------------------------------------------------------------

## "" = a round can be bought now; else the reason.
func round_block_reason(inv: Inventory) -> String:
	if _round_day == TimeManager.day:
		return TEXT_ROUND_DONE
	if not villager_present(INNKEEPER):
		return TEXT_ABSENT % "Rosine"
	if inv == null or inv.count(COIN_ITEM) < _cfg().round_price:
		return TEXT_NO_COINS
	return ""


## The innkeeper present, once per day; Relationships.add(round) for everyone in the inn; the clock
## runs round_minutes.
func buy_round(inv: Inventory) -> bool:
	if round_block_reason(inv) != "":
		return false
	var cfg := _cfg()
	if not inv.remove_item(COIN_ITEM, cfg.round_price):
		return false
	GameState.note_coins_spent(cfg.round_price, REASON_ROUND)
	_round_day = TimeManager.day
	GameState.add_stat(STAT_ROUNDS, 1)
	var gain := int(_rel_cfg().gains.get(&"round", 2))
	for npc: StringName in in_inn(TimeManager.minute_of_day):
		_rel_add(npc, gain, REASON_ROUND_TEXT)
	EventBus.notification_requested.emit(TEXT_ROUND, &"info")
	if cfg.round_minutes > 0:
		TimeManager.advance(cfg.round_minutes)
	return true


## Villagers in the inn at `minute` (their schedule's current entry stands at a v_in_inn_* waypoint).
func in_inn(minute: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for npc: StringName in _villagers():
		var schedule := Database.schedule(npc) as NpcSchedule
		if schedule == null:
			continue
		var entry := ScheduleResolver.entry_at(schedule, minute, TimeManager.day)
		if entry == null or not entry.visible or entry.path.is_empty():
			continue
		if String(entry.path[entry.path.size() - 1]).begins_with(INN_WAYPOINT_PREFIX):
			out.append(npc)
	return out


## "" = one more step into the poor box today; else the reason.
func donation_block_reason(inv: Inventory) -> String:
	var cfg := _cfg()
	if _donation_day == TimeManager.day and _donation_steps >= cfg.donation_steps_per_day:
		return TEXT_DONATION_DONE
	if inv == null or inv.count(COIN_ITEM) < cfg.donation_step:
		return TEXT_NO_COINS
	return ""


## Steps given today (0…donation_steps_per_day).
func donations_today() -> int:
	return _donation_steps if _donation_day == TimeManager.day else 0


## One step; reputation +1 (event donation), Fenner +1 (gains.donation).
func donate(inv: Inventory) -> bool:
	if donation_block_reason(inv) != "":
		return false
	var cfg := _cfg()
	if not inv.remove_item(COIN_ITEM, cfg.donation_step):
		return false
	GameState.note_coins_spent(cfg.donation_step, REASON_DONATION)
	if _donation_day != TimeManager.day:
		_donation_day = TimeManager.day
		_donation_steps = 0
	_donation_steps += 1
	GameState.add_stat(STAT_DONATIONS, 1)
	_rep_event(EVENT_DONATION, REASON_DONATION_TEXT)
	_rel_add(MAYOR, int(_rel_cfg().gains.get(&"donation", 1)), REASON_DONATION_TEXT)
	EventBus.notification_requested.emit(TEXT_DONATED, &"info")
	return true


# --- mourning ribbon ------------------------------------------------------------------------------

## The house with the mourning ribbon on `day` ("" = none): from 00:00 of her delivery day Wiebke
## Hagedorn's cottage (flag hagedorn_dead) until she is buried; otherwise the newest unburied corpse
## delivered since the village opened, from its arrival day on.
func mourning_house(day: int) -> StringName:
	if not is_open():
		return &""
	var manager := _first(&"corpse_manager")
	var records: Array = manager.call(&"records") if manager != null and manager.has_method(&"records") else []
	if GameState.flag_on(FLAG_HAGEDORN_DEAD):
		var buried := false
		var found := false
		for r: CorpseRecord in records:
			if String(r.story_id) == D1_STORY:
				found = true
				buried = r.location == CorpseRecord.LOCATION_BURIED
		if not buried and (found or _num(GameState.get_flag(FLAG_HAGEDORN_DEAD), day) <= day):
			return HAGEDORN_HOUSE
	var open_day := maxi(_open_day, _num(GameState.get_flag(FLAG_OPEN_DAY), 0))
	var newest: CorpseRecord = null
	for r: CorpseRecord in records:
		if r.location == CorpseRecord.LOCATION_BURIED or r.story_id != &"":
			continue
		var arrived := floori(float(r.arrival_total_minutes) / MINUTES_PER_DAY) + 1
		if arrived > day or (open_day > 0 and arrived < open_day):
			continue
		if newest == null or r.arrival_total_minutes > newest.arrival_total_minutes:
			newest = r
	if newest == null:
		return &""
	var houses := _ribbon_houses()
	if houses.is_empty():
		return &""
	var arrived := floori(float(newest.arrival_total_minutes) / MINUTES_PER_DAY) + 1
	return StringName(houses[posmod(hash([arrived, newest.seed]), houses.size())])


## STUB (P6) – Phase 8 (docs/PHASE8_DESIGN.md §2.2.1, §5.2 step 1): the pure part of mourning_house – the
## house of a corpse that arrived on `arrival_day` with `seed` among `houses` (bit-identical to the Phase-7
## mourning ribbon: houses[posmod(hash([arrival_day, seed]), houses.size())]); SaveMigration uses it for
## kin_house. W0: &"" (P6 extracts it from mourning_house).
static func mourning_house_for(_arrival_day: int, _seed: int, _houses: PackedStringArray) -> StringName:
	return &""


# --- chapter --------------------------------------------------------------------------------------

## {consecrated, orders_done, orders_givers, trusted, insight, done, total} (§1.5).
func goal_progress() -> Dictionary:
	var cfg := _cfg()
	var orders := _first(&"orders")
	var done := int(orders.call(&"done_count")) if orders != null and orders.has_method(&"done_count") else 0
	var givers: PackedStringArray = orders.call(&"done_givers") if orders != null and orders.has_method(&"done_givers") else PackedStringArray()
	var trusted := trusted_count()
	var consecrated := GameState.flag_on(FLAG_CONSECRATED)
	var insight := _has_insight(cfg.goal_insight)
	var parts := [consecrated, done >= cfg.goal_orders and givers.size() >= cfg.goal_givers, trusted >= cfg.goal_trusted, insight]
	var n := 0
	for p: bool in parts:
		if p:
			n += 1
	return {"consecrated": consecrated, "orders_done": done, "orders_goal": cfg.goal_orders, "orders_givers": givers.size(),
			"givers_goal": cfg.goal_givers, "trusted": trusted, "trusted_goal": cfg.goal_trusted, "insight": insight,
			"done": n, "total": parts.size()}


## Villagers at „Vertraut" or higher (relationship ≥ the trusted threshold).
func trusted_count() -> int:
	var rel := _first(&"relationships")
	if rel == null or not rel.has_method(&"value"):
		return 0
	var n := 0
	for npc: StringName in _villagers():
		if OrderRules.tier_index(OrderRules.rel_tier(int(rel.call(&"value", npc)), _rel_cfg())) >= OrderRules.tier_index(&"trusted"):
			n += 1
	return n


## Chapter §1.5 once: goal_flag, chapter_completed, summary panel (variant = chapter_id).
func check_goal() -> void:
	var cfg := _cfg()
	if _goal_done or GameState.flag_on(cfg.goal_flag):
		_goal_done = true
		return
	var p := goal_progress()
	if int(p.done) < int(p.total):
		return
	_goal_done = true
	GameState.set_flag(cfg.goal_flag, true)
	EventBus.chapter_completed.emit(cfg.chapter_id)
	EventBus.ui_panel_requested.emit(SUMMARY_PANEL, chapter_context())


## Context of the chapter panel (§1.5): the graveyard's summary_context with variant/chapter =
## chapter_id, plus days since village_open, trips, orders by giver, relationships as words,
## burials in the Lindenacker, specimen statistics, deductions, standing, coins earned / spent in the
## village by purpose, the phase's insights and the final line by piety tier.
func chapter_context() -> Dictionary:
	var cfg := _cfg()
	var context := {}
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"summary_context"):
		context = graveyard.call(&"summary_context")
	context["variant"] = cfg.chapter_id
	context["chapter"] = cfg.chapter_id
	var open_day := maxi(_open_day, _num(GameState.get_flag(FLAG_OPEN_DAY), 0))
	context["village_days"] = maxi(TimeManager.day - open_day, 0) if open_day > 0 else 0
	context["village_trips"] = GameState.get_stat(&"village_trips")
	var orders := _first(&"orders")
	context["orders_done"] = int(orders.call(&"done_count")) if orders != null and orders.has_method(&"done_count") else 0
	context["orders_by_giver"] = orders.call(&"done_by_giver") if orders != null and orders.has_method(&"done_by_giver") else {}
	var rel := _first(&"relationships")
	var words := {}
	for npc: StringName in _villagers():
		var value := int(rel.call(&"value", npc)) if rel != null and rel.has_method(&"value") else 0
		words[npc] = OrderRules.tier_word(OrderRules.rel_tier(value, _rel_cfg()))
	context["relationships"] = words
	context["reputation_tier"] = GameState.reputation_label()
	var linden := 0
	if graveyard != null and graveyard.has_method(&"plots_in_section"):
		for gid: String in graveyard.call(&"plots_in_section", cfg.consecration_section):
			var g := graveyard.call(&"get_grave", gid) as GraveRecord
			if g != null and (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED):
				linden += 1
	context["linden_burials"] = linden
	var specimens := {}
	for stat: StringName in [&"specimens_taken", &"specimens_sold", &"specimens_researched", &"lectures_attended",
			&"medicines_made", &"specimens_collected", &"specimens_returned"]:
		specimens[stat] = GameState.get_stat(stat)
	context["specimens"] = specimens
	context["deductions"] = GameState.get_stat(&"deductions")
	context["university_standing"] = GameState.get_stat(&"university_standing")
	context["coins_earned_village"] = _earned.duplicate()
	var spent := {}
	for reason: StringName in [&"village", &"donation", &"round", &"consecration"]:
		spent[reason] = GameState.get_stat(GameState.coin_ledger_stat(reason))
	context["coins_spent_village"] = spent
	var insights := PackedStringArray()
	for id: StringName in [&"i_deathbook", &"i_burn_it"]:
		if _has_insight(id):
			insights.append(String(id))
	context["insights_phase7"] = insights
	context["final_line"] = final_line()
	return context


## The last line of the chapter panel by the piety tier (§1.5, 5 variants).
func final_line() -> String:
	return str(FINAL_LINES.get(DialogueConditions.piety_tier(), FINAL_LINE_DEFAULT))


## §5.1: {open_day, consecration_paid_day, round_day, donation_day, donation_steps, goal_done,
## ribbon_seen} + earned (chapter panel bookkeeping).
func save_state() -> Dictionary:
	var earned := {}
	for key: Variant in _earned:
		earned[str(key)] = int(_earned[key])
	return {"open_day": _open_day, "consecration_paid_day": _consecration_paid_day, "round_day": _round_day,
			"donation_day": _donation_day, "donation_steps": _donation_steps, "goal_done": _goal_done,
			"ribbon_seen": _ribbon_seen.duplicate(true), "earned": earned}


## Tolerant: missing / damaged keys fall back to the defaults ({} = a migrated v5 save).
func load_state(data: Dictionary) -> void:
	_loaded_v6 = not data.is_empty()
	_unlock_seen_total = -1
	_open_day = maxi(0, _num(data.get("open_day"), 0))
	_consecration_paid_day = maxi(0, _num(data.get("consecration_paid_day"), 0))
	_round_day = maxi(0, _num(data.get("round_day"), 0))
	_donation_day = maxi(0, _num(data.get("donation_day"), 0))
	_donation_steps = clampi(_num(data.get("donation_steps"), 0), 0, maxi(_cfg().donation_steps_per_day, 0))
	var done: Variant = data.get("goal_done", false)
	_goal_done = done is bool and done
	var seen: Variant = data.get("ribbon_seen", {})
	_ribbon_seen = (seen as Dictionary).duplicate(true) if seen is Dictionary else {}
	_earned.clear()
	var earned: Variant = data.get("earned", {})
	if earned is Dictionary:
		for key: Variant in earned:
			_earned[str(key)] = _num((earned as Dictionary)[key], 0)
	_ribbon_day = -1


# --- internals ------------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_morning(day)
	apply_minute(day, minute)


## Records the unlock time (own bookkeeping only; opening follows in apply_morning).
func _on_chapter_completed(chapter_id: StringName) -> void:
	if _unlock_seen_total < 0 and not is_open() and GameState.flag_on(_cfg().unlock_flag) and chapter_id != _cfg().chapter_id:
		_unlock_seen_total = TimeManager.total_minutes()


func _on_goal_input() -> void:
	if not SaveManager.is_loading and is_open():
		check_goal()


## Bookkeeping for the chapter panel: coins earned in the village (orders, sales, specimens …).
func _on_payment(amount: int, reason: String) -> void:
	if amount <= 0 or not is_open():
		return
	var kind := ""
	if reason.begins_with("Auftrag"):
		kind = "orders"
	elif reason.begins_with("Verkauf im Dorf"):
		kind = "shops"
	elif reason.begins_with("Präparat") or reason.begins_with("Vorlesung") or reason.begins_with("Sammlung") or reason.begins_with("Arznei"):
		kind = "anatomy"
	if kind != "":
		_earned[kind] = int(_earned.get(kind, 0)) + amount


func _on_ribbon_input() -> void:
	_refresh_ribbons(true)


func _refresh_ribbons(force: bool) -> void:
	if not is_inside_tree():
		return
	if not force and _ribbon_day == TimeManager.day:
		return
	_ribbon_day = TimeManager.day
	for node: Node in get_tree().get_nodes_in_group(RIBBON_GROUP):
		if node.has_method(&"refresh"):
			node.call(&"refresh")


func _ribbon_houses() -> PackedStringArray:
	var out := PackedStringArray()
	for h: String in _cfg().mourning_houses:
		if StringName(h) != HAGEDORN_HOUSE:
			out.append(h)
	return out


## The villager is there: true without an Npc node of that id in the village (W1 / dialogue context),
## else the node is present.
func villager_present(npc_id: StringName) -> bool:
	if not is_inside_tree():
		return true
	var any := false
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		if node.get(&"npc_id") != npc_id or node.get(&"region_id") != &"village":
			continue
		any = true
		if node.has_method(&"is_present") and bool(node.call(&"is_present")):
			return true
	return not any


func _tier(npc_id: StringName) -> StringName:
	var rel := _first(&"relationships")
	var value := int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0
	return OrderRules.rel_tier(value, _rel_cfg())


func _villagers() -> Array[StringName]:
	if not villager_ids.is_empty():
		return villager_ids
	var out: Array[StringName] = []
	for res: Resource in Database.villagers():
		var v := res as VillagerData
		if v != null and v.npc_id != &"":
			out.append(v.npc_id)
	return out if not out.is_empty() else DEFAULT_VILLAGERS


func _has_insight(id: StringName) -> bool:
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"has_insight"):
		return bool(journal.call(&"has_insight", id))
	var data := Database.insight(id) as InsightData
	return data != null and data.sets_flag != &"" and GameState.flag_on(data.sets_flag)


func _rel_add(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"add") and delta != 0:
		rel.call(&"add", npc_id, delta, reason)


## Reputation.event when the data knows the event, else the class-default points.
func _rep_event(kind: StringName, reason: String) -> void:
	var rep := _first(&"reputation")
	if rep == null:
		return
	var cfg := Database.config(&"reputation_config") as ReputationConfig
	if cfg != null and cfg.event_points.has(kind):
		rep.call(&"event", kind, reason)
		return
	var points := int(ReputationConfig.new().event_points.get(kind, 0))
	if points != 0:
		rep.call(&"change", points, reason)


## The first total minute with the clock at `intro_minute` strictly after `seen_total`.
static func _open_at(seen_total: int, intro_minute: int) -> int:
	var day_index := floori(float(seen_total - intro_minute) / MINUTES_PER_DAY) + 1
	return day_index * MINUTES_PER_DAY + intro_minute


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _cfg() -> VillageConfig:
	if config == null:
		config = Database.config(&"village_config") as VillageConfig
		if config == null:
			config = VillageConfig.new()
	return config


func _rel_cfg() -> RelationshipConfig:
	if relationship_config == null:
		relationship_config = Database.config(&"relationship_config") as RelationshipConfig
		if relationship_config == null:
			relationship_config = RelationshipConfig.new()
	return relationship_config


static func _num(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
