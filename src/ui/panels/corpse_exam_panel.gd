class_name CorpseExamPanel
extends UIPanel
## &"corpse_exam" – context {corpse_id: String, table: MorgueTable, player: Player}.
## Shows name, age, cause (+ description once examined), freshness, the findings and the
## valuables decision. Closes itself when the corpse leaves the table.
## Two modes, chosen on every refresh:
## - Phase 4 (docs/PHASE4_DESIGN.md §7): the table offers panel_state() (a CorpseCare node
##   exists) → the left column gets the tabs Untersuchen · Herrichten · Verwerten
##   (CorpseExamTabs), the right column the find cards grouped by step (lost ones dimmed).
##   Buttons call table.request_exam_step / request_exam_all / request_wash / request_dress /
##   request_lay_out / request_balm / request_harvest, decide_valuables and request_pick_up.
## - Phase 2 (no panel_state): the old layout – request_examine(), request_shroud(),
##   decide_valuables(take), request_pick_up() and the trait cards.
## The sections are built by CorpseExamSections / CorpseExamTabs; this script wires and
## refreshes them.
## Phase 6 (docs/PHASE6_DESIGN.md §2.2, §7): the header names the table (table.panel_title():
## „Gruft-Tisch" / „Leichentisch") before the dead's name; the condition adds the cold of the crypt
## („Kühle: × 0,7 (Gruft)", CorpseManager.cold_factor_for) – the forecast already counts it
## (CorpseDecay.minutes_until with both window lists).
## Phase 7 (docs/PHASE7_DESIGN.md §2.6, §7): the tab „Präparate" (CorpseExamOrgans → CorpseExamTabs) and
## the cause „laut Osric: Fieber · gedeutet: Arsenik" once deduced (CorpseRecord.revealed_cause).

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
const TEXT_DRESSED := "✓ Eingekleidet (%s)"
const TEXT_NOT_DRESSED := "Nicht eingekleidet"
const STAGE_LABELS: Dictionary[StringName, String] = {&"fresh": "Frisch", &"wilted": "Welk", &"decaying": "Verwesend", &"rotten": "Verfallen"}
const STAGE_BARS: Dictionary[StringName, StringName] = {&"fresh": &"FreshBar", &"wilted": &"WiltedBar", &"decaying": &"DecayBar", &"rotten": &"DecayBar"}
const SHROUD_ITEM := &"shroud"
const LOCATION_TABLE := &"table"
const CORPSE_MANAGER_GROUP := &"corpse_manager"

@export var column_width: float = 600.0
## Height of the scrolling findings column (several traits fit, more scroll).
@export var findings_height: float = 400.0
## Phase 4: the findings column is taller (it sits beside the tabs).
@export var findings_height_p4: float = 500.0
## Phase 4: seconds a harvest button stays armed after the first press.
@export var harvest_confirm_seconds: float = 3.0

var title_label: Label
## Phase 6: the table's name („Gruft-Tisch") and the cold line.
var table_label: Label
var cold_label: Label
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
## Phase-4 tabs, pages and find cards.
var tabs: CorpseExamTabs
## True while the table offers panel_state() (Phase-4 layout).
var phase4: bool = false

var _corpse_id: String = ""
var _traits_scroll: ScrollContainer
var _left: VBoxContainer
var _decision_home: int = 0
var _last_corpse: String = ""


func _build() -> void:
	var box := UIKit.vbox(14)
	add_child(box)
	CorpseExamSections.build_header(self, box).pressed.connect(request_close)
	var columns := CorpseExamSections.build_columns(self, box)
	_left = columns[0]
	var right := columns[1]
	CorpseExamSections.build_cause(self, _left)
	CorpseExamSections.build_condition(self, _left)
	_traits_scroll = CorpseExamSections.build_findings(self, right)
	CorpseExamSections.build_decision(self, _left)
	_decision_home = decision_box.get_index()
	take_button.pressed.connect(_on_take_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	tabs = CorpseExamTabs.new(_call_table, _economy())
	tabs.confirm_seconds = harvest_confirm_seconds
	tabs.build_condition_extras(freshness_bar.get_parent().get_parent() as VBoxContainer, freshness_bar)
	tabs.build(_left, column_width, self)
	tabs.build_findings(traits_box, findings_note)
	tabs.exam_only.append(cause_label.get_parent().get_parent() as Control)
	tabs.organs_hide.append(freshness_bar.get_parent().get_parent().get_parent() as Control)

	_make_action_row(box)
	box.add_child(UIKit.separator())
	CorpseExamSections.build_buttons(self, box)
	examine_button.pressed.connect(_call_table.bind(&"request_examine"))
	shroud_button.pressed.connect(_call_table.bind(&"request_shroud"))
	pick_up_button.pressed.connect(_on_pick_up_pressed)
	close_button.pressed.connect(request_close)


func _ready() -> void:
	super._ready()
	EventBus.corpse_updated.connect(_on_corpse_updated)
	EventBus.time_tick.connect(_on_time_tick)


func _on_opened() -> void:
	_corpse_id = str(context.get("corpse_id", ""))
	if _corpse_id != _last_corpse:
		tabs.current_tab = CorpseExamTabs.TAB_EXAM
	_last_corpse = _corpse_id


func _on_closed() -> void:
	_corpse_id = ""
	if tabs != null:
		tabs.disarm()


func _refresh() -> void:
	var record := current_record()
	if record == null or record.location != LOCATION_TABLE:
		request_close.call_deferred()
		return
	var state := panel_state()
	if not state.is_empty():
		state["organs"] = CorpseExamOrgans.state(get_tree() if is_inside_tree() else null, record, _exam_inventory())
	_set_mode(not state.is_empty())
	var tables := Database.corpse_tables() as CorpseTables
	var cause: Dictionary = tables.get_cause(record.cause_id) if tables != null else {}
	title_label.text = record.display_name
	table_label.text = table_title()
	table_label.visible = table_label.text != ""
	cold_label.text = cold_text(record)
	cold_label.visible = cold_label.text != ""
	age_label.text = TEXT_AGE % record.age
	cause_label.text = str(cause.get("label", record.cause_id))
	if record.revealed_cause != &"":
		cause_label.text = Phase7Texts.CAUSE_REVEALED % [cause_label.text, Phase7Texts.cause_label(record.revealed_cause)]
	cause_text.text = str(cause.get("description", "")) if record.examined else TEXT_CAUSE_HIDDEN
	cause_text.theme_type_variation = &"" if record.examined else &"DimLabel"
	_refresh_condition(record)
	_refresh_valuables(record)
	if phase4:
		_refresh_phase4(record, state)
	else:
		_refresh_traits(record, tables)
		_refresh_buttons(record)


## Default focus never lands on the (irreversible) valuables or harvest buttons.
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	var candidates: Array[Button] = []
	if phase4 and tabs != null:
		candidates.append_array(tabs.focus_candidates())
	else:
		candidates.append_array([examine_button, shroud_button])
	candidates.append_array([pick_up_button, close_button])
	for button: Button in candidates:
		if button != null and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return


## The context table's panel_title() („Gruft-Tisch" / „Leichentisch"), "" for a table without one.
func table_title() -> String:
	var table: Variant = context.get("table")
	if is_instance_valid(table) and (table as Object).has_method(&"panel_title"):
		return str((table as Object).call(&"panel_title"))
	return ""


## „Kühle: × 0,7 (Gruft)" while the corpse lies in the cold (CorpseManager.cold_factor_for), else "".
func cold_text(record: CorpseRecord) -> String:
	if record == null or not is_inside_tree():
		return ""
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"cold_factor_for"):
		return ""
	return Phase6Texts.cold_line(record.location, float(manager.call(&"cold_factor_for", record.location, record.room)))


## The CorpseRecord of the context (null when unknown / no manager).
func current_record() -> CorpseRecord:
	if _corpse_id == "" or not is_inside_tree():
		return null
	var manager := get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"get_record"):
		return null
	return manager.call(&"get_record", _corpse_id) as CorpseRecord


## MorgueTable.panel_state() of the context table ({} = Phase-2 table / no CorpseCare).
func panel_state() -> Dictionary:
	var table: Variant = context.get("table")
	if not is_instance_valid(table) or not (table as Object).has_method(&"panel_state"):
		return {}
	var state: Variant = (table as Object).call(&"panel_state")
	return state if state is Dictionary else {}


## Trait labels shown in the findings (Phase 2; empty until examined).
func shown_traits() -> PackedStringArray:
	var out: PackedStringArray = []
	for card: Node in traits_box.get_children():
		if not card.is_queued_for_deletion() and card.has_meta(&"trait_id"):
			out.append(String(card.get_meta(&"trait_id")))
	return out


## Phase 4: [find id, state] of every shown find card, in display order.
func shown_finds() -> Array[Array]:
	var out: Array[Array] = []
	for card: Node in traits_box.get_children():
		if not card.is_queued_for_deletion() and card.has_meta(&"find_id"):
			out.append([card.get_meta(&"find_id"), card.get_meta(&"find_state")])
	return out


## Phase 4: step labels shown as „… – Nichts Auffälliges.“ rows.
func shown_nothing_steps() -> PackedStringArray:
	var out: PackedStringArray = []
	for card: Node in traits_box.get_children():
		if not card.is_queued_for_deletion() and card.has_meta(&"nothing_step"):
			out.append(str(card.get_meta(&"nothing_step")))
	return out


func _set_mode(p4: bool) -> void:
	if p4 == phase4 and tabs.tab_bar.visible == p4:
		return
	phase4 = p4
	tabs.tab_bar.visible = p4
	for tab: StringName in CorpseExamTabs.TABS:
		tabs.pages[tab].visible = p4 and tab == tabs.current_tab
	for l: Control in tabs.stage_labels:
		l.get_parent().visible = p4
	tabs.stage_ticks.visible = p4
	tabs.loss_label.visible = false
	examine_button.visible = not p4
	if not p4:
		for c: Control in tabs.exam_only:
			c.visible = true
	shroud_button.visible = not p4
	_traits_scroll.custom_minimum_size.y = findings_height_p4 if p4 else findings_height
	# The valuables decision sits in the Untersuchen page (Phase 4) or under the condition.
	var target: Container = tabs.exam_page_decision_slot if p4 else _left
	for node: Control in [decision_box, decided_label]:
		if node.get_parent() != target:
			node.reparent(target, false)
	if not p4:
		_left.move_child(decision_box, mini(_decision_home, _left.get_child_count() - 1))
		_left.move_child(decided_label, decision_box.get_index() + 1)


func _refresh_condition(record: CorpseRecord) -> void:
	var stage := record.freshness_stage()
	freshness_bar.value = clampf(record.freshness, 0.0, 1.0)
	freshness_bar.theme_type_variation = STAGE_BARS.get(stage, &"FreshBar")
	freshness_label.text = TEXT_FRESHNESS % [STAGE_LABELS.get(stage, String(stage)), roundi(record.freshness * 100.0)]
	examined_label.text = TEXT_EXAMINED if record.examined else TEXT_NOT_EXAMINED
	examined_label.theme_type_variation = &"GoodLabel" if record.examined else &"DimLabel"
	if phase4 and record.dress != &"":
		shrouded_label.text = TEXT_DRESSED % Phase4Texts.DRESS_LABELS.get(record.dress, String(record.dress))
	elif phase4:
		shrouded_label.text = TEXT_NOT_DRESSED
	else:
		shrouded_label.text = TEXT_SHROUDED if record.shrouded else TEXT_NOT_SHROUDED
	shrouded_label.theme_type_variation = &"GoodLabel" if record.shrouded else &"DimLabel"


func _refresh_phase4(record: CorpseRecord, state: Dictionary) -> void:
	tabs.refresh(state, action_running)
	tabs.refresh_findings(state, column_width)
	_traits_scroll.visible = traits_box.get_child_count() > 0
	pick_up_button.disabled = action_running
	reason_label.text = TEXT_REASON_BUSY if action_running else ""
	reason_label.visible = action_running
	take_button.text = Phase4Texts.TEXT_TAKE_P4 % [record.valuables_coins, UIKit.signed(_economy().valuables_taken_malus),
			UIKit.signed(_economy().valuables_reputation)]


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
		traits_box.add_child(CorpseExamSections.trait_card(trait_id, info, column_width))


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


## The acting player's inventory (context player, else the group player) – Phase 7 specimen card.
func _exam_inventory() -> Inventory:
	var inv := _player_inventory()
	if inv != null:
		return inv
	var p := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return p.get(&"inventory") as Inventory if p != null else null


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
	if not is_open:
		return
	var r := current_record()
	if r == null or r.location != LOCATION_TABLE:
		return
	_refresh_condition(r)
	if phase4:
		tabs.refresh_condition(panel_state())
