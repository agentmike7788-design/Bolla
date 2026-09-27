class_name Phase3Bot
extends RefCounted
## QA playthrough bot (docs/PHASE3_DESIGN.md §10 "Playthrough-Bot", W3): drives the real
## graveyard world through the entities' interact() / request_*() and the systems' public API
## with Player.instant_actions, one in-game day per run_day(). Walking is approximated by
## WALK_MINUTES per task. Purchases at Osric's cart mirror data/dialogue/carter.tres
## (take_item coin → give_item), because the bot does not click through dialogue panels.
## Strategies (flags): see STRATEGIES. Used by tests/integration/test_phase3_playthrough.gd.

const WALK_MINUTES := 3
## The bot stops starting work after this minute and goes to bed.
const EVENING := 1290
## 22:15 – the ghosts have faded in (21:30 + 30 min).
const LISTEN_MINUTE := 1335
const PRICE := {&"linen": 3, &"iron_fittings": 3, &"seeds": 1}
## Coins kept back for tomorrow's shroud (2 linen).
const RESERVE := 6

const STRATEGIES := {
	&"diligent": {"tend": true, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": true, "listen": true, "upgrade": true, "save_load": false, "sleep_minute": 1350},
	&"sloppy": {"tend": false, "take_valuables": true, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": false, "listen": false, "upgrade": false, "save_load": false, "sleep_minute": 1350},
	&"neglectful": {"tend": false, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": true, "listen": true, "upgrade": true, "save_load": false, "sleep_minute": 1350},
	&"hoarder": {"tend": true, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": false, "listen": false, "upgrade": true, "save_load": false, "sleep_minute": 1350},
	&"save_load": {"tend": true, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": true, "listen": true, "upgrade": true, "save_load": true, "sleep_minute": 1350},
	&"early_sleeper": {"tend": true, "take_valuables": false, "shroud": true, "examine": true, "stone": true,
			"clear": true, "decor": true, "listen": false, "upgrade": true, "save_load": false, "sleep_minute": 1080},
}

var strategy: StringName
var flags: Dictionary
var tree: SceneTree
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var manager: CorpseManager
var expansion: ExpansionManager
var clean: CleanlinessManager
var decorations: DecorationManager
var score: CemeteryScore
var rep: Reputation
var ghosts: GhostManager
## One row per finished day (see record_day).
var rows: Array[Dictionary] = []
## Coins spent at the cart / received from ghosts over the whole run.
var spent: int = 0
var gifts: int = 0
var problems: PackedStringArray = []


func _init(p_strategy: StringName, p_tree: SceneTree) -> void:
	strategy = p_strategy
	flags = STRATEGIES[p_strategy]
	tree = p_tree


func bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	manager = world.corpse_manager
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	clean = world.get_node("Systems/Cleanliness") as CleanlinessManager
	decorations = world.get_node("Systems/Decorations") as DecorationManager
	score = world.get_node("Systems/CemeteryScore") as CemeteryScore
	rep = world.get_node("Systems/Reputation") as Reputation
	ghosts = world.get_node("Systems/Ghosts") as GhostManager
	TimeManager.running = false


func inv() -> Inventory:
	return player.inventory


# --- one day ------------------------------------------------------------------------------

## Morning (06:00, or the new game's 06:30) → evening → bed. Coroutine (save / load).
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
	if flags.listen:
		_listen_to_ghosts()
	await _sleep()


func _leave_hut() -> void:
	if player.in_interior:
		var door := world.get_node_by_layout_id("hut_door") as HutDoor
		HutPortal.arrive(player, door.exit_transform(), false)


func _gather() -> void:
	for id: String in ["res_wood", "res_stone"]:
		var node := world.get_node_by_layout_id(id) as ResourceNode
		_walk()
		while node != null and node.can_interact(player):
			node.interact(player)


func _walk(minutes: int = WALK_MINUTES) -> void:
	TimeManager.advance(minutes)


func _wait_until(minute: int) -> void:
	if TimeManager.minute_of_day < minute:
		TimeManager.advance(minute - TimeManager.minute_of_day)


func _time_left() -> bool:
	return TimeManager.minute_of_day < EVENING and TimeManager.minute_of_day >= 300


## Osric's cart (07:40–10:00, 18:30–21:00): linen for tomorrow, iron / seeds from day 2.
func _buy(item: StringName, amount: int) -> bool:
	var cost := int(PRICE[item]) * amount
	if amount <= 0 or inv().count(&"coin") < cost or not inv().can_add(item, amount):
		return false
	inv().remove_item(&"coin", cost)
	inv().add_item(item, amount)
	spent += cost
	return true


func _buy_for_today() -> void:
	if flags.shroud:
		var want := 2 * (_waiting_corpses() + 1) - inv().count(&"linen") - 2 * inv().count(&"shroud")
		for i: int in maxi(want, 0):
			_buy(&"linen", 1)


func _waiting_corpses() -> int:
	var n := 0
	for r: CorpseRecord in manager.records():
		if r.location != CorpseRecord.LOCATION_BURIED and not r.shrouded:
			n += 1
	return n


## Gravestone (4 stone, 1 wood) or the wooden cross, the shroud, the rake.
func _craft_essentials() -> void:
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	if flags.shroud and inv().count(&"shroud") == 0 and inv().count(&"linen") >= 2:
		_craft(bench, &"shroud")
	var markers := inv().count(&"gravestone_simple") + inv().count(&"wooden_cross")
	if markers == 0:
		if flags.stone and inv().count(&"stone") >= 4 and inv().count(&"wood") >= 1:
			_craft(bench, &"gravestone_simple")
		elif inv().count(&"wood") >= 3:
			_craft(bench, &"wooden_cross")
	if flags.tend and not inv().has(&"rake") and inv().count(&"wood") >= 3 + 1 and TimeManager.day >= 2:
		_craft(bench, &"rake")


func _craft(bench: Workbench, recipe: StringName) -> bool:
	if not _time_left():
		return false
	var r := Database.recipe(recipe) as RecipeData
	if r == null or not CraftingSystem.can_craft(r, inv()):
		return false
	_walk()
	bench.interact(player)
	UIState.clear()
	bench.request_craft(recipe)
	return true


## Every corpse at the bier / on the ground / on the table: table → examine → valuables →
## shroud → dig a free plot → bury → marker.
func _handle_corpses() -> void:
	for record: CorpseRecord in manager.records():
		if record.location == CorpseRecord.LOCATION_BURIED or not _time_left():
			continue
		_bury(record)


func _bury(record: CorpseRecord) -> void:
	var plot := _free_plot()
	if plot == null:
		problems.append("day %d: no free plot for %s" % [TimeManager.day, record.id])
		return
	var table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	if record.location != CorpseRecord.LOCATION_TABLE:
		_walk()
		var node := manager.get_corpse_node(record.id)
		node.interact(player)
		_walk()
		table.interact(player)
	else:
		table.interact(player)
		UIState.clear()
	UIState.clear()
	if flags.examine and not record.examined:
		table.request_examine()
	if record.needs_valuables_decision():
		table.decide_valuables(flags.take_valuables)
	if flags.shroud and not record.shrouded:
		if inv().count(&"shroud") == 0:
			_craft_essentials()
		if inv().count(&"shroud") > 0:
			table.interact(player)
			UIState.clear()
			table.request_shroud()
	# Marker ready before the pit is dug.
	if inv().count(&"gravestone_simple") + inv().count(&"wooden_cross") == 0:
		_craft_essentials()
	_walk()
	plot.interact(player)  # dig
	if graveyard.get_grave(plot.grave_id).state != GraveRecord.State.DUG:
		problems.append("day %d: could not dig %s" % [TimeManager.day, plot.grave_id])
		return
	table.interact(player)
	UIState.clear()
	table.request_pick_up()
	_walk()
	plot.interact(player)  # bury
	if graveyard.get_grave(plot.grave_id).state != GraveRecord.State.FILLED:
		problems.append("day %d: could not bury in %s" % [TimeManager.day, plot.grave_id])
		return
	if inv().count(&"gravestone_simple") > 0 and inv().count(&"wooden_cross") > 0:
		plot.interact(player)
		UIState.clear()
		plot.request_marker(&"gravestone_simple")
	else:
		plot.interact(player)
	if graveyard.get_grave(plot.grave_id).state != GraveRecord.State.MARKED:
		problems.append("day %d: no marker on %s (%s, %s)" % [TimeManager.day, plot.grave_id, TimeManager.format_clock(), str(inv().get_slots())])


func _free_plot() -> GravePlot:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG:
			var plot := world.get_node_by_layout_id(g.id) as GravePlot
			if plot != null and g.state == GraveRecord.State.EMPTY:
				return plot
	return null


func _upgrade_markers() -> void:
	for g: GraveRecord in graveyard.graves():
		if g.state != GraveRecord.State.MARKED or g.marker_id != &"wooden_cross":
			continue
		if inv().count(&"gravestone_simple") == 0:
			var bench := world.get_node_by_layout_id("workbench") as Workbench
			# Only with stone to spare beyond tomorrow's gravestone.
			if inv().count(&"stone") >= 8 and inv().count(&"wood") >= 1:
				_craft(bench, &"gravestone_simple")
		var plot := world.get_node_by_layout_id(g.id) as GravePlot
		if inv().count(&"gravestone_simple") > 0 and plot.can_interact(player):
			_walk()
			plot.interact(player)


## Clears every obstacle it can afford (east first, then north once workable). Keeps the wood
## for tomorrow's marker and the coins for tomorrow's shroud.
func _clear_obstacles() -> void:
	for section: StringName in [&"east", &"north"]:
		if expansion.is_unlocked(section) or expansion.block_reason(section) != "":
			continue
		# The hedge is the access of the Birkenhang – clear it first.
		var ids := expansion.obstacle_ids(section)
		ids.sort()
		if section == &"north" and ids.has("obs_n_hedge"):
			ids.remove_at(ids.find("obs_n_hedge"))
			ids.insert(0, "obs_n_hedge")
		for id: String in ids:
			if not _time_left() or expansion.is_cleared(id):
				continue
			var node := expansion.obstacle(id)
			var data := expansion.data_of(id)
			if data.cost.has(&"iron_fittings") and inv().count(&"iron_fittings") < int(data.cost[&"iron_fittings"]):
				if TimeManager.day < 2 or inv().count(&"coin") - 3 < RESERVE:
					continue
				_buy(&"iron_fittings", int(data.cost[&"iron_fittings"]) - inv().count(&"iron_fittings"))
			if data.cost.has(&"wood") and inv().count(&"wood") - int(data.cost[&"wood"]) < 1:
				continue
			if node.can_interact(player):
				_walk()
				node.interact(player)


func _tend() -> void:
	for id: String in clean.spot_ids():
		if not _time_left():
			return
		if clean.level(id) < 1:
			continue
		var spot := world.get_node("Entities/" + id) as DirtSpot
		if spot != null and spot.can_interact(player):
			_walk(2)
			spot.interact(player)


# --- decor ----------------------------------------------------------------------------------

## A vase next to every marked grave, two lanterns per section, a wooden bench per section,
## flower beds with what is left – within the coins / wood / stone to spare.
func _decorate() -> void:
	if TimeManager.day < 2:
		return
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	for g: GraveRecord in graveyard.graves():
		if g.state != GraveRecord.State.MARKED or not _time_left():
			continue
		var plot := world.get_node_by_layout_id(g.id) as Node3D
		var centre := Vector2(plot.global_position.x, plot.global_position.z)
		if ghosts.mood_info(g.id).get("decor_bonus", 0) >= 1:
			continue
		if inv().count(&"decor_grave_vase") == 0:
			if inv().count(&"stone") < 5 or (inv().count(&"seeds") == 0 and not _buy(&"seeds", 1)):
				continue
			_craft(bench, &"decor_grave_vase")
		_place_near(&"decor_grave_vase", centre, graveyard.section_of(g.id))
	for section: StringName in [&"yard", &"east", &"north"]:
		if not expansion.is_unlocked(section):
			continue
		var marked := _marked_in(section)
		if marked.is_empty():
			continue
		var by := decorations.score_by_section()
		var s := expansion.section(section)
		var entry: Dictionary = by.get(s.order, {"raw": 0, "cap": s.decor_cap})
		if int(entry.raw) >= int(entry.cap):
			continue
		if _count_in(&"decor_lantern", s.order) < 2 and decorations.count_of(&"decor_lantern") < 6:
			if inv().count(&"decor_lantern") == 0 and inv().count(&"wood") >= 3:
				if inv().count(&"iron_fittings") > 0 or (inv().count(&"coin") - 3 >= RESERVE and _buy(&"iron_fittings", 1)):
					_craft(bench, &"decor_lantern")
			if inv().count(&"decor_lantern") > 0:
				_place_near(&"decor_lantern", _centre_of(marked[_count_in(&"decor_lantern", s.order) % marked.size()]), section)
		if _count_in(&"decor_bench_wood", s.order) < 1:
			if inv().count(&"decor_bench_wood") == 0 and inv().count(&"wood") >= 5:
				_craft(bench, &"decor_bench_wood")
			if inv().count(&"decor_bench_wood") > 0:
				_place_near(&"decor_bench_wood", _centre_of(marked[0]) + Vector2(0.0, 3.2), section)


func _marked_in(section: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in graveyard.plots_in_section(section):
		if graveyard.get_grave(id).state == GraveRecord.State.MARKED:
			out.append(id)
	return out


func _centre_of(grave_id: String) -> Vector2:
	var plot := world.get_node_by_layout_id(grave_id) as Node3D
	return Vector2(plot.global_position.x, plot.global_position.z)


func _count_in(decor_id: StringName, order: int) -> int:
	var n := 0
	for p: DecorPlacement in decorations.placements():
		if p.decor_id == decor_id and decorations.mask.section_at(p.cell) == order:
			n += 1
	return n


## The valid cell nearest to `target` (within 4 m) in `section`; places it (5 min).
func _place_near(decor_id: StringName, target: Vector2, section: StringName) -> String:
	var mask := decorations.mask
	var s := expansion.section(section)
	var c0 := mask.world_to_cell(target)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dz: int in range(-8, 9):
		for dx: int in range(-8, 9):
			var c := c0 + Vector2i(dx, dz)
			if mask.section_at(c) != s.order:
				continue
			var d := (mask.cell_to_world(c) - target).length()
			if d >= best_d:
				continue
			if decorations.can_place(decor_id, c, 0, inv(), player) == BuildGrid.REASON_OK:
				best = c
				best_d = d
	if best.x < 0:
		return ""
	_walk()
	return _place_with_build_mode(decor_id, best)


## Through BuildMode like a player: stand 2.5 m in front of the spot, enter, select, point the
## mouse at the cell (camera ray), left click (5 min timed action).
func _place_with_build_mode(decor_id: StringName, anchor: Vector2i) -> String:
	var mask := decorations.mask
	var size := BuildGrid.rotated_size(decorations.decor(decor_id).footprint, 0)
	var cursor := anchor + Vector2i((size.x - 1) / 2, (size.y - 1) / 2)
	var at := mask.cell_to_world(cursor)
	player.global_position = Vector3(at.x, world.ground_height(at + Vector2(0, 2.5)), at.y + 2.5)
	var build := world.get_node("Systems/BuildMode") as BuildMode
	if not build.enter():
		problems.append("day %d: build mode refused" % TimeManager.day)
		return ""
	build.select(decor_id)
	build.rotation_step = 0
	var cam := tree.root.get_viewport().get_camera_3d()
	var rig := world.get_node_or_null("CameraRig")
	if rig != null and rig.has_method(&"snap"):
		rig.call(&"snap")
	build.mouse_active = true
	build.mouse_position = cam.unproject_position(Vector3(at.x, 0.0, at.y))
	var before := decorations.placements().size()
	var reason := build.cursor_reason()
	if build.anchor_cell() != anchor or reason != BuildGrid.REASON_OK:
		problems.append("day %d: mouse cursor %s (want %s): %s" % [TimeManager.day, build.anchor_cell(), anchor, reason])
		build.exit()
		return ""
	build.confirm_place()
	build.exit()
	if decorations.placements().size() != before + 1:
		problems.append("day %d: build mode did not place %s" % [TimeManager.day, decor_id])
		return ""
	return decorations.placement_at(anchor).uid


# --- night ----------------------------------------------------------------------------------

## Walks to every walking ghost and listens through its node ([E] on the Ghost).
func _listen_to_ghosts() -> void:
	_wait_until(LISTEN_MINUTE)
	for id: String in ghosts.eligible_graves():
		var plot := world.get_node_by_layout_id(id) as Node3D
		player.global_position = plot.global_position + Vector3(0.0, 0.0, 1.5)
		ghosts.reselect()
		ghosts.update_visuals(TimeManager.get_minute_f())
		var ghost: Ghost = null
		for g: Ghost in ghosts.active_ghosts():
			if g.grave_id == id:
				ghost = g
		if ghost == null or not ghost.can_interact(player):
			problems.append("day %d: no ghost to listen to at %s" % [TimeManager.day, id])
			continue
		var before := inv().count(&"coin")
		ghost.interact(player)
		if not ghost.is_speaking():
			problems.append("day %d: ghost %s said nothing" % [TimeManager.day, id])
		gifts += inv().count(&"coin") - before


func _sleep() -> void:
	_wait_until(int(flags.sleep_minute))
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var interior := tree.get_first_node_in_group(HutInterior.GROUP) as HutInterior
	if door.can_interact(player):
		HutPortal.arrive(player, interior.spawn_transform(), true)
	var bed := interior.get_node("Entities/bed") as Bed
	if not bed.can_interact(player):
		problems.append("day %d: cannot sleep (%s)" % [TimeManager.day, bed.get_interaction_prompt(player)])
		return
	var ended := TimeManager.day
	bed.interact(player)
	UIState.clear()
	record_day(ended)
	if flags.save_load:
		var err: Error = await SaveManager.load_game(SaveManager.AUTOSAVE_SLOT)
		if err != OK:
			problems.append("day %d: autosave load failed %s" % [ended, error_string(err)])
		bind()


func record_day(day: int) -> void:
	var marked := 0
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			marked += 1
	var b := score.breakdown()
	rows.append({
		"day": day, "marked": marked, "graves": b.graves, "decor": b.decor, "dirt": b.dirt,
		"quality": b.total, "rating": b.rating, "rep": rep.value(), "tier": rep.tier(),
		"coins": inv().count(&"coin"), "east": expansion.is_unlocked(&"east"),
		"north": expansion.is_unlocked(&"north"), "missed": GameState.get_stat(&"missed_deliveries"),
		"moods": ghosts.heard_moods(),
	})


## "| day | … |" rows for docs/reviews/phase3_wip/qa_playthrough.md.
func table() -> String:
	var lines := PackedStringArray(["| Tag | Gräber | Q Gräber | Zier | Pflege | Qualität | Stufe | Ruf | Ruf-Stufe | Münzen | Ost | Nord |",
			"|---|---|---|---|---|---|---|---|---|---|---|---|"])
	for r: Dictionary in rows:
		lines.append("| %d | %d | %d | %d | −%d | %d | %s | %d | %s | %d | %s | %s |" % [r.day, r.marked, r.graves, r.decor,
				r.dirt, r.quality, CemeteryRating.label(r.rating), r.rep, ReputationRules.label(r.tier), r.coins,
				"✓" if r.east else "–", "✓" if r.north else "–"])
	return "\n".join(lines)
