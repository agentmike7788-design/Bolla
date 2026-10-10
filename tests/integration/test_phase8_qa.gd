extends TestCase
## W3 QA of Phase 8 (docs/PHASE8_DESIGN.md §10, §12 W3, docs/reviews/phase8_round1/qa_playthrough.md): regression
## tests of the review findings on the real world (the v6 fixture slot_p7_day53_neighbor through SaveManager;
## the pure ones are in tests/unit/test_phase8_qa.gd):
## QA8-04 the register extract for Lenz 1 / Theres 2 is copied at the hut's desk (20 min, 1 ink) ·
## QA8-05 Jakob's free day sets apprentice_off_day and the village figure follows its data schedule (in the inn) ·
## QA8-06 Liesel's corpse wash is seen – her figure behind the crypt table, washing, also after a load ·
## QA8-08 at dusk with seedlings and a candle [E] at a grave lights the candle first, at noon it sets the flowers ·
## QA8-09 the mason bench refuses the memorial plate without friend_innkeeper_2 (not only the panel) ·
## QA8-12 a loaded state has no disturbed / mortsafe on an EMPTY grave, ≤ max_open wishes, one per grave, on
## graves of this world, no visit plan for a later day ·
## QA8-13 watering pours in step with the clip (ToolAnimConfig.bite_at / beat_cues water) ·
## QA8-15 the Lichtgang procession takes the graveyard figures (the village npc_priest keeps his schedule).

const TIMEOUT := 600.0
const SLOT := 93
const FIXTURE := "slot_p7_day53_neighbor"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const DT := 1.0 / 30.0

var saves_dir := TestCase.user_dir("test_saves_p8_qa")
var world: WorldRoot
var player: Player
var notes: Array[String] = []
var _p: Player


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	if is_instance_valid(_p):
		_p.cancel_timed_action()
		_p.free()
	_p = null
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _load() -> void:
	assert_eq(Phase8Fixtures.install_save_v6(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	TimeManager.running = false


func _sys(name: String) -> Node:
	return world.get_node("Systems/" + name)


# --- QA8-04 -------------------------------------------------------------------------------------------

func test_qa8_04_register_extract_at_the_desk() -> void:
	await _load()
	var orders := _sys("Orders") as Orders
	var desk := world.find_child("desk", true, false) as Desk
	assert_not_null(desk, "the hut's desk")
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "no order: the register is read")
	assert_true(orders.accept_owed(&"of_lenz_1"), "Lenz 1 „Die Namen im Buch\" accepted")
	var inv := player.inventory
	while inv.has(&"ink"):
		inv.remove_item(&"ink", 1)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_COPY_NO_INK % "Lenz", "no ink: said so")
	inv.add_item(&"ink", 1)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_COPY % ["Lenz", 20], "„[E] Namen für Lenz abschreiben (20 Min, 1 Tinte)\"")
	desk.interact(player)
	assert_true(player.is_busy(), "copying is a timed action")
	player.cancel_timed_action()
	desk._finish_copy(player)
	assert_eq([inv.count(&"register_extract"), inv.count(&"ink")], [1, 0], "one extract for one ink")
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "copied: the register is read again")
	assert_true(orders.turn_in(&"of_lenz_1", inv), "Lenz 1 turned in with the extract")


# --- QA8-05 -------------------------------------------------------------------------------------------

func test_qa8_05_jakob_free_day_in_the_inn() -> void:
	await _load()
	var app := _sys("Apprentice") as Apprentice
	app.load_state({"hired": true, "hire_day": 53, "levels": {"rake": 1}, "jobs": {}, "board": [], "morale": 3})
	# Day 65: 65 % 7 == 2 – his day off (no festival; day 58 = 58 % 7 == 2 is the Lichtgang).
	TimeManager.set_time(65, 400)
	app.apply_minute(65, 400)
	assert_false(app.works_today(65), "day 65 is free")
	assert_eq(int(GameState.get_flag(&"apprentice_off_day", 0)), 65, "QA8-05: apprentice_off_day = 65")
	var v := world.get_node("Regions/Village/Entities/npc_apprentice_v") as Npc
	assert_null(v.runtime_schedule(), "the village Jakob follows his data schedule")
	TimeManager.set_time(65, 600)
	v.refresh()
	assert_not_null(v.entry, "an entry at 10:00")
	if v.entry != null:
		assert_eq(String(v.entry.path[v.entry.path.size() - 1]), "v_in_inn_jakob", "„Jakob hilft heute im Krug\"")
		assert_eq(v.entry.today_flag, &"apprentice_off_day", "the free-day overlay")
	# A working day: the runtime schedule again.
	TimeManager.set_time(66, 400)
	app.apply_minute(66, 400)
	assert_true(app.works_today(66))
	assert_not_null(v.runtime_schedule(), "a working day: the runtime schedule")


# --- QA8-06 -------------------------------------------------------------------------------------------

func test_qa8_06_liesel_washes_behind_the_crypt_table() -> void:
	await _load()
	var friendship := _sys("Friendship") as Friendship
	var npc := world.get_node("Entities/npc_washer_g") as Npc
	var table: Node3D = null
	for n: Node in tree.get_nodes_in_group(&"morgue_table"):
		if StringName(str(n.get(&"room"))) == &"crypt":
			table = n as Node3D
	assert_not_null(table, "the crypt table")
	var state := friendship.save_state()
	state["wash"] = {"day": 55, "minute": 580, "minutes": 60, "corpse": "corpse_x"}
	TimeManager.set_time(55, 500)
	friendship.load_state(state)
	friendship.post_load()
	assert_not_null(npc.runtime_schedule(), "QA8-06: the wash figure")
	if npc.runtime_schedule() == null:
		return
	var up: ScheduleEntry = npc.runtime_schedule().entries[1]
	assert_eq(up.activity, ScheduleBuilder.ACTIVITY_WALK, "the walk up")
	assert_eq([up.path[0], up.path[up.path.size() - 1]], ["road_end", Friendship.WASH_DOOR], "road end → crypt stair")
	assert_eq(up.start_minute + up.travel_minutes, 578, "at the crypt stair two minutes before the wash")
	TimeManager.set_time(55, up.start_minute + up.travel_minutes / 2)
	npc.refresh()
	assert_true(npc.is_present() and npc.is_walking(), "on her way up (%s)" % [npc.entry.path if npc.entry != null else []])
	TimeManager.set_time(55, 600)
	npc.refresh()
	assert_true(npc.is_present(), "Liesel is there at 10:00")
	var spot := table.global_transform * Friendship.WASH_SPOT
	assert_true(Vector2(npc.global_position.x - spot.x, npc.global_position.z - spot.z).length() < 0.05,
			"behind the crypt table (%s, table %s)" % [npc.global_position, table.global_position])
	assert_eq(npc.current_animation(), Friendship.WASH_ANIM, "washing")
	TimeManager.set_time(55, 800)
	npc.refresh()
	assert_false(npc.is_present(), "gone again at 13:20")
	# The next morning her data schedule again.
	friendship.load_state(friendship.save_state().merged({"wash": {}}, true))
	TimeManager.set_time(56, 400)
	friendship.apply_morning(56)
	assert_null(npc.runtime_schedule(), "the day after: her data schedule")


# --- QA8-08 -------------------------------------------------------------------------------------------

func test_qa8_08_candle_before_flowers_at_dusk() -> void:
	await _load()
	var care := _sys("GraveCare") as GraveCare
	var plot: GravePlot = null
	for g: GraveRecord in world.graveyard.graves():
		if g.state == GraveRecord.State.MARKED and care.flowers_state(g.id) == &"" and not care.candle_lit(g.id):
			var p := world.get_node_by_layout_id(g.id) as GravePlot
			if p != null:
				plot = p
				break
	assert_not_null(plot, "a marked grave without flowers")
	if plot == null:
		return
	var inv := player.inventory
	inv.add_item(care.get_config().flower_item, 2)
	inv.add_item(care.get_config().candle_item, 2)
	TimeManager.set_time(55, 12 * 60)
	assert_eq(plot.care_order(player)[plot.care_order(player).find(GravePlot.CARE_PLANT) + 1], GravePlot.CARE_WREATH, "noon: CARE_ORDER")
	assert_true(plot.get_interaction_prompt(player).contains("Grabblumen"), "noon: flowers (%s)" % plot.get_interaction_prompt(player))
	TimeManager.set_time(55, 16 * 60 + 30)
	var order := plot.care_order(player)
	assert_true(order.find(GravePlot.CARE_CANDLE) < order.find(GravePlot.CARE_PLANT), "QA8-08: dusk – the candle before the flowers")
	assert_true(plot.get_interaction_prompt(player).contains("Grabkerze"), "dusk: the candle (%s)" % plot.get_interaction_prompt(player))


# --- QA8-09 -------------------------------------------------------------------------------------------

func test_qa8_09_mason_bench_checks_the_flag() -> void:
	await _load()
	var bench: Workbench = null
	for n: Node in world.find_children("*", "Workbench", true, false):
		if (n as Workbench).station == &"mason":
			bench = n as Workbench
	assert_not_null(bench, "the mason bench")
	if bench == null:
		return
	GameState.set_flag(&"friend_innkeeper_2", false)
	var recipe := Database.recipe(&"memorial_plate") as RecipeData
	assert_false(Workbench.recipe_offered(recipe), "no flag: not offered")
	notes.clear()
	bench.request_craft(&"memorial_plate")
	assert_true(notes.has(Workbench.TEXT_UNKNOWN), "QA8-09: refused without the flag (%s)" % str(notes))
	assert_false(player.is_busy(), "nothing started")
	GameState.set_flag(&"friend_innkeeper_2", true)
	assert_true(Workbench.recipe_offered(recipe), "with the flag")
	notes.clear()
	bench.request_craft(&"memorial_plate")
	assert_false(notes.has(Workbench.TEXT_UNKNOWN), "with the flag it is known (%s)" % str(notes))
	player.cancel_timed_action()


# --- QA8-12 -------------------------------------------------------------------------------------------

func test_qa8_12_load_sanitizes_the_phase8_parts() -> void:
	await _load()
	var care := _sys("GraveCare") as GraveCare
	var visitors := _sys("Visitors") as Visitors
	var empty := ""
	var marked: Array[String] = []
	for g: GraveRecord in world.graveyard.graves():
		if g.state in [GraveRecord.State.EMPTY, GraveRecord.State.LOCKED] and empty == "":
			empty = g.id
		elif g.state == GraveRecord.State.MARKED:
			marked.append(g.id)
	assert_true(empty != "" and marked.size() >= 5, "an empty (or locked) grave and five marked ones")
	world.graveyard.get_grave(empty).disturbed = true
	var cs := care.save_state()
	cs["mortsafes"] = {empty: 60, marked[0]: 60}
	cs["disturbed"] = [empty, marked[1]]
	care.load_state(cs)
	assert_false(care.is_disturbed(empty), "QA8-12: no disturbed EMPTY grave")
	assert_false(world.graveyard.get_grave(empty).disturbed, "the record too")
	assert_false(care.has_mortsafe(empty), "QA8-12: no mortsafe on an EMPTY grave")
	assert_true(care.has_mortsafe(marked[0]), "the mortsafe on the marked grave stays")
	assert_true(care.is_disturbed(marked[1]), "the disturbed marked grave stays")
	var vs := visitors.save_state()
	var wishes: Array = []
	for i: int in 5:
		wishes.append({"wish_id": "w_%d" % (90 + i), "grave_id": marked[i], "kin_id": "kin_kehr", "kind": "tend", "state": "offered", "day": 53})
	wishes.append({"wish_id": "w_99", "grave_id": "nowhere", "kin_id": "kin_kehr", "kind": "tend", "state": "accepted", "day": 53})
	vs["wishes"] = wishes
	vs["plan_day"] = TimeManager.day + 3
	visitors.load_state(vs)
	var open := visitors.open_wishes()
	assert_eq(open.size(), (Database.config(&"visitor_config") as VisitorConfig).max_open, "QA8-12: at most max_open open wishes")
	assert_false(open.any(func(w: Dictionary) -> bool: return str(w.grave_id) == "nowhere"), "no wish on an unknown grave")
	assert_true(int(visitors.save_state().plan_day) <= TimeManager.day, "no plan for a later day")


# --- QA8-13 -------------------------------------------------------------------------------------------

func test_qa8_13_watering_pours_in_step() -> void:
	_p = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	tree.root.add_child(_p)
	_p.set_physics_process(false)
	await tree.physics_frame
	Audio.reset()
	Audio.enabled = true
	assert_true(_p.syncs_work_cue(&"water"), "QA8-13: water syncs")
	assert_eq(_p.beat_cue(&"water"), &"water_pour")
	_p.start_timed_action("Blumen gießen", 60, func() -> void: pass, true, &"water")
	var anim := _p._anim
	var t := 0.0
	var pours := 0
	var was := false
	while t < 4.0:
		_p._physics_process(DT)
		anim.advance(DT)
		t += DT
		var n := Audio.played.count(&"water_pour")
		if n > pours:
			pours = n
			if not was:
				was = true
				var pos := anim.current_animation_position / anim.current_animation_length
				assert_eq(anim.current_animation, &"water", "the watering clip")
				assert_true(pos >= 0.04 and pos <= 0.05 + 2.0 * DT / anim.current_animation_length + 0.01, "at the pour (%.2f)" % pos)
	assert_true(pours >= 2, "QA8-13: one pour per cycle (%d in 4 s)" % pours)
	_p.cancel_timed_action()
	Audio.reset()


# --- QA8-15 -------------------------------------------------------------------------------------------

func test_qa8_15_the_procession_walks_on_the_graveyard_only() -> void:
	await _load()
	var fest := _sys("Festivals") as Festivals
	var state := fest.save_state()
	state["days"] = {"fest_lights": TimeManager.day, "fest_kathrein": TimeManager.day + 20}
	fest.load_state(state)
	assert_eq(fest.today(), Festivals.LIGHTS, "the Lichtgang today")
	fest.apply_procession()
	var lenz_g := world.get_node("Entities/npc_priest") as Npc
	var lenz_v := world.get_node("Regions/Village/Entities/npc_priest") as Npc
	assert_not_null(lenz_g.runtime_schedule(), "QA8-15: Lenz walks the procession on the graveyard")
	assert_null(lenz_v.runtime_schedule(), "QA8-15: the village Lenz keeps his schedule")
