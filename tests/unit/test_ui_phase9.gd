extends TestCase
## W-UI Phase 9 (docs/PHASE9_DESIGN.md §6, §7, §10): the Merkbuch tabs „Vorhaben" (groups, steps as sentences, hidden
## steps, „Verfolgen" → HUD line), „Die Liste" (two inks, names, witnesses, „Niemandem sagen") and „Briefe" (open letters
## with „Entscheiden …", copies), the letter card (choices with their place, dimmed ones with a reason, reading),
## Brenneisen's panel (offers, „Verkaufen" / „Nein"), the large requests in the gate's and the parish board's panels (parts
## ✓ / ○, stamp „halb"), every new panel docked at 1280 × 720 … 1920 × 1080, the objective lines, the day summary rows, the
## chapter panel „Wer weiß, wann?", the hand props of the letter clips and the debug commands. Systems come from
## Phase9Fixtures or small doubles – no graveyard scene is needed.

const UI_SCENE := "res://src/ui/ui_root.tscn"
const DAY := Phase9Fixtures.OPEN_DAY
const NOON := 720
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1366, 768)]


class FakePlayer extends Node3D:
	var inventory: Inventory
	var busy: bool = false
	var region_id: StringName = &"graveyard"

	func _init() -> void:
		add_to_group(&"player")

	func is_busy() -> bool:
		return busy


class JournalDouble extends Node:
	var page: Dictionary = {}
	var letters: Array[Dictionary] = []
	var clues: Array[StringName] = []
	var insights: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"journal")

	func list_known() -> bool:
		return bool(page.get("known", false))

	func list_page() -> Dictionary:
		return page

	func letter_pages() -> Array[Dictionary]:
		return letters

	func has_clue(id: StringName) -> bool:
		return id in clues

	func has_insight(id: StringName) -> bool:
		return id in insights

	func clue_cards() -> Array[Dictionary]:
		return []

	func open_question_cards() -> Array[Dictionary]:
		return []


var ui: UIRoot
var player: FakePlayer
var inv: Inventory
var world: Node3D
var _extra: Array[Node] = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	TimeManager.set_time(DAY, NOON)


func after_each() -> void:
	if is_instance_valid(ui):
		ui.close_all()
		ui.queue_free()
	for node: Node in _extra + [world, player]:
		if is_instance_valid(node):
			node.queue_free()
	_extra.clear()
	Phase9Fixtures.remove_injected_items()
	UIState.clear()
	GameState.reset()
	TimeManager.reset()
	Debug.reset()
	await wait_frames(2)


# --- „Vorhaben" (§7.1) ---------------------------------------------------------------------------------------------

func test_plans_groups_steps_and_pin() -> void:
	await _setup()
	var q := _keep(Phase9Fixtures.quest_at(&"q_who_knows", &"h3", tree)) as Quests
	_keep(Phase9Fixtures.large_pinned(&"hrl_ferry_graves", [true, false, false] as Array[bool], tree))
	var panel := _journal(&"plans")
	assert_true(&"plans" in panel.pages(), "the tab is there from p9_open")
	assert_eq(panel.current_page, &"plans")
	var texts := _journal_texts(panel)
	for g: String in ["Hauptkette", "Große Bitten"]:
		assert_true(_contains(texts, g), "group " + g)
	assert_false(_contains(texts, "Freundschaft"), "empty groups are left out")
	assert_true(panel.plan_buttons.has(&"q_who_knows"), "the main chain is an entry")
	assert_true(panel.plan_buttons.has(&"hrl_ferry_graves"), "the large request is an entry")
	assert_eq(panel.plan_selected, &"q_who_knows", "the first entry is shown")
	# done steps as sentences in ink, the current one in pencil with its hint, the future as „…"
	assert_true(_contains(texts, "Du hast Lorenz' Kladde gelesen."), "h1 as a sentence")
	assert_true(_contains(texts, "Wer hat das Licht gesehen?"), "the current step")
	assert_true(_contains(texts, "Frag die, die nachts die Fenster sehen."), "its hint")
	assert_true(_has_label(panel.right_page, "…", &"InkDimLabel"), "future steps hidden")
	assert_false(_contains(texts, "Was wird aus Johann?"), "a future step's title stays hidden")
	assert_true(_has_variation(panel.right_page, "Wer hat das Licht gesehen?", &"InkPencilLabel"), "pencil")
	assert_true(_has_variation(panel.right_page, "Du hast Lorenz' Kladde gelesen.", &"InkLabel"), "ink")
	# „Verfolgen" pins one entry → the HUD line
	assert_eq(panel.pin_button.text, "Verfolgen")
	panel.pin_button.pressed.emit()
	assert_eq(q.pinned(), &"q_who_knows")
	assert_eq(panel.pin_button.text, "Nicht mehr verfolgen")
	assert_true((panel.plan_buttons[&"q_who_knows"] as Button).text.begins_with("◆"), "pinned mark")
	assert_eq(QuestLog.objective(tree).get("id"), &"q_who_knows")
	assert_eq(ui.hud.objective_label.text, "Wer hat das Licht gesehen?", "the HUD shows the pinned step")
	# another entry replaces it (max_pinned 1)
	(panel.plan_buttons[&"hrl_ferry_graves"] as Button).pressed.emit()
	assert_eq(panel.plan_selected, &"hrl_ferry_graves")
	panel.pin_button.pressed.emit()
	assert_eq(q.pinned(), &"hrl_ferry_graves", "one entry at a time")
	assert_true(ui.hud.objective_label.text.begins_with("Bitte: Die Gräber der Fähre"), ui.hud.objective_label.text)
	var t2 := _journal_texts(panel)
	assert_true(_contains(t2, "✓"), "a done part")
	assert_true(_contains(t2, "○"), "an open part")
	panel.pin_button.pressed.emit()
	assert_eq(q.pinned(), &"", "Nicht mehr verfolgen")


func test_plans_keyboard_and_tabs_q_e() -> void:
	await _setup()
	_keep(Phase9Fixtures.quest_at(&"q_who_knows", &"h2", tree))
	_keep(Phase9Fixtures.large_pinned(&"hrl_crosses", [false, false] as Array[bool], tree))
	var panel := _journal(&"plans")
	await wait_frames(2)
	var focus := ui.get_viewport().gui_get_focus_owner()
	assert_eq(focus, panel.plan_buttons[&"q_who_knows"], "the chosen entry has the focus")
	(panel.plan_buttons[&"hrl_crosses"] as Button).pressed.emit()
	await wait_frames(2)
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.plan_buttons[&"hrl_crosses"], "the focus stays on the entry")
	var before := panel.current_page
	_press(&"interact")
	await wait_frames(1)
	assert_ne(panel.current_page, before, "E turns the tab")
	_press(&"drop")
	await wait_frames(1)
	assert_eq(panel.current_page, before, "Q turns it back")


func test_plans_shown_from_the_first_large_request() -> void:
	await _setup()
	GameState.set_flag(&"village_open", true)
	var hill := _keep(Phase9Fixtures.large_pinned(&"hrl_crosses", [] as Array[bool], tree)) as HillRequests
	hill.load_state({})
	ui.open_panel(&"journal", {"page": &"people"})
	var panel := ui.get_panel(&"journal") as JournalPanel
	assert_false(&"plans" in panel.pages(), "no large request yet")
	ui.close_all()
	hill.load_state({"large_board": {"gate": ["hrl_crosses"]}})
	ui.open_panel(&"journal", {"page": &"plans"})
	assert_true(&"plans" in panel.pages(), "the first large request opens the tab")
	assert_false(&"letters" in panel.pages(), "„Briefe“ only from p9_open")


func test_plans_ending_and_choice_sentences() -> void:
	await _setup()
	var q := _keep(Phase9Fixtures.ending(&"stay", tree)) as Quests
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "done": {"q_who_knows": ["h1", "h2", "h3", "h4", "h5", "h6"]},
			"choices": {"q_who_knows": {"h5": "confide_washer", "h6": "stay"}}, "ending": {"q_who_knows": "stay"}})
	var panel := _journal(&"plans")
	var texts := _journal_texts(panel)
	assert_true(_contains(texts, "Du hast es Liesel gesagt."), "a choice as a sentence")
	assert_true(_contains(texts, "Ende: Bei Grete"), "the ending with its title")
	assert_false(_contains(texts, "+"), "no numbers for consequences")


# --- „Die Liste" (§7.2) --------------------------------------------------------------------------------------------

func test_list_two_inks_names_witnesses_and_confide() -> void:
	await _setup()
	var q := _keep(Phase9Fixtures.quest_at(&"q_who_knows", &"h5", tree)) as Quests
	GameState.set_flag(&"q_sieber_marked", true)
	var j := _journal_double()
	j.page = {"known": true, "footer": "Licht. Drei Wochen.", "struck": "Wer weiß, wann?", "confide_none": true, "entries": [
		{"id": &"e_dorn", "initial": "D.", "ink": &"old", "date": "2. Julmond 1833", "name": "Kaspar Dorn", "witness": "Liesel Dorn",
				"witnessed": true, "matched": true, "open": false},
		{"id": &"e_quendel", "initial": "Q.", "ink": &"old", "date": "17. Gilbhart", "name": "", "witness": "Osric",
				"witnessed": false, "matched": false, "open": false},
		{"id": &"e_open", "initial": "S.", "ink": &"fresh", "date": "22. Nebelung", "name": "Johann Sieber. Er lebt noch.",
				"witness": "Veit Ammer", "witnessed": true, "matched": false, "open": true}]}
	var panel := _journal(&"list")
	assert_true(&"list" in panel.pages(), "the tab once the ledger is read")
	assert_eq(panel.list_rows.size(), 3)
	var dorn: Array = panel.list_rows[0]
	assert_eq((dorn[0] as Label).text, "2. Julmond 1833")
	assert_eq((dorn[0] as Label).theme_type_variation, &"InkOldLabel", "old ink")
	assert_eq(((panel.list_rows[2] as Array)[0] as Label).theme_type_variation, &"InkFreshLabel", "fresh ink")
	assert_eq((dorn[2] as Label).text, "Kaspar Dorn")
	assert_eq((dorn[3] as Label).text, "✓", "witness asked")
	assert_eq(((panel.list_rows[1] as Array)[3] as Label).text, "–")
	assert_eq(((panel.list_rows[1] as Array)[2] as Label).text, "", "no name before it is matched")
	var texts := _journal_texts(panel)
	assert_true(_contains(texts, "Licht. Drei Wochen."))
	var struck := false
	for l: Node in panel.left_page.find_children("*", "Label", true, false):
		struck = struck or (l is JournalPagesPhase9.StruckLabel and (l as Label).text == "Wer weiß, wann?")
	assert_true(struck, "the struck-out line")
	assert_true(_contains(texts, "1 von 2 Gräbern verglichen · 1 von 2 Zeugen gefragt"))
	assert_not_null(panel.confide_button, "„Niemandem sagen“ after H4")
	panel.confide_button.pressed.emit()
	assert_eq(q.choice_of(&"q_who_knows", &"h5"), &"confide_none")


func test_list_unknown_before_the_ledger() -> void:
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var j := _journal_double()
	j.page = {"known": false}
	var panel := _journal(&"plans")
	assert_false(&"list" in panel.pages())


# --- „Briefe" (§7.2) and the letter card (§7.3) -----------------------------------------------------------------------

func test_letters_page_decide_opens_the_card() -> void:
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var made := Phase9Fixtures.letter_in(inv, &"lp_l1_carter", tree)
	_keep(made.letters)
	var uid := str(made.uid)
	var j := _journal_double()
	j.letters = [{"uid": "lt_9999", "id": &"lg_grocer", "outside": "An Theres Mangold", "sender": "Jost", "state": &"delivered",
			"line": "Theres hat ihn in die Schürze gesteckt.", "text": "Liebe Theres.", "day": 60, "kind": &"pocket"}] as Array[Dictionary]
	var panel := _journal(&"letters")
	assert_true(panel.letter_buttons.has(uid), "the letter in the bag has „Entscheiden …“")
	assert_eq((panel.letter_buttons[uid] as Button).text, "Entscheiden …")
	assert_true(_contains(_journal_texts(panel), "Theres hat ihn in die Schürze gesteckt."), "where a letter went")
	assert_true(_contains(_journal_texts(panel), "„Liebe Theres.“"), "the copy of a read one")
	(panel.letter_buttons[uid] as Button).pressed.emit()
	await wait_frames(1)
	assert_eq(ui.top(), &"letter", "the letter card over the Merkbuch")
	var card := ui.get_panel(&"letter") as LetterPanel
	assert_eq(card.uid, uid)
	ui.close_top_panel()
	assert_eq(ui.top(), &"journal", "back in the Merkbuch")


func test_letter_card_choices_places_and_reasons() -> void:
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var made := Phase9Fixtures.letter_in(inv, &"lp_l1_carter", tree)
	var letters := _keep(made.letters) as Letters
	var uid := str(made.uid)
	var card := _open(&"letter", {"uid": uid, "inventory": inv, "player": player}) as LetterPanel
	assert_true(card.dock_right, "docked")
	assert_false(ui.dim.visible, "no dim")
	assert_eq(card.outside_label.text, letters.letter(uid).outside, "the outside in the hand's colour")
	assert_eq(card.outside_label.theme_type_variation, &"InkFreshLabel")
	assert_true(card.choice_rows.size() >= 3, "deliver, read, burn …")
	for id: StringName in card.choice_rows:
		var b := card.choice_button(id)
		var reason: Label = card.choice_rows[id].reason
		assert_eq(b.disabled, reason.visible, "%s: a dimmed choice names its reason" % id)
		assert_false(b.text.contains("+"), "no numbers")
	assert_true(card.choice_button(&"burn").disabled, "not at the fire")
	assert_eq((card.choice_rows[&"burn"].reason as Label).text, LetterRules.TEXT_AT_FIRE)
	assert_true(card.choice_button(&"burn").text.contains("Ofen"), "the choice names its place")
	# at the stove the same choice is possible
	ui.close_all()
	card = _open(&"letter", {"uid": uid, "inventory": inv, "player": player, "place": &"stove"}) as LetterPanel
	assert_false(card.choice_button(&"burn").disabled, "at the stove")
	# reading (no Player: at once) shows the text
	ui.close_all()
	card = _open(&"letter", {"uid": uid, "inventory": inv, "player": player}) as LetterPanel
	if not card.choice_button(&"read").disabled:
		assert_true(card.choose(&"read"))
		assert_true(letters.is_opened(uid))
		assert_eq(card.text_label.text, "„%s“" % letters.letter(uid).text, "the text once opened")
		assert_true(card.choice_button(&"read").disabled, "read once")


func test_letter_card_steps_through_the_bag() -> void:
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var a := Phase9Fixtures.letter_in(inv, &"lp_l1_carter", tree)
	_keep(a.letters)
	var card := _open(&"letter", {"inventory": inv, "player": player}) as LetterPanel
	assert_eq(card.uid, str(a.uid), "without a uid the first letter of the bag")
	assert_false(card.prev_button.visible, "one letter: no ‹ ›")


# --- Brenneisen (§7.4) --------------------------------------------------------------------------------------------------

func test_stranger_panel_offers_sell_and_no() -> void:
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var s := Stranger.new()
	s.config = Phase9Fixtures.stranger_config()
	for o: StrangerOfferData in Phase9Fixtures.stranger_offers():
		s.offer_table[o.id] = o
	_world().add_child(s)
	var day := DAY + s.config.arrive_offset
	TimeManager.set_time(day, 870)
	s.apply_morning(day)
	s.apply_minute(day, 870)
	assert_true(s.here(), "he is here")
	var panel := _open(&"stranger", {"inventory": inv, "player": player}) as StrangerPanel
	assert_true(panel.dock_right, "docked")
	assert_false(ui.dim.visible)
	assert_eq(panel.title_label.text, "C. Brenneisen, Commissionär")
	assert_true(panel.cards.has(&"so_register"), "the register extract")
	assert_true(panel.cards.has(&"so_soil"), "grave soil")
	assert_true(panel.sell_button(&"so_register").disabled, "nothing to sell yet")
	assert_true((panel.cards[&"so_register"].reason as Label).visible, "with its reason")
	assert_eq((panel.cards[&"so_register"].price as Label).text, "10 Münzen")
	var note: Label = panel.cards[&"so_register"].note
	assert_false(note.text.is_empty(), "one line of what follows")
	assert_false(note.text.contains("+") or note.text.contains("−"), "never a number for it")
	inv.add_item(&"register_extract", 1)
	await wait_frames(1)
	assert_false(panel.sell_button(&"so_register").disabled)
	var coins := inv.count(&"coin")
	assert_true(panel.sell(&"so_register"))
	assert_eq(inv.count(&"coin"), coins + 10)
	panel.decline(&"so_soil")
	assert_true(panel.sell_button(&"so_soil").disabled, "„Nein“ – the card rests")
	assert_eq((panel.cards[&"so_soil"].reason as Label).text, Phase9Texts.STRANGER_DECLINED)


# --- large requests (§2.3.4) ----------------------------------------------------------------------------------------------

func test_large_card_at_the_gate_parts_and_half() -> void:
	await _setup()
	var hill := _keep(Phase9Fixtures.large_pinned(&"hrl_ferry_graves", [true, true, false] as Array[bool], tree)) as HillRequests
	var panel := _open(&"hill_requests", {"inventory": inv, "player": player, "place": &"gate"}) as HillRequestsPanel
	assert_true(panel.cards.has(&"hrl_ferry_graves"), "the large sheet first")
	var c: Dictionary = panel.cards[&"hrl_ferry_graves"]
	var parts: Array = c.parts
	assert_eq(parts.size(), 3)
	assert_true((parts[0] as Label).text.begins_with("✓"))
	assert_true((parts[2] as Label).text.begins_with("○"))
	assert_true((c.half as Label).visible, "two of three: the stamp „halb“")
	assert_eq((c.half as Label).text, "halb")
	hill.set_part(&"hrl_ferry_graves", 1, false)
	await wait_frames(1)
	c = panel.cards[&"hrl_ferry_graves"]
	assert_false((c.half as Label).visible, "one of three: no stamp")


func test_parish_board_strip_opens_the_large_card() -> void:
	await _setup()
	GameState.set_flag(&"village_open", true)
	_keep(Phase9Fixtures.large_pinned(&"hrv_bridge_stones", [] as Array[bool], tree)).load_state({"large_board": {"village": ["hrv_bridge_stones"]}})
	var orders := _open(&"orders", {"board": true, "orders": [] as Array[StringName], "inventory": inv, "player": player,
			"hill_place": &"village", "large": [&"hrv_bridge_stones"]}) as OrdersPanel
	assert_true(orders.large_buttons.has(&"hrv_bridge_stones"), "„Große Bitte“ above the orders")
	orders.large_buttons[&"hrv_bridge_stones"].pressed.emit()
	await wait_frames(1)
	assert_eq(ui.top(), &"hill_requests")
	var panel := ui.get_panel(&"hill_requests") as HillRequestsPanel
	assert_eq(panel.place, &"village")
	assert_eq(panel.ids(), [] as Array[StringName], "the small requests stay at the gate")
	assert_true(panel.cards.has(&"hrv_bridge_stones"))
	assert_false((panel.cards[&"hrv_bridge_stones"].accept as Button).disabled, "can be accepted")


func test_new_panels_docked_below_the_hud_at_every_size() -> void:
	var size_before := tree.root.size
	await _setup()
	_keep(Phase9Fixtures.p9_open(tree))
	var made := Phase9Fixtures.letter_in(inv, &"lp_l1_carter", tree)
	_keep(made.letters)
	_keep(Phase9Fixtures.large_pinned(&"hrl_ferry_graves", [true, false, false] as Array[bool], tree))
	var contexts := {&"letter": {"uid": made.uid, "inventory": inv, "player": player},
			&"stranger": {"inventory": inv, "player": player}, &"hill_requests": {"inventory": inv, "player": player, "place": &"gate"}}
	for window: Vector2i in WINDOW_SIZES:
		tree.root.size = window
		await wait_frames(2)
		for id: StringName in contexts:
			ui.open_panel(id, contexts[id])
			await wait_frames(3)
			var panel := ui.get_panel(id)
			var view := ui.get_viewport().get_visible_rect()
			var rect := panel.get_global_rect()
			var hud := ui.hud.resource_panel.get_global_rect()
			var at := "%s at %s" % [id, window]
			assert_true(panel.dock_right and panel.get_parent() is MarginContainer, at + " docked")
			assert_false(ui.dim.visible, at + " no dim")
			assert_almost(rect.end.x, view.end.x - UIRoot.DOCK_MARGIN, 1.0, at + " at the right edge")
			assert_false(rect.intersects(hud), at + " below the HUD's resource panel")
			assert_true(rect.end.y <= view.end.y - UIRoot.DOCK_MARGIN + 1.0, "%s on screen (%s in %s)" % [at, rect, view])
			assert_false(rect.has_point(view.get_center()), at + " the middle stays free")
			ui.close_all()
			await wait_frames(1)
	tree.root.size = size_before


# --- HUD (§7.5) -----------------------------------------------------------------------------------------------------------

func test_objective_lines_of_the_chain() -> void:
	var q := Phase9Fixtures.quest_at(&"q_who_knows", &"h1", tree)
	_keep(q)
	GameState.set_flag(&"p9_intro", false)
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Sprich mit Osric")
	GameState.set_flag(&"p9_intro", true)
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Lies Lorenz' Kladde (Hütte)")
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "step": {"q_who_knows": "h2"}, "done": {"q_who_knows": ["h1"]},
			"notes": {"date_grave": ["e_dorn", "e_ott", "e_hagedorn"]}})
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Die Liste: 3/5 Gräber verglichen")
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "step": {"q_who_knows": "h3"}, "done": {"q_who_knows": ["h1", "h2"]}})
	_keep(Phase9Fixtures.witnessed([&"e_dorn", &"e_ott"], tree))
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Wer hat das Licht gesehen? 2/3")
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "step": {"q_who_knows": "h4"}, "done": {"q_who_knows": ["h1", "h2", "h3"]}})
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Wer ist „S.“?")
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "step": {"q_who_knows": "h5"}, "done": {"q_who_knows": ["h1", "h2", "h3", "h4"]}})
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Wem sagst du es?")
	GameState.set_flag(&"sieber_dead", true)
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Johann Sieber – bestatten")
	GameState.set_flag(&"sieber_buried", true)
	q.load_state({"open_day": DAY, "open": ["q_who_knows"], "done": {"q_who_knows": ["h1", "h2", "h3", "h4", "h5", "h6"]},
			"ending": {"q_who_knows": "stay"}, "settled": ["q_who_knows"]})
	assert_eq(Phase9Status.objective({"p9": Phase9Status.objective_state(tree)}), "Wer weiß, wann? 1/3")


func test_objective_decide_deadline_words() -> void:
	assert_eq(Phase9Texts.decide_words(2), "bis morgen Abend")
	assert_eq(Phase9Texts.decide_words(1), "heute")
	assert_eq(Phase9Texts.decide_words(4), "noch 3 Tage")
	assert_eq(Phase9Status.objective({"p9": {"open": true, "intro": true, "main_step": &"h6", "main_days": 2}}),
			"Was wird aus Johann? (bis morgen Abend)")


func test_objective_pinned_first_and_large_lines() -> void:
	var world := {"p9": {"pinned": {"id": &"hrl_ferry_graves", "group": &"large", "title": "Die Gräber der Fähre",
			"line": "Zwei Zierstücke im Alten Hof", "days_left": 2, "progress": Vector2i(1, 3)}}}
	var line := ObjectiveResolver.current([] as Array[CorpseRecord], [] as Array[GraveRecord], null, NOON, {}, world)
	assert_eq(line, "Bitte: Die Gräber der Fähre – Zwei Zierstücke im Alten Hof (1/3)")
	var hill := {"hill": {"active": [], "waiting": 0, "can_accept": true, "large": [{"id": &"hrl_crosses",
			"line": "Bitte: Drei Kreuze für den Hohlweg – Holzkreuze (1/3)"}], "large_waiting": []}}
	assert_eq(ObjectiveResolver.current([] as Array[CorpseRecord], [] as Array[GraveRecord], null, NOON, {}, hill),
			"Bitte: Drei Kreuze für den Hohlweg – Holzkreuze (1/3)")
	var waiting := {"hill": {"active": [], "waiting": 0, "can_accept": true, "large": [], "large_waiting": [&"gate"]}}
	assert_eq(ObjectiveResolver.current([] as Array[CorpseRecord], [] as Array[GraveRecord], null, NOON, {}, waiting),
			"Eine große Bitte am Tor wartet")


# --- day summary and chapter (§7.6, §1.5) ----------------------------------------------------------------------------------

func test_day_summary_phase9_rows() -> void:
	await _setup()
	EventBus.letter_changed.emit("lt_0001", &"lp_l1_carter", &"found")
	EventBus.letter_changed.emit("lt_0001", &"lp_l1_carter", &"burned")
	EventBus.letter_changed.emit("lt_0002", &"lpo_quendel", &"received")
	EventBus.hill_request_part.emit(&"hrl_crosses", 0, true)
	EventBus.hill_request_changed.emit(&"hrl_crosses", &"half")
	EventBus.stranger_event.emit(&"asked", "frank")
	EventBus.stranger_event.emit(&"sold", "so_register")
	var panel := _open(&"day_summary", {"day": DAY}) as DaySummaryPanel
	assert_eq(panel.row_text(panel.letters_label), "gefunden 1 · entschieden 1 · Post 1")
	assert_eq(panel.row_text(panel.requests_label), "Teile 1 · halb 1")
	assert_true(panel.row_text(panel.stranger_label).begins_with("er fragte · er bekam: "), panel.row_text(panel.stranger_label))
	ui.close_all()
	var again := _open(&"day_summary", {"day": DAY + 1}) as DaySummaryPanel
	assert_eq(again.row_text(again.letters_label), "", "the log starts anew")


func test_chapter_panel_who_knows_when() -> void:
	await _setup()
	var ctx := {"variant": &"who_knows_when", "days_open": 10, "main_title": "Bei Grete", "confided": &"confide_washer",
			"closing_line": "Johann hat sich nicht beeilt.", "letters_delivered": 2, "letters_read_grave": 1, "letters_answered": 1,
			"letters_burned": 1, "letters_buried": 0, "errands_done": 2, "large_requests_done": 2, "large_requests_half": 1,
			"large_requests_failed": 0, "large_request_parts": 8, "stranger_talks": 2, "stranger_coins": 13, "stranger_end": &"fenner",
			"list": [{"date": "2. Julmond 1833", "name": "Kaspar Dorn", "initial": "D.", "witnessed": true}], "insights": ["i_light_before"]}
	var panel := _open(&"slice_summary", ctx) as SliceSummaryPanel
	assert_eq(panel.header_label.text, "Wer weiß, wann?")
	assert_true(panel.when_grid.visible)
	assert_false(panel.people_grid.visible)
	assert_eq(panel.when_value("Tage seit der Liste"), "10")
	assert_eq(panel.when_value("Das Ende"), "Bei Grete")
	assert_eq(panel.when_value("Gesagt"), "Liesel Dorn")
	assert_eq(panel.when_value("Die Liste"), "2. Julmond 1833 Kaspar Dorn ✓")
	assert_eq(panel.when_value("Briefe"), "zugestellt 2 · vorgelesen 1 · beantwortet 1 · verbrannt 1 · ins Grab 0")
	assert_eq(panel.when_value("Größere Bitten"), "erfüllt 2 · halb 1 · versäumt 0 · Teile 8")
	assert_eq(panel.when_value("Der Herr mit dem Koffer"), "bekam 13 Münzen · über die Brücke gebracht")
	assert_eq(panel.goal_label.text, "Johann hat sich nicht beeilt.")


# --- debug (§6) ---------------------------------------------------------------------------------------------------------

func test_debug_commands_phase9() -> void:
	var q := _keep(Phase9Fixtures.p9_open(tree)) as Quests
	assert_true(Debug.execute("quest q_who_knows h3").ok)
	assert_eq(q.current_step(&"q_who_knows"), &"h3")
	Phase9Fixtures.light_list(tree)
	var w := _keep(tree.get_first_node_in_group(&"who_knows")) as WhoKnows
	assert_true(str(Debug.execute("kladde").text).contains("S."), "the list")
	assert_true(Debug.execute("witness e_dorn").ok)
	assert_true(&"e_dorn" in w.witnessed())
	assert_true(Debug.execute("match e_ott").ok)
	assert_true(w.matched(&"e_ott"))
	assert_true(Debug.execute("lightday 51").ok)
	assert_eq(w.light_day(), 51)
	assert_true(Debug.execute("sieber marked").ok)
	assert_true(GameState.flag_on(&"q_sieber_marked"))
	assert_true(Debug.execute("goal9").ok)
	assert_false(Debug.execute("quest nope").ok, "unknown chain")


# --- helpers ------------------------------------------------------------------------------------------------------------

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
		world.name = "P9UiWorld"
		tree.root.add_child(world)
	return world


func _keep(node: Node) -> Node:
	_extra.append(node)
	return node


func _journal_double() -> JournalDouble:
	var j := JournalDouble.new()
	_world().add_child(j)
	return j


func _open(id: StringName, ctx: Dictionary) -> UIPanel:
	ui.open_panel(id, ctx)
	return ui.get_panel(id)


func _journal(page: StringName) -> JournalPanel:
	ui.open_panel(&"journal", {"page": page})
	return ui.get_panel(&"journal") as JournalPanel


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		ui.get_viewport().push_input(ev)


func _journal_texts(panel: JournalPanel) -> PackedStringArray:
	var out := PackedStringArray()
	for page: Control in [panel.left_page, panel.right_page]:
		out.append_array(_labels(page))
	return out


func _labels(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node: Node in root.find_children("*", "", true, false):
		if node is Label:
			out.append((node as Label).text)
		elif node is Button:
			out.append((node as Button).text)
	return out


func _contains(texts: PackedStringArray, part: String) -> bool:
	for t: String in texts:
		if t.contains(part):
			return true
	return false


func _has_label(root: Node, text: String, variation: StringName) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text and (node as Label).theme_type_variation == variation:
			return true
	return false


func _has_variation(root: Node, part: String, variation: StringName) -> bool:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text.contains(part) and (node as Label).theme_type_variation == variation:
			return true
	return false
