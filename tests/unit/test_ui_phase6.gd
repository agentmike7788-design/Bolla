extends TestCase
## W-UI Phase 6 (docs/PHASE6_DESIGN.md §6, §7, §10): building panel (three level cards, have / need,
## coin row, pips, fetch from the shed, maxed), chapel panel (checklist, reasons and values =
## ChapelRites / ChapelRules), devotion panel (graves, the cap of robbed souls, reasons), the exam
## panel's table title and cold line, the shed rows of the station and build-site panels, the shed
## chest (larger grid, × 2 stacks), the HUD chapter and grave lines, the objective lines, the day
## summary additions, the chapter panel roof_and_earth and the debug commands.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const SHED_SCENE := "res://src/entities/shed_store/shed_store.tscn"
const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const CRYPT_2 := {&"workstone": 4, &"stone": 8, &"clay": 4, &"iron_bar": 1}


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false

	func is_busy() -> bool:
		return busy


class SiteDouble extends Node3D:
	var building_id: StringName = &"crypt"
	var lvl: int = 1
	var calls: Array = []

	func level() -> int:
		return lvl

	func block_reason(inv: Inventory) -> String:
		return BuildingRules.upgrade_block_reason(Database.building(building_id) as BuildingData, lvl, inv, true)

	func request_upgrade() -> void:
		calls.append("upgrade")

	func request_fetch() -> void:
		calls.append("fetch")


class BenchDouble extends Node3D:
	var calls: Array = []

	func request_craft(id: StringName) -> void:
		calls.append(["craft", id])

	func request_fetch(needs: Dictionary) -> void:
		calls.append(["fetch", needs])

	func request_store() -> void:
		calls.append(["store"])


class AltarDouble extends Node3D:
	var calls: Array = []

	func request_service() -> void:
		calls.append("service")

	func request_devotion(grave_id: String) -> void:
		calls.append(grave_id)


class TableDouble extends Node3D:
	var title: String = "Gruft-Tisch"

	func panel_title() -> String:
		return title


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var world: Node3D
var buildings: Buildings
var shed: ShedStore
var corpses: CorpseManager
var graveyard: Graveyard
var rites: ChapelRites


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	Debug.reset()


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	for node: Node in [world, player, buildings, shed]:
		if is_instance_valid(node):
			node.queue_free()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	await wait_frames(1)


# --- building panel -------------------------------------------------------------------------

func test_building_panel_cards_costs_and_button() -> void:
	await _setup()
	_buildings({&"crypt": 1})
	var site := _site(&"crypt", 1)
	inv.add_item(&"coin", 12)
	inv.add_item(&"stone", 8)
	var panel := _open_building(site)
	assert_eq(panel.title_label.text, "Gruft")
	assert_eq(panel.pips_label.text, "●○○  Stufe 1 von 3")
	assert_eq([panel.card_state(1), panel.card_state(2), panel.card_state(3)], [&"done", &"next", &"later"])
	assert_eq(panel.cards_box.get_child_count(), 3, "three cards side by side")
	assert_eq(panel.row_text(&"stone"), "8× Stein 8 / 8")
	assert_eq(panel.row_text(&"workstone"), "4× Werkstein 0 / 4")
	assert_eq(panel.row_text(&"coin"), "Schieferplatten für die Nischen · 30 Münzen 12 / 30")
	assert_eq(panel.costs_caption.text, "Was Stufe 2 braucht")
	assert_eq(panel.build_button.text, "Stufe 2 bauen (210 Min)")
	assert_true(panel.build_button.disabled)
	assert_true(panel.reason_label.text.begins_with("Es fehlt: "), panel.reason_label.text)
	assert_true(panel.reason_label.text.contains("18 Münzen"), panel.reason_label.text)
	assert_false(panel.shed_bar.visible, "no shed yet: no fetch row")
	for id: StringName in CRYPT_2:
		inv.add_item(id, int(CRYPT_2[id]))
	inv.add_item(&"coin", 18)
	assert_false(panel.build_button.disabled, "refreshes on inventory changes")
	assert_eq(panel.reason_label.text, "")
	panel.build_button.pressed.emit()
	assert_eq(site.calls, ["upgrade"])
	assert_false(panel.is_open, "building closes the panel")


func test_building_panel_level_zero_and_maxed() -> void:
	await _setup()
	_buildings({})
	var site := _site(&"chapel", 0)
	var panel := _open_building(site)
	assert_eq(panel.pips_label.text, "○○○  Bauplatz · Stufe 0 von 3")
	assert_eq([panel.card_state(1), panel.card_state(2)], [&"next", &"later"])
	assert_eq(panel.build_button.text, "Stufe 1 bauen (240 Min)")
	assert_eq(panel.row_text(&"coin"), "Dachschiefer · 25 Münzen 0 / 25")
	ui.close_top_panel()
	site.lvl = 3
	panel = _open_building(site)
	assert_false(panel.build_button.visible, "fully built: no button")
	assert_false(panel.next_box.visible)
	assert_eq(panel.note_label.text, Phase6Texts.MAXED_NOTE)
	assert_eq([panel.card_state(1), panel.card_state(2), panel.card_state(3)], [&"done", &"done", &"done"])


func test_building_panel_fetch_from_the_shed() -> void:
	await _setup()
	_buildings({&"crypt": 1, &"shed": 2})
	await _shed_store()
	shed.store().add_item(&"workstone", 6)
	shed.store().add_item(&"clay", 4)
	var site := _site(&"crypt", 1)
	var panel := _open_building(site)
	assert_true(panel.shed_bar.visible, "shed 2: the fetch row")
	assert_eq(panel.shed_bar.fetch_button.text, "Fehlendes aus dem Schuppen holen (10 Min)")
	assert_eq(panel.row_text(&"workstone"), "4× Werkstein im Schuppen: 6 0 / 4")
	assert_true(panel.shed_bar.fetch_button.disabled, "the shed lacks stone and iron")
	assert_true(panel.shed_bar.reason_label.text.begins_with("Im Schuppen fehlt:"), panel.shed_bar.reason_label.text)
	assert_false(panel.shed_bar.store_button.visible, "store only from shed 3")
	shed.store().add_item(&"stone", 8)
	shed.store().add_item(&"iron_bar", 1)
	assert_false(panel.shed_bar.fetch_button.disabled, "refreshes on shed changes: " + panel.shed_bar.reason_label.text)
	panel.shed_bar.fetch_button.pressed.emit()
	assert_eq(site.calls, ["fetch"])
	ui.close_top_panel()
	buildings.load_state({"levels": {"crypt": 1, "shed": 3}})
	panel = _open_building(site)
	assert_eq(panel.shed_bar.fetch_button.text, "Fehlendes aus dem Schuppen holen (sofort)")
	assert_true(panel.shed_bar.store_button.visible)


# --- shed rows at the stations --------------------------------------------------------------

func test_crafting_and_build_site_panels_fetch_rows() -> void:
	await _setup()
	_buildings({&"shed": 2})
	await _shed_store()
	shed.store().add_item(&"wood", 5)
	var bench := BenchDouble.new()
	world_node().add_child(bench)
	ui.open_panel(&"crafting", {"station": &"workbench", "inventory": inv, "player": player, "workbench": bench})
	var crafting := ui.get_panel(&"crafting") as CraftingPanel
	var cross := crafting.fetch_button(&"wooden_cross")
	assert_not_null(cross, "wood missing, the shed has it: fetch button")
	assert_eq(cross.text, "Fehlendes holen (10 Min)")
	assert_false(cross.disabled)
	cross.pressed.emit()
	assert_eq(bench.calls[0][0], "fetch")
	assert_eq(int((bench.calls[0][1] as Dictionary).get(&"wood", 0)), int((Database.recipe(&"wooden_cross") as RecipeData).inputs[&"wood"]))
	assert_false(crafting.shed_bar.visible, "store only from shed 3")
	ui.close_top_panel()
	var site := BenchDouble.new()
	world_node().add_child(site)
	ui.open_panel(&"build_site", {"station": &"forge", "station_data": Database.station(&"forge"), "site": site, "inventory": inv, "player": player})
	var bs := ui.get_panel(&"build_site") as BuildSitePanel
	assert_true(bs.shed_bar.visible)
	assert_true(bs.row_text(&"stone").contains("im Schuppen: 0"), bs.row_text(&"stone"))
	assert_true(bs.shed_bar.fetch_button.disabled, "the shed has no stone")
	buildings.load_state({"levels": {"shed": 3}})
	bs.refresh()
	assert_true(bs.shed_bar.store_button.visible)
	bs.shed_bar.store_button.pressed.emit()
	assert_eq(site.calls, [["store"]])


func test_shed_chest_larger_grid_and_double_stacks() -> void:
	await _setup()
	_buildings({&"shed": 3})
	await _shed_store()
	shed.store().add_item(&"stone", 70)
	shed.store().add_item(&"shovel_iron", 1)
	ui.open_panel(&"chest", {"storage": shed.store(), "inventory": inv, "chest": shed})
	var panel := ui.get_panel(&"chest") as ChestPanel
	assert_true(panel.is_shed)
	assert_eq(panel.title_label.text, "Lagerschuppen")
	assert_eq(panel.chest_label.text, "Regal")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_CHEST).size(), 40)
	assert_eq(panel._chest_grid.columns, 8)
	assert_eq(panel.shed_label.text, "Schuppen Stufe 3 · 40 Plätze")
	assert_true(panel.stack_note.visible)
	assert_eq(panel.stack_note.text, "Rohstoffe und Werkstoffe stapeln hier doppelt (× 2).")
	assert_true(panel.doubled(&"stone"))
	assert_false(panel.doubled(&"shovel_iron"), "tools never stack doubled")
	assert_eq(panel.shown_slots(ChestPanel.SIDE_CHEST)[0], {"id": &"stone", "amount": 70}, "one doubled stack")
	var badge := panel.slot_button(ChestPanel.SIDE_CHEST, 0).get_node(^"Badge") as Label
	assert_eq(badge.text, "× 2", "above the normal limit of 50")
	assert_true(panel.slot_button(ChestPanel.SIDE_CHEST, 0).tooltip_text.contains("Stapel bis 100 (× 2)"))
	assert_eq((panel.slot_button(ChestPanel.SIDE_CHEST, 1).get_node(^"Badge") as Label).text, "", "the tool: no badge")
	ui.close_top_panel()
	var chest := Chest.new()
	var storage := Inventory.new()
	storage.name = "Storage"
	chest.add_child(storage)
	world_node().add_child(chest)
	ui.open_panel(&"chest", {"storage": chest.storage, "inventory": inv, "chest": chest})
	assert_false(panel.is_shed)
	assert_eq(panel.title_label.text, "Truhe")
	assert_false(panel.stack_note.visible or panel.shed_label.visible)


# --- chapel & devotion ------------------------------------------------------------------------

func test_chapel_panel_checklist_values_and_reasons() -> void:
	await _setup()
	_world_with_chapel({&"chapel": 2})
	TimeManager.set_time(31, 420)
	var r := _catafalque_corpse("Martha Stein", CorpseRecord.DRESS_GOWN)
	var altar := AltarDouble.new()
	world_node().add_child(altar)
	ui.open_panel(&"chapel", {"corpse_id": r.id, "altar": altar, "inventory": inv, "player": player})
	var panel := ui.get_panel(&"chapel") as ChapelPanel
	assert_eq(panel.name_label.text, "für Martha Stein")
	assert_true(panel.check_ok(&"catafalque") and panel.check_ok(&"dressed") and panel.check_ok(&"fresh"))
	assert_false(panel.check_ok(&"time"), "07:00 is too early")
	assert_false(panel.check_ok(&"candle"))
	assert_eq(panel.block_reason(), ChapelRules.TEXT_DAYTIME)
	assert_eq(panel.reason_label.text, "Die Trauergäste kommen nur bei Tag.")
	assert_true(panel.service_button.disabled)
	var cfg := rites.get_config()
	assert_eq(panel.preview[0], ChapelRites.fee_text(ChapelRules.fee(2, cfg)))
	assert_eq(panel.preview[0], "Die Familie legt 5 Münzen auf den Altar.")
	assert_eq(panel.preview[1], "Ruf +2")
	assert_eq(panel.preview[2], "2 Trauergäste in den Bänken")
	assert_eq(panel.service_button.text, "Aussegnung halten (45 Min)")
	TimeManager.set_time(31, 600)
	panel.refresh()
	assert_eq(panel.reason_label.text, ChapelRules.TEXT_NO_CANDLE)
	inv.add_item(&"altar_candle", 1)
	assert_true(panel.check_ok(&"candle") and panel.check_ok(&"time"))
	assert_false(panel.service_button.disabled)
	panel.service_button.pressed.emit()
	assert_eq(altar.calls, ["service"])
	assert_false(panel.is_open)


func test_chapel_panel_undressed_and_level_one() -> void:
	await _setup()
	_world_with_chapel({&"chapel": 1})
	TimeManager.set_time(31, 600)
	var r := _catafalque_corpse("Paul Egger", CorpseRecord.DRESS_NONE)
	inv.add_item(&"altar_candle", 1)
	var altar := AltarDouble.new()
	world_node().add_child(altar)
	ui.open_panel(&"chapel", {"corpse_id": r.id, "altar": altar, "inventory": inv, "player": player})
	var panel := ui.get_panel(&"chapel") as ChapelPanel
	assert_false(panel.check_ok(&"dressed"))
	assert_eq(panel.block_reason(), ChapelRules.TEXT_DRESS)
	assert_eq(panel.preview[0], "Die Familie legt 3 Münzen auf den Altar.")
	assert_eq(panel.preview[2], Phase6Texts.PREVIEW_NO_MOURNERS)


func test_devotion_panel_rows_cap_and_reasons() -> void:
	await _setup()
	_world_with_chapel({&"chapel": 1})
	_marked("plot_01", "Agnes Kalb", false)
	_marked("plot_02", "Jost Ferber", true)
	var altar := AltarDouble.new()
	world_node().add_child(altar)
	ui.open_panel(&"devotion", {"altar": altar, "inventory": inv, "player": player})
	var panel := ui.get_panel(&"devotion") as DevotionPanel
	assert_eq(panel.rows.size(), 2)
	var robbed := panel.find_row("plot_02")
	assert_true(bool(robbed.capped))
	assert_eq(int(robbed.robbed), 2, "hair and teeth")
	assert_false(bool(panel.find_row("plot_01").capped))
	assert_eq(str(panel.find_row("plot_01").lit_text), "kein Licht")
	assert_eq(panel.list_box.get_child_count(), 2)
	assert_eq(panel.block_reason(), ChapelRules.TEXT_NO_CANDLE)
	inv.add_item(&"altar_candle", 2)
	assert_eq(panel.candles_label.text, "Altarkerzen: 2")
	panel.select("plot_02")
	assert_true(panel.hint_label.visible, "robbed soul: „Mehr als Ruhe kann eine Kerze nicht geben.“")
	assert_eq(panel.hint_label.text, "Mehr als Ruhe kann eine Kerze nicht geben.")
	assert_eq(panel.chosen_label.text, "Gewählt: Jost Ferber")
	assert_false(panel.devotion_button.disabled)
	assert_eq(panel.devotion_button.text, "Andacht halten (30 Min)")
	panel.devotion_button.pressed.emit()
	assert_eq(altar.calls, ["plot_02"])
	assert_true(rites.hold_devotion("plot_01", inv))
	ui.open_panel(&"devotion", {"altar": altar, "inventory": inv, "player": player})
	assert_eq(str(panel.find_row("plot_01").lit_text), "Licht brennt (Stufe 1)")
	panel.select("plot_01")
	assert_eq(panel.block_reason(), ChapelRules.TEXT_LIT)


func test_devotion_rows_restless_first() -> void:
	var entries: Array[Dictionary] = [
		{"grave_id": "a", "name": "A", "mood": &"content", "held_level": 0},
		{"grave_id": "b", "name": "B", "mood": &"restless", "held_level": 0},
		{"grave_id": "c", "name": "C", "mood": &"calm", "held_level": 2},
	]
	var cfg := Phase6Fixtures.chapel_config()
	var rows := Phase6Texts.devotion_rows(entries, {"b": 1}, 2, cfg, true)
	assert_eq([rows[0].grave_id, rows[1].grave_id, rows[2].grave_id], ["b", "c", "a"])
	assert_eq([rows[0].mood_word, rows[1].mood_word, rows[2].mood_word], ["unruhig", "gleichmütig", "zufrieden"])
	assert_true(bool(rows[0].capped))
	assert_eq(str(rows[1].lit_text), "Licht brennt (Stufe 2)")
	assert_eq(str(rows[0].bonus_text), "Stimmung +2")
	var plain := Phase6Texts.devotion_rows(entries, {}, 2, cfg, false)
	assert_eq(plain[0].grave_id, "a", "grave order when not sorted")


# --- exam panel -------------------------------------------------------------------------------

func test_exam_panel_title_and_cold_line() -> void:
	await _setup()
	_world_with_chapel({&"crypt": 2})
	var r := CorpseRecord.new()
	r.display_name = "Ida Brenner"
	r.cause_id = &"fever"
	r.age = 44
	var spawned := corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	assert_true(corpses.put_down(spawned.id, CorpseRecord.LOCATION_TABLE, Transform3D.IDENTITY, null, &"crypt"))
	var table := TableDouble.new()
	world_node().add_child(table)
	ui.open_panel(&"corpse_exam", {"corpse_id": spawned.id, "table": table, "player": player})
	var panel := ui.get_panel(&"corpse_exam") as CorpseExamPanel
	assert_eq(panel.table_label.text, "Gruft-Tisch")
	assert_eq(panel.title_label.text, "Ida Brenner")
	assert_eq(panel.cold_label.text, "Kühle: × 0,7 (Gruft)")
	ui.close_top_panel()
	table.title = "Leichentisch"
	assert_true(corpses.put_down(spawned.id, CorpseRecord.LOCATION_TABLE, Transform3D.IDENTITY, null, &""))
	ui.open_panel(&"corpse_exam", {"corpse_id": spawned.id, "table": table, "player": player})
	assert_eq(panel.table_label.text, "Leichentisch")
	assert_false(panel.cold_label.visible, "outside: no cold")
	assert_eq(Phase6Texts.cold_line(CorpseRecord.LOCATION_NICHE, 0.4), "Nische: × 0,4")


# --- HUD, objective, summaries ------------------------------------------------------------------

func test_chapter_and_graves_lines() -> void:
	var progress := BuildingRules.goal_progress({&"crypt": 2, &"chapel": 1, &"shed": 2}, 1, 3, Phase6Fixtures.buildings_config())
	assert_eq(Phase6Texts.chapter_line(progress), "Gruft 2/2 · Kapelle 1/2 · Schuppen 2/2 · Aussegnung 1/1 · Umbettung 3/1")
	assert_eq(Phase6Texts.chapter_line({}), "")
	assert_eq(Phase6Texts.graves_line({"taken": 21, "free": 2, "old": 2, "old_resting": 2, "reinterred": 4}),
			"Gräber 21 belegt · 2 frei · 2 alt (Ruhezeit) · 4 umgebettet")
	assert_eq(Phase6Texts.graves_line({"taken": 18, "free": 0, "old": 8, "old_resting": 2, "reinterred": 0}),
			"Gräber 18 belegt · 0 frei · 8 alt · 0 umgebettet")
	assert_eq(Phase6Texts.pips(2, 3), "●●○")


func test_hud_tooltip_shows_the_chapter_line_after_buildings_open() -> void:
	await _setup()
	_buildings({&"crypt": 2, &"chapel": 1})
	assert_false(ui.hud.quality_tooltip().contains("Gruft"), "closed: no chapter line")
	GameState.set_flag(&"buildings_open", true)
	EventBus.building_upgraded.emit(&"chapel", 1)
	assert_true(ui.hud.quality_tooltip().contains("Gruft 2/2 · Kapelle 1/2 · Schuppen 0/2 · Aussegnung 0/1 · Umbettung 0/1"),
			ui.hud.quality_tooltip())
	GameState.set_flag(&"roof_and_earth_complete", true)
	EventBus.building_upgraded.emit(&"shed", 2)
	assert_true(ui.hud.quality_tooltip().contains("Unter Dach und Erde: erreicht"))


func test_objective_lines_phase6() -> void:
	var base := {"p6": true, "p6_intro": false, "levels": {&"crypt": 0, &"chapel": 0, &"shed": 0},
			"goal_levels": {&"crypt": 2, &"chapel": 2, &"shed": 2}, "goal_done": false}
	assert_eq(Phase6Texts.objective({}), "")
	assert_eq(Phase6Texts.objective(base), "Sprich mit Osric über die Gruft")
	base["p6_intro"] = true
	assert_eq(Phase6Texts.objective(base), "Bauplatz: Gruft")
	base["levels"] = {&"crypt": 1, &"chapel": 0, &"shed": 0}
	base["next_lift"] = "Barbe Lindt (1730–1758)"
	base["ossuary_free"] = true
	assert_eq(Phase6Texts.objective(base), "Gebeinkiste zimmern")
	base["boxes"] = 1
	assert_eq(Phase6Texts.objective(base), "Altes Grab heben: Barbe Lindt (1730–1758)")
	base["reinter_waiting"] = 2
	base["full_boxes"] = 2
	assert_eq(Phase6Texts.objective(base), "Gebeine beisetzen (2 warten)")
	base["reinter_waiting"] = 0
	base["ossuary_free"] = false
	base["passage_unseen"] = true
	assert_eq(Phase6Texts.objective(base), "Hinter dem Beinhaus zieht es kalt")
	base["passage_unseen"] = false
	assert_eq(Phase6Texts.objective(base), "Kapelle 2 · Gruft 2 · Schuppen 2")
	base["goal_done"] = true
	base["devotion_name"] = "Agnes Hollweg"
	assert_eq(Phase6Texts.objective(base), "Eine Andacht für Agnes Hollweg?")
	# The corpse chain: into the crypt, onto the catafalque.
	var r := CorpseRecord.new()
	r.display_name = "Hanna Wirth"
	r.location = &"carried"
	var world := {"crypt_level": 1, "chapel_level": 1}
	var graves: Array[GraveRecord] = []
	assert_eq(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 600, {}, world), "Bring die Leiche in die Gruft")
	r.examined = true
	r.dress = CorpseRecord.DRESS_SHROUD
	r.shrouded = true
	assert_eq(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 600, {}, world), "Die Kapelle steht – leg Hanna Wirth auf den Katafalk")
	assert_ne(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 1100, {}, world), "Die Kapelle steht – leg Hanna Wirth auf den Katafalk",
			"only 08:00–17:00")
	r.location = &"catafalque"
	assert_eq(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 600, {}, world), "Aussegnung am Altar halten")
	r.service_held = true
	assert_eq(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 600, {}, world), ObjectiveResolver.TEXT_NO_PLOT)
	r.location = &"carried"
	r.examined = false
	assert_eq(ObjectiveResolver.current([r] as Array[CorpseRecord], graves, null, 600, {}, {}), ObjectiveResolver.TEXT_TO_TABLE, "no crypt: the old line")


func test_day_summary_services_reinterred_buildings() -> void:
	await _setup()
	EventBus.building_upgraded.emit(&"crypt", 2)
	EventBus.funeral_held.emit("c1", 1, 3)
	EventBus.bones_reinterred.emit("old_04", 1)
	EventBus.bones_reinterred.emit("old_06", 1)
	EventBus.coins_spent.emit(30, &"building")
	EventBus.coins_spent.emit(2, &"osric")
	ui.open_panel(&"day_summary", {"day": 33, "burials_today": 1, "coins_today": -20, "total": 180, "rating": &"venerable"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.row_text(panel.built_label), "Gruft Stufe 2")
	assert_eq(panel.row_text(panel.services_label), "1")
	assert_eq(panel.row_text(panel.reinterred_label), "2")
	assert_eq(panel.row_text(panel.spent_label), "32 Münzen (Gebäude 30 · Osric 2)")
	ui.close_top_panel()
	ui.open_panel(&"day_summary", {"day": 34, "burials_today": 0, "coins_today": 0, "total": 180, "rating": &"venerable"})
	assert_false(panel.services_label.visible or panel.reinterred_label.visible, "a new day starts empty")


func test_chapter_panel_roof_and_earth() -> void:
	await _setup()
	var ctx := {"variant": &"roof_and_earth", "chapter": &"roof_and_earth", "buildings_days": 6,
			"levels": {&"crypt": 2, &"chapel": 2, &"shed": 2}, "services_held": 5, "devotions_held": 2,
			"reinterred": PackedStringArray(["Barbe Lindt", "Hanne Sörgel", "Elias Brand, Totengräber"]), "reinterred_total": 6,
			"niche_waits": 2, "coins_spent": {&"building": 130, &"osric": 12}, "content_before": 9, "content_now": 13,
			"final_line": "Die Toten warten jetzt nicht mehr im Regen."}
	ui.open_panel(&"slice_summary", ctx)
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Unter Dach und Erde")
	assert_true(panel.roof_grid.visible and not panel.stone_grid.visible and not panel.chapter_grid.visible and not panel._cemetery_grid.visible)
	assert_eq(panel.roof_value("Tage seit dem Gemeinderat"), "6")
	assert_eq(panel.roof_value("Gebäude"), "Gruft 2 · Kapelle 2 · Schuppen 2")
	assert_eq(panel.roof_value("Aussegnungen"), "5")
	assert_eq(panel.roof_value("Andachten"), "2")
	assert_eq(panel.roof_value("Umbettungen"), "3/6 · Barbe Lindt, Hanne Sörgel, Elias Brand, Totengräber")
	assert_eq(panel.roof_value("In der Kühlnische gewartet"), "2")
	assert_eq(panel.roof_value("Ausgaben seit dem Gemeinderat"), "142 Münzen (Gebäude 130 · Osric 12)")
	assert_eq(panel.roof_value("Zufriedene Geister"), "9 → 13")
	assert_eq(panel.goal_label.text, "Die Toten warten jetzt nicht mehr im Regen.")
	ui.close_top_panel()
	ui.open_panel(&"slice_summary", {"variant": &"names_in_stone", "workshop_days": 1})
	assert_false(panel.roof_grid.visible, "other variants unchanged")


# --- debug --------------------------------------------------------------------------------------

func test_debug_commands_without_world() -> void:
	for command: String in ["buildings open", "build crypt 1", "building shed 2", "lift all", "reinter", "service",
			"devotion plot_01", "room crypt", "niche fill", "cold", "candles 2", "mourners 2", "passage", "vis", "goal6"]:
		var r := Debug.execute(command)
		assert_false(r.ok, command)
		assert_true(str(r.text).contains("Keine Spielwelt"), command + ": " + str(r.text))
	var help := str(Debug.execute("help").text)
	assert_true(help.contains("build <crypt|chapel|shed|all> [1-3]") and help.contains("goal6"), help)
	assert_false(Debug.execute("build all").text.contains("crypt"), "plain „build all“ stays Phase 5")


func test_debug_build_candles_goal() -> void:
	await _setup()
	_buildings({})
	assert_true(Debug.execute("buildings open").ok)
	assert_true(buildings.is_open())
	assert_true(Debug.execute("build crypt 2").ok, str(Debug.execute("goal6").text))
	assert_eq(buildings.level(&"crypt"), 2)
	assert_false(Debug.execute("build crypt 1").ok, "no demolition")
	assert_true(Debug.execute("building shed 1").ok)
	assert_eq(buildings.level(&"shed"), 1)
	assert_true(Debug.execute("build all 2").ok)
	assert_eq([buildings.level(&"crypt"), buildings.level(&"chapel"), buildings.level(&"shed")], [2, 2, 2])
	assert_true(str(Debug.execute("goal6").text).contains("Gruft 2/2 · Kapelle 2/2 · Schuppen 2/2"))
	assert_false(Debug.execute("build crypt 4").ok)
	assert_true(Debug.execute("candles 3").ok)
	assert_eq(inv.count(&"altar_candle"), 3)
	assert_true(Debug.execute("candles 1").ok)
	assert_eq(inv.count(&"altar_candle"), 1)


# --- helpers ------------------------------------------------------------------------------------

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


func world_node() -> Node3D:
	if world == null:
		world = Node3D.new()
		world.name = "P6World"
		tree.root.add_child(world)
	return world


func _buildings(levels: Dictionary) -> void:
	buildings = Phase6Fixtures.buildings_at(levels, tree)


func _shed_store() -> void:
	shed = (load(SHED_SCENE) as PackedScene).instantiate() as ShedStore
	world_node().add_child(shed)
	await wait_frames(1)


func _site(id: StringName, lvl: int) -> SiteDouble:
	var site := SiteDouble.new()
	site.building_id = id
	site.lvl = lvl
	world_node().add_child(site)
	return site


func _open_building(site: SiteDouble) -> BuildingPanel:
	ui.open_panel(&"building", {"building": site.building_id, "data": Database.building(site.building_id), "level": site.lvl, "site": site,
			"inventory": inv, "player": player})
	return ui.get_panel(&"building") as BuildingPanel


## Corpses + Graveyard (3 plot doubles) + ChapelRites + Buildings at `levels`.
func _world_with_chapel(levels: Dictionary) -> void:
	_buildings(levels)
	GameState.set_flag(&"buildings_open", true)
	var w := world_node()
	var tables := load(FIXTURE_TABLES) as CorpseTables
	var eco := Phase6Fixtures.economy_config()
	var container := Node3D.new()
	container.name = "Corpses"
	w.add_child(container)
	corpses = CorpseManager.new()
	corpses.tables = tables
	corpses.economy = eco
	corpses.container_path = ^"../Corpses"
	w.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = eco
	graveyard.tables = tables
	graveyard.section_data = Phase3Fixtures.sections()
	graveyard.reputation_config = Phase6Fixtures.reputation_config()
	graveyard.stone_config = Phase5Fixtures.stone_config()
	for i: int in 3:
		var plot := PlotDouble.new()
		plot.grave_id = "plot_%02d" % (i + 1)
		plot.add_to_group(&"grave_plot")
		w.add_child(plot)
	w.add_child(graveyard)
	rites = ChapelRites.new()
	rites.config = Phase6Fixtures.chapel_config()
	w.add_child(rites)


func _catafalque_corpse(name: String, dress: StringName) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = name
	r.cause_id = &"fever"
	r.age = 60
	r.examined = true
	r.dress = dress
	r.shrouded = dress != CorpseRecord.DRESS_NONE
	var spawned := corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	assert_true(corpses.put_down(spawned.id, CorpseRecord.LOCATION_CATAFALQUE, Transform3D.IDENTITY, null, &"chapel"))
	return spawned


func _marked(grave_id: String, name: String, robbed: bool) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = name
	r.cause_id = &"fever"
	r.age = 50
	r.examined = true
	r.shrouded = true
	if robbed:
		r.harvested.assign([CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH])
	var spawned := corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	graveyard.dig(grave_id)
	graveyard.bury(grave_id, spawned.id)
	var purse := FakeInventory.new()
	purse.add_item(&"wooden_cross", 1)
	graveyard.place_marker(grave_id, &"wooden_cross", purse)
	purse.free()
	return spawned
