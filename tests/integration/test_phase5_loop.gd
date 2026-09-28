extends TestCase
## W-Welt (docs/PHASE5_DESIGN.md §10 test_phase5_loop): the Phase-5 chain on the real world through
## SaveManager, from the Phase-4 end state (v3 fixture slot_p4_day20_reverent) to the chapter
## "Namen in Stein" – entities and systems as a player uses them (instant timed actions, the real
## dialogue runner for Osric, the real gather / build-site / station / grave entities):
## workshop_open → Osric: licence → walk (real movement) to the Ostpforte, unlock it → clay, flax,
## herbs → back to the hut → mason's bench → elderberries → ink → a stele with an inscription set on
## a MARKED grave (quality up, no payment) → pickaxe → loom, forge → kiln over night → boulders →
## ore → bar → fittings → woodcutter's axe → an alder felled (stump, shoots after 2 days, tree after
## 5) → steel rod → master pickaxe → workstone → master stone gilded with an ornament → chapter.
## collect_state() is identical after save_game / load_game at four moments: kiln burning, two
## finished stones in the rack, an alder in the shoot stage, after the chapter.
## Plus: the workyard decor of a Phase-4 save is cleared into the hut chest (§5.2 step 5).

const TIMEOUT := 420.0
const SLOT := 93
const FIXTURE := "slot_p4_day20_reverent"
const INTERIOR_FIXTURE := "slot_p4_interior_chest_tools"
## Walk from the hut door to Am Bruch (the lane between the old graves, the Ostwiese passage, the
## Ostpforte) and back – driven with the move actions like a player.
const TO_BRUCH: Array[Vector2] = [Vector2(-5.2, -3.4), Vector2(-2.2, -2.6), Vector2(0.8, -1.5), Vector2(10.3, -1.6),
		Vector2(11.5, -2.2), Vector2(13.0, -2.2), Vector2(20.4, -0.2), Vector2(22.4, 0.0), Vector2(25.5, 0.0)]
const ARRIVE := 0.35

var saves_dir := TestCase.user_dir("test_saves_p5_loop")
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var expansion: ExpansionManager
var shop: Workshop
var gathering: GatherManager
var masonry: Stonemasonry
var trade: NightTrade
var chapters: Array = []
var spent: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	spent.clear()
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.coins_spent.connect(_on_spent)


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.coins_spent.disconnect(_on_spent)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase5_loop_to_names_in_stone_with_round_trips() -> void:
	assert_eq(Phase5Fixtures.install_save_v3(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world == null:
		return
	var inv := player.inventory
	# --- B1: workshop open at once (cemetery_complete), Osric's licence, the Ostpforte -----------
	assert_true(shop.is_open(), "workshop_open right after loading the Phase-4 end state")
	var coins := inv.count(&"coin")
	_osric([&"p5_intro", &"p5_license", &"p5_license_bought"])
	assert_true(GameState.has_flag(&"bruch_license"), "the quarry licence")
	assert_eq(inv.count(&"coin"), coins - 20)
	await _walk(TO_BRUCH.slice(0, 7))
	var gate := expansion.obstacle("obs_b_gate")
	assert_true(gate.can_interact(player), "the Ostpforte can be unlocked")
	gate.interact(player)
	assert_true(expansion.is_unlocked(&"bruch"), "Am Bruch open")
	await _walk(TO_BRUCH.slice(7))
	assert_true(_flat_distance(player.global_position, _waypoint(&"tp_bruch")) < 1.0, "walked to Am Bruch")
	for i: int in 3:
		_gather("gather_clay_1")
	assert_eq(inv.count(&"clay"), 6, "3 × 2 clay")
	assert_eq(_node("gather_clay_1").get_interaction_prompt(player).begins_with("Abgeerntet"), true, "clay pit empty")
	for k: int in [1, 2, 3]:
		_gather("gather_flax_%d" % k)
	assert_eq(inv.count(&"flax"), 9)
	_gather("gather_herbs_1")
	_gather("gather_herbs_1")
	var back := TO_BRUCH.duplicate()
	back.reverse()
	await _walk(back)
	# --- the mason's bench on its build site ----------------------------------------------------
	_stock({&"stone": 6, &"wood": 3})
	_build(&"mason")
	assert_true(shop.is_built(&"mason"))
	assert_true((world.get_node("Entities/station_mason") as Node3D).visible, "the bench stands")
	# Ink: elderberries (a Holunderwinkel bush) + herbs at the workbench.
	_gather("gather_elder_1")
	assert_eq(inv.count(&"elderberries"), 2)
	_craft("workbench", &"ink")
	assert_eq(inv.count(&"ink"), 2, "2 ink")
	# A stele with an inscription for a grave with a plain stone: quality up, no payment.
	var grave_id := _grave_with_marker()
	var grave := graveyard.get_grave(grave_id)
	var quality := grave.quality
	coins = inv.count(&"coin")
	_stock({&"stone": 4})
	var order := _carve(grave_id, [&"stone_stele", &"i_rest", &"", false])
	assert_ne(order, "", "stele carved")
	assert_eq((world.get_node("Entities/station_mason/StoneRack").get("shown") as PackedStringArray), PackedStringArray([order]), "in the rack")
	_set_stone(grave_id)
	assert_true(graveyard.get_grave(grave_id).quality > quality, "quality %d → %d" % [quality, graveyard.get_grave(grave_id).quality])
	assert_eq(inv.count(&"coin"), coins, "a MARKED grave pays nothing again")
	assert_eq(StoneDesign.from_dict(graveyard.get_grave(grave_id).design).shape, &"stone_stele")
	# --- B2/B3: pickaxe, fittings, loom and forge -----------------------------------------------
	_osric([&"p5_shop", &"p5_shop_pickaxe"])
	assert_eq(player.tool_tier(&"pickaxe"), 1, "the old pickaxe on the belt")
	_osric([&"p5_shop", "Vier Eisenbeschläge"])
	_stock({&"wood": 8})
	_build(&"loom")
	_stock({&"stone": 10, &"clay": 6, &"iron_fittings": 2})
	_build(&"forge")
	assert_eq(shop.built(), [&"mason", &"loom", &"forge"] as Array[StringName])
	_stock({&"wood": 4})
	_craft("forge", &"charcoal")
	var kiln := world.get_node("Entities/station_forge/Kiln")
	assert_true(bool(kiln.get("burning")), "the kiln burns")
	await _round_trip("kiln burning")
	inv = player.inventory
	assert_false(shop.job_of(&"forge").is_empty(), "the kiln job survives the load")
	assert_true(bool(world.get_node("Entities/station_forge/Kiln").get("burning")), "still burning after the load")
	# --- B4: next morning – charcoal, boulders, ore ----------------------------------------------
	_next_morning()
	var forge := world.get_node("Entities/station_forge") as Workbench
	assert_eq(forge.get_interaction_prompt(player), "[E] Holzkohle holen (3)")
	forge.interact(player)
	assert_eq(inv.count(&"charcoal"), 3)
	for k: int in [1, 2, 3]:
		var boulder := expansion.obstacle("obs_q_boulder_%d" % k)
		assert_true(boulder.can_interact(player), "boulder %d with the pickaxe" % k)
		boulder.interact(player)
	assert_true(expansion.is_unlocked(&"quarry"), "the quarry is free")
	for i: int in 3:
		_gather("gather_ore_1")
	assert_eq(inv.count(&"iron_ore"), 3)
	_craft("forge", &"iron_bar")
	_craft("forge", &"iron_fittings_forge")
	_stock({&"wood": 1})
	_craft("forge", &"axe_iron")
	assert_eq(player.tool_tier(&"axe"), 1, "woodcutter's axe")
	# An alder felled: stump now, shoots after 2 days, a tree again after 5.
	_gather("gather_alder_1")
	assert_eq(gathering.stage("gather_alder_1"), &"empty", "a stump")
	assert_eq(GameState.get_stat(&"trees_felled"), 1)
	# --- B5: more ore (next day), bars, fittings, iron shovel, steel rod, master pickaxe --------
	_next_morning()
	_next_morning()
	assert_eq(gathering.stage("gather_alder_1"), &"regrowing", "shoots after 2 days")
	assert_true((_node("gather_alder_1").get_node("Regrow") as Node3D).visible, "the sapling model")
	await _round_trip("alder in the shoot stage")
	inv = player.inventory
	assert_eq(gathering.stage("gather_alder_1"), &"regrowing")
	for i: int in 3:
		_gather("gather_ore_1")
	_next_morning()
	for i: int in 3:
		_gather("gather_ore_1")
	_stock({&"wood": 4})
	_craft("forge", &"charcoal")
	_next_morning()
	forge = world.get_node("Entities/station_forge") as Workbench
	forge.interact(player)
	for i: int in 3:
		_craft("forge", &"iron_bar")
	_craft("forge", &"iron_fittings_forge")
	_stock({&"wood": 1})
	_craft("forge", &"shovel_iron")
	assert_eq(player.tool_tier(&"shovel"), 1, "iron shovel")
	_osric([&"p5_shop", &"p5_shop_steel"])
	_craft("forge", &"pickaxe_master")
	assert_eq(player.tool_tier(&"pickaxe"), 2, "master pickaxe")
	# --- B6: workstone, gold leaf at night, two stones in the rack --------------------------------
	for i: int in 2:
		_gather("gather_workstone_1")
	_gather("gather_workstone_2")
	assert_eq(inv.count(&"workstone"), 3)
	_until(TimeManager.day, 1410)
	await wait_frames(2)
	(world.get_node_by_layout_id("npc_trader") as Npc).refresh()
	await wait_frames(1)
	assert_true(trade.is_present(), "Ilse at the wall")
	assert_true(trade.buy(&"gold_leaf", 1, inv), "gold leaf from Ilse")
	_next_morning()
	var story_grave := _grave_with_marker([grave_id])
	_gather("gather_elder_2")
	_gather("gather_herbs_2")
	_craft("workbench", &"ink")
	_stock({&"stone": 2, &"clay": 1, &"iron_fittings": 2})
	var master := _carve(story_grave, [&"stone_master", &"i_rest", &"orn_elder", true])
	assert_ne(master, "", "master stone carved")
	var second_grave := _grave_with_marker([grave_id, story_grave])
	_stock({&"stone": 5, &"clay": 1})
	var arch := _carve(second_grave, [&"stone_arch", &"i_rest", &"orn_ivy", false])
	assert_ne(arch, "", "round-arch stone carved")
	assert_eq(masonry.ready_stones().size(), 2, "two finished stones in the rack")
	await _round_trip("two stones in the rack")
	inv = player.inventory
	assert_eq((world.get_node("Entities/station_mason/StoneRack").get("shown") as PackedStringArray).size(), 2, "both shown after the load")
	assert_eq(chapters, [], "no chapter before the master stone is set")
	_set_stone(second_grave)
	_set_stone(story_grave)
	# --- B7: the chapter ---------------------------------------------------------------------------
	assert_eq(chapters, [&"names_in_stone"], "chapter names_in_stone once")
	assert_true(GameState.has_flag(&"names_in_stone_complete"))
	var d := StoneDesign.from_dict(graveyard.get_grave(story_grave).design)
	assert_eq([d.shape, d.ornament, d.gilded], [&"stone_master", &"orn_elder", true])
	assert_false(d.text.is_empty(), "the name carved in stone")
	var plot := world.get_node_by_layout_id(story_grave) as Node3D
	assert_not_null(plot.find_child("Inscription", true, false), "inscription shown at the grave")
	# Five days after the felling the alder is a tree again.
	_next_morning()
	assert_eq(gathering.stage("gather_alder_1"), &"full", "a tree again after 5 days")
	UIState.clear()
	await _round_trip("after the chapter")
	assert_true(GameState.has_flag(&"names_in_stone_complete"))
	assert_true(spent.any(func(e: Array) -> bool: return e[1] == &"build"), "build costs in the ledger")


## §5.2 step 5: decor standing on the workyard of a Phase-4 save is cleared on the first load into
## the hut chest (the grave vase next to the mason's site), once, with the note; decor elsewhere stays.
func test_workyard_decor_of_a_phase4_save_is_cleared_into_the_chest() -> void:
	assert_eq(Phase5Fixtures.install_save_v3(INTERIOR_FIXTURE, saves_dir, SLOT), OK)
	var notes: Array[String] = []
	var on_note := func(text: String, _kind: StringName) -> void: notes.append(text)
	EventBus.notification_requested.connect(on_note)
	var err: Error = await SaveManager.load_game(SLOT)
	EventBus.notification_requested.disconnect(on_note)
	assert_eq(err, OK)
	_bind()
	var decor := world.get_node("Systems/Decorations") as DecorationManager
	var in_yard := 0
	for p: DecorPlacement in decor.placements():
		var w := decor.mask.cell_to_world(p.cell)
		for r: Rect2 in shop.workyard_rects:
			if r.has_point(w):
				in_yard += 1
	assert_eq(in_yard, 0, "no decor left on the workyard")
	assert_true(GameState.has_flag(&"workyard_cleared"))
	assert_true(Workshop.TEXT_EVICTED in notes, "the note about the chest")
	assert_eq(shop.pending_returns(), {}, "everything found room")
	var chest_has_vase := false
	for node: Node in tree.get_nodes_in_group(&"saveable"):
		if str(node.get(&"save_id")) == "hut_chest":
			chest_has_vase = (node.get(&"storage") as Inventory).count(&"decor_grave_vase") > 0
	assert_true(chest_has_vase, "the vase lies in the hut chest")
	assert_eq(decor.placements().size(), 9, "the other nine pieces stay")


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	shop = world.get_node("Systems/Workshop") as Workshop
	gathering = world.get_node("Systems/Gathering") as GatherManager
	masonry = world.get_node("Systems/Stonemasonry") as Stonemasonry
	trade = world.get_node("Systems/NightTrade") as NightTrade
	TimeManager.running = false


## Save → load → identical collect_state(); rebinds the new world.
func _round_trip(moment: String) -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	await wait_frames(1)
	var after := SaveManager.collect_state()
	var diffs: PackedStringArray = []
	_state_diff(before, after, "", diffs)
	assert_eq(diffs, PackedStringArray(), moment + ": collect_state identical after save → load")


## Paths where two states differ. Floats count as equal within 1e-9 (relative): the save file
## stores a float as JSON.from_native's "f:<14 significant digits>" (SaveFileIO, P6), so a value
## like 1.620580833333336 comes back as 1.62058083333334 – everything else must match exactly.
func _state_diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not (b as Dictionary).has(key):
				out.append("-%s.%s" % [path, key])
			else:
				_state_diff(a[key], b[key], "%s.%s" % [path, key], out)
		for key: Variant in b:
			if not (a as Dictionary).has(key):
				out.append("+%s.%s" % [path, key])
		return
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("#%s (%d → %d)" % [path, (a as Array).size(), (b as Array).size()])
			return
		for i: int in (a as Array).size():
			_state_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		return
	if a is float and b is float:
		if absf(a - b) > 1e-9 * maxf(1.0, absf(a)):
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if typeof(a) == typeof(b) and (a is Vector2 or a is Vector3 or a is Transform3D or a is Basis or a is Quaternion):
		if not a.is_equal_approx(b):
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("~%s (%s → %s)" % [path, a, b])


## Drives the gravekeeper along `points` with the move actions (physics, collisions) – no teleport.
func _walk(points: Array) -> void:
	for target: Vector2 in points:
		var budget := 60 + int(_flat_distance(player.global_position, Vector3(target.x, 0, target.y)) / 3.2 * 60.0 * 2.5)
		while _flat_distance(player.global_position, Vector3(target.x, 0, target.y)) > ARRIVE and budget > 0:
			var dir := Vector2(target.x - player.global_position.x, target.y - player.global_position.z).normalized()
			_press(&"move_right", maxf(dir.x, 0.0))
			_press(&"move_left", maxf(-dir.x, 0.0))
			_press(&"move_down", maxf(dir.y, 0.0))
			_press(&"move_up", maxf(-dir.y, 0.0))
			await tree.physics_frame
			budget -= 1
		assert_true(budget > 0, "walked to %s (stuck at %s)" % [target, player.global_position])
		if budget <= 0:
			break
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	await tree.physics_frame


func _press(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _node(id: String) -> GatherNode:
	var node := world.get_node_or_null("Entities/" + id) as GatherNode
	if node == null:
		node = world.find_child(id, true, false) as GatherNode
	return node


func _gather(id: String) -> void:
	var node := _node(id)
	assert_not_null(node, id)
	if node == null:
		return
	assert_true(node.can_interact(player), "%s gatherable: %s" % [id, node.get_interaction_prompt(player)])
	node.interact(player)


## Tops the inventory up to `items` (materials of the base loop – wood / stone heaps – are not what
## this chain tests; the W3 bot plays the economy).
func _stock(items: Dictionary) -> void:
	for id: StringName in items:
		var have := player.inventory.count(id)
		if have < int(items[id]):
			player.inventory.add_item(id, int(items[id]) - have)


func _build(station_id: StringName) -> void:
	var site := world.get_node("Entities/site_" + String(station_id)) as BuildSite
	var data := Database.station(station_id) as StationData
	if player.inventory.count(&"coin") < data.build_coins:
		fail("not enough coins for %s" % station_id)
	assert_true(site.visible and site.can_interact(player), "build site %s" % station_id)
	site.interact(player)
	assert_eq(site.block_reason(player.inventory), "", "%s buildable" % station_id)
	site.request_build()
	UIState.clear()
	assert_true(shop.is_built(station_id), "%s built" % station_id)


func _craft(station_node: String, recipe: StringName) -> void:
	var node := (world.get_node_by_layout_id(station_node) if station_node == "workbench"
			else world.get_node("Entities/station_" + station_node)) as Workbench
	assert_true(node.can_interact(player), station_node + " usable")
	node.interact(player)
	node.request_craft(recipe)
	UIState.clear()


func _carve(grave_id: String, spec: Array) -> String:
	var design := StoneDesign.new()
	design.shape = spec[0]
	design.inscription = spec[1]
	design.ornament = spec[2]
	design.gilded = spec[3]
	var bench := world.get_node("Entities/station_mason") as Workbench
	assert_true(bench.can_interact(player), "the bench")
	var reason := masonry.order_block_reason(grave_id, design, player.inventory)
	assert_eq(reason, "", "stone for %s" % grave_id)
	if reason != "":
		return ""
	var order := [""]
	player.start_timed_action("Stein hauen", StoneDesignRules.minutes(design, Database.config(&"stone_config") as StoneConfig), func() -> void:
			order[0] = masonry.carve(grave_id, design, player.inventory), false)
	return order[0]


func _set_stone(grave_id: String) -> void:
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	assert_true(plot.has_stone_to_set(), grave_id + " has a stone waiting")
	plot.interact(player)
	assert_true(masonry.ready_for(grave_id).is_empty(), grave_id + " stone set")


## A MARKED grave with a simple stone or a cross and a known corpse (not in `skip`).
func _grave_with_marker(skip: Array = []) -> String:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED and g.design.is_empty() and not g.id in skip and g.corpse_id != "":
			return g.id
	fail("no plain grave left")
	return ""


## Osric through the real dialogue: node ids or choice texts after start at the first node.
func _osric(path: Array) -> void:
	var r := DialogueRunner.new()
	var speaker := world.get_node_by_layout_id("npc_carter")
	r.start(Database.dialogue(&"carter") as DialogueData, {"inventory": player.inventory, "speaker": speaker})
	r._enter(StringName(path[0]))
	for step: Variant in path.slice(1):
		var choices := r.available_choices()
		var picked := -1
		for i: int in choices.size():
			if (step is StringName and choices[i].next == step) or (step is String and choices[i].text.contains(step)):
				picked = i
				break
		assert_true(picked >= 0, "Osric: a choice to %s" % step)
		if picked < 0:
			return
		r.choose(picked)


func _next_morning() -> void:
	TimeManager.set_time(TimeManager.day + 1, 420)
	UIState.clear()


func _until(day: int, minute: int) -> void:
	if TimeManager.total_minutes() < (day - 1) * 1440 + minute:
		TimeManager.set_time(day, minute)


func _waypoint(id: StringName) -> Vector3:
	return world.get_waypoint(id)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_chapter(chapter_id: StringName) -> void:
	chapters.append(chapter_id)


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])
