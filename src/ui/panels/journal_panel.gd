class_name JournalPanel
extends UIPanel
## &"journal" – the Merkbuch (docs/PHASE4_DESIGN.md §2.12, §3.6, §7): context {page: StringName,
## journal: JournalManager} (JournalManager.panel_context()); without "journal" the node in group
## &"journal" is used. A leather-bound double page like the grave register, four tabs:
##   people   – Die Toten: list (newest first) and the death note of the chosen one
##   clues    – Hinweise: card grid, a click chooses (at most 3, red thread between them),
##              „Verknüpfen“ → JournalManager.try_link; right: the chosen clue + open questions
##   insights – Erkenntnisse: the diary pages in order (a new one is revealed after linking)
##   self     – Ich: the piety sentence (never a number) and prepared / utilized
## Tabs by click or [ / ] (journal_page_prev / _next), J / Esc close (UIRoot). Unread entries
## carry a dot; they are marked read when their page is left or the book is closed.
## The only game call is try_link (and mark_read) – everything else is read-only.
## Phase 7 (docs/PHASE7_DESIGN.md §7): from village_open two more tabs – „Aufträge" (running, completed,
## missed) and „Hollerbrück" (eight people, JournalPagesPhase7); the death note lists the dead's specimens
## with where they are, the finding and the deduced cause, and offers „Ursache deuten" (&"deduction").
## Phase 8 (docs/PHASE8_DESIGN.md §7.4): from p8_open the tab „Angehörige" (JournalPagesPhase8), the villager cards
## of „Hollerbrück" add mood, the three story points and the favour, a second sheet shows Jakob, Veit and Hanne;
## „Aufträge" keeps the friendship orders and „Was du schuldest" apart; up to four clues may be chosen (the
## any-group insight „Der unterstrichene Name") and its question card shows both groups with their counters.

const PAGES: Array[StringName] = [&"people", &"clues", &"insights", &"self"]
## Phase 7: shown from village_open.
const PHASE7_PAGES: Array[StringName] = [&"orders", &"village"]
## Phase 8: shown from p8_open.
const PHASE8_PAGES: Array[StringName] = [&"kin"]
const P8_FLAG := &"p8_open"
## Phase 8: four clues for „Der unterstrichene Name" (two required + two of four).
const MAX_SELECTED_P8 := 4
const TEXT_SELECT_HINT_P8 := "Wähle zwei bis vier Hinweise, die zusammengehören."
const VILLAGE_FLAG := &"village_open"
const PAGE_LABELS: Dictionary[StringName, String] = {
	&"people": "Die Toten", &"clues": "Hinweise", &"insights": "Erkenntnisse", &"self": "Ich",
	&"orders": "Aufträge", &"village": "Hollerbrück", &"kin": "Angehörige",
}
const JOURNAL_GROUP := &"journal"
const MAX_SELECTED := 3
const MIN_LINK := 2
const TEXT_TITLE := "Merkbuch"
const TEXT_UNREAD_DOT := "●"
const TEXT_HINT := "[ / ] blättern · Klick wählt Hinweise · [J] oder [Esc] schließen"
const TEXT_NO_PEOPLE := "Noch hat dir niemand etwas mitgebracht."
const TEXT_NO_CLUES := "Noch keine Hinweise. Sieh dir die Toten genau an."
const TEXT_NO_INSIGHTS := "Noch keine Erkenntnis. Manche Hinweise erzählen zusammen mehr."
const TEXT_PERSON := "%s · Tag %d"
const TEXT_NOTE_HEAD := "%d Jahre · %s · Tag %d"
const TEXT_NOTE_GRAVE := " · Grab %s"
const TEXT_FINDS := "Funde"
const TEXT_LOST := "Verloren"
const TEXT_NO_FINDS := "Nichts vermerkt."
const TEXT_PREP := "Herrichtung"
const TEXT_PREP_NONE := "nicht hergerichtet"
const TEXT_WASHED := "gewaschen"
const TEXT_LAID_OUT := "aufgebahrt"
const TEXT_HARVESTED := "Genommen: %s"
const HARVEST_LABELS: Dictionary[StringName, String] = {&"hair": "der Zopf", &"teeth": "die Zähne", &"heart": "das Herz",
		&"lung": "die Lunge", &"stomach": "der Magen", &"liver": "die Leber", &"kidneys": "die Nieren", &"eyes": "die Augen",
		&"hand": "die Hand"}
const TEXT_HEARD := "Gehört: „%s“"
const TEXT_HEARD_ANY := "Gehört: Ihr Geist hat zu dir gesprochen."
const TEXT_SELECTED := "%d von höchstens %d gewählt"
const TEXT_SELECT_HINT := "Wähle zwei oder drei Hinweise, die zusammengehören."
const TEXT_LINK := "Verknüpfen"
const TEXT_LINKED := "Erkenntnis: %s"
const TEXT_QUESTIONS := "Offene Fragen"
const TEXT_NO_QUESTIONS := "Keine offene Frage."
const TEXT_QUESTION_COUNT := "%d von %d Hinweisen"
const TEXT_CLUE_COUNT := "bei %d Toten"
const TEXT_CLUE_DAY := "Tag %d"
const TEXT_INSIGHT_DAY := "Erkannt an Tag %d"
const TEXT_SELF_COUNTS := "Hergerichtet: %d · Verwertet: %d"
const TEXT_SELF_INSIGHTS := "Erkenntnisse: %d von %d"
const TEXT_SELF_HEAD := "Was du über dich weißt"
const TEXT_SELF_QUOTE := "Was man nicht ansieht, nimmt sie mit ins Grab."
const KIND_LABELS: Dictionary[StringName, String] = {
	&"mark": "Zeichen", &"letter": "Brief", &"page": "Seite", &"object": "Gegenstand",
	&"place": "Ort", &"note": "Zettel", &"talk": "Gespräch",
}

@export var page_width: float = 700.0
@export var page_height: float = 700.0
## Seconds the newly linked insight fades in.
@export var reveal_time: float = 0.8

var journal: Node
var current_page: StringName = &"people"
## Chosen clue ids in click order (≤ MAX_SELECTED).
var selected: Array[StringName] = []
## Clue shown on the right page of Hinweise (last clicked).
var focused_clue: StringName = &""
var chosen_person: String = ""
var chosen_insight: StringName = &""
## Text after the last link attempt ("" = none): the fail text or „Erkenntnis: …“.
var link_feedback: String = ""

var tab_buttons: Dictionary[StringName, Button] = {}
var tab_dots: Dictionary[StringName, Label] = {}
var left_page: VBoxContainer
var right_page: VBoxContainer
var link_button: Button
var feedback_label: Label
var selection_label: Label
var thread: RedThread
## clue id -> its card button (Hinweise page)
var clue_buttons: Dictionary[StringName, Button] = {}
var insight_text_label: Label
## Phase 7: „Ursache deuten" on the death note (null = not offered).
var deduce_button: Button
## Phase 8: the sheet of „Hollerbrück" (0 = the villagers, 1 = the new faces) and its switch.
var village_sheet: int = 0
var sheet_button: Button
var fest_button: Button


func _build() -> void:
	theme_type_variation = &"LedgerPanel"
	var box := UIKit.vbox(10)
	add_child(box)
	var head := UIKit.hbox(8)
	var title := UIKit.label(TEXT_TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	for page: StringName in PAGES + PHASE7_PAGES + PHASE8_PAGES:
		var tab := UIKit.hbox(2)
		var b := UIKit.button(PAGE_LABELS[page], &"JournalTabButton")
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_page.bind(page))
		tab.add_child(b)
		var dot := UIKit.label(TEXT_UNREAD_DOT, &"AccentLabel")
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tab.add_child(dot)
		head.add_child(tab)
		tab_buttons[page] = b
		tab_dots[page] = dot
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var spread := UIKit.hbox(6)
	box.add_child(spread)
	left_page = _page(spread)
	right_page = _page(spread)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _page(parent: Container) -> VBoxContainer:
	var sheet := UIKit.panel(&"LedgerPagePanel")
	sheet.custom_minimum_size = Vector2(page_width, page_height)
	parent.add_child(sheet)
	var inner := UIKit.vbox(10)
	sheet.add_child(inner)
	return inner


func _on_opened() -> void:
	var j: Variant = context.get("journal")
	journal = j if is_instance_valid(j) else (get_tree().get_first_node_in_group(JOURNAL_GROUP) if is_inside_tree() else null)
	var page := StringName(str(context.get("page", "people")))
	current_page = page if page in pages() else &"people"
	selected.clear()
	link_feedback = ""
	focused_clue = &""
	village_sheet = 0


func _on_closed() -> void:
	_mark_page_read()


func _refresh() -> void:
	_refresh_tabs()
	UIKit.clear_children(left_page)
	UIKit.clear_children(right_page)
	clue_buttons.clear()
	thread = null
	link_button = null
	insight_text_label = null
	deduce_button = null
	sheet_button = null
	fest_button = null
	match current_page:
		&"people":
			_build_people()
		&"clues":
			_build_clues()
		&"insights":
			_build_insights()
		&"self":
			_build_self()
		&"orders":
			_page_title(left_page, PAGE_LABELS[&"orders"])
			JournalPagesPhase7.build_orders(left_page, right_page, get_tree() if is_inside_tree() else null, _inventory(), page_width)
		&"village":
			_page_title(left_page, PAGE_LABELS[&"village"])
			var tree_v := get_tree() if is_inside_tree() else null
			if village_sheet == 1:
				JournalPagesPhase8.build_new_faces(left_page, right_page, tree_v, page_width)
				right_page.add_child(UIKit.spacer(false))
			else:
				JournalPagesPhase7.build_village(left_page, right_page, tree_v, page_width)
			if GameState.flag_on(P8_FLAG):
				fest_button = JournalPagesPhase8.fest_button(right_page, tree_v)
				sheet_button = UIKit.button(Phase8Texts.PAGE_VILLAGE_BACK if village_sheet == 1 else Phase8Texts.PAGE_VILLAGE_MORE, &"InkButton")
				sheet_button.size_flags_horizontal = Control.SIZE_SHRINK_END
				sheet_button.pressed.connect(toggle_village_sheet)
				right_page.add_child(sheet_button)
		&"kin":
			_page_title(left_page, PAGE_LABELS[&"kin"])
			JournalPagesPhase8.build_kin(left_page, right_page, get_tree() if is_inside_tree() else null, page_width)


## The tabs shown now: the four Phase-4 pages, from village_open also „Aufträge" and „Hollerbrück".
func pages() -> Array[StringName]:
	var out: Array[StringName] = PAGES.duplicate()
	if GameState.flag_on(VILLAGE_FLAG):
		out.append_array(PHASE7_PAGES)
	if GameState.flag_on(P8_FLAG):
		out.append_array(PHASE8_PAGES)
	return out


## Phase 8: „Hollerbrück" between the villagers and the new faces.
func toggle_village_sheet() -> void:
	village_sheet = 1 - village_sheet
	refresh()


## How many clues may be chosen: four from p8_open (Der unterstrichene Name), else three.
func max_selected() -> int:
	return MAX_SELECTED_P8 if GameState.flag_on(P8_FLAG) else MAX_SELECTED


func _inventory() -> Inventory:
	var p := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return p.get(&"inventory") as Inventory if p != null else null


## Switches the tab (marks the left page read).
func show_page(page: StringName) -> void:
	if not page in pages() or page == current_page:
		return
	_mark_page_read()
	current_page = page
	link_feedback = ""
	refresh()


## ±1 page, wrapping ([ / ]).
func turn_page(step: int) -> void:
	var shown := pages()
	show_page(shown[posmod(shown.find(current_page) + step, shown.size())])


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	if event.is_action_pressed(&"journal_page_prev"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal_page_next"):
		turn_page(1)
		get_viewport().set_input_as_handled()


# --- clue selection -------------------------------------------------------------------------

## Click on a clue card: toggles it in the selection (at most MAX_SELECTED; a 4th click
## replaces nothing and only focuses the card).
func toggle_clue(id: StringName) -> void:
	focused_clue = id
	link_feedback = ""
	if id in selected:
		selected.erase(id)
	elif selected.size() < max_selected():
		selected.append(id)
	refresh()


## „Verknüpfen“: JournalManager.try_link(selected). A match reveals the insight page; a miss
## shows LINK_FAIL_TEXT and keeps the selection (costs nothing, §2.12).
func link_selected() -> StringName:
	if journal == null or selected.size() < MIN_LINK or not journal.has_method(&"try_link"):
		return &""
	var ids: Array[StringName] = selected.duplicate()
	var result := journal.call(&"try_link", ids) as StringName
	if result == &"":
		link_feedback = _fail_text()
		refresh()
		return &""
	selected.clear()
	chosen_insight = result
	var data: Variant = journal.call(&"insight_by_id", result) if journal.has_method(&"insight_by_id") else null
	link_feedback = TEXT_LINKED % (data as InsightData).title if data is InsightData else ""
	_mark_page_read()
	current_page = &"insights"
	refresh()
	_reveal()
	return result


func _fail_text() -> String:
	var text: Variant = journal.get(&"LINK_FAIL_TEXT") if journal != null else null
	return str(text) if text != null and str(text) != "" else JournalManager.LINK_FAIL_TEXT


func _reveal() -> void:
	if insight_text_label == null or reveal_time <= 0.0 or not is_inside_tree():
		return
	insight_text_label.modulate.a = 0.0
	var tween := insight_text_label.create_tween()
	tween.tween_property(insight_text_label, ^"modulate:a", 1.0, reveal_time)


# --- pages ------------------------------------------------------------------------------------

func _build_people() -> void:
	var people := _list(&"people")
	_page_title(left_page, PAGE_LABELS[&"people"])
	if people.is_empty():
		left_page.add_child(UIKit.label(TEXT_NO_PEOPLE, &"InkDimLabel", true))
		return
	if chosen_person == "" or not people.any(func(p: Dictionary) -> bool: return str(p.get("corpse_id", "")) == chosen_person):
		chosen_person = str(people[0].get("corpse_id", ""))
	var scroll := _scroll(left_page)
	var list := UIKit.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var chosen: Dictionary = people[0]
	for p: Dictionary in people:
		var id := str(p.get("corpse_id", ""))
		var b := UIKit.button(TEXT_PERSON % [str(p.get("name", "")), int(p.get("day", 0))],
				&"JournalTabSelected" if id == chosen_person else &"JournalTabButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta(&"corpse_id", id)
		b.pressed.connect(func() -> void:
			chosen_person = id
			refresh())
		list.add_child(b)
		if id == chosen_person:
			chosen = p
	_death_note(right_page, chosen)


func _death_note(parent: VBoxContainer, p: Dictionary) -> void:
	var name := UIKit.label(str(p.get("name", "")), &"LedgerTitleLabel", true)
	parent.add_child(name)
	var head := TEXT_NOTE_HEAD % [int(p.get("age", 0)), str(p.get("cause_label", "")), int(p.get("day", 0))]
	if str(p.get("grave_id", "")) != "":
		head += TEXT_NOTE_GRAVE % GraveRegisterPanel.grave_label(str(p.get("grave_id", "")))
	parent.add_child(UIKit.label(head, &"InkDimLabel", true))
	parent.add_child(LedgerOrnament.new())
	var scroll := _scroll(parent)
	var body := UIKit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(UIKit.label(TEXT_FINDS, &"LedgerHeadLabel"))
	var finds: Array = p.get("finds", [])
	if finds.is_empty():
		body.add_child(UIKit.label(TEXT_NO_FINDS, &"InkDimLabel"))
	for f: Variant in finds:
		body.add_child(_note_entry(f as Dictionary, false))
	var lost: Array = p.get("lost", [])
	if not lost.is_empty():
		body.add_child(UIKit.label(TEXT_LOST, &"LedgerHeadLabel"))
		for f: Variant in lost:
			body.add_child(_note_entry(f as Dictionary, true))
	body.add_child(UIKit.label(TEXT_PREP, &"LedgerHeadLabel"))
	body.add_child(UIKit.label(prep_line(p), &"InkLabel", true))
	var harvested: Array = p.get("harvested", [])
	if not harvested.is_empty():
		var names := PackedStringArray()
		for k: Variant in harvested:
			names.append(HARVEST_LABELS.get(StringName(str(k)), str(k)))
		body.add_child(UIKit.label(TEXT_HARVESTED % ", ".join(names), &"LedgerWarnLabel", true))
	var heard := str(p.get("heard", ""))
	if heard != "":
		body.add_child(UIKit.label(TEXT_HEARD % heard, &"InkDimLabel", true))
	elif bool(p.get("heard_any", false)):
		body.add_child(UIKit.label(TEXT_HEARD_ANY, &"InkDimLabel", true))
	deduce_button = JournalPagesPhase7.build_note(body, get_tree() if is_inside_tree() else null, str(p.get("corpse_id", "")), page_width)


func _note_entry(f: Dictionary, lost: bool) -> Control:
	var row := UIKit.hbox(8)
	if lost:
		var leaf := CorpseExamSections.WiltedLeaf.new()
		leaf.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(leaf)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(str(f.get("label", "")), &"InkDimLabel" if lost else &"InkHeaderLabel"))
	var text := UIKit.label(str(f.get("text", "")), &"InkDimLabel" if lost else &"InkLabel", true)
	text.custom_minimum_size.x = page_width - 140.0
	col.add_child(text)
	row.add_child(col)
	return row


## "gewaschen · Totenhemd · aufgebahrt" / "nicht hergerichtet".
static func prep_line(p: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(p.get("washed", false)):
		parts.append(TEXT_WASHED)
	var dress := StringName(str(p.get("dress", "")))
	if dress != &"":
		parts.append(Phase4Texts.DRESS_LABELS.get(dress, String(dress)))
	if bool(p.get("laid_out", false)):
		parts.append(TEXT_LAID_OUT)
	return " · ".join(parts) if not parts.is_empty() else TEXT_PREP_NONE


func _build_clues() -> void:
	var cards := _list(&"clue_cards")
	_page_title(left_page, PAGE_LABELS[&"clues"])
	if cards.is_empty():
		left_page.add_child(UIKit.label(TEXT_NO_CLUES, &"InkDimLabel", true))
		_build_questions(right_page)
		return
	var scroll := _scroll(left_page)
	var board := MarginContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(board)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 12)
	board.add_child(grid)
	for c: Dictionary in cards:
		var id := StringName(str(c.get("id", "")))
		grid.add_child(_clue_card(c, id))
	thread = RedThread.new()
	thread.grid = grid
	board.add_child(thread)
	_update_thread()
	var bottom := UIKit.hbox(12)
	var hint := TEXT_SELECT_HINT_P8 if max_selected() > MAX_SELECTED else TEXT_SELECT_HINT
	selection_label = UIKit.label(TEXT_SELECTED % [selected.size(), max_selected()] if not selected.is_empty() else hint, &"InkDimLabel", true)
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(selection_label)
	link_button = UIKit.button(TEXT_LINK, &"InkButton")
	link_button.disabled = selected.size() < MIN_LINK
	link_button.pressed.connect(link_selected)
	bottom.add_child(link_button)
	left_page.add_child(bottom)
	feedback_label = UIKit.label(link_feedback, &"LedgerWarnLabel", true)
	feedback_label.visible = link_feedback != ""
	left_page.add_child(feedback_label)
	var focus_id: StringName = focused_clue if focused_clue != &"" else (selected.back() if not selected.is_empty() else &"")
	var shown := _find_card(cards, focus_id)
	if not shown.is_empty():
		right_page.add_child(UIKit.label(str(shown.get("title", "")), &"InkHeaderLabel", true))
		right_page.add_child(UIKit.label(_clue_meta(shown), &"InkDimLabel"))
		var text := UIKit.label(str(shown.get("text", "")), &"InkLabel", true)
		text.custom_minimum_size.x = page_width - 90.0
		right_page.add_child(text)
		right_page.add_child(LedgerOrnament.new())
	_build_questions(right_page)


func _clue_card(c: Dictionary, id: StringName) -> Button:
	var chosen := id in selected
	var b := Button.new()
	b.theme_type_variation = &"JournalCardSelected" if chosen else &"JournalCardButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2((page_width - 110.0) * 0.5, 74.0)
	b.set_meta(&"clue_id", id)
	b.pressed.connect(toggle_clue.bind(id))
	var box := UIKit.vbox(0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_right = -10.0
	box.offset_top = 6.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UIKit.hbox(6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UIKit.label(str(c.get("title", "")), &"InkLabel")
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	if bool(c.get("unread", false)):
		var dot := UIKit.label(TEXT_UNREAD_DOT, &"InkStampLabel")
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(dot)
	box.add_child(head)
	var kind := UIKit.label(_clue_meta(c), &"InkDimLabel")
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(kind)
	b.add_child(box)
	b.tooltip_text = str(c.get("text", ""))
	clue_buttons[id] = b
	return b


func _clue_meta(c: Dictionary) -> String:
	var parts := PackedStringArray([KIND_LABELS.get(StringName(str(c.get("kind", ""))), "Hinweis")])
	if int(c.get("count", 0)) > 1:
		parts.append(TEXT_CLUE_COUNT % int(c.get("count", 0)))
	if int(c.get("day", 0)) > 0:
		parts.append(TEXT_CLUE_DAY % int(c.get("day", 0)))
	return " · ".join(parts)


func _build_questions(parent: VBoxContainer) -> void:
	parent.add_child(UIKit.label(TEXT_QUESTIONS, &"LedgerHeadLabel"))
	var questions := _list(&"open_question_cards")
	if questions.is_empty():
		parent.add_child(UIKit.label(TEXT_NO_QUESTIONS, &"InkDimLabel"))
		return
	for q: Dictionary in questions:
		var row := UIKit.panel(&"LedgerRowPanel")
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label("„%s“" % str(q.get("question", "")), &"InkLabel", true))
		col.add_child(UIKit.label(TEXT_QUESTION_COUNT % [int(q.get("found", 0)), int(q.get("needed", 0))], &"InkDimLabel"))
		for group: String in Phase8Texts.question_groups(q):
			col.add_child(UIKit.label(group, &"InkStampLabel"))
		row.add_child(col)
		parent.add_child(row)


func _update_thread() -> void:
	if thread == null:
		return
	var nodes: Array[Control] = []
	for id: StringName in selected:
		if clue_buttons.has(id):
			nodes.append(clue_buttons[id])
	thread.cards = nodes
	thread.queue_redraw()


func _build_insights() -> void:
	var pages := _list(&"insight_pages")
	_page_title(left_page, PAGE_LABELS[&"insights"])
	if pages.is_empty():
		left_page.add_child(UIKit.label(TEXT_NO_INSIGHTS, &"InkDimLabel", true))
		return
	if chosen_insight == &"" or not pages.any(func(p: Dictionary) -> bool: return StringName(str(p.get("id", ""))) == chosen_insight):
		chosen_insight = StringName(str(pages.back().get("id", "")))
	var shown: Dictionary = pages.back()
	for p: Dictionary in pages:
		var id := StringName(str(p.get("id", "")))
		var label := str(p.get("title", ""))
		if bool(p.get("unread", false)):
			label += "  " + TEXT_UNREAD_DOT
		var b := UIKit.button(label, &"JournalTabSelected" if id == chosen_insight else &"JournalTabButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			chosen_insight = id
			refresh())
		left_page.add_child(b)
		if id == chosen_insight:
			shown = p
	if link_feedback != "":
		var fb := UIKit.label(link_feedback, &"InkStampLabel", true)
		left_page.add_child(fb)
	right_page.add_child(UIKit.label(str(shown.get("title", "")), &"LedgerTitleLabel", true))
	right_page.add_child(UIKit.label("„%s“" % str(shown.get("question", "")), &"InkDimLabel", true))
	right_page.add_child(LedgerOrnament.new())
	insight_text_label = UIKit.label(str(shown.get("text", "")), &"InkLabel", true)
	insight_text_label.custom_minimum_size.x = page_width - 90.0
	right_page.add_child(insight_text_label)
	right_page.add_child(UIKit.spacer(false))
	var day := UIKit.label(TEXT_INSIGHT_DAY % int(shown.get("day", 0)), &"InkDimLabel")
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_page.add_child(day)


func _build_self() -> void:
	var page: Dictionary = journal.call(&"self_page") if journal != null and journal.has_method(&"self_page") else {}
	_page_title(left_page, TEXT_SELF_HEAD)
	left_page.add_child(UIKit.spacer(false))
	var sentence := UIKit.label(str(page.get("sentence", "")), &"LedgerTitleLabel", true)
	sentence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence.custom_minimum_size.x = page_width - 90.0
	left_page.add_child(sentence)
	left_page.add_child(LedgerOrnament.new())
	left_page.add_child(UIKit.spacer(false))
	_page_title(right_page, PAGE_LABELS[&"self"])
	right_page.add_child(UIKit.label(TEXT_SELF_COUNTS % [int(page.get("prepared", 0)), int(page.get("utilized", 0))], &"InkLabel"))
	right_page.add_child(UIKit.label(TEXT_SELF_INSIGHTS % [int(page.get("insights", 0)), int(page.get("insights_total", 0))], &"InkLabel"))
	right_page.add_child(UIKit.spacer(false))
	var quote := UIKit.label(TEXT_SELF_QUOTE, &"InkDimLabel", true)
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_page.add_child(quote)


# --- helpers ----------------------------------------------------------------------------------

func _refresh_tabs() -> void:
	var shown := pages()
	for page: StringName in PAGES + PHASE7_PAGES + PHASE8_PAGES:
		tab_buttons[page].get_parent().visible = page in shown
		tab_buttons[page].theme_type_variation = &"JournalTabSelected" if page == current_page else &"JournalTabButton"
		tab_dots[page].modulate.a = 1.0 if page_has_unread(page) else 0.0


## Clues page: unread clues; insights page: unread insights (self / people never).
func page_has_unread(page: StringName) -> bool:
	if journal == null:
		return false
	match page:
		&"clues":
			return _list(&"clue_cards").any(func(c: Dictionary) -> bool: return bool(c.get("unread", false)))
		&"insights":
			return _list(&"insight_pages").any(func(c: Dictionary) -> bool: return bool(c.get("unread", false)))
	return false


func _mark_page_read() -> void:
	if journal == null or not journal.has_method(&"mark_read"):
		return
	var ids: Array[StringName] = []
	var source := &"clue_cards" if current_page == &"clues" else (&"insight_pages" if current_page == &"insights" else &"")
	if source == &"":
		return
	for c: Dictionary in _list(source):
		if bool(c.get("unread", false)):
			ids.append(StringName(str(c.get("id", ""))))
	if not ids.is_empty():
		journal.call(&"mark_read", ids)


func _list(method: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if journal == null or not journal.has_method(method):
		return out
	var raw: Variant = journal.call(method)
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				out.append(item)
	return out


func _find_card(cards: Array[Dictionary], id: StringName) -> Dictionary:
	for c: Dictionary in cards:
		if StringName(str(c.get("id", ""))) == id:
			return c
	return {}


func _page_title(parent: VBoxContainer, text: String) -> void:
	var l := UIKit.label(text, &"InkHeaderLabel")
	parent.add_child(l)


func _scroll(parent: VBoxContainer) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.get_v_scroll_bar().theme_type_variation = &"LedgerScrollBar"
	parent.add_child(s)
	return s


## The red thread between the chosen clue cards (click order), with a pin on each card.
class RedThread extends Control:
	var grid: Control
	var cards: Array[Control] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		if not cards.is_empty():
			queue_redraw()

	func points() -> PackedVector2Array:
		var out := PackedVector2Array()
		for c: Control in cards:
			if is_instance_valid(c):
				out.append(c.position + Vector2(c.size.x - 22.0, 4.0) + ((grid.position - position) if grid != null else Vector2.ZERO))
		return out

	func _draw() -> void:
		var thread_color := get_theme_color(&"thread", &"JournalThread")
		var pin := get_theme_color(&"pin", &"JournalThread")
		var pts := points()
		for i: int in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var sag := Vector2(0.0, clampf(a.distance_to(b) * 0.12, 6.0, 26.0))
			var curve := PackedVector2Array()
			for s: int in 17:
				var t := float(s) / 16.0
				var mid := a.lerp(b, 0.5) + sag
				curve.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
			draw_polyline(curve, thread_color, 2.5, true)
		for p: Vector2 in pts:
			draw_circle(p, 5.0, pin, true, -1.0, true)
			draw_circle(p + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.35), true, -1.0, true)
