extends TestCase
## W-UI Phase 4 (docs/PHASE4_DESIGN.md §6, §7, §10): the morgue table tabs (Verwerten only with
## Ilse known, step buttons + reasons, loss forecast, find cards revealed / lost, preparation
## lines, the two-stage harvest button and its consequence line), the Merkbuch (pages,
## selection ≤ 3, linking, the fail text, unread dots, the HUD badge), Ilse's trade panel
## (prices, piety bonus, stock, only while present), the chapter panel „Sechs Gruben“, quiet
## notifications, the Ehrwürdig condition, the Phase-4 objective lines and the debug commands.
## Systems come from the Phase-4 fixtures or small doubles.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class FakeManager extends Node:
	var list: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return list

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in list:
			if r.id == id:
				return r
		return null

	func story_delivered() -> PackedStringArray:
		return PackedStringArray()


## MorgueTable double: a fixed panel_state() and a call log.
class P4Station extends Node3D:
	var state: Dictionary = {}
	var calls: Array = []

	func panel_state() -> Dictionary:
		return state

	func request_exam_step(step: StringName) -> void:
		calls.append(["step", step])

	func request_exam_all() -> void:
		calls.append("exam_all")

	func request_wash() -> void:
		calls.append("wash")

	func request_dress(kind: StringName) -> void:
		calls.append(["dress", kind])

	func request_lay_out() -> void:
		calls.append("lay_out")

	func request_balm() -> void:
		calls.append("balm")

	func request_harvest(kind: StringName) -> void:
		calls.append(["harvest", kind])

	func decide_valuables(take: bool) -> void:
		calls.append(["decide", take])

	func request_pick_up() -> void:
		calls.append("pick_up")


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return busy


class PietyDouble extends Node:
	var bonus: int = 0

	func _init() -> void:
		add_to_group(&"piety")

	func buyer_bonus() -> int:
		return bonus


var ui: UIRoot
var manager: FakeManager
var station: P4Station
var player: FakePlayer
var inv: FakeInventory
var record: CorpseRecord
var notes: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	UIState.clear()
	GameState.reset()
	TimeManager.reset()


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _setup() -> void:
	manager = FakeManager.new()
	tree.root.add_child(manager)
	station = P4Station.new()
	tree.root.add_child(station)
	player = FakePlayer.new()
	inv = FakeInventory.new()
	inv.name = "Inventory"
	player.add_child(inv)
	player.inventory = inv
	tree.root.add_child(player)
	record = CorpseRecord.new()
	record.id = "corpse_0007"
	record.display_name = "Marthe Quendel"
	record.age = 63
	record.cause_id = &"old_age"
	record.traits = [&"strange_wound"]
	record.freshness = 0.72
	record.location = &"table"
	manager.list = [record]
	ui = await add_scene(UI_SCENE) as UIRoot


## A MorgueTablePanelState-shaped dictionary: clothing + wounds done, the mark lost.
func _state(harvest_visible: bool = false) -> Dictionary:
	return {
		"corpse_id": record.id, "stage": &"fresh", "freshness": 0.72, "examined": true,
		"steps": [
			{"id": &"clothing", "label": "Kleidung", "minutes": 10, "done": true, "reason": ""},
			{"id": &"hands", "label": "Hände & Arme", "minutes": 10, "done": false, "reason": ""},
			{"id": &"wounds", "label": "Wunden & Haut", "minutes": 15, "done": true, "reason": ""},
			{"id": &"pockets", "label": "Taschen & Säume", "minutes": 10, "done": false, "reason": "Nach dem Einkleiden nicht mehr zugänglich."},
		],
		"open_steps": [&"hands"], "exam_all_minutes": 10,
		"finds": [
			{"id": &"f_cause_old_age", "step": &"wounds", "label": "Müde Hände", "text": "Ein langes Leben.", "state": &"revealed", "clue_id": &""},
			{"id": &"f_s1_mark", "step": &"wounds", "label": "Das Zeichen", "text": "Verblasst.", "state": &"lost", "clue_id": &"c_mark"},
		],
		"nothing_steps": [&"clothing"], "nothing_text": "Nichts Auffälliges.",
		"next_loss": {"minutes": 180, "label": "Hautzeichen", "stage_label": "Verwesend"},
		"prep": {
			"wash": {"minutes": 15, "done": true, "reason": ""},
			"dress": {"current": &"", "shroud": {"minutes": 10, "item": &"shroud", "reason": "Kein Leichentuch – an der Werkbank herstellen."},
					"gown": {"minutes": 15, "item": &"burial_gown", "reason": ""}},
			"dress_warning": MorgueTablePanelState.DRESS_WARNING,
			"lay_out": {"minutes": 10, "done": false, "reason": "Holzkamm nötig – Werkbank."},
			"balm": {"minutes": 10, "active": true, "until": 250, "reason": "Der Wacholderrauch hängt noch über ihr."},
		},
		"harvest_visible": harvest_visible,
		"harvest": {
			"hair": {"label": "Haar", "verb": "Zopf abschneiden", "minutes": 10, "item": &"hair_braid", "done": false,
					"reason": "" if harvest_visible else UtilizationRules.HIDDEN},
			"teeth": {"label": "Zähne", "verb": "Zähne nehmen", "minutes": 15, "item": &"teeth_pouch", "done": false,
					"reason": "Werkzeug fehlt – Ilse Kranich hat es." if harvest_visible else UtilizationRules.HIDDEN},
		},
	}


func _open_exam(state: Dictionary) -> CorpseExamPanel:
	station.state = state
	ui.open_panel(&"corpse_exam", {"corpse_id": record.id, "table": station, "player": player})
	await wait_frames(1)
	return ui.get_panel(&"corpse_exam") as CorpseExamPanel


# --- texts ----------------------------------------------------------------------------------

func test_loss_and_step_texts() -> void:
	assert_eq(Phase4Texts.loss_text({"minutes": 180, "label": "Hautzeichen"}), "Noch ca. 3 h, dann verblassen die Hautzeichen.")
	assert_eq(Phase4Texts.loss_text({"minutes": 42, "label": "Feine Spuren"}), "Noch ca. 40 Min, dann verblassen die feinen Spuren.")
	assert_eq(Phase4Texts.loss_text({}), "")
	assert_eq(Phase4Texts.step_text({"label": "Kleidung", "minutes": 10, "done": false}), "Kleidung · 10 Min")
	assert_eq(Phase4Texts.step_text({"label": "Kleidung", "minutes": 10, "done": true}), "Kleidung ✓")
	assert_eq(Phase4Texts.exam_all_text(35, 3), "Gründlich untersuchen (35 Min)")
	assert_eq(Phase4Texts.balm_text({"active": true, "until": 250, "minutes": 10}), "Geräuchert bis 04:10")
	assert_eq(Phase4Texts.balm_text({"active": false, "minutes": 10}), "Mit Wacholder räuchern · 10 Min")


func test_harvest_consequence_line_without_piety() -> void:
	var line := Phase4Texts.consequence_line(UtilizationRules.effects(&"hair"))
	assert_eq(line, "+1 Zopf (Ilse zahlt 4) · Grabqualität −1 · Ruf −3 · Der Geist wird es wissen.")
	assert_eq(Phase4Texts.consequence_line(UtilizationRules.effects(&"teeth"), 1), "+1 Zahnsäckchen (Ilse zahlt 6) · Grabqualität −2 · Ruf −5 · Der Geist wird es wissen.")
	assert_false(line.contains("Pietät"), "piety is never a number (§7)")
	assert_eq(Phase4Texts.consequence_line({}), "")


func test_chapter_closing_lines_by_tier() -> void:
	for tier: StringName in PietyRules.TIERS:
		var text := Phase4Texts.chapter_closing(tier, true)
		assert_true(text.ends_with(Phase4Texts.CHAPTER_NOT_LORENZ), text)
	assert_ne(Phase4Texts.chapter_closing(&"devout", false), Phase4Texts.chapter_closing(&"hardhearted", false))
	assert_true(Phase4Texts.chapter_closing(&"callous", false).ends_with(Phase4Texts.CHAPTER_LORENZ_OPEN))


# --- morgue table panel ---------------------------------------------------------------------

func test_exam_tabs_and_harvest_tab_only_when_trader_known() -> void:
	await _setup()
	var panel := await _open_exam(_state(false))
	assert_true(panel.phase4)
	assert_true(panel.tabs.tab_bar.visible)
	assert_false(panel.examine_button.visible, "Phase-2 buttons replaced by the tabs")
	assert_true(panel.tabs.tab_buttons[&"exam"].visible)
	assert_true(panel.tabs.tab_buttons[&"prep"].visible)
	assert_false(panel.tabs.tab_buttons[&"harvest"].visible, "no Verwerten before Ilse is known")
	station.state = _state(true)
	panel.refresh()
	assert_true(panel.tabs.tab_buttons[&"harvest"].visible)
	assert_eq(panel.tabs.tab_buttons[&"harvest"].theme_type_variation, &"ExamTabMuted", "muted, no signal colour")
	panel.tabs.select_tab(&"harvest")
	assert_eq(panel.tabs.tab_buttons[&"harvest"].theme_type_variation, &"ExamTabMutedSelected")
	assert_true(panel.tabs.pages[&"harvest"].visible)
	assert_false(panel.tabs.pages[&"exam"].visible)


func test_exam_step_buttons_reasons_and_loss_forecast() -> void:
	await _setup()
	var panel := await _open_exam(_state())
	var t := panel.tabs
	assert_eq(t.step_buttons[&"clothing"].text, "Kleidung ✓")
	assert_true(t.step_buttons[&"clothing"].disabled)
	assert_eq(t.step_buttons[&"hands"].text, "Hände & Arme · 10 Min")
	assert_false(t.step_buttons[&"hands"].disabled)
	assert_true(t.step_buttons[&"pockets"].disabled)
	assert_eq(t.step_buttons[&"pockets"].tooltip_text, "Nach dem Einkleiden nicht mehr zugänglich.")
	assert_eq(t.step_reason_label.text, "Taschen & Säume: Nach dem Einkleiden nicht mehr zugänglich.")
	assert_eq(t.exam_all_button.text, "Gründlich untersuchen (10 Min)")
	assert_eq(t.loss_label.text, "Noch ca. 3 h, dann verblassen die Hautzeichen.")
	assert_true(t.loss_label.visible)
	assert_eq(t.loss_label.theme_type_variation, &"AccentLabel", "> 2 h: no warning colour")
	t.step_buttons[&"hands"].pressed.emit()
	t.exam_all_button.pressed.emit()
	assert_eq(station.calls, [["step", &"hands"], "exam_all"])
	var s := _state()
	s["next_loss"] = {"minutes": 90, "label": "Hautzeichen"}
	station.state = s
	panel.refresh()
	assert_eq(t.loss_label.theme_type_variation, &"WarningLabel", "≤ 2 h: warning")


func test_find_cards_revealed_lost_and_nothing() -> void:
	await _setup()
	var panel := await _open_exam(_state())
	assert_eq(panel.shown_finds(), [[&"f_cause_old_age", &"revealed"], [&"f_s1_mark", &"lost"]] as Array[Array])
	assert_eq(panel.shown_nothing_steps(), PackedStringArray(["Kleidung"]))
	var lost: PanelContainer
	for c: Node in panel.traits_box.get_children():
		if c.has_meta(&"find_id") and c.get_meta(&"find_id") == &"f_s1_mark":
			lost = c
	assert_eq(lost.theme_type_variation, &"FindLostPanel", "lost card dimmed")


func test_prep_lines_and_dress_warning() -> void:
	await _setup()
	var panel := await _open_exam(_state())
	var t := panel.tabs
	t.select_tab(&"prep")
	assert_eq(t.wash_button.text, "✓ Gewaschen")
	assert_true(t.wash_button.disabled)
	assert_eq(t.dress_buttons[&"shroud"].text, "Leichentuch · 10 Min · Grabqualität +2")
	assert_true(t.dress_buttons[&"shroud"].disabled)
	assert_eq(t.dress_buttons[&"gown"].text, "Totenhemd · 15 Min · Grabqualität +3")
	assert_false(t.dress_buttons[&"gown"].disabled)
	assert_eq(t.dress_warning.text, MorgueTablePanelState.DRESS_WARNING)
	assert_eq(t.lay_out_reason.text, "Holzkamm nötig – Werkbank.")
	assert_eq(t.balm_button.text, "Geräuchert bis 04:10")
	assert_true(t.balm_button.disabled)
	t.dress_buttons[&"gown"].pressed.emit()
	assert_eq(station.calls, [["dress", &"gown"]])


func test_harvest_button_is_two_stage_and_never_default_focus() -> void:
	await _setup()
	var panel := await _open_exam(_state(true))
	var t := panel.tabs
	t.select_tab(&"harvest")
	var hair: Button = t.harvest_rows[&"hair"].button
	assert_eq(hair.text, "Zopf abschneiden · 10 Min")
	assert_eq((t.harvest_rows[&"hair"].line as Label).text, "+1 Zopf (Ilse zahlt 4) · Grabqualität −1 · Ruf −3 · Der Geist wird es wissen.")
	assert_true((t.harvest_rows[&"teeth"].button as Button).disabled)
	assert_eq((t.harvest_rows[&"teeth"].reason as Label).text, "Werkzeug fehlt – Ilse Kranich hat es.")
	panel.focus_default()
	assert_ne(ui.get_viewport().gui_get_focus_owner(), hair, "never the default focus")
	hair.pressed.emit()
	assert_eq(hair.text, Phase4Texts.TEXT_HARVEST_CONFIRM)
	assert_eq(station.calls, [], "first press only arms")
	hair.pressed.emit()
	assert_eq(station.calls, [["harvest", &"hair"]])
	assert_eq(t.armed_kind, &"")
	t.confirm_seconds = 0.05
	hair.pressed.emit()
	await tree.create_timer(0.2).timeout
	assert_eq(t.armed_kind, &"", "falls back after the timeout")
	assert_eq(hair.text, "Zopf abschneiden · 10 Min")


func test_exam_panel_without_panel_state_keeps_phase2_layout() -> void:
	await _setup()
	var panel := await _open_exam({})
	assert_false(panel.phase4)
	assert_false(panel.tabs.tab_bar.visible)
	assert_true(panel.examine_button.visible)


# --- journal --------------------------------------------------------------------------------

func _journal() -> JournalManager:
	var j := JournalManager.new()
	j.clue_data = Phase4Fixtures.clues()
	j.insight_data = Phase4Fixtures.insights()
	j.piety_config = Phase4Fixtures.piety_config()
	tree.root.add_child(j)
	return j


func test_journal_pages_selection_and_link() -> void:
	await _setup()
	var j := _journal()
	for id: StringName in [&"c_warning_letter", &"c_page_1", &"c_mark", &"c_anchor_snake"]:
		j.add_clue(id, "", true)
	ui.open_panel(&"journal", j.panel_context(&"clues"))
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	assert_eq(panel.current_page, &"clues")
	assert_eq(panel.clue_buttons.size(), 4)
	panel.toggle_clue(&"c_mark")
	panel.toggle_clue(&"c_page_1")
	panel.toggle_clue(&"c_anchor_snake")
	panel.toggle_clue(&"c_warning_letter")
	assert_eq(panel.selected, [&"c_mark", &"c_page_1", &"c_anchor_snake"] as Array[StringName], "at most 3")
	assert_eq(panel.clue_buttons[&"c_mark"].theme_type_variation, &"JournalCardSelected")
	assert_eq(panel.thread.cards.size(), 3, "red thread between the chosen")
	assert_eq(panel.link_selected(), &"", "wrong set")
	assert_eq(panel.link_feedback, JournalManager.LINK_FAIL_TEXT)
	assert_true(panel.feedback_label.visible)
	assert_false(j.has_insight(&"i_warnings"))
	panel.toggle_clue(&"c_mark")
	panel.toggle_clue(&"c_anchor_snake")
	panel.toggle_clue(&"c_warning_letter")
	assert_eq(panel.link_selected(), &"i_warnings")
	assert_true(j.has_insight(&"i_warnings"))
	assert_eq(panel.current_page, &"insights", "reveal on the insight page")
	assert_true(panel.insight_text_label.text.begins_with("Dieselbe schräge Hand"), panel.insight_text_label.text)


func test_journal_page_turn_unread_and_hud_badge() -> void:
	await _setup()
	var j := _journal()
	ui.hud.refresh_journal_badge()
	assert_eq(ui.hud.journal_badge_text(), "[J] Merkbuch")
	j.add_clue(&"c_mark")
	j.add_clue(&"c_page_1")
	ui.hud.refresh_journal_badge()
	assert_eq(ui.hud.journal_badge_text(), "[J] Merkbuch · 2 neu")
	ui.open_journal()
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	assert_eq(panel.current_page, &"people")
	assert_true(panel.page_has_unread(&"clues"))
	assert_eq(panel.tab_dots[&"clues"].modulate.a, 1.0, "unread dot on the tab")
	panel.turn_page(1)
	assert_eq(panel.current_page, &"clues")
	panel.turn_page(1)
	assert_eq(panel.current_page, &"insights", "leaving the clues marks them read")
	assert_eq(j.unread_count(), 0)
	panel.turn_page(-3)
	assert_eq(panel.current_page, &"self", "wraps around")
	ui.toggle_journal()
	await wait_frames(2)
	assert_false(ui.is_open(&"journal"))
	assert_eq(ui.hud.journal_badge_text(), "[J] Merkbuch")


func test_journal_self_page_without_number() -> void:
	await _setup()
	var j := _journal()
	GameState.stats[&"piety"] = 35
	GameState.stats[&"prepared"] = 9
	GameState.stats[&"utilized"] = 2
	ui.open_panel(&"journal", j.panel_context(&"self"))
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	var texts := PackedStringArray()
	for l: Node in panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var all := "\n".join(texts)
	assert_true(all.contains("Du sprichst mit ihnen, wenn keiner zuhört."), all)
	assert_true(all.contains("Hergerichtet: 9 · Verwertet: 2"))
	assert_false(all.contains("35"), "no piety number")


func test_journal_people_death_note() -> void:
	await _setup()
	var j := _journal()
	record.finds_lost = [&"f_mark"]
	record.washed = true
	record.dress = &"gown"
	j.find_data = Phase4Fixtures.finds()
	ui.open_panel(&"journal", j.panel_context(&"people"))
	await wait_frames(1)
	var panel := ui.get_panel(&"journal") as JournalPanel
	assert_eq(panel.chosen_person, record.id)
	assert_eq(JournalPanel.prep_line({"washed": true, "dress": &"gown", "laid_out": false}), "gewaschen · Totenhemd")
	assert_eq(JournalPanel.prep_line({}), "nicht hergerichtet")


# --- trade panel ----------------------------------------------------------------------------

func _trade() -> NightTrade:
	var t := NightTrade.new()
	t.trader_config = Phase4Fixtures.trader_config()
	t.utilization_config = Phase4Fixtures.utilization_config()
	t.schedule = Phase4Fixtures.trader_schedule()
	tree.root.add_child(t)
	GameState.set_flag(&"trader_known", true)
	TimeManager.day = 5
	TimeManager.minute_of_day = 1410
	return t


func test_trade_panel_prices_bonus_stock_and_coins() -> void:
	await _setup()
	var t := _trade()
	var piety := PietyDouble.new()
	tree.root.add_child(piety)
	inv.add_item(&"hair_braid", 2)
	inv.add_item(&"coin", 3)
	ui.open_panel(&"trader", {"speaker": null, "inventory": inv})
	await wait_frames(1)
	var panel := ui.get_panel(&"trader") as TraderPanel
	assert_true(panel.is_present())
	assert_eq(panel.greeting_label.text, "„Guten Abend, Totengräber. Was bringen die Stillen heute?“")
	assert_eq((panel.sell_rows[&"hair_braid"].count as Label).text, "Zopf ×2")
	assert_eq((panel.sell_rows[&"hair_braid"].price as Label).text, "je 4 Münzen")
	assert_false((panel.sell_rows[&"hair_braid"].bonus as Label).visible)
	assert_true((panel.sell_rows[&"teeth_pouch"].one as Button).disabled, "none in the pack")
	assert_eq(panel.sum_label.text, "Zusammen: 8 Münzen")
	assert_eq((panel.buy_rows[&"linen"].stock as Label).text, "noch 3 heute Nacht")
	piety.bonus = 1
	panel.refresh()
	assert_eq((panel.sell_rows[&"hair_braid"].price as Label).text, "je 5 Münzen")
	assert_eq((panel.sell_rows[&"hair_braid"].bonus as Label).text, "+1")
	assert_true(panel.bonus_label.visible, "the +1 shown quietly")
	assert_eq(panel.sell(&"hair_braid", false), 5)
	assert_eq(inv.count(&"coin"), 8, "coins at once")
	assert_eq(panel.reply_label.text, Phase4Texts.TRADE_AFTER_SELL)
	assert_true(panel.buy(&"linen"))
	assert_eq(inv.count(&"linen"), 1)
	assert_eq((panel.buy_rows[&"linen"].stock as Label).text, "noch 2 heute Nacht")
	assert_eq(panel.coins_label.text, "Deine Münzen: 6")
	assert_eq(t.stock_left(&"linen"), 2)


func test_trade_panel_disabled_while_ilse_is_away() -> void:
	await _setup()
	_trade()
	TimeManager.minute_of_day = 720
	inv.add_item(&"hair_braid", 1)
	inv.add_item(&"coin", 9)
	ui.open_panel(&"trader", {"inventory": inv})
	await wait_frames(1)
	var panel := ui.get_panel(&"trader") as TraderPanel
	assert_false(panel.is_present())
	assert_true((panel.sell_rows[&"hair_braid"].one as Button).disabled)
	assert_true((panel.buy_rows[&"juniper"].buy as Button).disabled)
	assert_true(panel.away_label.visible)


func test_dialogue_open_trade_action_opens_the_panel() -> void:
	await _setup()
	_trade()
	EventBus.ui_panel_requested.emit(&"trader", {"speaker": null})
	await wait_frames(1)
	assert_true(ui.is_open(&"trader"))
	assert_true(UIRoot.PANEL_SCRIPTS.has(&"journal"))


# --- chapter panel, notifications, cemetery -------------------------------------------------

func test_six_pits_chapter_panel() -> void:
	await _setup()
	ui.open_panel(&"slice_summary", {"variant": &"six_pits", "days": 21, "burials": 18, "prepared": 12, "utilized": 3,
			"piety": 40, "piety_tier": &"considerate", "insights": 4, "not_lorenz": true, "content_ghosts": 9, "restless_ghosts": 2})
	await wait_frames(1)
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Sechs Gruben")
	assert_true(panel.chapter_grid.visible)
	assert_eq(panel.chapter_value("Pietät"), "Rücksichtsvoll", "a word, no number")
	assert_eq(panel.chapter_value("Erkenntnisse"), "4/5", "only the Phase-4 insights (i_deathbook belongs to Phase 7)")
	assert_eq(panel.chapter_value("Geister"), "9 zufrieden · 2 unruhig")
	assert_true(panel.goal_label.text.ends_with("Unter dem Birkenhang ist es nicht still."))
	ui.open_panel(&"slice_summary", {"days": 6, "burials": 6, "total": 48, "rating": &"dignified"})
	assert_eq(panel.header_label.text, SliceSummaryPanel.TEXT_TITLE)
	assert_false(panel.chapter_grid.visible)


func test_quiet_and_story_notifications() -> void:
	await _setup()
	ui.notifications.push(Piety.TEXT_TIER_DOWN, &"info")
	ui.notifications.push(NightTrade.TEXT_WAITING, &"info")
	ui.notifications.push(NightTrade.TEXT_NOTE, &"info")
	ui.notifications.push("Ruf gestiegen", &"reward")
	assert_eq(ui.notifications.styles(), [&"NoteQuiet", &"NoteQuiet", &"NoteStory", &"NoteReward"] as Array[StringName])
	var arrival := (Database.story_corpses()[0] as StoryCorpseData).arrival_note
	assert_eq(Phase4Texts.note_style(arrival), &"NoteStory")
	assert_eq(Phase4Texts.note_caption(arrival), Phase4Texts.STORY_CAPTION)


func test_venerable_gate_in_breakdown_and_texts() -> void:
	var b := CemeteryStatus.breakdown_of(104, 8, 9, EconomyConfig.resolve())
	assert_eq(b.rating, &"dignified", "gated")
	assert_eq(b.venerable_missing, PackedStringArray(["Zier 8/12", "Pflegeabzug 9 (höchstens 6)"]))
	assert_eq(Phase4Texts.venerable_missing_text(b.venerable_missing), "Für „Ehrwürdig“ fehlt noch: Zier 8/12 · Pflegeabzug 9 (höchstens 6)")
	assert_true(Phase3Texts.quality_tooltip(b).ends_with("Für „Ehrwürdig“ fehlt noch: Zier 8/12 · Pflegeabzug 9 (höchstens 6)"))


# --- objective ------------------------------------------------------------------------------

func _graves(free: int) -> Array[GraveRecord]:
	var out: Array[GraveRecord] = []
	for i: int in free:
		var g := GraveRecord.new()
		g.id = "plot_%02d" % i
		g.state = GraveRecord.State.EMPTY
		out.append(g)
	return out


func test_phase4_objective_lines() -> void:
	var table := CorpseRecord.new()
	table.id = "c1"
	table.location = &"table"
	var none: Array[CorpseRecord] = []
	var on_table: Array[CorpseRecord] = [table]
	assert_eq(ObjectiveResolver.current(on_table, _graves(3), null, 600, {}, {"table_loss": 90}), ObjectiveResolver.TEXT_LOSS)
	assert_eq(ObjectiveResolver.current(on_table, _graves(3), null, 600, {}, {"table_loss": 300}), ObjectiveResolver.TEXT_EXAMINE)
	assert_eq(ObjectiveResolver.current(none, _graves(3), null, 600, {}, {"journal_ready": PackedStringArray(["Wer die Warnbriefe schrieb"])}),
			ObjectiveResolver.TEXT_JOURNAL_READY)
	assert_eq(ObjectiveResolver.current(none, _graves(1), null, 600, {}, {"story_pending": 2}), ObjectiveResolver.TEXT_RESERVED)
	var elder := {"sections": [{"id": &"elder", "name": "Holunderwinkel", "unlocked": false, "done": 0, "total": 10, "block": "", "gate": true}]}
	assert_eq(ObjectiveResolver.current(none, _graves(0), null, 600, {}, elder), "Holunderwinkel aufschließen")
	(elder.sections[0] as Dictionary)["done"] = 4
	assert_eq(ObjectiveResolver.current(none, _graves(0), null, 600, {}, elder), "Holunderwinkel freilegen: 4/10")


# --- debug ----------------------------------------------------------------------------------

func test_debug_phase4_commands() -> void:
	await _setup()
	var lookup := DebugWorldLookup.new(ui)
	var cmds := DebugCommandsPhase4.new(lookup)
	for c: String in ["corpse", "exam", "prep", "harvest", "piety", "clue", "insight", "story", "trader", "decay"]:
		assert_true(cmds.handles(c), c)
	assert_false(bool(cmds.run("piety", PackedStringArray(["200"])).ok))
	assert_false(bool(cmds.run("piety", PackedStringArray(["20"])).ok), "no piety node")
	var piety := Piety.new()
	piety.config = Phase4Fixtures.piety_config()
	tree.root.add_child(piety)
	var r := cmds.run("piety", PackedStringArray(["-30"]))
	assert_true(bool(r.ok), str(r.text))
	assert_eq(GameState.get_stat(&"piety"), -30)
	var j := _journal()
	assert_true(bool(cmds.run("clue", PackedStringArray(["c_mark"])).ok))
	assert_true(j.has_clue(&"c_mark"))
	assert_false(bool(cmds.run("clue", PackedStringArray(["nope"])).ok))
	assert_true(bool(cmds.run("insight", PackedStringArray(["i_warnings"])).ok))
	assert_true(j.has_insight(&"i_warnings"))
	var t := _trade()
	GameState.set_flag(&"trader_known", false)
	assert_true(bool(cmds.run("trader", PackedStringArray(["known"])).ok))
	assert_true(t.is_known())
	assert_true(bool(cmds.run("trader", PackedStringArray(["stock"])).ok))
	assert_false(bool(cmds.run("corpse", PackedStringArray(["stage", "mouldy"])).ok))
	assert_true(DebugCommandsPhase4.HELP.size() >= 8)
