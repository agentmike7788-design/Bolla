extends TestCase
## W-UI Phase 8 (docs/PHASE8_DESIGN.md §6, §7, §10): the chalk board (values = Apprentice / ApprenticeBox, only taught
## tasks can be chosen, the wage tin), the wish card, the favour panel, the festival card, the Merkbuch pages
## „Angehörige" / „Hollerbrück" (mood, the three story points, the favour, the new faces), the orders' groups, four
## clues and the question groups, the festival banner, the encounters' bubbles, the prompts of §7.5, the grave tooltip,
## the register column, Jakob's tin in his box, the memorial plate at the mason's bench, the day summary, the chapter
## panel „Wer heraufkommt" and the debug commands. Systems come from Phase8Fixtures, the P2 visitors harness or small
## doubles – no graveyard scene is needed.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const Harness := preload("res://tests/unit/visitors_harness.gd")
const DAY := 55
const NOON := 720


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false
	var region_id: StringName = &"graveyard"

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return busy


class NpcDouble extends Node3D:
	var npc_id: StringName = &""
	var region_id: StringName = &"graveyard"

	func _init() -> void:
		add_to_group(&"npc")


class JournalDouble extends Node:
	var cards: Array[Dictionary] = []
	var questions: Array[Dictionary] = []
	var found: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"journal")

	func clue_cards() -> Array[Dictionary]:
		return cards

	func open_question_cards() -> Array[Dictionary]:
		return questions

	func has_clue(id: StringName) -> bool:
		return id in found

	func has_insight(_id: StringName) -> bool:
		return false


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var world: Node3D
var h: Harness


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	TimeManager.set_time(DAY, NOON)


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	if h != null:
		h.teardown()
		h = null
	for node: Node in [world, player]:
		if is_instance_valid(node):
			node.queue_free()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	await wait_frames(2)


# --- the chalk board (§7.1) -------------------------------------------------------------------------

func test_board_values_follow_the_apprentice() -> void:
	await _setup()
	var a := _apprentice({"rake": 1, "water": 2}, [{"task": "rake", "area": "yard"}], 9)
	var app: Apprentice = a.apprentice
	var box: ApprenticeBox = a.box
	var panel := _open(&"apprentice_board", {"apprentice": app, "box": box, "inventory": inv, "player": player}) as ApprenticeBoardPanel
	assert_eq(panel.title_label.text, "Jakob – Arbeitsliste")
	var row0: Dictionary = panel.line_rows[0]
	assert_false((row0.tasks[&"rake"] as Button).disabled, "taught task can be chosen")
	assert_true((row0.tasks[&"weed"] as Button).disabled, "untaught task is grey")
	assert_eq((row0.tasks[&"weed"] as Button).tooltip_text, "noch nicht gezeigt")
	assert_eq((row0.tasks[&"rake"] as Button).theme_type_variation, &"ChalkSelected")
	assert_eq((row0.area as Button).text, "‹ Alter Hof ›")
	assert_eq((panel.level_rows[&"rake"].marks as Label).text, "|")
	assert_eq((panel.level_rows[&"water"].marks as Label).text, "||")
	assert_eq((panel.level_rows[&"weed"].marks as Label).text, "–")
	assert_eq((panel.level_rows[&"rake"].practice as Label).text, "noch 12 Stellen bis Geübt")
	assert_false((panel.level_rows[&"water"].practice as Label).visible, "practised: no counter")
	assert_eq(panel.tin_label.text, "Lohndose: 9 Münzen (3 Tage)")
	assert_eq(panel.tin_state_label.text, "bezahlt für 3 Tage")
	assert_false(panel.set_task(1, &"weed"), "untaught cannot be written")
	assert_eq(app.board_lines().size(), 1)
	assert_true(panel.set_task(1, &"water"))
	assert_eq(app.board_lines().size(), 2)
	assert_eq(str(app.board_lines()[1].task), "water")
	panel.cycle_area(0)
	assert_eq(str(app.board_lines()[0].area), "east", "Alter Hof → Ostwiese")
	assert_eq((panel.line_rows[0].area as Button).text, "‹ Ostwiese ›")
	assert_true(panel.deposit_button.disabled, "no coins in the pack")
	inv.add_item(&"coin", 4)
	panel.refresh()
	assert_false(panel.deposit_button.disabled)
	assert_true(panel.deposit())
	assert_eq(box.coins, 12)
	assert_eq(inv.count(&"coin"), 1)
	assert_eq(panel.tin_label.text, "Lohndose: 12 Münzen (4 Tage)")
	assert_true(panel.set_task(0, &""), "clear a line")
	assert_eq(app.board_lines().size(), 1)


func test_board_tin_states_and_done_list() -> void:
	await _setup()
	var a := _apprentice({"rake": 1}, [{"task": "rake", "area": "all"}], 2)
	var app: Apprentice = a.apprentice
	var state := app.save_state()
	state["debt"] = 6
	state["plan_day"] = DAY
	state["progress"] = 2
	state["plan"] = [_plan_entry("rake", 510, "l_01", false), _plan_entry("rake", 530, "l_02", true), _plan_entry("rake", 560, "l_03", false)]
	app.load_state(state)
	var panel := _open(&"apprentice_board", {"apprentice": app, "box": a.box, "inventory": inv, "player": player}) as ApprenticeBoardPanel
	assert_eq(panel.tin_state_label.text, "schuldet 6")
	assert_eq(panel.done_entries().size(), 2)
	assert_true(bool(panel.done_entries()[1].mistake))
	panel.toggle_done()
	assert_true(panel.done_box.visible and not panel.lines_box.visible)
	var texts := _labels(panel.done_box)
	assert_true(_contains(texts, "08:30  Laub harken"), str(texts))
	assert_true(_contains(texts, "ein Fehler"), str(texts))
	assert_eq(panel.done_button.text, "Zurück zur Liste")
	assert_eq(Phase8Texts.tin_state(0, 3, 0), "leer – morgen ohne Lohn")
	assert_eq(Phase8Texts.tin_state(3, 3, 0), "bezahlt bis morgen")
	assert_eq(Phase8Texts.estimate_text([{"task": "rake", "count": 12}, {"task": "weed", "count": 4}],
			[{"task": "rake", "area": "yard"}, {"task": "weed", "area": "linden"}]),
			"≈ 12 Laubstellen im Alten Hof, dann 4 Unkrautstellen im Lindenacker")


# --- the wish card (§7.2) -------------------------------------------------------------------------------

func test_wish_card_shows_and_accepts() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 2)
	var v := h.visitors
	v.load_state({"wishes": [{"wish_id": "w_0001", "kind": "flowers", "grave_id": "l_02", "kin_id": "kin_kehr", "state": "offered",
			"day": DAY, "candle_seen": false, "template": "w_flowers"}], "next_wish": 2})
	var offer := {"wish_id": "w_0001", "kind": &"flowers", "grave_id": "l_02", "text": "Ein paar Blumen. Heide, wenn's geht."}
	var card := _open(&"wish_card", {"offer": offer, "kin_id": &"kin_kehr", "inventory": inv, "player": player}) as WishCard
	assert_eq(card.name_label.text, "Martha Kehr")
	assert_true(card.grave_label.text.begins_with("Hedwig Lamprecht, "), card.grave_label.text)
	assert_eq(card.quote_label.text, "„Ein paar Blumen. Heide, wenn's geht.“")
	assert_eq(card.kind_label.text, "Blumen")
	assert_not_null(card.kind_icon.texture)
	assert_true(card.deadline_label.text.begins_with("bis zum nächsten Besuch (≈ in "), card.deadline_label.text)
	assert_eq(card.reward_label.text, "Die Kehrs werden es dir danken.")
	assert_false(card.full_label.visible)
	assert_true(card.accept())
	assert_eq(str(v.open_wishes()[0].state), "accepted")
	assert_false(ui.is_open(&"wish_card"), "the card closes")


## G8 Runde 1 (B8-2): the card says where the vase comes from (WishData.source_text via Visitors' offer "source").
func test_wish_card_origin_line_for_the_vase() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 2)
	var data := Database.wish(&"w_vase") as WishData
	var card := _open(&"wish_card", {"offer": {"wish_id": "w_0001", "kind": &"vase", "grave_id": "l_02", "text": data.ask_text,
			"source": data.source_text}, "kin_id": &"kin_kehr"}) as WishCard
	assert_true(card.origin_label.visible)
	assert_true(card.origin_label.text.begins_with("Woher: Grabvase: an der Werkbank"), card.origin_label.text)
	card.decline()
	card = _open(&"wish_card", {"offer": {"wish_id": "w_0002", "kind": &"candle", "grave_id": "l_02", "text": "…"},
			"kin_id": &"kin_kehr"}) as WishCard
	assert_false(card.origin_label.visible, "no origin line for a candle")
	card.decline()


func test_wish_card_dimmed_with_three_open() -> void:
	await _setup()
	_harness()
	var wishes: Array = []
	for i: int in 4:
		wishes.append({"wish_id": "w_%04d" % (i + 1), "kind": "tend", "grave_id": "l_0%d" % (i + 1), "kin_id": "kin_kehr",
				"state": "accepted" if i < 3 else "offered", "day": DAY, "candle_seen": false, "template": "w_tend"})
	h.visitors.load_state({"wishes": wishes, "next_wish": 5})
	var card := _open(&"wish_card", {"offer": {"wish_id": "w_0004", "kind": &"tend", "grave_id": "l_04", "text": "…"},
			"kin_id": &"kin_kehr"}) as WishCard
	assert_true(card.is_full())
	assert_true(card.full_label.visible)
	assert_eq(card.full_label.text, "Drei Wünsche sind schon offen.")
	assert_true(card.accept_button.disabled)
	assert_false(card.accept())
	card.decline()
	assert_false(ui.is_open(&"wish_card"))


# --- the favour panel (§7.3) -------------------------------------------------------------------------------

func test_favor_panel_choices_and_cooldown() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 9)
	var f := Phase8Fixtures.story_at(&"priest", 3, null, {"smith": 3, "mayor": 3, "innkeeper": 1})
	h.root.add_child(f)
	var panel := _open(&"favor", {"npc_id": &"priest", "inventory": inv, "player": player}) as FavorPanel
	assert_eq(panel.title_label.text, "Gefallen: Fürbitte")
	assert_eq(panel.question_label.text, "Für wen soll gebetet werden?")
	assert_true(panel.buttons.has("l_02"), str(panel.buttons.keys()))
	assert_false(panel.buttons["l_02"].disabled)
	assert_true(panel.ask("l_02"))
	assert_eq(panel.reply_label.text, "„Gut. Ich kümmere mich darum.“")
	assert_eq(f.prayer_bonus("l_02") > 0 or f.save_state().prayer.get("grave", "") == "l_02", true)
	panel = _open(&"favor", {"npc_id": &"priest"}) as FavorPanel
	assert_true(panel.reason_label.visible, "asked: the return favour first, then the cooldown")
	assert_true(panel.reason_label.text == FavorRules.TEXT_OWED or panel.reason_label.text.begins_with("Gerade erst."), panel.reason_label.text)
	assert_true(panel.buttons["l_02"].disabled)
	panel = _open(&"favor", {"npc_id": &"smith"}) as FavorPanel
	assert_eq(panel.choices().size(), 3, "iron fittings, a mortsafe on loan, a steel rod")
	assert_true(panel.buttons.has("mortsafe_loan"))
	panel = _open(&"favor", {"npc_id": &"mayor"}) as FavorPanel
	assert_eq(panel.choices().size(), 2, "tonight / tomorrow night")
	assert_eq(str(panel.choices()[0].text), "heute Nacht")
	panel = _open(&"favor", {"npc_id": &"innkeeper"}) as FavorPanel
	assert_eq(panel.reason_label.text, "Erst wenn ihr euch richtig kennt.")
	assert_true(panel.buttons[""].disabled)


func test_favor_line_in_the_dialogue_and_the_map_legend() -> void:
	var f := Phase8Fixtures.story_at(&"priest", 3, tree)
	f.load_state(f.save_state().merged({"favor_day": {"priest": DAY - 2}, "return_for": {"priest": DAY - 2}}, true))
	assert_eq(Phase8Texts.favor_hint(f, &"priest"), "[Gefallen] Fürbitte – in 3 Tagen wieder")
	f.load_state(f.save_state().merged({"favor_day": {"priest": DAY - 4}}, true))
	assert_eq(Phase8Texts.favor_hint(f, &"priest"), "[Gefallen] Fürbitte – erst der Gegengefallen", "a return favour is open")
	f.load_state({"steps": {"priest": 3}})
	assert_eq(Phase8Texts.favor_hint(f, &"priest"), "", "ready: the dialogue offers it itself")
	assert_eq(Phase8Texts.favor_hint(f, &"smith"), "", "no story told yet")
	f.queue_free()
	assert_eq(MapLegend.entries().size(), MapLegend.ENTRIES.size())
	GameState.set_flag(&"p8_open", true)
	assert_eq(MapLegend.entries().size(), MapLegend.ENTRIES.size() + MapLegend.ENTRIES_P8.size())


func test_calendar_tooltip_names_hanne_and_the_festivals() -> void:
	await _setup()
	assert_eq(Phase8Status.calendar_text(tree), "", "nothing before p8_open")
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)
	var w := Wanderers.new()
	_world().add_child(w)
	var fest := Phase8Fixtures.fest_today(&"fest_lights", null, DAY + 3)
	_world().add_child(fest)
	ui.hud.refresh_calendar()
	var tip := ui.hud.calendar_tooltip()
	assert_true(tip.contains("Hanne Vogelsang: heute da"), tip)
	assert_true(tip.contains("Lichtgang: Tag %d" % (DAY + 3)), tip)
	TimeManager.set_time(DAY + 1, NOON)
	ui.hud.refresh_calendar()
	assert_true(ui.hud.calendar_tooltip().contains("nächster Besuch in 5 Tagen"), ui.hud.calendar_tooltip())


# --- the festival card (§2.7) -----------------------------------------------------------------------------

func test_fest_panel_lights_and_dance() -> void:
	await _setup()
	_harness()
	for plot: String in ["l_01", "l_02", "l_03"]:
		h.bury(plot, &"house_kehr", DAY - 20)
	var fest := Phase8Fixtures.fest_today(&"fest_lights", null, DAY)
	h.root.add_child(fest)
	h.care.light_free("l_01")
	var panel := _open(&"fest", {}) as FestPanel
	assert_eq(panel.title_label.text, "Lichtgang – Tag %d" % DAY)
	assert_eq(panel.count_label.text, "Kein Grab ohne Licht: 1/3")
	assert_eq(panel.dark_graves().size(), 2)
	assert_true(_contains(_labels(panel.list_box), "Hedwig Lamprecht"))
	h.care.light_free("l_02")
	h.care.light_free("l_03")
	panel.refresh()
	assert_eq(panel.count_label.text, "Kein Grab ohne Licht.")
	fest.queue_free()
	await wait_frames(1)
	var kathrein := Phase8Fixtures.fest_today(&"fest_kathrein", null, DAY)
	h.root.add_child(kathrein)
	panel = _open(&"fest", {"fest_id": &"fest_kathrein"}) as FestPanel
	assert_eq(panel.title_label.text, "Kathreintanz – Tag %d" % DAY)
	assert_true(panel.when_label.text.begins_with("19:00 bis 23:00"), panel.when_label.text)
	assert_true(_contains(_labels(panel.list_box), "Rosine Wackernagel"))


# --- the Merkbuch (§7.4) ----------------------------------------------------------------------------------

func test_journal_kin_page() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 2)
	h.visitors.add_goodwill(&"kin_kehr", 3)
	h.visitors.load_state(h.visitors.save_state().merged({"wishes": [{"wish_id": "w_0001", "kind": "flowers", "grave_id": "l_02",
			"kin_id": "kin_kehr", "state": "accepted", "day": DAY, "candle_seen": false, "template": "w_flowers"}], "next_wish": 2,
			"last_visit": {"l_02": DAY - 1}}, true))
	var life := Phase8Fixtures.p8_open(null, 53)
	h.root.add_child(life)
	var panel := _journal(&"kin")
	assert_eq(panel.current_page, &"kin")
	assert_true(panel.tab_buttons[&"kin"].get_parent().visible, "tab from p8_open")
	var texts := _journal_texts(panel)
	assert_true(_contains(texts, "Martha Kehr"), str(texts))
	assert_true(_contains(texts, "dankbar"), "goodwill 8 → a word: " + str(texts))
	assert_false(_contains(texts, "Wohlwollen 8"), "never the number")
	assert_true(_contains(texts, "Haus Kehr"), str(texts))
	assert_true(_contains(texts, "Gräber: Hedwig Lamprecht"), str(texts))
	assert_true(_contains(texts, "zuletzt: gestern"), str(texts))
	assert_true(_contains(texts, "Blumen · offen"), str(texts))
	h.care.load_state({"flowers": {"l_02": {"planted": TimeManager.total_minutes(), "watered": TimeManager.total_minutes(), "wreath": false}}})
	panel.refresh()
	texts = _journal_texts(panel)
	assert_true(_contains(texts, "Blumen ✓ · frisch bis "), str(texts))


func test_journal_village_page_moods_points_and_new_faces() -> void:
	await _setup()
	_harness()
	var life := Phase8Fixtures.p8_open(null, 53)
	h.root.add_child(life)
	life.set_mood(&"priest", &"low")
	var f := Phase8Fixtures.story_at(&"innkeeper", 1, null, {"priest": 3})
	h.root.add_child(f)
	var panel := _journal(&"village")
	var texts := _journal_texts(panel)
	assert_true(_contains(texts, "heute bedrückt"), str(texts))
	assert_true(_contains(texts, "●○○") or _contains(texts, "●◎○"), str(texts))
	assert_true(_contains(texts, "●●●"), "Lenz: the story is told")
	assert_true(_contains(texts, "Die Geschichte ist erzählt."), str(texts))
	assert_true(_contains(texts, "Gefallen bereit"), str(texts))
	assert_not_null(panel.sheet_button)
	panel.toggle_village_sheet()
	texts = _journal_texts(panel)
	assert_true(_contains(texts, "Jakob Wackernagel"), str(texts))
	assert_true(_contains(texts, "Veit Ammer"), str(texts))
	assert_true(_contains(texts, "Hanne Vogelsang"), str(texts))
	assert_true(_contains(texts, "Noch geht Jakob in Rosines Küche zur Hand."), str(texts))


func test_journal_four_clues_and_question_groups() -> void:
	await _setup()
	var j := JournalDouble.new()
	_world().add_child(j)
	for id: StringName in [&"c_n_veit", &"c_n_kladde", &"c_n_quast_visit", &"c_n_lenz_visit", &"c_n_ott_three"]:
		j.cards.append({"id": id, "title": String(id), "text": "", "kind": &"note", "unread": false})
	j.questions.append({"id": &"i_underlined", "question": "Wen hat Lorenz verdächtigt?", "found": 3, "needed": 4,
			"requires_found": 2, "requires_needed": 2, "any_found": 1, "any_count": 2, "any_total": 4})
	var panel := _journal(&"clues")
	assert_eq(panel.max_selected(), 3, "before p8_open")
	GameState.set_flag(&"p8_open", true)
	assert_eq(panel.max_selected(), 4)
	for c: Dictionary in j.cards:
		panel.toggle_clue(StringName(str(c.id)))
	assert_eq(panel.selected.size(), 4, "two required + two of four")
	var texts := _journal_texts(panel)
	assert_true(_contains(texts, "Muss sein: 2/2"), str(texts))
	assert_true(_contains(texts, "Zwei von vier: 1/2"), str(texts))
	assert_eq(Phase8Texts.question_groups({"any_count": 0}).size(), 0)


func test_orders_groups() -> void:
	assert_eq(JournalPagesPhase8.order_group(Phase8Fixtures.order(&"of_rosine_1")), &"friend")
	assert_eq(JournalPagesPhase8.order_group(Phase8Fixtures.order(&"of_rosine_return_1")), &"owed")
	var o := OrderData.new()
	o.id = &"o_rosine_berries"
	assert_eq(JournalPagesPhase8.order_group(o), &"village")


# --- HUD (§7.5) -------------------------------------------------------------------------------------------

func test_fest_banner_at_six_and_three() -> void:
	await _setup()
	var fest := Phase8Fixtures.fest_today(&"fest_lights", null, DAY)
	_world().add_child(fest)
	var banner := ui.fest_banner
	assert_not_null(banner)
	banner._on_time_tick(DAY, 600)
	assert_eq(banner.shown_text, "", "only at 06:00 and 15:00")
	banner._on_time_tick(DAY, 360)
	assert_eq(banner.shown_text, "Heute Abend: Lichtgang")
	assert_true(banner.visible)
	fest.queue_free()
	await wait_frames(1)
	var kathrein := Phase8Fixtures.fest_today(&"fest_kathrein", null, DAY)
	_world().add_child(kathrein)
	banner._on_time_tick(DAY, 900)
	assert_eq(banner.shown_text, "Kathreintanz im Holderkrug (ab 19:00)")
	assert_eq(Phase8Texts.fest_banner(&"", 0), "")


func test_chatter_bubbles_one_encounter_two_speakers() -> void:
	await _setup()
	var theres := _npc(&"grocer")
	var liesel := _npc(&"washer")
	var b := ui.chatter_bubbles
	EventBus.chatter_line.emit(&"ch_well_spin", &"grocer", "Hast du gehört?")
	assert_eq(b.count(), 1)
	var bubble := theres.get_node("ChatterBubble") as Label3D
	assert_eq(bubble.text, "Hast du gehört?")
	assert_eq((bubble.get_node("Name") as Label3D).text, "Theres Mangold", "the name small below")
	EventBus.chatter_line.emit(&"ch_well_spin", &"washer", "Ich hör immer.")
	assert_eq(b.count(), 2, "a conversation: both bubbles")
	assert_true(bubble.modulate.a < 1.0, "the earlier line dimmed")
	EventBus.chatter_line.emit(&"apprentice", &"apprentice", "Verstanden.")
	assert_eq(b.count(), 0, "another encounter clears the old (Jakob has no Npc here)")
	assert_false(liesel.has_node("ChatterBubble") and not (liesel.get_node("ChatterBubble") as Node).is_queued_for_deletion())


func test_prompts_of_the_contract() -> void:
	assert_eq(ApprenticeBoard.PROMPT, "[E] Arbeitsliste für Jakob")
	assert_eq(ApprenticeBoard.TEXT_EMPTY, "Eine leere Kreidetafel.")
	assert_eq(ApprenticeBox.PROMPT_BOX, "[E] Jakobs Kiste")
	assert_eq(GraveCare.TEXT_CAN_EMPTY, "Die Gießkanne ist leer.")
	assert_eq(GraveCare.TEXT_TOO_EARLY, "Erst am Nachmittag.")
	assert_true(RainBarrel.PROMPT.begins_with("[E] Gießkanne füllen"))
	assert_true(WatchSpot.PROMPT_FORMAT.begins_with("[E] Im Schatten warten (bis ≈ "))
	assert_eq(TipStone.PROMPT_FORMAT % Phase8Texts.coins_on_stone(2, "Martha Kehr"), "[E] Zwei Münzen auf dem Stein (Martha Kehr)", "QA8-10")


# --- objective line from the systems (§7.5) ------------------------------------------------------------------

func test_objective_state_from_the_systems() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 2)
	var life := Phase8Fixtures.p8_open(null, 53)
	h.root.add_child(life)
	var tree_ := ui.get_tree()
	var s := Phase8Status.objective_state(tree_)
	assert_false(bool(s.intro))
	assert_eq(Phase8Texts.objective({"p8": s}), "Sprich mit Osric")
	GameState.set_flag(&"p8_intro", true)
	s = Phase8Status.objective_state(tree_)
	assert_eq(Phase8Texts.objective({"p8": s}), "Wer heraufkommt: 0/4", "Rosine not ready without Friendship")
	h.visitors.load_state(h.visitors.save_state().merged({"plan_day": DAY, "plan": [{"visit_id": "v_1", "kin_id": "kin_kehr",
			"graves": ["l_02"], "slot": 570, "phase": "waiting"}]}, true))
	s = Phase8Status.objective_state(tree_)
	assert_eq(Phase8Texts.objective({"p8": s}), "Martha Kehr wartet am Grab")
	player.region_id = &"village"
	s = Phase8Status.objective_state(tree_)
	assert_ne(Phase8Texts.objective({"p8": s}), "Martha Kehr wartet am Grab", "only on the graveyard")
	h.care.set_disturbed("l_02")
	s = Phase8Status.objective_state(tree_)
	assert_eq(Phase8Texts.objective({"p8": s}), "Ein Grab ist aufgewühlt")


# --- grave tooltip & register (§7.2, §7.6) ---------------------------------------------------------------------

func test_grave_tooltip_and_register_column() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 12)
	var now := TimeManager.total_minutes()
	h.care.load_state({"flowers": {"l_02": {"planted": now, "watered": now, "wreath": false}}, "mortsafes": {"l_02": now - 3 * 1440}})
	h.care.light_free("l_02")
	h.visitors.load_state({"wishes": [{"wish_id": "w_0001", "kind": "candle", "grave_id": "l_02", "kin_id": "kin_kehr", "state": "accepted",
			"day": DAY, "candle_seen": false, "template": "w_candle"}], "tips_on_stone": {"l_02": [2, "kin_kehr"]}, "next_wish": 2})
	var info: Dictionary = Phase8Status.grave_info(ui.get_tree())
	assert_true(info.has("l_02"))
	var lines := Phase8Texts.grave_lines(info["l_02"])
	assert_true(_contains(lines, "Blumen frisch (gießen in ≈ 2 Tagen)"), str(lines))
	assert_true(_contains(lines, "Kerze brennt"), str(lines))
	assert_true(_contains(lines, "Grabgitter seit 3 Tagen"), str(lines))
	assert_true(_contains(lines, "Die Kehrs: ruhig"), str(lines))
	assert_true(_contains(lines, "Wunsch: Kerze"), str(lines))
	assert_true(_contains(lines, "Zwei Münzen auf dem Stein (Martha Kehr)"), str(lines))
	h.care.set_disturbed("l_02")
	lines = Phase8Texts.grave_lines(Phase8Status.grave_info(ui.get_tree())["l_02"])
	assert_true(_contains(lines, "aufgewühlt"), str(lines))
	var entries := GraveRegisterPanel.complete_entries([{"name": "Hedwig Lamprecht", "grave_id": "l_02", "day_buried": DAY - 12}], ui.get_tree())
	var cells := GraveRegisterPanel.cells(entries[0], false, true)
	assert_eq(cells[cells.size() - 1], "Haus Kehr ¡ # !", "the digger trod the flowers")
	for w: int in 11:
		assert_eq(Phase8Texts.goodwill_word(w), ["verbittert", "verbittert", "enttäuscht", "enttäuscht", "ruhig", "ruhig", "zufrieden",
				"zufrieden", "dankbar", "dankbar", "dankbar"][w])


# --- Jakob's box, the memorial plate -------------------------------------------------------------------------

func test_box_coin_tin_in_the_chest_panel() -> void:
	await _setup()
	var a := _apprentice({}, [], 3)
	var box: ApprenticeBox = a.box
	inv.add_item(&"coin", 5)
	var panel := _open(&"chest", {"storage": box.storage, "inventory": inv, "chest": box, "coins_box": box}) as ChestPanel
	assert_eq(panel.title_label.text, "Jakobs Kiste")
	assert_true(panel.tin_row.visible)
	assert_eq(panel.tin_label.text, "Lohndose: 3 Münzen (1 Tag)")
	assert_true(panel.tin_deposit())
	assert_eq(box.coins, 6)
	assert_eq(inv.count(&"coin"), 2)
	assert_true(panel.tin_withdraw())
	assert_eq(box.coins, 3)
	panel = _open(&"chest", {"storage": box.storage, "inventory": inv, "chest": null}) as ChestPanel
	assert_false(panel.tin_row.visible, "an ordinary chest has no tin")


func test_memorial_plate_needs_rosine_two() -> void:
	var recipe := Database.recipe(&"memorial_plate") as RecipeData
	assert_not_null(recipe)
	assert_false(CraftingPanel.offered(recipe))
	var stone := StoneDesignPanel.new()
	assert_eq(stone.extra_recipes().size(), 0)
	GameState.set_flag(&"friend_innkeeper_2", true)
	assert_true(CraftingPanel.offered(recipe))
	assert_eq(stone.extra_recipes().size(), 1)
	assert_eq(stone.extra_recipes()[0].id, &"memorial_plate")
	stone.free()
	var plain := RecipeData.new()
	assert_true(CraftingPanel.offered(plain), "no flag = always")


# --- day summary & chapter (§7.6, §7.7) ----------------------------------------------------------------------

func test_day_summary_phase8_rows() -> void:
	await _setup()
	var log8 := ui.day_log8
	EventBus.grave_viewed.emit("l_02", &"kin_kehr", &"kept")
	EventBus.wish_changed.emit("w_0001", &"offered")
	EventBus.wish_changed.emit("w_0002", &"done")
	EventBus.payment_received.emit(2, "Trinkgeld")
	EventBus.payment_received.emit(5, "Verkauf")
	EventBus.apprentice_job_done.emit(&"rake", "l_04", false)
	EventBus.apprentice_job_done.emit(&"rake", "l_05", true)
	EventBus.coins_spent.emit(3, &"apprentice")
	EventBus.robber_event.emit(&"seen", "l_02")
	EventBus.robber_event.emit(&"fled", "l_02")
	ui.open_panel(&"day_summary", {"day": DAY, "burials_today": 0, "coins_today": 4, "total": 50, "rating": &"orderly"})
	var panel := ui.get_panel(&"day_summary") as DaySummaryPanel
	assert_eq(panel.row_text(panel.visits_label), "Martha Kehr (l_02, gepflegt)")
	assert_eq(panel.row_text(panel.wishes_label), "1 erfüllt · 1 neu")
	assert_eq(panel.row_text(panel.tips_label), "+2 Münzen")
	assert_eq(panel.row_text(panel.jakob_label), "Laub harken 2 · Fehler: l_05 · Lohn 3")
	assert_eq(panel.row_text(panel.night_label), "Grabräuber gesehen · verscheucht")
	assert_true(log8.visits.is_empty(), "taken")
	ui.close_panel(&"day_summary")
	ui.open_panel(&"day_summary", {"day": DAY + 1})
	assert_eq(panel.row_text(panel.visits_label), "", "a quiet day hides the rows")
	EventBus.notification_requested.emit(Apprentice.TEXT_UNPAID, &"info")
	assert_eq(Phase8Texts.jakob_text(ui.day_log8.take().jakob), "ohne Lohn heim")


func test_chapter_panel_who_comes_up() -> void:
	await _setup()
	var ctx := {"variant": &"who_comes_up", "chapter": &"who_comes_up", "days_open": 9, "visits_seen": 11, "wishes_done": 6,
			"wishes_failed": 1, "tips_coins": 14, "apprentice_levels": {"rake": 2, "weed": 1, "water": 1, "candle": 0}, "apprentice_jobs": 83,
			"apprentice_mistakes": 2, "apprentice_wage": 21, "friend_steps": 7, "favors_used": 2, "favors_returned": 1, "dances": 2,
			"robber_encounters": 2, "night_visits_observed": 3, "steps_by_npc": {"innkeeper": 3, "priest": 2}, "lights_result": &"lights_all",
			"robber_fate": &"reported", "insights": ["i_underlined"], "final_line": "Früher kam nur Osric den Hügel herauf."}
	ui.open_panel(&"slice_summary", ctx)
	var panel := ui.get_panel(&"slice_summary") as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Wer heraufkommt")
	assert_true(panel.people_grid.visible and not panel.village_grid.visible)
	assert_eq(panel.people_value("Tage seit dem ersten Besuch"), "9")
	assert_eq(panel.people_value("Wünsche"), "erfüllt 6 · verfehlt 1")
	assert_eq(panel.people_value("Trinkgeld"), "14 Münzen")
	assert_eq(panel.people_value("Jakob"), "Laub harken ||, Unkraut jäten |, Blumen gießen | · 83 Stellen · 2 Fehler · Lohn 21")
	assert_eq(panel.people_value("Geschichten"), "Rosine ●●● · Lenz ●●○")
	assert_eq(panel.people_value("Lichtgang"), "Kein Grab ohne Licht")
	assert_eq(panel.people_value("Der Nachtgräber"), "2 Begegnungen · beim Schultheiß")
	assert_eq(panel.people_value("Erkenntnisse"), "Der unterstrichene Name")
	assert_eq(panel.goal_label.text, "Früher kam nur Osric den Hügel herauf.")


# --- debug (§6) ------------------------------------------------------------------------------------------------

func test_debug_commands_without_world() -> void:
	for command: String in ["p8 open", "moods", "mood innkeeper low", "react wish_done", "visits", "visit kehr", "goodwill kehr 7",
			"wish l_02 flowers", "wishes", "tip l_02 2", "flowers l_02", "candle all", "mortsafe l_02", "disturb l_02", "apprentice hire",
			"apprentice plan", "box coins 9", "step innkeeper 1", "favor priest", "fest lights today", "lights all", "peddler", "alms 2",
			"robber tonight", "vis8", "goal8"]:
		var r := Debug.execute(command)
		assert_false(r.ok, command)
		assert_true(str(r.text).contains("Keine Spielwelt"), command + ": " + str(r.text))
	var help := str(Debug.execute("help").text)
	assert_true(help.contains("p8 open") and help.contains("goal8") and help.contains("nightpath <ott|kehr> [now]"), help)
	assert_true(Debug.execute("d2").ok)
	assert_eq(int(GameState.get_flag(&"ott_dead")), DAY)
	assert_false(Debug.execute("fest kirmes").ok)
	assert_false(Debug.execute("mood innkeeper happy").ok)


func test_debug_commands_with_fixtures() -> void:
	await _setup()
	_harness()
	h.bury("l_02", &"house_kehr", DAY - 2)
	var life := Phase8Fixtures.p8_open(null, 53)
	h.root.add_child(life)
	assert_true(Debug.execute("mood priest low").ok)
	assert_eq(life.mood(&"priest"), &"low")
	assert_true(str(Debug.execute("moods").text).contains("Lenz heute bedrückt"))
	assert_true(Debug.execute("goodwill kehr 8").ok)
	assert_eq(h.visitors.goodwill(&"kin_kehr"), 8)
	assert_true(Debug.execute("wish l_02 flowers").ok)
	assert_eq(h.visitors.open_wishes().size(), 1)
	assert_true(str(Debug.execute("wishes").text).contains("l_02"))
	assert_true(Debug.execute("tip l_02 2").ok)
	assert_eq(h.visitors.tip_on_stone("l_02").x, 2)
	assert_true(Debug.execute("flowers l_02 wilted").ok)
	assert_eq(h.care.flowers_state("l_02"), &"wilted")
	assert_true(Debug.execute("candle l_02").ok)
	assert_true(h.care.candle_lit("l_02"))
	assert_true(Debug.execute("disturb l_02").ok)
	assert_true(h.care.is_disturbed("l_02"))
	assert_true(Debug.execute("visit kehr").ok)
	assert_false(h.visitors.visit_of(&"kin_kehr").is_empty())
	var a := _apprentice({}, [], 0)
	assert_true(Debug.execute("apprentice level rake 2").ok)
	assert_eq((a.apprentice as Apprentice).level(&"rake"), 2)
	assert_true(Debug.execute("apprentice morale 5").ok)
	assert_eq((a.apprentice as Apprentice).morale(), 5)
	assert_true(Debug.execute("box coins 9").ok)
	assert_eq((a.box as ApprenticeBox).coins, 9)
	var f := Phase8Fixtures.story_at(&"priest", 0)
	h.root.add_child(f)
	assert_true(Debug.execute("step priest 3").ok)
	assert_eq(f.step_done(&"priest"), 3)
	assert_true(GameState.flag_on(&"friend_priest_3"))
	assert_true(Debug.execute("favor priest").ok)
	var fest := Phase8Fixtures.fest_today(&"fest_kathrein", null, DAY - 3)
	h.root.add_child(fest)
	assert_true(Debug.execute("fest lights today").ok)
	assert_eq(fest.today(), &"fest_lights")
	assert_true(str(Debug.execute("goal8").text).begins_with("Wer heraufkommt 0/4"))


# --- helpers ------------------------------------------------------------------------------------------------

func _setup() -> void:
	player = FakePlayer.new()
	player.name = "FakePlayer"
	inv = Inventory.new()
	inv.slot_count = 30
	inv.name = "Inventory"
	player.add_child(inv)
	player.inventory = inv
	tree.root.add_child(player)
	ui = await add_scene(UI_SCENE) as UIRoot


func _world() -> Node3D:
	if world == null:
		world = Node3D.new()
		world.name = "P8UiWorld"
		tree.root.add_child(world)
	return world


func _harness() -> void:
	h = Harness.new()
	h.setup(tree, 53)
	h.all_kin()
	# The harness' NpcLife double would stand in for the real NpcLife of these tests.
	h.life.remove_from_group(&"npc_life")


func _apprentice(levels: Dictionary, lines: Array, coins: int) -> Dictionary:
	var a := Phase8Fixtures.apprentice_with(levels, lines, coins, tree)
	# Phase8Fixtures adds both under tree.root; keep them with this test's world.
	for key: String in ["apprentice", "box"]:
		var n: Node = a[key]
		n.reparent(_world())
	return a


func _plan_entry(task: String, start: int, grave: String, mistake: bool) -> Dictionary:
	return {"task": task, "spot_id": "dirt_" + grave, "grave_id": grave, "start": start, "walk_minutes": 0, "work_start": start,
			"work_minutes": 15, "end": start + 15, "path": [], "mistake": mistake, "kind": "leaves", "consumes": ""}


func _open(id: StringName, ctx: Dictionary) -> UIPanel:
	ui.open_panel(id, ctx)
	return ui.get_panel(id)


func _journal(page: StringName) -> JournalPanel:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"p8_open", page != &"clues" or GameState.flag_on(&"p8_open"))
	ui.open_panel(&"journal", {"page": page})
	return ui.get_panel(&"journal") as JournalPanel


func _npc(id: StringName) -> NpcDouble:
	var n := NpcDouble.new()
	n.npc_id = id
	n.name = "npc_%s" % id
	_world().add_child(n)
	return n


func _journal_texts(panel: JournalPanel) -> PackedStringArray:
	var out := PackedStringArray()
	for page: Control in [panel.left_page, panel.right_page]:
		out.append_array(_labels(page))
	return out


func _labels(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


func _contains(texts: PackedStringArray, part: String) -> bool:
	for t: String in texts:
		if t.contains(part):
			return true
	return false
