class_name ActionChoicePanel
extends UIPanel
## &"action_choice" – Phase 9 W3 QA-Fix (QA9-01 … QA9-04): a short choice when one place offers more than one thing
## to do and a wrong press could not be undone (a letter burned, a letter into the grave) or would hide the others.
## Context {title: String, question?: String, options: Array[{id, label, reason?}], target: Object, method?:
## StringName (default request_action), player?}. One button per option in the given order (the first free one has the
## focus – the place's main action), a dimmed option names its reason under it; „Abbrechen" closes. Choosing closes the
## panel, then calls target.<method>(id) – the place starts its own timed action. Never a number.

const PANEL := &"action_choice"
const TEXT_CANCEL := "Abbrechen"
const DEFAULT_METHOD := &"request_action"

@export var panel_width: float = 620.0

var title_label: Label
var question_label: Label
var _options_box: VBoxContainer
## option id → Button
var _buttons: Dictionary[StringName, Button] = {}


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	title_label = _make_header(box, "")
	question_label = UIKit.label("", &"DimLabel", true)
	question_label.custom_minimum_size.x = panel_width - 60.0
	box.add_child(question_label)
	_options_box = UIKit.vbox(10)
	box.add_child(_options_box)
	var bottom := UIKit.hbox()
	bottom.add_child(UIKit.spacer())
	var cancel := UIKit.button(TEXT_CANCEL)
	cancel.pressed.connect(request_close)
	bottom.add_child(cancel)
	box.add_child(bottom)


func _refresh() -> void:
	title_label.text = str(context.get("title", ""))
	question_label.text = str(context.get("question", ""))
	question_label.visible = question_label.text != ""
	UIKit.clear_children(_options_box)
	_buttons.clear()
	for o: Dictionary in options():
		var id := StringName(str(o.id))
		var reason := str(o.get("reason", ""))
		var col := UIKit.vbox(2)
		var b := UIKit.button(str(o.get("label", id)), &"AccentButton" if reason == "" else &"")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = reason != ""
		b.tooltip_text = reason
		b.pressed.connect(choose.bind(id))
		col.add_child(b)
		if reason != "":
			var why := UIKit.label(reason, &"DimLabel", true)
			why.custom_minimum_size.x = panel_width - 90.0
			col.add_child(why)
		_options_box.add_child(col)
		_buttons[id] = b


## The offered options ({id, label, reason}; entries without an id dropped).
func options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Variant = context.get("options", [])
	if raw is Array:
		for entry: Variant in raw:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) != "":
				out.append(entry as Dictionary)
	return out


func option_button(id: StringName) -> Button:
	return _buttons.get(id)


## Closes the panel, then lets the target run option `id` (a dimmed or unknown option does nothing).
func choose(id: StringName) -> bool:
	var b := option_button(id)
	if b == null or b.disabled:
		return false
	var target: Variant = context.get("target")
	var method := StringName(str(context.get("method", DEFAULT_METHOD)))
	request_close()
	if not is_instance_valid(target) or not (target as Object).has_method(method):
		push_warning("[ActionChoicePanel] target has no %s()" % method)
		return false
	(target as Object).call(method, id)
	return true
