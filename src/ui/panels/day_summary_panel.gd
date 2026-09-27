class_name DaySummaryPanel
extends UIPanel
## &"day_summary" – context {day, burials_today, coins_today, total, rating}.
## Shown after sleeping (the autosave already ran).

const TEXT_TITLE := "Tag %d ist vorüber"
const TEXT_BURIALS := "Bestattungen heute"
const TEXT_COINS := "Münzen heute"
const TEXT_TOTAL := "Friedhofsqualität"
const TEXT_TOTAL_VALUE := "%d · %s"
const TEXT_SAVED := "Der Tag wurde gespeichert (Autosave)."
const TEXT_CONTINUE := "Neuer Tag"

@export var panel_width: float = 620.0

var title_label: Label
var burials_label: Label
var coins_label: Label
var total_label: Label


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	title_label = _make_header(box, "", false)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 40)
	burials_label = _add_row(grid, TEXT_BURIALS)
	coins_label = _add_row(grid, TEXT_COINS)
	total_label = _add_row(grid, TEXT_TOTAL)
	box.add_child(grid)
	box.add_child(UIKit.label(TEXT_SAVED, &"DimLabel"))
	var bottom := UIKit.hbox()
	bottom.add_child(UIKit.spacer())
	var next := UIKit.button(TEXT_CONTINUE, &"AccentButton")
	next.pressed.connect(request_close)
	bottom.add_child(next)
	box.add_child(bottom)


func _refresh() -> void:
	title_label.text = TEXT_TITLE % int(context.get("day", TimeManager.day))
	burials_label.text = str(int(context.get("burials_today", 0)))
	coins_label.text = UIKit.signed(int(context.get("coins_today", 0)))
	total_label.text = TEXT_TOTAL_VALUE % [int(context.get("total", 0)), rating_label(context.get("rating", &""))]


## German label of a rating id (&"orderly" → "Ordentlich"); other strings pass through.
static func rating_label(rating: Variant) -> String:
	var id := StringName(str(rating))
	if CemeteryRating.LABELS.has(id):
		return CemeteryRating.label(id)
	return str(rating)


func _add_row(grid: GridContainer, caption: String) -> Label:
	grid.add_child(UIKit.label(caption, &"DimLabel"))
	var value := UIKit.label("", &"SubheaderLabel")
	grid.add_child(value)
	return value
