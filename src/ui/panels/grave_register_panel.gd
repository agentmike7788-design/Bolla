class_name GraveRegisterPanel
extends UIPanel
## &"grave_register" – context {entries: Array[Dictionary], total: int, rating: StringName}
## (docs §11), entry {name, age, cause_label, day_buried, grave_id, quality, marker_label}.
## Read-only ledger page on the desk: a leather-bound parchment page with ruled lines,
## one line per burial (oldest first), blank ruled lines fill a short page, a long list
## scrolls (mouse wheel, ↑/↓, Bild↑/Bild↓). Footer: cemetery quality and its tier.

const TEXT_TITLE := "Grabregister des Friedhofs"
const TEXT_SUBTITLE_NONE := "Verzeichnis der Bestatteten · noch keine Einträge"
const TEXT_SUBTITLE_ONE := "Verzeichnis der Bestatteten · 1 Eintrag"
const TEXT_SUBTITLE := "Verzeichnis der Bestatteten · %d Einträge"
const TEXT_EMPTY := "Noch ist niemand in deiner Obhut bestattet."
const TEXT_FOOTER := "Friedhofsqualität %d · %s"
const TEXT_NAME_AGE := "%s (%d)"
const TEXT_QUALITY := "%d/%d"
const TEXT_GRAVE := "Nr. %d"
const TEXT_NONE := "–"
const TEXT_UNKNOWN := "Unbekannt"
## Column headings and widths (1920 × 1080 base); the name column takes the rest.
const COLUMNS: Array[String] = ["Tag", "Name (Alter)", "Todesursache", "Grab", "Grabzeichen", "Qualität"]
const COLUMN_WIDTHS: PackedFloat32Array = [70.0, 330.0, 300.0, 100.0, 200.0, 120.0]
const COLUMN_GAP := 16
const NAME_COLUMN := 1
const QUALITY_COLUMN := 5
## Below this share of the maximum a quality is written in dried red.
const LOW_QUALITY_RATIO := 0.35

@export var page_width: float = 1300.0
## Ruled lines per page (blank lines fill up; more entries scroll).
@export var page_rows: int = 8
@export var row_height: float = 50.0

var title_label: Label
var subtitle_label: Label
var footer_label: Label
var empty_label: Label
var close_button: Button
var scroll: ScrollContainer

var _rows: VBoxContainer
var _empty_row: PanelContainer
## Rendered entries in display order (for tests).
var _shown: Array[Dictionary] = []


func _build() -> void:
	theme_type_variation = &"LedgerPanel"
	var page := UIKit.panel(&"LedgerPagePanel")
	page.custom_minimum_size.x = page_width
	add_child(page)
	var box := UIKit.vbox(12)
	page.add_child(box)
	var head := UIKit.hbox(16)
	title_label = UIKit.label(TEXT_TITLE, &"LedgerTitleLabel")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"LedgerCloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	# Balances the close button so the title stays centred on the page.
	var balance := Control.new()
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(balance)
	head.move_child(balance, 0)
	head.add_child(close_x)
	box.add_child(head)
	balance.custom_minimum_size.x = close_x.get_combined_minimum_size().x
	subtitle_label = UIKit.label("", &"InkDimLabel")
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle_label)
	box.add_child(LedgerOrnament.new())
	var head_panel := UIKit.panel(&"LedgerHeadPanel")
	head_panel.add_child(_make_line(PackedStringArray(COLUMNS), true))
	head_panel.draw.connect(_draw_margin_rule.bind(head_panel))
	# Heading and ruled lines touch, so the margin rule runs through both.
	var table := UIKit.vbox(0)
	box.add_child(table)
	table.add_child(head_panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = row_height * page_rows
	scroll.get_v_scroll_bar().theme_type_variation = &"LedgerScrollBar"
	table.add_child(scroll)
	var scroll_box := UIKit.vbox(0)
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_box)
	scroll_box.draw.connect(_draw_margin_rule.bind(scroll_box))
	# Empty state: the message on the first ruled line of the page.
	_empty_row = UIKit.panel(&"LedgerRowPanel")
	_empty_row.custom_minimum_size.y = row_height
	empty_label = UIKit.label(TEXT_EMPTY, &"InkDimLabel")
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_row.add_child(empty_label)
	scroll_box.add_child(_empty_row)
	_rows = UIKit.vbox(0)
	scroll_box.add_child(_rows)
	box.add_child(LedgerOrnament.new())
	var bottom := UIKit.hbox(16)
	footer_label = UIKit.label("", &"InkHeaderLabel")
	footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(footer_label)
	close_button = UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	box.add_child(bottom)


func _refresh() -> void:
	_shown = sorted_entries(context.get("entries", []))
	UIKit.clear_children(_rows)
	for entry: Dictionary in _shown:
		_rows.add_child(_make_row(entry))
	var blank := page_rows - maxi(_shown.size(), 1 if _shown.is_empty() else 0)
	for i: int in maxi(blank, 0):
		_rows.add_child(_make_row({}))
	_empty_row.visible = _shown.is_empty()
	empty_label.visible = _shown.is_empty()
	match _shown.size():
		0:
			subtitle_label.text = TEXT_SUBTITLE_NONE
		1:
			subtitle_label.text = TEXT_SUBTITLE_ONE
		_:
			subtitle_label.text = TEXT_SUBTITLE % _shown.size()
	footer_label.text = TEXT_FOOTER % [int(context.get("total", 0)), DaySummaryPanel.rating_label(context.get("rating", &""))]
	scroll.scroll_vertical = 0


func _on_closed() -> void:
	_shown.clear()


## ↑/↓ scroll one line, Bild↑/Bild↓ one page (nothing else on the page takes them).
func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	var step := 0.0
	if event.is_action_pressed(&"ui_down", true):
		step = row_height
	elif event.is_action_pressed(&"ui_up", true):
		step = -row_height
	elif event.is_action_pressed(&"ui_page_down", true):
		step = row_height * (page_rows - 1)
	elif event.is_action_pressed(&"ui_page_up", true):
		step = -row_height * (page_rows - 1)
	if step != 0.0:
		scroll.scroll_vertical = int(scroll.scroll_vertical + step)
		get_viewport().set_input_as_handled()


## Entries in display order: by day_buried (oldest first), ties keep the given order.
static func sorted_entries(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	var indexed: Array = []
	var list: Array = raw
	for i: int in list.size():
		if list[i] is Dictionary:
			indexed.append([int((list[i] as Dictionary).get("day_buried", 0)), i, list[i]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	for item: Array in indexed:
		out.append(item[2])
	return out


## Cell texts of one entry, in COLUMNS order.
static func cells(entry: Dictionary) -> PackedStringArray:
	var name_text := str(entry.get("name", "")).strip_edges()
	if name_text == "":
		name_text = TEXT_UNKNOWN
	var age := int(entry.get("age", 0))
	if age > 0:
		name_text = TEXT_NAME_AGE % [name_text, age]
	var cause := str(entry.get("cause_label", "")).strip_edges()
	var marker := str(entry.get("marker_label", "")).strip_edges()
	return PackedStringArray([
		str(int(entry.get("day_buried", 0))),
		name_text,
		cause if cause != "" else TEXT_NONE,
		grave_label(str(entry.get("grave_id", ""))),
		marker if marker != "" else TEXT_NONE,
		TEXT_QUALITY % [int(entry.get("quality", 0)), _quality_max()],
	])


## "plot_03" → "Nr. 3"; ids without a trailing number pass through ("" → "–").
static func grave_label(grave_id: String) -> String:
	if grave_id == "":
		return TEXT_NONE
	var digits := ""
	var i := grave_id.length() - 1
	while i >= 0 and grave_id[i] >= "0" and grave_id[i] <= "9":
		digits = grave_id[i] + digits
		i -= 1
	return TEXT_GRAVE % digits.to_int() if digits != "" else grave_id


## Rendered entry lines ({} entries are not included; blank ruled lines are not counted).
func shown_entries() -> Array[Dictionary]:
	return _shown.duplicate()


## Cell texts of every rendered entry line.
func row_texts() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	for row: Node in _rows.get_children():
		if not row.has_meta(&"entry"):
			continue
		var texts := PackedStringArray()
		for cell: Node in row.get_child(0).get_children():
			texts.append((cell as Label).text)
		out.append(texts)
	return out


func _make_row(entry: Dictionary) -> PanelContainer:
	var row := UIKit.panel(&"LedgerRowPanel")
	row.custom_minimum_size.y = row_height
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if entry.is_empty():
		row.add_child(_make_line(PackedStringArray(["", "", "", "", "", ""]), false))
		return row
	var texts := cells(entry)
	var line := _make_line(texts, false)
	var quality := int(entry.get("quality", 0))
	if float(quality) < LOW_QUALITY_RATIO * float(_quality_max()):
		(line.get_child(QUALITY_COLUMN) as Label).theme_type_variation = &"LedgerWarnLabel"
	row.add_child(line)
	row.set_meta(&"entry", entry)
	row.tooltip_text = "%s · %s" % [texts[NAME_COLUMN], texts[2]]
	return row


func _make_line(texts: PackedStringArray, heading: bool) -> HBoxContainer:
	var line := UIKit.hbox(COLUMN_GAP)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in texts.size():
		var cell := UIKit.label(texts[i], &"LedgerHeadLabel" if heading else &"InkLabel")
		cell.custom_minimum_size.x = COLUMN_WIDTHS[i]
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cell.clip_text = true
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == NAME_COLUMN:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0 or i == QUALITY_COLUMN:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == QUALITY_COLUMN else HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(cell)
	return line


## Dried-red margin rule between the day and the name column (old ledger look).
func _draw_margin_rule(on: Control) -> void:
	var row_box := get_theme_stylebox(&"panel", &"LedgerRowPanel")
	var x := (row_box.get_margin(SIDE_LEFT) if row_box != null else 0.0) + COLUMN_WIDTHS[0] + COLUMN_GAP * 0.5
	var color := get_theme_color(&"margin", LedgerOrnament.THEME_TYPE)
	on.draw_line(Vector2(x, 0.0), Vector2(x, on.size.y), color, 2.0)


static func _quality_max() -> int:
	return maxi(_economy().quality_max, 1)
