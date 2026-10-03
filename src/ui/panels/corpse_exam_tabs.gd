class_name CorpseExamTabs
extends RefCounted
## Phase-4 part of the morgue table panel (docs/PHASE4_DESIGN.md §7), owned by CorpseExamPanel:
## the tab bar Untersuchen · Herrichten · Verwerten (the third only once Ilse is known, muted,
## without signal colour), the pages and the find cards of the right column. Input is
## MorgueTable.panel_state() (MorgueTablePanelState); every button calls a MorgueTable
## request_* method through `call_table` – no game state is changed here.
## Harvest buttons are two-stage: the first press arms them („Wirklich? Noch einmal klicken“),
## after confirm_seconds they fall back; they never take the default focus.
## Phase 7 (docs/PHASE7_DESIGN.md §2.6, §7): a fourth tab „Präparate" (only with anatomy_known at the crypt
## table – state["organs"] from CorpseExamOrgans): seven rows Herz … Hand under „Genommen: 1 von höchstens
## 3", each with Glas / Bündel where allowed (eyes only the jar, the hand only linen), the ingredients
## (there / missing), the minutes, the consequence line without a piety number, the clarity preview and a
## two-stage button (3 s; eyes and hand with the longer line) → MorgueTable.request_organ(organ, container).
## Taken rows say where the piece is now.

const TAB_EXAM := &"exam"
const TAB_PREP := &"prep"
const TAB_HARVEST := &"harvest"
const TAB_ORGANS := &"organs"
const TABS: Array[StringName] = [TAB_EXAM, TAB_PREP, TAB_HARVEST, TAB_ORGANS]
const TAB_LABELS: Dictionary[StringName, String] = {
	TAB_EXAM: Phase4Texts.TAB_EXAM, TAB_PREP: Phase4Texts.TAB_PREP, TAB_HARVEST: Phase4Texts.TAB_HARVEST,
	TAB_ORGANS: Phase7Texts.TAB_ORGANS,
}
## Tabs drawn muted (no signal colour): taking from the dead.
const MUTED_TABS: Array[StringName] = [TAB_HARVEST, TAB_ORGANS]
## Loss forecast at or below this many minutes is written as a warning (§7 objective: 120).
const LOSS_WARN_MINUTES := 120
const DRESS_KINDS: Array[StringName] = [&"shroud", &"gown"]
const HARVEST_KINDS: Array[StringName] = [&"hair", &"teeth"]

## (method: StringName, args: Array) → the panel forwards to the table.
var call_table: Callable
var confirm_seconds: float = 3.0

var tab_bar: HBoxContainer
var tab_buttons: Dictionary[StringName, Button] = {}
var pages: Dictionary[StringName, VBoxContainer] = {}
var current_tab: StringName = TAB_EXAM
## Shown on the Untersuchen tab only (the cause section of the panel; keeps the panel on screen).
var exam_only: Array[Control] = []
## Phase 7: hidden on the „Präparate" tab (the condition section – the card needs the room for its seven
## rows; the clarity stands in its head line).
var organs_hide: Array[Control] = []

var stage_ticks: StageTicks
## Frisch · Welk · Verwesend · Verfallen – the current stage lit.
var stage_labels: Array[Label] = []
var loss_label: Label

var step_buttons: Dictionary[StringName, Button] = {}
var exam_all_button: Button
var step_reason_label: Label
var exam_page_decision_slot: VBoxContainer

var wash_button: Button
var wash_reason: Label
var dress_buttons: Dictionary[StringName, Button] = {}
var dress_reason: Label
var dress_warning: Label
var dress_done: Label
var lay_out_button: Button
var lay_out_reason: Label
var balm_button: Button
var balm_reason: Label
var full_prep_label: Label

var harvest_rows: Dictionary[StringName, Dictionary] = {}
var harvest_intro: Label

## Phase 7: organ -> {box, title, jar, bundle, button, info, consequence, reason, taken}; the chosen
## container per organ; the head line.
var organ_rows: Dictionary[StringName, Dictionary] = {}
var organ_containers: Dictionary[StringName, StringName] = {}
var organs_head: Label
var armed_organ: StringName = &""

var findings_box: VBoxContainer
var findings_note: Label

## Kind armed by the first press (&"" = none) and when the arming ends (msec).
var armed_kind: StringName = &""
var _armed_until: int = 0
var _timer: Timer
var _state: Dictionary = {}
var _economy: EconomyConfig
var _column_width: float = 600.0


func _init(caller: Callable, economy: EconomyConfig = null) -> void:
	call_table = caller
	_economy = economy


# --- build ------------------------------------------------------------------------------------

## Stage ticks + loss line under the freshness bar (inside the condition section).
func build_condition_extras(condition_box: VBoxContainer, bar: ProgressBar) -> void:
	stage_ticks = StageTicks.new()
	stage_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(stage_ticks)
	var row := UIKit.hbox(8)
	for i: int in range(Phase4Texts.STAGE_IDS.size() - 1, -1, -1):
		if not stage_labels.is_empty():
			row.add_child(UIKit.label("·", &"DimLabel"))
		var l := UIKit.label(Phase4Texts.STAGE_NAMES[i], &"DimLabel")
		l.set_meta(&"stage", Phase4Texts.STAGE_IDS[i])
		row.add_child(l)
		stage_labels.append(l)
	condition_box.add_child(row)
	loss_label = UIKit.label("", &"DimLabel", true)
	loss_label.custom_minimum_size.x = _column_width - 40.0
	condition_box.add_child(loss_label)


## Tab bar + three pages under `parent` (the left column); `timer_parent` hosts the arm timer.
func build(parent: VBoxContainer, column_width: float, timer_parent: Node) -> void:
	_column_width = column_width
	tab_bar = UIKit.hbox(4)
	for tab: StringName in TABS:
		var b := UIKit.button(TAB_LABELS[tab], &"ExamTabButton")
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(select_tab.bind(tab))
		tab_bar.add_child(b)
		tab_buttons[tab] = b
	parent.add_child(tab_bar)
	for tab: StringName in TABS:
		var page := UIKit.vbox(10)
		page.custom_minimum_size.x = column_width
		pages[tab] = page
		parent.add_child(page)
	_build_exam(pages[TAB_EXAM])
	_build_prep(pages[TAB_PREP])
	_build_harvest(pages[TAB_HARVEST])
	_build_organs(pages[TAB_ORGANS])
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(disarm)
	timer_parent.add_child(_timer)


func _build_exam(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 8)
	for step: StringName in CorpseRecord.STEPS:
		var b := UIKit.button("")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_call.bind(&"request_exam_step", [step]))
		grid.add_child(b)
		step_buttons[step] = b
	page.add_child(grid)
	exam_all_button = UIKit.button("", &"AccentButton")
	exam_all_button.pressed.connect(_call.bind(&"request_exam_all", []))
	page.add_child(exam_all_button)
	step_reason_label = UIKit.label("", &"DimLabel", true)
	step_reason_label.custom_minimum_size.x = _column_width
	page.add_child(step_reason_label)
	exam_page_decision_slot = UIKit.vbox(8)
	page.add_child(exam_page_decision_slot)


func _build_prep(page: VBoxContainer) -> void:
	var wash := _prep_row(page)
	wash_button = wash[0]
	wash_reason = wash[1]
	wash_button.pressed.connect(_call.bind(&"request_wash", []))
	var dress_box := UIKit.vbox(6)
	dress_box.add_child(UIKit.label(Phase4Texts.TEXT_DRESS_CAPTION, &"DimLabel"))
	for kind: StringName in DRESS_KINDS:
		var b := UIKit.button("")
		b.custom_minimum_size.x = _column_width * 0.6
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_call.bind(&"request_dress", [kind]))
		dress_box.add_child(b)
		dress_buttons[kind] = b
	dress_done = UIKit.label("", &"GoodLabel")
	dress_box.add_child(dress_done)
	dress_reason = UIKit.label("", &"DimLabel", true)
	dress_reason.custom_minimum_size.x = _column_width
	dress_box.add_child(dress_reason)
	dress_warning = UIKit.label("", &"WarningLabel", true)
	dress_warning.custom_minimum_size.x = _column_width
	dress_box.add_child(dress_warning)
	page.add_child(dress_box)
	var lay := _prep_row(page)
	lay_out_button = lay[0]
	lay_out_reason = lay[1]
	lay_out_button.pressed.connect(_call.bind(&"request_lay_out", []))
	var balm := _prep_row(page)
	balm_button = balm[0]
	balm_reason = balm[1]
	balm_button.pressed.connect(_call.bind(&"request_balm", []))
	full_prep_label = UIKit.label(Phase4Texts.TEXT_FULL_PREP, &"GoodLabel")
	page.add_child(full_prep_label)


## [button, reason label] – the reason sits under the button (dim, wrapping).
func _prep_row(page: VBoxContainer) -> Array:
	var row := UIKit.vbox(2)
	var b := UIKit.button("")
	b.custom_minimum_size.x = _column_width * 0.6
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(b)
	var reason := UIKit.label("", &"DimLabel", true)
	reason.custom_minimum_size.x = _column_width
	row.add_child(reason)
	page.add_child(row)
	return [b, reason]


func _build_harvest(page: VBoxContainer) -> void:
	harvest_intro = UIKit.label(Phase4Texts.TEXT_HARVEST_INTRO, &"DimLabel", true)
	harvest_intro.custom_minimum_size.x = _column_width
	page.add_child(harvest_intro)
	for kind: StringName in HARVEST_KINDS:
		var box := UIKit.vbox(4)
		var b := UIKit.button("", &"DangerButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(press_harvest.bind(kind))
		box.add_child(b)
		var line := UIKit.label("", &"DimLabel", true)
		line.custom_minimum_size.x = _column_width
		box.add_child(line)
		var reason := UIKit.label("", &"WarningLabel", true)
		reason.custom_minimum_size.x = _column_width
		box.add_child(reason)
		page.add_child(box)
		harvest_rows[kind] = {"box": box, "button": b, "line": line, "reason": reason}


func _build_organs(page: VBoxContainer) -> void:
	organs_head = UIKit.label("", &"AccentLabel")
	page.add_child(organs_head)
	var intro := UIKit.label(Phase7Texts.ORGANS_INTRO, &"DimLabel", true)
	intro.custom_minimum_size.x = _column_width
	page.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(_column_width, 560.0)
	page.add_child(scroll)
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for organ: StringName in AnatomyConfig.ORGANS:
		var box := UIKit.vbox(2)
		var head := UIKit.hbox(8)
		var title := UIKit.label("", &"SubheaderLabel")
		title.custom_minimum_size.x = 110.0
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(title)
		var jar := UIKit.button(Phase7Texts.ORGAN_JAR, &"ExamTabButton")
		jar.focus_mode = Control.FOCUS_NONE
		jar.pressed.connect(choose_container.bind(organ, SpecimenRecord.CONTAINER_JAR))
		head.add_child(jar)
		var bundle := UIKit.button(Phase7Texts.ORGAN_BUNDLE, &"ExamTabButton")
		bundle.focus_mode = Control.FOCUS_NONE
		bundle.pressed.connect(choose_container.bind(organ, SpecimenRecord.CONTAINER_BUNDLE))
		head.add_child(bundle)
		var b := UIKit.button("", &"DangerButton")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(press_organ.bind(organ))
		head.add_child(b)
		box.add_child(head)
		var line := UIKit.hbox(14)
		var info := UIKit.label("", &"DimLabel")
		line.add_child(info)
		var consequence := UIKit.label("", &"DimLabel")
		consequence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		consequence.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(consequence)
		box.add_child(line)
		var reason := UIKit.label("", &"WarningLabel", true)
		reason.custom_minimum_size.x = _column_width - 30.0
		box.add_child(reason)
		var taken := UIKit.label("", &"GoodLabel", true)
		box.add_child(taken)
		list.add_child(box)
		organ_rows[organ] = {"box": box, "title": title, "jar": jar, "bundle": bundle, "button": b, "info": info,
				"consequence": consequence, "reason": reason, "taken": taken}


## Findings column: caption, note and the grouped cards (inside the panel's scroll).
func build_findings(findings: VBoxContainer, note: Label) -> void:
	findings_box = findings
	findings_note = note


# --- refresh ----------------------------------------------------------------------------------

func refresh(state: Dictionary, running: bool) -> void:
	_state = state
	var harvest_visible := bool(state.get("harvest_visible", false))
	tab_buttons[TAB_HARVEST].visible = harvest_visible
	if current_tab == TAB_HARVEST and not harvest_visible:
		current_tab = TAB_EXAM
	var organs: Dictionary = state.get("organs", {})
	tab_buttons[TAB_ORGANS].visible = bool(organs.get("visible", false))
	if current_tab == TAB_ORGANS and not tab_buttons[TAB_ORGANS].visible:
		current_tab = TAB_EXAM
	_refresh_tabs()
	_refresh_exam(state, running)
	_refresh_prep(state.get("prep", {}), running)
	_refresh_harvest(state.get("harvest", {}), running)
	_refresh_organs(organs, running)
	refresh_condition(state)


## Stage ticks, the stage name and the loss forecast (also every clock tick).
func refresh_condition(state: Dictionary) -> void:
	var stage := StringName(str(state.get("stage", "")))
	stage_ticks.current = Phase4Texts.stage_index(stage)
	stage_ticks.queue_redraw()
	for l: Label in stage_labels:
		l.theme_type_variation = &"AccentLabel" if StringName(l.get_meta(&"stage")) == stage else &"DimLabel"
	var loss: Dictionary = state.get("next_loss", {})
	loss_label.text = Phase4Texts.loss_text(loss)
	loss_label.visible = loss_label.text != ""
	var urgent := not loss.is_empty() and int(loss.get("minutes", 9999)) <= LOSS_WARN_MINUTES
	loss_label.theme_type_variation = &"WarningLabel" if urgent else &"AccentLabel"


func select_tab(tab: StringName) -> void:
	if not tab in TABS or (tab in MUTED_TABS and not tab_buttons[tab].visible):
		return
	current_tab = tab
	disarm()
	_refresh_tabs()


func _refresh_tabs() -> void:
	for tab: StringName in TABS:
		var selected := tab == current_tab
		if tab in MUTED_TABS:
			tab_buttons[tab].theme_type_variation = &"ExamTabMutedSelected" if selected else &"ExamTabMuted"
		else:
			tab_buttons[tab].theme_type_variation = &"ExamTabSelected" if selected else &"ExamTabButton"
		pages[tab].visible = selected
	for c: Control in exam_only:
		c.visible = current_tab == TAB_EXAM
	for c: Control in organs_hide:
		c.visible = current_tab != TAB_ORGANS


func _refresh_exam(state: Dictionary, running: bool) -> void:
	var reasons := {}
	for raw: Variant in state.get("steps", []):
		var s := raw as Dictionary
		var step := StringName(str(s.get("id", "")))
		if not step_buttons.has(step):
			continue
		var b := step_buttons[step]
		b.text = Phase4Texts.step_text(s)
		var reason := str(s.get("reason", ""))
		var done := bool(s.get("done", false))
		b.disabled = running or done or reason != ""
		b.tooltip_text = reason if not done else ""
		b.theme_type_variation = &""
		if reason != "" and not done:
			if not reasons.has(reason):
				reasons[reason] = []
			(reasons[reason] as Array).append(str(s.get("label", "")))
	var open: Array = state.get("open_steps", [])
	exam_all_button.text = Phase4Texts.exam_all_text(int(state.get("exam_all_minutes", 0)), open.size())
	exam_all_button.disabled = running or open.is_empty()
	var lines := PackedStringArray()
	for reason: String in reasons:
		lines.append("%s: %s" % [", ".join(PackedStringArray(reasons[reason])), reason])
	step_reason_label.text = "\n".join(lines)
	step_reason_label.visible = not lines.is_empty()


func _refresh_prep(prep: Dictionary, running: bool) -> void:
	var wash: Dictionary = prep.get("wash", {})
	_prep_button(wash_button, wash_reason, Phase4Texts.wash_text(wash, _economy), wash, running)
	var dress: Dictionary = prep.get("dress", {})
	var current := StringName(str(dress.get("current", "")))
	var reasons := PackedStringArray()
	for kind: StringName in DRESS_KINDS:
		var entry: Dictionary = dress.get(kind, {})
		var b := dress_buttons[kind]
		b.text = Phase4Texts.dress_text(kind, entry, _economy)
		b.visible = current == &"" and not entry.is_empty()
		var reason := str(entry.get("reason", ""))
		b.disabled = running or reason != ""
		b.tooltip_text = reason
		if reason != "" and not reason in reasons:
			reasons.append(reason)
	dress_done.text = Phase4Texts.dressed_text(current) if current != &"" else ""
	dress_done.visible = current != &""
	dress_reason.text = "\n".join(reasons) if current == &"" else ""
	dress_reason.visible = dress_reason.text != ""
	dress_warning.text = str(prep.get("dress_warning", "")) if current == &"" else ""
	dress_warning.visible = dress_warning.text != ""
	var lay: Dictionary = prep.get("lay_out", {})
	_prep_button(lay_out_button, lay_out_reason, Phase4Texts.lay_out_text(lay, _economy), lay, running)
	if not bool(lay.get("done", false)) and lay_out_reason.text == "":
		lay_out_reason.text = Phase4Texts.TEXT_LAY_OUT_HINT
		lay_out_reason.visible = true
	var balm: Dictionary = prep.get("balm", {})
	balm_button.text = Phase4Texts.balm_text(balm)
	var active := bool(balm.get("active", false))
	var balm_block := str(balm.get("reason", ""))
	balm_button.disabled = running or balm_block != ""
	balm_button.theme_type_variation = &""
	balm_reason.text = balm_block if balm_block != "" and not active else (Phase4Texts.TEXT_BALM_HINT if not active else "")
	balm_reason.visible = balm_reason.text != ""
	full_prep_label.visible = bool(wash.get("done", false)) and current != &"" and bool(lay.get("done", false))


func _prep_button(b: Button, reason_label: Label, text: String, entry: Dictionary, running: bool) -> void:
	var done := bool(entry.get("done", false))
	var reason := str(entry.get("reason", ""))
	b.text = text
	b.disabled = running or done or reason != ""
	reason_label.text = reason if not done else ""
	reason_label.visible = reason_label.text != ""


func _refresh_harvest(harvest: Dictionary, running: bool) -> void:
	var bonus := _buyer_bonus()
	for kind: StringName in HARVEST_KINDS:
		var row: Dictionary = harvest_rows[kind]
		var entry: Dictionary = harvest.get(kind, {})
		var reason := str(entry.get("reason", UtilizationRules.HIDDEN))
		var box := row.box as Control
		box.visible = not entry.is_empty() and reason != UtilizationRules.HIDDEN
		if not box.visible:
			if armed_kind == kind:
				disarm()
			continue
		var b := row.button as Button
		var done := bool(entry.get("done", false))
		b.text = Phase4Texts.TEXT_HARVEST_CONFIRM if armed_kind == kind else Phase4Texts.harvest_text(entry)
		b.disabled = running or done or reason != ""
		(row.line as Label).text = Phase4Texts.consequence_line(UtilizationRules.effects(kind), bonus) if not done else ""
		(row.line as Label).visible = not done
		(row.reason as Label).text = reason if not done else ""
		(row.reason as Label).visible = (row.reason as Label).text != ""


## Phase 7: the seven specimen rows from state["organs"] (CorpseExamOrgans.state).
func _refresh_organs(organs: Dictionary, running: bool) -> void:
	if organs_head == null:
		return
	var rows: Dictionary = organs.get("rows", {})
	organs_head.text = Phase7Texts.ORGANS_HEAD % [int(organs.get("taken", 0)), int(organs.get("max", 3))]
	var clarity := str(organs.get("clarity_word", ""))
	if clarity != "":
		organs_head.text += Phase7Texts.SEP + Phase7Texts.ORGAN_CLARITY % clarity
	var inv := _inventory()
	for organ: StringName in organ_rows:
		var ui: Dictionary = organ_rows[organ]
		var entry: Dictionary = rows.get(organ, {})
		(ui.box as Control).visible = not entry.is_empty()
		if entry.is_empty():
			continue
		var containers: Array = entry.get("containers", [])
		var chosen := chosen_container(organ, containers)
		var jar := ui.jar as Button
		var bundle := ui.bundle as Button
		var taken_now := bool(entry.get("taken", false))
		jar.visible = containers.has(SpecimenRecord.CONTAINER_JAR) and not taken_now
		bundle.visible = containers.has(SpecimenRecord.CONTAINER_BUNDLE) and not taken_now
		jar.theme_type_variation = &"ExamTabSelected" if chosen == SpecimenRecord.CONTAINER_JAR else &"ExamTabButton"
		bundle.theme_type_variation = &"ExamTabSelected" if chosen == SpecimenRecord.CONTAINER_BUNDLE else &"ExamTabButton"
		(ui.title as Label).text = str(entry.get("label", organ))
		var taken := bool(entry.get("taken", false))
		var reasons: Dictionary = entry.get("reasons", {})
		var reason := str(reasons.get(chosen, SpecimenRules.REASON_NO_CARD))
		var b := ui.button as Button
		b.visible = not taken
		jar.disabled = taken or running
		bundle.disabled = taken or running
		if armed_organ == organ:
			b.text = Phase7Texts.ORGAN_CONFIRM_GRAVE if organ in Phase7Texts.GRAVE_ORGANS else Phase7Texts.ORGAN_CONFIRM
		else:
			b.text = Phase7Texts.ORGAN_TAKE % [Phase7Texts.container_word(chosen), UIKit.minutes(int(entry.get("minutes", 20)))]
		b.disabled = running or taken or reason != ""
		var inputs: Dictionary = (entry.get("inputs", {}) as Dictionary).get(chosen, {})
		var info := Phase7Texts.inputs_text(inputs, inv)
		(ui.info as Label).text = info if not taken else ""
		(ui.info as Label).visible = not taken
		(ui.consequence as Label).text = str(entry.get("consequence", ""))
		(ui.consequence as Label).visible = not taken
		var shown_reason := reason if not taken and reason != SpecimenRules.REASON_NO_CARD else ""
		(ui.reason as Label).text = shown_reason
		(ui.reason as Label).visible = shown_reason != ""
		var where := str(entry.get("where", ""))
		var taken_text := Phase7Texts.ORGAN_RETURNED if bool(entry.get("returned", false)) else Phase7Texts.ORGAN_TAKEN % (where if where != "" else Phase7Texts.NONE)
		(ui.taken as Label).text = taken_text if taken else ""
		(ui.taken as Label).visible = taken


## The container shown for `organ` (the chosen one if still allowed, else the first allowed).
func chosen_container(organ: StringName, containers: Array) -> StringName:
	var c: StringName = organ_containers.get(organ, &"")
	if c != &"" and containers.has(c):
		return c
	return StringName(str(containers[0])) if not containers.is_empty() else SpecimenRecord.CONTAINER_JAR


func choose_container(organ: StringName, container: StringName) -> void:
	organ_containers[organ] = container
	if armed_organ == organ:
		armed_organ = &""
	_refresh_organs(_state.get("organs", {}), false)


## First press arms the organ row, a second within confirm_seconds calls request_organ(organ, container).
func press_organ(organ: StringName) -> void:
	var rows: Dictionary = (_state.get("organs", {}) as Dictionary).get("rows", {})
	var entry: Dictionary = rows.get(organ, {})
	var container := chosen_container(organ, entry.get("containers", []))
	if armed_organ == organ and Time.get_ticks_msec() <= _armed_until:
		disarm()
		_call(&"request_organ", [organ, container])
		return
	armed_kind = &""
	armed_organ = organ
	_armed_until = Time.get_ticks_msec() + int(confirm_seconds * 1000.0)
	if _timer != null and _timer.is_inside_tree():
		_timer.start(confirm_seconds)
	_refresh_organs(_state.get("organs", {}), false)


func _inventory() -> Inventory:
	var tree := Engine.get_main_loop() as SceneTree
	var p := tree.get_first_node_in_group(&"player") if tree != null else null
	return p.get(&"inventory") as Inventory if p != null else null


## Find cards grouped by step; lost finds dimmed with their lost text; clue cards stamped.
func refresh_findings(state: Dictionary, card_width: float) -> void:
	UIKit.clear_children(findings_box)
	var finds: Array = state.get("finds", [])
	var nothing: Array = state.get("nothing_steps", [])
	var any_done := false
	for raw: Variant in state.get("steps", []):
		var s := raw as Dictionary
		if not bool(s.get("done", false)):
			continue
		any_done = true
		var step := StringName(str(s.get("id", "")))
		var cards: Array[Dictionary] = []
		for f: Variant in finds:
			if StringName(str((f as Dictionary).get("step", ""))) == step:
				cards.append(f)
		if step in nothing or cards.is_empty():
			findings_box.add_child(CorpseExamSections.nothing_row(str(s.get("label", "")), str(state.get("nothing_text", "")), card_width))
			continue
		findings_box.add_child(UIKit.label(str(s.get("label", "")), &"DimLabel"))
		for card: Dictionary in cards:
			findings_box.add_child(CorpseExamSections.find_card(card, card_width))
	findings_note.text = Phase4Texts.TEXT_NO_FINDS if not any_done else ""
	findings_note.visible = findings_note.text != ""


# --- harvest arming ---------------------------------------------------------------------------

## First press arms the kind, a second press within confirm_seconds calls request_harvest.
func press_harvest(kind: StringName) -> void:
	if armed_kind == kind and Time.get_ticks_msec() <= _armed_until:
		disarm()
		_call(&"request_harvest", [kind])
		return
	armed_kind = kind
	armed_organ = &""
	_armed_until = Time.get_ticks_msec() + int(confirm_seconds * 1000.0)
	if _timer != null and _timer.is_inside_tree():
		_timer.start(confirm_seconds)
	_refresh_harvest(_state.get("harvest", {}), false)


func disarm() -> void:
	if armed_kind == &"" and armed_organ == &"":
		return
	armed_kind = &""
	armed_organ = &""
	if _timer != null and _timer.is_inside_tree():
		_timer.stop()
	_refresh_harvest(_state.get("harvest", {}), false)
	_refresh_organs(_state.get("organs", {}), false)


## Buttons that may take the default focus (never harvest or valuables).
func focus_candidates() -> Array[Button]:
	var out: Array[Button] = []
	match current_tab:
		TAB_EXAM:
			for step: StringName in CorpseRecord.STEPS:
				out.append(step_buttons[step])
			out.append(exam_all_button)
		TAB_PREP:
			out.append_array([wash_button, dress_buttons[&"shroud"], dress_buttons[&"gown"], lay_out_button, balm_button])
	return out


func _call(method: StringName, args: Array) -> void:
	if call_table.is_valid():
		call_table.call(method, args)



func _buyer_bonus() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var piety := tree.get_first_node_in_group(&"piety") if tree != null else null
	return int(piety.call(&"buyer_bonus")) if piety != null and piety.has_method(&"buyer_bonus") else 0


## Tick marks on the freshness bar at the stage limits (0.1 / 0.3 / 0.6) – 4 stages.
class StageTicks extends Control:
	var current: int = -1
	var limits: PackedFloat32Array = [0.1, 0.3, 0.6]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := Color(0.93, 0.88, 0.77, 0.8)
		for v: float in limits:
			var x := size.x * v
			draw_line(Vector2(x, -3.0), Vector2(x, size.y + 3.0), ink, 2.0)
