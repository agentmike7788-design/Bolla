class_name DaySummaryPanel
extends UIPanel
## &"day_summary" – context {day, burials_today, coins_today, total, rating} (Bed) plus the
## Phase-3 rows (docs/PHASE3_DESIGN.md §7), filled in by complete_context() when UIRoot opens it:
## {stipend, reputation_delta, reputation_tier, dirty_spots, sections_unlocked: Array[String]}.
## Missing Phase-3 keys hide their rows. Shown after sleeping (the autosave already ran).
## Phase 5 (docs/PHASE5_DESIGN.md §7): + „Gesammelt" (sum per item), „Hergestellt", „Gebaut"
## and „Ausgaben" by purpose (coins_spent) – complete_phase5() with Phase5DayLog.take(); rows
## without anything to say stay hidden.

const TEXT_TITLE := "Tag %d ist vorüber"
const TEXT_BURIALS := "Bestattungen heute"
const TEXT_COINS := "Münzen heute"
const TEXT_TOTAL := "Friedhofsqualität"
const TEXT_TOTAL_VALUE := "%d · %s"
const TEXT_STIPEND := "Pflegegeld"
const TEXT_STIPEND_VALUE := "+%d Münzen"
const TEXT_REPUTATION := "Ruf"
const TEXT_REPUTATION_VALUE := "%s (%s)"
const TEXT_DIRTY := "Verwilderte Stellen"
const TEXT_UNLOCKED := "Freigelegt"
const TEXT_SAVED := "Der Tag wurde gespeichert (Autosave)."
const TEXT_CONTINUE := "Neuer Tag"

@export var panel_width: float = 620.0

var title_label: Label
var burials_label: Label
var coins_label: Label
var total_label: Label
var stipend_label: Label
var reputation_label: Label
var dirty_label: Label
var unlocked_label: Label
var gathered_label: Label
var crafted_label: Label
var built_label: Label
var spent_label: Label
## value label -> its caption (hidden together).
var _captions: Dictionary[Label, Label] = {}


## Adds the Phase-3 values of the live systems to the Bed's context (keys already present win):
## the cemetery quality of CemeteryScore (the Bed reports graves only), the last daily
## reputation change and stipend, dirty spots (level ≥ 2), sections unlocked since the last
## summary. Without the systems the context stays as it is.
static func complete_context(ctx: Dictionary, tree: SceneTree, unlocked: Array[StringName]) -> Dictionary:
	var out := ctx.duplicate()
	if tree == null:
		return out
	var score_node := tree.get_first_node_in_group(CemeteryStatus.SCORE_GROUP)
	if score_node != null and score_node.has_method(&"breakdown"):
		var score := CemeteryStatus.score(tree)
		out["total"] = int(score.total)
		out["rating"] = score.rating
	var rep := tree.get_first_node_in_group(CemeteryStatus.REPUTATION_GROUP) as Reputation
	if rep != null:
		var daily := rep.last_daily()
		if not out.has("stipend"):
			out["stipend"] = int(daily.get("stipend", 0))
		if not out.has("reputation_delta"):
			out["reputation_delta"] = int(daily.get("drift", 0))
		if not out.has("reputation_tier"):
			out["reputation_tier"] = rep.tier()
	var clean := tree.get_first_node_in_group(CemeteryStatus.CLEANLINESS_GROUP) as CleanlinessManager
	if clean != null and not out.has("dirty_spots"):
		out["dirty_spots"] = clean.dirty_count(2)
	if not out.has("sections_unlocked") and (not unlocked.is_empty() or tree.get_first_node_in_group(CemeteryStatus.EXPANSION_GROUP) != null):
		var names: Array[String] = []
		for id: StringName in unlocked:
			var s := Database.section(id) as SectionData
			names.append(s.display_name if s != null else String(id))
		out["sections_unlocked"] = names
	return out


## Adds the Phase-5 rows (Phase5DayLog.take(): gathered, crafted, built, spent) – keys already
## in the context win.
static func complete_phase5(ctx: Dictionary, log_data: Dictionary) -> Dictionary:
	var out := ctx.duplicate()
	for key: String in ["gathered", "crafted", "built", "spent"]:
		if not out.has(key) and log_data.has(key):
			out[key] = log_data[key]
	return out


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
	stipend_label = _add_row(grid, TEXT_STIPEND)
	total_label = _add_row(grid, TEXT_TOTAL)
	reputation_label = _add_row(grid, TEXT_REPUTATION)
	dirty_label = _add_row(grid, TEXT_DIRTY)
	unlocked_label = _add_row(grid, TEXT_UNLOCKED)
	gathered_label = _add_row(grid, Phase5Texts.DAY_GATHERED)
	crafted_label = _add_row(grid, Phase5Texts.DAY_CRAFTED)
	built_label = _add_row(grid, Phase5Texts.DAY_BUILT)
	spent_label = _add_row(grid, Phase5Texts.DAY_SPENT)
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
	_show(stipend_label, context.has("stipend"), TEXT_STIPEND_VALUE % int(context.get("stipend", 0)))
	var tier := StringName(str(context.get("reputation_tier", "")))
	_show(reputation_label, tier != &"", TEXT_REPUTATION_VALUE % [ReputationRules.label(tier), UIKit.signed(int(context.get("reputation_delta", 0)))])
	var dirty := int(context.get("dirty_spots", 0))
	_show(dirty_label, context.has("dirty_spots"), str(dirty))
	dirty_label.theme_type_variation = &"WarningLabel" if dirty > 0 else &"SubheaderLabel"
	var unlocked: Array = context.get("sections_unlocked", [])
	_show(unlocked_label, not unlocked.is_empty(), ", ".join(PackedStringArray(unlocked)))
	unlocked_label.theme_type_variation = &"GoodLabel" if not unlocked.is_empty() else &"SubheaderLabel"
	var gathered := Phase5Texts.amounts_text(context.get("gathered", {}))
	_show(gathered_label, gathered != "", gathered)
	var crafted := int(context.get("crafted", 0))
	_show(crafted_label, crafted > 0, str(crafted))
	var built := Phase5Texts.stations_text(context.get("built", []))
	_show(built_label, built != "", built)
	built_label.theme_type_variation = &"GoodLabel"
	var spent := Phase5Texts.spent_text(context.get("spent", {}))
	_show(spent_label, spent != "", spent)


## German label of a rating id (&"orderly" → "Ordentlich"); other strings pass through.
static func rating_label(rating: Variant) -> String:
	var id := StringName(str(rating))
	if CemeteryRating.LABELS.has(id):
		return CemeteryRating.label(id)
	return str(rating)


## Value text of a row ("" when the row is hidden).
func row_text(value_label: Label) -> String:
	return value_label.text if value_label.visible else ""


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
