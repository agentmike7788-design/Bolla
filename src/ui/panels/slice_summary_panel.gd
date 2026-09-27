class_name SliceSummaryPanel
extends UIPanel
## &"slice_summary" – context {days, burials, total, rating, reputation}.
## Requested by the Graveyard when the last grave is completed (slice_complete).

const TEXT_TITLE := "Der Friedhof ist vollendet"
const TEXT_INTRO := "Jede Grabstelle ist belegt und trägt ihr Zeichen. Oben auf dem Hügel ist es still geworden – die gute Art von still."
const TEXT_DAYS := "Tage"
const TEXT_BURIALS := "Bestattungen"
const TEXT_TOTAL := "Friedhofsqualität"
const TEXT_TOTAL_VALUE := "%d · %s"
const TEXT_REPUTATION := "Ruf"
const TEXT_REPUTATION_VALUE := "%s (%s)"
const TEXT_GOAL_REACHED := "Ziel „%s“ (ab %d) erreicht."
const TEXT_GOAL_MISSED := "Ziel „%s“ (ab %d) verfehlt – es fehlen %d Punkte."
const TEXT_CONTINUE := "Weiterspielen"
const TEXT_TITLE_SCREEN := "Zum Titel"
const GOAL_RATING := &"dignified"

@export var panel_width: float = 720.0

var days_label: Label
var burials_label: Label
var total_label: Label
var reputation_label: Label
var goal_label: Label


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
	reputation_label = _add_row(grid, TEXT_REPUTATION)
	box.add_child(grid)
	goal_label = UIKit.label("", &"AccentLabel", true)
	goal_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(goal_label)
	var bottom := UIKit.hbox(12)
	bottom.add_child(UIKit.spacer())
	var to_title := UIKit.button(TEXT_TITLE_SCREEN)
	to_title.pressed.connect(action_requested.emit.bind(&"title"))
	bottom.add_child(to_title)
	var resume := UIKit.button(TEXT_CONTINUE, &"AccentButton")
	resume.pressed.connect(request_close)
	bottom.add_child(resume)
	box.add_child(bottom)


func _refresh() -> void:
	var total := int(context.get("total", 0))
	days_label.text = str(int(context.get("days", TimeManager.day)))
	burials_label.text = str(int(context.get("burials", 0)))
	total_label.text = TEXT_TOTAL_VALUE % [total, DaySummaryPanel.rating_label(context.get("rating", &""))]
	reputation_label.text = TEXT_REPUTATION_VALUE % [GameState.reputation_label(), UIKit.signed(int(context.get("reputation", 0)))]
	var goal := _goal_threshold()
	var goal_name := CemeteryRating.label(GOAL_RATING)
	if total >= goal:
		goal_label.text = TEXT_GOAL_REACHED % [goal_name, goal]
		goal_label.theme_type_variation = &"GoodLabel"
	else:
		goal_label.text = TEXT_GOAL_MISSED % [goal_name, goal, goal - total]
		goal_label.theme_type_variation = &"AccentLabel"


func _goal_threshold() -> int:
	var thresholds := _economy().rating_thresholds
	var index := CemeteryRating.TIERS.find(GOAL_RATING) - 1
	return thresholds[index] if index >= 0 and index < thresholds.size() else 0


func _add_row(grid: GridContainer, caption: String) -> Label:
	grid.add_child(UIKit.label(caption, &"DimLabel"))
	var value := UIKit.label("", &"SubheaderLabel")
	grid.add_child(value)
	return value
