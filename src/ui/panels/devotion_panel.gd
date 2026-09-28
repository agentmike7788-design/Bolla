class_name DevotionPanel
extends UIPanel
## &"devotion" – a devotion for one grave (docs/PHASE6_DESIGN.md §2.4, §3.6, §7): context {altar:
## ChapelAltar, inventory, player}. The graves of ChapelRites.eligible_devotions() with name,
## section, the ghost's mood as a word („unruhig" / „gleichmütig" / „zufrieden"), the light already
## burning („Licht brennt (Stufe 2)") and, for a robbed soul, „höchstens gleichmütig" with the hint
## „Mehr als Ruhe kann eine Kerze nicht geben." A toggle sorts „Unruhige zuerst"; [ / ]
## (journal_page_prev / _next) page. Choosing a grave and „Andacht halten (30 Min)" (dimmed with
## ChapelRites' reason) closes the panel and calls altar.request_devotion(grave_id).

const RITES_GROUP := &"chapel_rites"
const GRAVEYARD_GROUP := &"graveyard"
const MANAGER_GROUP := &"corpse_manager"
const ROWS_PER_PAGE := 7

@export var panel_width: float = 1320.0

var title_label: Label
var candles_label: Label
var list_box: VBoxContainer
var empty_label: Label
var page_label: Label
var sort_button: Button
var chosen_label: Label
var hint_label: Label
var reason_label: Label
var devotion_button: Button
## Rows as shown (Phase6Texts.devotion_rows, all pages).
var rows: Array[Dictionary] = []
var selected: String = ""
var restless_first: bool = true
var page: int = 0

var _inventory: Inventory


func _build() -> void:
	custom_minimum_size.x = panel_width
	var box := UIKit.vbox(14)
	add_child(box)
	var head := UIKit.hbox(18)
	title_label = UIKit.label(Phase6Texts.DEVOTION_TITLE, &"HeaderLabel")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	head.add_child(UIKit.icon(Database.icon(&"altar_candle"), 40.0))
	candles_label = UIKit.label("", &"SubheaderLabel")
	candles_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(candles_label)
	var close_x := UIKit.button(TEXT_CLOSE_X, &"CloseButton")
	close_x.tooltip_text = TEXT_CLOSE
	close_x.focus_mode = Control.FOCUS_NONE
	close_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_x.pressed.connect(request_close)
	head.add_child(close_x)
	box.add_child(head)
	var intro := UIKit.label(Phase6Texts.DEVOTION_INTRO, &"WhisperLabel", true)
	intro.custom_minimum_size.x = panel_width - 80.0
	box.add_child(intro)
	var tools := UIKit.hbox(16)
	sort_button = UIKit.button("")
	sort_button.pressed.connect(toggle_sort)
	tools.add_child(sort_button)
	tools.add_child(UIKit.spacer())
	page_label = UIKit.label("", &"DimLabel")
	page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(page_label)
	box.add_child(tools)
	list_box = UIKit.vbox(6)
	box.add_child(list_box)
	empty_label = UIKit.label(Phase6Texts.DEVOTION_EMPTY, &"DimLabel", true)
	box.add_child(empty_label)
	hint_label = UIKit.label(Phase6Texts.DEVOTION_ROBBED_HINT, &"WhisperLabel", true)
	box.add_child(hint_label)
	_make_action_row(box)
	box.add_child(UIKit.separator())
	var bottom := UIKit.hbox(16)
	chosen_label = UIKit.label("", &"SubheaderLabel")
	chosen_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(chosen_label)
	reason_label = UIKit.label("", &"WarningLabel")
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reason_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(reason_label)
	var close_button := UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	devotion_button = UIKit.button("", &"AccentButton")
	devotion_button.pressed.connect(_on_devotion_pressed)
	bottom.add_child(devotion_button)
	box.add_child(bottom)


func _on_opened() -> void:
	page = 0
	selected = ""
	_inventory = _player_inventory()
	if _inventory != null and not _inventory.changed.is_connected(refresh):
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree() or UIState.top() != panel_id:
		return
	if event.is_action_pressed(&"journal_page_prev"):
		turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"journal_page_next"):
		turn_page(1)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var rites := rites_node()
	var cfg := rites.get_config() if rites != null else ChapelRules._cfg(null)
	var entries: Array[Dictionary] = rites.eligible_devotions() if rites != null else []
	rows = Phase6Texts.devotion_rows(entries, robbed_by_grave(), rites.level() if rites != null else 0, cfg, restless_first)
	if selected == "" or find_row(selected).is_empty():
		selected = _first_open()
	page = clampi(page, 0, page_count() - 1)
	candles_label.text = Phase6Texts.DEVOTION_CANDLES % (_inventory.count(cfg.candle_item) if is_instance_valid(_inventory) else 0)
	sort_button.text = Phase6Texts.DEVOTION_SORT_ROWS if restless_first else Phase6Texts.DEVOTION_SORT_RESTLESS
	page_label.text = Phase6Texts.DEVOTION_PAGE % [page + 1, page_count()]
	page_label.visible = page_count() > 1
	UIKit.clear_children(list_box)
	for i: int in range(page * ROWS_PER_PAGE, mini(rows.size(), (page + 1) * ROWS_PER_PAGE)):
		list_box.add_child(_row(rows[i]))
	empty_label.visible = rows.is_empty()
	var row := find_row(selected)
	hint_label.visible = not row.is_empty() and bool(row.get("capped", false))
	chosen_label.text = Phase6Texts.DEVOTION_CHOSEN % str(row.get("name", "")) if not row.is_empty() else Phase6Texts.DEVOTION_PICK
	var reason := block_reason()
	devotion_button.text = Phase6Texts.DEVOTION_BUTTON % UIKit.minutes(cfg.devotion_minutes)
	devotion_button.disabled = reason != ""
	devotion_button.tooltip_text = reason
	reason_label.text = reason if reason != TEXT_BUSY and selected != "" else ""


## "" or why no devotion for the selected grave (ChapelRites) / TEXT_BUSY / nothing chosen.
func block_reason() -> String:
	if action_running:
		return TEXT_BUSY
	var rites := rites_node()
	if rites == null:
		return ChapelRules.TEXT_NO_CHAPEL
	if selected == "":
		return Phase6Texts.DEVOTION_PICK
	return rites.devotion_block_reason(selected, _inventory)


func select(grave_id: String) -> void:
	selected = grave_id
	refresh()


func toggle_sort() -> void:
	restless_first = not restless_first
	page = 0
	refresh()


func turn_page(delta: int) -> void:
	page = clampi(page + delta, 0, page_count() - 1)
	refresh()


func page_count() -> int:
	return maxi(1, ceili(float(rows.size()) / ROWS_PER_PAGE))


func find_row(grave_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("grave_id", "")) == grave_id:
			return row
	return {}


## {grave_id: robbed kinds} of the MARKED graves (GhostMood.robbed_count of the dead).
func robbed_by_grave() -> Dictionary:
	var out := {}
	if not is_inside_tree():
		return out
	var graveyard := get_tree().get_first_node_in_group(GRAVEYARD_GROUP) as Graveyard
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager
	if graveyard == null or manager == null:
		return out
	for grave: GraveRecord in graveyard.graves():
		if grave.state == GraveRecord.State.MARKED and grave.corpse_id != "":
			var n := GhostMood.robbed_count(manager.get_record(grave.corpse_id))
			if n > 0:
				out[grave.id] = n
	return out


func rites_node() -> ChapelRites:
	return get_tree().get_first_node_in_group(RITES_GROUP) as ChapelRites if is_inside_tree() else null


## The first grave (shown order) that can get a devotion now, else the first one.
func _first_open() -> String:
	for row: Dictionary in rows:
		if str(row.get("block_reason", "")) == "":
			return str(row.grave_id)
	return str(rows[0].grave_id) if not rows.is_empty() else ""


func _row(row: Dictionary) -> Control:
	var grave_id := str(row.grave_id)
	var chosen := grave_id == selected
	var b := UIKit.button("", &"JournalCardSelected" if chosen else &"SlotButton")
	b.custom_minimum_size = Vector2(panel_width - 80.0, 58.0)
	b.toggle_mode = false
	b.pressed.connect(select.bind(grave_id))
	var line := UIKit.hbox(18)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 18.0
	line.offset_right = -18.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := UIKit.label(str(row.get("name", "")), &"SubheaderLabel")
	name.custom_minimum_size.x = 330.0
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name)
	var section := UIKit.label(str(row.get("section", "")), &"DimLabel")
	section.custom_minimum_size.x = 200.0
	section.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(section)
	var mood := StringName(str(row.get("mood", "")))
	var mood_label := UIKit.label(str(row.mood_word), &"WarningLabel" if mood == &"restless" else (&"GoodLabel" if mood == &"content" else &""))
	mood_label.custom_minimum_size.x = 170.0
	mood_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(mood_label)
	var cap := UIKit.label(Phase6Texts.DEVOTION_ROBBED if bool(row.capped) else "", &"AccentLabel")
	cap.custom_minimum_size.x = 230.0
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(cap)
	var lit := UIKit.label(str(row.lit_text), &"GoodLabel" if int(row.get("held_level", 0)) > 0 else &"DimLabel")
	lit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lit)
	b.add_child(line)
	b.tooltip_text = str(row.get("block_reason", "")) if str(row.get("block_reason", "")) != "" else str(row.get("bonus_text", ""))
	b.set_meta(&"grave_id", grave_id)
	return b


func _on_devotion_pressed() -> void:
	if block_reason() != "":
		return
	var altar: Variant = context.get("altar")
	if not is_instance_valid(altar) or not (altar as Object).has_method(&"request_devotion"):
		push_warning("[DevotionPanel] altar has no request_devotion()")
		return
	var grave_id := selected
	request_close()
	(altar as Object).call(&"request_devotion", grave_id)
