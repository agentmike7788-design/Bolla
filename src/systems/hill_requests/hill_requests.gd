class_name HillRequests
extends Node
## Systems/HillRequests (G8 Runde 6 „Bitten vom Hügel", docs/PHASE8_DESIGN.md G8 Runde 6), groups &"hill_requests",
## &"saveable", save_id hill_requests / 80: small requests of the village on the cemetery gate's notice board.
## From day 2 Osric pins them at 07:44 (two places before village_open, one afterwards with a longer refill); the
## gravekeeper accepts them in the docked panel (HillRequestsPanel via NoticeBoard); an accepted one has a deadline
## of 1–3 days (checked at 06:00), completes through the EventBus (care spots, examination, burial, marker, ghost,
## clearing, decor) or the hand-over at Osric's cart (carter.tres hill_turn_in) and pays a little reputation, a few
## coins and now and then a small thing. A missed one costs HillRequestsConfig.fail_rep. Never an order of Orders:
## no Phase-7 counter (chapter „Ein Name im Dorf", stats.orders_done, the order limits) sees them.
## Saved: {board, states, accepted_day, posted_day, ended, targets, touched, refill, check_day, post_day, log}; a save
## without this node's state (before G8 Runde 6) loads the default state without a warning (save_optional).

const GROUP := &"hill_requests"
const STATE_OFFERED := &"offered"
const STATE_ACCEPTED := &"accepted"
const STATE_COMPLETED := &"completed"
const STATE_FAILED := &"failed"
const STATE_WITHDRAWN := &"withdrawn"
const BOARD_STATES: Array[StringName] = [STATE_OFFERED, STATE_ACCEPTED]
const LOG_STATES: Array[StringName] = [STATE_COMPLETED, STATE_FAILED]
const COIN_ITEM := &"coin"
const PLAYER_GROUP := &"player"
const REPUTATION_GROUP := &"reputation"
const CLEANLINESS_GROUP := &"cleanliness"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const EXPANSION_GROUP := &"expansion"

@export var save_id: String = "hill_requests"
@export var save_order: int = 80
## SaveStateCollector: a save without this node's state (written before G8 Runde 6) loads load_state({}) silently.
var save_optional: bool = true

## Rules; null = data/config/hill_requests_config.tres (resolved lazily).
var config: HillRequestsConfig
## Requests by id; empty = Database.hill_requests() (tests inject fixtures).
var request_table: Dictionary[StringName, OrderData] = {}

## Ids on the board (offered or accepted), in pinning order.
var _board: Array[StringName] = []
var _states: Dictionary[StringName, StringName] = {}
var _accepted_day: Dictionary[StringName, int] = {}
var _posted_day: Dictionary[StringName, int] = {}
## id → day the request last ended (completed / failed / taken down) – its cooldown.
var _ended: Dictionary[StringName, int] = {}
## id → grave of a tend request with conditions.grave marked_dirty.
var _targets: Dictionary[StringName, String] = {}
## Tend requests with a spot tended since the acceptance.
var _touched: Dictionary[StringName, bool] = {}
## Days from which a free place may be filled again (one entry per free place, sorted).
var _refill: Array[int] = []
var _check_day: int = 0
var _post_day: int = 0
## [{id, day, state, title}] – the newest last, at most HillRequestsConfig.log_size.
var _log: Array[Dictionary] = []
## Inventory the reward of the request being turned in goes to (turn_in → complete).
var _pay_into: Inventory


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.dirt_changed.connect(_on_dirt_changed)
	EventBus.exam_step_done.connect(_on_exam_step_done)
	EventBus.corpse_buried.connect(_on_corpse_buried)
	EventBus.grave_completed.connect(_on_grave_completed)
	EventBus.ghost_spoke.connect(_on_ghost_spoke)
	EventBus.obstacle_cleared.connect(_on_obstacle_cleared)
	EventBus.decor_changed.connect(_on_decor_changed)
	EventBus.new_game_started.connect(_reset)


# --- queries --------------------------------------------------------------------------------------

func request_data(id: StringName) -> OrderData:
	if not request_table.is_empty():
		return request_table.get(id)
	return Database.hill_request(id) as OrderData


## Every request of the pool, sorted by order (then id).
func all_requests() -> Array[OrderData]:
	var out: Array[OrderData] = []
	var list: Array = request_table.values() if not request_table.is_empty() else Database.hill_requests()
	for r: Variant in list:
		if r is OrderData and (r as OrderData).category == OrderData.CATEGORY_HILL:
			out.append(r)
	out.sort_custom(func(a: OrderData, b: OrderData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## Ids on the board (offered and accepted), in pinning order.
func board() -> Array[StringName]:
	return _board.duplicate()


## &"" (not on the board) | offered | accepted.
func state(id: StringName) -> StringName:
	return _states.get(id, &"")


func offered() -> Array[StringName]:
	return _in_state(STATE_OFFERED)


func active() -> Array[StringName]:
	return _in_state(STATE_ACCEPTED)


func accepted_day(id: StringName) -> int:
	return int(_accepted_day.get(id, 0))


func posted_day(id: StringName) -> int:
	return int(_posted_day.get(id, 0))


## Morning the accepted request falls due (0 = not accepted).
func deadline_day(id: StringName) -> int:
	if state(id) != STATE_ACCEPTED:
		return 0
	return HillRules.deadline_day(request_data(id), accepted_day(id))


## Days left of an accepted request (1 = today is the last day; −1 = not accepted).
func days_left(id: StringName) -> int:
	return HillRules.days_left(deadline_day(id), TimeManager.day) if state(id) == STATE_ACCEPTED else -1


## The grave a tend request means ("" = its fixed spots).
func target_grave(id: StringName) -> String:
	return str(_targets.get(id, ""))


## The title with its grave's dead named (marked_dirty).
func title_of(id: StringName) -> String:
	var r := request_data(id)
	return HillRules.fill(r.title, _target_name(id)) if r != null else String(id)


func text_of(id: StringName) -> String:
	var r := request_data(id)
	return HillRules.fill(r.request_text, _target_name(id)) if r != null else ""


## The care spots of a tend request (its grave's own spot for marked_dirty).
func spots_of(id: StringName) -> PackedStringArray:
	return HillRules.spots_of(request_data(id), target_grave(id))


## True from village_open on (one place, longer refill).
func village() -> bool:
	return GameState.flag_on(_cfg().village_flag)


func max_active() -> int:
	return HillRules.max_active(_cfg(), village())


## "" = the request can be accepted now; else the reason.
func accept_reason(id: StringName) -> String:
	return HillRules.accept_block(state(id), active().size(), _cfg(), village())


## True once Osric pinned the first request (the journal's tab „Bitten").
func any_posted() -> bool:
	return _post_day > 0 or not _board.is_empty() or not _log.is_empty()


## The journal's log: [{id, day, state, title}], the newest last.
func history() -> Array[Dictionary]:
	return _log.duplicate(true)


## Accepted deliveries for `giver` (Osric) whose items are in `inv`.
func ready_for(giver: StringName, inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in active():
		var r := request_data(id)
		if r != null and r.kind == HillRules.KIND_DELIVER and HillRules.recipient(r) == giver and HillRules.deliver_ready(r, inv):
			out.append(id)
	return out


## The HUD's view (CemeteryStatus.objective_state "hill"): {active: [{id, title, left, kind, ready}], waiting,
## can_accept}.
func objective_state(inv: Inventory = null) -> Dictionary:
	var list: Array = []
	for id: StringName in active():
		var r := request_data(id)
		if r == null:
			continue
		list.append({"id": id, "title": title_of(id), "left": days_left(id), "kind": r.kind,
				"ready": r.kind == HillRules.KIND_DELIVER and HillRules.deliver_ready(r, inv)})
	return {"active": list, "waiting": offered().size(), "can_accept": active().size() < max_active(), "village": village()}


# --- changes --------------------------------------------------------------------------------------

## Accepts an offered request (max_active); hill_request_changed accepted.
func accept(id: StringName) -> bool:
	var r := request_data(id)
	if r == null or accept_reason(id) != "":
		return false
	_states[id] = STATE_ACCEPTED
	_accepted_day[id] = TimeManager.day
	_touched.erase(id)
	EventBus.hill_request_changed.emit(id, STATE_ACCEPTED)
	EventBus.notification_requested.emit(HillTexts.ACCEPTED % title_of(id), &"info")
	return true


## Osric's cart (carter.tres hill_turn_in:<giver>): every accepted delivery for `giver` whose items are in `inv`
## – the items leave `inv`, the reward goes into it. Returns how many were handed over.
func turn_in(giver: StringName, inv: Inventory) -> int:
	var n := 0
	for id: StringName in ready_for(giver, inv):
		var r := request_data(id)
		if not HillRules.deliver_ready(r, inv):
			continue
		var snapshot := inv.save_state()
		var ok := true
		for item: StringName in r.items:
			if not inv.remove_item(item, int(r.items[item])):
				ok = false
				break
		if not ok:
			inv.load_state(snapshot)
			continue
		_pay_into = inv
		complete(id)
		_pay_into = null
		n += 1
	return n


## Pays the reward (coins → inventory + payment_received, Reputation.change, reward items), notes the thanks
## (`detail` fills its %s), frees the place (refilled after refill_days). Once.
func complete(id: StringName, detail: String = "") -> void:
	var r := request_data(id)
	if r == null or state(id) != STATE_ACCEPTED:
		return
	var title := title_of(id)
	var reason := HillRules.REASON % title
	var inv := _pay_into if _pay_into != null else _player_inventory()
	if r.reward_coins > 0:
		if inv != null:
			inv.add_item(COIN_ITEM, r.reward_coins)
		EventBus.payment_received.emit(r.reward_coins, reason)
	var items := HillRules.reward_items(r)
	if inv != null:
		for item: StringName in items:
			inv.add_item(item, items[item])
	if r.reward_rep != 0:
		var rep := _first(REPUTATION_GROUP)
		if rep != null and rep.has_method(&"change"):
			rep.call(&"change", r.reward_rep, reason)
	var thanks := HillRules.fill(r.thanks_text, detail if detail != "" else _target_name(id))
	_end(id, STATE_COMPLETED, TimeManager.day)
	if thanks != "":
		EventBus.notification_requested.emit(thanks, &"reward")
	EventBus.notification_requested.emit(HillTexts.reward_note(title, HillRules.reward_parts(r)), &"reward")


## Deadline missed: fail_rep, the place frees.
func fail(id: StringName, end_day: int = -1) -> void:
	var r := request_data(id)
	if r == null or state(id) != STATE_ACCEPTED:
		return
	var title := title_of(id)
	var points := _cfg().fail_rep
	if points != 0:
		var rep := _first(REPUTATION_GROUP)
		if rep != null and rep.has_method(&"change"):
			rep.call(&"change", points, HillRules.REASON_FAILED % title)
	_end(id, STATE_FAILED, end_day if end_day >= 0 else TimeManager.day)
	EventBus.notification_requested.emit(HillTexts.FAILED % title, &"warning")


## An offered request taken down unanswered (no consequence).
func withdraw(id: StringName, end_day: int = -1) -> void:
	if state(id) != STATE_OFFERED:
		return
	_end(id, STATE_WITHDRAWN, end_day if end_day >= 0 else TimeManager.day)


## 06:00: deadlines and offered requests that hung long enough (both ended „last night" – day − 1).
func apply_morning(day: int) -> void:
	if day <= _check_day:
		return
	_check_day = day
	for id: StringName in active():
		if day >= deadline_day(id):
			fail(id, day - 1)
	for id: StringName in offered():
		if day >= posted_day(id) + maxi(1, _cfg().offer_days):
			withdraw(id, day - 1)


## 07:44: Osric pins a request on every free place whose refill day has come (from start_day). Returns the
## number pinned (HUD note „Osric hat eine Bitte ans Tor geheftet.").
func post(day: int) -> int:
	if day <= _post_day or day < _cfg().start_day:
		return 0
	_post_day = day
	var cfg := _cfg()
	var vill := village()
	var free := HillRules.slots(cfg, vill) - _board.size()
	_refill.sort()
	while _refill.size() > maxi(free, 0):
		_refill.pop_back()
	while _refill.size() < free:
		_refill.append(day)
	var pinned := 0
	var slot := 0
	var keep: Array[int] = []
	for when: int in _refill:
		if when > day:
			keep.append(when)
			continue
		var id := HillRules.pick(all_requests(), offer_context(day), slot)
		slot += 1
		if id == &"":
			keep.append(when)
			continue
		_board.append(id)
		_states[id] = STATE_OFFERED
		_posted_day[id] = day
		_targets.erase(id)
		_touched.erase(id)
		var r := request_data(id)
		if r.kind == HillRules.KIND_TEND and str(r.conditions.get("grave", "")) == HillRules.GRAVE_MARKED_DIRTY:
			_targets[id] = HillRules.pick_grave(_dirty_graves(), day)
		pinned += 1
		EventBus.hill_request_changed.emit(id, STATE_OFFERED)
	_refill = keep
	if pinned > 0:
		EventBus.notification_requested.emit(HillTexts.posted(pinned), &"info")
	return pinned


## The context HillRules.offer_block / pick read (see hill_rules.gd).
func offer_context(day: int) -> Dictionary:
	var givers: Array = []
	for id: StringName in _board:
		var r := request_data(id)
		if r != null:
			givers.append(r.giver)
	var ended := {}
	for id: StringName in _ended:
		ended[id] = _ended[id]
	var items: Array = []
	var inv := _player_inventory()
	if inv != null:
		for slot: Dictionary in inv.get_slots():
			var item := StringName(str(slot.get("id", "")))
			if item != &"" and not items.has(item):
				items.append(item)
		for t: StringName in inv.tools():
			if not items.has(t):
				items.append(t)
	return {"day": day, "village": village(), "on_board": _board.duplicate(), "givers": givers, "ended": ended,
			"levels": _levels(), "dirty_graves": _dirty_graves(), "free_plots": _free_plots(), "marked": _marked(),
			"items": items, "open_obstacles": _open_obstacles()}


# --- save -----------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var states := {}
	for id: StringName in _states:
		states[String(id)] = String(_states[id])
	return {"board": _board.map(func(id: StringName) -> String: return String(id)), "states": states,
			"accepted_day": _str_keys(_accepted_day), "posted_day": _str_keys(_posted_day), "ended": _str_keys(_ended),
			"targets": _str_keys(_targets), "touched": _touched.keys().map(func(id: StringName) -> String: return String(id)),
			"refill": _refill.duplicate(), "check_day": _check_day, "post_day": _post_day, "log": _log.duplicate(true)}


## Tolerant: unknown ids and broken values are dropped; {} (a save before G8 Runde 6) = the default state.
func load_state(data: Dictionary) -> void:
	_reset()
	var states: Variant = data.get("states")
	var raw_board: Variant = data.get("board")
	if raw_board is Array:
		for v: Variant in raw_board:
			var id := StringName(str(v))
			var s := StringName(str((states as Dictionary).get(String(id), ""))) if states is Dictionary else &""
			if request_data(id) == null or _board.has(id) or not s in BOARD_STATES:
				continue
			_board.append(id)
			_states[id] = s
	var cap := maxi(_cfg().slots_early, _cfg().slots_village)
	while _board.size() > cap:
		_states.erase(_board.pop_back())
	for id: StringName in _board:
		_posted_day[id] = maxi(0, _num(_dict(data, "posted_day").get(String(id)), 0))
		if _states[id] == STATE_ACCEPTED:
			_accepted_day[id] = maxi(1, _num(_dict(data, "accepted_day").get(String(id)), TimeManager.day))
		var target := str(_dict(data, "targets").get(String(id), ""))
		if target != "":
			_targets[id] = target
	var ended := _dict(data, "ended")
	for key: Variant in ended:
		var id := StringName(str(key))
		if request_data(id) != null:
			_ended[id] = _num(ended[key], 0)
	var touched: Variant = data.get("touched")
	if touched is Array:
		for v: Variant in touched:
			var id := StringName(str(v))
			if _states.get(id, &"") == STATE_ACCEPTED:
				_touched[id] = true
	var refill: Variant = data.get("refill")
	if refill is Array:
		for v: Variant in refill:
			if v is int or v is float:
				_refill.append(int(v))
	_refill.sort()
	_check_day = maxi(0, _num(data.get("check_day"), 0))
	_post_day = maxi(0, _num(data.get("post_day"), 0))
	var log_raw: Variant = data.get("log")
	if log_raw is Array:
		for e: Variant in log_raw:
			if e is Dictionary and StringName(str((e as Dictionary).get("state", ""))) in LOG_STATES:
				_log.append({"id": StringName(str(e.get("id", ""))), "day": _num(e.get("day"), 0),
						"state": StringName(str(e.get("state"))), "title": str(e.get("title", ""))})
	while _log.size() > maxi(1, _cfg().log_size):
		_log.pop_front()


# --- internals ------------------------------------------------------------------------------------

func _reset() -> void:
	_board.clear()
	_states.clear()
	_accepted_day.clear()
	_posted_day.clear()
	_ended.clear()
	_targets.clear()
	_touched.clear()
	_refill.clear()
	_check_day = 0
	_post_day = 0
	_log.clear()


func _end(id: StringName, end_state: StringName, day: int) -> void:
	var title := title_of(id)
	_board.erase(id)
	_states.erase(id)
	_accepted_day.erase(id)
	_posted_day.erase(id)
	_targets.erase(id)
	_touched.erase(id)
	_ended[id] = day
	if _board.size() < HillRules.slots(_cfg(), village()):
		_refill.append(day + HillRules.refill_days(_cfg(), village()))
		_refill.sort()
	if end_state in LOG_STATES:
		_log.append({"id": id, "day": TimeManager.day, "state": end_state, "title": title})
		while _log.size() > maxi(1, _cfg().log_size):
			_log.pop_front()
	EventBus.hill_request_changed.emit(id, end_state)


func _in_state(wanted: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _board:
		if state(id) == wanted:
			out.append(id)
	return out


func _accepted_of(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in active():
		var r := request_data(id)
		if r != null and r.kind == kind:
			out.append(id)
	return out


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	var cfg := _cfg()
	if minute >= cfg.refresh_minute and day > _check_day:
		apply_morning(day)
	if minute >= cfg.post_minute and day > _post_day and day >= cfg.start_day:
		post(day)


func _on_dirt_changed(spot_id: String, level: int) -> void:
	if SaveManager.is_loading:
		return
	for id: StringName in _accepted_of(HillRules.KIND_TEND):
		var spots := spots_of(id)
		if not spots.has(spot_id):
			continue
		if level == 0:
			_touched[id] = true
		if HillRules.tend_done(spots, _levels(), bool(_touched.get(id, false))):
			complete(id)


func _on_exam_step_done(corpse_id: String, _step: StringName, _revealed: Array[StringName], _lost: Array[StringName]) -> void:
	if SaveManager.is_loading:
		return
	var record := _record(corpse_id)
	if record == null or not record.is_fully_examined():
		return
	for id: StringName in _accepted_of(HillRules.KIND_EXAM):
		complete(id, HillTexts.finding(record.display_name, Phase7Texts.cause_label(record.cause_id)))
		return


func _on_corpse_buried(corpse_id: String, _grave_id: String) -> void:
	if SaveManager.is_loading:
		return
	var record := _record(corpse_id)
	for id: StringName in _accepted_of(HillRules.KIND_PREP):
		if HillRules.prep_ok(request_data(id), record):
			complete(id, record.display_name)
			return


func _on_grave_completed(grave_id: String, _corpse_id: String, _quality: int, _breakdown: Array) -> void:
	if SaveManager.is_loading:
		return
	var graveyard := _first(GRAVEYARD_GROUP)
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	for id: StringName in _accepted_of(HillRules.KIND_MARKER):
		if HillRules.marker_ok(request_data(id), grave):
			var record := _record(grave.corpse_id)
			complete(id, record.display_name if record != null else "")
			return


func _on_ghost_spoke(_grave_id: String, _mood: StringName, text: String) -> void:
	if SaveManager.is_loading:
		return
	for id: StringName in _accepted_of(HillRules.KIND_GHOST):
		complete(id, text)
		return


func _on_obstacle_cleared(_obstacle_id: String, section_id: StringName) -> void:
	if SaveManager.is_loading:
		return
	for id: StringName in _accepted_of(HillRules.KIND_CLEAR):
		if HillRules.clear_ok(request_data(id), section_id):
			complete(id)
			return


func _on_decor_changed(_uid: String, decor_id: StringName, placed: bool) -> void:
	if SaveManager.is_loading or not placed:
		return
	for id: StringName in _accepted_of(HillRules.KIND_DECOR):
		if HillRules.decor_ok(request_data(id), decor_id):
			complete(id)
			return


func _target_name(id: StringName) -> String:
	var grave_id := target_grave(id)
	if grave_id == "":
		return ""
	var graveyard := _first(GRAVEYARD_GROUP)
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	var record := _record(grave.corpse_id) if grave != null else null
	return record.display_name if record != null and record.display_name != "" else HillTexts.GRAVE_FALLBACK


func _levels() -> Dictionary:
	var out := {}
	var clean := _first(CLEANLINESS_GROUP)
	if clean == null or not clean.has_method(&"spot_ids"):
		return out
	for s: String in clean.call(&"spot_ids"):
		out[s] = int(clean.call(&"level", s))
	return out


func _dirty_graves() -> Array:
	var out: Array = []
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	var levels := _levels()
	for g: GraveRecord in graveyard.call(&"graves"):
		if g.state == GraveRecord.State.MARKED and int(levels.get(HillRules.GRAVE_SPOT_PREFIX + g.id, 0)) >= 1:
			out.append(g.id)
	return out


func _free_plots() -> int:
	var n := 0
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"graves"):
		for g: GraveRecord in graveyard.call(&"graves"):
			if g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG:
				n += 1
	return n


func _marked() -> int:
	var n := 0
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"graves"):
		for g: GraveRecord in graveyard.call(&"graves"):
			if g.state == GraveRecord.State.MARKED:
				n += 1
	return n


## Section id → uncleared obstacles, for every workable section (unlocked or open to work).
func _open_obstacles() -> Dictionary:
	var out := {}
	var expansion := _first(EXPANSION_GROUP) as ExpansionManager
	if expansion == null:
		return out
	for s: SectionData in expansion.sections():
		if expansion.block_reason(s.id) != "":
			continue
		var n := 0
		for o: String in expansion.obstacle_ids(s.id):
			if not expansion.is_cleared(o):
				n += 1
		out[s.id] = n
	return out


func _record(corpse_id: String) -> CorpseRecord:
	var manager := _first(CORPSE_MANAGER_GROUP)
	return manager.call(&"get_record", corpse_id) as CorpseRecord if manager != null and manager.has_method(&"get_record") else null


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


func _cfg() -> HillRequestsConfig:
	if config == null:
		config = Database.config(&"hill_requests_config") as HillRequestsConfig
		if config == null:
			config = HillRequestsConfig.new()
	return config


static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[String(k)] = d[k]
	return out


static func _dict(data: Dictionary, key: String) -> Dictionary:
	var v: Variant = data.get(key)
	return v if v is Dictionary else {}


static func _num(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
