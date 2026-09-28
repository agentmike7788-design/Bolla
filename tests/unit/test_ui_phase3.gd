extends TestCase
## W-UI Phase 3 (docs/PHASE3_DESIGN.md §6, §7, §10): build bar + reason texts, reputation line +
## trend arrow, tooltips, cemetery overview panel, day summary / cemetery summary, objective
## priorities, notifications, reward-card reputation rows, workbench groups, debug commands.
## Systems come from the Phase-3 fixtures or small doubles (no graveyard world needed).

const UI_SCENE := "res://src/ui/ui_root.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const NOON := 720


## CemeteryScore with a fixed breakdown.
class ScoreDouble extends CemeteryScore:
	var parts: Dictionary = {"graves": 48, "decor": 12, "dirt": 3}

	func breakdown() -> Dictionary:
		return CemeteryStatus.breakdown_of(int(parts.graves), int(parts.decor), int(parts.dirt), EconomyConfig.resolve())

	func total() -> int:
		return int(breakdown().total)

	func rating() -> StringName:
		return breakdown().rating

	func refresh(_force: bool = false) -> void:
		pass


## Grave place with a section (group "grave_plot").
class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false
	var section_id: StringName = &"yard"


## GhostManager double: fixed heard moods / eligible graves.
class GhostsDouble extends GhostManager:
	var moods: Dictionary = {&"content": 3, &"calm": 1, &"restless": 1}
	## Ids without plot nodes: nothing is bound to the pool.
	var eligible: PackedStringArray = ["g_1", "g_2", "g_3", "g_4", "g_5", "g_6", "g_7"]

	func heard_moods() -> Dictionary:
		return moods

	func eligible_graves() -> PackedStringArray:
		return eligible

	func _process(_delta: float) -> void:
		pass


var ui: UIRoot
var world: Node3D
var player: Player
var inv: FakeInventory
var rep: Reputation
var score: ScoreDouble
var decorations: DecorationManager
var mode: BuildMode
var notes: Array = []
var _debug_before: bool = true


func before_each() -> void:
	notes.clear()
	GameState.reset()
	GameState.stats[&"reputation"] = 40
	EventBus.notification_requested.connect(_on_note)
	_debug_before = GameConfig.debug_enabled
	GameConfig.debug_enabled = true
	Debug.reset()


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	Debug.reset()
	GameConfig.debug_enabled = _debug_before
	UIState.clear()
	GameState.reset()


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


## World with player, reputation (fixture config), score double, decorations + build mode.
func _world(with_ui: bool = true) -> void:
	world = Node3D.new()
	world.name = "P3World"
	var placed := Node3D.new()
	placed.name = "Placed"
	world.add_child(placed)
	rep = Reputation.new()
	rep.config = Phase3Fixtures.reputation_config()
	world.add_child(rep)
	score = ScoreDouble.new()
	world.add_child(score)
	decorations = DecorationManager.new()
	decorations.mask = Phase3Fixtures.build_mask()
	decorations.config = Phase3Fixtures.decor_config()
	for id: StringName in Phase3Fixtures.DECOR_IDS:
		decorations.decor_table[id] = Phase3Fixtures.decor(id)
	decorations.section_list = Phase3Fixtures.sections()
	decorations.fallback_unlocked = PackedInt32Array([1, 2])
	decorations.container_path = NodePath("../Placed")
	world.add_child(decorations)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old := player.get_node("Inventory")
	player.remove_child(old)
	old.free()
	inv = FakeInventory.new()
	inv.name = "Inventory"
	player.add_child(inv)
	player.position = Vector3(5.0, 0.0, 2.0)
	player.instant_actions = true
	world.add_child(player)
	mode = BuildMode.new()
	mode.config = Phase3Fixtures.decor_config()
	mode.player = player
	mode.decorations = decorations
	world.add_child(mode)
	tree.root.add_child(world)
	if with_ui:
		ui = await add_scene(UI_SCENE) as UIRoot
	await tree.process_frame


# --- texts ----------------------------------------------------------------------------------

func test_reason_texts_of_section_7() -> void:
	var lantern := Phase3Fixtures.decor(&"decor_lantern")
	assert_eq(Phase3Texts.reason_text(&"ok"), "")
	assert_eq(Phase3Texts.reason_text(&"route"), "Weg freihalten")
	assert_eq(Phase3Texts.reason_text(&"grave_ring"), "Zu nah am Grab")
	assert_eq(Phase3Texts.reason_text(&"obstacle"), "Erst roden")
	assert_eq(Phase3Texts.reason_text(&"limit", lantern), "Höchstens 6 Grablaternen")
	assert_eq(Phase3Texts.reason_text(&"limit", Phase3Fixtures.decor(&"decor_bench_wood"), 80), "Höchstens 80 Zierstücke auf dem Friedhof")
	assert_eq(Phase3Texts.reason_text(&"player"), "Du stehst im Weg")
	assert_eq(Phase3Texts.reason_text(&"locked_section"), "Dieser Teil ist noch nicht freigelegt")
	for reason: StringName in [&"blocked", &"occupied", &"corpse", &"no_item"]:
		assert_ne(Phase3Texts.reason_text(reason), String(reason), "German text for %s" % reason)


func test_decor_captions_and_tooltips() -> void:
	assert_eq(Phase3Texts.zier_text(Phase3Fixtures.decor(&"decor_bench_wood")), "Zier +3")
	assert_eq(Phase3Texts.zier_text(Phase3Fixtures.decor(&"decor_path_gravel")), "Zier +1 je 4")
	var tip := Phase3Texts.decor_tooltip(Phase3Fixtures.decor(&"decor_lantern"))
	assert_true(tip.begins_with("Grablaterne\nZier +3 · zählt bis 6 Stück\n"), tip)
	assert_true(tip.contains("höchstens 6 aufstellbar"), tip)
	assert_true(tip.contains("leuchtet nachts"), tip)
	assert_true(Phase3Texts.decor_tooltip(Phase3Fixtures.decor(&"decor_path_gravel")).contains("begehbar"))
	assert_eq(Phase3Texts.section_decor_text({"name": "Ostwiese", "decor": 6, "decor_cap": 9}), "Ostwiese: Zier 6/9")
	assert_eq(Phase3Texts.section_decor_text({}), "")
	assert_eq(Phase3Texts.recipe_decor_hint(Phase3Fixtures.decor(&"decor_bench_wood")), "Zier +3 – zählt je Abschnitt bis zur Obergrenze")
	assert_eq(Phase3Texts.recipe_decor_hint(null), "")
	assert_eq(Phase3Texts.BUILD_HELP, "[Linksklick/E] aufstellen · [Rechtsklick/X] abbauen · [R/Mausrad] drehen · [1–8] wählen · [B] fertig")


func test_hud_tooltip_texts() -> void:
	var b := CemeteryStatus.breakdown_of(48, 12, 3, EconomyConfig.resolve())
	assert_eq(int(b.total), 57)
	assert_eq(b.rating, &"dignified")
	assert_eq(Phase3Texts.quality_tooltip(b), "Gräber 48 · Zier +12 · Pflege −3\nEhrwürdig ab 100 – es fehlen 43")
	var top := CemeteryStatus.breakdown_of(110, 0, 0, EconomyConfig.resolve())
	assert_eq(top.rating, &"dignified", "Phase 4 §2.14: Ehrwürdig needs decor and tending")
	assert_eq(Phase3Texts.quality_tooltip(top), "Gräber 110 · Zier 0 · Pflege 0\nFür „Ehrwürdig“ fehlt noch: Zier 0/12")
	var full := CemeteryStatus.breakdown_of(100, 14, 2, EconomyConfig.resolve())
	assert_eq(full.rating, &"venerable")
	assert_eq(Phase3Texts.quality_tooltip(full), "Gräber 100 · Zier +14 · Pflege −2\nHöchste Stufe erreicht.")
	var r := CemeteryStatus.reputation_of(40, 3, Phase3Fixtures.reputation_config())
	assert_eq(r.tier, &"respected")
	assert_eq(Phase3Texts.reputation_tooltip(r),
			"Ruf 40 von 100 · Geachtet\nBezahlung +1 je Bestattung · 1 Lieferung am Tag · Pflegegeld 2 · morgen +3\nGeschätzt ab 55")
	var low := CemeteryStatus.reputation_of(5, -2, Phase3Fixtures.reputation_config())
	assert_true(Phase3Texts.reputation_tooltip(low).contains("Bezahlung −2 je Bestattung · Lieferung nur an ungeraden Tagen · Pflegegeld 0 · morgen −2"))
	assert_eq([Phase3Texts.arrow(2), Phase3Texts.arrow(-1), Phase3Texts.arrow(0)], ["▲", "▼", "–"])


func test_tier_change_texts() -> void:
	assert_eq(Phase3Texts.rating_change_text(&"tended", &"dignified"), "Der Friedhof gilt jetzt als „Würdevoll“.")
	assert_eq(Phase3Texts.rating_change_text(&"dignified", &"tended"), "Der Friedhof gilt nur noch als „Gepflegt“.")
	assert_eq(Phase3Texts.rating_change_text(&"tended", &"tended"), "")
	assert_eq(Phase3Texts.reputation_change_text(&"respected", &"esteemed"), "In Hollerbrück bist du jetzt geschätzt.")
	assert_eq(Phase3Texts.reputation_change_text(&"esteemed", &"esteemed"), "")


# --- HUD ------------------------------------------------------------------------------------

func test_hud_reputation_line_and_arrow() -> void:
	await _world()
	ui.hud.refresh_all()
	# Quality 57 → target 20 + 34 = 54 > 40 → drift up.
	assert_eq(ui.hud.reputation_text(), "Geachtet ▲")
	assert_eq(ui.hud.reputation_meter.value, 40)
	assert_eq(ui.hud.reputation_meter.thresholds, PackedInt32Array([15, 35, 55, 80]))
	assert_true(ui.hud.reputation_tooltip().begins_with("Ruf 40 von 100 · Geachtet\nBezahlung +1 je Bestattung"), ui.hud.reputation_tooltip())
	score.parts = {"graves": 0, "decor": 0, "dirt": 0}
	rep.change(-10, "Test")
	await wait_frames(2)
	assert_eq(ui.hud.reputation_text(), "Unauffällig ▼", "quality 0 → target 20 < 30")
	rep.change(-10, "Test")
	await wait_frames(2)
	assert_eq(ui.hud.reputation_text(), "Unauffällig –", "at the target: flat")


func test_hud_quality_block_uses_cemetery_score() -> void:
	await _world()
	ui.hud.refresh_all()
	assert_eq(ui.hud.quality_text(), "57 · Würdevoll")
	assert_eq(ui.hud.next_tier_label.text, "Ehrwürdig ab 100")
	assert_eq(ui.hud.quality_tooltip(), "Gräber 48 · Zier +12 · Pflege −3\nEhrwürdig ab 100 – es fehlen 43")
	assert_eq(ui.hud.quality_row.mouse_filter, Control.MOUSE_FILTER_STOP, "hover target for the tooltip")
	assert_eq(ui.hud.reputation_row.mouse_filter, Control.MOUSE_FILTER_STOP)


func test_hud_without_reputation_system_uses_game_state() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	GameState.stats[&"reputation"] = 60
	ui.hud.refresh_all()
	assert_eq(ui.hud.reputation_text(), "Geschätzt –")


# --- build bar ------------------------------------------------------------------------------

func test_build_bar_replaces_the_prompt() -> void:
	await _world()
	inv.add_item(&"decor_bench_wood", 2)
	inv.add_item(&"decor_lantern", 1)
	EventBus.interaction_focus_changed.emit("Leiche aufnehmen", true)
	assert_true(ui.hud.prompt_panel.visible)
	assert_false(ui.hud.build_bar_visible())
	assert_true(mode.enter())
	assert_true(ui.hud.build_bar_visible(), "bar while building")
	assert_false(ui.hud.prompt_panel.visible, "replaces the interaction prompt")
	var bar := ui.hud.build_bar
	assert_eq(bar.slot_ids(), [&"decor_bench_wood", &"decor_lantern"] as Array[StringName])
	assert_eq(bar.slot_count_text(0), "×2")
	assert_eq(bar.slot_zier_text(0), "Zier +3")
	assert_eq(bar.selected_slot(), 0, "amber frame on the selected piece")
	assert_true(bar.slot_tooltip(1).begins_with("Grablaterne"), bar.slot_tooltip(1))
	assert_eq(bar.help_label.text, Phase3Texts.BUILD_HELP)
	bar.click_slot(1)
	assert_eq(mode.selected, &"decor_lantern", "a click selects the slot")
	assert_eq(bar.selected_slot(), 1)
	mode.exit()
	assert_false(ui.hud.build_bar_visible())
	assert_true(ui.hud.prompt_panel.visible, "prompt back after building")


func test_build_bar_status_and_section_decor() -> void:
	await _world()
	inv.add_item(&"decor_bench_wood", 1)
	mode.enter()
	var bar := ui.hud.build_bar
	# Player at (5, 2) facing +Z: cursor (5, 3.2) = cell (10, 6), section 2 (Ostwiese).
	bar.sync(mode)
	assert_eq(mode.cursor_reason(), &"ok")
	assert_eq(bar.status_text(), "Holzbank hier aufstellen (5 Min)")
	assert_false(bar.status_is_warning())
	assert_eq(bar.section_text(), "Ostwiese: Zier 0/9")
	decorations.free_build = true
	decorations.place(&"decor_bench_wood", Vector2i(7, 2), 0, null)
	bar.sync(mode)
	assert_eq(bar.section_text(), "Ostwiese: Zier 3/9")
	assert_eq(bar.slot_count_text(0), "∞", "free build")
	decorations.free_build = false
	# Bench across the grave ring (cells 0–2, z 2): refused, the reason in warning style.
	player.position = Vector3(0.75, 0.0, 0.0)
	bar.sync(mode)
	assert_eq(mode.cursor_reason(), &"grave_ring")
	assert_eq(bar.status_text(), "Zu nah am Grab")
	assert_true(bar.status_is_warning())
	assert_eq(bar.section_text(), "Alter Hof: Zier 0/12")
	# The fence row is not buildable at all: no section decor line.
	player.position = Vector3(5.0, 0.0, -1.0)
	bar.sync(mode)
	assert_eq(mode.cursor_reason(), &"blocked")
	assert_eq(bar.section_text(), "")


func test_build_bar_without_decor_items() -> void:
	await _world()
	mode.enter()
	var bar := ui.hud.build_bar
	bar.sync(mode)
	assert_true(bar.slot_ids().is_empty())
	assert_true(bar.empty_label.visible)
	assert_false(bar.slot_row.visible)


# --- cemetery overview ----------------------------------------------------------------------

## Graveyard (fixture economy/sections) with 4 plot doubles, 3 obstacles, ExpansionManager and a
## ghost double – added to the running world (plots first, so the Graveyard collects them).
func _expansion_ready() -> Dictionary:
	for spec: Array in [["plot_01", &"yard"], ["plot_02", &"yard"], ["plot_07", &"east"], ["plot_10", &"north"]]:
		var plot := PlotDouble.new()
		plot.grave_id = spec[0]
		plot.section_id = spec[1]
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	for spec: Array in [["obs_e_01", &"east", &"bramble"], ["obs_e_02", &"east", &"rubble"], ["obs_n_01", &"north", &"hedge"]]:
		var o := ClearableObstacle.new()
		o.obstacle_id = spec[0]
		o.section_id = spec[1]
		o.kind = spec[2]
		o.name = spec[0]
		world.add_child(o)
	var graveyard := Graveyard.new()
	graveyard.economy = load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig
	graveyard.tables = load("res://tests/fixtures/corpse_tables_fixture.tres") as CorpseTables
	graveyard.section_data = Phase3Fixtures.sections()
	graveyard.reputation_config = Phase3Fixtures.reputation_config()
	world.add_child(graveyard)
	var expansion := ExpansionManager.new()
	expansion.section_data = Phase3Fixtures.sections()
	for id: StringName in Phase3Fixtures.CLEARABLE_IDS:
		expansion.clearable_data[id] = Phase3Fixtures.clearable(id)
	world.add_child(expansion)
	world.add_child(GhostsDouble.new())
	await tree.process_frame
	return {"graveyard": graveyard, "expansion": expansion}


func test_overview_context_from_the_systems() -> void:
	await _world()
	var sys := await _expansion_ready()
	var ctx := CemeteryStatus.overview_context(tree)
	assert_eq(int(ctx.score.total), 57)
	var ids: Array = (ctx.sections as Array).map(func(s: Dictionary) -> StringName: return s.id)
	assert_eq(ids, [&"yard", &"east", &"north"])
	var east: Dictionary = ctx.sections[1]
	assert_eq([east.name, east.unlocked, east.done, east.total, east.block], ["Ostwiese", false, 0, 2, ""])
	var north: Dictionary = ctx.sections[2]
	assert_true(str(north.block).contains("Ostwiese"), north.block)
	var yard: Dictionary = ctx.sections[0]
	assert_eq([yard.plots, yard.plots_free, yard.decor_cap], [2, 2, 12])
	assert_eq(ctx.reputation.label, "Geachtet")
	assert_eq([ctx.ghosts.content, ctx.ghosts.calm, ctx.ghosts.restless, ctx.ghosts.heard, ctx.ghosts.eligible], [3, 1, 1, 5, 7])
	assert_false(bool(ctx.dirt.known), "no cleanliness system")
	(sys.expansion as ExpansionManager).unlock(&"east")
	ctx = CemeteryStatus.overview_context(tree)
	assert_true(bool(ctx.sections[1].unlocked))


func test_overview_panel_opens_with_u_and_shows_everything() -> void:
	await _world()
	await _expansion_ready()
	_press(&"cemetery_overview")
	assert_eq(ui.top(), &"cemetery_overview")
	var panel := ui.get_panel(&"cemetery_overview") as CemeteryOverviewPanel
	assert_true(panel.is_visible_in_tree())
	assert_eq(panel.section_status(&"yard"), "freigelegt")
	assert_eq(panel.section_status(&"east"), "freilegen: 0/2")
	assert_eq(panel.section_status(&"north"), "gesperrt")
	assert_true(panel.section_detail(&"yard").contains("Zier 0/12"), panel.section_detail(&"yard"))
	assert_true(panel.section_detail(&"north").contains("Ostwiese"), panel.section_detail(&"north"))
	assert_eq(panel.quality_value.text, "57 · Würdevoll")
	assert_eq(panel.quality_rows["Zier"].text, "+12")
	assert_eq(panel.quality_rows["Pflege"].text, "−3")
	assert_eq(panel.quality_next.text, "Ehrwürdig ab 100 – es fehlen 43")
	assert_eq([panel.reputation_value.text, panel.reputation_arrow.text], ["Geachtet", "▲"])
	assert_eq(panel.reputation_rows["Bezahlung je Bestattung"].text, "+1 Münze")
	assert_eq(panel.reputation_rows["Pflegegeld am Morgen"].text, "2 Münzen")
	assert_eq(panel.ghosts_moods.text, "3 zufrieden · 1 gleichmütig · 1 unruhig")
	assert_eq(panel.care_levels.text, CemeteryOverviewPanel.TEXT_NO_CARE)
	_press(&"cemetery_overview")
	assert_false(ui.is_open(&"cemetery_overview"), "U closes it again")


func test_overview_panel_care_and_no_ghosts() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"cemetery_overview", {"score": CemeteryStatus.breakdown_of(20, 0, 0, EconomyConfig.resolve()), "sections": [],
			"reputation": CemeteryStatus.reputation_of(25, 0, Phase3Fixtures.reputation_config()),
			"dirt": {"levels": [20, 8, 4, 2], "penalty": 8, "known": true}, "ghosts": {"content": 0, "calm": 0, "restless": 0}})
	var panel := ui.get_panel(&"cemetery_overview") as CemeteryOverviewPanel
	assert_eq(panel.care_levels.text, "20 sauber · 8 sprießt · 4 verunkrautet · 2 verwildert")
	assert_eq(panel.care_penalty.text, "Abzug −8")
	assert_eq(panel.ghosts_moods.text, CemeteryOverviewPanel.TEXT_NO_GHOSTS)
	assert_eq(panel.reputation_rows["Bezahlung je Bestattung"].text, "0 Münzen")


func test_grave_register_opens_the_overview() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"grave_register", {"entries": [], "total": 0, "rating": &"neglected"})
	var register := ui.get_panel(&"grave_register") as GraveRegisterPanel
	register.overview_button.pressed.emit()
	assert_eq(ui.open_ids(), [&"grave_register", &"cemetery_overview"] as Array[StringName])


# --- summaries ------------------------------------------------------------------------------

func test_day_summary_phase3_rows() -> void:
	await _world()
	rep.apply_daily(TimeManager.day + 1)
	var daily := rep.last_daily()
	EventBus.section_unlocked.emit(&"east")
	ui.open_panel(&"day_summary", {"day": 3, "burials_today": 1, "coins_today": 9, "total": 12, "rating": &"orderly"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.total_label.text, "57 · Würdevoll", "cemetery quality of CemeteryScore, not graves only")
	assert_eq(panel.row_text(panel.stipend_label), "+%d Münzen" % int(daily.stipend))
	assert_eq(panel.row_text(panel.reputation_label), "%s (%s)" % [ReputationRules.label(rep.tier()), UIKit.signed(int(daily.drift))])
	assert_eq(panel.row_text(panel.unlocked_label), "Ostwiese")
	assert_eq(panel.row_text(panel.dirty_label), "", "no cleanliness system: row hidden")
	ui.close_panel(&"day_summary")
	ui.open_panel(&"day_summary", {"day": 4})
	assert_eq(panel.row_text(panel.unlocked_label), "", "taken by the previous summary")


func test_day_summary_phase2_context_unchanged() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"day_summary", {"day": 2, "burials_today": 1, "coins_today": 9, "total": 15, "rating": &"orderly"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.total_label.text, "15 · Ordentlich")
	assert_false(panel.stipend_label.visible)
	assert_false(panel.reputation_label.visible)
	assert_false(panel.unlocked_label.visible)
	var complete := DaySummaryPanel.complete_context({"day": 2, "stipend": 4, "reputation_delta": 3, "reputation_tier": &"esteemed",
			"dirty_spots": 2, "sections_unlocked": ["Birkenhang"]}, null, [])
	ui.open_panel(&"day_summary", complete)
	assert_eq(panel.row_text(panel.stipend_label), "+4 Münzen")
	assert_eq(panel.row_text(panel.reputation_label), "Geschätzt (+3)")
	assert_eq(panel.row_text(panel.dirty_label), "2")
	assert_eq(panel.row_text(panel.unlocked_label), "Birkenhang")


func test_cemetery_summary_variant() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	ui.open_panel(&"slice_summary", {"days": 14, "burials": 12, "total": 104, "rating": &"venerable", "reputation": 78,
			"variant": &"cemetery", "decor": 24, "dirt": 2, "reputation_tier": &"esteemed", "content_ghosts": 9})
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.total_label.text, "104 · Ehrwürdig")
	assert_eq(panel.decor_label.text, "+24")
	assert_eq(panel.dirt_label.text, "−2")
	assert_eq(panel.reputation_label.text, "Geschätzt")
	assert_eq(panel.ghosts_label.text, "9")
	assert_eq(panel.goal_label.text, "Ziel „Ehrwürdig“ (ab 100) erreicht.")
	ui.open_panel(&"slice_summary", {"days": 14, "burials": 12, "total": 88, "rating": &"dignified", "variant": &"cemetery",
			"reputation_tier": &"respected"})
	assert_eq(panel.goal_label.text, "Ziel „Ehrwürdig“ (ab 100) verfehlt – es fehlen 12 Punkte.")


# --- objective ------------------------------------------------------------------------------

func _graves(states: Array) -> Array[GraveRecord]:
	var out: Array[GraveRecord] = []
	for i: int in states.size():
		var g := GraveRecord.new()
		g.id = "plot_%02d" % (i + 1)
		g.state = states[i]
		g.quality = 8 if g.state == GraveRecord.State.MARKED else 0
		out.append(g)
	return out


func _sections(east_done: int, north_block: String = "Erst die Ostwiese freilegen") -> Array:
	return [{"id": &"yard", "name": "Alter Hof", "unlocked": true, "done": 0, "total": 0, "block": ""},
			{"id": &"east", "name": "Ostwiese", "unlocked": false, "done": east_done, "total": 10, "block": ""},
			{"id": &"north", "name": "Birkenhang", "unlocked": false, "done": 0, "total": 13, "block": north_block}]


func test_objective_phase3_priorities() -> void:
	var m := GraveRecord.State.MARKED
	var e := GraveRecord.State.EMPTY
	var none: Array[CorpseRecord] = []
	var i := FakeInventory.new()
	var full := _graves([m, m, m, m, m, e])
	var world_state := {"sections": _sections(3), "weeds": 3, "leaves": 2, "has_rake": false, "total": 40, "rating": &"tended"}
	assert_eq(ObjectiveResolver.current(none, full, i, NOON, {}, world_state), "Ostwiese freilegen: 3/10", "≤ 1 free plot: section first")
	var roomy := _graves([m, e, e, e])
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Unkraut jäten (3 Stellen)", "plots free: care")
	world_state.weeds = 1
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Unkraut jäten (1 Stelle)")
	world_state.weeds = 0
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Laub liegt – Rechen an der Werkbank bauen")
	world_state.has_rake = true
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Laub harken (2 Stellen)")
	world_state.leaves = 0
	assert_eq(ObjectiveResolver.current(none, roomy, i, 1270, {}, world_state), "Etwas regt sich zwischen den Gräbern …", "first ghost night")
	assert_eq(ObjectiveResolver.current(none, roomy, i, 1270, {&"ghosts_seen": true}, world_state), "Feierabend – Schlafen an der Hüttentür")
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Feierabend – Ausruhen an der Hüttentür", "below Würdevoll: rest")
	world_state.total = 57
	world_state.rating = &"dignified"
	assert_eq(ObjectiveResolver.current(none, roomy, i, NOON, {}, world_state), "Friedhof: Ehrwürdig ab 100 (jetzt 57)")
	world_state.sections = _sections(10)
	world_state.sections[1].unlocked = true
	assert_eq(ObjectiveResolver.current(none, full, i, NOON, {}, world_state), "Birkenhang: Erst die Ostwiese freilegen", "only blocked left: its prerequisite")
	i.free()


func test_objective_corpse_chain_still_wins() -> void:
	var m := GraveRecord.State.MARKED
	var c := CorpseRecord.new()
	c.id = "corpse_0009"
	c.location = &"carried"
	var i := FakeInventory.new()
	var world_state := {"sections": _sections(3), "weeds": 5, "leaves": 0, "total": 40, "rating": &"tended"}
	assert_eq(ObjectiveResolver.current([c] as Array[CorpseRecord], _graves([m, GraveRecord.State.EMPTY]), i, NOON, {}, world_state),
			"Leiche zum Leichentisch bringen")
	c.examined = true
	assert_eq(ObjectiveResolver.current([c] as Array[CorpseRecord], _graves([m, m]), i, NOON, {}, world_state), "Ostwiese freilegen: 3/10",
			"no free plot: the section that brings new ones")
	assert_eq(ObjectiveResolver.current([c] as Array[CorpseRecord], _graves([m, m]), i, NOON, {}, {}), "Keine freie Grabstelle mehr", "Phase-2 world")
	i.free()


func test_objective_after_the_phase_goal() -> void:
	var i := FakeInventory.new()
	var graves := _graves([GraveRecord.State.MARKED])
	var flags := {&"cemetery_complete": true, &"ghosts_seen": true}
	assert_eq(ObjectiveResolver.current([], graves, i, 400, flags, {"total": 80, "rating": &"dignified"}), "Friedhof: Ehrwürdig ab 100 (jetzt 80)",
			"no carter wait after the goal")
	assert_eq(ObjectiveResolver.current([], graves, i, NOON, flags, {"total": 104, "rating": &"venerable"}), "Der Friedhof ist vollendet und ehrwürdig")
	i.free()


func test_hud_objective_uses_world_state() -> void:
	await _world()
	var sys := await _expansion_ready()
	TimeManager.set_time(TimeManager.day, NOON)
	ui.hud.refresh_objective()
	# 2 yard plots free → no section step; no dirt; quality 57 → the Ehrwürdig line.
	assert_eq(ui.hud.objective_text(), "Friedhof: Ehrwürdig ab 100 (jetzt 57)")
	var graveyard := sys.graveyard as Graveyard
	for id: String in ["plot_01", "plot_02"]:
		graveyard.get_grave(id).state = GraveRecord.State.MARKED
	ui.hud.refresh_objective()
	assert_eq(ui.hud.objective_text(), "Ostwiese freilegen: 0/2")


# --- notifications & reward card ------------------------------------------------------------

func test_tier_and_stipend_notifications() -> void:
	await _world()
	await wait_frames(2)
	EventBus.cemetery_quality_changed.emit(57, &"dignified")
	assert_true(_note_texts().is_empty(), "same tier as read at start: silent")
	EventBus.cemetery_quality_changed.emit(100, &"venerable")
	assert_has(_note_texts(), "Der Friedhof gilt jetzt als „Ehrwürdig“.")
	rep.change(20, "Test")
	assert_has(_note_texts(), "In Hollerbrück bist du jetzt geschätzt.")
	EventBus.payment_received.emit(3, Reputation.REASON_STIPEND)
	assert_has(_note_texts(), "Pflegegeld der Gemeinde: +3 Münzen")
	EventBus.payment_received.emit(7, "Bestattung von Hedwig")
	assert_false(_note_texts().has("Bestattung von Hedwig: +7 Münzen"))


func test_ghost_speech_is_a_quiet_note() -> void:
	await _world()
	EventBus.ghost_spoke.emit("plot_03", &"restless", "Es ist kalt hier.")
	assert_eq(notes.back(), ["Ein Geist: „Es ist kalt hier.“", &"info"])


func test_reward_card_reputation_rows() -> void:
	await _world()
	var card := ui.reward_card
	EventBus.grave_completed.emit("plot_01", "corpse_0001", 9, [{"label": "Bestattet", "points": 2}])
	EventBus.payment_received.emit(8, "Bestattung")
	rep.change(2, "Grab vollendet")
	assert_eq(card.reputation_texts(), PackedStringArray(["Ruf Geachtet: +1 Münze", "Ruf +2"]))


# --- workbench ------------------------------------------------------------------------------

func test_workbench_groups_and_decor_hint() -> void:
	ui = await add_scene(UI_SCENE) as UIRoot
	var i := FakeInventory.new()
	ui.add_child(i)
	ui.open_panel(&"crafting", {"station": &"workbench", "inventory": i})
	var panel := ui.get_panel(&"crafting") as CraftingPanel
	var headers: Array = []
	for child: Node in panel._list.get_children():
		if child is Label:
			headers.append((child as Label).text)
	assert_eq(headers, ["Werkstoffe", "Werkzeug", "Grab", "Zier"], "Phase 5 §7: Werkstoffe · Werkzeug · Grab · Zier")
	var ids := panel.recipe_ids()
	var first_decor := -1
	var last_grave := -1
	for n: int in ids.size():
		var cat := (Database.recipe(ids[n]) as RecipeData).category
		if cat == &"decor" and first_decor < 0:
			first_decor = n
		if cat == &"grave":
			last_grave = n
	assert_true(last_grave < first_decor, "grave recipes first")
	var row := panel.craft_button(&"decor_bench_wood").get_parent().get_parent().get_parent() as Control
	assert_true(row.tooltip_text.begins_with("Zier +3 – zählt je Abschnitt bis zur Obergrenze"), row.tooltip_text)


# --- debug ----------------------------------------------------------------------------------

func test_debug_phase3_commands() -> void:
	await _world(false)
	var sys := await _expansion_ready()
	var expansion := sys.expansion as ExpansionManager
	var help := String(Debug.execute("help").text)
	for command: String in ["unlock <east|north>", "clear <hindernis|east|north>", "dirt <0-3>", "dirt grow", "rep <0-100>",
			"ghosts on|off", "ghost mood", "decor clear", "build free on|off", "tp <east|north>"]:
		assert_true(help.contains(command), command)
	var r := Debug.execute("rep 60")
	assert_true(r.ok, r.text)
	assert_eq(rep.value(), 60)
	assert_eq(r.text, "Ruf 60 · Geschätzt")
	assert_false(Debug.execute("rep 101").ok)
	assert_true(Debug.execute("build free on").ok)
	assert_true(decorations.free_build)
	decorations.place(&"decor_lantern", Vector2i(0, 6), 0, null)
	assert_eq(decorations.placements().size(), 1)
	r = Debug.execute("decor clear")
	assert_eq(r.text, "1 Zierstück(e) entfernt.")
	assert_true(decorations.placements().is_empty())
	assert_true(Debug.execute("build free off").ok)
	assert_false(decorations.free_build)
	r = Debug.execute("clear obs_e_01")
	assert_true(r.ok, r.text)
	assert_true(expansion.is_cleared("obs_e_01"))
	assert_eq(r.text, "obs_e_01 geräumt (1/2).")
	assert_false(Debug.execute("clear obs_n_01").ok, "north blocked until the east is open")
	r = Debug.execute("unlock east")
	assert_true(r.ok, r.text)
	assert_true(expansion.is_unlocked(&"east"))
	assert_true(Debug.execute("unlock east").text.contains("schon"))
	assert_false(Debug.execute("unlock moon").ok)
	r = Debug.execute("quality")
	assert_true(String(r.text).contains("Gräber 48 · Zier +12 · Pflege −3 = 57"), r.text)
	assert_true(String(r.text).contains("Ruf 64 · Geschätzt"), "60 + 4 for the unlocked section: " + r.text)
	r = Debug.execute("ghosts on")
	assert_true(r.ok, r.text)
	assert_true((tree.get_first_node_in_group(&"ghosts") as GhostManager).forced)
	assert_true(Debug.execute("ghosts off").ok)
	r = Debug.execute("ghost mood")
	assert_true(r.ok, r.text)
	assert_false(Debug.execute("dirt 2").ok, "no cleanliness system")
	assert_false(Debug.execute("dirt 7").ok)
	r = Debug.execute("tp east")
	assert_true(r.ok, r.text)
	assert_true(player.global_position.distance_to(Vector3(0.0, 0.0, 1.6)) < 0.01, str(player.global_position))


func test_debug_dirt_commands() -> void:
	await _world(false)
	var clean := CleanlinessManager.new()
	clean.config = Phase3Fixtures.cleanliness_config()
	for spec: Array in [["spot_a", &"weeds"], ["spot_b", &"leaves"]]:
		var spot := DirtSpot.new()
		spot.spot_id = spec[0]
		spot.kind = spec[1]
		spot.section_id = &"yard"
		world.add_child(spot)
	world.add_child(clean)
	clean.collect_spots()
	var r := Debug.execute("dirt 3")
	assert_true(r.ok, r.text)
	assert_eq([clean.level("spot_a"), clean.level("spot_b")], [3, 3])
	var d := CemeteryStatus.dirt(tree)
	assert_eq([d.levels, d.weeds, d.leaves, d.dirty], [[0, 0, 0, 2], 1, 1, 2])
	assert_true(Debug.execute("dirt 0").ok)
	assert_eq(clean.dirty_count(1), 0)
	r = Debug.execute("dirt grow 10")
	assert_true(r.ok, r.text)
	assert_true(clean.level("spot_a") >= 2, "10 days of weeds")
	assert_false(Debug.execute("dirt grow 99").ok)


func test_debug_without_world() -> void:
	for command: String in ["unlock east", "rep 50", "ghosts on", "decor clear", "build free on", "dirt 1", "ghost mood"]:
		var r := Debug.execute(command)
		assert_false(r.ok, command)
		assert_eq(r.text, DebugCommands.TEXT_NO_WORLD, command)
	assert_true(Debug.execute("clear").ok, "plain clear still empties the log")


# --- helpers --------------------------------------------------------------------------------

func _note_texts() -> Array:
	return notes.map(func(n: Array) -> String: return n[0])


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ui._unhandled_input(ev)
