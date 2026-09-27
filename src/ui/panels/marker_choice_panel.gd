class_name MarkerChoicePanel
extends UIPanel
## &"marker_choice" – context {grave_id: String, plot: GravePlot, options: Array[StringName]}.
## One button per marker option ("+1/+3 Qualität" from EconomyConfig.marker_quality);
## choosing closes the panel and calls plot.request_marker(id).

const TEXT_TITLE := "Grabzeichen wählen"
const TEXT_QUESTION := "Welches Zeichen soll das Grab tragen?"
const TEXT_OPTION := "%s   %s Qualität"
const TEXT_CANCEL := "Abbrechen"

@export var panel_width: float = 620.0
@export var icon_edge: float = 56.0

var _options_box: VBoxContainer
## marker id -> Button
var _buttons: Dictionary[StringName, Button] = {}


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	_make_header(box, TEXT_TITLE)
	box.add_child(UIKit.label(TEXT_QUESTION, &"DimLabel"))
	_options_box = UIKit.vbox(10)
	box.add_child(_options_box)
	var bottom := UIKit.hbox()
	bottom.add_child(UIKit.spacer())
	var cancel := UIKit.button(TEXT_CANCEL)
	cancel.pressed.connect(request_close)
	bottom.add_child(cancel)
	box.add_child(bottom)


func _refresh() -> void:
	UIKit.clear_children(_options_box)
	_buttons.clear()
	var qualities := _economy().marker_quality
	for id: StringName in options():
		var button := UIKit.button(TEXT_OPTION % [UIKit.item_name(id), UIKit.signed(int(qualities.get(id, 0)))], &"AccentButton")
		button.icon = Database.icon(id)
		button.expand_icon = false
		button.add_theme_constant_override(&"icon_max_width", int(icon_edge))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose.bind(id))
		_options_box.add_child(button)
		_buttons[id] = button


## The offered marker ids (context "options", unknown entries dropped).
func options() -> Array[StringName]:
	var out: Array[StringName] = []
	var raw: Variant = context.get("options", [])
	if raw is Array or raw is PackedStringArray:
		for entry: Variant in raw:
			if (entry is String or entry is StringName) and String(entry) != "":
				out.append(StringName(entry))
	return out


func option_button(id: StringName) -> Button:
	return _buttons.get(id)


## Closes the panel, then lets the plot place the marker (it starts the timed action).
func choose(marker_id: StringName) -> void:
	var plot: Variant = context.get("plot")
	request_close()
	if not is_instance_valid(plot) or not (plot as Object).has_method(&"request_marker"):
		push_warning("[MarkerChoicePanel] plot has no request_marker()")
		return
	(plot as Object).call(&"request_marker", marker_id)
