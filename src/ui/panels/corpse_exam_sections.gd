class_name CorpseExamSections
extends RefCounted
## Section builders for the corpse exam panel (CorpseExamPanel): header, the two columns,
## cause, condition, findings, the valuables decision, the button row and a trait card.
## Static: each builder adds its nodes to `parent` and stores the widgets in the panel's
## public fields; the panel keeps the signal wiring and all refresh logic.


## Title, age and the ✕ button (returned so the panel can wire it).
static func build_header(panel: CorpseExamPanel, parent: Container) -> Button:
	var head := UIKit.hbox(18)
	panel.title_label = UIKit.label("", &"HeaderLabel")
	head.add_child(panel.title_label)
	panel.age_label = UIKit.label("", &"DimLabel")
	panel.age_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.age_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(panel.age_label)
	var close_x := UIKit.button(UIPanel.TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = UIPanel.TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(close_x)
	parent.add_child(head)
	return close_x


## Returns [left, right] columns (both VBoxContainer, column_width wide).
static func build_columns(panel: CorpseExamPanel, parent: Container) -> Array[VBoxContainer]:
	var columns := UIKit.hbox(24)
	parent.add_child(columns)
	var left := UIKit.vbox(14)
	left.custom_minimum_size.x = panel.column_width
	columns.add_child(left)
	var right := UIKit.vbox(10)
	right.custom_minimum_size.x = panel.column_width
	columns.add_child(right)
	return [left, right]


static func build_cause(panel: CorpseExamPanel, parent: Container) -> void:
	var cause_section := UIKit.panel(&"SectionPanel")
	var cause_box := UIKit.vbox(4)
	cause_box.add_child(UIKit.label(CorpseExamPanel.TEXT_CAUSE, &"DimLabel"))
	panel.cause_label = UIKit.label("", &"SubheaderLabel")
	cause_box.add_child(panel.cause_label)
	panel.cause_text = UIKit.label("", &"", true)
	panel.cause_text.custom_minimum_size.x = panel.column_width - 40.0
	cause_box.add_child(panel.cause_text)
	cause_section.add_child(cause_box)
	parent.add_child(cause_section)


static func build_condition(panel: CorpseExamPanel, parent: Container) -> void:
	var condition := UIKit.panel(&"SectionPanel")
	var condition_box := UIKit.vbox(10)
	condition_box.add_child(UIKit.label(CorpseExamPanel.TEXT_CONDITION, &"DimLabel"))
	var bar_row := UIKit.hbox(14)
	panel.freshness_bar = UIKit.bar(&"FreshBar")
	panel.freshness_bar.custom_minimum_size = Vector2(300.0, 22.0)
	panel.freshness_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(panel.freshness_bar)
	panel.freshness_label = UIKit.label("", &"")
	bar_row.add_child(panel.freshness_label)
	condition_box.add_child(bar_row)
	var status_row := UIKit.hbox(24)
	panel.examined_label = UIKit.label("", &"DimLabel")
	status_row.add_child(panel.examined_label)
	panel.shrouded_label = UIKit.label("", &"DimLabel")
	status_row.add_child(panel.shrouded_label)
	condition_box.add_child(status_row)
	condition.add_child(condition_box)
	parent.add_child(condition)


## Findings caption, note and the fixed-height trait column (its ScrollContainer is returned).
static func build_findings(panel: CorpseExamPanel, parent: Container) -> ScrollContainer:
	parent.add_child(UIKit.label(CorpseExamPanel.TEXT_FINDINGS, &"DimLabel"))
	panel.findings_note = UIKit.label("", &"DimLabel", true)
	panel.findings_note.custom_minimum_size.x = panel.column_width
	parent.add_child(panel.findings_note)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(panel.column_width, panel.findings_height)
	panel.traits_box = UIKit.vbox(10)
	panel.traits_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel.traits_box)
	parent.add_child(scroll)
	return scroll


## Valuables question with take / leave buttons, plus the "decided" line.
static func build_decision(panel: CorpseExamPanel, parent: Container) -> void:
	panel.decision_box = UIKit.vbox(8)
	panel.decision_box.add_child(UIKit.label(CorpseExamPanel.TEXT_VALUABLES_QUESTION, &"AccentLabel"))
	panel.take_button = UIKit.button("", &"DangerButton")
	panel.decision_box.add_child(panel.take_button)
	panel.leave_button = UIKit.button("", &"AccentButton")
	panel.decision_box.add_child(panel.leave_button)
	parent.add_child(panel.decision_box)
	panel.decided_label = UIKit.label("", &"DimLabel")
	parent.add_child(panel.decided_label)


## Examine / shroud / pick up, the block reason and close.
static func build_buttons(panel: CorpseExamPanel, parent: Container) -> void:
	var buttons := UIKit.hbox(12)
	panel.examine_button = UIKit.button("")
	buttons.add_child(panel.examine_button)
	panel.shroud_button = UIKit.button("")
	buttons.add_child(panel.shroud_button)
	panel.pick_up_button = UIKit.button(CorpseExamPanel.TEXT_PICK_UP)
	buttons.add_child(panel.pick_up_button)
	panel.reason_label = UIKit.label("", &"DimLabel", true)
	panel.reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buttons.add_child(panel.reason_label)
	panel.close_button = UIKit.button(UIPanel.TEXT_CLOSE)
	buttons.add_child(panel.close_button)
	parent.add_child(buttons)


## One findings card (meta trait_id) for a revealed trait.
static func trait_card(trait_id: StringName, info: Dictionary, column_width: float) -> PanelContainer:
	var card := UIKit.panel(&"CardPanel")
	card.set_meta(&"trait_id", trait_id)
	var card_box := UIKit.vbox(4)
	card_box.add_child(UIKit.label(str(info.get("label", trait_id)), &"InkHeaderLabel"))
	var text := UIKit.label(str(info.get("reveal_text", "")), &"InkLabel", true)
	text.custom_minimum_size.x = column_width - 70.0
	card_box.add_child(text)
	card.add_child(card_box)
	return card


# --- Phase 4 (docs/PHASE4_DESIGN.md §7) ------------------------------------------------------

## A find card of MorgueTablePanelState.finds: revealed = parchment card (ink stamp „→ Merkbuch“
## when it carries a clue); lost = dimmed card with the lost text and a small wilted leaf.
## Meta find_id / find_state.
static func find_card(find: Dictionary, width: float) -> PanelContainer:
	var lost := StringName(str(find.get("state", ""))) == MorgueTablePanelState.STATE_LOST
	var card := UIKit.panel(&"FindLostPanel" if lost else &"CardPanel")
	card.set_meta(&"find_id", StringName(str(find.get("id", ""))))
	card.set_meta(&"find_state", StringName(str(find.get("state", ""))))
	var box := UIKit.vbox(4)
	var head := UIKit.hbox(10)
	if lost:
		var leaf := WiltedLeaf.new()
		leaf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(leaf)
	var title := UIKit.label(str(find.get("label", "")), &"InkDimLabel" if lost else &"InkHeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if not lost and StringName(str(find.get("clue_id", ""))) != &"":
		var stamp := UIKit.label(Phase4Texts.TEXT_FIND_STAMP, &"InkStampLabel")
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stamp.rotation_degrees = -3.0
		head.add_child(stamp)
	box.add_child(head)
	var text := UIKit.label(str(find.get("text", "")), &"InkDimLabel" if lost else &"InkLabel", true)
	text.custom_minimum_size.x = width - 70.0
	box.add_child(text)
	card.add_child(box)
	return card


## Slim line for a finished step without finds: „Kleidung – Nichts Auffälliges.“
static func nothing_row(step_label: String, text: String, width: float) -> PanelContainer:
	var row := UIKit.panel(&"FindNothingPanel")
	row.set_meta(&"nothing_step", step_label)
	var l := UIKit.label("%s – %s" % [step_label, text], &"DimLabel", true)
	l.custom_minimum_size.x = width - 40.0
	row.add_child(l)
	return row


## Small painted-looking wilted leaf (the loss symbol of lost find cards).
class WiltedLeaf extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22.0, 22.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var leaf := Color(0.42, 0.36, 0.24, 0.95)
		var vein := Color(0.25, 0.2, 0.13, 0.9)
		var pts := PackedVector2Array()
		for i: int in 13:
			var t := float(i) / 12.0
			var a := lerpf(-PI * 0.5, PI * 0.5, t)
			pts.append(c + Vector2(cos(a) * 5.0 + 1.5 * sin(t * PI * 3.0), sin(a) * 9.0).rotated(0.7))
		for i: int in range(12, -1, -1):
			var t := float(i) / 12.0
			var a := lerpf(-PI * 0.5, PI * 0.5, t)
			pts.append(c + Vector2(-cos(a) * 4.0, sin(a) * 9.0).rotated(0.7))
		draw_colored_polygon(pts, leaf)
		draw_line(c + Vector2(0.0, -9.0).rotated(0.7), c + Vector2(0.0, 11.0).rotated(0.7), vein, 1.5, true)
