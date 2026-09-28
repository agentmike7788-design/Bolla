class_name CemeteryOverviewPanel
extends UIPanel
## &"cemetery_overview" (docs/PHASE3_DESIGN.md §7; key U, button in the grave register) –
## context {score: Dictionary, sections: Array[Dictionary], reputation: Dictionary,
## dirt: Dictionary, ghosts: Dictionary} as built by CemeteryStatus.overview_context().
## Left: the sections (progress of clearing, prerequisite, plots, decor x/cap), below them the
## tending spots per level with the penalty. Right: quality breakdown, reputation with every
## effect and tomorrow's drift, the heard ghosts by mood. Read-only.

const TEXT_TITLE := "Friedhofsübersicht"
const TEXT_SECTIONS := "Abschnitte"
const TEXT_QUALITY := "Friedhofsqualität"
const TEXT_REPUTATION := "Ruf in Hollerbrück"
const TEXT_CARE := "Pflege"
const TEXT_GHOSTS := "Geister"
const TEXT_OPEN := "freigelegt"
const TEXT_WORKING := "freilegen: %d/%d"
const TEXT_LOCKED := "gesperrt"
const TEXT_PLOTS := "Grabstellen %d/%d vollendet · %d frei"
const TEXT_PLOTS_LOCKED := "Grabstellen erst nach dem Freilegen"
const TEXT_DECOR := "Zier %d/%d"
const TEXT_DECOR_OVER := "Zier %d/%d (voll – %d zählen nicht)"
const TEXT_TOTAL := "%d · %s"
const TEXT_GRAVES := "Gräber"
const TEXT_DECOR_ROW := "Zier"
const TEXT_DIRT_ROW := "Pflege"
const TEXT_NEXT := "%s ab %d – es fehlen %d"
const TEXT_TOP := "Höchste Stufe erreicht."
const TEXT_PAY := "Bezahlung je Bestattung"
const TEXT_DELIVERY := "Lieferungen"
const TEXT_DELIVERY_DAILY := "1 Leiche am Tag"
const TEXT_DELIVERY_ODD := "nur an ungeraden Tagen"
const TEXT_STIPEND := "Pflegegeld am Morgen"
const TEXT_STIPEND_VALUE := "%d Münzen"
const TEXT_TOMORROW := "Morgen"
const TEXT_REP_NEXT := "%s ab %d"
const LEVEL_NAMES: PackedStringArray = ["sauber", "sprießt", "verunkrautet", "verwildert"]
const TEXT_LEVEL := "%d %s"
const TEXT_PENALTY := "Abzug %s"
const TEXT_NO_CARE := "Keine Pflegestellen bekannt."
const TEXT_MOODS := "%d zufrieden · %d gleichmütig · %d unruhig"
const TEXT_HEARD := "Nur Geister, denen du zugehört hast (%d von %d)."
const TEXT_NO_GHOSTS := "Noch keinem Geist zugehört – sie gehen nachts um (21:30–04:30)."
const TEXT_NO_SECTIONS := "Keine Abschnitte bekannt."
const TEXT_HINT := "[U] oder [Esc] schließen"

@export var panel_width: float = 1280.0
@export var column_gap: int = 28

var _sections_box: VBoxContainer
var quality_value: Label
var quality_rows: Dictionary[String, Label] = {}
var quality_next: Label
## Phase 4 §2.14: what „Ehrwürdig“ still lacks (decor / tending).
var quality_venerable: Label
var reputation_value: Label
var reputation_arrow: Label
var reputation_meter: ReputationMeter
var reputation_rows: Dictionary[String, Label] = {}
var reputation_next: Label
var care_levels: Label
var care_penalty: Label
var ghosts_moods: Label
var ghosts_hint: Label
## section id -> {status: Label, bar: ProgressBar, plots: Label, decor: Label, block: Label}
var section_rows: Dictionary[StringName, Dictionary] = {}


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(16)
	add_child(box)
	_make_header(box, TEXT_TITLE)
	var columns := UIKit.hbox(column_gap)
	box.add_child(columns)
	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.add_child(UIKit.label(TEXT_SECTIONS, &"AccentLabel"))
	_sections_box = UIKit.vbox(12)
	left.add_child(_sections_box)
	_build_care(left)
	columns.add_child(left)
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	columns.add_child(right)
	_build_quality(right)
	_build_reputation(right)
	_build_ghosts(right)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _refresh() -> void:
	_refresh_sections(context.get("sections", []))
	_refresh_quality(context.get("score", {}))
	_refresh_reputation(context.get("reputation", {}))
	_refresh_care(context.get("dirt", {}))
	_refresh_ghosts(context.get("ghosts", {}))


# --- accessors (tests) ----------------------------------------------------------------------

func section_status(id: StringName) -> String:
	return (section_rows[id].status as Label).text if section_rows.has(id) else ""


func section_detail(id: StringName) -> String:
	if not section_rows.has(id):
		return ""
	var parts := PackedStringArray()
	for key: String in ["plots", "decor", "block"]:
		var l: Label = section_rows[id][key]
		if l.visible and l.text != "":
			parts.append(l.text)
	return " | ".join(parts)


# --- build ----------------------------------------------------------------------------------

func _card(parent: Container, title: String) -> VBoxContainer:
	var card := UIKit.panel(&"SectionPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := UIKit.vbox(6)
	inner.add_child(UIKit.label(title, &"AccentLabel"))
	card.add_child(inner)
	parent.add_child(card)
	return inner


func _row(parent: Container, caption: String) -> Label:
	var row := UIKit.hbox(12)
	var cap := UIKit.label(caption, &"DimLabel")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cap)
	var value := UIKit.label("", &"")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	parent.add_child(row)
	return value


func _build_quality(parent: Container) -> void:
	var inner := _card(parent, TEXT_QUALITY)
	quality_value = UIKit.label("", &"SubheaderLabel")
	inner.add_child(quality_value)
	for key: String in [TEXT_GRAVES, TEXT_DECOR_ROW, TEXT_DIRT_ROW]:
		quality_rows[key] = _row(inner, key)
	quality_next = UIKit.label("", &"DimLabel")
	inner.add_child(quality_next)
	quality_venerable = UIKit.label("", &"WarningLabel", true)
	inner.add_child(quality_venerable)


func _build_reputation(parent: Container) -> void:
	var inner := _card(parent, TEXT_REPUTATION)
	var head := UIKit.hbox(14)
	reputation_value = UIKit.label("", &"SubheaderLabel")
	head.add_child(reputation_value)
	reputation_arrow = UIKit.label("", &"DimLabel")
	head.add_child(reputation_arrow)
	head.add_child(UIKit.spacer())
	reputation_meter = ReputationMeter.new()
	reputation_meter.custom_minimum_size = Vector2(240.0, 10.0)
	reputation_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(reputation_meter)
	inner.add_child(head)
	for key: String in [TEXT_PAY, TEXT_DELIVERY, TEXT_STIPEND, TEXT_TOMORROW]:
		reputation_rows[key] = _row(inner, key)
	reputation_next = UIKit.label("", &"DimLabel")
	inner.add_child(reputation_next)


func _build_care(parent: Container) -> void:
	var inner := _card(parent, TEXT_CARE)
	care_levels = UIKit.label("", &"", true)
	inner.add_child(care_levels)
	care_penalty = UIKit.label("", &"DimLabel")
	inner.add_child(care_penalty)


func _build_ghosts(parent: Container) -> void:
	var inner := _card(parent, TEXT_GHOSTS)
	ghosts_moods = UIKit.label("", &"", true)
	inner.add_child(ghosts_moods)
	ghosts_hint = UIKit.label("", &"DimLabel", true)
	inner.add_child(ghosts_hint)


# --- refresh --------------------------------------------------------------------------------

func _refresh_sections(list: Array) -> void:
	UIKit.clear_children(_sections_box)
	section_rows.clear()
	if list.is_empty():
		_sections_box.add_child(UIKit.label(TEXT_NO_SECTIONS, &"DimLabel"))
		return
	for raw: Variant in list:
		var s := raw as Dictionary
		if s != null:
			_sections_box.add_child(_section_card(s))


func _section_card(s: Dictionary) -> Control:
	var card := UIKit.panel(&"SectionPanel")
	var inner := UIKit.vbox(6)
	card.add_child(inner)
	var head := UIKit.hbox(12)
	var name := UIKit.label(str(s.get("name", "")), &"SubheaderLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var unlocked := bool(s.get("unlocked", false))
	var block := str(s.get("block", ""))
	var done := int(s.get("done", 0))
	var total := int(s.get("total", 0))
	var status := UIKit.label("", &"")
	if unlocked:
		status.text = TEXT_OPEN
		status.theme_type_variation = &"GoodLabel"
	elif block != "":
		status.text = TEXT_LOCKED
		status.theme_type_variation = &"WarningLabel"
	else:
		status.text = TEXT_WORKING % [done, total]
		status.theme_type_variation = &"AccentLabel"
	head.add_child(status)
	inner.add_child(head)
	var bar := UIKit.bar()
	bar.custom_minimum_size.y = 12.0
	bar.value = float(done) / float(total) if total > 0 else 1.0
	bar.visible = not unlocked and total > 0 and block == ""
	inner.add_child(bar)
	var plots := UIKit.label("", &"DimLabel")
	if unlocked:
		plots.text = TEXT_PLOTS % [int(s.get("plots_marked", 0)), int(s.get("plots", 0)), int(s.get("plots_free", 0))]
	else:
		plots.text = TEXT_PLOTS_LOCKED
	var decor := UIKit.label("", &"DimLabel")
	var capped := int(s.get("decor", 0))
	var cap := int(s.get("decor_cap", 0))
	var raw := int(s.get("decor_raw", capped))
	decor.text = TEXT_DECOR_OVER % [capped, cap, raw - cap] if raw > cap and cap > 0 else TEXT_DECOR % [capped, cap]
	decor.visible = unlocked
	var line := UIKit.hbox(18)
	line.add_child(plots)
	line.add_child(UIKit.spacer())
	line.add_child(decor)
	inner.add_child(line)
	var block_label := UIKit.label(block, &"WarningLabel", true)
	block_label.visible = block != "" and not unlocked
	inner.add_child(block_label)
	section_rows[StringName(str(s.get("id", "")))] = {"status": status, "bar": bar, "plots": plots, "decor": decor, "block": block_label}
	return card


func _refresh_quality(score: Dictionary) -> void:
	var total := int(score.get("total", 0))
	quality_value.text = TEXT_TOTAL % [total, CemeteryRating.label(StringName(str(score.get("rating", "neglected"))))]
	quality_rows[TEXT_GRAVES].text = str(int(score.get("graves", 0)))
	quality_rows[TEXT_DECOR_ROW].text = UIKit.signed(int(score.get("decor", 0)))
	var dirt := int(score.get("dirt", 0))
	quality_rows[TEXT_DIRT_ROW].text = UIKit.signed(-dirt)
	quality_rows[TEXT_DIRT_ROW].theme_type_variation = &"WarningLabel" if dirt > 0 else &""
	var next := StringName(str(score.get("next_rating", "")))
	var at := int(score.get("next_at", 0))
	quality_next.text = TEXT_NEXT % [CemeteryRating.label(next), at, maxi(at - total, 0)] if next != &"" else TEXT_TOP
	var missing := Phase4Texts.venerable_missing_text(score.get("venerable_missing", PackedStringArray()))
	quality_venerable.text = missing if StringName(str(score.get("rating", ""))) != &"venerable" else ""
	quality_venerable.visible = quality_venerable.text != ""


func _refresh_reputation(rep: Dictionary) -> void:
	var forecast := int(rep.get("forecast", 0))
	reputation_value.text = str(rep.get("label", ""))
	reputation_arrow.text = Phase3Texts.arrow(forecast)
	reputation_arrow.theme_type_variation = &"GoodLabel" if forecast > 0 else (&"WarningLabel" if forecast < 0 else &"DimLabel")
	reputation_meter.value = int(rep.get("value", 0))
	var cfg := Database.config(&"reputation_config") as ReputationConfig
	reputation_meter.thresholds = cfg.tier_thresholds if cfg != null else ReputationConfig.new().tier_thresholds
	var pay := int(rep.get("pay_bonus", 0))
	reputation_rows[TEXT_PAY].text = "%s %s" % [UIKit.signed(pay), "Münze" if absi(pay) == 1 else "Münzen"]
	reputation_rows[TEXT_DELIVERY].text = TEXT_DELIVERY_ODD if bool(rep.get("every_other_day", false)) else TEXT_DELIVERY_DAILY
	reputation_rows[TEXT_STIPEND].text = TEXT_STIPEND_VALUE % int(rep.get("stipend", 0))
	reputation_rows[TEXT_TOMORROW].text = UIKit.signed(forecast)
	reputation_rows[TEXT_TOMORROW].theme_type_variation = &"GoodLabel" if forecast > 0 else (&"WarningLabel" if forecast < 0 else &"")
	var next := StringName(str(rep.get("next_tier", "")))
	reputation_next.text = TEXT_REP_NEXT % [ReputationRules.label(next), int(rep.get("next_at", 0))] if next != &"" else TEXT_TOP


func _refresh_care(dirt: Dictionary) -> void:
	var levels: Array = dirt.get("levels", [])
	if not bool(dirt.get("known", not levels.is_empty())) or levels.is_empty():
		care_levels.text = TEXT_NO_CARE
		care_penalty.text = ""
		return
	var parts := PackedStringArray()
	for i: int in mini(levels.size(), LEVEL_NAMES.size()):
		parts.append(TEXT_LEVEL % [int(levels[i]), LEVEL_NAMES[i]])
	care_levels.text = " · ".join(parts)
	var penalty := int(dirt.get("penalty", 0))
	care_penalty.text = TEXT_PENALTY % UIKit.signed(-penalty)
	care_penalty.theme_type_variation = &"WarningLabel" if penalty > 0 else &"DimLabel"


func _refresh_ghosts(ghosts: Dictionary) -> void:
	var heard := int(ghosts.get("heard", int(ghosts.get("content", 0)) + int(ghosts.get("calm", 0)) + int(ghosts.get("restless", 0))))
	if heard <= 0:
		ghosts_moods.text = TEXT_NO_GHOSTS
		ghosts_moods.theme_type_variation = &"DimLabel"
		ghosts_hint.text = ""
		ghosts_hint.visible = false
		return
	ghosts_moods.theme_type_variation = &""
	ghosts_moods.text = TEXT_MOODS % [int(ghosts.get("content", 0)), int(ghosts.get("calm", 0)), int(ghosts.get("restless", 0))]
	ghosts_hint.visible = true
	ghosts_hint.text = TEXT_HEARD % [heard, maxi(int(ghosts.get("eligible", heard)), heard)]
