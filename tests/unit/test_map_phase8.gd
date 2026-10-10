extends TestCase
## W-UI Phase 8 – the map's marks (docs/PHASE8_DESIGN.md §7.8, §10): visitors, Jakob, wishes, coins on the stone,
## Hanne, Veit, the sick light (only from c_n_veit), the festival, disturbed graves – never the night digger; the
## grave tooltip; the marks live on the overlay, so the baked sheet is baked again only for what it shows itself (a new
## grave of the third row, a new prop), never for a Phase-8 mark. Headless, with the P2 visitors harness and doubles.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const Harness := preload("res://tests/unit/visitors_harness.gd")
const DAY := 55


class FakePlayer extends Node3D:
	var inventory: Inventory
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false
	var interior_id: StringName = &""

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return false


class JournalDouble extends Node:
	var found: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_clue(id: StringName) -> bool:
		return id in found


class PathsDouble extends NightPaths:
	var houses := PackedStringArray()

	func sick_houses(_day: int, _minute: int) -> PackedStringArray:
		return houses


var ui: UIRoot
var player: FakePlayer
var h: Harness
var cfg: MapConfig


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(DAY, 600)
	cfg = MapPanel.map_config()


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	if h != null:
		h.teardown()
		h = null
	if is_instance_valid(player):
		player.queue_free()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	tree.paused = false
	await wait_frames(2)


func test_nothing_before_p8_open() -> void:
	assert_eq(MapStatePhase8.context(tree), {})
	GameState.set_flag(&"p8_open", true)
	assert_true(MapStatePhase8.context(tree).has("marks"))


func test_marks_from_the_systems() -> void:
	await _setup()
	h.bury("l_02", &"house_kehr", DAY - 2)
	h.bury("l_03", &"house_ott", DAY - 9)
	var now := TimeManager.total_minutes()
	h.visitors.load_state({"plan_day": DAY, "plan": [{"visit_id": "v_1", "kin_id": "kin_kehr", "graves": ["l_02"], "slot": 570,
			"phase": "mourning"}], "wishes": [{"wish_id": "w_0001", "kind": "flowers", "grave_id": "l_02", "kin_id": "kin_kehr",
			"state": "accepted", "day": DAY, "candle_seen": false, "template": "w_flowers"}], "tips_on_stone": {"l_03": [2, "kin_ott"]},
			"next_wish": 2})
	h.care.set_disturbed("l_03")
	h.care.load_state(h.care.save_state().merged({"flowers": {"l_02": {"planted": now, "watered": now, "wreath": false}}}, true))
	var ctx := MapStatePhase8.context(tree)
	var kinds := _kinds(ctx.marks)
	assert_true(&"visitor" in kinds, str(kinds))
	assert_true(&"wish" in kinds, str(kinds))
	assert_true(&"coins" in kinds, str(kinds))
	assert_true(&"disturbed" in kinds, str(kinds))
	assert_false(&"sick_light" in kinds, "no sick light before c_n_veit")
	var visitor := _mark(ctx.marks, &"visitor")
	assert_eq(str(visitor.text), "Martha Kehr", "the name in the tooltip")
	assert_eq(str(visitor.place), "l_02", "no Npc here: at the grave")
	assert_true(str(_mark(ctx.marks, &"wish").text).begins_with("Wunsch: Blumen (Die Kehrs"), str(_mark(ctx.marks, &"wish").text))
	assert_eq(str(_mark(ctx.marks, &"coins").text), "2 Münzen auf dem Stein (Gesa Ott)")
	assert_true(ctx.grave_info.has("l_02"))


func test_sick_light_only_from_c_n_veit_and_the_festival() -> void:
	await _setup()
	var paths := PathsDouble.new()
	paths.houses = PackedStringArray(["house_ott"])
	h.root.add_child(paths)
	var journal := JournalDouble.new()
	h.root.add_child(journal)
	assert_false(&"sick_light" in _kinds(MapStatePhase8.context(tree).marks))
	journal.found.append(&"c_n_veit")
	var ctx := MapStatePhase8.context(tree)
	var sick := _mark(ctx.marks, &"sick_light")
	assert_eq(str(sick.place), "house_ott")
	assert_eq(StringName(str(sick.region)), &"village")
	assert_eq(str(sick.text), "Bei den Otts brennt Licht")
	var fest := Phase8Fixtures.fest_today(&"fest_lights", null, DAY)
	h.root.add_child(fest)
	ctx = MapStatePhase8.context(tree)
	var lights: Array = ctx.marks.filter(func(m: Dictionary) -> bool: return m.kind == &"fest")
	assert_eq(lights.size(), 2, "the graveyard and the bridge")
	assert_eq(StringName(str(lights[0].glyph)), &"lantern")


func test_canvas_draws_the_marks_on_the_overlay_and_never_the_digger() -> void:
	await _setup()
	h.bury("l_02", &"house_kehr", DAY - 2)
	h.care.light_free("l_02")
	ui.open_map()
	await wait_frames(2)
	var c := (ui.get_panel(&"map") as MapPanel).canvas
	var ctx := c.ctx.duplicate(true)
	var info := Phase8Status.grave_info(tree)
	ctx["p8"] = {"grave_info": info, "marks": [
		{"kind": &"visitor", "region": &"graveyard", "place": "l_02", "id": "kin_kehr", "text": "Martha Kehr"},
		{"kind": &"wish", "region": &"graveyard", "place": "l_02", "id": "l_02", "text": "Wunsch: Blumen"},
		{"kind": &"coins", "region": &"graveyard", "place": "l_02", "id": "l_02", "text": "2 Münzen"},
		{"kind": &"apprentice", "region": &"graveyard", "place": "l_03", "id": "apprentice", "text": "Jakob harkt im Lindenacker"},
		{"kind": &"visitor", "region": &"graveyard", "place": "l_04", "id": "robber", "text": "Lambert Grell"},
		{"kind": &"peddler", "region": &"village", "place": "well", "id": "peddler", "text": "Hanne Vogelsang"},
	]}
	GameState.set_flag(&"linden_granted", true)
	ctx["sections"] = MapState.sections(tree)
	var sections: Dictionary = ctx.sections
	if sections.has(&"linden"):
		sections[&"linden"]["unlocked"] = true
	c.show_region(&"graveyard", c.layout, ctx, c.cfg)
	var p8 := c.phase8_markers()
	assert_eq(p8.size(), 4, "graveyard marks without the digger and the village's Hanne: %s" % str(p8.map(func(m: Dictionary) -> String: return str(m.kind))))
	assert_true(c.phase8_markers(&"apprentice").size() == 1)
	assert_true(p8.all(func(m: Dictionary) -> bool: return str(m.id) != "robber"), "never the night digger")
	var wish: Dictionary = c.phase8_markers(&"wish")[0]
	var coins: Dictionary = c.phase8_markers(&"coins")[0]
	assert_ne(wish.point, coins.point, "side by side on the grave")
	assert_eq(c.tooltip_at(wish.point), "Wunsch: Blumen")
	var grave_point := c.world_to_map(c.layout.places["l_02"])
	var tip := ""
	for hs: Dictionary in c.hotspots:
		if (hs.point as Vector2).distance_to(grave_point) < 0.5 and str(hs.text).begins_with("Gepflegtes Grab"):
			tip = str(hs.text)
	assert_true(tip.contains("Kerze brennt"), tip)
	assert_true(tip.contains("Die Kehrs: ruhig"), tip)


func test_marks_never_bake_the_sheet_again() -> void:
	await _setup()
	h.bury("l_02", &"house_kehr", DAY - 2)
	ui.open_map()
	await wait_frames(2)
	var c := (ui.get_panel(&"map") as MapPanel).canvas
	var bakes := c.bake_count
	var key := c.static_key()
	var ctx := c.ctx.duplicate(true)
	ctx["p8"] = {"grave_info": {"l_02": {"candle": true}}, "marks": [{"kind": &"wish", "region": &"graveyard", "place": "l_02", "id": "l_02",
			"text": "Wunsch"}]}
	c.show_region(&"graveyard", c.layout, ctx, c.cfg)
	assert_eq(c.static_key(), key, "Phase-8 marks and the tooltip do not touch the sheet")
	assert_eq(c.bake_count, bakes)
	ctx["p8"] = {"grave_info": {}, "marks": []}
	c.show_region(&"graveyard", c.layout, ctx, c.cfg)
	assert_eq(c.bake_count, bakes, "marks gone: still no bake")
	# The third row of the Lindenacker (or a new prop) is part of the sheet: that bakes again, once.
	var layout := c.layout
	var extra := {"id": "l_99", "pos": Vector2(15.0, 18.0), "section": &"yard", "old": false}
	layout.graves.append(extra)
	c.show_region(&"graveyard", layout, ctx, c.cfg)
	assert_ne(c.static_key(), key, "a new grave changes the sheet")
	assert_eq(c.bake_count, bakes + 1)
	layout.graves.erase(extra)


func test_apprentice_tooltip_text() -> void:
	await _setup()
	var a := Phase8Fixtures.apprentice_with({"rake": 1}, [{"task": "rake", "area": "yard"}], 0, tree)
	var app: Apprentice = a.apprentice
	var state := app.save_state()
	state["plan_day"] = DAY
	state["plan"] = [{"task": "rake", "spot_id": "dirt_l_02", "grave_id": "l_02", "start": 590, "end": 620, "walk_minutes": 0,
			"work_start": 590, "work_minutes": 15, "path": [], "mistake": false, "kind": "leaves", "consumes": ""}]
	app.load_state(state)
	var text := MapStatePhase8.apprentice_text(tree, app)
	assert_true(text.begins_with("Jakob harkt"), text)
	(state.plan as Array)[0]["start"] = 640
	(state.plan as Array)[0]["end"] = 670
	app.load_state(state)
	assert_eq(MapStatePhase8.apprentice_text(tree, app), "Jakob ist auf dem Weg", "between two places")
	(a.apprentice as Node).queue_free()
	(a.box as Node).queue_free()


# --- helpers ---------------------------------------------------------------------------------

func _setup() -> void:
	h = Harness.new()
	h.setup(tree, 53)
	h.all_kin()
	h.life.remove_from_group(&"npc_life")
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.inventory = Inventory.new()
	player.add_child(player.inventory)
	tree.root.add_child(player)
	player.global_position = Vector3(-4.4, 0.0, -3.6)
	ui = await add_scene(UI_SCENE) as UIRoot


func _kinds(marks: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for m: Dictionary in marks:
		out.append(StringName(str(m.kind)))
	return out


func _mark(marks: Array, kind: StringName) -> Dictionary:
	for m: Dictionary in marks:
		if StringName(str(m.kind)) == kind:
			return m
	return {}
