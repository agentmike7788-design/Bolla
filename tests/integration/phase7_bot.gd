class_name Phase7Bot
extends Phase6Bot
## QA playthrough bot of Phase 7 (docs/PHASE7_DESIGN.md §10 "Playthrough-Bot", W3). Extends Phase6Bot
## by the Phase-7 day once village_open is set:
## - the way down and up through the real RegionPortals (milestone road_exit / bridge road_out, the
##   30 minutes on the clock, the 0.8 s fade awaited), the houses through the real HouseDoors / RoomExits;
## - every villager who stands at a talking spot through the real DialogueRunner (v_<npc>.tres): meet /
##   talk, orders offered (the order card) and accepted, turned in (order_ready → order_turn_in), the
##   clues (register, Liesel, the Sterbebuch), the consecration, Quast's case (anatomist) or „Nein"
##   (anatomy_declined), the lecture invitation; the panels the dialogue opens are used through their
##   own buttons' methods (ShopPanel.buy / sell, GiftPanel.give, AnatomistPanel.sell, LecturePanel);
## - the Gemeindetafel (VillageBoard → OrdersPanel.accept) for council orders the pack can deliver now;
## - the Lindenacker cleared (the real obstacles), the pult built (BuildSite in the crypt), tinctures at
##   the pult (Workbench.request_craft), stones for the stone orders on old_01 / old_08 (the real
##   StoneDesignPanel, „[E] Neuen Stein setzen"), D1 with gown and the poppy stele;
## - anatomist7: three specimens of every delivery but D1 (heart in a jar, eyes in the small jar, the hand
##   in linen → bone specimen at the pult) through MorgueTable.request_organ (the exam card's call),
##   pieces to the collection (CollectionPanel.place), sold to Quast, one per lecture night (the trip at
##   22:30, the surgery door, the lecture panel);
## - Ilse at night: „Wer besucht im Dorf die Kranken?" (c_v_three_visitors); the journal links
##   i_deathbook like every insight (Phase4Bot._link).
## The day: the morning as Phase 6 (corpses, gathering, building) until 13:30, then Hollerbrück 14:00–17:30
## (§2.2: everyone is there), then the rest of the Phase-6 passes until the evening.
## Coin ledger: Phase 6 + income "order", "village_sale", "specimen", "lecture", "collection"; spending by
## coins_spent reason incl. &"village", &"donation", &"round", &"consecration".

const VILLAGERS: Array[StringName] = [&"mayor", &"priest", &"innkeeper", &"smith", &"grocer", &"surgeon", &"washer", &"oldwoman"]
## Indoor waypoints → the house door.
const INDOOR_DOORS := {"v_in_office": &"door_office", "v_in_inn": &"door_inn", "v_in_surgery": &"door_surgery"}
const LEAVE_FOR_VILLAGE := 810
const LEAVE_VILLAGE := 1050
const VILLAGE_WALK := 2
const VILLAGE_STEPS := 40
const LECTURE_TRIP := 1350
## Coins kept back in the village (the next day's linen, a cross).
const RESERVE7 := 8
const MILESTONE_STAND := Vector2(9.0, 23.0)
const GIFT_ITEM := &"honey_cake"
## Who gets the honey cakes (the chapter's three „Vertraut", §1.5).
const GIFT_TARGETS: Array[StringName] = [&"washer", &"innkeeper", &"priest", &"mayor"]
const TINCTURE := &"fever_tincture"
const PULT_SITE := "Entities/PultPlace/site_pult"
const PULT_STATION := "Entities/PultPlace/station_pult"
const SHELF := "Entities/PultPlace/station_pult/CollectionShelf"
const D1 := &"d1_hagedorn"

## Phase-7 flags on top of the Phase-6 ones:
## "p7": plays Phase 7 · "anatomy": takes Quast's case and three specimens of every delivery but D1 ·
## "gifts": a honey cake a day to GIFT_TARGETS · "rounds": rounds in the Holderkrug (in all) · "board":
## council orders · "donations": the two donation orders · "sell": surplus herbs / berries / yarn in the
## village · "collection": specimens to the shelf first (anatomist) · "lectures": one per lecture night.
const P7_FLAGS := {"p7": true, "anatomy": false, "gifts": true, "rounds": 2, "board": true, "donations": true, "sell": true,
		"collection": false, "lectures": false, "save_in_inn": false}

static var P7_STRATEGIES := {
	&"neighbor7": _with7({}, {}, {"optional": [&"crypt", &"chapel"]}, {}),
	&"anatomist7": _with7({}, {}, {"optional": [&"crypt", &"chapel"]}, {"anatomy": true, "collection": true, "lectures": true,
			"donations": false}),
	&"save_load7": _with7({"save_load": true}, {}, {"optional": [&"crypt", &"chapel"]}, {"save_in_inn": true}),
}

var village: Village
var orders: Orders
var rel: Relationships
var shops: VillageShops
var specimens: Specimens
var lectures: Lectures

## Phase-7 progress.
var open7_day: int = -1
var chapter7_day: int = -1
var spent_p7: int = 0
var lowest_morning_p7: int = 1 << 30
var village_days: Array[int] = []
var orders_done: Array[Dictionary] = []
var organs_taken: Array[Dictionary] = []
var lectures_held: Array[Dictionary] = []
var saved_in_inn: bool = false
var trace7: PackedStringArray = []
var _deadline: int = EVENING
var _watching7: bool = false
var _shop_done: Dictionary = {}
var _rounds: int = 0


static func _with7(p4: Dictionary, p5: Dictionary, p6: Dictionary, p7: Dictionary) -> Dictionary:
	var out := _with6(p4, p5, p6)
	out.merge(P7_FLAGS.duplicate(true), true)
	out.merge(p7, true)
	return out


func _init(p_strategy: StringName, p_tree: SceneTree) -> void:
	super(p_strategy, p_tree)
	flags = flags.duplicate(true)
	income.merge({"order": 0, "village_sale": 0, "specimen": 0, "lecture": 0, "collection": 0})


func strategies() -> Dictionary:
	return P7_STRATEGIES


func bind() -> void:
	super.bind()
	village = world.get_node("Systems/Village") as Village
	orders = world.get_node("Systems/Orders") as Orders
	rel = world.get_node("Systems/Relationships") as Relationships
	shops = world.get_node("Systems/VillageShops") as VillageShops
	specimens = world.get_node("Systems/Specimens") as Specimens
	lectures = world.get_node("Systems/Lectures") as Lectures


func watch() -> void:
	super.watch()
	EventBus.order_changed.connect(_on_order)
	EventBus.lecture_held.connect(_on_lecture)
	_watching7 = true


func unwatch() -> void:
	super.unwatch()
	if _watching7:
		EventBus.order_changed.disconnect(_on_order)
		EventBus.lecture_held.disconnect(_on_lecture)
		_watching7 = false


func p7_open() -> bool:
	return flags.p7 and GameState.flag_on(&"village_open")


# --- the clock limit (the morning ends at 13:30 on a village day) --------------------------------

func _time_left() -> bool:
	return TimeManager.minute_of_day < mini(EVENING, _deadline) and TimeManager.minute_of_day >= 300


func _fits(minutes: int) -> bool:
	return TimeManager.minute_of_day >= 300 and TimeManager.minute_of_day + minutes <= mini(EVENING, _deadline)


# --- one day ------------------------------------------------------------------------------------

func run_day() -> void:
	_shop_done = {}
	if p7_open():
		if open7_day < 0:
			open7_day = TimeManager.day
			_t7("open: coins %d · %s" % [inv().count(&"coin"), _stock_text(inv())])
		lowest_morning_p7 = mini(lowest_morning_p7, inv().count(&"coin"))
		# The morning's work (corpses, tending, building) ends at 13:30 – Hollerbrück in the afternoon;
		# a burial that does not fit waits in a niche until the way back.
		_deadline = LEAVE_FOR_VILLAGE
	await super.run_day()
	_deadline = EVENING


## Phase 6's passes until 13:30, Hollerbrück, then the rest of the day.
func _phase5() -> void:
	if not p7_open():
		await super._phase5()
		return
	await _p7_tasks()
	var go := _village_today()
	if go:
		_deadline = LEAVE_FOR_VILLAGE
	await super._phase5()
	_deadline = EVENING
	if go and TimeManager.minute_of_day < LEAVE_VILLAGE - 60:
		await _village_trip()
	await _p7_tasks()
	await super._phase5()


## Lindenacker, pult, tinctures, gowns and stones for the orders, the anatomist's pult work.
func _p7_tasks() -> void:
	if not _time_left():
		return
	_clear_linden()
	_build_pult()
	_pult_work()
	_order_gowns()
	await _order_stones()


## A full pack (honey cakes, spirits, jars come with Phase 7): the surplus goes to the shed first.
func _collect_kiln() -> bool:
	var job := shop.job_of(&"forge") if shop.is_built(&"forge") else {}
	if not job.is_empty() and bool(job.get("ready", false)) and player.region_id == &"graveyard":
		_to_room(&"")
	if not job.is_empty() and bool(job.get("ready", false)) and not inv().can_add(&"charcoal", int(job.get("amount", 3))):
		_store_surplus6(true)
	return super._collect_kiln()


func _village_today() -> bool:
	return TimeManager.minute_of_day < LEAVE_VILLAGE - 60


# --- travel -------------------------------------------------------------------------------------

## Down to Hollerbrück or up to the graveyard through the real portal; false = refused.
func _travel(target: StringName) -> bool:
	if player.region_id == target:
		return true
	if player.region_id == &"graveyard":
		if not _to_room(&""):
			return false
		player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	else:
		await _leave_vroom()
	var portal: RegionPortal
	if target == &"village":
		portal = world.get_node("Entities/road_exit") as RegionPortal
	else:
		portal = world.get_node("Regions/Village/Entities/road_out") as RegionPortal
		player.global_transform = Transform3D(Basis.IDENTITY, portal.global_position + Vector3(1.0, 0.0, 0.0))
	if not portal.can_interact(player):
		problems.append("day %d: portal to %s refuses (%s)" % [TimeManager.day, target, portal.get_interaction_prompt(player)])
		return false
	portal.interact(player)
	await _until_arrived()
	if player.region_id != target:
		problems.append("day %d: trip to %s did not arrive" % [TimeManager.day, target])
		return false
	return true


func _until_arrived() -> void:
	var budget := 300
	while HutPortal.is_travelling(player) and budget > 0:
		await tree.process_frame
		budget -= 1
	await tree.physics_frame
	UIState.clear()


func _vnpc(npc_id: StringName) -> Npc:
	return world.get_node_or_null("Regions/Village/Entities/npc_" + String(npc_id)) as Npc


## Into the house of an indoor spot (HouseDoor), out of any other room first.
func _enter_for(npc: Npc) -> bool:
	var door_id := _door_of(npc)
	var room := &""
	if door_id != &"":
		room = (HouseDoor.find(tree, door_id) as HouseDoor).room_id
	if player.interior_id == room:
		return true
	await _leave_vroom()
	if door_id == &"":
		return true
	var door := HouseDoor.find(tree, door_id)
	player.global_transform = door.exit_transform()
	if not door.can_interact(player):
		problems.append("day %d: %s closed (%s)" % [TimeManager.day, door_id, door.get_interaction_prompt(player)])
		return false
	door.interact(player)
	await _until_arrived()
	return player.interior_id == door.room_id


func _door_of(npc: Npc) -> StringName:
	var e := npc.entry
	if e == null or e.path.is_empty():
		return &""
	var wp := String(e.path[e.path.size() - 1])
	for prefix: String in INDOOR_DOORS:
		if wp.begins_with(prefix):
			return INDOOR_DOORS[prefix]
	return &""


func _leave_vroom() -> void:
	if player.interior_id == &"" or player.region_id != &"village":
		return
	var room := InteriorRoom.find(tree, player.interior_id)
	var exits := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit) if room != null else []
	if exits.is_empty():
		problems.append("day %d: no way out of %s" % [TimeManager.day, player.interior_id])
		return
	(exits[0] as RoomExit).interact(player)
	await _until_arrived()


# --- Hollerbrück --------------------------------------------------------------------------------

func _village_trip() -> void:
	if not await _travel(&"village"):
		return
	village_days.append(TimeManager.day)
	_t7("village at %s · coins %d" % [TimeManager.format_clock(), inv().count(&"coin")])
	await _board()
	for pass_i: int in 2:
		for npc_id: StringName in VILLAGERS:
			if TimeManager.minute_of_day >= LEAVE_VILLAGE:
				break
			var npc := _vnpc(npc_id)
			if npc == null:
				continue
			npc.refresh()
			if not npc.is_talkable():
				continue
			if pass_i == 1 and not _has_business(npc_id):
				continue
			if not await _enter_for(npc):
				continue
			_walk(VILLAGE_WALK)
			_talk(npc)
			if flags.save_in_inn and not saved_in_inn and player.interior_id == &"inn":
				await _save_and_load_in_inn()
				npc = _vnpc(npc_id)
	# Pfarrer Lenz stands at the church door 08:00–11:30 and from 16:00 (§2.2): wait for him when he is
	# wanted (first meeting, the consecration, an order).
	var priest := _vnpc(&"priest")
	if priest != null and _priest_wanted() and TimeManager.minute_of_day < 960:
		priest.refresh()
		if not priest.is_talkable():
			await _leave_vroom()
			_wait_until(965)
			priest.refresh()
	if priest != null and priest.is_talkable() and _priest_wanted():
		await _leave_vroom()
		_walk(VILLAGE_WALK)
		_talk(priest)
	await _leave_vroom()
	_t7("leave at %s · coins %d · orders %s" % [TimeManager.format_clock(), inv().count(&"coin"), str(orders.active())])
	await _travel(&"graveyard")


## Something left to do with `npc_id` (an order ready, a shop or gift wish, an offer).
func _priest_wanted() -> bool:
	return not rel.met(&"priest") or not rel.talked_today(&"priest") and (_want_consecration() or not orders.offers(&"priest").is_empty())


func _has_business(npc_id: StringName) -> bool:
	for id: StringName in orders.active():
		if DialogueConditions.order_ready(id, {"inventory": inv()}):
			var o := orders.order_data(id)
			if (o.recipient if o.recipient != &"" else o.giver) == npc_id:
				return true
	var data := rel.villager(npc_id)
	var shop_id := data.shop_id if data != null else &""
	return shop_id != &"" and not _shop_done.has(shop_id) and not _shop_wishes(shop_id).is_empty()


## The Gemeindetafel: council orders the pack can deliver today.
func _board() -> void:
	if not flags.board or orders.active().size() >= 4:
		return
	var wanted: Array[StringName] = []
	for id: StringName in orders.board():
		if orders.state(id) == &"offered" or orders.state(id) == &"":
			if _want_order(id):
				wanted.append(id)
	if wanted.is_empty():
		return
	var board := world.get_node_or_null("Regions/Village/Entities/village_board")
	if board == null:
		problems.append("day %d: no board" % TimeManager.day)
		return
	await _leave_vroom()
	_walk(VILLAGE_WALK)
	board.call(&"interact", player)
	var panel := ui.get_panel(&"orders") as OrdersPanel if ui != null else null
	for id: StringName in wanted:
		if orders.active().size() >= 4:
			break
		if panel != null and panel.is_open and panel.accept_reason(id) == "":
			panel.accept(id)
		elif orders.offer(id) or orders.state(id) == &"offered":
			orders.accept(id)
		if orders.state(id) == &"accepted":
			_t7("board: accepted %s" % id)
	UIState.clear()


# --- dialogues ------------------------------------------------------------------------------------

func _talk(npc: Npc) -> void:
	var dlg := Database.dialogue(npc.entry.dialogue_id if npc.entry != null else &"") as DialogueData
	if dlg == null:
		problems.append("day %d: %s has no dialogue" % [TimeManager.day, npc.npc_id])
		return
	var runner := DialogueRunner.new()
	runner.start(dlg, {"inventory": inv(), "speaker": npc, "player": player})
	var visited := {}
	var path := PackedStringArray()
	for step: int in VILLAGE_STEPS:
		if runner.is_finished():
			break
		var choices := runner.available_choices()
		if choices.is_empty():
			break
		var pick := _pick7(dlg, npc.npc_id, choices, visited)
		if OS.get_environment("P7QA_DEBUG") != "":
			_t7("  %s @%s: %s → %d" % [npc.npc_id, runner.current_node().id if runner.current_node() != null else &"?",
					str(choices.map(func(c: DialogueChoice) -> String: return "%s:%d" % [c.next, _score(npc.npc_id, c, visited)])), pick])
		if pick < 0:
			break
		var choice := choices[pick]
		visited[choice.next] = int(visited.get(choice.next, 0)) + 1
		for a: String in choice.actions:
			visited["a:" + a] = true
		path.append(String(choice.next))
		runner.choose(pick)
		_after_choice(npc.npc_id, choice)
		UIState.clear()
	UIState.clear()
	if path.size() > 1:
		_t7("talk %s: %s" % [npc.npc_id, " ".join(path)])


func _score(npc_id: StringName, c: DialogueChoice, visited: Dictionary) -> int:
	var best := 0
	for a: String in c.actions:
		if visited.has("a:" + a):
			continue
		var key := a.get_slice(":", 0)
		var arg := StringName(a.get_slice(":", 1))
		match key:
			"order_turn_in":
				best = maxi(best, 100)
			"order_accept":
				if _want_order(arg) and orders.active().size() < 4:
					best = maxi(best, 90)
			"consecrate_pay":
				if _want_consecration():
					best = maxi(best, 95)
			"add_clue":
				if not journal.has_clue(arg):
					best = maxi(best, 80)
			"anatomy_case":
				if flags.anatomy and not GameState.flag_on(&"anatomy_known"):
					best = maxi(best, 85)
			"lecture_invite":
				if flags.anatomy:
					best = maxi(best, 75)
			"open_shop":
				if not _shop_done.has(arg) and not _shop_wishes(arg).is_empty():
					best = maxi(best, 60)
			"open_gifts":
				if _gift_for(npc_id) != &"":
					best = maxi(best, 55)
			"open_anatomist":
				if flags.anatomy and not _to_sell().is_empty():
					best = maxi(best, 58)
			"open_lecture":
				if flags.lectures and not _lecture_piece().is_empty():
					best = maxi(best, 59)
			"buy_round":
				if _rounds < int(flags.rounds) and inv().count(&"coin") >= 5 + RESERVE7 + 10:
					best = maxi(best, 50)
			"donate":
				pass
			"set_flag", "set_flag_day":
				if arg == &"anatomy_declined" and not flags.anatomy and not GameState.has_flag(&"anatomy_declined"):
					best = maxi(best, 70)
	return best


func _pick7(dlg: DialogueData, npc_id: StringName, choices: Array[DialogueChoice], visited: Dictionary) -> int:
	var best := -1
	var best_score := 0
	for i: int in choices.size():
		var s := _score(npc_id, choices[i], visited)
		if s > 0 and choices[i].next == &"" and s < 80:
			s = mini(s, 30)  # a panel that ends the talk: after everything else
		if s <= 0:
			var n := choices[i].next
			if n != &"" and int(visited.get(n, 0)) == 0:
				var ahead := _ahead(dlg, n, npc_id, visited, 2)
				if ahead > 0:
					s = ahead - 5
				elif not String(n).begins_with("bye") and n != &"menu" and _plain_node(dlg, n):
					s = 5
		if s > best_score:
			best_score = s
			best = i
	if best >= 0:
		return best
	# Nothing wanted: leave (bye / the end), never loop through the menu.
	for i: int in choices.size():
		if choices[i].next == &"" or String(choices[i].next).begins_with("bye"):
			return i
	if int(visited.get(&"menu", 0)) < 3:
		for i: int in choices.size():
			if choices[i].next == &"menu":
				return i
	return -1


## The best score reachable from node `n` within `depth` steps (conditions of later nodes ignored).
func _ahead(dlg: DialogueData, n: StringName, npc_id: StringName, visited: Dictionary, depth: int) -> int:
	var node := dlg.get_node_by_id(n)
	if node == null or depth <= 0:
		return 0
	var best := 0
	for c: DialogueChoice in node.choices:
		if not DialogueConditions.all_met(c.conditions, {"inventory": inv()}):
			continue
		best = maxi(best, _score(npc_id, c, visited))
		if c.next != &"" and c.next != n and c.next != &"menu":
			best = maxi(best, _ahead(dlg, c.next, npc_id, visited, depth - 1) - 10)
	return best


## A node without panel actions (a remark worth hearing once).
func _plain_node(dlg: DialogueData, n: StringName) -> bool:
	var node := dlg.get_node_by_id(n)
	if node == null:
		return false
	for a: String in node.actions:
		if a.begins_with("open_") or a.begins_with("order_") or a.begins_with("take_item") or a == "donate" or a == "buy_round" \
				or a == "consecrate_pay" or a == "anatomy_case":
			return false
	return true


## The panels a choice opened: used through their own methods, then closed.
func _after_choice(npc_id: StringName, choice: DialogueChoice) -> void:
	for a: String in choice.actions:
		var key := a.get_slice(":", 0)
		var arg := StringName(a.get_slice(":", 1))
		match key:
			"open_shop":
				_use_shop(arg)
			"open_gifts":
				_use_gifts(npc_id)
			"open_anatomist":
				_use_anatomist()
			"open_lecture":
				_use_lecture()
			"buy_round":
				_rounds += 1
			"order_accept":
				if orders.state(arg) == &"accepted":
					_t7("accepted %s" % arg)
			"consecrate_pay":
				_t7("consecration paid (day %s)" % str(GameState.get_flag(&"linden_consecration_day", -1)))


# --- shops, gifts ------------------------------------------------------------------------------------

## [{item, n, sell: bool}] for `shop_id` now.
func _shop_wishes(shop_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := shops.shop(shop_id)
	if s == null:
		return out
	for item: StringName in s.buys:
		var keep := _keep(item)
		var n := mini(inv().count(item) - keep, shops.bought_left(shop_id, item))
		if flags.sell and n > 0:
			out.append({"item": item, "n": n, "sell": true})
	for item: StringName in s.sells:
		var need := _buy_need(item)
		var n := mini(need, shops.stock_left(shop_id, item))
		if n > 0 and shops.buy_block_reason(shop_id, item, n, inv()) == "" and inv().count(&"coin") - shops.sell_price(shop_id, item) * n >= RESERVE7:
			out.append({"item": item, "n": n, "sell": false})
	return out


## How many of `item` the pack keeps back from a sale (orders, gathering wants, the pult).
func _keep(item: StringName) -> int:
	var keep := _want(item) + _order_need(item)
	match item:
		&"herbs":
			keep += 2 * _tinctures_wanted() + 3
		&"elderberries":
			keep += _tinctures_wanted() + 2
		&"burial_gown", &"shroud":
			keep += 3
		&"yarn":
			keep += 4
		&"wound_salve", &"fever_tincture", &"herb_bundle":
			keep += 9
	return keep


## What the strategy buys of `item` in the village now.
func _buy_need(item: StringName) -> int:
	match item:
		&"honey_cake":
			var want := (GIFT_TARGETS.size() if flags.gifts else 0) + _order_need(&"honey_cake")
			return maxi(0, want - inv().count(item))
		&"spirits":
			var want := _tinctures_wanted() + (3 if flags.anatomy else 0)
			return maxi(0, want - inv().count(item))
		&"prep_jar":
			return maxi(0, (2 if flags.anatomy else 0) - inv().count(item))
		&"prep_jar_small":
			return maxi(0, (1 if flags.anatomy else 0) - inv().count(item))
		&"beeswax":
			return maxi(0, (3 if flags.anatomy else 0) - inv().count(item))
	return 0


func _use_shop(shop_id: StringName) -> void:
	var panel := ui.get_panel(&"shop") as ShopPanel if ui != null else null
	if panel == null or not panel.is_open:
		problems.append("day %d: shop %s did not open" % [TimeManager.day, shop_id])
		return
	_shop_done[shop_id] = true
	for w: Dictionary in _shop_wishes(shop_id):
		if bool(w.sell):
			if panel.sell_reason(w.item, int(w.n)) == "":
				panel.sell(w.item, int(w.n))
				_t7("sold %d %s at %s" % [int(w.n), w.item, shop_id])
		elif panel.buy_reason(w.item, int(w.n)) == "":
			panel.buy(w.item, int(w.n))
			_t7("bought %d %s at %s" % [int(w.n), w.item, shop_id])


func _gift_for(npc_id: StringName) -> StringName:
	if not flags.gifts or not npc_id in GIFT_TARGETS:
		return &""
	var data := rel.villager(npc_id)
	if data == null:
		return &""
	if data.gifts_liked.has(GIFT_ITEM) and rel.gift_block_reason(npc_id, GIFT_ITEM, inv()) == "" \
			and inv().count(GIFT_ITEM) > _order_need(GIFT_ITEM):
		return GIFT_ITEM
	return &""


func _use_gifts(npc_id: StringName) -> void:
	var panel := ui.get_panel(&"gift") as GiftPanel if ui != null else null
	var item := _gift_for(npc_id)
	if panel == null or not panel.is_open or item == &"":
		return
	if panel.block_reason(item) == "":
		panel.give(item)
		_t7("gift %s to %s" % [item, npc_id])


# --- orders ----------------------------------------------------------------------------------------

func _want_order(id: StringName) -> bool:
	var o := orders.order_data(id)
	if o == null or orders.state(id) == &"accepted" or orders.state(id) == &"completed":
		return false
	if orders.block_reason(id) != "" and orders.state(id) != &"offered":
		return false
	# One slot stays for the Lindenacker until it is taken; Wiebke's wish once she has died (a bury order
	# for a story corpse would hold a slot for eight days).
	var active := orders.active().size()
	if id != &"o_fenner_linden" and orders.state(&"o_fenner_linden") != &"accepted" and orders.state(&"o_fenner_linden") != &"completed" \
			and active >= 3:
		return false
	if id == &"o_hagedorn_place" and not GameState.flag_on(&"hagedorn_dead"):
		return false
	match o.kind:
		&"section":
			return true
		&"deliver":
			if o.requires_flag == &"anatomy_known" and not flags.anatomy:
				return false
			for item: StringName in o.items:
				if not _can_supply(item, int(o.items[item]), o.board):
					return false
			return true
		&"donate":
			if not flags.donations:
				return false
			var coins_ok := inv().count(&"coin") >= o.coins + 15
			for item: StringName in o.items:
				if item != &"honey_cake" and inv().count(item) < int(o.items[item]):
					return false
			return coins_ok
		&"stone":
			return shop.is_built(&"mason")
		&"bury":
			if id == &"o_lenz_service":
				return flags.service and rites.level() >= 2
			if id == &"ob_gown":
				return inv().count(&"burial_gown") >= 2
			return true
		&"tend":
			return flags.tend and o.board
	return false


## `item` × n can be in the pack before the deadline (board: now).
func _can_supply(item: StringName, n: int, board: bool) -> bool:
	if inv().count(item) >= n:
		return true
	if board:
		return false
	match item:
		&"workstone", &"elderberries", &"charcoal", &"wood", &"stone", &"herbs", &"yarn":
			return true
		&"burial_gown":
			return shop.is_built(&"loom")
		&"fever_tincture":
			return true
	return false


## Items the accepted orders still want (deliver + donate).
func _order_need(item: StringName) -> int:
	var n := 0
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o != null and (o.kind == &"deliver" or o.kind == &"donate"):
			n += int(o.items.get(item, 0))
	return n


func _tinctures_wanted() -> int:
	return maxi(0, _order_need(TINCTURE) - inv().count(TINCTURE))


func _want_consecration() -> bool:
	if GameState.flag_on(&"linden_consecrated") or GameState.has_flag(&"linden_consecration_day"):
		return false
	return inv().count(&"coin") >= village.consecration_price()


## Phase 5 wants + what the orders still need (gathered on the graveyard).
func _want(item: StringName) -> int:
	var base := super._want(item)
	if not p7_open():
		return base
	var need := _order_need(item)
	match item:
		&"herbs":
			need += 2 * _tinctures_wanted()
		&"elderberries":
			need += _tinctures_wanted()
	# The pult (§2.7: 6 wood, 2 iron fittings, 2 stone) while an order or the anatomy wants it.
	if not _pult_built() and (flags.anatomy or _order_need(TINCTURE) > 0):
		var data := Database.station(&"pult") as StationData
		if data != null:
			need += int(data.build_inputs.get(item, 0))
	# The stones of the stone orders.
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o != null and o.kind == &"stone" and masonry.ready_for(o.target).is_empty():
			var shape := Database.stone_shape(StringName(str(o.conditions.get("stone_shape", "stone_stele")))) as StoneShapeData
			if shape != null:
				need += int(shape.inputs.get(item, 0))
	return base + need


func _charcoal_need() -> int:
	return super._charcoal_need() + (_order_need(&"charcoal") if p7_open() else 0)


# --- the Lindenacker, the pult, gowns, stones -----------------------------------------------------

func _clear_linden() -> void:
	if not GameState.flag_on(&"linden_granted") or expansion.is_unlocked(&"linden"):
		return
	for id: String in expansion.obstacle_ids(&"linden"):
		if not _time_left():
			return
		if expansion.is_cleared(id):
			continue
		var node := expansion.obstacle(id)
		if node == null or not node.can_interact(player):
			problems.append("day %d: Lindenacker obstacle %s refuses (%s)" % [TimeManager.day, id, expansion.tool_block_reason(id, inv())])
			continue
		_to_room(&"")
		_walk()
		node.interact(player)
		if expansion.is_cleared(id):
			_t7("cleared %s" % id)


func _pult_built() -> bool:
	return shop.is_built(&"pult")


func _build_pult() -> void:
	if _pult_built() or crypt_level() < 1:
		return
	if _order_need(TINCTURE) == 0 and not flags.anatomy:
		return
	var data := Database.station(&"pult") as StationData
	if data == null or inv().count(&"coin") - data.build_coins < RESERVE7:
		return
	if not _fits(data.build_minutes + CRYPT_WALK):
		return
	if not _to_room(&"crypt"):
		return
	var site := _room_node(&"crypt").get_node_or_null(PULT_SITE) as BuildSite
	if site == null or not site.is_active() or site.block_reason(inv()) != "":
		_note_wait(&"pult", site.block_reason(inv()) if site != null else "no site")
		return
	site.interact(player)
	var panel := ui.get_panel(&"build_site") as BuildSitePanel if ui != null else null
	if panel != null and panel.is_open:
		panel._on_build_pressed()
	else:
		site.request_build()
	UIState.clear()
	if _pult_built():
		_t7("pult built")
	else:
		problems.append("day %d: pult not built (%s)" % [TimeManager.day, site.block_reason(inv())])


func _pult() -> Workbench:
	var room := _room_node(&"crypt")
	return room.get_node_or_null(PULT_STATION) as Workbench if room != null else null


func _pult_work() -> void:
	if not _pult_built():
		return
	var r := Database.recipe(TINCTURE) as RecipeData
	while _tinctures_wanted() > 0 and r != null and CraftingSystem.can_craft(r, inv()) and _fits(r.minutes + CRYPT_WALK):
		if not _to_room(&"crypt"):
			return
		var bench := _pult()
		var had := inv().count(TINCTURE)
		bench.interact(player)
		UIState.clear()
		bench.request_craft(TINCTURE)
		UIState.clear()
		if inv().count(TINCTURE) <= had:
			problems.append("day %d: tincture not made" % TimeManager.day)
			return
		_t7("tincture (%d)" % inv().count(TINCTURE))
	if flags.anatomy:
		_anatomy_pult()


func _order_gowns() -> void:
	var need := _order_need(&"burial_gown")
	if need <= 0 or not shop.is_built(&"loom"):
		return
	while inv().count(&"burial_gown") < need + 1 and _fits(30 + WALK_MINUTES):
		if inv().count(&"yarn") < 2 and inv().count(&"flax") >= 2:
			if not _craft5(&"loom", &"yarn"):
				return
			continue
		if inv().count(&"yarn") < 2 or inv().count(&"linen") < 1:
			return
		if not _craft5(&"loom", &"burial_gown_loom"):
			return


## Stone orders (old_01 / old_08): carved through the stone panel by the order's conditions, set at the
## old grave („[E] Neuen Stein setzen").
func _order_stones() -> void:
	if not shop.is_built(&"mason"):
		return
	for id: StringName in orders.active():
		var o := orders.order_data(id)
		if o == null or o.kind != &"stone" or not _time_left():
			continue
		var grave_id := o.target
		if masonry.ready_for(grave_id).is_empty():
			var d := _order_design(o)
			if masonry.order_block_reason(grave_id, d, inv()) != "":
				_note_wait(id, masonry.order_block_reason(grave_id, d, inv()))
				continue
			if not _fits(StoneDesignRules.minutes(d, stone_cfg) + stone_cfg.set_minutes + 2 * WALK_MINUTES):
				continue
			if _carve_with_panel(grave_id, d) == "":
				continue
		_to_room(&"")
		_walk()
		var plot := world.get_node_by_layout_id(grave_id) as GravePlot
		plot.interact(player)
		UIState.clear()
		_t7("stone for %s on %s: %s" % [id, grave_id, orders.state(id)])


func _order_design(o: OrderData) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = StringName(str(o.conditions.get("stone_shape", "stone_stele")))
	d.ornament = StringName(str(o.conditions.get("ornament", "")))
	if bool(o.conditions.get("inscription", false)) or inv().count(&"ink") >= 1:
		d.inscription = &"i_rest"
	return d


## D1 (and every grave with a bury order) gets the order's ornament (poppy for Wiebke Hagedorn).
func _design_for(grave_id: String, shape: StringName) -> StoneDesign:
	var d := super._design_for(grave_id, shape)
	var grave := graveyard.get_grave(grave_id)
	var corpse := manager.get_record(grave.corpse_id) if grave != null else null
	if corpse != null and corpse.story_id == D1:
		d.ornament = &"orn_poppy"
	return d


# --- anatomy (anatomist7) --------------------------------------------------------------------------

## Heart (jar), eyes (small jar), hand (bundle) of every corpse but D1, before the dress.
func _on_table(record: CorpseRecord, table: MorgueTable) -> bool:
	if p7_open() and flags.anatomy and GameState.flag_on(&"anatomy_known") and record.story_id != D1 and not record.is_dressed() \
			and record.story_id == &"":
		for pair: Array in [[&"heart", SpecimenRecord.CONTAINER_JAR], [&"eyes", SpecimenRecord.CONTAINER_JAR],
				[&"hand", SpecimenRecord.CONTAINER_BUNDLE]]:
			_stock_organ(pair[0], pair[1])
			var reason := care.organ_block_reason(record.id, pair[0], pair[1], inv())
			if reason != "":
				_note_wait(StringName("organ_" + String(pair[0])), reason)
				continue
			var before := specimens.of_corpse(record.id).size()
			table.request_organ(pair[0], pair[1])
			UIState.clear()
			if specimens.of_corpse(record.id).size() > before:
				organs_taken.append({"day": TimeManager.day, "corpse": record.id, "organ": pair[0]})
				_t7("took %s of %s" % [pair[0], record.id])
	return super._on_table(record, table)


## The inputs for one organ – bought in the village the day before; Osric's linen as usual.
func _stock_organ(_organ: StringName, _container: StringName) -> void:
	pass


## Bundled hands → bone specimens; pieces to the collection shelf.
func _anatomy_pult() -> void:
	for uid: String in specimens.held():
		var spec := specimens.get_record(uid)
		if spec.organ == &"hand" and spec.container == SpecimenRecord.CONTAINER_BUNDLE and inv().has_uid(uid) \
				and inv().count(&"beeswax") >= 1 and inv().count(&"linen") >= 2 and _fits(70):
			if not _to_room(&"crypt"):
				return
			_pult().interact(player)
			UIState.clear()
			EventBus.ui_panel_requested.emit(&"pult", {"station": &"pult", "inventory": inv(), "workbench": _pult(), "player": player})
			var panel := ui.get_panel(&"pult") as PultPanel if ui != null else null
			if panel != null and panel.is_open:
				panel.select(uid)
				if panel.action_reason(PultPanel.ACTION_BONE) == "":
					panel.request_action(PultPanel.ACTION_BONE)
			UIState.clear()
			_t7("bone specimen %s: %s" % [uid, specimens.get_record(uid).container])
	if flags.collection:
		_fill_shelf()


func _fill_shelf() -> void:
	var shelf := _room_node(&"crypt").get_node_or_null(SHELF) if _room_node(&"crypt") != null else null
	if shelf == null or not _pult_built():
		return
	var placed: Array[StringName] = []
	var taken := {}
	for uid: String in specimens.held():
		var spec := specimens.get_record(uid)
		if not inv().has_uid(uid) or spec.container == SpecimenRecord.CONTAINER_BUNDLE or taken.has(spec.organ):
			continue
		if _shelf_has(shelf, spec.organ):
			continue
		taken[spec.organ] = uid
	if taken.is_empty():
		return
	if not _to_room(&"crypt"):
		return
	shelf.call(&"interact", player)
	var panel := ui.get_panel(&"collection") as CollectionPanel if ui != null else null
	if panel != null and panel.is_open:
		for organ: Variant in taken:
			if panel.place(String(taken[organ])):
				placed.append(StringName(str(organ)))
	UIState.clear()
	if not placed.is_empty():
		_t7("shelf: %s" % str(placed))


func _shelf_has(shelf: Node, organ: StringName) -> bool:
	var store := shelf.call(&"store") as Inventory if shelf.has_method(&"store") else null
	if store == null:
		return false
	for uid: String in store.uids():
		var spec := specimens.get_record(uid)
		if spec != null and spec.organ == organ:
			return true
	return false


## Held pieces Quast may buy now (not wanted on the shelf or for tonight's lecture).
func _to_sell() -> PackedStringArray:
	var out := PackedStringArray()
	var keep_lecture := _lecture_piece() if flags.lectures else ""
	for uid: String in specimens.held():
		var spec := specimens.get_record(uid)
		if uid == keep_lecture or not inv().has_uid(uid) or specimens.sell_block_reason(uid, inv()) != "":
			continue
		if spec.organ == &"hand" and spec.container == SpecimenRecord.CONTAINER_BUNDLE:
			continue  # becomes a bone specimen first
		out.append(uid)
	return out


func _use_anatomist() -> void:
	var panel := ui.get_panel(&"anatomist") as AnatomistPanel if ui != null else null
	if panel == null or not panel.is_open:
		return
	for uid: String in _to_sell():
		if panel.sell_block_reason(uid) == "":
			var coins := panel.sell(uid)
			_t7("sold %s for %d" % [specimens.get_record(uid).organ, coins])


func _lecture_piece() -> String:
	for uid: String in specimens.held():
		var spec := specimens.get_record(uid)
		if inv().has_uid(uid) and spec.container == SpecimenRecord.CONTAINER_JAR and specimens.clarity(uid) >= 0.5:
			return uid
	return ""


func _use_lecture() -> void:
	var panel := ui.get_panel(&"lecture") as LecturePanel if ui != null else null
	var uid := _lecture_piece()
	if panel == null or not panel.is_open or uid == "":
		return
	panel.select(uid)
	if panel.block_reason() == "":
		panel.request_hold()
	UIState.clear()


## A lecture night (anatomist): at 22:30 down to the surgery, Quast at the lectern, the lecture, back.
func _lecture_night() -> void:
	if not (flags.lectures and p7_open() and lectures.invited()) or TimeManager.day % 3 != 0 or _lecture_piece() == "":
		return
	if TimeManager.minute_of_day < LECTURE_TRIP:
		_wait_until(LECTURE_TRIP)
	if not await _travel(&"village"):
		return
	var quast := _vnpc(&"surgeon")
	quast.refresh()
	if not quast.is_talkable():
		problems.append("day %d: Quast not at the lectern at %s" % [TimeManager.day, TimeManager.format_clock()])
	elif await _enter_for(quast):
		_talk(quast)
	await _leave_vroom()
	await _travel(&"graveyard")


func _night_at_the_wall() -> void:
	await _lecture_night()
	await super._night_at_the_wall()
	# Kapelle 3 (§2.10, B8) wants 2 gold leaf: Ilse sells it at night (Theres only to „Befreundet").
	var nb := _next_build()
	if not p7_open() or nb.is_empty() or not trade.is_present():
		return
	var lvl := (buildings.building(nb.id) as BuildingData).level_data(int(nb.level))
	var need := int(lvl.inputs.get(&"gold_leaf", 0)) - inv().count(&"gold_leaf") if lvl != null else 0
	if need > 0 and inv().count(&"coin") - 6 * need >= lvl.coins + RESERVE7 and trade.stock_left(&"gold_leaf") >= need:
		if trade.buy(&"gold_leaf", need, inv()):
			_t7("gold leaf %d for %s %d" % [need, nb.id, int(nb.level)])
	UIState.clear()


## Ilse (Phase 4) – the Phase-7 question first while its clue is missing.
func _pick(choices: Array[DialogueChoice], asked: Dictionary) -> int:
	if p7_open() and not journal.has_clue(&"c_v_three_visitors"):
		for want: StringName in [&"p7_visitors", &"p7_village_ilse"]:
			for i: int in choices.size():
				if choices[i].next == want and not asked.has(want):
					return i
	return super._pick(choices, asked)


# --- save / load ---------------------------------------------------------------------------------

func _save_and_load_in_inn() -> void:
	saved_in_inn = true
	UIState.clear()
	var err := SaveManager.save_game(SaveManager.AUTOSAVE_SLOT)
	if err != OK:
		problems.append("day %d: save in the inn failed %s" % [TimeManager.day, error_string(err)])
		return
	var load_err: Error = await SaveManager.load_game(SaveManager.AUTOSAVE_SLOT)
	if load_err != OK:
		problems.append("day %d: load in the inn failed %s" % [TimeManager.day, error_string(load_err)])
	bind()
	player.instant_actions = true
	if player.interior_id != &"inn" or player.region_id != &"village":
		problems.append("day %d: after the load in the inn: %s / %s" % [TimeManager.day, player.region_id, player.interior_id])


# --- record ---------------------------------------------------------------------------------------

func _t7(what: String) -> void:
	trace7.append("d%d %s %s" % [TimeManager.day, TimeManager.format_clock(), what])


func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	var values := {}
	for id: StringName in VILLAGERS:
		values[String(id)] = rel.value(id)
	r.merge({
		"orders_done": orders.done_count(), "givers": orders.done_givers().size(), "trusted": village.trusted_count(),
		"rel": values, "linden": expansion.is_unlocked(&"linden"), "consecrated": GameState.flag_on(&"linden_consecrated"),
		"chapter7": GameState.flag_on(&"name_in_village_complete"), "open7": p7_open(),
		"specimens": GameState.get_stat(&"specimens_taken"), "sold": GameState.get_stat(&"specimens_sold"),
		"standing": GameState.get_stat(&"university_standing"), "deathbook": journal.has_insight(&"i_deathbook"),
		"active": orders.active().size(),
	})


func table_p7() -> String:
	var lines := PackedStringArray(["| Tag | Münzen früh | Ausgaben (Zweck) | Einnahmen (Quelle) | Münzen abends | Aufträge erledigt (Geber) | aktiv | Vertraut | Beziehungen Fe/Le/Ro/Es/Th/Qu/Li/Ha | Lindenacker | Präparate gen./verk. | Ansehen | Erkenntnis | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		if not bool(r.get("open7", false)):
			continue
		var parts := PackedStringArray()
		var spent_day: Dictionary = r.get("spent_day", {})
		for reason: Variant in spent_day:
			parts.append("%s %d" % [reason, int(spent_day[reason])])
		var inc := PackedStringArray()
		var income_day: Dictionary = r.get("income_day", {})
		for source: Variant in income_day:
			inc.append("%s %d" % [source, int(income_day[source])])
		var v: Dictionary = r.get("rel", {})
		var rels := "/".join(PackedStringArray([str(v.get("mayor", 0)), str(v.get("priest", 0)), str(v.get("innkeeper", 0)), str(v.get("smith", 0)),
				str(v.get("grocer", 0)), str(v.get("surgeon", 0)), str(v.get("washer", 0)), str(v.get("oldwoman", 0))]))
		lines.append("| %d | %d | %s | %s | %d | %d (%d) | %d | %d | %s | %s | %d/%d | %d | %s | %s |" % [r.day, int(r.get("morning_coins", 0)),
				", ".join(parts) if not parts.is_empty() else "–", ", ".join(inc) if not inc.is_empty() else "–", r.coins,
				int(r.get("orders_done", 0)), int(r.get("givers", 0)), int(r.get("active", 0)), int(r.get("trusted", 0)), rels,
				"offen" if r.get("linden", false) else ("geweiht" if r.get("consecrated", false) else "–"),
				int(r.get("specimens", 0)), int(r.get("sold", 0)), int(r.get("standing", 0)), "✓" if r.get("deathbook", false) else "–",
				"✓" if r.get("chapter7", false) else "offen"])
	return "\n".join(lines)


func ledger_text() -> String:
	return super.ledger_text() + " · Phase 7 spent %d · lowest morning (Phase 7) %d" % [spent_p7, lowest_morning_p7]


func _on_coins_spent(amount: int, reason: StringName) -> void:
	super._on_coins_spent(amount, reason)
	if p7_open():
		spent_p7 += amount


func _on_payment(coins: int, reason: String) -> void:
	var source := ""
	if reason.begins_with(Orders.REASON_ORDER.split("%")[0]):
		source = "order"
	elif reason == VillageShops.PAYMENT_REASON:
		source = "village_sale"
	elif reason.begins_with(Specimens.REASON_SALE.split("%")[0]):
		source = "specimen"
	elif reason == Lectures.REASON_FEE:
		source = "lecture"
	elif reason.begins_with(CollectionShelf.FORMAT_PAYMENT.split("%")[0]):
		source = "collection"
	if source != "":
		income[source] = int(income.get(source, 0)) + coins
		_income_day[source] = int(_income_day.get(source, 0)) + coins
		return
	super._on_payment(coins, reason)


func _on_chapter(chapter_id: StringName) -> void:
	super._on_chapter(chapter_id)
	if chapter_id == &"name_in_village" and chapter7_day < 0:
		chapter7_day = TimeManager.day


func _on_order(order_id: StringName, state: StringName) -> void:
	_t7("order %s %s" % [order_id, state])
	if state == &"completed":
		orders_done.append({"day": TimeManager.day, "id": order_id, "giver": orders.order_data(order_id).giver})


func _on_lecture(night: int, organ: StringName, fee: int, rumor: bool) -> void:
	lectures_held.append({"night": night, "organ": organ, "fee": fee, "rumor": rumor})
