class_name DialogueBox
extends Control
## Dialogue UI (docs §7): runs a DialogueRunner with {inventory, speaker}, shows speaker
## name, text and up to MAX_CHOICES answers (buttons + keys dialogue_choice_1..4).
## UIState modal &"dialogue" while open; emits EventBus.dialogue_ended(id) at the end.
## Phase 6: Osric's menu has grown past four answers (candles, buildings) – every available answer
## is shown (up to MAX_CHOICES; from TWO_COLUMNS_FROM on in two columns), keys 1–4 pick the first
## four, the rest by mouse or focus (arrows + Enter).

signal closed(dialogue_id: StringName)

const MODAL_ID := &"dialogue"
const MAX_CHOICES := 12
const KEY_CHOICES := 4
const TWO_COLUMNS_FROM := 6
const CHOICE_ACTIONS: Array[StringName] = [&"dialogue_choice_1", &"dialogue_choice_2", &"dialogue_choice_3", &"dialogue_choice_4"]
const TEXT_END := "(Ende)"
const TEXT_HINT := "[1–4] wählen · [Esc] beenden"

## Letters per second of the typewriter (0 = instant).
@export var chars_per_second: float = 110.0
@export var box_width: float = 1180.0
@export var bottom_margin: float = 44.0

var dialogue_id: StringName = &""
var runner: DialogueRunner
var speaker_label: Label
var text_label: Label
var choices_box: VBoxContainer

var _speaker: Node
var _choice_buttons: Array[Button] = []
var _typing: float = 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var frame := UIKit.panel(&"WindowPanel")
	frame.name = "Frame"
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_bottom = -bottom_margin
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.custom_minimum_size.x = box_width
	add_child(frame)
	var box := UIKit.vbox(12)
	frame.add_child(box)
	var head := UIKit.hbox()
	speaker_label = UIKit.label("", &"HeaderLabel")
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(speaker_label)
	head.add_child(UIKit.label(TEXT_HINT, &"DimLabel"))
	box.add_child(head)
	text_label = UIKit.label("", &"SubheaderLabel", true)
	text_label.custom_minimum_size.x = box_width - 80.0
	text_label.mouse_filter = Control.MOUSE_FILTER_STOP
	text_label.gui_input.connect(_on_text_input)
	box.add_child(text_label)
	box.add_child(UIKit.separator())
	choices_box = UIKit.vbox(8)
	box.add_child(choices_box)


func _process(delta: float) -> void:
	if not visible or text_label.visible_ratio >= 1.0 or chars_per_second <= 0.0:
		return
	_typing += delta * chars_per_second
	var total := maxi(text_label.get_total_character_count(), 1)
	text_label.visible_ratio = clampf(_typing / total, 0.0, 1.0)


## Starts dialogue `id` (Database.dialogue). false (and dialogue_ended right away, so the
## speaker never waits) when the data is missing or no node can be entered.
func start(id: StringName, speaker: Node, inventory: Object) -> bool:
	if is_active():
		push_warning("[DialogueBox] '%s' requested while '%s' runs – ignored" % [id, dialogue_id])
		return false
	var data := Database.dialogue(id) as DialogueData
	if data == null:
		push_warning("[DialogueBox] unknown dialogue '%s'" % id)
		EventBus.dialogue_ended.emit(id)
		return false
	dialogue_id = id
	_speaker = speaker
	runner = DialogueRunner.new()
	runner.start(data, {"inventory": inventory, "speaker": speaker})
	if runner.is_finished():
		_emit_end(_clear())
		return false
	speaker_label.text = data.speaker_name
	UIState.push_modal(MODAL_ID)
	visible = true
	_show_node()
	return true


func is_active() -> bool:
	return runner != null


## Picks available choice `index` (0-based). On a node without choices any index ends.
func choose(index: int) -> void:
	if not is_active():
		return
	var choices := runner.available_choices()
	if choices.is_empty():
		end_dialogue()
		return
	if index < 0 or index >= mini(choices.size(), MAX_CHOICES):
		return
	runner.choose(index)
	if runner.is_finished():
		end_dialogue()
	else:
		_show_node()


## Ends the dialogue now (Esc, last choice): pops the modal, emits dialogue_ended.
func end_dialogue() -> void:
	if not is_active():
		return
	var id := _clear()
	UIState.pop_modal(MODAL_ID)
	_emit_end(id)


## Hides without popping the modal (UIState was cleared elsewhere, e.g. loading).
func abort() -> void:
	if is_active():
		_emit_end(_clear())


func current_text() -> String:
	return runner.current_text() if is_active() else ""


func choice_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for button: Button in _choice_buttons:
		out.append(button.text)
	return out


## Handles dialogue_choice_1..4; true if the event was used.
func handle_choice_input(event: InputEvent) -> bool:
	if not is_active():
		return false
	for i: int in CHOICE_ACTIONS.size():
		if event.is_action_pressed(CHOICE_ACTIONS[i]):
			choose(i)
			return true
	return false


func _show_node() -> void:
	text_label.text = runner.current_text()
	_typing = 0.0
	text_label.visible_ratio = 1.0 if chars_per_second <= 0.0 else 0.0
	UIKit.clear_children(choices_box)
	_choice_buttons.clear()
	var choices := runner.available_choices()
	if choices.is_empty():
		_add_choice(0, TEXT_END)
	var shown := mini(choices.size(), MAX_CHOICES)
	var columns := 2 if shown >= TWO_COLUMNS_FROM else 1
	var line: HBoxContainer = null
	for i: int in shown:
		if i % columns == 0:
			line = UIKit.hbox(16)
			choices_box.add_child(line)
		_add_choice(i, choices[i].text, line if columns > 1 else null)
	_focus_first_choice.call_deferred()


func _focus_first_choice() -> void:
	if not _choice_buttons.is_empty() and _choice_buttons[0].is_inside_tree():
		_choice_buttons[0].grab_focus()


func _add_choice(index: int, text: String, line: HBoxContainer = null) -> void:
	var row := UIKit.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap := UIKit.keycap(str(index + 1) if index < KEY_CHOICES else "·")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var button := UIKit.button(text, &"ChoiceButton")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(choose.bind(index))
	row.add_child(button)
	if line != null:
		row.custom_minimum_size.x = (box_width - 100.0) * 0.5
		line.add_child(row)
	else:
		choices_box.add_child(row)
	_choice_buttons.append(button)


## Resets the box (state first, so re-entrant modal listeners see it closed); returns the id.
func _clear() -> StringName:
	var id := dialogue_id
	visible = false
	runner = null
	dialogue_id = &""
	_speaker = null
	_choice_buttons.clear()
	UIKit.clear_children(choices_box)
	return id


func _emit_end(id: StringName) -> void:
	EventBus.dialogue_ended.emit(id)
	closed.emit(id)


func _on_text_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		text_label.visible_ratio = 1.0
