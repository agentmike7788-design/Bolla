extends TestCase
## W-UI Phase 5 (docs/PHASE5_DESIGN.md §6, §7, §10): station panels (title, groups, tool effect,
## kiln status), build-site panel (missing / there), stone panel (grave list + reasons, the text
## with the name, „passt", gilding only with an inscription, preview numbers = Stonemasonry.
## preview, carving, rack and the two-step discard, paging), StonePreview, the tool belt, the
## objective lines, the HUD chapter line, the day summary additions, the chapter panel
## names_in_stone, CemeteryStatus without work areas, Ilse's gold leaf behind its flag and the
## debug commands.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const MASTER_ITEMS := {&"workstone": 3, &"stone": 2, &"iron_fittings": 2, &"clay": 1, &"ink": 1, &"gold_leaf": 1}


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false
	var actions: Array = []

	func is_busy() -> bool:
		return busy

	## Runs the action at once (the timed part is the Player's business).
	func start_timed_action(label: String, minutes: int, on_done: Callable, cancellable: bool = true, _anim: StringName = &"") -> bool:
		actions.append([label, minutes, cancellable])
		on_done.call()
		return true

	func tool_tier(kind: StringName) -> int:
		return ToolRules.tier(inventory, kind)


class SiteDouble extends Node3D:
	var station_id: StringName = &"forge"
	var calls: Array = []

	func block_reason(inv: Inventory) -> String:
		return WorkshopRules.build_block_reason(Database.station(station_id) as StationData, inv, false, true)

	func request_build() -> void:
		calls.append("build")


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


class NightTradeDouble extends Node:
	var open: bool = false

	func _init() -> void:
		add_to_group(&"night_trade")

	func offers(item_id: StringName) -> bool:
		return item_id != &"gold_leaf" or open

	func is_present() -> bool:
		return true

	func stock_left(_item_id: StringName) -> int:
		return 2


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var world: Node3D
var graveyard: Graveyard
var corpses: CorpseManager
var masonry: Stonemasonry
var shop: Workshop


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	Debug.reset()


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	for node: Node in [world, player]:
		if is_instance_valid(node):
			node.queue_free()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	await wait_frames(1)


# --- station panels -------------------------------------------------------------------------

func test_station_panels_title_and_groups() -> void:
	await _setup()
	for spec: Array in [[&"forge", "Esse", ["Werkstoffe", "Werkzeug"]], [&"loom", "Webstuhl", ["Werkstoffe", "Grab"]],
			[&"workbench", "Werkbank", ["Werkstoffe", "Werkzeug", "Grab", "Zier"]]]:
		ui.open_panel(&"crafting", {"station": spec[0], "inventory": inv, "player": player})
		var panel := ui.get_panel(&"crafting") as CraftingPanel
		assert_eq(panel.title_label.text, spec[1], String(spec[0]))
		var headers: Array = []
		for child: Node in panel._list.get_children():
			if child is Label:
				headers.append((child as Label).text)
		assert_eq(headers, spec[2], String(spec[0]) + ": Werkstoffe · Werkzeug · Grab · Zier")
		ui.close_top_panel()


func test_tool_recipe_shows_replaced_tool_and_effect() -> void:
	await _setup()
	inv.add_item(&"shovel_iron", 1)
	ui.open_panel(&"crafting", {"station": &"forge", "inventory": inv, "player": player})
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	var master := " · ".join(panel.phase5_details(Database.recipe(&"shovel_master") as RecipeData))
	assert_true(master.contains("ersetzt: Eisenschaufel"), master)
	assert_true(master.contains("Graben 50 → 35 Min"), master)
	var axe := " · ".join(panel.phase5_details(Database.recipe(&"axe_iron") as RecipeData))
	assert_true(axe.contains("Erle fällen: neu · 50 Min"), "the axe opens the alders: " + axe)
	assert_eq(Phase5Texts.tool_effect(&"shovel", 0, 1, Phase5Fixtures.action_config()), "Graben 60 → 50 Min · Bestatten 30 → 25 Min")


func test_kiln_status_in_the_forge_panel() -> void:
	await _setup()
	_world_with_workshop()
	GameState.set_flag(&"workshop_open", true)
	shop.load_state({"built": ["forge"]})
	var charcoal := Database.recipe(&"charcoal") as RecipeData
	TimeManager.set_time(3, 380)
	inv.add_item(&"wood", 4)
	ui.open_panel(&"crafting", {"station": &"forge", "inventory": inv, "player": player})
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	assert_true(" · ".join(panel.phase5_details(charcoal)).contains("läuft allein · 8 Std."))
	assert_eq(panel.reason_text(&"charcoal"), "", "wood there, no job")
	assert_eq(panel.job_text(), "")
	assert_true(shop.start_job(&"forge", charcoal, inv))
	TimeManager.set_time(3, 600)
	panel.refresh()
	assert_eq(panel.job_text(), "fertig um 14:20 · noch 4 Std. 20 Min")
	assert_almost(panel.job_ratio(), 220.0 / 480.0, 0.01)
	assert_eq(panel.reason_text(&"charcoal"), "Hier läuft schon ein Auftrag.")
	assert_true(panel.craft_button(&"charcoal").disabled)
	TimeManager.set_time(3, 900)
	panel.refresh()
	assert_eq(panel.job_text(), "fertig – holen")


# --- build site -----------------------------------------------------------------------------

func test_build_site_panel_missing_and_there() -> void:
	await _setup()
	var site := SiteDouble.new()
	player.add_child(site)
	inv.clear()
	for entry: Array in [[&"stone", 10], [&"clay", 2], [&"iron_fittings", 2], [&"coin", 20]]:
		inv.add_item(entry[0], entry[1])
	ui.open_panel(&"build_site", {"station": &"forge", "station_data": Database.station(&"forge"), "site": site,
			"inventory": inv, "player": player})
	var panel := ui.get_panel(&"build_site") as BuildSitePanel
	assert_eq(panel.title_label.text, "Bauplatz: Esse")
	assert_eq(panel.row_text(&"stone"), "10× Stein 10 / 10")
	assert_eq(panel.row_text(&"clay"), "6× Lehm 2 / 6")
	assert_eq(panel.row_text(&"coin"), "Amboss und Blasebalg · 25 Münzen 20 / 25", "coins as their own row")
	assert_eq(panel.duration_label.text, "2 Std.")
	assert_eq(panel.build_button.text, "Bauen (120 Min)")
	assert_true(panel.build_button.disabled)
	assert_eq(panel.reason_label.text, "Es fehlt: 4 Lehm, 5 Münzen")
	assert_true(panel.picture.texture != null, "station picture (icon renderer)")
	panel.build_button.pressed.emit()
	assert_eq(site.calls, [], "blocked: nothing requested")
	inv.add_item(&"clay", 4)
	inv.add_item(&"coin", 5)
	assert_false(panel.build_button.disabled, "inventory changes refresh")
	assert_eq(panel.reason_label.text, "")
	panel.build_button.pressed.emit()
	assert_eq(site.calls, ["build"])
	assert_false(ui.is_open(&"build_site"), "closes – the build bar takes over")


# --- stone panel ----------------------------------------------------------------------------

func test_stone_panel_grave_list_and_reasons() -> void:
	await _setup()
	_world_with_masonry()
	_marked("plot_01", "Hedwig Rabenstein", &"wooden_cross", 67)
	var best := Phase5Fixtures.design(&"stone_master", &"i_long_road", &"orn_ivy", true)
	best.text = PackedStringArray(["Hedwig Rabenstein", "* 1767", "Ein langer Weg, gut gegangen."])
	graveyard.set_designed_stone("plot_01", best, inv)
	_marked("plot_02", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	_filled("plot_03", "Egbert Kornblum", 71)
	var panel := await _open_stone()
	var list := panel.graves()
	assert_eq(list.size(), 3)
	assert_eq(String(list[0].grave_id), "plot_02", "nameless first")
	assert_eq(String(list[2].grave_id), "plot_01", "the named grave last")
	assert_eq(str(list[2].reason), "Der jetzige Stein ist schon besser.", "no better stone possible")
	assert_true(panel.grave_buttons["plot_01"].get_meta(&"dimmed"), "dimmed with the reason")
	assert_eq(str(list[0].reason), "")
	assert_eq(panel.grave_id, "plot_02", "the first grave that can get a better stone")
	panel.toggle_filter()
	assert_eq(String(panel.graves()[0].grave_id), "plot_01", "by position")
	assert_eq(String(panel.graves()[1].grave_id), "plot_02")


func test_stone_panel_text_fits_gilding_and_preview_numbers() -> void:
	await _setup()
	_world_with_masonry()
	_marked("plot_01", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	var panel := await _open_stone()
	assert_eq(panel.inscription, &"i_long_road", "first fitting template preselected (age 63)")
	assert_eq(Array(panel.inscription_lines(&"i_garden")), ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."])
	assert_eq(panel.fits_text(&"i_garden"), "passt – Geschichte")
	assert_eq(panel.fits_text(&"i_long_road"), "passt – Alter")
	assert_eq(panel.fits_text(&"i_water"), "")
	assert_eq(panel._ins_title.text, "Inschrift für Marthe Quendel")
	panel.select_inscription(&"")
	panel.set_gilded(true)
	assert_false(panel.gilded, "gilding only with an inscription")
	assert_true(panel.gilded_toggle.disabled)
	panel.select_shape(&"stone_master")
	panel.select_inscription(&"i_garden")
	panel.set_gilded(true)
	panel.select_ornament(&"orn_elder")
	assert_true(panel.gilded and not panel.gilded_toggle.disabled)
	var expected := masonry.preview("plot_01", panel.design())
	assert_eq(panel.current_preview, expected, "every number from Stonemasonry.preview")
	assert_eq(panel.quality_label.text, "Grab %d → %d" % [int(expected.quality_before), int(expected.quality_after)])
	var labels: Array = []
	for line: Dictionary in panel.stone_lines():
		labels.append(str(line.label))
	assert_eq(labels, ["Meisterstein", "Inschrift", "Passende Inschrift", "Vergoldet", "Zierde: Holunderdolde"])
	assert_eq(panel._sum_label.text, "Stein: 9 von 9 Punkten")
	assert_eq(panel.carve_button.text, "Stein hauen (205 Min)")
	assert_true(panel.carve_button.disabled)
	assert_true(panel.reason_label.text.begins_with("Es fehlt:"), panel.reason_label.text)
	assert_true(Array(panel.preview.label_texts()).has("Marthe Quendel"), "3D preview shows the real text")
	assert_true(panel._text_label.text.contains("8. Nebelung 1834"))


func test_stone_panel_carves_into_the_rack_and_discards_in_two_steps() -> void:
	await _setup()
	_world_with_masonry()
	_marked("plot_01", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	_marked("plot_02", "Egbert Kornblum", &"wooden_cross", 71)
	for id: Variant in MASTER_ITEMS:
		inv.add_item(id, MASTER_ITEMS[id])
	var panel := await _open_stone()
	panel.select_grave("plot_01", false)
	panel.select_shape(&"stone_master")
	panel.select_inscription(&"i_garden")
	panel.set_gilded(true)
	panel.select_ornament(&"orn_elder")
	assert_false(panel.carve_button.disabled, panel.reason_label.text)
	panel.carve_button.pressed.emit()
	assert_eq(player.actions, [["Stein hauen", 205, false]], "a timed action, not cancellable")
	assert_eq(masonry.ready_stones().size(), 1)
	assert_eq(inv.count(&"workstone"), 0, "material taken")
	assert_eq(panel.rack_label.text, "Ablage: 1/3 fertig")
	for e: Dictionary in panel.graves():
		if String(e.grave_id) == "plot_01":
			assert_eq(str(e.reason), "Ein Stein liegt schon bereit.")
	# A better stone reaches the grave another way → the rack stone „passt nicht mehr".
	var other := Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_ivy", true)
	var c := corpses.get_record(graveyard.get_grave("plot_01").corpse_id)
	other.text = StoneDesignRules.render_text(Database.inscription(&"i_garden") as InscriptionData, c, masonry.config)
	graveyard.set_designed_stone("plot_01", other, inv)
	panel.refresh()
	var order := String(masonry.ready_stones()[0].id)
	assert_false(bool(masonry.ready_stones()[0].fits_still))
	assert_true(panel.discard_buttons.has(order), "stale stone offers Verwerfen")
	panel.press_discard(order)
	assert_eq(panel.discard_buttons[order].text, "Wirklich verwerfen?")
	assert_eq(masonry.ready_stones().size(), 1, "first press only asks")
	panel.press_discard(order)
	assert_eq(masonry.ready_stones().size(), 0)
	assert_eq(panel.rack_label.text, "Ablage: 0/3 fertig")


func test_stone_panel_pages_with_journal_keys() -> void:
	await _setup()
	_world_with_masonry(10)
	for i: int in 10:
		_filled("plot_%02d" % (i + 1), "Tote %d" % (i + 1), 40 + i)
	var panel := await _open_stone()
	assert_eq(panel.page_count(), 2)
	assert_eq(panel.grave_buttons.size(), StoneDesignPanel.GRAVES_PER_PAGE)
	_press(&"journal_page_next")
	await wait_frames(1)
	assert_eq(panel.page, 1)
	assert_eq(panel.grave_buttons.size(), 10 - StoneDesignPanel.GRAVES_PER_PAGE)
	_press(&"journal_page_next")
	await wait_frames(1)
	assert_eq(panel.page, 0, "wraps")


func test_stone_preview_renders_on_change_only() -> void:
	var preview := StonePreview.new()
	tree.root.add_child(preview)
	var d := Phase5Fixtures.design(&"stone_stele", &"i_rest")
	d.text = PackedStringArray(["Hier ruht", "Egbert Kornblum", "* 1763 – † 3. Gilbhart 1834"])
	preview.show_design(d)
	assert_eq(preview.render_count, 1)
	assert_eq(preview.viewport.render_target_update_mode, SubViewport.UPDATE_ONCE)
	assert_true(preview.viewport.own_world_3d, "own World3D")
	assert_true(Array(preview.label_texts()).has("Egbert Kornblum") or Array(preview.label_texts()).has("Kornblum"), str(preview.label_texts()))
	preview.show_design(Phase5Fixtures.design(&"stone_stele", &"i_rest", &"", false,
			PackedStringArray(["Hier ruht", "Egbert Kornblum", "* 1763 – † 3. Gilbhart 1834"])))
	assert_eq(preview.render_count, 1, "same design: nothing rebuilt")
	preview.show_design(Phase5Fixtures.design(&"stone_arch"))
	assert_eq(preview.render_count, 2)
	assert_eq(preview.label_texts().size(), 0, "no inscription")
	preview.show_design(null)
	assert_null(preview.stone)
	preview.queue_free()


# --- tool belt ------------------------------------------------------------------------------

func test_inventory_panel_tool_belt() -> void:
	await _setup()
	var belt := Inventory.new()
	belt.slot_count = 20
	belt.tool_belt = true
	player.add_child(belt)
	for id: StringName in [&"shovel_master", &"pickaxe_iron", &"rake", &"comb"]:
		belt.add_item(id, 1)
	belt.add_item(&"wood", 3)
	ui.open_panel(&"inventory", {"inventory": belt})
	var panel := ui.get_panel(&"inventory") as InventoryPanel
	assert_eq(panel.shown_slots().size(), 20)
	assert_eq(panel._grid.columns, 5, "5 × 4")
	assert_eq(panel.shown_slots()[0], {"id": &"wood", "amount": 3}, "tools are not in the slots")
	var e := panel.belt_entries()
	assert_eq([e[&"shovel"].name, e[&"shovel"].tier], ["Meisterschaufel", 2])
	assert_eq([e[&"axe"].name, e[&"axe"].tier], ["Altes Beil", 0], "tier 0 by its old name")
	assert_eq([e[&"pickaxe"].name, e[&"pickaxe"].tier], ["Alte Spitzhacke", 1])
	assert_true(e.has(&"rake") and e.has(&"comb"), "care tools beside them")
	assert_true(str(e[&"shovel"].tooltip).contains("Graben dauert 35 statt 60 Minuten."), str(e[&"shovel"].tooltip))
	assert_true(str(e[&"axe"].tooltip).contains("Erle fällen: 50 Minuten – geht erst mit Holzfälleraxt."), str(e[&"axe"].tooltip))
	assert_true(str(e[&"pickaxe"].tooltip).contains("Nächste Stufe: Meisterhacke"), str(e[&"pickaxe"].tooltip))
	ui.close_top_panel()
	var plain := Inventory.new()
	player.add_child(plain)
	ui.open_panel(&"inventory", {"inventory": plain})
	assert_false(panel._belt_box.visible, "no belt row for an inventory without belt")


# --- objective / HUD --------------------------------------------------------------------------

func test_objective_lines_phase5() -> void:
	var flags := {&"cemetery_complete": true}
	var base := {"p5": true, "license": true, "bruch_open": true, "quarry_open": true, "sites": [], "kiln_ready": false,
			"stone_ready": "", "tiers": {&"shovel": 1, &"axe": 1, &"pickaxe": 2}, "goal_tiers": {&"shovel": 1, &"axe": 1, &"pickaxe": 2},
			"goal_missing": PackedStringArray(), "goal_done": true, "nameless": 0}
	var cases: Array = [
		[{"license": false}, "Sprich mit Osric über den Bruch"],
		[{"bruch_open": false}, "Ostpforte aufschließen"],
		[{"sites": [{"id": &"mason", "name": "Steinmetzbank", "affordable": false}, {"id": &"loom", "name": "Webstuhl", "affordable": true}]},
				"Bauplatz: Webstuhl bauen"],
		[{"sites": [{"id": &"forge", "name": "Esse", "affordable": false}]}, "Bauplatz: Esse bauen"],
		[{"quarry_open": false, "tiers": {&"pickaxe": 0}}, "Findlinge brechen – Spitzhacke nötig"],
		[{"quarry_open": false, "tiers": {&"pickaxe": 1}}, "Findlinge brechen"],
		[{"kiln_ready": true, "license": false}, "Holzkohle ist fertig"],
		[{"stone_ready": "Marthe Quendel", "license": false}, "Ein Stein liegt bereit – setz ihn bei Marthe Quendel"],
		[{"goal_done": false, "goal_missing": PackedStringArray(["pickaxe"]), "tiers": {&"shovel": 1, &"axe": 1, &"pickaxe": 1}},
				"Werkzeug: Schaufel 1/1 · Axt 1/1 · Spitzhacke 1/2"],
		[{"goal_done": false, "goal_missing": PackedStringArray(["stone_master"])}, "Setz den Meisterstein"],
		[{"nameless": 11}, "Gräber ohne Namen: 11"],
	]
	for c: Array in cases:
		var world := base.duplicate(true)
		world.merge(c[0], true)
		assert_eq(ObjectiveResolver.current([], [], null, 600, flags, world), c[1], str(c[0]))
	assert_eq(ObjectiveResolver.current([], [], null, 600, flags, base), ObjectiveResolver.TEXT_REST, "all done, nothing nameless: rest")
	var weeds := base.duplicate(true)
	weeds.merge({"license": false, "weeds": 3}, true)
	assert_eq(ObjectiveResolver.current([], [], null, 600, flags, weeds), "Unkraut jäten (3 Stellen)", "tending first")


func test_hud_chapter_line_in_the_quality_tooltip() -> void:
	assert_eq(Phase5Texts.chapter_line({"stations": [2, 3], "tools": [2, 3], "master": [0, 1]}), "Werkhof 2/3 · Werkzeug 2/3 · Meisterstein 0/1")
	assert_eq(Phase5Texts.chapter_line({}), "")
	await _setup()
	_world_with_workshop()
	var hud := ui.hud
	assert_false(hud.quality_tooltip_text(CemeteryStatus.score(tree)).contains("Werkhof"), "closed: no chapter line")
	GameState.set_flag(&"workshop_open", true)
	shop.load_state({"built": ["mason", "loom"]})
	inv.add_item(&"shovel_iron", 1)
	EventBus.station_built.emit(&"loom")
	assert_true(hud.quality_tooltip().contains("Werkhof 2/3 · Werkzeug"), hud.quality_tooltip())
	assert_true(hud.quality_tooltip().contains("Meisterstein 0/1"))


func test_cemetery_status_lists_burial_sections_only() -> void:
	var expansion := ExpansionManager.new()
	tree.root.add_child(expansion)
	var ids: Array = []
	for s: Dictionary in CemeteryStatus.sections(tree):
		ids.append(s.id)
	assert_false(ids.has(&"bruch") or ids.has(&"quarry"), str(ids))
	assert_true(ids.has(&"yard"), str(ids))
	var real: Array = []
	for s: SectionData in expansion.sections():
		real.append(s.id)
	assert_true(real.has(&"bruch"), "the work areas exist in the data")
	expansion.free()


# --- summaries --------------------------------------------------------------------------------

func test_day_summary_gathered_crafted_built_spent() -> void:
	await _setup()
	EventBus.resource_gathered.emit("gather_alder_1", &"wood", 4)
	EventBus.resource_gathered.emit("gather_alder_2", &"wood", 2)
	EventBus.resource_gathered.emit("gather_flax_1", &"flax", 3)
	EventBus.station_built.emit(&"loom")
	EventBus.coins_spent.emit(15, &"build")
	EventBus.coins_spent.emit(12, &"osric")
	GameState.add_stat(&"crafted", 2)
	ui.open_panel(&"day_summary", {"day": 21, "burials_today": 0, "coins_today": -27, "total": 180, "rating": &"venerable"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.row_text(panel.gathered_label), "6 Holz, 3 Flachs")
	assert_eq(panel.row_text(panel.crafted_label), "2")
	assert_eq(panel.row_text(panel.built_label), "Webstuhl")
	assert_eq(panel.row_text(panel.spent_label), "27 Münzen (Bau 15 · Osric 12)")
	ui.close_top_panel()
	ui.open_panel(&"day_summary", {"day": 22, "burials_today": 0, "coins_today": 0, "total": 180, "rating": &"venerable"})
	assert_eq(panel.row_text(panel.spent_label), "", "a new day starts empty")
	assert_false(panel.gathered_label.visible)


func test_chapter_panel_names_in_stone() -> void:
	await _setup()
	var ctx := {"variant": &"names_in_stone", "chapter": &"names_in_stone", "workshop_days": 7, "stations": [&"mason", &"loom", &"forge"],
			"tool_tiers": {&"shovel": 2, &"axe": 1, &"pickaxe": 2}, "stones_set": 6, "master_stones": 1, "named_graves": 7,
			"graves_total": 18, "coins_spent": {&"license": 20, &"build": 50, &"osric": 32, &"ilse": 12}, "content_before": 4,
			"content_now": 9, "final_line": "Die Namen stehen jetzt da, wo der Regen sie nicht wegwäscht."}
	ui.open_panel(&"slice_summary", ctx)
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Namen in Stein")
	assert_true(panel.stone_grid.visible and not panel.chapter_grid.visible and not panel._cemetery_grid.visible)
	assert_eq(panel.stone_value("Tage seit dem Werkhof"), "7")
	assert_eq(panel.stone_value("Stationen"), "Steinmetzbank, Webstuhl, Esse")
	assert_eq(panel.stone_value("Werkzeug"), "Meisterschaufel · Holzfälleraxt · Meisterhacke")
	assert_eq(panel.stone_value("Steine gesetzt"), "6 (davon 1 Meisterstein)")
	assert_eq(panel.stone_value("Gräber mit Namen"), "7/18")
	assert_eq(panel.stone_value("Ausgaben seit dem Werkhof"), "114 Münzen (Brief 20 · Bau 50 · Osric 32 · Ilse 12)")
	assert_eq(panel.stone_value("Zufriedene Geister"), "4 → 9")
	assert_eq(panel.goal_label.text, "Die Namen stehen jetzt da, wo der Regen sie nicht wegwäscht.")
	ui.close_top_panel()
	ui.open_panel(&"slice_summary", {"variant": &"six_pits", "days": 19})
	assert_false(panel.stone_grid.visible, "other variants unchanged")


func test_trader_hides_gold_leaf_before_the_workyard() -> void:
	await _setup()
	var trade := NightTradeDouble.new()
	player.add_child(trade)
	ui.open_panel(&"trader", {"inventory": inv})
	var panel := ui.get_panel(&"trader") as TraderPanel
	assert_true(panel.buy_rows.has(&"gold_leaf"))
	assert_false((panel.buy_rows[&"gold_leaf"].row as Control).visible, "not offered yet")
	assert_true((panel.buy_rows[&"linen"].row as Control).visible)
	trade.open = true
	panel.refresh()
	assert_true((panel.buy_rows[&"gold_leaf"].row as Control).visible, "offered from workshop_open on")


# --- debug ----------------------------------------------------------------------------------

func test_debug_commands_without_world() -> void:
	for command: String in ["workshop open", "build all", "tool axe 1", "gather refill", "regrow 2", "job done", "goal",
			"stone plot_01 stone_stele", "coins 5"]:
		var r := Debug.execute(command)
		assert_false(r.ok, command)
		assert_true(str(r.text).contains("Keine Spielwelt"), command + ": " + str(r.text))
	assert_eq(str(Debug.execute("calendar 1").text), "Tag 1: † 3. Gilbhart 1834")
	assert_eq(str(Debug.execute("calendar 37").text), "Tag 37: † 8. Nebelung 1834")
	for bad: String in ["build nothing", "tool axe 3", "tool hammer 1", "regrow 0", "calendar x", "stones", "job"]:
		assert_false(Debug.execute(bad).ok, bad)
	var help := str(Debug.execute("help").text)
	assert_true(help.contains("stones showcase") and help.contains("tp <bruch|quarry|schlag|workyard>"))


func test_debug_workshop_build_tool_goal_coins() -> void:
	await _setup()
	_world_with_workshop()
	assert_true(Debug.execute("workshop open").ok)
	assert_true(shop.is_open())
	assert_true(Debug.execute("license").ok)
	assert_eq(GameState.get_flag(&"bruch_license"), true)
	var built: Array = []
	EventBus.station_built.connect(func(id: StringName) -> void: built.append(id))
	assert_true(Debug.execute("build loom").ok)
	assert_true(shop.is_built(&"loom"))
	assert_true(Debug.execute("build all").ok)
	assert_eq(shop.built().size(), 3)
	assert_eq(built, [&"loom", &"mason", &"forge"], "station_built once each")
	assert_true(Debug.execute("tool pickaxe 2").ok)
	assert_eq(ToolRules.tier(inv, &"pickaxe"), 2)
	assert_true(Debug.execute("tool pickaxe 0").ok)
	assert_eq(ToolRules.tier(inv, &"pickaxe"), 0)
	assert_true(Debug.execute("tool shovel 1").ok)
	var goal := str(Debug.execute("goal").text)
	assert_true(goal.contains("Werkhof 3/3 · Werkzeug 1/3 · Meisterstein 0/1"), goal)
	assert_true(Debug.execute("coins 42").ok)
	assert_eq(inv.count(&"coin"), 42)
	assert_true(Debug.execute("coins 3").ok)
	assert_eq(inv.count(&"coin"), 3)
	assert_false(Debug.execute("job done").ok, "no job runs")
	TimeManager.set_time(2, 400)
	inv.add_item(&"wood", 4)
	assert_true(shop.start_job(&"forge", Database.recipe(&"charcoal") as RecipeData, inv))
	assert_true(Debug.execute("job done").ok)
	assert_true(bool(shop.job_of(&"forge").ready))


func test_debug_gather_and_stone() -> void:
	await _setup()
	_world_with_masonry()
	var gm := GatherManager.new()
	world.add_child(gm)
	gm.register("gather_flax_1", Database.gather_kind(&"flax_bed") as GatherNodeData)
	gm.register("gather_clay", Database.gather_kind(&"clay_pit") as GatherNodeData)
	TimeManager.set_time(5, 600)
	assert_true(Debug.execute("gather empty gather_flax_1").ok)
	assert_eq(gm.charges("gather_flax_1"), 0)
	assert_eq(gm.charges("gather_clay"), 3, "only the named node")
	assert_false(Debug.execute("gather empty nowhere").ok)
	assert_true(Debug.execute("regrow 1").ok)
	assert_eq(gm.charges("gather_flax_1"), 0, "flax needs 3 days")
	assert_true(Debug.execute("regrow 2").ok)
	assert_eq(gm.charges("gather_flax_1"), 1, "3 days → full")
	assert_true(Debug.execute("gather empty all").ok)
	assert_true(Debug.execute("gather refill").ok)
	assert_eq(gm.charges("gather_clay"), 3)
	_marked("plot_01", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	var r := Debug.execute("stone plot_01 stone_master i_garden orn_elder gold")
	assert_true(r.ok, str(r.text))
	var grave := graveyard.get_grave("plot_01")
	assert_eq(grave.marker_id, &"stone_master")
	assert_eq(StoneDesign.from_dict(grave.design).text[0], "Marthe Quendel", "text filled in like carving")
	assert_eq(str(Debug.execute("stone plot_01 stone_stele").text), "Der jetzige Stein ist schon besser.", "same rules")
	assert_false(Debug.execute("stone plot_01 stone_stele - - gold").ok, "gold needs an inscription")
	assert_false(Debug.execute("stone plot_09 stone_stele").ok)
	assert_eq(DebugCommandsPhase5.showcase_designs().size(), 6, "3 shapes × ink/gold")


# --- helpers ----------------------------------------------------------------------------------

func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	player.add_to_group(&"player")
	inv = Inventory.new()
	inv.slot_count = 20
	inv.tool_belt = true
	inv.name = "Inventory"
	player.add_child(inv)
	player.inventory = inv
	tree.root.add_child(player)
	ui = await add_scene(UI_SCENE) as UIRoot


func _world_with_workshop() -> void:
	if world == null:
		world = Node3D.new()
		world.name = "P5World"
		tree.root.add_child(world)
	shop = Workshop.new()
	shop.name = "Workshop"
	world.add_child(shop)


## Graveyard + corpses + Stonemasonry with the Phase-5 fixtures and `plots` plot doubles.
func _world_with_masonry(plots: int = 5) -> void:
	var tables := load(FIXTURE_TABLES) as CorpseTables
	var eco := Phase5Fixtures.economy_config()
	world = Node3D.new()
	world.name = "P5World"
	var container := Node3D.new()
	container.name = "Corpses"
	world.add_child(container)
	corpses = CorpseManager.new()
	corpses.tables = tables
	corpses.economy = eco
	corpses.container_path = ^"../Corpses"
	world.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = eco
	graveyard.tables = tables
	graveyard.section_data = Phase3Fixtures.sections()
	graveyard.reputation_config = Phase5Fixtures.reputation_config()
	graveyard.stone_config = Phase5Fixtures.stone_config()
	world.add_child(graveyard)
	for i: int in plots:
		var plot := PlotDouble.new()
		plot.grave_id = "plot_%02d" % (i + 1)
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	masonry = Stonemasonry.new()
	masonry.config = Phase5Fixtures.stone_config()
	masonry.workshop_config = Phase5Fixtures.workshop_config()
	world.add_child(masonry)
	tree.root.add_child(world)


func _open_stone() -> StoneDesignPanel:
	ui.open_panel(&"stone_design", {"inventory": inv, "player": player})
	await wait_frames(1)
	return ui.get_panel(&"stone_design") as StoneDesignPanel


func _corpse(name: String, age: int, story: StringName, day: int) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = name
	r.cause_id = &"fever"
	r.age = age
	r.story_id = story
	r.shrouded = true
	r.examined = true
	var spawned := corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	spawned.arrival_total_minutes = (day - 1) * 1440 + 460
	return spawned


func _filled(grave_id: String, name: String, age: int = 50, story: StringName = &"", day: int = 1) -> CorpseRecord:
	var r := _corpse(name, age, story, day)
	graveyard.dig(grave_id)
	graveyard.bury(grave_id, r.id)
	return r


func _marked(grave_id: String, name: String, marker: StringName, age: int = 50, story: StringName = &"", day: int = 1) -> CorpseRecord:
	var r := _filled(grave_id, name, age, story, day)
	var purse := FakeInventory.new()
	purse.add_item(marker, 1)
	graveyard.place_marker(grave_id, marker, purse)
	purse.free()
	return r


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		tree.root.push_input(ev)
