extends TestCase
## G7 Änderungsrunde 1 – the map (MapPanel / MapCanvas / MapLayout / MapState): M opens and closes it,
## the sheet follows the region and the room, the player marker is the world position scaled, locked
## sections are hidden or faded, the village sheet only from village_open, every building of both
## layouts is labelled, people / orders / shop hours, all headless.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const FLAGS: Array[StringName] = [&"village_open", &"linden_granted", &"buildings_open", &"has_elder_key"]


class FakePlayer extends Node3D:
	var inventory: Inventory
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false
	var interior_id: StringName = &""

	func is_busy() -> bool:
		return false


var ui: UIRoot
var player: FakePlayer
var cfg: MapConfig
var _flags_before: Dictionary = {}


func before_each() -> void:
	_flags_before.clear()
	for f: StringName in FLAGS:
		_flags_before[f] = GameState.get_flag(f)
		GameState.clear_flag(f)
	cfg = MapPanel.map_config()


func after_each() -> void:
	for f: StringName in FLAGS:
		GameState.clear_flag(f)
		if _flags_before.get(f) != null:
			GameState.set_flag(f, _flags_before[f])
	tree.paused = false


func _setup(at: Vector3 = Vector3(-4.4, 0.0, -3.6)) -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.add_to_group(&"player")
	player.inventory = Inventory.new()
	player.add_child(player.inventory)
	tree.root.add_child(player)
	player.global_position = at
	ui = await add_scene(UI_SCENE) as UIRoot


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		tree.root.push_input(ev)


func _map() -> MapPanel:
	return ui.get_panel(&"map") as MapPanel


# --- open / close ---------------------------------------------------------------------------

func test_config_and_action_exist() -> void:
	assert_true(InputMap.has_action(&"map_toggle"), "map_toggle in project.godot")
	assert_true(UIRoot.PANEL_SCRIPTS.has(&"map"))
	assert_true(Database.config(&"map_config") is MapConfig, "data/config/map_config.tres")


func test_m_opens_and_closes_the_map() -> void:
	await _setup()
	_press(&"map_toggle")
	await wait_frames(1)
	assert_eq(ui.top(), &"map")
	assert_true(UIState.is_open(&"map"), "modal through UIState")
	assert_true(TimeManager.paused, "the clock stands while the map is open")
	assert_true(_map().is_visible_in_tree())
	_press(&"map_toggle")
	await wait_frames(1)
	assert_eq(ui.open_ids(), [])
	assert_false(UIState.is_modal())
	_press(&"map_toggle")
	await wait_frames(1)
	_press(&"pause")
	await wait_frames(1)
	assert_eq(ui.open_ids(), [], "Esc closes the map (no pause menu)")


func test_m_does_nothing_over_another_panel() -> void:
	await _setup()
	ui.open_panel(&"inventory", {"inventory": player.inventory})
	_press(&"map_toggle")
	await wait_frames(1)
	assert_eq(ui.open_ids(), [&"inventory"])


func test_pause_menu_button_opens_the_map() -> void:
	await _setup()
	ui.open_panel(&"pause", {})
	var pause := ui.get_panel(&"pause") as PauseMenu
	assert_not_null(pause.map_button)
	pause.map_button.pressed.emit()
	await wait_frames(1)
	assert_eq(ui.open_ids(), [&"map"], "the map replaces the pause menu")
	assert_false(tree.paused, "the tree pause of the pause menu ends")
	ui.close_top_panel()


# --- sheets -----------------------------------------------------------------------------------

func test_sheet_follows_region_and_room() -> void:
	await _setup()
	ui.open_map()
	assert_eq(_map().current_region, &"graveyard")
	ui.close_all()
	player.region_id = &"village"
	player.global_position = Vector3(1.0, 0.0, 402.0)
	ui.open_map()
	assert_eq(_map().current_region, &"village", "in the village: Hollerbrück, even before the flag")
	ui.close_all()
	player.in_interior = true
	player.interior_id = &"inn"
	player.global_position = Vector3(240.0, 0.0, -200.0)
	ui.open_map()
	var map := _map()
	assert_eq(map.current_region, &"village", "the Holderkrug lies in the village")
	var lay := MapLayout.of(&"village", cfg)
	assert_eq(map.canvas.player_point, map.canvas.world_to_map(lay.places["v_inn"]), "marker on the inn")
	assert_eq(map.canvas.player_heading, Vector2.ZERO, "no heading inside a room")
	ui.close_all()
	player.region_id = &"village"
	player.interior_id = &"crypt"
	player.global_position = Vector3(60.0, 0.0, -200.0)
	ui.open_map()
	map = _map()
	assert_eq(map.current_region, &"graveyard", "the crypt is on the graveyard")
	assert_eq(map.canvas.player_point, map.canvas.world_to_map(MapLayout.of(&"graveyard", cfg).places["site_crypt"]))


func test_player_marker_is_the_world_position_scaled() -> void:
	await _setup(Vector3(3.0, 0.0, -8.0))
	player.rotation.y = PI * 0.5
	ui.open_map()
	var c := _map().canvas
	var lay := MapLayout.of(&"graveyard", cfg)
	assert_true(c.map_scale > 1.0)
	var expected := c.map_offset + (Vector2(3.0, -8.0) - lay.view.position) * c.map_scale
	assert_almost(c.player_point.x, expected.x, 0.01)
	assert_almost(c.player_point.y, expected.y, 0.01)
	var a := c.world_to_map(Vector2(0.0, 0.0))
	var b := c.world_to_map(Vector2(10.0, 0.0))
	assert_almost(b.x - a.x, 10.0 * c.map_scale, 0.01, "uniform scale")
	assert_almost(c.player_heading.x, 1.0, 0.001, "facing east")
	# The village sheet: region-local (origin 0, 0, 400).
	ui.close_all()
	player.region_id = &"village"
	player.global_position = Vector3(-7.0, 0.0, 404.0)
	ui.open_map()
	c = _map().canvas
	assert_eq(c.player_point, c.world_to_map(Vector2(-7.0, 4.0)))


func test_village_sheet_only_from_village_open() -> void:
	await _setup()
	ui.open_map()
	var map := _map()
	assert_false(map.tab_buttons[&"village"].visible, "no Hollerbrück tab before village_open")
	map.show_region(&"village")
	assert_eq(map.current_region, &"graveyard")
	map.turn_sheet(1)
	assert_eq(map.current_region, &"graveyard")
	ui.close_all()
	GameState.set_flag(&"village_open", true)
	ui.open_map()
	map = _map()
	assert_true(map.tab_buttons[&"village"].visible)
	map.turn_sheet(1)
	assert_eq(map.current_region, &"village")
	assert_true(map.canvas.player_point == Vector2.INF, "the gravekeeper is not in the village")


# --- sections, buildings, graves ------------------------------------------------------------

func test_locked_sections_are_hidden_or_faded() -> void:
	await _setup()
	ui.open_map()
	var c := _map().canvas
	assert_eq(c.section_view[&"yard"], &"open")
	assert_eq(c.labels["yard"], "Alter Hof")
	assert_eq(c.section_view[&"east"], &"locked", "Ostwiese not cleared yet")
	assert_eq(c.labels["east"], "Ostwiese", "known, just not cleared")
	assert_eq(c.labels["elder"], "?", "behind the locked Pförtchen: unknown")
	assert_eq(c.section_view[&"linden"], &"hidden", "Lindenacker before linden_granted: nothing")
	assert_false(c.labels.has("linden"))
	for g: Dictionary in MapLayout.of(&"graveyard", cfg).graves:
		if g.section != &"yard":
			assert_false(c.shown_graves.has(g.id), "no graves in locked sections: " + str(g.id))
	assert_false(c.labels.has("obs_c_gate") and c.section_view[&"churchyard"] == &"hidden")
	ui.close_all()
	GameState.set_flag(&"linden_granted", true)
	ui.open_map()
	c = _map().canvas
	assert_eq(c.section_view[&"linden"], &"locked", "granted: drawn faded")
	assert_eq(c.labels["linden"], "Lindenacker")


func test_graves_by_state() -> void:
	var lay := MapLayout.of(&"graveyard", cfg)
	var c := MapCanvas.new()
	c.size = Vector2(1500.0, 860.0)
	tree.root.add_child(c)
	var ctx := {"sections": {&"yard": {"name": "Alter Hof", "unlocked": true, "known": true}},
			"graves": {"plot_01": &"free", "plot_02": &"taken", "plot_03": &"tended", "old_01": &"taken"}}
	c.show_region(&"graveyard", lay, ctx, cfg)
	assert_eq(c.shown_graves["plot_01"], &"free")
	assert_eq(c.shown_graves["plot_02"], &"taken")
	assert_eq(c.shown_graves["plot_03"], &"tended")
	assert_eq(c.tooltip_at(c.world_to_map(lay.places["plot_03"])), "Gepflegtes Grab mit Grabzeichen")
	assert_eq(MapState.grave_kind(GraveRecord.State.DUG), &"free")
	assert_eq(MapState.grave_kind(GraveRecord.State.FILLED), &"taken")
	assert_eq(MapState.grave_kind(GraveRecord.State.OLD), &"taken")
	assert_eq(MapState.grave_kind(GraveRecord.State.MARKED), &"tended")
	assert_eq(MapState.grave_kind(GraveRecord.State.LOCKED), &"locked")


func test_every_building_of_both_layouts_is_labelled() -> void:
	GameState.set_flag(&"buildings_open", true)
	GameState.set_flag(&"village_open", true)
	await _setup()
	ui.open_map()
	var map := _map()
	for region: StringName in [&"graveyard", &"village"]:
		map.show_region(region)
		assert_eq(map.current_region, region)
		var data := MapLayout.read_json(cfg.layouts[region])
		var ids: Array[String] = []
		if region == &"village":
			for b: Variant in data.buildings:
				ids.append(str(b.id))
			for p: Variant in data.props:
				if cfg.village_landmarks.has(str(p.id)):
					ids.append(str(p.id))
		else:
			ids.append("hut")
			for s: Variant in data.buildings.sites:
				ids.append(str(s.id))
			ids.append("road_exit")
		assert_true(ids.size() >= 4, String(region))
		for id: String in ids:
			assert_true(str(map.canvas.labels.get(id, "")) != "", "%s: '%s' labelled" % [region, id])
			assert_true(id in map.canvas.shown_buildings or map.canvas.labels.has(id), id)
	map.show_region(&"graveyard")
	for key: String in ["road", "forest", "workyard"]:
		assert_true(map.canvas.labels.has(key), key)
	assert_eq(map.canvas.labels["obs_c_gate"], "Kirchpforte")
	map.show_region(&"village")
	for key: String in ["anger", "brook"]:
		assert_true(map.canvas.labels.has(key), key)


func test_graveyard_buildings_only_from_buildings_open() -> void:
	await _setup()
	ui.open_map()
	var c := _map().canvas
	assert_true("hut" in c.shown_buildings)
	assert_false("site_crypt" in c.shown_buildings, "no crypt before buildings_open")


# --- people, orders, shops ------------------------------------------------------------------

func test_people_orders_and_shop_hours() -> void:
	var lay := MapLayout.of(&"village", cfg)
	var c := MapCanvas.new()
	c.size = Vector2(1500.0, 860.0)
	tree.root.add_child(c)
	var hours := MapState.shop_hours(Database.schedule(&"smith") as NpcSchedule)
	assert_true(not hours.is_empty(), "the smith keeps shop hours")
	var ctx := {
		"region": &"village", "flags": {&"village_open": true},
		"people": [
			{"id": &"innkeeper", "name": "Rosine Wackernagel", "kind": &"villager", "region": &"village", "world": Vector3(240.0, 0.0, -200.0)},
			{"id": &"carter", "name": "Osric Faulhaber", "kind": &"carter", "region": &"village", "world": Vector3(19.0, 0.0, 408.0)},
			{"id": &"carter", "name": "Osric Faulhaber", "kind": &"carter", "region": &"graveyard", "world": Vector3(1.0, 0.0, 8.0)},
		],
		"orders": [MapState.order_place(load("res://data/orders/o_esch_charcoal.tres") as OrderData, cfg)],
		"shops": {&"smith": {"open": true, "hours": hours, "keeper": "Ulrich Esch"}},
	}
	c.show_region(&"village", lay, ctx, cfg)
	var rosine := c.person_marker(&"innkeeper")
	assert_eq(rosine.get("point"), c.world_to_map(lay.building("v_inn").door), "inside the inn: at its door")
	assert_true(rosine.get("inside", false))
	assert_eq(rosine.get("name"), "Rosine")
	var osric := c.person_marker(&"carter")
	assert_eq(osric.get("point"), c.world_to_map(Vector2(19.0, 8.0)), "only the village Osric on this sheet")
	assert_eq(c.markers.filter(func(m: Dictionary) -> bool: return m.kind == &"carter").size(), 1)
	var seals := c.order_markers()
	assert_eq(seals.size(), 1, "Esch's order at the smithy")
	assert_true(str(seals[0].text).begins_with("Auftrag: "))
	var tip := c.tooltip_at(c.world_to_map(lay.places["v_smithy"]))
	assert_true(tip.begins_with("Schmiede"), tip)
	assert_true(tip.contains("Ulrich Esch") and tip.contains("Laden: ") and tip.contains("Jetzt geöffnet"), tip)
	var inn_tip := c.tooltip_at(c.world_to_map(lay.places["v_inn"]) + Vector2(30.0, 30.0))
	assert_true(inn_tip.contains("Tür offen"), "house door hours: " + inn_tip)


func test_unknown_villagers_are_not_listed() -> void:
	await _setup()
	var rel := Relationships.new()
	tree.root.add_child(rel)
	var people := MapState.people(tree, cfg)
	for p: Dictionary in people:
		assert_true(cfg.known_people.has(p.id) or rel.met(p.id), "only known people: " + str(p.id))


func test_legend_toggles() -> void:
	await _setup()
	ui.open_map()
	var map := _map()
	assert_true(map.legend.visible)
	map.toggle_legend()
	assert_false(map.legend.visible)
	assert_eq(map.legend_button.text, MapPanel.TEXT_LEGEND_ON)
	map.toggle_legend()
	assert_true(map.legend.visible)
	await wait_frames(2)


# --- G7 Runde 2: performance -------------------------------------------------------------------

func test_static_sheet_is_baked_once_and_only_on_change() -> void:
	await _setup()
	ui.open_map()
	await wait_frames(2)
	var c := _map().canvas
	var bakes := c.bake_count
	var paints := c.paint_count
	assert_true(bakes >= 1 and paints >= 1, "the first sheet is baked and painted (%d / %d)" % [bakes, paints])
	assert_not_null(c.baked_texture(&"graveyard"), "the sheet is a texture")
	ui.close_all()
	await wait_frames(1)
	for i: int in 3:
		ui.open_map()
		await wait_frames(2)
		ui.close_all()
		await wait_frames(1)
	assert_eq(c.bake_count, bakes, "re-opening with the same state bakes nothing")
	assert_eq(c.paint_count, paints, "… and paints no sheet")
	ui.open_map()
	await wait_frames(2)
	var key := c.static_key()
	c.show_region(c.region, c.layout, c.ctx, c.cfg)
	assert_eq(c.static_key(), key)
	assert_eq(c.bake_count, bakes, "a refresh (people moved) only redraws the markers")
	ui.close_all()
	GameState.set_flag(&"linden_granted", true)
	ui.open_map()
	await wait_frames(2)
	assert_eq(c.bake_count, bakes + 1, "a section granted: the sheet is baked again, once")
	assert_eq(c.paint_count, paints + 1)


func test_map_is_prepared_before_the_first_open() -> void:
	await _setup()
	ui.prepare_map()
	await wait_frames(1)
	var map := _map()
	assert_false(map.is_open, "preparing does not open the map")
	assert_false(map.visible)
	assert_true(map.canvas.bake_count >= 1, "the graveyard sheet is baked ahead")
	assert_true(map.canvas.baking(), "… spread over frames, one layer at a time")
	assert_eq(map.canvas.paint_count, 0, "no frame paints the whole sheet")
	for i: int in MapCanvas.LAYERS + 2:
		await wait_frames(1)
	assert_false(map.canvas.baking())
	assert_true(map.canvas.paint_count >= 1, "… and painted while hidden")
	var bakes := map.canvas.bake_count
	ui.open_map()
	await wait_frames(2)
	assert_eq(map.canvas.bake_count, bakes, "the first M bakes nothing")
	ui.close_all()


func test_paper_comes_from_the_baked_asset() -> void:
	var path := MapPaint.paper_asset_path(cfg.paper, cfg.paper_dark)
	assert_true(ResourceLoader.exists(path), "tools/map/bake_map_paper.gd wrote %s" % path)
	var tex := MapPaint.paper(cfg)
	assert_eq(tex.resource_path, path, "no paper computed at runtime")
	var img := (load(path) as Texture2D).get_image()
	assert_eq(img.get_size(), MapPaint.PAPER_SIZE)
	var fresh := MapPaint.paper_image(cfg.paper, cfg.paper_dark)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(210, 150), Vector2i(419, 299), Vector2i(57, 233)]:
		var a := img.get_pixelv(p)
		var b := fresh.get_pixelv(p)
		assert_true(absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02, "baked = generated at %s" % p)
