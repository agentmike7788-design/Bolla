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
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3.6): the strategies with "large" also accept the large request
## at the gate and work its parts – crafts at the workbench (iron and seeds from Osric), the named care spots, decor
## in the Alter Hof / at the gate, an obstacle, the dead of the exam → burial chain (the corpse work does it), ghosts
## at night, the evening wait at the gate (visit) and the hand-over at Osric's cart. The other strategies never
## accept one and stay bit-identical.

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
	&"duty_large": _with({"tend": false, "clear": true, "decor": false, "listen": false, "upgrade": false,
			"trade": false, "link": true, "requests": true, "large": true}),
	&"reverent_large": _with({"requests": true, "large": true}),
}
## Wood kept for tomorrow's gravestone when crafting for a large request.
const LARGE_KEEP_WOOD := 1
## Decor a large decor part may take, cheapest first.
const LARGE_DECOR_ORDER: Array[StringName] = [&"decor_grave_vase", &"decor_flowerbed", &"decor_lantern", &"decor_bench_wood"]

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
## Phase 9: large requests accepted / completed / half done / missed, their coins and work minutes.
var large_accepted: int = 0
var large_done: int = 0
var large_half: int = 0
var large_failed: int = 0
var large_coins: int = 0
var large_minutes: int = 0
var large_log: PackedStringArray = []
var large_ends: Array[Dictionary] = []


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
	if flags.get("large", false):
		# Phase 9: the large sheet is read at the gate in the morning, while the delivery is there.
		_large_board()
	_handle_corpses()
	_craft_essentials()
	if flags.get("large", false) and flags.decor:
		# A decorating player sets the request's decor first – the routine decor would use up its places.
		_large_decor_first()
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
	if flags.get("large", false):
		_large_day()
	_work_end = TimeManager.minute_of_day
	if flags.requests:
		_hill_evening()
	if flags.get("large", false):
		_large_evening()
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
			"hill_coins": hill_coins, "large_done": large_done, "large_coins": large_coins, "large_on": _large_on()})


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
	# W3 QA-Fix QA9-05: hill_ready is the small requests only now – the large ones' deliver parts are large_ready's (the
	# same hand-over: hill_turn_in → HillRequests.turn_in takes both, as before).
	if not DialogueConditions.hill_ready(&"carter", ctx) and DialogueConditions.large_ready(&"carter", ctx).is_empty():
		return
	_wait_until(OSRIC_EVENING)
	_leave_room()
	_hill_walk()
	DialogueActions.apply("hill_turn_in:carter", ctx)


func _hill_walk() -> void:
	var before := TimeManager.total_minutes()
	_walk()
	hill_minutes += TimeManager.total_minutes() - before


func _on_hill(id: StringName, state: StringName) -> void:
	if hill != null and hill.is_large(id):
		_on_large(id, state)
		return
	match state:
		HillRequests.STATE_COMPLETED:
			hill_done += 1
		HillRequests.STATE_FAILED:
			hill_failed += 1


func _on_payment(coins: int, reason: String) -> void:
	super._on_payment(coins, reason)
	if _large_reason(reason):
		large_coins += coins
	elif reason.begins_with(HillRules.REASON_PREFIX):
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


# --- Phase 9: the large requests -------------------------------------------------------------------

func _on_large(id: StringName, state: StringName) -> void:
	match state:
		HillRequests.STATE_ACCEPTED:
			large_accepted += 1
		HillRequests.STATE_COMPLETED:
			large_done += 1
		HillRequests.STATE_HALF:
			large_half += 1
		HillRequests.STATE_FAILED:
			large_failed += 1
	if state != HillRequests.STATE_OFFERED:
		large_log.append("Tag %d %s %s" % [TimeManager.day, id, state])
		large_ends.append({"day": TimeManager.day, "id": id, "state": state})


## Large requests that ended in `state` up to `last_day` (a deadline on the morning after the run is not counted).
func large_count(state: StringName, last_day: int) -> int:
	var n := 0
	for e: Dictionary in large_ends:
		if e.state == state and int(e.day) <= last_day:
			n += 1
	return n


## A payment reason of a large request („Bitte: <Titel>“, „Bitte zur Hälfte: …“).
func _large_reason(reason: String) -> bool:
	if hill == null or not reason.begins_with("Bitte"):
		return false
	for r: OrderData in hill.all_large():
		if reason == HillRules.REASON % r.title or reason == HillRules.REASON_HALF % r.title:
			return true
	return false


func _large_on() -> String:
	var out := PackedStringArray()
	for id: StringName in hill.large_active():
		var done := hill.parts_done(id)
		out.append("%s %d/%d" % [id, HillRules.done_count(done), done.size()])
	return ", ".join(out)


## Read the gate's large sheet, accept it, work its open parts (three rounds – a part done can open the next).
func _large_day() -> void:
	_large_board()
	for i: int in 3:
		if not _large_work():
			break
		_large_board()


func _large_board() -> void:
	if not hill.large_active().is_empty() or not _time_left():
		return
	if OS.has_environment("HILLBOT_DEBUG") and hill.large_offered(OrderData.PLACE_GATE).is_empty():
		var ctx := hill.large_offer_context(TimeManager.day)
		var why := PackedStringArray()
		for r: OrderData in hill.all_large():
			if r.place == OrderData.PLACE_GATE:
				why.append("%s: %s" % [r.id, HillRules.large_offer_block(r, ctx)])
		large_log.append("Tag %d nichts am Tor (%s)" % [TimeManager.day, ", ".join(why)])
	for id: StringName in hill.large_offered(OrderData.PLACE_GATE):
		if hill.accept_reason(id) == "":
			_leave_room()
			_large_walk()
			hill.accept(id)
			return


func _large_decor_first() -> void:
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		for i: int in hill.open_parts(id):
			if parts[i].kind == HillRules.KIND_DECOR and _time_left():
				var before := TimeManager.total_minutes()
				_large_decor(id, i, parts[i])
				large_minutes += TimeManager.total_minutes() - before


## One round over the open parts; true = some work was done.
func _large_work() -> bool:
	var did := false
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		for i: int in hill.open_parts(id):
			if not _time_left() or not hill.large_active().has(id):
				return did
			var part := parts[i]
			var before := TimeManager.total_minutes()
			match part.kind:
				HillRules.KIND_CRAFT:
					_large_craft(id, i, part)
				HillRules.KIND_TEND:
					_large_tend(id, i)
				HillRules.KIND_DECOR:
					_large_decor(id, i, part)
				HillRules.KIND_CLEAR:
					_hill_clear(part)
				HillRules.KIND_GATHER:
					_large_gather(id, i, part)
				HillRules.KIND_VISIT:
					if HillRules.visit_window(part).x < 0:
						_large_visit(id, part)
			var spent := TimeManager.total_minutes() - before
			if spent > 0:
				large_minutes += spent
				did = true
	return did


## Craft what the part still needs (materials with a little kept back; iron / seeds bought from Osric).
func _large_craft(id: StringName, index: int, part: OrderData) -> void:
	var recipe_id := HillRules.recipe_of(part)
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	var left := HillRules.need(part) - hill.part_progress(id, index)
	for k: int in maxi(left, 0):
		if not _large_materials(recipe_id) or not _craft(bench, recipe_id):
			return


## The inputs of `recipe_id` are there (bought when they are Osric's goods) – keeping wood for tomorrow's marker.
func _large_materials(recipe_id: StringName) -> bool:
	var r := Database.recipe(recipe_id) as RecipeData
	if r == null:
		return false
	for item: StringName in r.inputs:
		var need := int(r.inputs[item])
		var keep := LARGE_KEEP_WOOD if item == &"wood" else 0
		if inv().count(item) >= need + keep:
			continue
		var missing := need - inv().count(item)
		if PRICE.has(item) and inv().count(&"coin") - int(PRICE[item]) * missing >= RESERVE:
			_buy(item, missing)
		if inv().count(item) < need + keep:
			return false
	return true


## „schlagen oder roden": the piles are taken in the morning; beyond them the obstacles that yield the item.
func _large_gather(id: StringName, index: int, part: OrderData) -> void:
	var item := StringName(str(part.conditions.get("item", "")))
	for section: StringName in [&"east", &"north", &"elder"]:
		if expansion.is_unlocked(section) or expansion.block_reason(section) != "":
			continue
		var ids := expansion.obstacle_ids(section)
		ids.sort()
		for o: String in ids:
			if not _time_left() or not hill.large_active().has(id) or hill.part_progress(id, index) >= HillRules.need(part):
				return
			if expansion.is_cleared(o):
				continue
			var data := expansion.data_of(o)
			if not data.yield_items.has(item) or not data.cost.is_empty():
				continue
			var node := expansion.obstacle(o)
			if node != null and node.can_interact(player):
				_walk()
				node.interact(player)


func _large_tend(id: StringName, index: int) -> void:
	for spot_id: String in hill.part_targets(id, index):
		if clean.level(spot_id) < 1:
			continue
		if not inv().has(&"rake") and _large_materials(&"rake"):
			_craft(world.get_node_by_layout_id("workbench") as Workbench, &"rake")
		var spot := _spot(spot_id)
		if spot != null and spot.can_interact(player):
			_walk(2)
			spot.interact(player)


## Place the decor the part asks for: a piece already made, else the cheapest one that can be made now.
func _large_decor(id: StringName, index: int, part: OrderData) -> void:
	var allowed: Array = part.conditions.get("decor", [])
	var left := HillRules.need(part) - hill.part_progress(id, index)
	for k: int in maxi(left, 0):
		var decor_id := &""
		for d: Variant in allowed:
			if inv().count(StringName(str(d))) > 0:
				decor_id = StringName(str(d))
				break
		if decor_id == &"":
			for d: StringName in LARGE_DECOR_ORDER:
				if (allowed.has(String(d)) or allowed.has(d)) and _large_materials(d) \
						and _craft(world.get_node_by_layout_id("workbench") as Workbench, d):
					decor_id = d
					break
		if decor_id == &"" or inv().count(decor_id) == 0:
			return
		if _large_place(decor_id, part) == "":
			var gate := world.get_waypoint(&"gate_inside")
			var cell := decorations.mask.world_to_cell(Vector2(gate.x, gate.z))
			problems.append("day %d: could not place %s for %s (at the gate: %s, %d placed)" % [TimeManager.day, decor_id, id,
					decorations.can_place(decor_id, cell, 0, inv(), player), decorations.placements().size()])
			return


func _large_place(decor_id: StringName, part: OrderData) -> String:
	var section := StringName(str(part.conditions.get("section", "yard")))
	var targets: Array[Vector2] = []
	if str(part.conditions.get("near", "")) == "gate":
		var at := world.get_waypoint(&"gate_inside")
		for dz: float in [0.0, -1.5, -3.0, -4.5, -6.0]:
			for dx: float in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0]:
				if Vector2(dx, dz).length() <= HillRequests.NEAR_RADIUS - 2.0:
					targets.append(Vector2(at.x + dx, at.z + dz))
		for t: Vector2 in targets:
			var uid := _place_near(decor_id, t, section)
			if uid != "":
				return uid
		return ""
	for g: String in graveyard.plots_in_section(section):
		targets.append(_centre_of(g) + Vector2(0.0, 1.6))
	for t: Vector2 in targets:
		var uid := _place_near(decor_id, t, section)
		if uid != "":
			return uid
	return ""


## A visit part at its place (the player stands at the waypoint; the TimedAction of start_visit).
func _large_visit(id: StringName, part: OrderData) -> void:
	_leave_room()
	_large_walk()
	player.global_position = world.get_waypoint(StringName(str(part.conditions.get("place", ""))))
	var reason := hill.visit_block_reason(id, player)
	if reason != "":
		problems.append("day %d: visit %s refused: %s" % [TimeManager.day, id, reason])
		return
	hill.start_visit(id)


## After Osric's evening: a visit part with a window (the lantern evening at the gate, 21:30–23:00); the ghosts.
func _large_evening() -> void:
	for id: StringName in hill.large_active():
		var parts := HillRules.parts_of(hill.large_data(id))
		for i: int in hill.open_parts(id):
			var part := parts[i]
			if part.kind != HillRules.KIND_VISIT:
				continue
			var w := HillRules.visit_window(part)
			if w.x < 0 or TimeManager.minute_of_day > w.y - HillRules.visit_minutes(part):
				continue
			_wait_until(w.x)
			_large_visit(id, part)
		if not hill.large_active().has(id):
			continue
		for i: int in hill.open_parts(id):
			if parts[i].kind in [HillRules.KIND_GHOST, HillRules.KIND_GHOSTS] and not _listen_tonight:
				_large_listen(parts[i])


## Only the ghosts a ghost / ghosts part needs (in its section) – the duty player does not walk every grave.
func _large_listen(part: OrderData) -> void:
	_wait_until(LISTEN_MINUTE)
	var want := str(part.conditions.get("section", ""))
	var left := HillRules.need(part)
	for id: String in ghosts.eligible_graves():
		if left <= 0:
			break
		if want != "" and String(graveyard.section_of(id)) != want:
			continue
		var plot := world.get_node_by_layout_id(id) as Node3D
		player.global_position = plot.global_position + Vector3(0.0, 0.0, 1.5)
		ghosts.reselect()
		ghosts.update_visuals(TimeManager.get_minute_f())
		for g: Ghost in ghosts.active_ghosts():
			if g.grave_id == id and g.can_interact(player):
				var coins := inv().count(&"coin")
				g.interact(player)
				gifts += inv().count(&"coin") - coins
				left -= 1
				break


func _large_walk() -> void:
	var before := TimeManager.total_minutes()
	_walk()
	large_minutes += TimeManager.total_minutes() - before


## "| Tag | Arbeit bis | Leerlauf | … große Bitten …" for docs/reviews/phase9_round1/bitten_gross.md.
func table_large() -> String:
	var lines := PackedStringArray(["| Tag | Arbeit bis | Leerlauf bis 18:00 | kleine Bitten (Σ) | große Bitten erfüllt (Σ) | Münzen aus großen Bitten (Σ) | läuft am Abend | Münzen | Ruf |",
			"|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		lines.append("| %d | %s | %d min | %d | %d | %d | %s | %d | %d |" % [r.day, UIKit.clock(int(r.work_end)), int(r.idle),
				int(r.hill_done), int(r.get("large_done", 0)), int(r.get("large_coins", 0)), str(r.get("large_on", "")),
				int(r.coins), int(r.rep)])
	return "\n".join(lines)
