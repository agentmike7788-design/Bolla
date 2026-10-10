class_name FestPanel
extends UIPanel
## &"fest" – the festival card (docs/PHASE8_DESIGN.md §2.7, §3.2.1): context {fest_id?} (today's festival when
## left out; the Merkbuch page „Hollerbrück" offers it on a festival day, dialogues may open_panel:fest). Name
## and day, time and place, the custom in one sentence and its state, then
## - Lichtgang: „Kein Grab ohne Licht: 31/34" (Festivals.lights_count) and the graves still without a light,
## - Kathreintanz: the half hour in the parlour and the dance partners (Festivals.dance_block_reason).
## Read-only – candles are lit at the graves, dances asked in the parlour ([E]).

const FESTIVALS_GROUP := &"festivals"
const GRAVEYARD_GROUP := &"graveyard"
const GRAVE_CARE_GROUP := &"grave_care"
const DARK_ROWS := 8

@export var panel_width: float = 880.0

var festivals: Festivals
var fest_id: StringName = &""
var title_label: Label
var when_label: Label
var intro_label: Label
var state_label: Label
var count_label: Label
var list_box: VBoxContainer


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(12)
	add_child(box)
	title_label = _make_header(box, "")
	when_label = UIKit.label("", &"SubheaderLabel")
	box.add_child(when_label)
	intro_label = UIKit.label("", &"WhisperLabel", true)
	intro_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro_label)
	state_label = UIKit.label("", &"DimLabel")
	box.add_child(state_label)
	box.add_child(UIKit.separator())
	count_label = UIKit.label("", &"AccentLabel")
	box.add_child(count_label)
	list_box = UIKit.vbox(4)
	box.add_child(list_box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	bottom.add_child(UIKit.spacer())
	var back := UIKit.button(TEXT_CLOSE)
	back.pressed.connect(request_close)
	bottom.add_child(back)
	box.add_child(bottom)


func _on_opened() -> void:
	var f: Variant = context.get("festivals")
	festivals = f if is_instance_valid(f) else (get_tree().get_first_node_in_group(FESTIVALS_GROUP) as Festivals if is_inside_tree() else null)
	fest_id = StringName(str(context.get("fest_id", "")))
	if fest_id == &"" and festivals != null:
		fest_id = festivals.today()


func _refresh() -> void:
	UIKit.clear_children(list_box)
	var data := festivals.festival(fest_id) if festivals != null and fest_id != &"" else null
	if data == null:
		title_label.text = Phase8Texts.FEST_NOT_TODAY
		when_label.text = ""
		intro_label.text = ""
		state_label.text = ""
		count_label.text = ""
		return
	var day := festivals.fest_day(fest_id)
	title_label.text = Phase8Texts.FEST_TITLE % [Phase8Texts.fest_name(fest_id), day]
	when_label.text = "%s%s%s" % [Phase8Texts.FEST_WHEN % [UIKit.clock(data.window.x), UIKit.clock(data.window.y)], Phase8Texts.SEP,
			Phase8Texts.FEST_WHERE.get(fest_id, "")]
	intro_label.text = Phase8Texts.FEST_INTRO.get(fest_id, "")
	state_label.text = Phase8Texts.FEST_STATE.get(festivals.state(fest_id), "")
	if fest_id == Festivals.LIGHTS:
		_refresh_lights()
	else:
		_refresh_dance()


func _refresh_lights() -> void:
	var lights := festivals.lights_count()
	count_label.text = Phase8Texts.FEST_LIGHTS_ALL if lights.y > 0 and lights.x >= lights.y else Phase8Texts.FEST_LIGHTS % [lights.x, lights.y]
	var dark := dark_graves()
	if dark.is_empty():
		return
	list_box.add_child(UIKit.label(Phase8Texts.FEST_DARK, &"DimLabel"))
	var tree := get_tree() if is_inside_tree() else null
	var names := PackedStringArray()
	for i: int in mini(dark.size(), DARK_ROWS):
		names.append(Phase8Status.dead_name(tree, dark[i]))
	var l := UIKit.label(Phase8Texts.SEP.join(names), &"", true)
	l.custom_minimum_size.x = panel_width - 80.0
	list_box.add_child(l)
	if dark.size() > DARK_ROWS:
		list_box.add_child(UIKit.label(Phase8Texts.FEST_DARK_MORE % (dark.size() - DARK_ROWS), &"DimLabel"))


func _refresh_dance() -> void:
	count_label.text = "%s: %s" % [Phase8Texts.FEST_PRESENCE, Phase8Texts.CHECK if festivals.presence_done() else Phase8Texts.NONE]
	list_box.add_child(UIKit.label(Phase8Texts.FEST_DANCE, &"DimLabel"))
	var danced := festivals.danced()
	for id: StringName in Phase7Texts.VILLAGER_ORDER:
		if id == &"oldwoman" or id == &"surgeon":
			continue
		var reason := festivals.dance_block_reason(id)
		var text := Phase8Texts.FEST_DANCED if danced.has(id) else (Phase8Texts.FEST_DANCE_OK if reason == "" else reason)
		var row := UIKit.hbox(12)
		var n := UIKit.label(Phase7Texts.person_name(id), &"")
		n.custom_minimum_size.x = 260.0
		row.add_child(n)
		var t := UIKit.label(text, &"GoodLabel" if danced.has(id) or reason == "" else &"DimLabel", true)
		t.custom_minimum_size.x = panel_width - 360.0
		row.add_child(t)
		list_box.add_child(row)


## Graves with a dead and no burning candle (the Lichtgang).
func dark_graves() -> PackedStringArray:
	var out := PackedStringArray()
	var tree := get_tree() if is_inside_tree() else null
	var graveyard := tree.get_first_node_in_group(GRAVEYARD_GROUP) if tree != null else null
	var care := tree.get_first_node_in_group(GRAVE_CARE_GROUP) as GraveCare if tree != null else null
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	for g: GraveRecord in graveyard.call(&"graves"):
		if (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED) and (care == null or not care.candle_lit(g.id)):
			out.append(g.id)
	return out
