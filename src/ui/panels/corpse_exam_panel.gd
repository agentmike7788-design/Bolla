class_name CorpseExamPanel
extends UIPanel
## &"corpse_exam" – context {corpse_id: String, table: MorgueTable, player: Player}.
## Shows name, age, cause (+ description once examined), freshness, the revealed traits
## and the valuables decision. Buttons only call table.request_examine(),
## table.request_shroud(), table.decide_valuables(take) and table.request_pick_up().
## Closes itself when the corpse leaves the table.

const TEXT_AGE := "%d Jahre"
const TEXT_CAUSE := "Todesursache"
const TEXT_CAUSE_HIDDEN := "Genaueres zeigt erst eine Untersuchung."
const TEXT_CONDITION := "Zustand"
const TEXT_FRESHNESS := "%s · %d %%"
const TEXT_FINDINGS := "Befund"
const TEXT_TRAITS_HIDDEN := "Noch nicht untersucht – Merkmale bleiben verborgen."
const TEXT_NO_TRAITS := "Keine Auffälligkeiten."
const TEXT_EXAMINED := "✓ Untersucht"
const TEXT_NOT_EXAMINED := "Nicht untersucht"
const TEXT_SHROUDED := "✓ Eingehüllt"
const TEXT_NOT_SHROUDED := "Ohne Leichentuch"
const TEXT_VALUABLES_QUESTION := "Wertsachen gefunden. Was tust du? (endgültig)"
const TEXT_TAKE := "Nehmen: +%d Münzen · Grabqualität %s · Ruf sinkt"
const TEXT_LEAVE := "Liegen lassen: Grabqualität %s"
const TEXT_TAKEN := "Wertsachen genommen (+%d Münzen)."
const TEXT_LEFT := "Wertsachen liegen gelassen."
const TEXT_EXAMINE := "Untersuchen (%s)"
const TEXT_EXAMINE_DONE := "Untersucht"
const TEXT_SHROUD := "Leichentuch anlegen (%s)"
const TEXT_SHROUD_DONE := "Eingehüllt"
const TEXT_PICK_UP := "Aufnehmen"
const TEXT_REASON_BUSY := "Arbeit läuft …"
const TEXT_REASON_DECIDE := "Leichentuch: erst über die Wertsachen entscheiden."
const TEXT_REASON_NO_SHROUD := "Kein Leichentuch im Inventar (Werkbank: %s)."
const TEXT_REASON_NO_SHROUD_PLAIN := "Kein Leichentuch im Inventar."
const STAGE_LABELS: Dictionary[StringName, String] = {&"fresh": "Frisch", &"wilted": "Welk", &"decaying": "Verwesend"}
const STAGE_BARS: Dictionary[StringName, StringName] = {&"fresh": &"FreshBar", &"wilted": &"WiltedBar", &"decaying": &"DecayBar"}
const SHROUD_ITEM := &"shroud"
const LOCATION_TABLE := &"table"
const CORPSE_MANAGER_GROUP := &"corpse_manager"

@export var column_width: float = 600.0
## Height of the scrolling findings column (several traits fit, more scroll).
@export var findings_height: float = 400.0

var title_label: Label
var age_label: Label
var cause_label: Label
var cause_text: Label
var freshness_bar: ProgressBar
var freshness_label: Label
var examined_label: Label
var shrouded_label: Label
var traits_box: VBoxContainer
## "Noch nicht untersucht …" / "Keine Auffälligkeiten." (hidden while cards are shown).
var findings_note: Label
var decision_box: VBoxContainer
var take_button: Button
var leave_button: Button
var decided_label: Label
var examine_button: Button
var shroud_button: Button
var pick_up_button: Button
var close_button: Button
var reason_label: Label

var _corpse_id: String = ""
var _traits_scroll: ScrollContainer


func _build() -> void:
	var box := UIKit.vbox(14)
	add_child(box)
	var head := UIKit.hbox(18)
	title_label = UIKit.label("", &"HeaderLabel")
	head.add_child(title_label)
	age_label = UIKit.label("", &"DimLabel")
	age_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(age_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.pressed.connect(request_close)
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(close_x)
	box.add_child(head)

	var columns := UIKit.hbox(24)
	box.add_child(columns)
	var left := UIKit.vbox(14)
	left.custom_minimum_size.x = column_width
	columns.add_child(left)
	var right := UIKit.vbox(10)
	right.custom_minimum_size.x = column_width
	columns.add_child(right)

	var cause_section := UIKit.panel(&"SectionPanel")
	var cause_box := UIKit.vbox(4)
	cause_box.add_child(UIKit.label(TEXT_CAUSE, &"DimLabel"))
	cause_label = UIKit.label("", &"SubheaderLabel")
	cause_box.add_child(cause_label)
	cause_text = UIKit.label("", &"", true)
	cause_text.custom_minimum_size.x = column_width - 40.0
	cause_box.add_child(cause_text)
	cause_section.add_child(cause_box)
	left.add_child(cause_section)

	var condition := UIKit.panel(&"SectionPanel")
	var condition_box := UIKit.vbox(10)
	condition_box.add_child(UIKit.label(TEXT_CONDITION, &"DimLabel"))
	var bar_row := UIKit.hbox(14)
	freshness_bar = UIKit.bar(&"FreshBar")
	freshness_bar.custom_minimum_size = Vector2(300.0, 22.0)
	freshness_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(freshness_bar)
	freshness_label = UIKit.label("", &"")
	bar_row.add_child(freshness_label)
	condition_box.add_child(bar_row)
	var status_row := UIKit.hbox(24)
	examined_label = UIKit.label("", &"DimLabel")
	status_row.add_child(examined_label)
	shrouded_label = UIKit.label("", &"DimLabel")
	status_row.add_child(shrouded_label)
	condition_box.add_child(status_row)
	condition.add_child(condition_box)
	left.add_child(condition)

	right.add_child(UIKit.label(TEXT_FINDINGS, &"DimLabel"))
	findings_note = UIKit.label("", &"DimLabel", true)
	findings_note.custom_minimum_size.x = column_width
	right.add_child(findings_note)
	_traits_scroll = ScrollContainer.new()
	_traits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_traits_scroll.custom_minimum_size = Vector2(column_width, findings_height)
	traits_box = UIKit.vbox(10)
	traits_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_traits_scroll.add_child(traits_box)
	right.add_child(_traits_scroll)

	decision_box = UIKit.vbox(8)
	decision_box.add_child(UIKit.label(TEXT_VALUABLES_QUESTION, &"AccentLabel"))
	take_button = UIKit.button("", &"DangerButton")
	take_button.pressed.connect(_on_take_pressed)
	decision_box.add_child(take_button)
	leave_button = UIKit.button("", &"AccentButton")
	leave_button.pressed.connect(_on_leave_pressed)
	decision_box.add_child(leave_button)
	left.add_child(decision_box)
	decided_label = UIKit.label("", &"DimLabel")
	left.add_child(decided_label)

	_make_action_row(box)
	box.add_child(UIKit.separator())
	var buttons := UIKit.hbox(12)
	examine_button = UIKit.button("")
	examine_button.pressed.connect(_call_table.bind(&"request_examine"))
	buttons.add_child(examine_button)
	shroud_button = UIKit.button("")
	shroud_button.pressed.connect(_call_table.bind(&"request_shroud"))
	buttons.add_child(shroud_button)
	pick_up_button = UIKit.button(TEXT_PICK_UP)
	pick_up_button.pressed.connect(_on_pick_up_pressed)
	buttons.add_child(pick_up_button)
	reason_label = UIKit.label("", &"DimLabel", true)
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buttons.add_child(reason_label)
	close_button = UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	buttons.add_child(close_button)
	box.add_child(buttons)


func _ready() -> void:
	super._ready()
	EventBus.corpse_updated.connect(_on_corpse_updated)
	EventBus.time_tick.connect(_on_time_tick)


func _on_opened() -> void:
	_corpse_id = str(context.get("corpse_id", ""))


func _on_closed() -> void:
	_corpse_id = ""


func _refresh() -> void:
	var record := current_record()
	if record == null or record.location != LOCATION_TABLE:
		request_close.call_deferred()
		return
	var tables := Database.corpse_tables() as CorpseTables
	var cause: Dictionary = tables.get_cause(record.cause_id) if tables != null else {}
	title_label.text = record.display_name
	age_label.text = TEXT_AGE % record.age
	cause_label.text = str(cause.get("label", record.cause_id))
	cause_text.text = str(cause.get("description", "")) if record.examined else TEXT_CAUSE_HIDDEN
	cause_text.theme_type_variation = &"" if record.examined else &"DimLabel"
	_refresh_condition(record)
	_refresh_traits(record, tables)
	_refresh_valuables(record)
	_refresh_buttons(record)


## Default focus never lands on the (irreversible) valuables buttons.
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	for button: Button in [examine_button, shroud_button, pick_up_button, close_button]:
		if button != null and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return


## The CorpseRecord of the context (null when unknown / no manager).
func current_record() -> CorpseRecord:
	if _corpse_id == "" or not is_inside_tree():
		return null
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"get_record"):
		return null
	return manager.call(&"get_record", _corpse_id) as CorpseRecord


## Trait labels shown in the findings (empty until examined).
func shown_traits() -> PackedStringArray:
	var out: PackedStringArray = []
	for card: Node in traits_box.get_children():
		if not card.is_queued_for_deletion() and card.has_meta(&"trait_id"):
			out.append(String(card.get_meta(&"trait_id")))
	return out


func _refresh_condition(record: CorpseRecord) -> void:
	var stage := record.freshness_stage()
	freshness_bar.value = clampf(record.freshness, 0.0, 1.0)
	freshness_bar.theme_type_variation = STAGE_BARS.get(stage, &"FreshBar")
	freshness_label.text = TEXT_FRESHNESS % [STAGE_LABELS.get(stage, String(stage)), roundi(record.freshness * 100.0)]
	examined_label.text = TEXT_EXAMINED if record.examined else TEXT_NOT_EXAMINED
	examined_label.theme_type_variation = &"GoodLabel" if record.examined else &"DimLabel"
	shrouded_label.text = TEXT_SHROUDED if record.shrouded else TEXT_NOT_SHROUDED
	shrouded_label.theme_type_variation = &"GoodLabel" if record.shrouded else &"DimLabel"


## Trait cards scroll in a fixed-height column; without cards only a note is shown.
func _refresh_traits(record: CorpseRecord, tables: CorpseTables) -> void:
	UIKit.clear_children(traits_box)
	var revealed := record.revealed_traits()
	findings_note.text = TEXT_TRAITS_HIDDEN if not record.examined else (TEXT_NO_TRAITS if revealed.is_empty() else "")
	findings_note.visible = findings_note.text != ""
	_traits_scroll.visible = not revealed.is_empty()
	if revealed.is_empty():
		return
	for trait_id: StringName in revealed:
		var info: Dictionary = tables.get_trait(trait_id) if tables != null else {}
		var card := UIKit.panel(&"CardPanel")
		card.set_meta(&"trait_id", trait_id)
		var card_box := UIKit.vbox(4)
		card_box.add_child(UIKit.label(str(info.get("label", trait_id)), &"InkHeaderLabel"))
		var text := UIKit.label(str(info.get("reveal_text", "")), &"InkLabel", true)
		text.custom_minimum_size.x = column_width - 70.0
		card_box.add_child(text)
		card.add_child(card_box)
		traits_box.add_child(card)


func _refresh_valuables(record: CorpseRecord) -> void:
	var economy := _economy()
	var open_decision := record.needs_valuables_decision()
	decision_box.visible = open_decision
	take_button.text = TEXT_TAKE % [record.valuables_coins, UIKit.signed(economy.valuables_taken_malus)]
	leave_button.text = TEXT_LEAVE % UIKit.signed(economy.valuables_left_bonus)
	take_button.disabled = action_running
	leave_button.disabled = action_running
	match record.valuables_decision:
		CorpseRecord.DECISION_TAKEN:
			decided_label.text = TEXT_TAKEN % record.valuables_coins
		CorpseRecord.DECISION_LEFT:
			decided_label.text = TEXT_LEFT
		_:
			decided_label.text = ""
	decided_label.visible = decided_label.text != ""


func _refresh_buttons(record: CorpseRecord) -> void:
	var actions := _action_config()
	var reasons: PackedStringArray = []
	examine_button.text = TEXT_EXAMINE_DONE if record.examined else TEXT_EXAMINE % UIKit.minutes(actions.examine_minutes)
	examine_button.disabled = action_running or record.examined
	shroud_button.text = TEXT_SHROUD_DONE if record.shrouded else TEXT_SHROUD % UIKit.minutes(actions.shroud_minutes)
	var shroud_reason := _shroud_block_reason(record)
	shroud_button.disabled = action_running or record.shrouded or shroud_reason != ""
	shroud_button.tooltip_text = shroud_reason
	if shroud_reason != "" and not record.shrouded:
		reasons.append(shroud_reason)
	pick_up_button.disabled = action_running
	if action_running:
		reasons = [TEXT_REASON_BUSY]
	reason_label.text = "\n".join(reasons)
	reason_label.visible = not reasons.is_empty()


func _shroud_block_reason(record: CorpseRecord) -> String:
	if record.shrouded:
		return ""
	if record.needs_valuables_decision():
		return TEXT_REASON_DECIDE
	var inv := _player_inventory()
	if inv == null or inv.count(SHROUD_ITEM) <= 0:
		var recipe := Database.recipe(SHROUD_ITEM) as RecipeData
		if recipe == null or recipe.inputs.is_empty():
			return TEXT_REASON_NO_SHROUD_PLAIN
		var parts: PackedStringArray = []
		for id: StringName in recipe.inputs:
			parts.append("%d %s" % [recipe.inputs[id], UIKit.item_name(id)])
		return TEXT_REASON_NO_SHROUD % " + ".join(parts)
	return ""


func _call_table(method: StringName, args: Array = []) -> void:
	var table: Variant = context.get("table")
	if not is_instance_valid(table) or not (table as Object).has_method(method):
		push_warning("[CorpseExamPanel] table has no %s()" % method)
		return
	(table as Object).callv(method, args)


func _on_take_pressed() -> void:
	_call_table(&"decide_valuables", [true])


func _on_leave_pressed() -> void:
	_call_table(&"decide_valuables", [false])


func _on_pick_up_pressed() -> void:
	_call_table(&"request_pick_up")
	var r := current_record()
	if r == null or r.location != LOCATION_TABLE:
		request_close()


func _on_corpse_updated(corpse_id: String) -> void:
	if is_open and corpse_id == _corpse_id:
		refresh()


func _on_time_tick(_day: int, _minute: int) -> void:
	if is_open:
		var r := current_record()
		if r != null and r.location == LOCATION_TABLE:
			_refresh_condition(r)
