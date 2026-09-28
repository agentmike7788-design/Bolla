class_name SliceSummaryPanel
extends UIPanel
## &"slice_summary" – context {days, burials, total, rating, reputation}.
## Requested by the Graveyard when the last grave is completed. Phase 3 (docs/PHASE3_DESIGN.md
## §1.3, §7): variant &"cemetery" (Graveyard.summary_context()) adds {decor, dirt,
## reputation_tier, content_ghosts} and measures the goal „Ehrwürdig“ (100) instead of
## „Würdevoll“; reputation is shown as its tier (no raw value).
## Phase 4 (docs/PHASE4_DESIGN.md §1.3, §7): variant &"six_pits" (Graveyard.chapter_context())
## is the chapter panel „Sechs Gruben“: days, burials, prepared / utilized, the piety tier as a
## word (never a number), insights n/5, ghosts content / restless and a closing line by piety
## tier and the insight „Nicht Lorenz“.
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
const VARIANT_SIX_PITS := &"six_pits"
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
var header_label: Label
var intro_label: Label
var chapter_grid: GridContainer
## CHAPTER_ROWS caption -> value label (variant six_pits).
var chapter_rows: Dictionary[String, Label] = {}
var _cemetery_grid: GridContainer
var continue_button: Button

## True while "Zum Titel" waits for its confirming second press.
var _confirm_title: bool = false


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	header_label = _make_header(box, TEXT_TITLE, false)
	intro_label = UIKit.label(TEXT_INTRO, &"", true)
	intro_label.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro_label)
	var grid := GridContainer.new()
	_cemetery_grid = grid
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
	chapter_grid = GridContainer.new()
	chapter_grid.columns = 2
	chapter_grid.add_theme_constant_override(&"h_separation", 40)
	for caption: String in Phase4Texts.CHAPTER_ROWS:
		chapter_grid.add_child(UIKit.label(caption, &"DimLabel"))
		var value := UIKit.label("", &"SubheaderLabel")
		chapter_grid.add_child(value)
		chapter_rows[caption] = value
	chapter_grid.visible = false
	box.add_child(chapter_grid)
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
	var chapter := StringName(str(context.get("variant", ""))) == VARIANT_SIX_PITS
	_cemetery_grid.visible = not chapter
	chapter_grid.visible = chapter
	header_label.text = Phase4Texts.CHAPTER_TITLE if chapter else TEXT_TITLE
	intro_label.text = Phase4Texts.CHAPTER_INTRO if chapter else TEXT_INTRO
	if chapter:
		_refresh_chapter()
		return
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


## Chapter „Sechs Gruben“: the rows of Phase4Texts.CHAPTER_ROWS and the closing lines.
func _refresh_chapter() -> void:
	var values := Phase4Texts.chapter_values(context, Phase4Texts.main_insight_total())
	for i: int in Phase4Texts.CHAPTER_ROWS.size():
		chapter_rows[Phase4Texts.CHAPTER_ROWS[i]].text = values[i]
	var tier := StringName(str(context.get("piety_tier", "")))
	if tier == &"":
		tier = PietyRules.tier(int(context.get("piety", 0)), PietyRules._cfg(null))
	goal_label.text = Phase4Texts.chapter_closing(tier, bool(context.get("not_lorenz", false)))
	goal_label.theme_type_variation = &"AccentLabel"


## Chapter row value by caption ("" unknown) – tests.
func chapter_value(caption: String) -> String:
	return chapter_rows[caption].text if chapter_rows.has(caption) else ""


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
