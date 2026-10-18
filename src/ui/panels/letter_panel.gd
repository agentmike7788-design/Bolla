class_name LetterPanel
extends UIPanel
## &"letter" – the letter card (docs/PHASE9_DESIGN.md §7.3, W-UI): context {uid?, inventory, player, place?, grave_id?,
## npc?, carrier?} (the Merkbuch's „Entscheiden …", the debug console; a prompt may pass its place / grave). Docked at the
## right edge below the HUD's resource panel like the work panels of rounds 4/5 (dock_right, no dim, hidden while a work
## started from it runs, back with the focus on the choice used last). One parchment card: the outside in the colour of
## the hand, the sender and – once opened, or for an unsealed one – the text; below the choices of Letters.choices as
## buttons with their place („Zustellen – Rosine im Holderkrug", „Am Grab vorlesen – Lindenacker, l_14", „Verbrennen –
## Ofen in der Hütte"); a choice not possible here is dimmed and names its reason under it („Versiegelt. Er ist nicht an
## dich." – a hint, not a lock). Never a number. Several letters in the bag: ‹ / › (Q / E) step through them.
## The only choice made here is reading it (a TimedAction with the clip read_letter, then Letters.decide read) and every
## choice Letters allows with this context (Letters.decide) – the places' own prompts (desk, stove, grave) do the rest.

const LETTERS_GROUP := &"letters"
const READ_CHOICE := &"read"
## The clip of reading a letter standing (ToolAnimConfig action_clips letter_read → read_letter, ph_tool_letter_open).
const ACTION_READ := &"letter_read"
const ANIM_READ := &"read_letter"
const LABEL_READ := "Brief lesen"
## Fallback minutes of reading (LettersConfig.read_minutes once it exists).
const READ_MINUTES := 5
const ACTION_PREV := &"drop"
const ACTION_NEXT := &"interact"

@export var panel_width: float = 600.0
@export var max_body_height: float = 720.0

var letters: Letters
var title_label: Label
var count_label: Label
var outside_label: Label
var sender_label: Label
var text_label: Label
var state_label: Label
var hint_label: Label
var prev_button: Button
var next_button: Button
## choice id → {button, reason}
var choice_rows: Dictionary[StringName, Dictionary] = {}
## The letters shown (uids) and the one shown now.
var uids: PackedStringArray = []
var uid: String = ""
var _scroll: ScrollContainer
var _body: VBoxContainer
var _choices: VBoxContainer
var _focus_choice: StringName = &""
var _inventory: Inventory


func _init() -> void:
	super._init()
	dock_right = true
	hide_while_working = true


func _ready() -> void:
	super._ready()
	EventBus.letter_changed.connect(_on_letter_changed.unbind(3))
	get_viewport().size_changed.connect(_fit_scroll)


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	title_label = _make_header(box, Phase9Texts.LETTER_TITLE)
	var nav := UIKit.hbox(8)
	prev_button = UIKit.button(Phase9Texts.LETTER_PREV)
	prev_button.focus_mode = Control.FOCUS_NONE
	prev_button.pressed.connect(step_letter.bind(-1))
	nav.add_child(prev_button)
	count_label = UIKit.label("", &"DimLabel")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(count_label)
	next_button = UIKit.button(Phase9Texts.LETTER_NEXT)
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(step_letter.bind(1))
	nav.add_child(next_button)
	box.add_child(nav)
	var dock := make_dock_scroll(box, 10)
	_scroll = dock[0] as ScrollContainer
	_body = dock[1] as VBoxContainer
	var sheet := UIKit.panel(&"LedgerPagePanel")
	var inner := UIKit.vbox(8)
	sheet.add_child(inner)
	_body.add_child(sheet)
	var width := panel_width - 110.0
	inner.add_child(UIKit.label(Phase9Texts.LETTER_OUTSIDE, &"InkDimLabel"))
	outside_label = _wrap(inner, &"InkFreshLabel", width)
	sender_label = _wrap(inner, &"InkDimLabel", width)
	inner.add_child(LedgerOrnament.new())
	text_label = _wrap(inner, &"InkLabel", width)
	state_label = _wrap(inner, &"InkPencilLabel", width)
	_body.add_child(UIKit.label(Phase9Texts.LETTER_CHOICES, &"SubheaderLabel"))
	_choices = UIKit.vbox(6)
	_body.add_child(_choices)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(12)
	bottom.add_child(UIKit.spacer())
	var close := UIKit.button(TEXT_CLOSE)
	close.pressed.connect(request_close)
	bottom.add_child(close)
	box.add_child(bottom)
	hint_label = UIKit.label(Phase9Texts.LETTER_HINT, &"DimLabel")
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)


func _on_opened() -> void:
	letters = get_tree().get_first_node_in_group(LETTERS_GROUP) as Letters if is_inside_tree() else null
	_inventory = _player_inventory()
	_focus_choice = &""
	uids = Phase9Status.open_letters(get_tree() if is_inside_tree() else null, _inventory)
	uid = str(context.get("uid", ""))
	if uid != "" and not uid in uids:
		uids.insert(0, uid)
	if uid == "" and not uids.is_empty():
		uid = uids[0]
	_scroll.scroll_vertical = 0


func _on_closed() -> void:
	_inventory = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id or uids.size() < 2:
		return
	if event.is_action_pressed(ACTION_PREV) or event.is_action_pressed(&"journal_page_prev"):
		step_letter(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_NEXT) or event.is_action_pressed(&"journal_page_next"):
		step_letter(1)
		get_viewport().set_input_as_handled()


## ±1 letter of the bag (wrapping).
func step_letter(step: int) -> void:
	if uids.is_empty():
		return
	uid = uids[posmod(uids.find(uid) + step, uids.size())]
	_focus_choice = &""
	refresh()


## The context Letters reads for the choices: the panel's place / grave / speaker / carrier and the inventory.
func choice_context() -> Dictionary:
	var ctx := {}
	for key: String in ["place", "grave_id", "npc", "carrier", "speaker", "burying"]:
		if context.has(key):
			ctx[key] = context[key]
	if _inventory != null:
		ctx["inventory"] = _inventory
	return ctx


## Letters.choices of the letter shown ([] without one).
func choices() -> Array[Dictionary]:
	if letters == null or uid == "":
		return [] as Array[Dictionary]
	return letters.choices(uid, choice_context())


func _refresh() -> void:
	var data := letters.letter(uid) if letters != null and uid != "" else null
	var n := uids.size()
	count_label.text = Phase9Texts.LETTER_COUNT % [maxi(uids.find(uid) + 1, 1), n] if n > 1 else ""
	prev_button.visible = n > 1
	next_button.visible = n > 1
	for c: Node in _choices.get_children():
		var b := c.get_child(0) as Button if c.get_child_count() > 0 else null
		if b != null and b.has_focus():
			_focus_choice = StringName(str(b.get_meta(&"choice", "")))
	UIKit.clear_children(_choices)
	choice_rows.clear()
	if data == null:
		outside_label.text = Phase9Texts.LETTER_NONE
		sender_label.text = ""
		text_label.text = ""
		state_label.text = ""
		_fit_scroll.call_deferred()
		return
	outside_label.text = data.outside if data.outside != "" else String(data.id)
	var shown_text := letters.visible_text(uid)
	sender_label.text = Phase9Texts.LETTER_SENDER % data.sender if data.sender != "" and shown_text != "" else ""
	sender_label.visible = sender_label.text != ""
	text_label.text = "„%s“" % shown_text if shown_text != "" else Phase9Texts.LETTER_TEXT_HIDDEN
	text_label.theme_type_variation = &"InkLabel" if shown_text != "" else &"InkDimLabel"
	var st := letters.state(uid)
	state_label.text = JournalManager.letter_line(data, st) if not st in LetterRules.OPEN else ""
	state_label.visible = state_label.text != ""
	for c: Dictionary in choices():
		_choices.add_child(_choice_row(c))
	_fit_scroll.call_deferred()


func _choice_row(c: Dictionary) -> Control:
	var id := StringName(str(c.get("id", "")))
	var reason := str(c.get("reason", ""))
	var col := UIKit.vbox(2)
	var b := UIKit.button(str(c.get("label", "")), &"AccentButton" if reason == "" else &"")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = reason != "" or action_running
	b.tooltip_text = reason
	b.set_meta(&"choice", id)
	b.pressed.connect(choose.bind(id))
	col.add_child(b)
	var why := UIKit.label(reason, &"DimLabel", true)
	why.custom_minimum_size.x = panel_width - 90.0
	why.visible = reason != ""
	col.add_child(why)
	choice_rows[id] = {"button": b, "reason": why}
	return col


## A choice of the letter shown: reading starts the TimedAction (read_letter, the open letter in the hand) and decides
## at its end; every other allowed choice goes to Letters.decide now. Returns true when it was started / done.
func choose(choice: StringName) -> bool:
	if letters == null or uid == "" or action_running:
		return false
	var allowed := false
	for c: Dictionary in choices():
		if StringName(str(c.id)) == choice and str(c.reason) == "":
			allowed = true
	if not allowed:
		return false
	_focus_choice = choice
	var player := _player() as Player
	if choice == READ_CHOICE and player != null and is_instance_valid(player) and player.has_method(&"start_timed_action"):
		var minutes := READ_MINUTES
		var cfg := letters.get_config()
		if cfg != null and cfg.get(&"read_minutes") != null:
			minutes = int(cfg.get(&"read_minutes"))
		return player.start_timed_action(LABEL_READ, minutes, _decide.bind(uid, choice), true,
				ToolAnimConfig.clip_for(ACTION_READ, ANIM_READ))
	return _decide(uid, choice)


func _decide(letter_uid: String, choice: StringName) -> bool:
	if letters == null:
		return false
	var ok := letters.decide(letter_uid, choice, choice_context())
	refresh()
	return ok


func choice_button(choice: StringName) -> Button:
	return choice_rows[choice].button as Button if choice_rows.has(choice) else null


## After a rebuild the focus stays on the choice used last (else the first free one).
func focus_default() -> void:
	var again := choice_button(_focus_choice)
	if again != null and not again.disabled and again.is_visible_in_tree():
		again.grab_focus()
		reveal.call_deferred(again)
		return
	super.focus_default()


func _fit_scroll() -> void:
	fit_dock_scroll(_scroll, _body, max_body_height)


func _fit_dock() -> void:
	_fit_scroll()


func _wrap(parent: Container, variation: StringName, width: float) -> Label:
	var l := UIKit.label("", variation, true)
	l.custom_minimum_size.x = width
	parent.add_child(l)
	return l


func _on_letter_changed() -> void:
	if is_open:
		refresh()
