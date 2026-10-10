extends TestCase
## W3 QA of Phase 8 (docs/PHASE8_DESIGN.md §10, docs/reviews/phase8_round1/qa_playthrough.md): regression tests of
## the review findings that need no world (the world ones are in tests/integration/test_phase8_qa.gd):
## QA8-01 Lenz' and Theres' favour opens the favour panel (a grave / a ware to choose) instead of favor_use without a
## choice · QA8-03 a meet order on the hill sets its schedule flag (today / tomorrow / never on the Lichtgang) and the
## schedules of Fenner (l_12) and Rosine (Jakob's bench) bring them up · QA8-10 „Zwei Münzen auf dem Stein" ·
## QA8-16 the coins on the stone win the [E] over the grave they lie on (TipStone priority above GravePlot's) ·
## QA8-A5 (E8-1) the short November days: the keyframes of the time-driven atmosphere move with the calendar ·
## QA8-17 a deferred Apprentice refresh out of the tree (the world a load replaces) touches nothing ·
## QA8-19 the chapter intro without words of the game's making („Phase“).

var world: Node
var orders: Orders
var panels: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": 56, "minute_of_day": 600})
	panels.clear()


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


func _on_panel(id: StringName, ctx: Dictionary) -> void:
	panels.append([id, ctx])


func _choices_of(dlg: DialogueData, node_id: StringName) -> Array:
	for n: DialogueNode in dlg.nodes:
		if n.id == node_id:
			return n.choices
	return []


# --- QA8-01 -------------------------------------------------------------------------------------------

func test_qa8_01_lenz_and_theres_favour_opens_the_panel() -> void:
	for spec: Array in [[&"v_priest", "favor_use:priest"], [&"v_grocer", "favor_use:grocer"]]:
		var dlg := Database.dialogue(spec[0]) as DialogueData
		assert_not_null(dlg, String(spec[0]))
		if dlg == null:
			continue
		var acts: Array[String] = []
		for c: DialogueChoice in _choices_of(dlg, &"favor"):
			acts.append_array(c.actions)
		assert_true("open_panel:favor" in acts, "%s: the favour opens the panel (%s)" % [spec[0], str(acts)])
		assert_false(spec[1] in acts, "%s: no %s without a choice" % [spec[0], spec[1]])
	# The action opens &"favor" with the speaker (FavorPanel reads npc_id from it).
	EventBus.ui_panel_requested.connect(_on_panel)
	var speaker := Node.new()
	DialogueActions.run_all(["open_panel:favor"] as Array[String], {"speaker": speaker})
	EventBus.ui_panel_requested.disconnect(_on_panel)
	speaker.free()
	assert_eq(panels.size(), 1, "one panel")
	if not panels.is_empty():
		assert_eq(panels[0][0], &"favor")


# --- QA8-03 -------------------------------------------------------------------------------------------

func _orders() -> void:
	world = Node.new()
	world.name = "QA8World"
	orders = Orders.new()
	for id: StringName in [&"of_fenner_2", &"of_rosine_3"]:
		orders.order_table[id] = Database.order_data(id) as OrderData
	world.add_child(orders)
	tree.root.add_child(world)


func test_qa8_03_meet_orders_set_their_schedule_flag() -> void:
	_orders()
	assert_eq(StringName(str((Database.order_data(&"of_fenner_2") as OrderData).conditions.get("schedule_flag", ""))), &"meet_mayor_day")
	assert_eq(StringName(str((Database.order_data(&"of_rosine_3") as OrderData).conditions.get("schedule_flag", ""))), &"meet_innkeeper_day")
	# 10:00: the walk up can still start → today.
	assert_true(orders.accept_owed(&"of_fenner_2"))
	assert_eq(int(GameState.get_flag(&"meet_mayor_day", 0)), 56, "accepted in the morning: today")
	# 15:30 (window 15:00): too late for today → tomorrow.
	TimeManager.load_state({"day": 56, "minute_of_day": 930})
	assert_true(orders.accept_owed(&"of_rosine_3"))
	assert_eq(int(GameState.get_flag(&"meet_innkeeper_day", 0)), 57, "accepted at 15:30: tomorrow")
	# Every morning while accepted.
	orders.apply_morning(58)
	assert_eq([int(GameState.get_flag(&"meet_mayor_day", 0)), int(GameState.get_flag(&"meet_innkeeper_day", 0))], [58, 58])
	orders.complete(&"of_fenner_2")
	orders.apply_morning(59)
	assert_eq(int(GameState.get_flag(&"meet_mayor_day", 0)), 58, "completed: no more days on the hill")


func test_qa8_03_schedules_bring_fenner_and_rosine_up() -> void:
	var mayor := Database.schedule(&"mayor") as NpcSchedule
	var inn := Database.schedule(&"innkeeper") as NpcSchedule
	# Without the flag: the board / the bar as in Phase 7.
	var e := ScheduleResolver.entry_at(mayor, 965, 56)
	assert_eq(String(e.path[e.path.size() - 1]), "v_board", "a normal day: at the board")
	GameState.set_flag(&"meet_mayor_day", 56)
	e = ScheduleResolver.entry_at(mayor, 965, 56)
	assert_eq([String(e.path[e.path.size() - 1]), e.region, e.dialogue_id], ["gv_l_12", &"", &"v_mayor"], "QA8-03: Fenner at l_12")
	e = ScheduleResolver.entry_at(mayor, 1040, 56)
	assert_eq(String(e.path[e.path.size() - 1]), "v_board", "back at the board before the inn")
	e = ScheduleResolver.entry_at(mayor, 1100, 56)
	assert_eq(String(e.path[e.path.size() - 1]), "v_in_inn_table", "18:20 in the inn as every day")
	e = ScheduleResolver.entry_at(inn, 910, 56)
	assert_eq(String(e.path[e.path.size() - 1]), "v_in_inn_bar", "Rosine behind the bar")
	GameState.set_flag(&"meet_innkeeper_day", 56)
	e = ScheduleResolver.entry_at(inn, 910, 56)
	assert_eq([String(e.path[e.path.size() - 1]), e.region, e.dialogue_id], ["vw_39", &"", &"v_innkeeper"], "QA8-03: Rosine at Jakob's bench")
	e = ScheduleResolver.entry_at(inn, 990, 56)
	assert_eq(String(e.path[e.path.size() - 1]), "v_in_inn_bar", "back behind the bar at 16:30")


# --- QA8-10 -------------------------------------------------------------------------------------------

func test_qa8_10_coins_on_the_stone_in_words() -> void:
	assert_eq(Phase8Texts.coins_on_stone(2, "Martha Kehr"), "Zwei Münzen auf dem Stein (Martha Kehr)")
	assert_eq(Phase8Texts.coins_on_stone(1, "Gesa Ott"), "Eine Münze auf dem Stein (Gesa Ott)")
	assert_eq(Phase8Texts.coin_count(3), "Drei Münzen")
	assert_eq(Phase8Texts.coin_count(9), "9 Münzen", "beyond the words: digits")
	assert_eq(TipStone.PROMPT_FORMAT % Phase8Texts.coins_on_stone(2, "X"), "[E] Zwei Münzen auf dem Stein (X)")
	assert_eq(GravePlot.PROMPT_COINS % Phase8Texts.coins_on_stone(3, "Y"), "[E] Drei Münzen auf dem Stein (Y)")


# --- QA8-A5 (E8-1) ------------------------------------------------------------------------------------

func test_qa8_a5_november_dusk_comes_earlier() -> void:
	var scene := load("res://src/world/graveyard/graveyard.tscn") as PackedScene
	var state := scene.get_state()
	var atmo := AtmosphereController.new()
	for i: int in state.get_node_count():
		if state.get_node_name(i) == &"Atmosphere":
			for k: int in state.get_node_property_count(i):
				var key := state.get_node_property_name(i, k)
				if String(key).begins_with("season") or key == &"blend_minutes":
					atmo.set(key, state.get_node_property_value(i, k))
	assert_eq(atmo.keyframe_minutes(45), atmo.blend_minutes, "before the season: the approved Phase-7 keyframes")
	assert_eq(atmo.keyframe_minutes(50), atmo.blend_minutes, "day 50: unchanged")
	var late := atmo.keyframe_minutes(56)
	assert_eq(Array(late), [0, 180, 270, 390, 525, 900, 1000, 1090, 1290], "late November: day until 15:00, dusk 16:40, night 18:10")
	assert_eq(atmo.keyframe_minutes(70), late, "held after the full day")
	var mid := atmo.keyframe_minutes(53)
	for k: int in mid.size():
		assert_true(mid[k] >= mini(late[k], atmo.blend_minutes[k]) and mid[k] <= maxi(late[k], atmo.blend_minutes[k]), "day 53 between")
		if k > 0:
			assert_true(mid[k] > mid[k - 1], "strictly ascending")
	atmo.free()


# --- QA8-16 -------------------------------------------------------------------------------------------

func _priority(scene_path: String) -> int:
	var node := (load(scene_path) as PackedScene).instantiate()
	var p := int(node.get_node("Interactable").get(&"priority"))
	node.free()
	return p


func test_qa8_16_coins_on_the_stone_win_the_prompt() -> void:
	assert_true(_priority("res://src/entities/tip_stone/tip_stone.tscn") > _priority("res://src/entities/grave/grave_plot.tscn"),
			"QA8-16: „[E] Zwei Münzen auf dem Stein“ before the grave's own prompt")


# --- QA8-17 -------------------------------------------------------------------------------------------

## A deferred refresh of an Apprentice whose world a load just replaced (out of the tree, its cached Npc too):
## nothing is touched – before the fix Npc._update read global_transform / look_yaw outside the tree (errors).
func test_qa8_17_apprentice_refresh_out_of_tree_is_a_no_op() -> void:
	var app := Apprentice.new()
	var npc := (load("res://src/entities/npc/npc.tscn") as PackedScene).instantiate() as Npc
	app.npc = npc
	app.refresh_npcs()
	assert_eq(npc.runtime_schedule() if npc.has_method(&"runtime_schedule") else null, null, "no runtime schedule set outside the tree")
	npc.free()
	app.free()


# --- QA8-19 -------------------------------------------------------------------------------------------

## The chapter panel speaks of the game's world, not of its making („In Phase sieben …“ named a dev phase).
func test_qa8_19_chapter_intro_without_meta_words() -> void:
	for word: String in ["Phase", "Kapitel", "Spieler", "Level"]:
		assert_false(Phase8Texts.CHAPTER_INTRO.contains(word), "QA8-19: no „%s“ in the chapter intro" % word)
	assert_true(Phase8Texts.CHAPTER_INTRO.contains("herauf"), "the line keeps its turn: they come up")
