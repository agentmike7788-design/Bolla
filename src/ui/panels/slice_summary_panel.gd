class_name SliceSummaryPanel
extends UIPanel
## &"slice_summary" – context {days, burials, total, rating, reputation}.
## Requested by the Graveyard when the last grave is completed. Phase 3 (docs/PHASE3_DESIGN.md
## §1.3, §7): variant &"cemetery" (Graveyard.summary_context()) adds {decor, dirt,
## reputation_tier, content_ghosts} and measures the goal „Ehrwürdig“ (100) instead of
## „Würdevoll“; reputation is shown as its tier (no raw value).
## Default focus is "Weiterspielen"; "Zum Titel" asks once (like the pause menu).

const TEXT_TITLE := "Der Friedhof ist vollendet"
const TEXT_INTRO := "Jede Grabstelle ist belegt und trägt ihr Zeichen. Oben auf dem Hügel ist es still geworden – die gute Art von still."
const TEXT_DAYS := "Tage"
const TEXT_BURIALS := "Bestattungen"
const TEXT_TOTAL := "Friedhofsqualität"
const TEXT_TOTAL_VALUE := "%d · %s"
const TEXT_REPUTATION := "Ruf"
const TEXT_DECOR := "Zier"
const TEXT_DIRT := "Pflege"
const TEXT_GHOSTS := "Zufriedene Geister"
const VARIANT_CEMETERY := &"cemetery"
const TEXT_GOAL_REACHED := "Ziel „%s“ (ab %d) erreicht."
const TEXT_GOAL_MISSED := "Ziel „%s“ (ab %d) verfehlt – es fehlen %d Punkte."
const TEXT_CONTINUE := "Weiterspielen"
const TEXT_TITLE_SCREEN := "Zum Titel"
const TEXT_CONFIRM := PauseMenu.TEXT_CONFIRM
const ACTION_TITLE := &"title"
const GOAL_RATING := &"dignified"
const GOAL_RATING_CEMETERY := &"venerable"

@export var panel_width: float = 720.0

var days_label: Label
var burials_label: Label
var total_label: Label
var reputation_label: Label
var decor_label: Label
var dirt_label: Label
var ghosts_label: Label
var _captions: Dictionary[Label, Label] = {}
var goal_label: Label
var title_button: Button
var continue_button: Button

## True while "Zum Titel" waits for its confirming second press.
var _confirm_title: bool = false


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	_make_header(box, TEXT_TITLE, false)
	var intro := UIKit.label(TEXT_INTRO, &"", true)
	intro.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 40)
	days_label = _add_row(grid, TEXT_DAYS)
	burials_label = _add_row(grid, TEXT_BURIALS)
	total_label = _add_row(grid, TEXT_TOTAL)
	decor_label = _add_row(grid, TEXT_DECOR)
	dirt_label = _add_row(grid, TEXT_DIRT)
	reputation_label = _add_row(grid, TEXT_REPUTATION)
	ghosts_label = _add_row(grid, TEXT_GHOSTS)
	box.add_child(grid)
	goal_label = UIKit.label("", &"AccentLabel", true)
	goal_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(goal_label)
	var bottom := UIKit.hbox(12)
	bottom.add_child(UIKit.spacer())
	title_button = UIKit.button(TEXT_TITLE_SCREEN)
	title_button.pressed.connect(_on_title_pressed)
	bottom.add_child(title_button)
	continue_button = UIKit.button(TEXT_CONTINUE, &"AccentButton")
	continue_button.pressed.connect(request_close)
	bottom.add_child(continue_button)
	box.add_child(bottom)


func _on_opened() -> void:
	_confirm_title = false


## The safe choice: one Enter keeps playing instead of leaving to the title.
func focus_default() -> void:
	if is_visible_in_tree() and continue_button != null and continue_button.is_visible_in_tree():
		continue_button.grab_focus()


func _refresh() -> void:
	title_button.text = TEXT_CONFIRM % TEXT_TITLE_SCREEN if _confirm_title else TEXT_TITLE_SCREEN
	var total := int(context.get("total", 0))
	days_label.text = str(int(context.get("days", TimeManager.day)))
	burials_label.text = str(int(context.get("burials", 0)))
	total_label.text = TEXT_TOTAL_VALUE % [total, DaySummaryPanel.rating_label(context.get("rating", &""))]
	var cemetery := StringName(str(context.get("variant", ""))) == VARIANT_CEMETERY
	var tier := StringName(str(context.get("reputation_tier", "")))
	reputation_label.text = ReputationRules.label(tier) if tier != &"" else GameState.reputation_label()
	_show(decor_label, cemetery, UIKit.signed(int(context.get("decor", 0))))
	_show(dirt_label, cemetery, UIKit.signed(-int(context.get("dirt", 0))))
	_show(ghosts_label, cemetery, str(int(context.get("content_ghosts", 0))))
	var goal_rating := GOAL_RATING_CEMETERY if cemetery else GOAL_RATING
	var goal := _goal_threshold(goal_rating)
	var goal_name := CemeteryRating.label(goal_rating)
	if total >= goal:
		goal_label.text = TEXT_GOAL_REACHED % [goal_name, goal]
		goal_label.theme_type_variation = &"GoodLabel"
	else:
		goal_label.text = TEXT_GOAL_MISSED % [goal_name, goal, goal - total]
		goal_label.theme_type_variation = &"AccentLabel"


func _goal_threshold(goal_rating: StringName = GOAL_RATING) -> int:
	var thresholds := _economy().rating_thresholds
	var index := CemeteryRating.TIERS.find(goal_rating) - 1
	return thresholds[index] if index >= 0 and index < thresholds.size() else 0


## First press asks ("wirklich? Ungespeichertes geht verloren."), the second one leaves.
func _on_title_pressed() -> void:
	if not _confirm_title:
		_confirm_title = true
		refresh()
		return
	_confirm_title = false
	action_requested.emit(ACTION_TITLE)


func _show(value_label: Label, shown: bool, text: String) -> void:
	value_label.text = text if shown else ""
	value_label.visible = shown
	_captions[value_label].visible = shown


func _add_row(grid: GridContainer, caption: String) -> Label:
	var cap := UIKit.label(caption, &"DimLabel")
	grid.add_child(cap)
	var value := UIKit.label("", &"SubheaderLabel")
	grid.add_child(value)
	_captions[value] = cap
	return value
