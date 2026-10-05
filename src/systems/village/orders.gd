class_name Orders
extends Node
## Systems/Orders (docs/PHASE7_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1), groups &"orders", &"saveable":
## offered → accepted → completed / failed; at most OrdersConfig.max_active accepted; deadlines at
## 06:00; the parish board offers each morning. complete pays (coins into the player's inventory,
## payment_received „Auftrag: <Titel>"), changes relationships (Relationships.add) and reputation
## (Reputation.change reward_rep) and calls Village.check_goal. Graveyard / Stonemasonry /
## ExpansionManager / CorpseCare report directly (note_*).
##
## Six kinds (§2.5): deliver / donate (turn_in in a dialogue, atomic), bury (note_grave_completed,
## note_stone_set, note_harvest), stone (note_stone_set), tend (apply_morning), section
## (note_section_progress). Personal orders run once; board orders return after cooldown_days.
## Burial targets: a story id (D1 o_hagedorn_place – accepted at the latest when she arrives, the
## deadline counts from her arrival, §2.5 / W0-Notizen 12) or "next_delivery" (the first corpse that
## arrives after the acceptance – the accept minute is kept in progress["at:<id>"]).
## Saved (§5.1): {states, accepted_day, board_day, board, history, progress}.

const GROUP := &"orders"
const STATE_OFFERED := &"offered"
const STATE_ACCEPTED := &"accepted"
const STATE_COMPLETED := &"completed"
const STATE_FAILED := &"failed"
const STATES: Array[StringName] = [STATE_OFFERED, STATE_ACCEPTED, STATE_COMPLETED, STATE_FAILED]
const KIND_DELIVER := &"deliver"
const KIND_BURY := &"bury"
const KIND_STONE := &"stone"
const KIND_TEND := &"tend"
const KIND_DONATE := &"donate"
const KIND_SECTION := &"section"
const COUNCIL := &"council"
const COIN_ITEM := &"coin"
const REASON_DONATION := &"donation"
const REASON_ORDER := "Auftrag: %s"
const REASON_FAILED := "Auftrag versäumt: %s"
const STAT_DONE := &"orders_done"
const STAT_FAILED := &"orders_failed"
const EVENT_FAILED := &"order_failed"
const TEXT_FAILED := "Zu spät: %s."
const TEXT_ACCEPTED := "Angenommen: %s"
const PROGRESS_AT := "at:"
const PROGRESS_DONE := "done:"
const MINUTES_PER_DAY := 1440
const RELATIONSHIPS_GROUP := &"relationships"
const REPUTATION_GROUP := &"reputation"
const VILLAGE_GROUP := &"village"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const BUILDINGS_GROUP := &"buildings"
const SPECIMENS_GROUP := &"specimens"
const LECTURES_GROUP := &"lectures"
const CLEANLINESS_GROUP := &"cleanliness"
const PLAYER_GROUP := &"player"
const CHAPEL := &"chapel"

@export var save_id: String = "orders"
@export var save_order: int = 53

## Rules; null = data/config/orders_config.tres (resolved lazily).
var config: OrdersConfig
## Orders by id; empty = Database.orders() (tests inject fixtures).
var order_table: Dictionary[StringName, OrderData] = {}
## Relationship thresholds for the tiers; null = data/config/relationship_config.tres.
var relationship_config: RelationshipConfig

var _states: Dictionary[StringName, StringName] = {}
var _accepted_day: Dictionary[StringName, int] = {}
## Day of the last morning check (= the day of today's board).
var _board_day: int = 0
var _board: Array[StringName] = []
## Board order → day it ended (completed / failed) – cooldown.
var _history: Dictionary[StringName, int] = {}
## tend: mornings in a row; "at:<id>": total minute of the acceptance (next_delivery) / arrival day of
## the target story corpse; "done:<id>": times completed (board orders repeat).
var _progress: Dictionary[String, int] = {}
## Inventory the coins of the order being turned in go to (turn_in → complete).
var _pay_into: Inventory


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- queries --------------------------------------------------------------------------------------

## OrderData of `order_id` (order_table / Database) or null.
func order_data(order_id: StringName) -> OrderData:
	if not order_table.is_empty():
		return order_table.get(order_id)
	return Database.order_data(order_id) as OrderData


## All orders, sorted by order (then id).
func all_orders() -> Array[OrderData]:
	var out: Array[OrderData] = []
	var list: Array = order_table.values() if not order_table.is_empty() else Database.orders()
	for o: Variant in list:
		if o is OrderData:
			out.append(o)
	out.sort_custom(func(a: OrderData, b: OrderData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## Order ids that can be accepted now (of `giver`; &"" = all): personal orders whose conditions hold
## and today's board offers – in order. The four-active limit is no part of it (the panel shows it).
func offers(giver: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for o: OrderData in all_orders():
		if giver != &"" and o.giver != giver:
			continue
		var reason := block_reason(o.id)
		if reason == "" or reason == OrderRules.TEXT_MAX_ACTIVE:
			out.append(o.id)
	return out


## Accepted order ids, in order.
func active() -> Array[StringName]:
	var out: Array[StringName] = []
	for o: OrderData in all_orders():
		if state(o.id) == STATE_ACCEPTED:
			out.append(o.id)
	for id: StringName in _states:
		if _states[id] == STATE_ACCEPTED and not out.has(id):
			out.append(id)
	return out


## &"" | offered | accepted | completed | failed.
func state(order_id: StringName) -> StringName:
	return _states.get(order_id, &"")


## Day the order was accepted (D1: her arrival; 0 = not accepted).
func accepted_day(order_id: StringName) -> int:
	return int(_accepted_day.get(order_id, 0))


## Day the deadline runs out at 06:00 (0 = none / not running).
func deadline_day(order_id: StringName) -> int:
	var o := order_data(order_id)
	if o == null or o.days_limit <= 0 or state(order_id) != STATE_ACCEPTED or not _deadline_running(o):
		return 0
	return accepted_day(order_id) + o.days_limit


## "" = offerable now; else the reason (OrderRules.offer_block_reason with this world's context).
func block_reason(order_id: StringName) -> String:
	var o := order_data(order_id)
	if o == null:
		return OrderRules.TEXT_NOT_YET
	return OrderRules.offer_block_reason(o, offer_context(o), giver_tier(o.giver), active().size(), _cfg())


## The context dictionary OrderRules.offer_block_reason reads (see order_rules.gd).
func offer_context(o: OrderData) -> Dictionary:
	var completed: Array = []
	var started := 0
	for id: StringName in _states:
		if _states[id] == STATE_COMPLETED:
			completed.append(id)
		var other := order_data(id)
		if other != null and o != null and other.giver == o.giver and _states[id] != STATE_OFFERED:
			started += 1
	return {"state": state(o.id) if o != null else &"", "completed": completed, "board": _board.duplicate(),
			"giver_started": started, "teachings": _teachings(), "standing": GameState.get_stat(&"university_standing")}


## Relationship tier with `npc_id` (thresholds of the RelationshipConfig; the council has none).
func giver_tier(npc_id: StringName) -> StringName:
	if npc_id == COUNCIL or npc_id == &"":
		return OrderRules.TIERS[0]
	var rel := _first(RELATIONSHIPS_GROUP)
	var value := int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0
	return OrderRules.rel_tier(value, _rel_cfg())


## Today's board offers.
func board() -> Array[StringName]:
	return _board.duplicate()


## Completed orders (a board order counts every time it was done).
func done_count() -> int:
	var n := 0
	for id: StringName in _completed_ids():
		n += completions(id)
	return n


## Times `order_id` was completed (progress "done:<id>"; a completed state without a counter = 1).
func completions(order_id: StringName) -> int:
	var n := int(_progress.get(PROGRESS_DONE + String(order_id), 0))
	if n <= 0 and state(order_id) == STATE_COMPLETED:
		n = 1
	return n


## Distinct givers of completed orders (the board counts as „Gemeinde" = council).
func done_givers() -> PackedStringArray:
	var out := PackedStringArray()
	for id: StringName in _completed_ids():
		var o := order_data(id)
		var giver := String(o.giver) if o != null else ""
		if giver != "" and not out.has(giver):
			out.append(giver)
	out.sort()
	return out


## {giver: completed count} – for the chapter panel.
func done_by_giver() -> Dictionary:
	var out := {}
	for id: StringName in _completed_ids():
		var o := order_data(id)
		if o != null:
			out[o.giver] = int(out.get(o.giver, 0)) + completions(id)
	return out


func _completed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _states:
		if _states[id] == STATE_COMPLETED:
			out.append(id)
	for key: String in _progress:
		if key.begins_with(PROGRESS_DONE):
			var id := StringName(key.substr(PROGRESS_DONE.length()))
			if not out.has(id) and int(_progress[key]) > 0:
				out.append(id)
	return out


# --- changes --------------------------------------------------------------------------------------

## Offered in a dialogue / on the board (order_changed offered); false when not offerable.
func offer(order_id: StringName) -> bool:
	var reason := block_reason(order_id)
	if reason != "" and reason != OrderRules.TEXT_MAX_ACTIVE:
		return false
	if state(order_id) != STATE_OFFERED:
		_states[order_id] = STATE_OFFERED
		EventBus.order_changed.emit(order_id, STATE_OFFERED)
	return true


## max_active; accept_flag; order_changed.
func accept(order_id: StringName) -> bool:
	var o := order_data(order_id)
	if o == null or block_reason(order_id) != "":
		return false
	_accept(o, TimeManager.day)
	EventBus.notification_requested.emit(TEXT_ACCEPTED % o.title, &"info")
	# A section that is already cleared counts at once.
	if o.kind == KIND_SECTION:
		_check_section_now(o)
	return true


## deliver / donate atomic → complete. Items (with substitutes, matching specimens) and coins leave
## `inv`; coins are noted as &"donation".
func turn_in(order_id: StringName, inv: Inventory) -> bool:
	var o := order_data(order_id)
	if o == null or inv == null or state(order_id) != STATE_ACCEPTED:
		return false
	if o.kind != KIND_DELIVER and o.kind != KIND_DONATE:
		return false
	if not OrderRules.deliver_ready(o, inv):
		return false
	var snapshot := inv.save_state()
	var used_specimens := PackedStringArray()
	for item: StringName in o.items:
		var need := int(o.items[item])
		if item in OrderRules.SPECIMEN_ITEMS:
			var uids := OrderRules.matching_specimens(o, item, inv)
			for i: int in need:
				used_specimens.append(uids[i])
			continue
		var own := mini(inv.count(item), need)
		if own > 0 and not inv.remove_item(item, own):
			inv.load_state(snapshot)
			return false
		var rest := need - own
		var sub := OrderRules.substitute(o, item)
		if rest > 0 and (sub == &"" or not inv.remove_item(sub, rest)):
			inv.load_state(snapshot)
			return false
	if o.kind == KIND_DONATE and o.coins > 0:
		if not inv.remove_item(COIN_ITEM, o.coins):
			inv.load_state(snapshot)
			return false
	var specimens := _first(SPECIMENS_GROUP)
	for uid: String in used_specimens:
		var gone := false
		if specimens != null and specimens.has_method(&"consume"):
			gone = bool(specimens.call(&"consume", uid, inv, &"sold"))
		if not gone:
			gone = inv.remove_uid(uid)
		if not gone:
			push_warning("[Orders] turn_in(%s): specimen %s could not be handed over" % [order_id, uid])
	if o.kind == KIND_DONATE and o.coins > 0:
		GameState.note_coins_spent(o.coins, REASON_DONATION)
	_pay_into = inv
	complete(order_id)
	_pay_into = null
	return true


## Reward: coins (payment_received), Relationships.add (giver reward_rel + extra_rel),
## Reputation.change(reward_rep); stats.orders_done; thanks; Village.check_goal. Once.
func complete(order_id: StringName) -> void:
	var o := order_data(order_id)
	if o == null or state(order_id) == STATE_COMPLETED:
		return
	_progress[PROGRESS_DONE + String(order_id)] = int(_progress.get(PROGRESS_DONE + String(order_id), 0)) + 1
	_states[order_id] = STATE_COMPLETED
	_accepted_day.erase(order_id)
	_progress.erase(String(order_id))
	_progress.erase(PROGRESS_AT + String(order_id))
	if o.board:
		_history[order_id] = TimeManager.day
		_board.erase(order_id)
	var reason := REASON_ORDER % o.title
	if o.reward_coins > 0:
		var inv := _pay_into if _pay_into != null else _player_inventory()
		if inv != null:
			inv.add_item(COIN_ITEM, o.reward_coins)
		EventBus.payment_received.emit(o.reward_coins, reason)
	if o.giver != COUNCIL and o.reward_rel != 0:
		_rel_add(o.giver, o.reward_rel, reason)
	for npc: StringName in o.extra_rel:
		_rel_add(npc, int(o.extra_rel[npc]), reason)
	if o.reward_rep != 0:
		var rep := _first(REPUTATION_GROUP)
		if rep != null and rep.has_method(&"change"):
			rep.call(&"change", o.reward_rep, reason)
	GameState.add_stat(STAT_DONE, 1)
	EventBus.order_changed.emit(order_id, STATE_COMPLETED)
	if o.thanks_text != "":
		EventBus.notification_requested.emit(o.thanks_text, &"reward")
	var village := _first(VILLAGE_GROUP)
	if village != null and village.has_method(&"check_goal"):
		village.call(&"check_goal")


## Deadline missed or condition broken: relationship −4 (gains.order_failed) with the giver +
## fail_rel, reputation order_failed, stats.orders_failed. Personal orders never come back.
func fail(order_id: StringName) -> void:
	var o := order_data(order_id)
	if o == null or state(order_id) != STATE_ACCEPTED:
		return
	_states[order_id] = STATE_FAILED
	_accepted_day.erase(order_id)
	_progress.erase(String(order_id))
	_progress.erase(PROGRESS_AT + String(order_id))
	if o.board:
		_history[order_id] = TimeManager.day
		_board.erase(order_id)
	var reason := REASON_FAILED % o.title
	if o.giver != COUNCIL and o.fail_rel.is_empty():
		_rel_add(o.giver, int(_rel_cfg().gains.get(&"order_failed", -4)), reason)
	for npc: StringName in o.fail_rel:
		_rel_add(npc, int(o.fail_rel[npc]), reason)
	_rep_event(EVENT_FAILED, reason)
	GameState.add_stat(STAT_FAILED, 1)
	EventBus.order_changed.emit(order_id, STATE_FAILED)
	EventBus.notification_requested.emit(TEXT_FAILED % o.title, &"warning")


## Graveyard: the marker of `grave_id` is set (grave_completed) – bury orders of this corpse.
func note_grave_completed(grave_id: String, corpse_id: String) -> void:
	_check_bury(corpse_id, grave_id)


## Graveyard: a designed stone stands on `grave_id` (set_designed_stone / replace_old_marker) – stone
## orders of this grave and bury orders waiting for their stone.
func note_stone_set(grave_id: String) -> void:
	var graveyard := _first(GRAVEYARD_GROUP)
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	if grave == null:
		return
	for id: StringName in active():
		var o := order_data(id)
		if o != null and o.kind == KIND_STONE and o.target == grave_id and OrderRules.stone_matches(o, grave):
			complete(id)
	if grave.corpse_id != "":
		_check_bury(grave.corpse_id, grave_id)


## ExpansionManager: progress of a section – a section order completes with its last obstacle.
func note_section_progress(section_id: StringName, done: int, total: int) -> void:
	if total <= 0 or done < total:
		return
	for id: StringName in active():
		var o := order_data(id)
		if o != null and o.kind == KIND_SECTION and StringName(o.target) == section_id:
			complete(id)


## CorpseCare: something was harvested from `corpse_id` – bury orders with unharvested → broken → fail.
func note_harvest(corpse_id: String) -> void:
	_check_bury(corpse_id, "")


## STUB (P4) – Phase 8 (docs/PHASE8_DESIGN.md §2.4, §3.4): a meeting of a meet order (npc at place in
## its window; DialogueActions meet:<place>). W0: inert.
func note_meet(_npc_id: StringName, _place_id: StringName) -> void:
	pass


## STUB (P4) – Phase 8: a task of a task order done (archive_help, register_extract, vigil, lights_names …).
## W0: inert.
func note_task(_action_id: StringName) -> void:
	pass


## Deadlines, the tend check, board offers (idempotent per day).
func apply_morning(day: int) -> void:
	if day <= _board_day:
		return
	_board_day = day
	_adopt_arrived_stories()
	# Deadlines (06:00 of accepted_day + days_limit).
	for id: StringName in active():
		var o := order_data(id)
		if o == null or o.days_limit <= 0 or not _deadline_running(o):
			continue
		if day >= accepted_day(id) + o.days_limit:
			fail(id)
	# tend: all occupied graves of the target without a care malus, mornings in a row.
	for id: StringName in active():
		var o := order_data(id)
		if o == null or o.kind != KIND_TEND:
			continue
		var key := String(id)
		_progress[key] = int(_progress.get(key, 0)) + 1 if _tended(StringName(o.target)) else 0
		if int(_progress[key]) >= int(o.conditions.get("mornings", 1)):
			complete(id)
	# Board: yesterday's offers expire, two new ones.
	for id: StringName in _board:
		if state(id) == STATE_OFFERED:
			_states.erase(id)
	_board.clear()
	var pool: Array[OrderData] = []
	for o: OrderData in all_orders():
		if not o.board or state(o.id) == STATE_ACCEPTED:
			continue
		if o.requires_flag != &"" and not GameState.flag_on(o.requires_flag):
			continue
		pool.append(o)
	var history := {}
	for id: StringName in _history:
		history[id] = _history[id]
	_board = OrderRules.board_pick(pool, day, history, _cfg().board_offers)
	for id: StringName in _board:
		_states[id] = STATE_OFFERED
		EventBus.order_changed.emit(id, STATE_OFFERED)


## §5.1: {states, accepted_day, board_day, board, history, progress}.
func save_state() -> Dictionary:
	var states := {}
	for id: StringName in _states:
		states[String(id)] = String(_states[id])
	var days := {}
	for id: StringName in _accepted_day:
		days[String(id)] = _accepted_day[id]
	var history := {}
	for id: StringName in _history:
		history[String(id)] = _history[id]
	var board_ids: Array = []
	for id: StringName in _board:
		board_ids.append(String(id))
	return {"states": states, "accepted_day": days, "board_day": _board_day, "board": board_ids, "history": history,
			"progress": _progress.duplicate()}


## Tolerant: unknown states / ids are dropped (warning for an unknown order with data present).
func load_state(data: Dictionary) -> void:
	_states.clear()
	_accepted_day.clear()
	_history.clear()
	_progress.clear()
	_board.clear()
	var saved: Variant = data.get("states")
	if saved is Dictionary:
		for key: Variant in saved:
			var id := StringName(str(key))
			var s := StringName(str((saved as Dictionary)[key]))
			if not s in STATES:
				push_warning("[Orders] saved state '%s' of '%s' ignored" % [s, id])
				continue
			if not _known(id):
				push_warning("[Orders] saved order '%s' is unknown – dropped" % id)
				continue
			_states[id] = s
	var days: Variant = data.get("accepted_day")
	if days is Dictionary:
		for key: Variant in days:
			var id := StringName(str(key))
			if _states.get(id, &"") == STATE_ACCEPTED:
				_accepted_day[id] = maxi(0, _num((days as Dictionary)[key], 0))
	for id: StringName in _states:
		if _states[id] == STATE_ACCEPTED and not _accepted_day.has(id):
			_accepted_day[id] = maxi(TimeManager.day, 1)
	_board_day = maxi(0, _num(data.get("board_day"), 0))
	var board_ids: Variant = data.get("board")
	if board_ids is Array:
		for v: Variant in board_ids:
			var id := StringName(str(v))
			if _known(id) and not _board.has(id):
				_board.append(id)
	var history: Variant = data.get("history")
	if history is Dictionary:
		for key: Variant in history:
			_history[StringName(str(key))] = _num((history as Dictionary)[key], 0)
	var progress: Variant = data.get("progress")
	if progress is Dictionary:
		for key: Variant in progress:
			_progress[str(key)] = _num((progress as Dictionary)[key], 0)


# --- internals ------------------------------------------------------------------------------------

func _accept(o: OrderData, day: int) -> void:
	_states[o.id] = STATE_ACCEPTED
	_accepted_day[o.id] = day
	if o.kind == KIND_BURY and o.target == OrderRules.NEXT_DELIVERY:
		_progress[PROGRESS_AT + String(o.id)] = TimeManager.total_minutes()
	if o.kind == KIND_TEND:
		_progress[String(o.id)] = 0
	if o.accept_flag != &"":
		GameState.set_flag(o.accept_flag, true)
	EventBus.order_changed.emit(o.id, STATE_ACCEPTED)


## Bury orders whose target story corpse has arrived: accepted at the latest now, the deadline
## counting from her arrival (CorpseManager.story_last_day of the last story, §2.5 „sonst bei ihrer
## Ankunft"). Idempotent; ignores the four-active limit (a wish of the dead).
func _adopt_arrived_stories() -> void:
	var manager := _first(CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"story_delivered"):
		return
	var delivered: PackedStringArray = manager.call(&"story_delivered")
	for o: OrderData in all_orders():
		if o.kind != KIND_BURY or o.target == "" or o.target == OrderRules.NEXT_DELIVERY or not delivered.has(o.target):
			continue
		var s := state(o.id)
		if s == STATE_COMPLETED or s == STATE_FAILED:
			continue
		var arrival := _story_arrival_day(o.target, manager)
		if s != STATE_ACCEPTED:
			_accept(o, arrival)
		elif not _progress.has(PROGRESS_AT + String(o.id)):
			_accepted_day[o.id] = arrival
		_progress[PROGRESS_AT + String(o.id)] = arrival


## Day the story corpse `story_id` arrived: its record's arrival, else story_last_day.
func _story_arrival_day(story_id: String, manager: Node) -> int:
	if manager.has_method(&"records"):
		for r: CorpseRecord in manager.call(&"records"):
			if String(r.story_id) == story_id:
				return floori(float(r.arrival_total_minutes) / MINUTES_PER_DAY) + 1
	return int(manager.call(&"story_last_day")) if manager.has_method(&"story_last_day") else TimeManager.day


## A deadline only runs for story bury orders once the corpse is there.
func _deadline_running(o: OrderData) -> bool:
	if o.kind != KIND_BURY or o.target == "" or o.target == OrderRules.NEXT_DELIVERY:
		return true
	return _progress.has(PROGRESS_AT + String(o.id))


## Evaluates the bury orders whose target is `corpse_id` (grave "" = only the harvest rule).
func _check_bury(corpse_id: String, grave_id: String) -> void:
	_adopt_arrived_stories()
	var manager := _first(CORPSE_MANAGER_GROUP)
	var record := manager.call(&"get_record", corpse_id) as CorpseRecord if manager != null and manager.has_method(&"get_record") else null
	if record == null:
		return
	var grave: GraveRecord = null
	if grave_id != "":
		var graveyard := _first(GRAVEYARD_GROUP)
		if graveyard != null and graveyard.has_method(&"get_grave"):
			grave = graveyard.call(&"get_grave", grave_id) as GraveRecord
	for id: StringName in active():
		var o := order_data(id)
		if o == null or o.kind != KIND_BURY or not _targets(o, record, manager):
			continue
		var result := OrderRules.bury_result(o, record, grave)
		if result == OrderRules.RESULT_DONE and int(o.conditions.get("chapel_level", 0)) > _chapel_level():
			result = OrderRules.RESULT_BROKEN
		if result == OrderRules.RESULT_DONE:
			complete(id)
		elif result == OrderRules.RESULT_BROKEN:
			fail(id)


## The bury order `o` is about `record`: its story id, or the first corpse that arrived after the
## acceptance (next_delivery).
func _targets(o: OrderData, record: CorpseRecord, manager: Node) -> bool:
	if o.target != OrderRules.NEXT_DELIVERY:
		return String(record.story_id) == o.target
	var at := int(_progress.get(PROGRESS_AT + String(o.id), -1))
	if at < 0 or record.arrival_total_minutes < at:
		return false
	var first: CorpseRecord = null
	if manager.has_method(&"records"):
		for r: CorpseRecord in manager.call(&"records"):
			if r.arrival_total_minutes >= at and (first == null or r.arrival_total_minutes < first.arrival_total_minutes \
					or (r.arrival_total_minutes == first.arrival_total_minutes and r.id < first.id)):
				first = r
	return first != null and first.id == record.id


func _check_section_now(o: OrderData) -> void:
	var expansion := _first(&"expansion")
	if expansion == null or not expansion.has_method(&"progress"):
		return
	var p: Vector2i = expansion.call(&"progress", StringName(o.target))
	note_section_progress(StringName(o.target), p.x, p.y)


## Every occupied grave of `section_id` is free of a care malus (its dirt spots at a level with
## penalty 0); at least one occupied grave.
func _tended(section_id: StringName) -> bool:
	var graveyard := _first(GRAVEYARD_GROUP)
	var clean := _first(CLEANLINESS_GROUP)
	if graveyard == null or not graveyard.has_method(&"plots_in_section"):
		return false
	var occupied := {}
	for gid: String in graveyard.call(&"plots_in_section", section_id):
		var g := graveyard.call(&"get_grave", gid) as GraveRecord
		if g != null and (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED):
			occupied[gid] = true
	if occupied.is_empty():
		return false
	if clean == null or not clean.has_method(&"level") or not is_inside_tree():
		return true
	var cfg := Database.config(&"cleanliness_config") as CleanlinessConfig
	for node: Node in get_tree().get_nodes_in_group(DirtSpot.GROUP):
		var spot := node as DirtSpot
		if spot == null or not occupied.has(spot.grave_id):
			continue
		var lvl := int(clean.call(&"level", spot.spot_id))
		var penalty := 0
		if cfg != null and lvl >= 0 and lvl < cfg.penalty_by_level.size():
			penalty = cfg.penalty_by_level[lvl]
		elif lvl >= 2:
			penalty = 1
		if penalty != 0:
			return false
	return true


func _chapel_level() -> int:
	var buildings := _first(BUILDINGS_GROUP)
	return int(buildings.call(&"level", CHAPEL)) if buildings != null and buildings.has_method(&"level") else 0


func _teachings() -> PackedStringArray:
	var lectures := _first(LECTURES_GROUP)
	if lectures == null or not lectures.has_method(&"known_teachings"):
		return PackedStringArray()
	var raw: Variant = lectures.call(&"known_teachings")
	return raw if raw is PackedStringArray else PackedStringArray(raw if raw is Array else [])


func _rel_add(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(RELATIONSHIPS_GROUP)
	if rel != null and rel.has_method(&"add") and delta != 0:
		rel.call(&"add", npc_id, delta, reason)


## Reputation.event when the data knows the event, else the class-default points (the W0 data file
## of reputation_config belongs to P4 and lists the Phase-7 events only after its handover).
func _rep_event(kind: StringName, reason: String) -> void:
	var rep := _first(REPUTATION_GROUP)
	if rep == null:
		return
	var cfg := Database.config(&"reputation_config") as ReputationConfig
	if cfg != null and cfg.event_points.has(kind):
		rep.call(&"event", kind, reason)
		return
	var points := int(ReputationConfig.new().event_points.get(kind, 0))
	if points != 0:
		rep.call(&"change", points, reason)


func _known(id: StringName) -> bool:
	if order_table.is_empty() and Database.orders().is_empty():
		return true
	return order_data(id) != null


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= _cfg().refresh_minute and day > _board_day:
		apply_morning(day)


func _player_inventory() -> Inventory:
	var player := _first(PLAYER_GROUP)
	if player == null:
		return null
	var inv: Variant = player.get(&"inventory")
	return inv as Inventory if inv is Inventory else null


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _cfg() -> OrdersConfig:
	if config == null:
		config = Database.config(&"orders_config") as OrdersConfig
		if config == null:
			config = OrdersConfig.new()
	return config


func _rel_cfg() -> RelationshipConfig:
	if relationship_config == null:
		relationship_config = Database.config(&"relationship_config") as RelationshipConfig
		if relationship_config == null:
			relationship_config = RelationshipConfig.new()
	return relationship_config


static func _num(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
