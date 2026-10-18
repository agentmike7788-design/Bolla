extends TestCase
## W-UI Phase 9 – the map's marks (docs/PHASE9_DESIGN.md §7.6, §10): Brenneisen (his top hat) while he is here, the
## large sheet at the gate's / the parish board, the Siebers' light (Ende B / C, at night), and the bookmark of the
## pinned entry – only at a fixed place, never as an arrow or a distance. The marks live on the overlay: the baked sheet
## never bakes again for them. Headless, with Phase9Fixtures.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const DAY := Phase9Fixtures.OPEN_DAY


class FakePlayer extends Node3D:
	var inventory: Inventory
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false
	var interior_id: StringName = &""

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return false


var ui: UIRoot
var player: FakePlayer
var _extra: Array[Node] = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(DAY, 600)


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	for n: Node in _extra + [player]:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	tree.paused = false
	await wait_frames(2)


func test_nothing_without_the_systems() -> void:
	assert_eq(MapStatePhase9.context(tree), {})


func test_large_sheet_and_bookmark_at_a_fixed_place() -> void:
	var q := _keep(Phase9Fixtures.quest_at(&"q_who_knows", &"h1", tree)) as Quests
	_keep(Phase9Fixtures.large_pinned(&"hrl_ferry_graves", [true, false, false] as Array[bool], tree))
	var ctx := MapStatePhase9.context(tree)
	var large: Array = (ctx.marks as Array).filter(func(m: Dictionary) -> bool: return m.kind == &"large")
	assert_eq(large.size(), 1, "the large sheet at the gate")
	assert_eq(str(large[0].place), "notice_board")
	assert_true(str(large[0].text).contains("Die Gräber der Fähre"))
	assert_true((ctx.marks as Array).filter(func(m: Dictionary) -> bool: return m.kind == &"bookmark").is_empty(), "nothing pinned")
	q.pin(&"q_who_knows")
	ctx = MapStatePhase9.context(tree)
	var marks: Array = (ctx.marks as Array).filter(func(m: Dictionary) -> bool: return m.kind == &"bookmark")
	assert_eq(marks.size(), 1, "H1: the hut is a fixed place")
	assert_eq(str(marks[0].place), "hut")
	assert_false(marks[0].has("world"), "a place, never a moving target")
	# H3 (ask the witnesses) has no fixed place: no bookmark
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "step": {"q_who_knows": "h3"}, "done": {"q_who_knows": ["h1", "h2"]},
			"pinned": "q_who_knows"})
	ctx = MapStatePhase9.context(tree)
	assert_true((ctx.get("marks", []) as Array).filter(func(m: Dictionary) -> bool: return m.kind == &"bookmark").is_empty(),
			"no fixed place – no bookmark")
	# a pinned large request: its board
	q.pin(&"hrl_ferry_graves")
	ctx = MapStatePhase9.context(tree)
	marks = (ctx.marks as Array).filter(func(m: Dictionary) -> bool: return m.kind == &"bookmark")
	assert_eq(str(marks[0].place), "notice_board")


func test_sieber_light_only_b_c_at_night() -> void:
	_keep(Phase9Fixtures.p9_open(tree))
	GameState.set_flag(&"q_end_stay", true)
	assert_eq(MapStatePhase9.context(tree), {}, "by day no light")
	TimeManager.set_time(DAY, 1300)
	var marks: Array = MapStatePhase9.context(tree).get("marks", [])
	assert_eq(marks.size(), 1)
	assert_eq(marks[0].kind, &"sick_light")
	assert_eq(str(marks[0].place), "house_sieber")
	GameState.set_flag(&"sieber_dead", true)
	assert_eq(MapStatePhase9.context(tree), {}, "after his death no light")


func test_canvas_draws_the_marks_without_baking() -> void:
	await _setup()
	ui.open_map()
	await wait_frames(2)
	var c := (ui.get_panel(&"map") as MapPanel).canvas
	var bakes := c.bake_count
	var ctx := c.ctx.duplicate(true)
	ctx["p9"] = {"marks": [
		{"kind": &"large", "region": &"graveyard", "place": "notice_board", "id": "hrl_crosses", "text": "Große Bitte: Drei Kreuze"},
		{"kind": &"stranger", "region": &"graveyard", "place": "gate_outside", "id": "stranger", "text": "Der Herr mit dem Koffer"},
		{"kind": &"bookmark", "region": &"graveyard", "place": "hut", "id": "q_who_knows", "text": "Verfolgt: Wer weiß, wann?"},
		{"kind": &"sick_light", "region": &"village", "place": "house_sieber", "id": "house_sieber", "text": "Licht bei den Siebers"},
	]}
	c.show_region(&"graveyard", c.layout, ctx, c.cfg)
	var p9 := c.phase9_markers()
	assert_eq(p9.size(), 3, "the graveyard's three (the village light on its own sheet): %s" % str(p9.map(func(m: Dictionary) -> String: return str(m.kind))))
	assert_eq(c.phase9_markers(&"bookmark").size(), 1)
	assert_eq(c.tooltip_at(c.phase9_markers(&"large")[0].point), "Große Bitte: Drei Kreuze")
	assert_eq(c.bake_count, bakes, "Phase-9 marks never bake the sheet")


func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.inventory = Inventory.new()
	player.add_child(player.inventory)
	tree.root.add_child(player)
	player.global_position = Vector3(-4.4, 0.0, -3.6)
	ui = await add_scene(UI_SCENE) as UIRoot


func _keep(node: Node) -> Node:
	_extra.append(node)
	return node
