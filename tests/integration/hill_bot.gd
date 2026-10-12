class_name HillBot
extends Phase4Bot
## G8 Runde 6 „Bitten vom Hügel" – measuring bot for days 1–14 (docs/reviews/phase8_round6/bitten.md): Phase4Bot's
## day with the moment the daytime work ends recorded (`work_end`, before the evening hand-over, the ghosts and the
## bed) and – with "requests" – the requests of the gate's notice board: the bot reads the board after the corpse
## work, accepts what it may, does what they ask (the named care spots, one obstacle, the decor, an extra cross or
## the wood / stone for a delivery when there is some to spare, a ghost at night) and hands deliveries to Osric at
## 18:30 through carter.tres' hill_turn_in. Strategies: see HILL_STRATEGIES ("duty" = the player of the user's
## criticism: the corpses, their graves and what the HUD asks for when no plot is left – clearing –, no tending, decor,
## upgrades, ghosts or night trade; "reverent" = Phase4Bot's diligent day).

## The HUD says „Feierabend – Schlafen …" from TimeConfig.sleep_from_minute (18:00): idle = that minus work_end.
const IDLE_UNTIL := 1080
## Osric's evening at the gate (carter_schedule: 18:30–21:00).
const OSRIC_EVENING := 1110
## Wood / stone kept for tomorrow's marker.
const KEEP_WOOD := 3
const KEEP_STONE := 4

static var HILL_STRATEGIES := {
	&"duty": _with({"tend": false, "clear": true, "decor": false, "listen": false, "upgrade": false, "trade": false,
			"link": true, "requests": false}),
	&"duty_requests": _with({"tend": false, "clear": true, "decor": false, "listen": false, "upgrade": false,
			"trade": false, "link": true, "requests": true}),
	&"reverent": _with({"requests": false}),
	&"reverent_requests": _with({"requests": true}),
}

var hill: HillRequests
## Requests completed / their coins / their reputation over the run.
var hill_done: int = 0
var hill_failed: int = 0
var hill_coins: int = 0
var hill_rep: int = 0
## Minutes of request work over the run (walks + the jobs).
var hill_minutes: int = 0
var _work_end: int = 0
var _listen_tonight: bool = false


func strategies() -> Dictionary:
	return HILL_STRATEGIES


func bind() -> void:
	super.bind()
	hill = world.get_node("Systems/HillRequests") as HillRequests


func watch() -> void:
	super.watch()
	EventBus.hill_request_changed.connect(_on_hill)


func unwatch() -> void:
	super.unwatch()
	EventBus.hill_request_changed.disconnect(_on_hill)


func run_day() -> void:
	_leave_hut()
	_gather()
	var tables := Database.corpse_tables() as CorpseTables
	if TimeManager.minute_of_day < tables.delivery_minute + 10:
		_craft_essentials()
		_wait_until(tables.delivery_minute + 10)
	_buy_for_today()
	_handle_corpses()
	_craft_essentials()
	if flags.upgrade:
		_upgrade_markers()
	if flags.clear:
		_clear_obstacles()
	if flags.tend:
		_tend()
	if flags.decor:
		_decorate()
	if flags.tend:
		_tend()
	_handle_corpses()
	_balm_waiting()
	if flags.link:
		_link()
	_listen_tonight = bool(flags.listen)
	if flags.requests:
		_hill_board()
		_hill_work()
		_hill_board()
		_hill_work()
	_work_end = TimeManager.minute_of_day
	if flags.requests:
		_hill_evening()
	if _listen_tonight:
		_listen_to_ghosts()
	if flags.trade:
		await _night_at_the_wall()
		if flags.link:
			_link()
	await _sleep()


func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	r.merge({"work_end": _work_end, "idle": maxi(0, IDLE_UNTIL - _work_end), "hill_done": hill_done,
			"hill_coins": hill_coins})


# --- the requests -------------------------------------------------------------------------------

## To the gate, read the board, accept what may be accepted.
func _hill_board() -> void:
	if hill.offered().is_empty() or hill.active().size() >= hill.max_active() or not _time_left():
		return
	_leave_room()
	_hill_walk()
	for id: StringName in hill.offered():
		if hill.accept_reason(id) == "" and _doable(id):
			hill.accept(id)


## A request the bot can do today (deliveries only with the means to spare).
func _doable(id: StringName) -> bool:
	var r := hill.request_data(id)
	if r == null:
		return false
	if r.kind == HillRules.KIND_DELIVER:
		for item: StringName in r.items:
			if item == &"wooden_cross":
				if inv().count(&"wooden_cross") < int(r.items[item]) and inv().count(&"wood") < KEEP_WOOD + 3:
					return false
			elif inv().count(item) < int(r.items[item]) + (KEEP_WOOD if item == &"wood" else KEEP_STONE if item == &"stone" else 0):
				return false
	return true


func _hill_work() -> void:
	for id: StringName in hill.active():
		if not _time_left():
			return
		var r := hill.request_data(id)
		match r.kind:
			HillRules.KIND_TEND:
				_hill_tend(id)
			HillRules.KIND_CLEAR:
				_hill_clear(r)
			HillRules.KIND_DECOR:
				_hill_decor()
			HillRules.KIND_GHOST:
				_listen_tonight = true
			HillRules.KIND_DELIVER:
				if r.items.has(&"wooden_cross") and inv().count(&"wooden_cross") < int(r.items[&"wooden_cross"]):
					var bench := world.get_node_by_layout_id("workbench") as Workbench
					var before := TimeManager.total_minutes()
					_craft(bench, &"wooden_cross")
					hill_minutes += TimeManager.total_minutes() - before


func _hill_tend(id: StringName) -> void:
	if not inv().has(&"rake") and TimeManager.day >= 2 and inv().count(&"wood") >= KEEP_WOOD + 3:
		_craft(world.get_node_by_layout_id("workbench") as Workbench, &"rake")
	for spot_id: String in hill.spots_of(id):
		if clean.level(spot_id) < 1:
			continue
		var spot := _spot(spot_id)
		if spot != null and spot.can_interact(player):
			var before := TimeManager.total_minutes()
			_walk(2)
			spot.interact(player)
			hill_minutes += TimeManager.total_minutes() - before


func _spot(spot_id: String) -> DirtSpot:
	for node: Node in tree.get_nodes_in_group(DirtSpot.GROUP):
		var s := node as DirtSpot
		if s != null and s.spot_id == spot_id:
			return s
	return null


## One obstacle of the request's sections (the first the bot can afford).
func _hill_clear(r: OrderData) -> void:
	for section: String in HillRules.sections_of(r):
		var sid := StringName(section)
		if expansion.is_unlocked(sid) or expansion.block_reason(sid) != "":
			continue
		var ids := expansion.obstacle_ids(sid)
		ids.sort()
		for o: String in ids:
			if expansion.is_cleared(o):
				continue
			var data := expansion.data_of(o)
			if data.cost.has(&"wood") and inv().count(&"wood") - int(data.cost[&"wood"]) < KEEP_WOOD:
				continue
			if data.cost.has(&"iron_fittings") and inv().count(&"iron_fittings") < int(data.cost[&"iron_fittings"]):
				continue
			var node := expansion.obstacle(o)
			if node != null and node.can_interact(player):
				var before := TimeManager.total_minutes()
				_walk()
				node.interact(player)
				hill_minutes += TimeManager.total_minutes() - before
				return


func _hill_decor() -> void:
	var before := TimeManager.total_minutes()
	_decorate()
	hill_minutes += TimeManager.total_minutes() - before


## 18:30 at Osric's cart: every ready delivery (carter.tres hill_turn_in:carter).
func _hill_evening() -> void:
	var ctx := {"inventory": inv(), "speaker": null}
	if not DialogueConditions.hill_ready(&"carter", ctx):
		return
	_wait_until(OSRIC_EVENING)
	_leave_room()
	_hill_walk()
	DialogueActions.apply("hill_turn_in:carter", ctx)


func _hill_walk() -> void:
	var before := TimeManager.total_minutes()
	_walk()
	hill_minutes += TimeManager.total_minutes() - before


func _on_hill(_id: StringName, state: StringName) -> void:
	match state:
		HillRequests.STATE_COMPLETED:
			hill_done += 1
		HillRequests.STATE_FAILED:
			hill_failed += 1


func _on_payment(coins: int, reason: String) -> void:
	super._on_payment(coins, reason)
	if reason.begins_with(HillRules.REASON_PREFIX):
		hill_coins += coins


func _on_rep(v: int, t: StringName, d: int, reason: String) -> void:
	super._on_rep(v, t, d, reason)
	if reason.begins_with(HillRules.REASON_PREFIX):
		hill_rep += d


## "| Tag | Arbeit bis | Leerlauf | Bitten | Münzen | …" for docs/reviews/phase8_round6/bitten.md.
func table_hill() -> String:
	var lines := PackedStringArray(["| Tag | Arbeit bis | Leerlauf bis 18:00 | Bitten erledigt (Summe) | Münzen aus Bitten (Summe) | Münzen | Ruf |",
			"|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		lines.append("| %d | %s | %d min | %d | %d | %d | %d |" % [r.day, UIKit.clock(int(r.work_end)), int(r.idle),
				int(r.hill_done), int(r.hill_coins), int(r.coins), int(r.rep)])
	return "\n".join(lines)
