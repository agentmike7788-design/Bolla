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
##
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3, §3.4, §5.1): from day 2 Osric also pins one large request
## (OrderData size large, 2–4 parts, data/hill_requests/large) at the gate; from village_open a second one hangs at the
## parish board (VillageBoard). One is accepted at a time (besides the small ones); its parts count in any order
## unless parts_in_order is set, each part done is a HUD line and hill_request_part; all done pays reputation, coins,
## often a thing and from village_open relationship to the giver; at the deadline half done pays half the coins (no
## reputation), less costs large_fail_rep. The small requests stay exactly as they were: an offered large request
## never changes their pick (only an accepted one blocks its giver), so the old bots run bit-identical.
## Saved in addition: {large_board, parts, large_refill, large_ended, ghost_night} (§5.1) + large_progress (the
## counts of craft / gather / decor / flowers parts) and large_targets (graves / spots a part was given); posted and
## accepted days of large requests share posted_day / accepted_day. A save without them loads the default state.

const GROUP := &"hill_requests"
const STATE_OFFERED := &"offered"
const STATE_ACCEPTED := &"accepted"
const STATE_COMPLETED := &"completed"
const STATE_FAILED := &"failed"
const STATE_WITHDRAWN := &"withdrawn"
## Phase 9: a large request half done at its deadline (half the coins, no reputation).
const STATE_HALF := &"half"
const BOARD_STATES: Array[StringName] = [STATE_OFFERED, STATE_ACCEPTED]
const LOG_STATES: Array[StringName] = [STATE_COMPLETED, STATE_FAILED, STATE_HALF]
const PLACES: Array[StringName] = [OrderData.PLACE_GATE, OrderData.PLACE_VILLAGE]
const RELATIONSHIPS_GROUP := &"relationships"
const VISITORS_GROUP := &"visitors"
const DECORATIONS_GROUP := &"decorations"
const WORKSHOP_GROUP := &"workshop"
const CHAPEL_GROUP := &"chapel_rites"
const WORLD_GROUP := &"world"
const REGION_GROUP := &"region_root"
const WAYPOINTS := "Waypoints"
const SPOT_PREFIX := "dirt_"
## A visit part: the player within this distance of its waypoint (§2.3.2: ≤ 3 m).
const VISIT_RADIUS := 3.0
## A meet part: the speaker within this distance of the place (a waypoint, the family's grave).
const MEET_RADIUS := 8.0
## A decor part with conditions.near: the piece within this distance of the place's waypoint.
const NEAR_RADIUS := 9.0
const GATE_NEAR_WAYPOINT := &"gate_inside"
const STAT_LARGE_DONE := &"large_requests_done"
const STAT_LARGE_HALF := &"large_requests_half"
const STAT_LARGE_FAILED := &"large_requests_failed"
const STAT_LARGE_PARTS := &"large_request_parts"
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
## Phase 9 (§5.1): place → large ids pinned there (offered or accepted), in pinning order.
var _large_board: Dictionary[StringName, Array] = {}
## Accepted large requests: id → done flag per part (OrderData.parts order). An id here is accepted.
var _parts: Dictionary[StringName, Array] = {}
## id → count per part (craft / gather / decor / flowers progress).
var _large_progress: Dictionary[StringName, Array] = {}
## id → {"corpse", "grave", "p<i>": [spots / graves]} – what a part was given (tend spots, flowers graves, the dead).
var _large_targets: Dictionary[StringName, Dictionary] = {}
## place → days from which a free large place may be filled again.
var _large_refill: Dictionary[StringName, Array] = {}
## id → day the large request last ended (its cooldown).
var _large_ended: Dictionary[StringName, int] = {}
## The night of a ghosts part: {night, count, graves} (distinct graves heard; GhostManager.night_index).
var _ghost_night: Dictionary = {}
## Item → its count in the player's inventory when last seen (gather parts; not saved, re-read after a load).
var _gather_seen: Dictionary[StringName, int] = {}
var _watched_inv: Inventory


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
	# Phase 9: the parts of the larger requests (only while one is accepted).
	EventBus.craft_finished.connect(_on_large_craft)
	EventBus.dirt_changed.connect(_on_large_dirt)
	EventBus.exam_step_done.connect(_on_large_exam)
	EventBus.corpse_buried.connect(_on_large_buried)
	EventBus.grave_completed.connect(_on_large_marker)
	EventBus.ghost_spoke.connect(_on_large_ghost)
	EventBus.obstacle_cleared.connect(_on_large_clear)
	EventBus.decor_changed.connect(_on_large_decor)
	EventBus.devotion_held.connect(_on_large_devotion)
	EventBus.grave_care_changed.connect(_on_large_care)
	EventBus.dialogue_requested.connect(_on_large_dialogue)
	EventBus.world_ready.connect(_on_large_world.unbind(1))
	EventBus.game_loaded.connect(_on_large_world.unbind(1))


# --- queries --------------------------------------------------------------------------------------

## A small request – or (Phase 9) a large one – by id.
func request_data(id: StringName) -> OrderData:
	if not request_table.is_empty():
		return request_table.get(id)
	var r := Database.hill_request(id) as OrderData
	return r if r != null else Database.large_request(id) as OrderData


## Every small request of the pool, sorted by order (then id).
func all_requests() -> Array[OrderData]:
	var out: Array[OrderData] = []
	var list: Array = request_table.values() if not request_table.is_empty() else Database.hill_requests()
	for r: Variant in list:
		if r is OrderData and (r as OrderData).category == OrderData.CATEGORY_HILL and not HillRules.is_large(r):
			out.append(r)
	out.sort_custom(func(a: OrderData, b: OrderData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## Ids on the board (offered and accepted), in pinning order.
func board() -> Array[StringName]:
	return _board.duplicate()


## &"" (not on the board) | offered | accepted – small and (Phase 9) large requests.
func state(id: StringName) -> StringName:
	if _parts.has(id):
		return STATE_ACCEPTED
	if _large_place_of(id) != &"":
		return STATE_OFFERED
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


## "" = the request can be accepted now; else the reason. A small one is also blocked while an accepted large
## request has its giver (never two of one giver at once).
func accept_reason(id: StringName) -> String:
	if is_large(id):
		return HillRules.large_accept_block(state(id), _large_place_of(id), large_active().size(), _cfg(), _busy_giver(id))
	var reason := HillRules.accept_block(state(id), active().size(), _cfg(), village())
	if reason == "" and not _parts.is_empty():
		return _busy_giver_reason(id)
	return reason


## True once Osric pinned the first request (the journal's tab „Bitten").
func any_posted() -> bool:
	return _post_day > 0 or not _board.is_empty() or not _log.is_empty()


## The journal's log: [{id, day, state, title}], the newest last.
func history() -> Array[Dictionary]:
	return _log.duplicate(true)


## Accepted deliveries for `giver` (Osric) whose items are in `inv` – Phase 9: also the large requests whose open
## deliver part goes to `giver` (Osric, Quast, Lenz …).
func ready_for(giver: StringName, inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in active():
		var r := request_data(id)
		if r != null and r.kind == HillRules.KIND_DELIVER and HillRules.recipient(r) == giver and HillRules.deliver_ready(r, inv):
			out.append(id)
	for id: StringName in large_active():
		if _ready_deliver_part(id, giver, inv) >= 0:
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
	return {"active": list, "waiting": offered().size(), "can_accept": active().size() < max_active(), "village": village(),
			"large": large_objectives(inv), "large_waiting": large_waiting()}


# --- changes --------------------------------------------------------------------------------------

## Accepts an offered request (max_active); hill_request_changed accepted. Phase 9: a large one (large_max_active).
func accept(id: StringName) -> bool:
	if is_large(id):
		return _accept_large(id)
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
	n += _turn_in_large(giver, inv)
	return n


## Pays the reward (coins → inventory + payment_received, Reputation.change, reward items), notes the thanks
## (`detail` fills its %s), frees the place (refilled after refill_days). Once.
func complete(id: StringName, detail: String = "") -> void:
	if is_large(id):
		_finish_large(id, STATE_COMPLETED, TimeManager.day)
		return
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
	if is_large(id):
		_finish_large(id, STATE_FAILED, end_day if end_day >= 0 else TimeManager.day)
		return
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
	if is_large(id):
		_end_large(id, STATE_WITHDRAWN, end_day if end_day >= 0 else TimeManager.day)
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
	_large_morning(day)


## 07:44: Osric pins a request on every free place whose refill day has come (from start_day). Returns the
## number pinned (HUD note „Osric hat eine Bitte ans Tor geheftet.").
func post(day: int) -> int:
	if day <= _post_day or day < mini(_cfg().start_day, _cfg().large_start_day):
		return 0
	_post_day = day
	var small := _post_small(day) if day >= _cfg().start_day else 0
	var large := _post_large(day, small) if day >= _cfg().large_start_day else 0
	return small + large


## The small requests of post(day) (G8 Runde 6, unchanged).
func _post_small(day: int) -> int:
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


## Debug console / tests / shots: pins `id` now without its offer conditions (a free place is used when there is
## one, else the place of the oldest offered request). false = unknown or already on the board.
func pin(id: StringName, grave_id: String = "") -> bool:
	if is_large(id):
		return pin_large(id)
	var r := request_data(id)
	if r == null or _board.has(id):
		return false
	if _board.size() >= HillRules.slots(_cfg(), village()):
		var old := offered()
		if old.is_empty():
			return false
		withdraw(old[0])
	if not _refill.is_empty():
		_refill.pop_front()
	_board.append(id)
	_states[id] = STATE_OFFERED
	_posted_day[id] = TimeManager.day
	_ended.erase(id)
	_touched.erase(id)
	_targets.erase(id)
	if r.kind == HillRules.KIND_TEND and str(r.conditions.get("grave", "")) == HillRules.GRAVE_MARKED_DIRTY:
		_targets[id] = grave_id if grave_id != "" else HillRules.pick_grave(_dirty_graves(), TimeManager.day)
	_post_day = maxi(_post_day, TimeManager.day)
	EventBus.hill_request_changed.emit(id, STATE_OFFERED)
	return true


## The context HillRules.offer_block / pick read (see hill_rules.gd).
func offer_context(day: int) -> Dictionary:
	var givers: Array = []
	for id: StringName in _board:
		var r := request_data(id)
		if r != null:
			givers.append(r.giver)
	# Phase 9: an accepted large request blocks its giver (an offered one does not – the small pick stays as it was).
	for id: StringName in _parts:
		var large := large_data(id)
		if large != null and not givers.has(large.giver):
			givers.append(large.giver)
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


# --- Phase 9: larger requests (docs/PHASE9_DESIGN.md §2.3, §3.4) -----------------------------------------------

## A large request by id (request_table when set, else data/hill_requests/large); null for a small / unknown one.
func large_data(id: StringName) -> OrderData:
	var r: OrderData = request_table.get(id) if not request_table.is_empty() else Database.large_request(id) as OrderData
	return r if HillRules.is_large(r) else null


func is_large(id: StringName) -> bool:
	return large_data(id) != null


## Every large request of the pool, sorted by order (then id).
func all_large() -> Array[OrderData]:
	var out: Array[OrderData] = []
	var list: Array = request_table.values() if not request_table.is_empty() else Database.large_requests()
	for r: Variant in list:
		if r is OrderData and HillRules.is_large(r) and (r as OrderData).category == OrderData.CATEGORY_HILL:
			out.append(r)
	out.sort_custom(func(a: OrderData, b: OrderData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## Done flags of the parts of the large request `id` (in the order of OrderData.parts); [] = not a running one.
func parts_done(id: StringName) -> Array[bool]:
	var out: Array[bool] = []
	for v: Variant in _parts.get(id, []):
		out.append(v == true)
	return out


## Large requests pinned at &"gate" | &"village" (offered or accepted), in pinning order.
func large_board(place: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for v: Variant in _large_board.get(place, []):
		out.append(StringName(str(v)))
	return out


## Every large id on both boards.
func large_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for place: StringName in PLACES:
		out.append_array(large_board(place))
	return out


## The accepted large requests (at most large_max_active).
func large_active() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in large_ids():
		if _parts.has(id):
			out.append(id)
	return out


## Offered large requests (all places, or only `place`).
func large_offered(place: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for p: StringName in PLACES:
		if place != &"" and p != place:
			continue
		for id: StringName in large_board(p):
			if not _parts.has(id):
				out.append(id)
	return out


## Places with an offered large request the player may accept now (HUD „Eine große Bitte am Tor wartet").
func large_waiting() -> Array[StringName]:
	var out: Array[StringName] = []
	if large_active().size() >= maxi(0, _cfg().large_max_active):
		return out
	for place: StringName in PLACES:
		if not large_offered(place).is_empty():
			out.append(place)
	return out


## Count of the part `index` (craft / gather / decor / flowers).
func part_progress(id: StringName, index: int) -> int:
	var p: Array = _large_progress.get(id, [])
	return int(p[index]) if index >= 0 and index < p.size() else 0


## What part `index` was given: the care spots of a tend part (fixed, the dead's neighbours, the night's ghosts), the
## graves still without flowers of a flowers part ([] = none yet).
func part_targets(id: StringName, index: int) -> PackedStringArray:
	return _targets_of(id, index)


## The open parts of an accepted large request (any order, or the next one with parts_in_order).
func open_parts(id: StringName) -> Array[int]:
	if not _parts.has(id):
		return [] as Array[int]
	return HillRules.open_parts(large_data(id), parts_done(id))


## The next open part (−1 = none / not running).
func next_part(id: StringName) -> int:
	var open := open_parts(id)
	return open[0] if not open.is_empty() else -1


## Part kind visit: why the player cannot start it here and now ("" = can).
func visit_block_reason(id: StringName, player: Player) -> String:
	var r := large_data(id)
	if r == null or not _parts.has(id):
		return HillRules.TEXT_VISIT_NOT_RUNNING
	var index := _visit_part(id)
	if index < 0:
		return HillRules.TEXT_VISIT_FIRST if _has_kind(r, HillRules.KIND_VISIT) and not _visit_done(id) else HillRules.TEXT_VISIT_NONE
	var part := HillRules.parts_of(r)[index]
	if player == null or not is_instance_valid(player) or player.is_busy():
		return HillRules.TEXT_VISIT_BUSY
	var at: Variant = _place_position(StringName(str(part.conditions.get("place", ""))))
	if at == null or (player.global_position - (at as Vector3)).length() > VISIT_RADIUS:
		return HillRules.TEXT_VISIT_HERE
	var w := HillRules.visit_window(part)
	if w.x >= 0 and not OrderRules.in_window([w.x, w.y], TimeManager.minute_of_day):
		return HillRules.TEXT_VISIT_WINDOW % [UIKit.clock(w.x), UIKit.clock(w.y)]
	return ""


## Part kind visit: starts the TimedAction of the open visit part (the player of the group; nothing when
## visit_block_reason says no). The part is done when the action ends.
func start_visit(id: StringName) -> void:
	var player := _first(PLAYER_GROUP) as Player
	if visit_block_reason(id, player) != "":
		return
	var index := _visit_part(id)
	var part := HillRules.parts_of(large_data(id))[index]
	player.start_timed_action(HillRules.visit_action_label(part), HillRules.visit_minutes(part),
			_finish_visit.bind(id, StringName(str(part.conditions.get("place", "")))), true)


## The accepted large request whose open visit part can be started where `player` stands now (&"" = none) – for
## the prompt of the waypoint (W-Welt).
func visit_here(player: Player) -> StringName:
	for id: StringName in large_active():
		if _visit_part(id) >= 0 and visit_block_reason(id, player) == "":
			return id
	return &""


## The prompt of the open visit part of `id` („[E] Steine abladen (20 Min)"; "" = none).
func visit_prompt(id: StringName) -> String:
	var index := _visit_part(id)
	return HillRules.visit_prompt(HillRules.parts_of(large_data(id))[index]) if index >= 0 else ""


## At the deadline at least HillRequestsConfig.half_ratio of the parts were done: for a running request „it would
## be half done now", for an ended one its log entry says half.
func half_done(id: StringName) -> bool:
	if _parts.has(id):
		return HillRules.half_reached(parts_done(id), _cfg().half_ratio)
	for i: int in range(_log.size() - 1, -1, -1):
		if _log[i].id == id:
			return _log[i].state == STATE_HALF
	return false


## Phase 9: a meeting a dialogue reports (DialogueActions meet:<place> of P6 may call it; HillRequests also sees
## every dialogue_requested itself): npc_id spoken to at place_id now.
func note_meet(npc_id: StringName, place_id: StringName) -> void:
	_large_event(HillRules.EV_MEET, {"npc": npc_id, "place": place_id, "minute": TimeManager.minute_of_day})


## Debug console (`large <id>`) / tests / shots: pins the large request `id` at its place now without its offer
## conditions (an offered one there is taken down). false = unknown, already pinned, or the place holds an accepted one.
func pin_large(id: StringName) -> bool:
	var r := large_data(id)
	if r == null or _large_place_of(id) != &"":
		return false
	var place := r.place
	var board: Array = _large_board.get_or_add(place, [])
	var cap := maxi(1, HillRules.large_slots(_cfg(), place, true))
	if board.size() >= cap:
		var old := large_offered(place)
		if old.is_empty():
			return false
		withdraw(old[0])
	var refill: Array = _large_refill.get(place, [])
	if not refill.is_empty():
		refill.pop_front()
	(_large_board.get_or_add(place, []) as Array).append(id)
	_posted_day[id] = TimeManager.day
	_large_ended.erase(id)
	_post_day = maxi(_post_day, TimeManager.day)
	EventBus.hill_request_changed.emit(id, STATE_OFFERED)
	return true


## Debug console (`large part <id> <n>`) / tests: marks part `index` of the accepted large request done (or open
## again). A last part done completes the request.
func set_part(id: StringName, index: int, done: bool = true) -> bool:
	if not _parts.has(id) or index < 0 or index >= (_parts[id] as Array).size():
		return false
	if done:
		_part_finished(id, index)
	elif (_parts[id] as Array)[index]:
		(_parts[id] as Array)[index] = false
		EventBus.hill_request_part.emit(id, index, false)
	return true


## The card of a large request for the panels (gate / parish board, §2.3.4): {id, title, giver, giver_name, text,
## place, state, parts: [{title, done, progress, need}], days_limit, days_left, hangs_left, reward, accept_reason,
## parts_in_order}.
func large_card(id: StringName) -> Dictionary:
	var r := large_data(id)
	if r == null:
		return {}
	var done := parts_done(id)
	var parts: Array = []
	var list := HillRules.parts_of(r)
	for i: int in list.size():
		var part := list[i]
		parts.append({"title": part.title if part != null else "", "done": i < done.size() and done[i],
				"progress": part_progress(id, i), "need": HillRules.need(part), "kind": part.kind if part != null else &""})
	var st := state(id)
	return {"id": id, "title": r.title, "giver": r.giver, "giver_name": HillRules.giver_name(r.giver), "text": r.request_text,
			"place": r.place, "state": st, "parts": parts, "days_limit": r.days_limit, "days_left": days_left(id),
			"hangs_left": maxi(0, posted_day(id) + maxi(1, _cfg().large_offer_days) - TimeManager.day) if st == STATE_OFFERED else 0,
			"reward": HillRules.large_reward_line(r), "accept_reason": accept_reason(id) if st == STATE_OFFERED else "",
			"parts_in_order": r.parts_in_order}


## The HUD lines of the accepted large requests: [{id, title, line, left, done, total, ready}] – line „Bitte: Die
## Gräber der Fähre – Zwei Zierstücke im Alten Hof (1/2)" (the next open part).
func large_objectives(inv: Inventory = null) -> Array:
	var out: Array = []
	for id: StringName in large_active():
		var r := large_data(id)
		var done := parts_done(id)
		out.append({"id": id, "title": r.title, "line": large_line(id), "left": days_left(id),
				"done": HillRules.done_count(done), "total": done.size(),
				"ready": inv != null and _ready_deliver_part(id, HillRules.recipient(_part(id, next_part(id))), inv) >= 0})
	return out


## „Bitte: Die Gräber der Fähre – Zwei Zierstücke im Alten Hof (1/2)" for the next open part ("" = not running).
func large_line(id: StringName) -> String:
	var index := next_part(id)
	var r := large_data(id)
	if index < 0 or r == null:
		return ""
	var part := _part(id, index)
	var need := HillRules.need(part)
	if need > 1:
		return HillRules.TEXT_OBJECTIVE_COUNT % [r.title, part.title, mini(part_progress(id, index), need), need]
	return HillRules.TEXT_OBJECTIVE % [r.title, part.title]


## The context HillRules.large_offer_block reads (see hill_rules.gd).
func large_offer_context(day: int) -> Dictionary:
	var ctx := offer_context(day)
	var givers: Array = ctx.get("givers", [])
	for id: StringName in large_ids():
		var r := large_data(id)
		if r != null and not givers.has(r.giver):
			givers.append(r.giver)
	ctx["givers"] = givers
	ctx["large_on_board"] = large_ids()
	var ended := {}
	for id: StringName in _large_ended:
		ended[id] = _large_ended[id]
	ctx["large_ended"] = ended
	ctx["marked_by_section"] = _marked_by_section()
	ctx["stations"] = _stations()
	ctx["gather_items"] = _gather_items()
	ctx["node_items"] = _gather_items(false)
	ctx["pile_daily"] = _pile_daily()
	ctx["clear_yields"] = _clear_yields()
	ctx["decor_room"] = _decor_room()
	ctx["places"] = _known_places()
	ctx["chapel"] = _chapel_ready()
	ctx["kin_graves"] = _kin_graves()
	return ctx


# --- large: changes -------------------------------------------------------------------------------

func _accept_large(id: StringName) -> bool:
	var r := large_data(id)
	if r == null or accept_reason(id) != "":
		return false
	var n := r.parts.size()
	var done: Array = []
	var progress: Array = []
	for i: int in n:
		done.append(false)
		progress.append(0)
	_parts[id] = done
	_large_progress[id] = progress
	_large_targets[id] = {}
	_accepted_day[id] = TimeManager.day
	var list := HillRules.parts_of(r)
	for i: int in n:
		_assign_part(id, i, list[i])
	_watch_inventory()
	EventBus.hill_request_changed.emit(id, STATE_ACCEPTED)
	EventBus.notification_requested.emit(HillTexts.ACCEPTED % r.title, &"info")
	_check_tend(id)
	return true


## Targets a part gets at the acceptance: fixed care spots, a dirty grave, the graves of a family (flowers).
func _assign_part(id: StringName, index: int, part: OrderData) -> void:
	if part == null:
		return
	match part.kind:
		HillRules.KIND_TEND:
			var grave := str(part.conditions.get("grave", ""))
			if grave == HillRules.GRAVE_MARKED_DIRTY:
				var g := HillRules.pick_grave(_dirty_graves(), TimeManager.day)
				_set_targets(id, index, PackedStringArray([SPOT_PREFIX + g]) if g != "" else PackedStringArray())
			elif grave == "":
				_set_targets(id, index, HillRules.spots_of(part))
		HillRules.KIND_FLOWERS:
			_set_targets(id, index, _graves_of_kin(HillRules.flowers_kin(part, large_data(id))))


## 07:44: a large request on every free large place whose refill day has come (gate; parish board from
## village_open). `small` = small requests pinned this morning (the note says „… und einen großen Bogen").
func _post_large(day: int, small: int) -> int:
	var cfg := _cfg()
	var vill := village()
	var pinned := 0
	for place: StringName in PLACES:
		var slots := HillRules.large_slots(cfg, place, vill)
		var board: Array = _large_board.get(place, [])
		var free := slots - board.size()
		var refill: Array = _large_refill.get(place, [])
		refill.sort()
		while refill.size() > maxi(free, 0):
			refill.pop_back()
		while refill.size() < free:
			refill.append(day)
		var keep: Array = []
		for when: Variant in refill:
			if int(when) > day:
				keep.append(int(when))
				continue
			var id := HillRules.large_pick(all_large(), large_offer_context(day), place)
			if id == &"":
				keep.append(int(when))
				continue
			(_large_board.get_or_add(place, []) as Array).append(id)
			_posted_day[id] = day
			pinned += 1
			EventBus.hill_request_changed.emit(id, STATE_OFFERED)
			var title := large_data(id).title
			var note := HillRules.TEXT_POSTED_VILLAGE if place == OrderData.PLACE_VILLAGE else (
					HillRules.TEXT_POSTED_ALSO if small > 0 else HillRules.TEXT_POSTED_GATE)
			EventBus.notification_requested.emit(note % title, &"info")
		if keep.is_empty():
			_large_refill.erase(place)
		else:
			_large_refill[place] = keep
	return pinned


## 06:00 (apply_morning): deadlines of the accepted large request (half / missed) and offered ones that hung long
## enough (both end „last night").
func _large_morning(day: int) -> void:
	for id: StringName in large_active():
		if day >= deadline_day(id):
			var half := HillRules.half_reached(parts_done(id), _cfg().half_ratio)
			_finish_large(id, STATE_HALF if half else STATE_FAILED, day - 1)
	for id: StringName in large_offered():
		if day >= posted_day(id) + maxi(1, _cfg().large_offer_days):
			_end_large(id, STATE_WITHDRAWN, day - 1)


## completed: the full reward · half: half the coins · failed: large_fail_rep; then the place frees.
func _finish_large(id: StringName, end_state: StringName, end_day: int) -> void:
	var r := large_data(id)
	if r == null or not _parts.has(id):
		return
	var reason := HillRules.REASON % r.title
	var inv := _pay_into if _pay_into != null else _player_inventory()
	match end_state:
		STATE_COMPLETED:
			_pay(r.reward_coins, reason, inv)
			var items := HillRules.reward_items(r)
			if inv != null:
				for item: StringName in items:
					inv.add_item(item, items[item])
			_change_rep(r.reward_rep, reason)
			if village() and _cfg().large_reward_rel != 0:
				var rel := _first(RELATIONSHIPS_GROUP)
				if rel != null and rel.has_method(&"add"):
					rel.call(&"add", r.giver, _cfg().large_reward_rel, reason)
			var goodwill := HillRules.reward_goodwill(r)
			var visitors := _first(VISITORS_GROUP)
			if visitors != null and visitors.has_method(&"add_goodwill"):
				for kin: StringName in goodwill:
					visitors.call(&"add_goodwill", kin, goodwill[kin])
			GameState.add_stat(STAT_LARGE_DONE, 1)
			if r.thanks_text != "":
				EventBus.notification_requested.emit(r.thanks_text, &"reward")
			EventBus.notification_requested.emit(HillRules.TEXT_DONE % [r.title, HillRules.large_reward_line(r)], &"reward")
		STATE_HALF:
			var coins := HillRules.half_coins(r)
			_pay(coins, HillRules.REASON_HALF % r.title, inv)
			GameState.add_stat(STAT_LARGE_HALF, 1)
			EventBus.notification_requested.emit(HillRules.TEXT_HALF_THANKS % HillRules.giver_name(r.giver), &"reward")
			EventBus.notification_requested.emit(HillRules.TEXT_HALF % [r.title, "%d %s" % [coins, "Münze" if coins == 1 else "Münzen"]]
					if coins > 0 else HillRules.TEXT_HALF_PLAIN % r.title, &"reward")
		STATE_FAILED:
			_change_rep(_cfg().large_fail_rep, HillRules.REASON_FAILED % r.title)
			GameState.add_stat(STAT_LARGE_FAILED, 1)
			var text := HillRules.TEXT_FAILED_VILLAGE if r.place == OrderData.PLACE_VILLAGE else HillRules.TEXT_FAILED_GATE
			EventBus.notification_requested.emit(text % r.title, &"warning")
	_end_large(id, end_state, end_day)


func _end_large(id: StringName, end_state: StringName, day: int) -> void:
	var r := large_data(id)
	var place := _large_place_of(id)
	if place == &"":
		return
	(_large_board[place] as Array).erase(id)
	_parts.erase(id)
	_large_progress.erase(id)
	_large_targets.erase(id)
	_accepted_day.erase(id)
	_posted_day.erase(id)
	_large_ended[id] = day
	if large_board(place).size() < HillRules.large_slots(_cfg(), place, village()):
		var refill: Array = _large_refill.get_or_add(place, [])
		refill.append(day + HillRules.large_refill_days(_cfg(), village()))
		refill.sort()
	if end_state in LOG_STATES:
		_log.append({"id": id, "day": TimeManager.day, "state": end_state, "title": r.title if r != null else String(id)})
		while _log.size() > maxi(1, _cfg().log_size):
			_log.pop_front()
	if _parts.is_empty():
		_ghost_night.clear()
	EventBus.hill_request_changed.emit(id, end_state)


## Part `index` done: HUD line „Die Gräber der Fähre: 2 von 3", hill_request_part; follow-up targets (the dead's
## grave → its neighbours, the night's ghosts → their graves); every part done → completed.
func _part_finished(id: StringName, index: int) -> void:
	var done: Array = _parts.get(id, [])
	if index < 0 or index >= done.size() or done[index]:
		return
	done[index] = true
	var r := large_data(id)
	GameState.add_stat(STAT_LARGE_PARTS, 1)
	EventBus.hill_request_part.emit(id, index, true)
	var flags := parts_done(id)
	EventBus.notification_requested.emit(HillRules.TEXT_PART_DONE % [r.title, HillRules.done_count(flags), flags.size()], &"info")
	if HillRules.done_count(flags) >= flags.size():
		_finish_large(id, STATE_COMPLETED, TimeManager.day)
		return
	_check_tend(id)


## Every open part of every accepted large request sees `event` (see HillRules.part_done).
func _large_event(event: StringName, args: Dictionary) -> void:
	if _parts.is_empty() or SaveManager.is_loading:
		return
	for id: StringName in large_active():
		var r := large_data(id)
		if r == null:
			continue
		var list := HillRules.parts_of(r)
		for index: int in open_parts(id):
			if not _parts.has(id):
				break
			var part := list[index]
			var st := _part_state(id, index, part)
			var gain := HillRules.part_gain(part, event, args, st)
			var finished := HillRules.part_done(part, event, args, st)
			if gain > 0:
				var progress: Array = _large_progress.get_or_add(id, [])
				while progress.size() <= index:
					progress.append(0)
				progress[index] = int(progress[index]) + gain
				if part.kind == HillRules.KIND_FLOWERS:
					var left := _targets_of(id, index)
					var at := left.find(str(args.get("grave", "")))
					if at >= 0:
						left.remove_at(at)
					_set_targets(id, index, left)
			if finished:
				_note_chain(id, part, event, args)
				_part_finished(id, index)


## The dead of an exam → prep → marker chain, the neighbours of its grave, the graves of a ghosts night.
func _note_chain(id: StringName, part: OrderData, event: StringName, args: Dictionary) -> void:
	var t: Dictionary = _large_targets.get_or_add(id, {})
	match event:
		HillRules.EV_EXAM:
			t["corpse"] = str(args.get("corpse", ""))
		HillRules.EV_BURIED:
			t["corpse"] = str(args.get("corpse", ""))
			t["grave"] = str(args.get("grave", ""))
			var list := HillRules.parts_of(large_data(id))
			for i: int in list.size():
				var p := list[i]
				if p != null and p.kind == HillRules.KIND_TEND and str(p.conditions.get("grave", "")) == HillRules.GRAVE_NEIGHBORS:
					_set_targets(id, i, _neighbor_spots(str(args.get("grave", "")), maxi(1, int(p.conditions.get("count", 2)))))
		HillRules.EV_GHOST:
			if part.kind != HillRules.KIND_GHOSTS:
				return
			var list := HillRules.parts_of(large_data(id))
			for i: int in list.size():
				var p := list[i]
				if p != null and p.kind == HillRules.KIND_TEND and str(p.conditions.get("grave", "")) == HillRules.GRAVE_GHOSTS_TONIGHT:
					var spots := PackedStringArray()
					var levels := _levels()
					for g: Variant in args.get("night_graves", []):
						if levels.has(SPOT_PREFIX + str(g)):
							spots.append(SPOT_PREFIX + str(g))
					_set_targets(id, i, spots)


## Tend parts that are open: done when their spots are clean (also at once when they already are).
func _check_tend(id: StringName) -> void:
	if not _parts.has(id):
		return
	var list := HillRules.parts_of(large_data(id))
	for index: int in open_parts(id):
		var part := list[index]
		if part != null and part.kind == HillRules.KIND_TEND:
			if HillRules.part_done(part, HillRules.EV_CHECK, {}, _part_state(id, index, part)):
				_part_finished(id, index)
				return


func _part_state(id: StringName, index: int, part: OrderData) -> Dictionary:
	var t: Dictionary = _large_targets.get(id, {})
	var st := {"progress": part_progress(id, index), "corpse": str(t.get("corpse", "")), "grave": str(t.get("grave", "")),
			"targets": _targets_of(id, index), "assigned": t.has("p%d" % index)}
	if part != null and part.kind == HillRules.KIND_TEND:
		st["levels"] = _levels()
	return st


func _targets_of(id: StringName, index: int) -> PackedStringArray:
	var out := PackedStringArray()
	var raw: Variant = (_large_targets.get(id, {}) as Dictionary).get("p%d" % index)
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(str(v))
	return out


func _set_targets(id: StringName, index: int, targets: PackedStringArray) -> void:
	var t: Dictionary = _large_targets.get_or_add(id, {})
	t["p%d" % index] = Array(targets)


func _part(id: StringName, index: int) -> OrderData:
	var list := HillRules.parts_of(large_data(id))
	return list[index] if index >= 0 and index < list.size() else null


## The open visit part of `id` (−1 = none open).
func _visit_part(id: StringName) -> int:
	var list := HillRules.parts_of(large_data(id))
	for index: int in open_parts(id):
		if list[index] != null and list[index].kind == HillRules.KIND_VISIT:
			return index
	return -1


func _visit_done(id: StringName) -> bool:
	var list := HillRules.parts_of(large_data(id))
	var done := parts_done(id)
	for i: int in list.size():
		if list[i] != null and list[i].kind == HillRules.KIND_VISIT and not (i < done.size() and done[i]):
			return false
	return true


static func _has_kind(r: OrderData, kind: StringName) -> bool:
	for p: OrderData in HillRules.parts_of(r):
		if p != null and p.kind == kind:
			return true
	return false


func _finish_visit(id: StringName, place: StringName) -> void:
	_large_event(HillRules.EV_VISIT, {"place": place})


## Hand-over (turn_in): the open deliver part of every accepted large request for `giver` whose items are in `inv`.
func _turn_in_large(giver: StringName, inv: Inventory) -> int:
	var n := 0
	for id: StringName in large_active():
		var index := _ready_deliver_part(id, giver, inv)
		if index < 0:
			continue
		var part := _part(id, index)
		var snapshot := inv.save_state()
		var ok := true
		for item: StringName in part.items:
			if not inv.remove_item(item, int(part.items[item])):
				ok = false
				break
		if not ok:
			inv.load_state(snapshot)
			continue
		_gather_rebase()
		_pay_into = inv
		_large_event(HillRules.EV_DELIVER, {"recipient": giver})
		_pay_into = null
		n += 1
	return n


## The open deliver part of `id` for `giver` whose items are in `inv` (−1 = none).
func _ready_deliver_part(id: StringName, giver: StringName, inv: Inventory) -> int:
	if inv == null or not _parts.has(id):
		return -1
	var list := HillRules.parts_of(large_data(id))
	for index: int in open_parts(id):
		var part := list[index]
		if part != null and part.kind == HillRules.KIND_DELIVER and HillRules.recipient(part) == giver \
				and HillRules.deliver_ready(part, inv):
			return index
	return -1


func _large_place_of(id: StringName) -> StringName:
	for place: StringName in _large_board:
		if (_large_board[place] as Array).has(id):
			return place
	return &""


## The display name of the giver of another accepted request (small or large) with `id`'s giver ("" = none).
func _busy_giver(id: StringName) -> String:
	var r := request_data(id)
	if r == null:
		return ""
	for other: StringName in active() + large_active():
		var o := request_data(other)
		if other != id and o != null and o.giver == r.giver:
			return HillRules.giver_name(r.giver)
	return ""


func _busy_giver_reason(id: StringName) -> String:
	var name := _busy_giver(id)
	return HillRules.TEXT_SAME_GIVER % name if name != "" else ""


func _pay(coins: int, reason: String, inv: Inventory) -> void:
	if coins <= 0:
		return
	if inv != null:
		inv.add_item(COIN_ITEM, coins)
	EventBus.payment_received.emit(coins, reason)


func _change_rep(points: int, reason: String) -> void:
	if points == 0:
		return
	var rep := _first(REPUTATION_GROUP)
	if rep != null and rep.has_method(&"change"):
		rep.call(&"change", points, reason)


# --- large: events --------------------------------------------------------------------------------

func _on_large_craft(station_id: StringName, recipe_id: StringName, amount: int) -> void:
	_large_event(HillRules.EV_CRAFT, {"station": station_id, "recipe": recipe_id, "amount": amount})


func _on_large_dirt(_spot_id: String, _level: int) -> void:
	if _parts.is_empty() or SaveManager.is_loading:
		return
	for id: StringName in large_active():
		_check_tend(id)


func _on_large_exam(corpse_id: String, _step: StringName, _revealed: Array[StringName], _lost: Array[StringName]) -> void:
	if _parts.is_empty():
		return
	var record := _record(corpse_id)
	if record != null and record.is_fully_examined():
		_large_event(HillRules.EV_EXAM, {"corpse": corpse_id, "full": true})


func _on_large_buried(corpse_id: String, grave_id: String) -> void:
	if _parts.is_empty():
		return
	_large_event(HillRules.EV_BURIED, {"corpse": corpse_id, "grave": grave_id, "record": _record(corpse_id)})


func _on_large_marker(grave_id: String, _corpse_id: String, _quality: int, _breakdown: Array) -> void:
	if _parts.is_empty():
		return
	var graveyard := _first(GRAVEYARD_GROUP)
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	_large_event(HillRules.EV_MARKER, {"grave": grave_id, "record": grave})


## ghosts: the distinct graves heard in this night (GhostManager.night_index: a minute before the split belongs to
## the night of the evening before).
func _on_large_ghost(grave_id: String, _mood: StringName, _text: String) -> void:
	if _parts.is_empty() or SaveManager.is_loading:
		return
	var night := GhostManager.night_index(TimeManager.day, TimeManager.minute_of_day)
	if int(_ghost_night.get("night", -999999)) != night:
		_ghost_night = {"night": night, "count": 0, "graves": []}
	var graves: Array = _ghost_night.get_or_add("graves", [])
	if not graves.has(grave_id):
		graves.append(grave_id)
	_ghost_night["count"] = graves.size()
	_large_event(HillRules.EV_GHOST, {"grave": grave_id, "section": String(_section_of(grave_id)),
			"night_graves": graves.duplicate()})


func _on_large_clear(_obstacle_id: String, section_id: StringName) -> void:
	_large_event(HillRules.EV_CLEAR, {"section": section_id})


func _on_large_decor(uid: String, decor_id: StringName, placed: bool) -> void:
	if _parts.is_empty() or not placed or SaveManager.is_loading:
		return
	var decorations := _first(DECORATIONS_GROUP) as DecorationManager
	var section := &""
	var near: Array = []
	if decorations != null:
		var p := decorations.get_placement(uid)
		if p != null:
			var centre := decorations.centre_of(p)
			section = _section_by_order(decorations.mask.section_at(p.cell) if decorations.mask != null else 0)
			for place: StringName in _near_places():
				var at: Variant = _place_position(GATE_NEAR_WAYPOINT if place == &"gate" else place)
				if at != null and Vector2((at as Vector3).x, (at as Vector3).z).distance_to(centre) <= NEAR_RADIUS:
					near.append(place)
	_large_event(HillRules.EV_DECOR, {"decor": decor_id, "section": section, "near": near})


func _on_large_devotion(grave_id: String, _bonus: int) -> void:
	_large_event(HillRules.EV_DEVOTION, {"grave": grave_id})


func _on_large_care(grave_id: String, kind: StringName, active: bool) -> void:
	if active and kind == HillRules.KIND_FLOWERS:
		_large_event(HillRules.EV_FLOWERS, {"grave": grave_id})


## meet: the dialogue with the part's npc at its place inside its window.
func _on_large_dialogue(_dialogue_id: StringName, speaker: Node) -> void:
	if _parts.is_empty() or speaker == null or not is_instance_valid(speaker):
		return
	var npc := StringName(str(speaker.get(&"npc_id"))) if speaker.get(&"npc_id") != null else &""
	if npc == &"":
		return
	for id: StringName in large_active():
		var list := HillRules.parts_of(large_data(id))
		for index: int in open_parts(id):
			var part := list[index]
			if part == null or part.kind != HillRules.KIND_MEET or StringName(str(part.conditions.get("npc", ""))) != npc:
				continue
			var place := StringName(str(part.conditions.get("place", "")))
			if _meet_place_ok(place, npc, speaker):
				note_meet(npc, place)
				return


func _on_large_world() -> void:
	_watch_inventory()


## gather: every gain of the part's item in the player's inventory while the part is open – the piles (ResourceNode
## sends no resource_gathered), felling, the quarry, clearing, and also what is bought or fetched from the shed
## (only elderberries are for sale; „besorgen" counts).
func _on_inventory_changed() -> void:
	if _parts.is_empty() or SaveManager.is_loading or _watched_inv == null:
		return
	var items := _gather_items_open()
	for item: StringName in items:
		var now := _watched_inv.count(item)
		var before := int(_gather_seen.get(item, now))
		_gather_seen[item] = now
		if now > before:
			_large_event(HillRules.EV_GATHER, {"item": item, "amount": now - before})
	for item: StringName in _gather_seen.keys():
		if not items.has(item):
			_gather_seen.erase(item)


func _watch_inventory() -> void:
	var inv := _player_inventory()
	if inv != _watched_inv:
		if _watched_inv != null and is_instance_valid(_watched_inv) and _watched_inv.changed.is_connected(_on_inventory_changed):
			_watched_inv.changed.disconnect(_on_inventory_changed)
		_watched_inv = inv
		if inv != null and not inv.changed.is_connected(_on_inventory_changed):
			inv.changed.connect(_on_inventory_changed)
	_gather_rebase()


## The counts the gather parts compare with (after a load, a hand-over, a trade).
func _gather_rebase() -> void:
	_gather_seen.clear()
	if _watched_inv == null or not is_instance_valid(_watched_inv):
		return
	for item: StringName in _gather_items_open():
		_gather_seen[item] = _watched_inv.count(item)


func _gather_items_open() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in large_active():
		var list := HillRules.parts_of(large_data(id))
		for index: int in open_parts(id):
			var part := list[index]
			if part != null and part.kind == HillRules.KIND_GATHER:
				var item := StringName(str(part.conditions.get("item", "")))
				if item != &"" and not out.has(item):
					out.append(item)
	return out


# --- large: world lookups -------------------------------------------------------------------------

## Waypoint `place` of the graveyard, a region or an interior room (null = unknown – never a warning).
func _place_position(place: StringName) -> Variant:
	if place == &"" or not is_inside_tree():
		return null
	var path := NodePath("%s/%s" % [WAYPOINTS, place])
	for group: StringName in [WORLD_GROUP, REGION_GROUP, InteriorRoom.GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var marker := node.get_node_or_null(path) as Node3D
			if marker != null and marker.is_inside_tree():
				return marker.global_position
	return null


func _known_places() -> Array:
	var out: Array = []
	for r: OrderData in all_large():
		for p: OrderData in HillRules.parts_of(r):
			if p != null and p.kind == HillRules.KIND_VISIT:
				var place := StringName(str(p.conditions.get("place", "")))
				if not out.has(place) and _place_position(place) != null:
					out.append(place)
	return out


func _near_places() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in large_active():
		for p: OrderData in HillRules.parts_of(large_data(id)):
			if p != null and p.kind == HillRules.KIND_DECOR:
				var near := StringName(str(p.conditions.get("near", "")))
				if near != &"" and not out.has(near):
					out.append(near)
	return out


## meet place: kin_grave = beside a grave the npc mourns at; a waypoint = near it; else the room / region the
## player is in (church, inn …).
func _meet_place_ok(place: StringName, npc: StringName, speaker: Node) -> bool:
	var at: Vector3 = (speaker as Node3D).global_position if speaker is Node3D and (speaker as Node3D).is_inside_tree() else Vector3.INF
	if place == HillRules.PLACE_KIN_GRAVE:
		if at == Vector3.INF:
			return false
		var world := _first(WORLD_GROUP)
		for g: String in _graves_of_kin(npc):
			var plot := world.call(&"get_node_by_layout_id", g) as Node3D if world != null and world.has_method(&"get_node_by_layout_id") else null
			if plot != null and plot.global_position.distance_to(at) <= MEET_RADIUS:
				return true
		return false
	var marker: Variant = _place_position(place)
	if marker != null and at != Vector3.INF:
		return (marker as Vector3).distance_to(at) <= MEET_RADIUS
	var player := _first(PLAYER_GROUP) as Player
	return player != null and (player.interior_id == place or player.region_id == place)


func _graves_of_kin(kin: StringName) -> PackedStringArray:
	var visitors := _first(VISITORS_GROUP)
	if visitors == null or not visitors.has_method(&"graves_of") or kin == &"":
		return PackedStringArray()
	return visitors.call(&"graves_of", kin)


func _kin_graves() -> Dictionary:
	var out := {}
	for r: OrderData in all_large():
		for p: OrderData in HillRules.parts_of(r):
			if p == null:
				continue
			var kin := &""
			if p.kind == HillRules.KIND_FLOWERS:
				kin = HillRules.flowers_kin(p, r)
			elif p.kind == HillRules.KIND_MEET and StringName(str(p.conditions.get("place", ""))) == HillRules.PLACE_KIN_GRAVE:
				kin = StringName(str(p.conditions.get("npc", "")))
			if kin != &"" and not out.has(kin):
				out[kin] = Array(_graves_of_kin(kin))
	return out


## The `count` plots nearest to `grave_id` in its section that have a care spot (the grave's neighbours).
func _neighbor_spots(grave_id: String, count: int) -> PackedStringArray:
	var out := PackedStringArray()
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	var world := _first(WORLD_GROUP)
	if graveyard == null or world == null or not world.has_method(&"get_node_by_layout_id"):
		return out
	var own := world.call(&"get_node_by_layout_id", grave_id) as Node3D
	if own == null:
		return out
	var levels := _levels()
	var ranked: Array = []
	for g: String in graveyard.plots_in_section(graveyard.section_of(grave_id)):
		if g == grave_id or not levels.has(SPOT_PREFIX + g):
			continue
		var plot := world.call(&"get_node_by_layout_id", g) as Node3D
		if plot != null:
			ranked.append([own.global_position.distance_to(plot.global_position), g])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	for i: int in mini(count, ranked.size()):
		out.append(SPOT_PREFIX + str(ranked[i][1]))
	return out


func _section_of(grave_id: String) -> StringName:
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	return graveyard.section_of(grave_id) if graveyard != null else &""


func _section_by_order(order: int) -> StringName:
	var expansion := _first(EXPANSION_GROUP) as ExpansionManager
	if expansion == null:
		return &""
	for s: SectionData in expansion.sections():
		if s.order == order:
			return s.id
	return &""


func _marked_by_section() -> Dictionary:
	var out := {}
	var graveyard := _first(GRAVEYARD_GROUP) as Graveyard
	if graveyard == null:
		return out
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			var s := graveyard.section_of(g.id)
			out[s] = int(out.get(s, 0)) + 1
	return out


## Stations that can craft now: the workbench, the built workyard stations.
func _stations() -> Array:
	var out: Array = [HillRules.STATION_WORKBENCH]
	var shop := _first(WORKSHOP_GROUP)
	if shop != null and shop.has_method(&"is_built"):
		for s: StringName in [&"mason", &"loom", &"forge", &"kiln", &"pult"]:
			if bool(shop.call(&"is_built", s)):
				out.append(s)
	return out


## What the piles (ResourceNode res_wood / res_stone) give each morning: {item: daily_amount}.
func _pile_daily() -> Dictionary:
	var out := {}
	var world := _first(WORLD_GROUP)
	if world == null or not world.has_method(&"get_node_by_layout_id"):
		return out
	for id: String in ["res_wood", "res_stone"]:
		var pile := world.call(&"get_node_by_layout_id", id) as ResourceNode
		if pile != null and pile.item_id != &"":
			out[pile.item_id] = int(out.get(pile.item_id, 0)) + maxi(0, pile.daily_amount)
	return out


## What clearing the open obstacles of the workable sections still yields: {item: n} (obstacles without a cost).
func _clear_yields() -> Dictionary:
	var out := {}
	var expansion := _first(EXPANSION_GROUP) as ExpansionManager
	if expansion == null:
		return out
	for s: SectionData in expansion.sections():
		if expansion.is_unlocked(s.id) or expansion.block_reason(s.id) != "":
			continue
		for o: String in expansion.obstacle_ids(s.id):
			var data := expansion.data_of(o)
			if expansion.is_cleared(o) or data == null or not data.cost.is_empty():
				continue
			for item: StringName in data.yield_items:
				out[item] = int(out.get(item, 0)) + int(data.yield_items[item])
	return out


## Decor id → pieces that may still be placed under DecorData.place_max and DecorConfig.max_placed (&"" = any).
func _decor_room() -> Dictionary:
	var out := {}
	var decorations := _first(DECORATIONS_GROUP) as DecorationManager
	if decorations == null:
		return out
	var cfg: DecorConfig = decorations.config if decorations.config != null else Database.config(&"decor_config") as DecorConfig
	var cap := cfg.max_placed if cfg != null else DecorConfig.new().max_placed
	var total := maxi(0, cap - decorations.placements().size())
	out[&""] = total
	for id: StringName in decorations.decor_ids():
		var d := decorations.decor(id)
		var left := total
		if d != null and d.place_max > 0:
			left = mini(left, maxi(0, d.place_max - decorations.count_of(id)))
		out[id] = left
	return out


## Items that can be gathered now: the piles' wood and stone (`with_piles`), and every open gather node's item.
func _gather_items(with_piles: bool = true) -> Array:
	var out: Array = HillRules.PILE_ITEMS.duplicate() if with_piles else []
	if not is_inside_tree():
		return out
	var manager := get_tree().get_first_node_in_group(GatherNode.MANAGER_GROUP) as GatherManager
	for node: Node in get_tree().get_nodes_in_group(GatherNode.GROUP):
		var g := node as GatherNode
		if g == null or not g.flag_ok() or not g.section_open() or manager == null:
			continue
		var data := manager.data_for_kind(g.kind)
		if data != null and not out.has(data.item_id):
			out.append(data.item_id)
	return out


func _chapel_ready() -> bool:
	var chapel := _first(CHAPEL_GROUP)
	return chapel != null and chapel.has_method(&"level") and int(chapel.call(&"level")) > 0


func _save_large() -> Dictionary:
	var board := {}
	for place: StringName in PLACES:
		board[String(place)] = large_board(place).map(func(id: StringName) -> String: return String(id))
	var parts := {}
	for id: StringName in _parts:
		parts[String(id)] = (_parts[id] as Array).duplicate()
	var progress := {}
	for id: StringName in _large_progress:
		progress[String(id)] = (_large_progress[id] as Array).duplicate()
	var targets := {}
	for id: StringName in _large_targets:
		targets[String(id)] = (_large_targets[id] as Dictionary).duplicate(true)
	var refill := {}
	for place: StringName in _large_refill:
		refill[String(place)] = (_large_refill[place] as Array).duplicate()
	return {"large_board": board, "parts": parts, "large_refill": refill, "large_ended": _str_keys(_large_ended),
			"ghost_night": _ghost_night.duplicate(true), "large_progress": progress, "large_targets": targets}


## Tolerant (§5.1, §10 fuzzer): unknown ids, a place that is not the request's, more than the places / large_max_active
## hold and broken values are dropped; a parts list shorter or longer than the request is cut / filled with false.
func _load_large(data: Dictionary) -> void:
	var cfg := _cfg()
	var board_raw: Variant = data.get("large_board")
	if board_raw is Dictionary:
		for place: StringName in PLACES:
			var ids: Variant = (board_raw as Dictionary).get(String(place))
			if not ids is Array:
				continue
			var list: Array = []
			var cap := maxi(maxi(cfg.large_slots_gate, cfg.large_slots_village), 1)
			for v: Variant in ids:
				var id := StringName(str(v))
				var r := large_data(id)
				if r == null or r.place != place or list.has(id) or _large_place_of(id) != &"" or list.size() >= cap:
					continue
				list.append(id)
			if not list.is_empty():
				_large_board[place] = list
	var parts_raw: Variant = data.get("parts")
	var progress_raw := _dict(data, "large_progress")
	var targets_raw := _dict(data, "large_targets")
	if parts_raw is Dictionary:
		for id: StringName in large_ids():
			var flags: Variant = (parts_raw as Dictionary).get(String(id))
			if not flags is Array or _parts.size() >= maxi(0, cfg.large_max_active):
				continue
			var n := large_data(id).parts.size()
			var done: Array = []
			var counts: Array = []
			var raw_counts: Variant = progress_raw.get(String(id))
			for i: int in n:
				done.append(i < (flags as Array).size() and (flags as Array)[i] == true)
				var c: Variant = (raw_counts as Array)[i] if raw_counts is Array and i < (raw_counts as Array).size() else 0
				counts.append(maxi(0, int(c)) if (c is int or c is float) else 0)
			_parts[id] = done
			_large_progress[id] = counts
			var t: Variant = targets_raw.get(String(id))
			var clean := {}
			if t is Dictionary:
				for key: Variant in t:
					var k := str(key)
					if k == "corpse" or k == "grave":
						clean[k] = str(t[key])
					elif k.begins_with("p") and (t[key] is Array or t[key] is PackedStringArray):
						clean[k] = Array(t[key]).map(func(v: Variant) -> String: return str(v))
			_large_targets[id] = clean
	var posted := _dict(data, "posted_day")
	var accepted := _dict(data, "accepted_day")
	for id: StringName in large_ids():
		_posted_day[id] = clampi(_num(posted.get(String(id)), TimeManager.day), 0, TimeManager.day)
		if _parts.has(id):
			_accepted_day[id] = clampi(_num(accepted.get(String(id)), TimeManager.day), 1, maxi(1, TimeManager.day))
	var refill_raw := _dict(data, "large_refill")
	for place: StringName in PLACES:
		var days: Variant = refill_raw.get(String(place))
		if days is Array:
			var list: Array = []
			for v: Variant in days:
				if v is int or v is float:
					list.append(clampi(int(v), 0, TimeManager.day + 30))
			list.sort()
			if not list.is_empty():
				_large_refill[place] = list
	var ended := _dict(data, "large_ended")
	for key: Variant in ended:
		var id := StringName(str(key))
		if large_data(id) != null:
			_large_ended[id] = _num(ended[key], 0)
	var night := _dict(data, "ghost_night")
	if not night.is_empty() and not _parts.is_empty():
		var graves: Array = []
		var raw_graves: Variant = night.get("graves")
		if raw_graves is Array:
			for g: Variant in raw_graves:
				if not graves.has(str(g)):
					graves.append(str(g))
		_ghost_night = {"night": _num(night.get("night"), 0), "count": graves.size() if not graves.is_empty() else
				maxi(0, _num(night.get("count"), 0)), "graves": graves}


# --- save -----------------------------------------------------------------------------------------

func save_state() -> Dictionary:
	var states := {}
	for id: StringName in _states:
		states[String(id)] = String(_states[id])
	return {"board": _board.map(func(id: StringName) -> String: return String(id)), "states": states,
			"accepted_day": _str_keys(_accepted_day), "posted_day": _str_keys(_posted_day), "ended": _str_keys(_ended),
			"targets": _str_keys(_targets), "touched": _touched.keys().map(func(id: StringName) -> String: return String(id)),
			"refill": _refill.duplicate(), "check_day": _check_day, "post_day": _post_day, "log": _log.duplicate(true)}.merged(
			_save_large())


## Tolerant: unknown ids and broken values are dropped; {} (a save before G8 Runde 6) = the default state.
func load_state(data: Dictionary) -> void:
	_reset()
	var states: Variant = data.get("states")
	var raw_board: Variant = data.get("board")
	if raw_board is Array:
		for v: Variant in raw_board:
			var id := StringName(str(v))
			var s := StringName(str((states as Dictionary).get(String(id), ""))) if states is Dictionary else &""
			if request_data(id) == null or is_large(id) or _board.has(id) or not s in BOARD_STATES:
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
		if request_data(id) != null and not is_large(id):
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
				_refill.append(clampi(int(v), 0, TimeManager.day + 30))
	_refill.sort()
	_check_day = clampi(_num(data.get("check_day"), 0), 0, TimeManager.day)
	_post_day = clampi(_num(data.get("post_day"), 0), 0, TimeManager.day)
	var log_raw: Variant = data.get("log")
	if log_raw is Array:
		for e: Variant in log_raw:
			if e is Dictionary and StringName(str((e as Dictionary).get("state", ""))) in LOG_STATES:
				_log.append({"id": StringName(str(e.get("id", ""))), "day": _num(e.get("day"), 0),
						"state": StringName(str(e.get("state"))), "title": str(e.get("title", ""))})
	while _log.size() > maxi(1, _cfg().log_size):
		_log.pop_front()
	_load_large(data)
	_watch_inventory()


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
	_large_board.clear()
	_parts.clear()
	_large_progress.clear()
	_large_targets.clear()
	_large_refill.clear()
	_large_ended.clear()
	_ghost_night.clear()
	_gather_seen.clear()


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
	if minute >= cfg.post_minute and day > _post_day and day >= mini(cfg.start_day, cfg.large_start_day):
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
