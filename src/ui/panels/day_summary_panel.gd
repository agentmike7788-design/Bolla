class_name DaySummaryPanel
extends UIPanel
## &"day_summary" – context {day, burials_today, coins_today, total, rating} (Bed) plus the
## Phase-3 rows (docs/PHASE3_DESIGN.md §7), filled in by complete_context() when UIRoot opens it:
## {stipend, reputation_delta, reputation_tier, dirty_spots, sections_unlocked: Array[String]}.
## Missing Phase-3 keys hide their rows. Shown after sleeping (the autosave already ran).
## Phase 5 (docs/PHASE5_DESIGN.md §7): + „Gesammelt" (sum per item), „Hergestellt", „Gebaut"
## and „Ausgaben" by purpose (coins_spent) – complete_phase5() with Phase5DayLog.take(); rows
## without anything to say stay hidden.
## Phase 6 (docs/PHASE6_DESIGN.md §7): „Gebaut" also names the building levels („Gruft Stufe 2"),
## „Ausgaben" has the purpose „Gebäude", + „Ausgesegnet" and „Umgebettet" (Phase5DayLog).
## Phase 7 (docs/PHASE7_DESIGN.md §7): + „Im Dorf" (earned · spent in the village by purpose), „Aufträge
## erledigt", „Beziehungen" (arrows per person) and „Präparate" (taken, sold, returned …).
## Phase 8 (docs/PHASE8_DESIGN.md §7.6): + „Besuche" (who, at which grave, how it looked), „Wünsche" (done, new,
## lapsed), „Trinkgeld", „Jakob" (places per task, mistakes with their place, wage, „Morgen: …") and „Die Nacht"
## (the robber seen / chased off, a grave disturbed, the sick light) – complete_phase8() with Phase8DayLog.take().

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
## Value column of the long Phase-8 rows (visits, Jakob, the night): they wrap at this width.
@export var wrap_width: float = 560.0

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
## Phase 6 (docs/PHASE6_DESIGN.md §7): services held and boxes reinterred today.
var services_label: Label
var reinterred_label: Label
## Phase 7 rows.
var village_label: Label
var orders_label: Label
var relations_label: Label
var specimens_label: Label
## Phase 8 rows.
var visits_label: Label
var wishes_label: Label
var tips_label: Label
var jakob_label: Label
var night_label: Label
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


## Adds the Phase-8 rows (Phase8DayLog.take(): visits, wishes, tips, jakob, night) – keys already in the context
## win.
static func complete_phase8(ctx: Dictionary, log_data: Dictionary) -> Dictionary:
	var out := ctx.duplicate()
	for key: String in ["visits", "wishes", "tips", "jakob", "night"]:
		if not out.has(key) and log_data.has(key):
			out[key] = log_data[key]
	return out


## Adds the Phase-5 rows (Phase5DayLog.take(): gathered, crafted, built, spent) – keys already
## in the context win.
static func complete_phase5(ctx: Dictionary, log_data: Dictionary) -> Dictionary:
	var out := ctx.duplicate()
	for key: String in ["gathered", "crafted", "built", "spent", "buildings", "services", "reinterred", "village_income",
			"orders_done", "relations", "specimens"]:
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
	services_label = _add_row(grid, Phase6Texts.DAY_SERVICES)
	reinterred_label = _add_row(grid, Phase6Texts.DAY_REINTERRED)
	village_label = _add_row(grid, Phase7Texts.DAY_VILLAGE)
	orders_label = _add_row(grid, Phase7Texts.DAY_ORDERS)
	relations_label = _add_row(grid, Phase7Texts.DAY_RELATIONS)
	specimens_label = _add_row(grid, Phase7Texts.DAY_SPECIMENS)
	visits_label = _add_row(grid, Phase8Texts.DAY_VISITS, true)
	wishes_label = _add_row(grid, Phase8Texts.DAY_WISHES)
	tips_label = _add_row(grid, Phase8Texts.DAY_TIPS)
	jakob_label = _add_row(grid, Phase8Texts.DAY_JAKOB, true)
	night_label = _add_row(grid, Phase8Texts.DAY_NIGHT, true)
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
	var built_parts := PackedStringArray()
	for part: String in [Phase5Texts.stations_text(context.get("built", [])), Phase6Texts.buildings_text(context.get("buildings", []))]:
		if part != "":
			built_parts.append(part)
	var built := ", ".join(built_parts)
	_show(built_label, built != "", built)
	built_label.theme_type_variation = &"GoodLabel"
	var spent := Phase5Texts.spent_text(context.get("spent", {}))
	_show(spent_label, spent != "", spent)
	var services := int(context.get("services", 0))
	_show(services_label, services > 0, str(services))
	var reinterred := int(context.get("reinterred", 0))
	_show(reinterred_label, reinterred > 0, str(reinterred))
	var income := int(context.get("village_income", 0))
	var spent_d: Dictionary = context.get("spent", {})
	var village_spent := 0
	for reason: StringName in Phase7Texts.SPENT_LABELS:
		village_spent += int(spent_d.get(reason, spent_d.get(String(reason), 0)))
	_show(village_label, income > 0 or village_spent > 0, Phase7Texts.DAY_VILLAGE_VALUE % [income, village_spent])
	var done := int(context.get("orders_done", 0))
	_show(orders_label, done > 0, str(done))
	var rel_text := Phase7Texts.relations_text(context.get("relations", {}))
	_show(relations_label, rel_text != "", rel_text)
	var spec_text := Phase7Texts.specimens_text(context.get("specimens", {}))
	_show(specimens_label, spec_text != "", spec_text)
	var visits_text := Phase8Texts.visits_text(context.get("visits", []))
	_show(visits_label, visits_text != "", visits_text)
	var wishes_text := Phase8Texts.wishes_text(context.get("wishes", {}))
	_show(wishes_label, wishes_text != "", wishes_text)
	var tips := int(context.get("tips", 0))
	_show(tips_label, tips > 0, "+%d %s" % [tips, Phase8Texts.coins(tips)])
	tips_label.theme_type_variation = &"GoodLabel"
	var jakob_text := Phase8Texts.jakob_text(context.get("jakob", {}))
	_show(jakob_label, jakob_text != "", jakob_text)
	var night_text := Phase8Texts.night_text(context.get("night", {}))
	_show(night_label, night_text != "", night_text)


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


func _add_row(grid: GridContainer, caption: String, wrap: bool = false) -> Label:
	var cap := UIKit.label(caption, &"DimLabel")
	grid.add_child(cap)
	var value := UIKit.label("", &"SubheaderLabel", wrap)
	if wrap:
		value.custom_minimum_size.x = wrap_width
	grid.add_child(value)
	_captions[value] = cap
	return value
