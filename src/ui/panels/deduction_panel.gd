class_name DeductionPanel
extends UIPanel
## &"deduction" – „Ursache deuten" from the death note in the Merkbuch (docs/PHASE7_DESIGN.md §2.6.5, §7):
## context {corpse_id, journal?}. Left the cards of this dead person (Deductions.cards: finding cards, the
## revealed finds, the known teachings – coloured by kind like the clue cards), right the list of causes
## (DeductionRules.cause_list + the hidden causes). Choose two or three cards and one cause → „Deuten"
## (Deductions.deduce): right – „Gedeutet: Arsenik" and the deduction's text (its clue goes to the
## Merkbuch); wrong – „Das passt nicht zusammen." No counter, no cost, as often as one likes.

const DEDUCTIONS_GROUP := &"deductions"
const MANAGER_GROUP := &"corpse_manager"
const MAX_CARDS := 3
const MIN_CARDS := 2
## Card tint by kind (journal card look, three quiet hues).
const KIND_TINT: Dictionary[StringName, Color] = {&"finding": Color(1.0, 0.94, 0.86), &"find": Color(0.9, 0.95, 1.0),
		&"teaching": Color(0.92, 1.0, 0.9)}

@export var panel_width: float = 1440.0

var deductions: Deductions
var corpse_id: String = ""
var title_label: Label
var for_label: Label
var cards_grid: GridContainer
var no_cards_label: Label
var causes_box: VBoxContainer
var selection_label: Label
var deduce_button: Button
var result_label: Label
var result_text: Label
var done_label: Label
## card id -> button
var card_buttons: Dictionary[String, Button] = {}
## cause id -> button
var cause_buttons: Dictionary[StringName, Button] = {}
var selected: PackedStringArray = []
var cause: StringName = &""
## Last deduce() result ({} = none).
var result: Dictionary = {}


func _build() -> void:
	custom_minimum_size.x = panel_width
	theme_type_variation = &"LedgerPanel"
	var page := UIKit.panel(&"LedgerPagePanel")
	add_child(page)
	var box := UIKit.vbox(12)
	page.add_child(box)
	var head := UIKit.hbox(16)
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label = UIKit.label(Phase7Texts.DEDUCTION_TITLE, &"LedgerTitleLabel")
	titles.add_child(title_label)
	for_label = UIKit.label("", &"InkDimLabel")
	titles.add_child(for_label)
	head.add_child(titles)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"LedgerCloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	box.add_child(LedgerOrnament.new())
	var columns := UIKit.hbox(28)
	box.add_child(columns)
	var left := UIKit.vbox(8)
	left.custom_minimum_size.x = panel_width * 0.6
	columns.add_child(left)
	left.add_child(UIKit.label(Phase7Texts.DEDUCTION_CARDS, &"LedgerHeadLabel"))
	cards_grid = GridContainer.new()
	cards_grid.columns = 2
	cards_grid.add_theme_constant_override(&"h_separation", 12)
	cards_grid.add_theme_constant_override(&"v_separation", 10)
	left.add_child(cards_grid)
	no_cards_label = UIKit.label(Phase7Texts.DEDUCTION_NO_CARDS, &"InkDimLabel", true)
	left.add_child(no_cards_label)
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UIKit.label(Phase7Texts.DEDUCTION_CAUSES, &"LedgerHeadLabel"))
	causes_box = UIKit.vbox(4)
	right.add_child(causes_box)
	box.add_child(LedgerOrnament.new())
	result_label = UIKit.label("", &"InkStampLabel", true)
	box.add_child(result_label)
	result_text = UIKit.label("", &"InkLabel", true)
	result_text.custom_minimum_size.x = panel_width - 120.0
	box.add_child(result_text)
	done_label = UIKit.label("", &"InkDimLabel", true)
	box.add_child(done_label)
	var bottom := UIKit.hbox(16)
	selection_label = UIKit.label("", &"InkDimLabel")
	selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(selection_label)
	var back := UIKit.button(TEXT_CLOSE, &"InkButton")
	back.pressed.connect(request_close)
	bottom.add_child(back)
	deduce_button = UIKit.button(Phase7Texts.DEDUCTION_BUTTON, &"InkButton")
	deduce_button.pressed.connect(deduce)
	bottom.add_child(deduce_button)
	box.add_child(bottom)


func _on_opened() -> void:
	deductions = get_tree().get_first_node_in_group(DEDUCTIONS_GROUP) as Deductions if is_inside_tree() else null
	corpse_id = str(context.get("corpse_id", ""))
	selected = PackedStringArray()
	cause = &""
	result = {}


func _refresh() -> void:
	var record := _record()
	var shown := record.cause_id if record != null else &""
	for_label.text = Phase7Texts.DEDUCTION_FOR % [record.display_name if record != null else corpse_id, Phase7Texts.cause_label(shown)]
	UIKit.clear_children(cards_grid)
	card_buttons.clear()
	var ids := cards()
	for id: String in ids:
		cards_grid.add_child(_card_button(Phase7Texts.card(id)))
	no_cards_label.visible = deductions == null or not deductions.can_deduce(corpse_id)
	UIKit.clear_children(causes_box)
	cause_buttons.clear()
	for c: StringName in causes():
		var b := UIKit.button(Phase7Texts.cause_label(c), &"JournalTabSelected" if c == cause else &"JournalTabButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choose_cause.bind(c))
		causes_box.add_child(b)
		cause_buttons[c] = b
	selection_label.text = Phase7Texts.DEDUCTION_SELECTED % [selected.size(), Phase7Texts.cause_label(cause) if cause != &"" else Phase7Texts.DEDUCTION_NO_CAUSE] \
			if not selected.is_empty() or cause != &"" else Phase7Texts.DEDUCTION_PICK
	deduce_button.disabled = not can_press()
	var ok := bool(result.get("ok", false))
	result_label.text = (Phase7Texts.DEDUCTION_RESULT % Phase7Texts.cause_label(StringName(str(result.get("cause", ""))))) if ok \
			else (DeductionRules.TEXT_NO_MATCH if not result.is_empty() else "")
	result_label.theme_type_variation = &"InkStampLabel" if ok else &"LedgerWarnLabel"
	result_label.visible = result_label.text != ""
	result_text.text = str(result.get("text", "")) if ok else ""
	result_text.visible = result_text.text != ""
	var done := PackedStringArray()
	if record != null and record.revealed_cause != &"":
		done.append(Phase7Texts.cause_label(record.revealed_cause))
	done_label.text = Phase7Texts.DEDUCTION_DONE % ", ".join(done) if not done.is_empty() else ""
	done_label.visible = done_label.text != ""


func cards() -> PackedStringArray:
	return deductions.cards(corpse_id) if deductions != null else PackedStringArray()


## The cause list (corpse tables + the hidden causes).
func causes() -> Array[StringName]:
	return DeductionRules.cause_list(Database.corpse_tables() as CorpseTables)


func can_press() -> bool:
	return deductions != null and deductions.can_deduce(corpse_id) and selected.size() >= MIN_CARDS \
			and selected.size() <= MAX_CARDS and cause != &""


## Click on a card: in / out of the selection (at most three).
func toggle_card(id: String) -> void:
	if selected.has(id):
		selected.remove_at(selected.find(id))
	elif selected.size() < MAX_CARDS:
		selected.append(id)
	result = {}
	refresh()


func choose_cause(c: StringName) -> void:
	cause = c
	result = {}
	refresh()


## Deductions.deduce with the chosen cards and cause; a right one keeps the result card, a wrong one only
## the line. Returns the result dictionary.
func deduce() -> Dictionary:
	if not can_press():
		return {}
	result = deductions.deduce(corpse_id, selected, cause)
	if bool(result.get("ok", false)):
		selected = PackedStringArray()
	refresh()
	return result


func _card_button(c: Dictionary) -> Button:
	var id := str(c.id)
	var chosen := selected.has(id)
	var b := Button.new()
	b.theme_type_variation = &"JournalCardSelected" if chosen else &"JournalCardButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(panel_width * 0.29, 92.0)
	b.self_modulate = KIND_TINT.get(StringName(str(c.kind)), Color.WHITE)
	b.set_meta(&"card_id", id)
	b.tooltip_text = str(c.text)
	b.pressed.connect(toggle_card.bind(id))
	var box := UIKit.vbox(0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0
	box.offset_right = -10.0
	box.offset_top = 6.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind := UIKit.label(str(c.kind_word), &"InkStampLabel")
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(kind)
	var text := UIKit.label(str(c.text) if str(c.text) != "" else str(c.title), &"InkLabel", true)
	text.custom_minimum_size.x = b.custom_minimum_size.x - 30.0
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.max_lines_visible = 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(text)
	b.add_child(box)
	card_buttons[id] = b
	return b


func _record() -> CorpseRecord:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null
