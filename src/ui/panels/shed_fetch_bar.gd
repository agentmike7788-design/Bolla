class_name ShedFetchBar
extends HBoxContainer
## The shed row of a panel (docs/PHASE6_DESIGN.md §2.5, §7): „Fehlendes aus dem Schuppen holen
## (10 Min)" (shed ≥ 2; dimmed with the reason – „Im Schuppen fehlt: 2 Werkstein", „Kein Platz im
## Inventar", „Es fehlt nichts.") and, from shed 3, „Überschuss einlagern". Hidden below shed 2.
## Pure view: the panel passes Phase6Texts.shed_state(…) to show() and connects the two signals
## to the entity (Workbench / BuildSite / BuildingSite: request_fetch / request_store).

signal fetch_pressed
signal store_pressed

var fetch_button: Button
var store_button: Button
var reason_label: Label
## Last state shown (tests).
var state: Dictionary = {}

var _short: bool = false
var _warn_variation: StringName = &"WarningLabel"


## `short_label`: „Fehlendes holen (…)"; `ink`: the parchment look of the stone panel.
func _init(short_label: bool = false, ink: bool = false) -> void:
	_short = short_label
	add_theme_constant_override(&"separation", 12)
	_warn_variation = &"LedgerWarnLabel" if ink else &"WarningLabel"
	reason_label = UIKit.label("", _warn_variation)
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(reason_label)
	store_button = UIKit.button(Phase6Texts.STORE_BUTTON, &"InkButton" if ink else &"")
	store_button.tooltip_text = Phase6Texts.STORE_HINT
	store_button.pressed.connect(func() -> void: store_pressed.emit())
	add_child(store_button)
	fetch_button = UIKit.button(Phase6Texts.fetch_button(10, _short), &"InkButton" if ink else &"")
	fetch_button.pressed.connect(_on_fetch)
	add_child(fetch_button)
	visible = false


## Shows `shed` (Phase6Texts.shed_state); `busy` dims both buttons (an action runs).
func show_state(shed: Dictionary, busy: bool = false) -> void:
	state = shed
	var reason := str(shed.get("reason", ""))
	var nothing := reason == ShedSupply.TEXT_NOTHING_MISSING
	var shown := bool(shed.get("shown", false)) and (not nothing or bool(shed.get("store_shown", false)))
	visible = shown
	if not shown:
		return
	fetch_button.text = Phase6Texts.fetch_button(int(shed.get("minutes", 0)), _short)
	fetch_button.disabled = busy or reason != ""
	fetch_button.tooltip_text = reason
	# Nothing missing: no fetch button, no warning (only „Überschuss einlagern" from shed 3).
	fetch_button.visible = not nothing
	reason_label.text = "" if nothing else reason
	reason_label.theme_type_variation = _warn_variation
	store_button.visible = bool(shed.get("store_shown", false))
	store_button.disabled = busy


func _on_fetch() -> void:
	if not fetch_button.disabled:
		fetch_pressed.emit()
