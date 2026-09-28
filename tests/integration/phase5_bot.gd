class_name Phase5Bot
extends Phase4Bot
## QA playthrough bot of Phase 5 (docs/PHASE5_DESIGN.md §10 "Playthrough-Bot", W3). Extends
## Phase4Bot (the Phase-3/4 day: heaps, deliveries, preparation, clearing, tending, decor, ghosts,
## Ilse, bed) by the Phase-5 day once workshop_open is set:
## - Osric through the real DialogueRunner on data/dialogue/carter.tres (p5_intro, the quarry
##   licence, the old pickaxe, steel rods, fittings – take_item:coin → the coin ledger);
## - the Ostpforte, the Am-Bruch / quarry / Schlag / Holunder gather nodes (GatherNode.interact),
##   the boulders (ClearableObstacle.interact);
## - the build sites (BuildSite.interact + request_build as the build-site panel does);
## - the stations (Workbench.interact + request_craft: kiln, bars, fittings, tools, yarn, linen,
##   gowns, ink, herb bundles) and "[E] Holzkohle holen";
## - designed stones through the real StoneDesignPanel (select grave / shape / inscription /
##   ornament / gold → carve(): the timed action + Stonemasonry.carve) and "[E] Gestalteten Stein
##   setzen" at the grave (GravePlot.interact);
## - gold leaf at Ilse's wall (NightTrade.buy after her dialogue opened the shop).
## Walking: WALK_MINUTES per task plus a trip to Am Bruch / the Schlag (TRIP_MINUTES).
## Coin ledger: start, income by source (burials, stipend, ghost gifts, Ilse, valuables), spending
## by coins_spent reason (license, build, osric, ilse) – Osric's Phase-3/4 goods go through
## GameState.note_coins_spent like the real dialogue (take_item:coin), end, lowest morning.

const TRIP_MINUTES := 5
## Coins kept after a purchase the chapter needs / after an optional one (§2.8: "nie arm").
const RESERVE_NEEDED := 10
const RESERVE_OPTIONAL := 15
const OSRIC_STEPS := 40
const FORGE_RECIPES_TOOLS: Array[StringName] = [&"axe_iron", &"shovel_iron", &"pickaxe_master", &"shovel_master", &"axe_master"]
const MASTER_OF := {&"shovel": &"shovel_master", &"axe": &"axe_master", &"pickaxe": &"pickaxe_master"}
const IRON_OF := {&"shovel": &"shovel_iron", &"axe": &"axe_iron", &"pickaxe": &"pickaxe_iron"}
const BRUCH_NODES: PackedStringArray = ["gather_clay_1", "gather_flax_1", "gather_flax_2", "gather_flax_3", "gather_herbs_1", "gather_herbs_2"]
const QUARRY_NODES: PackedStringArray = ["gather_ore_1", "gather_rubble_1", "gather_workstone_1", "gather_workstone_2"]
const SCHLAG_ALDERS: PackedStringArray = ["gather_alder_1", "gather_alder_2", "gather_alder_3", "gather_alder_4", "gather_alder_5"]
const SCHLAG_HERBS: PackedStringArray = ["gather_herbs_3", "gather_herbs_4"]
const ELDER_NODES: PackedStringArray = ["gather_elder_1", "gather_elder_2", "gather_elder_3"]
const ORNAMENTS: Array[StringName] = [&"orn_ivy", &"orn_poppy", &"orn_elder", &"orn_torch"]

## Phase-5 flags on top of the Phase-4 ones:
## "p5": plays Phase 5 at all · "gold": designed stones gilded over the run · "master_tools":
## master shovel + axe too (optional, §2.8) · "tools_first": all tools to tier 2 before any stone
## but the master stone · "robbed_first": master stones for harvested graves first (mender) ·
## "restone": re-set stones on graves beyond the chapter's master stone · "loom_gowns": gowns
## from the loom for the deliveries (new game) · "min_coins": floor of optional purchases.
const P5_FLAGS := {"p5": true, "gold": 3, "master_tools": true, "tools_first": false, "robbed_first": false,
		"restone": true, "loom_gowns": true}

static var P5_STRATEGIES := {
	&"reverent5": _with5({}, {}),
	&"toolsmith": _with5({}, {"tools_first": true, "gold": 0}),
	&"mender": _with5({}, {"robbed_first": true}),
	&"harvester5": _with5({"take_valuables": true, "prep": false, "gown": false, "balm": false,
			"harvest": [&"hair", &"teeth"], "decor": false}, {"gold": 0, "master_tools": false, "restone": false, "loom_gowns": false}),
	&"crafter": _with5({}, {}),
	&"save_load5": _with5({"save_load": true}, {}),
}

var shop: Workshop
var gathering: GatherManager
var masonry: Stonemasonry
var ui: UIRoot
var stone_cfg: StoneConfig

## Coin ledger.
var start_coins: int = -1
var income: Dictionary = {"burial": 0, "stipend": 0, "gift": 0, "ilse": 0, "valuables": 0}
var spent_by: Dictionary = {}
var lowest_morning: int = 1 << 30
var morning_coins: int = 0
var spent_p5: int = 0
## Phase-5 progress.
var open_day: int = -1
var chapter5_day: int = -1
var tier_days: Dictionary = {}
var gathered: Dictionary = {}
var stones_set: Array[Dictionary] = []
var loom_gowns: int = 0
var gilded: int = 0
## {"<action>@<tier>": minutes measured on the clock} (toolsmith: §2.3 table).
var action_minutes: Dictionary = {}
var content_start: int = -1
var _day_spent: Dictionary = {}
var _area: StringName = &"hut"
var _watching5: bool = false


static func _with5(p4_overrides: Dictionary, p5_overrides: Dictionary) -> Dictionary:
	var out := _with(p4_overrides)
	out.merge(P5_FLAGS.duplicate(true), true)
	out.merge(p5_overrides, true)
	return out


func strategies() -> Dictionary:
	return P5_STRATEGIES


func bind() -> void:
	super.bind()
	shop = world.get_node("Systems/Workshop") as Workshop
	gathering = world.get_node("Systems/Gathering") as GatherManager
	masonry = world.get_node("Systems/Stonemasonry") as Stonemasonry
	ui = world.get_node_or_null("UI") as UIRoot
	stone_cfg = Database.config(&"stone_config") as StoneConfig
	if start_coins < 0:
		start_coins = inv().count(&"coin")


func watch() -> void:
	super.watch()
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.trader_trade.connect(_on_trader_trade)
	EventBus.resource_gathered.connect(_on_gathered)
	EventBus.tool_tier_changed.connect(_on_tier)
	EventBus.grave_stone_set.connect(_on_stone_set)
	_watching5 = true


func unwatch() -> void:
	super.unwatch()
	if _watching5:
		EventBus.coins_spent.disconnect(_on_coins_spent)
		EventBus.trader_trade.disconnect(_on_trader_trade)
		EventBus.resource_gathered.disconnect(_on_gathered)
		EventBus.tool_tier_changed.disconnect(_on_tier)
		EventBus.grave_stone_set.disconnect(_on_stone_set)
		_watching5 = false


func p5_open() -> bool:
	return flags.p5 and shop.is_open()


# --- one day ------------------------------------------------------------------------------

func run_day() -> void:
	morning_coins = inv().count(&"coin")
	lowest_morning = mini(lowest_morning, morning_coins)
	_day_spent = {}
	_area = &"hut"
	if p5_open() and open_day < 0:
		open_day = TimeManager.day
		content_start = _content_ghosts()
	_leave_hut()
	_gather()
	if p5_open():
		_collect_kiln()
		_start_kiln()
	var tables := Database.corpse_tables() as CorpseTables
	if TimeManager.minute_of_day < tables.delivery_minute + 10:
		_craft_essentials()
		_wait_until(tables.delivery_minute + 10)
	_buy_for_today()
	if p5_open():
		_osric5()
	_handle_corpses()
	_craft_essentials()
	if flags.upgrade:
		_upgrade_markers()
	if flags.clear:
		_clear_obstacles()
	if flags.tend:
		_tend()
	if flags.decor and not p5_open():
		_decorate()
	if flags.tend:
		_tend()
	_handle_corpses()
	_balm_waiting()
	if p5_open():
		await _phase5()
	if flags.link:
		_link()
	if flags.listen:
		_listen_to_ghosts()
	if flags.trade:
		await _night_at_the_wall()
		if flags.link:
			_link()
	await _sleep()


## The Phase-5 part of the day: passes over all tasks until none makes progress or the evening.
func _phase5() -> void:
	for pass_i: int in 12:
		if not _time_left():
			return
		var did := false
		did = _open_gate() or did
		did = _collect_kiln() or did
		did = _build_next() or did
		did = _forge_work() or did
		did = _gather_bruch() or did
		did = _gather_quarry() or did
		did = _gather_schlag() or did
		did = _gather_elder() or did
		did = _workbench5() or did
		did = _loom_work() or did
		did = _forge_work() or did
		did = _start_kiln() or did
		did = (await _stones()) or did
		if not did:
			return


func _fits(minutes: int) -> bool:
	return TimeManager.minute_of_day >= 300 and TimeManager.minute_of_day + minutes <= EVENING


func _go(area: StringName) -> void:
	if _area != area:
		_walk(TRIP_MINUTES)
		_area = area


# --- Osric (real dialogue) --------------------------------------------------------------------

## What to buy at Osric's cart today, in order ({"id": choice marker, "coins": price, "reserve"}).
func _osric_wishes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var coins := inv().count(&"coin")
	var budget := coins
	if not GameState.has_flag(&"bruch_license"):
		if budget - 20 < RESERVE_NEEDED:
			return out
		out.append({"item": &"license", "coins": 20})
		budget -= 20
	if not GameState.has_flag(&"bought_pickaxe") and (shop.is_built(&"mason") or shop.is_built(&"loom")) and budget - 14 >= RESERVE_NEEDED:
		out.append({"item": &"pickaxe_iron", "coins": 14})
		budget -= 14
	# Fittings for the loom / forge (before the own forge) and the woodcutter's axe.
	var fittings_need := 0
	if not shop.is_built(&"loom"):
		fittings_need += 2
	if not shop.is_built(&"forge"):
		fittings_need += 2
	# §2.8: 2 fittings for the woodcutter's axe before the first own bar.
	if shop.is_built(&"loom") and player.tool_tier(&"axe") == 0 and inv().count(&"iron_bar") == 0 and inv().count(&"iron_ore") < 2:
		fittings_need += 2
	fittings_need -= inv().count(&"iron_fittings")
	while fittings_need > 0:
		var take := 4 if fittings_need >= 4 else 2
		if budget - 3 * take < RESERVE_NEEDED:
			break
		out.append({"item": &"iron_fittings", "coins": 3 * take, "amount": take})
		budget -= 3 * take
		fittings_need -= take
	# Steel rods: the master pickaxe (needed), master shovel / axe (optional).
	if shop.is_built(&"forge"):
		var rods := inv().count(&"steel_rod")
		for kind: StringName in [&"pickaxe", &"shovel", &"axe"]:
			if player.tool_tier(kind) != 1 or (kind != &"pickaxe" and not flags.master_tools):
				continue
			if rods > 0:
				rods -= 1
				continue
			var floor := RESERVE_NEEDED if kind == &"pickaxe" else RESERVE_OPTIONAL
			if budget - 6 >= floor:
				out.append({"item": &"steel_rod", "coins": 6})
				budget -= 6
	return out


## Talks to Osric (07:40–10:00) through carter.tres and buys the wishes of the day. A fresh
## conversation shows one pending remark first (p3_intro → p4_intro → p5_intro, each once): the bot
## talks again, as a player would, until the Phase-5 menu is there (at most 4 conversations).
func _osric5() -> void:
	var wishes := _osric_wishes()
	var trace := PackedStringArray()
	for talk: int in 4:
		if wishes.is_empty() and GameState.has_flag(&"p5_intro"):
			break
		var before := wishes.size()
		var intro_before := GameState.has_flag(&"p5_intro")
		_talk_to_osric(wishes, trace)
		if wishes.size() == before and GameState.has_flag(&"p5_intro") == intro_before and GameState.has_flag(&"p5_intro"):
			break
	UIState.clear()
	if not wishes.is_empty():
		problems.append("day %d: Osric – not bought %s (%s)" % [TimeManager.day, str(wishes), " ".join(trace)])


func _talk_to_osric(wishes: Array[Dictionary], trace: PackedStringArray) -> void:
	var speaker := world.get_node_by_layout_id("npc_carter")
	var runner := DialogueRunner.new()
	runner.start(Database.dialogue(&"carter") as DialogueData, {"inventory": inv(), "speaker": speaker})
	_walk(1)
	var visited := {}
	for step: int in OSRIC_STEPS:
		if runner.is_finished():
			break
		var choices := runner.available_choices()
		if choices.is_empty():
			break
		var pick := _pick_osric(choices, wishes, visited)
		if pick < 0:
			break
		var choice := choices[pick]
		trace.append("%s→%s" % [runner.current_node().id if runner.current_node() != null else &"?", choice.next])
		visited[choice.next] = int(visited.get(choice.next, 0)) + 1
		var bought := _choice_item(choice)
		runner.choose(pick)
		if bought != &"":
			for i: int in wishes.size():
				if wishes[i].item == bought:
					wishes.remove_at(i)
					break
		UIState.clear()
	UIState.clear()


## The item a choice buys (&"license" for the letter), &"" when it buys nothing.
static func _choice_item(choice: DialogueChoice) -> StringName:
	for a: String in choice.actions:
		if a.begins_with("set_flag:bruch_license"):
			return &"license"
		if a.begins_with("give_item:"):
			return StringName(a.split(":")[1])
	return &""


func _pick_osric(choices: Array[DialogueChoice], wishes: Array[Dictionary], visited: Dictionary) -> int:
	# 1. A choice that buys the next wish (fittings: the matching amount).
	for w: Dictionary in wishes:
		for i: int in choices.size():
			var c := choices[i]
			if _choice_item(c) != w.item:
				continue
			if w.item == &"iron_fittings" and not c.actions.has("give_item:iron_fittings:%d" % int(w.amount)):
				continue
			return i
	# 2. Towards the licence / the Phase-5 shop while something is still wanted.
	if not wishes.is_empty():
		var want: StringName = &"p5_license" if wishes[0].item == &"license" else &"p5_shop"
		for i: int in choices.size():
			if choices[i].next == want and int(visited.get(want, 0)) < 6:
				return i
		for i: int in choices.size():
			if choices[i].text == "Ich nehme noch etwas." or choices[i].next == &"p5_shop":
				return i
	# 3. Otherwise onwards (remarks), never twice into the same menu; leave at the end.
	for i: int in choices.size():
		var n := choices[i].next
		if n == &"" or n == &"menu" or n == &"menu_cold":
			continue
		if int(visited.get(n, 0)) == 0 and not String(n).begins_with("shop") and not String(n).begins_with("p5_shop") \
				and n != &"p5_license" and not String(n).begins_with("p3_intro_tools") and not String(n).begins_with("p4_intro_prep"):
			return i
	for i: int in choices.size():
		if choices[i].next == &"":
			return i
	if int(visited.get(&"menu", 0)) + int(visited.get(&"menu_cold", 0)) > 4:
		return -1
	for i: int in choices.size():
		if choices[i].next == &"menu" or choices[i].next == &"menu_cold":
			return i
	return -1


# --- Am Bruch, the quarry, the Schlag, the Holunder -----------------------------------------------

func _open_gate() -> bool:
	if not GameState.has_flag(&"bruch_license") or expansion.is_unlocked(&"bruch"):
		return false
	var gate := expansion.obstacle("obs_b_gate")
	if gate == null or not gate.can_interact(player) or not _fits(20):
		return false
	_go(&"bruch")
	gate.interact(player)
	if not expansion.is_unlocked(&"bruch"):
		problems.append("day %d: Ostpforte not opened" % TimeManager.day)
		return false
	return true


## Stock the next tasks want (never more – no endless gathering).
func _want(item: StringName) -> int:
	match item:
		&"clay":
			var n := 1 + (1 if flags.restone else 0)
			if not shop.is_built(&"forge"):
				n += 6
			return n + 2
		&"flax":
			return 9 if shop.is_built(&"loom") and _wants_gowns() else 0
		&"herbs":
			return 3
		&"elderberries":
			return 4
		&"iron_ore":
			return 6 if _tools_open() or inv().count(&"iron_fittings") < 4 else 2
		&"workstone":
			return 3 * (1 if _master_stone_open() or flags.restone else 0) + (3 if flags.restone else 0)
		&"stone":
			var need := 12
			if not shop.is_built(&"mason"):
				need = maxi(need, 6)
			if not shop.is_built(&"forge"):
				need += 10
			return need
		&"wood":
			return 14
	return 0


func _short(item: StringName) -> bool:
	return inv().count(item) < _want(item)


func _gather_at(ids: PackedStringArray, area: StringName, item_filter: Callable) -> bool:
	var did := false
	for id: String in ids:
		var node := _gather_node(id)
		if node == null:
			problems.append("day %d: gather node %s missing" % [TimeManager.day, id])
			continue
		var data := gathering.data_of(id)
		if data == null or not item_filter.call(data.item_id):
			continue
		while node.can_interact(player) and item_filter.call(data.item_id):
			var minutes := node.minutes(player)
			if not _fits(minutes + WALK_MINUTES):
				return did
			_go(area)
			_walk(1)
			var before := TimeManager.total_minutes()
			var had := inv().count(data.item_id)
			node.interact(player)
			var got := inv().count(data.item_id) - had
			_note_minutes(data, TimeManager.total_minutes() - before)
			if got <= 0:
				problems.append("day %d: %s gave nothing (%s)" % [TimeManager.day, id, node.get_interaction_prompt(player)])
				return did
			did = true
	return did


func _note_minutes(data: GatherNodeData, minutes: int) -> void:
	if data.tool_kind == &"":
		return
	action_minutes["%s@%d" % [data.id, player.tool_tier(data.tool_kind)]] = minutes


func _gather_bruch() -> bool:
	if not expansion.is_unlocked(&"bruch"):
		return false
	return _gather_at(BRUCH_NODES, &"bruch", func(item: StringName) -> bool: return _short(item))


func _gather_quarry() -> bool:
	if not expansion.is_unlocked(&"bruch"):
		return false
	var did := false
	if not expansion.is_unlocked(&"quarry") and player.tool_tier(&"pickaxe") >= 1:
		var ids := expansion.obstacle_ids(&"quarry")
		ids.sort()
		for id: String in ids:
			var node := expansion.obstacle(id)
			if expansion.is_cleared(id) or node == null or not node.can_interact(player):
				continue
			var minutes := (Database.config(&"action_config") as ActionConfig).tool_minutes(expansion.data_of(id).minutes, player.tool_tier(&"pickaxe"))
			if not _fits(minutes + WALK_MINUTES):
				return did
			_go(&"bruch")
			var before := TimeManager.total_minutes()
			node.interact(player)
			action_minutes["boulder@%d" % player.tool_tier(&"pickaxe")] = TimeManager.total_minutes() - before
			if not expansion.is_cleared(id):
				problems.append("day %d: boulder %s not broken" % [TimeManager.day, id])
				return did
			did = true
	if not expansion.is_unlocked(&"quarry"):
		return did
	return _gather_at(QUARRY_NODES, &"bruch", func(item: StringName) -> bool: return _short(item)) or did


func _gather_schlag() -> bool:
	var did := false
	if player.tool_tier(&"axe") >= 1:
		did = _gather_at(SCHLAG_ALDERS, &"schlag", func(item: StringName) -> bool: return _short(item))
	return _gather_at(SCHLAG_HERBS, &"schlag", func(item: StringName) -> bool: return _short(item)) or did


func _gather_elder() -> bool:
	if not expansion.is_unlocked(&"elder"):
		return false
	return _gather_at(ELDER_NODES, &"elder", func(item: StringName) -> bool: return _short(item))


func _gather_node(id: String) -> GatherNode:
	var node := world.get_node_or_null("Entities/" + id) as GatherNode
	if node == null:
		node = world.find_child(id, true, false) as GatherNode
	return node


# --- build sites ------------------------------------------------------------------------------

func _build_next() -> bool:
	for id: StringName in [&"mason", &"loom", &"forge"]:
		if shop.is_built(id):
			continue
		if id == &"forge" and not shop.is_built(&"loom") and not shop.is_built(&"mason"):
			return false
		var data := Database.station(id) as StationData
		var site := world.get_node("Entities/site_" + String(id)) as BuildSite
		if site == null or not site.is_active():
			return false
		if site.block_reason(inv()) != "" or inv().count(&"coin") - data.build_coins < RESERVE_NEEDED:
			continue
		if not _fits(data.build_minutes + WALK_MINUTES):
			return false
		_go(&"hut")
		_walk()
		site.interact(player)
		if ui != null:
			var panel := ui.get_panel(&"build_site") as BuildSitePanel
			if panel != null and panel.is_open:
				panel._on_build_pressed()  # the "Bauen" button
			else:
				site.request_build()
		else:
			site.request_build()
		UIState.clear()
		if not shop.is_built(id):
			problems.append("day %d: %s not built (%s)" % [TimeManager.day, id, site.block_reason(inv())])
			return false
		return true
	return false


# --- stations ---------------------------------------------------------------------------------

func _station(id: StringName) -> Workbench:
	return world.get_node("Entities/station_" + String(id)) as Workbench


func _collect_kiln() -> bool:
	if not shop.is_built(&"forge"):
		return false
	var job := shop.job_of(&"forge")
	if job.is_empty() or not job.ready:
		return false
	var forge := _station(&"forge")
	_go(&"hut")
	var before := inv().count(&"charcoal")
	forge.interact(player)
	UIState.clear()
	if inv().count(&"charcoal") <= before:
		problems.append("day %d: kiln not collected (%s)" % [TimeManager.day, forge.get_interaction_prompt(player)])
		return false
	return true


## The kiln whenever it is free and charcoal is still needed (4 wood, keeps 1 for a marker).
func _start_kiln() -> bool:
	if not shop.is_built(&"forge") or not shop.job_of(&"forge").is_empty():
		return false
	if inv().count(&"charcoal") >= _charcoal_need() or inv().count(&"wood") < 4 + 1 or not _fits(15):
		return false
	_go(&"hut")
	return _craft5(&"forge", &"charcoal")


func _charcoal_need() -> int:
	var n := 0
	if _tools_open():
		n += 4
	n += 1  # fittings for stones
	return n


func _tools_open() -> bool:
	for kind: StringName in [&"shovel", &"axe", &"pickaxe"]:
		var goal := 2 if kind == &"pickaxe" or flags.master_tools else 1
		if player.tool_tier(kind) < goal:
			return true
	return false


## Shovel ≥ 1, axe ≥ 1, pickaxe 2 (§1.5) not reached yet.
func _chapter_tools_open() -> bool:
	var goal := shop.workshop_config().goal_tiers
	for kind: StringName in goal:
		if player.tool_tier(kind) < int(goal[kind]):
			return true
	return false


func _master_stone_open() -> bool:
	return shop.master_stones() < 1


## Bars, fittings and tools in the order of the chain (§2.4, §1.4): woodcutter's axe, iron
## shovel, master pickaxe, the chapter's master stone, then the optional master shovel / axe and
## further master stones. Each pass crafts what is possible and otherwise works towards the
## first open need (a bar from ore, fittings from a bar).
func _forge_work() -> bool:
	if not shop.is_built(&"forge"):
		return false
	var did := false
	for guard: int in 12:
		var step := false
		for recipe_id: StringName in FORGE_RECIPES_TOOLS:
			if not _tool_wanted(recipe_id):
				continue
			var r := Database.recipe(recipe_id) as RecipeData
			if CraftingSystem.can_craft(r, inv()) and _fits(r.craft_minutes + WALK_MINUTES) and _craft5(&"forge", recipe_id):
				step = true
		var need := _forge_need()
		if need == &"fittings" and inv().count(&"iron_bar") > 0 and _fits(30 + WALK_MINUTES):
			step = _craft5(&"forge", &"iron_fittings_forge") or step
		elif (need == &"fittings" or need == &"bars") and inv().count(&"iron_ore") >= 2 and inv().count(&"charcoal") >= 1 \
				and _fits(45 + WALK_MINUTES):
			step = _craft5(&"forge", &"iron_bar") or step
		if not step:
			break
		did = true
	return did


## The tool of `recipe_id` would raise its kind's tier and the strategy wants it.
func _tool_wanted(recipe_id: StringName) -> bool:
	var r := Database.recipe(recipe_id) as RecipeData
	var item := Database.item(r.output_id) as ItemData
	if player.tool_tier(item.tool_kind) >= item.tool_tier:
		return false
	return item.tool_tier < 2 or item.tool_kind == &"pickaxe" or flags.master_tools


## &"fittings" | &"bars" | &"" – what the first open forge goal lacks (charcoal / steel / ore
## come from elsewhere).
func _forge_need() -> StringName:
	var fittings := inv().count(&"iron_fittings")
	var bars := inv().count(&"iron_bar")
	# 1. Tier-1 axe and shovel: 2 fittings each.
	for kind: StringName in [&"axe", &"shovel"]:
		if player.tool_tier(kind) == 0:
			if fittings < 2:
				return &"fittings"
			fittings -= 2
	# 2. The master pickaxe: 2 bars.
	if player.tool_tier(&"pickaxe") == 1:
		if bars < 2:
			return &"bars"
		bars -= 2
	# 3. The chapter's master stone: 2 fittings.
	if _master_stone_open():
		if fittings < 2:
			return &"fittings" if bars > 0 or inv().count(&"iron_ore") >= 2 else &""
		fittings -= 2
	# 4. Master shovel / axe (optional): 2 bars each.
	if flags.master_tools:
		for kind: StringName in [&"shovel", &"axe"]:
			if player.tool_tier(kind) == 1:
				if bars < 2:
					return &"bars"
				bars -= 2
	# 5. More master stones: fittings for the next one.
	if flags.restone and fittings < 2:
		return &"fittings"
	return &""


func _wants_gowns() -> bool:
	return flags.loom_gowns and graveyard_free_plots() > 0


func graveyard_free_plots() -> int:
	var n := 0
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG:
			n += 1
	return n


## Yarn, linen and gowns for the next deliveries (the loom saves Osric's linen, §2.8).
func _loom_work() -> bool:
	if not shop.is_built(&"loom") or not _wants_gowns():
		return false
	var did := false
	var gowns := inv().count(&"burial_gown")
	while gowns < 2 and _fits(60):
		if inv().count(&"yarn") >= 2 and inv().count(&"linen") >= 1:
			if not _craft5(&"loom", &"burial_gown_loom"):
				break
			loom_gowns += 1
			gowns += 1
			did = true
		elif inv().count(&"flax") >= 2:
			if not _craft5(&"loom", &"yarn"):
				break
			did = true
		else:
			break
	return did


## Ink (2 elderberries + 1 herbs) and herb bundles for the stones and the balm.
func _workbench5() -> bool:
	var did := false
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	if inv().count(&"ink") < 2 and inv().count(&"elderberries") >= 2 and inv().count(&"herbs") >= 1 and _fits(15 + WALK_MINUTES):
		_go(&"hut")
		did = _craft(bench, &"ink") or did
	if flags.balm and graveyard_free_plots() > 0 and inv().count(&"herb_bundle") == 0 and inv().count(&"herbs") >= 3 + 1 \
			and _fits(10 + WALK_MINUTES):
		_go(&"hut")
		did = _craft(bench, &"herb_bundle") or did
	return did


## A station craft through the entity; true = the output (or the kiln job) is there.
func _craft5(station: StringName, recipe_id: StringName) -> bool:
	var node := _station(station)
	var r := Database.recipe(recipe_id) as RecipeData
	if node == null or r == null or not _time_left():
		return false
	_go(&"hut")
	_walk()
	var had := inv().count(r.output_id)
	node.interact(player)
	UIState.clear()
	node.request_craft(recipe_id)
	UIState.clear()
	if r.background:
		var ok := not shop.job_of(station).is_empty()
		if not ok:
			problems.append("day %d: %s did not start" % [TimeManager.day, recipe_id])
		return ok
	if inv().count(r.output_id) <= had and not (Database.item(r.output_id) as ItemData).tool_kind != &"":
		problems.append("day %d: %s at %s failed" % [TimeManager.day, recipe_id, station])
		return false
	return true


## Phase 4 + the loom gown before the workbench gown; with the loom only 1 linen per gown.
func _craft_essentials() -> void:
	if p5_open() and shop.is_built(&"loom") and flags.gown and inv().count(&"burial_gown") == 0 \
			and inv().count(&"yarn") >= 2 and inv().count(&"linen") >= 1:
		if _craft5(&"loom", &"burial_gown_loom"):
			loom_gowns += 1
	super._craft_essentials()


func _buy_for_today() -> void:
	if p5_open() and shop.is_built(&"loom") and flags.gown and flags.loom_gowns and inv().count(&"yarn") >= 2:
		# Loom gown: 1 linen (+ 2 yarn) instead of 3.
		var want := (_waiting_corpses() + 1) - inv().count(&"linen") - inv().count(&"burial_gown")
		for i: int in maxi(want, 0):
			if inv().count(&"coin") < 3 + RESERVE:
				break
			_buy(&"linen", 1)
		if flags.balm and inv().count(&"juniper") == 0 and inv().count(&"herb_bundle") == 0 and inv().count(&"coin") >= RESERVE + 2:
			_buy(&"juniper", 1)
		return
	super._buy_for_today()


## Osric's Phase-3/4 goods as the dialogue takes them (take_item:coin → the coin ledger).
func _buy(item: StringName, amount: int) -> bool:
	var before := inv().count(&"coin")
	if not super._buy(item, amount):
		return false
	GameState.note_coins_spent(before - inv().count(&"coin"), &"osric")
	return true


# --- designed stones ------------------------------------------------------------------------------

## Carves and sets stones while material and time allow: the master stone first (chapter), then
## the graves the strategy cares for.
func _stones() -> bool:
	if not shop.is_built(&"mason"):
		return false
	var did := false
	for round_i: int in 6:
		if not _time_left():
			break
		var pick := _next_stone()
		if pick.is_empty():
			break
		if not _fits(int(pick.minutes) + int(stone_cfg.set_minutes) + 2 * WALK_MINUTES):
			break
		var order := _carve_with_panel(pick.grave_id, pick.design)
		if order == "":
			break
		_walk()
		var plot := world.get_node_by_layout_id(pick.grave_id) as GravePlot
		if plot == null or not plot.has_stone_to_set():
			problems.append("day %d: no stone to set at %s" % [TimeManager.day, pick.grave_id])
			break
		plot.interact(player)
		UIState.clear()
		if not masonry.ready_for(pick.grave_id).is_empty():
			problems.append("day %d: stone at %s not set (%s)" % [TimeManager.day, pick.grave_id, plot.get_interaction_prompt(player)])
			break
		did = true
	return did


## {grave_id, design, minutes} – the best stone the material allows for the grave the strategy
## wants next ({} = nothing to do now).
func _next_stone() -> Dictionary:
	var candidates: Array[Dictionary] = masonry.eligible_graves()
	candidates = candidates.filter(func(e: Dictionary) -> bool: return not e.ready)
	var master_ok := player.tool_tier(&"pickaxe") >= 2 and inv().count(&"workstone") >= 3
	var need_master := _master_stone_open()
	if flags.tools_first and _tools_open() and not need_master:
		return {}
	if not need_master and not flags.restone:
		return {}
	# Order: the master stone's grave first (story corpse; mender: harvested), then nameless ones by
	# quality (lowest first).
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _grave_rank(a) < _grave_rank(b))
	for e: Dictionary in candidates:
		var shapes: Array[StringName] = []
		# Beyond the chapter's master stone the fittings go to the chapter's tools first.
		if master_ok and (need_master or (flags.restone and not _chapter_tools_open())):
			shapes.append(&"stone_master")
		if not need_master or not master_ok:
			shapes.append_array([&"stone_arch", &"stone_stele"] as Array[StringName])
		if need_master and master_ok and _grave_rank(e) >= 100:
			shapes = shapes.filter(func(s: StringName) -> bool: return s != &"stone_master")
		for shape: StringName in shapes:
			if shape != &"stone_master" and need_master and master_ok:
				continue
			if not _material_left_for(shape):
				continue
			var d := _design_for(String(e.grave_id), shape)
			if masonry.order_block_reason(String(e.grave_id), d, inv()) == "":
				return {"grave_id": String(e.grave_id), "design": d, "minutes": StoneDesignRules.minutes(d, stone_cfg)}
	return {}


## Lower = earlier. Master-stone candidates first (story corpse / harvested for the mender).
func _grave_rank(e: Dictionary) -> int:
	var grave := graveyard.get_grave(String(e.grave_id))
	var corpse := manager.get_record(grave.corpse_id)
	var rank := 1000
	var named := StoneDesign.from_dict(grave.design).inscription != &""
	if flags.robbed_first and corpse != null and not corpse.harvested.is_empty():
		rank = 0
	elif corpse != null and corpse.story_id != &"":
		rank = 10
	elif not named:
		rank = 100
	return rank + int(e.quality)


## The stone keeps the material the unbuilt stations still need (§2.1).
func _material_left_for(shape: StringName) -> bool:
	var s := Database.stone_shape(shape) as StoneShapeData
	var stone_keep := (6 if not shop.is_built(&"mason") else 0) + (10 if not shop.is_built(&"forge") else 0)
	var clay_keep := 6 if not shop.is_built(&"forge") else 0
	var fittings_keep := (2 if not shop.is_built(&"loom") else 0) + (2 if not shop.is_built(&"forge") else 0)
	for id: StringName in s.inputs:
		var keep := 0
		match id:
			&"stone":
				keep = stone_keep
			&"clay":
				keep = clay_keep
			&"iron_fittings":
				keep = fittings_keep
		if inv().count(id) - keep < int(s.inputs[id]):
			return false
	return true


func _design_for(grave_id: String, shape: StringName) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = shape
	var grave := graveyard.get_grave(grave_id)
	var corpse := manager.get_record(grave.corpse_id)
	if inv().count(&"ink") >= 1:
		d.inscription = &"i_rest"
		for ins: InscriptionData in Database.inscriptions():
			if StoneDesignRules.fits(ins, corpse):
				d.inscription = ins.id
				break
	d.gilded = d.inscription != &"" and inv().count(&"gold_leaf") >= 1 and gilded < int(flags.gold)
	var idx := graveyard.graves().find(grave)
	d.ornament = ORNAMENTS[maxi(idx, 0) % ORNAMENTS.size()]
	return d


## Through the real StoneDesignPanel: [E] at the bench, choose, "Stein hauen" (timed action →
## Stonemasonry.carve). The order id of the finished stone ("" = refused, noted as a problem).
func _carve_with_panel(grave_id: String, d: StoneDesign) -> String:
	var bench := _station(&"mason")
	if bench == null or not bench.can_interact(player):
		problems.append("day %d: mason's bench not usable" % TimeManager.day)
		return ""
	_go(&"hut")
	_walk()
	bench.interact(player)
	var panel := ui.get_panel(&"stone_design") as StoneDesignPanel if ui != null else null
	if panel == null or not panel.is_open:
		problems.append("day %d: stone panel did not open" % TimeManager.day)
		UIState.clear()
		return ""
	panel.select_grave(grave_id, false)
	panel.select_shape(d.shape)
	panel.select_inscription(d.inscription)
	panel.select_ornament(d.ornament)
	panel.set_gilded(d.gilded)
	var reason := panel.block_reason()
	if reason != "":
		problems.append("day %d: panel refuses %s for %s: %s" % [TimeManager.day, d.shape, grave_id, reason])
		UIState.clear()
		return ""
	var before := masonry.ready_stones().size()
	panel.carve()
	UIState.clear()
	var order := masonry.ready_for(grave_id)
	if masonry.ready_stones().size() != before + 1 or order.is_empty():
		problems.append("day %d: carving %s for %s failed" % [TimeManager.day, d.shape, grave_id])
		return ""
	if d.gilded:
		gilded += 1
	return String(order.id)


# --- the night: gold leaf ---------------------------------------------------------------------

## No linen at the wall once no grave is left to fill (Phase4Bot keeps 6 for the deliveries).
func _linen_wanted_at_the_wall() -> int:
	return super._linen_wanted_at_the_wall() if graveyard_free_plots() > 0 or not p5_open() else 0


func _night_at_the_wall() -> void:
	await super._night_at_the_wall()
	if not p5_open() or not trade.is_present() or int(flags.gold) <= 0:
		return
	var want := int(flags.gold) - gilded - inv().count(&"gold_leaf")
	if want <= 0 or not shop.is_built(&"mason"):
		return
	var n := mini(want, trade.stock_left(&"gold_leaf"))
	while n > 0 and inv().count(&"coin") - 6 * n < RESERVE_OPTIONAL:
		n -= 1
	if n > 0 and not trade.buy(&"gold_leaf", n, inv()):
		problems.append("day %d: gold leaf not bought" % TimeManager.day)
	UIState.clear()


# --- record ---------------------------------------------------------------------------------

func record_day(day: int) -> void:
	super.record_day(day)
	var r: Dictionary = rows.back()
	var tiers := shop.tiers()
	var named := 0
	for g: GraveRecord in graveyard.graves():
		if StoneDesign.from_dict(g.design).inscription != &"":
			named += 1
	r.merge({
		"morning_coins": morning_coins, "spent_day": _day_spent.duplicate(), "stations": shop.built().size(),
		"tiers": "%d/%d/%d" % [int(tiers.get(&"shovel", 0)), int(tiers.get(&"axe", 0)), int(tiers.get(&"pickaxe", 0))],
		"stones_set": GameState.get_stat(&"stones_set"), "masters": shop.master_stones(), "named": named,
		"content": _content_ghosts(), "chapter5": GameState.has_flag(&"names_in_stone_complete"),
		"open": shop.is_open(), "crafted": GameState.get_stat(&"crafted"),
	})


func _content_ghosts() -> int:
	var n := 0
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED and ghosts.mood_of(g.id) == GhostMood.CONTENT:
			n += 1
	return n


## "| day | … |" rows for docs/reviews/phase5_wip/qa_playthrough.md.
func table_p5() -> String:
	var lines := PackedStringArray(["| Tag | Münzen früh | Ausgaben (Zweck) | Münzen abends | Gräber | Qualität | Ruf | Stationen | Werkzeug S/A/P | Steine | Meister | mit Namen | zufrieden | Kapitel |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		var parts := PackedStringArray()
		var spent_day: Dictionary = r.get("spent_day", {})
		for reason: Variant in spent_day:
			parts.append("%s %d" % [reason, int(spent_day[reason])])
		lines.append("| %d | %d | %s | %d | %d | %d | %d | %d | %s | %d | %d | %d | %d | %s |" % [r.day, int(r.get("morning_coins", 0)),
				", ".join(parts) if not parts.is_empty() else "–", r.coins, r.marked, r.quality, r.rep, int(r.get("stations", 0)),
				r.get("tiers", "–"), int(r.get("stones_set", 0)), int(r.get("masters", 0)), int(r.get("named", 0)),
				int(r.get("content", 0)), "✓" if r.get("chapter5", false) else ("offen" if r.get("open", false) else "–")])
	return "\n".join(lines)


## One line: the ledger of the run.
func ledger_text() -> String:
	var spent_parts := PackedStringArray()
	var total := 0
	for reason: Variant in spent_by:
		spent_parts.append("%s %d" % [reason, int(spent_by[reason])])
		total += int(spent_by[reason])
	var in_parts := PackedStringArray()
	var in_total := 0
	for source: Variant in income:
		in_parts.append("%s %d" % [source, int(income[source])])
		in_total += int(income[source])
	return "start %d · income %d (%s) · spent %d (%s) · Phase 5 spent %d · end %d · lowest morning %d" % [start_coins,
			in_total, ", ".join(in_parts), total, ", ".join(spent_parts), spent_p5, inv().count(&"coin"), lowest_morning]


func total_spent() -> int:
	var total := 0
	for reason: Variant in spent_by:
		total += int(spent_by[reason])
	return total


func total_income() -> int:
	var total := 0
	for source: Variant in income:
		total += int(income[source])
	return total


func _on_coins_spent(amount: int, reason: StringName) -> void:
	spent_by[reason] = int(spent_by.get(reason, 0)) + amount
	_day_spent[reason] = int(_day_spent.get(reason, 0)) + amount
	if shop != null and is_instance_valid(shop) and shop.is_open():
		spent_p5 += amount


func _on_trader_trade(coins: int, _given: Dictionary, _taken: Dictionary) -> void:
	if coins > 0:
		income.ilse = int(income.ilse) + coins


func _on_gathered(_node_id: String, item_id: StringName, amount: int) -> void:
	gathered[item_id] = int(gathered.get(item_id, 0)) + amount


func _on_tier(kind: StringName, tier: int) -> void:
	var key := "%s%d" % [kind, tier]
	if not tier_days.has(key):
		tier_days[key] = TimeManager.day


func _on_stone_set(grave_id: String, shape_id: StringName, quality: int) -> void:
	stones_set.append({"day": TimeManager.day, "grave": grave_id, "shape": shape_id, "quality": quality})
	if GameState.has_flag(&"names_in_stone_complete") and chapter5_day < 0:
		chapter5_day = TimeManager.day


func _on_chapter(chapter_id: StringName) -> void:
	super._on_chapter(chapter_id)
	if chapter_id == &"names_in_stone" and chapter5_day < 0:
		chapter5_day = TimeManager.day


func _on_payment(coins: int, reason: String) -> void:
	super._on_payment(coins, reason)
	if reason == Reputation.REASON_STIPEND:
		income.stipend = int(income.stipend) + coins
	elif reason.begins_with(Graveyard.PAYMENT_REASON.split("%")[0]):
		income.burial = int(income.burial) + coins
	else:
		income.gift = int(income.gift) + coins
