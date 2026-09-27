class_name BuildBar
extends PanelContainer
## Build bar of the HUD (docs/PHASE3_DESIGN.md §7, §14.3) – only while BuildMode is active,
## bottom centre in place of the interaction prompt. Top: status line (why the cursor cell is
## invalid, or what a click does) and the decor of the cursor's section („Ostwiese: Zier 6/9");
## middle: up to 8 slots (icon, count, „Zier +3", key number; the selected one framed in amber;
## a click selects it); bottom: the key help for mouse + keyboard. GameHud calls sync() a few
## times per second while the bar is shown; the bar only reads BuildMode / DecorationManager.

const MAX_SLOTS := BuildMode.HOTBAR_SLOTS
const STYLE_SLOT := &"BuildSlotButton"
const STYLE_SELECTED := &"BuildSlotSelected"
const TEXT_COUNT := "×%d"
const TEXT_FREE := "∞"

@export var slot_size: Vector2 = Vector2(112.0, 124.0)
@export var slot_icon_edge: float = 60.0

var status_label: Label
var section_label: Label
var help_label: Label
var empty_label: Label
var slot_row: HBoxContainer
## One entry per slot: {button: Button, icon: TextureRect, count: Label, zier: Label, key: Label}
var slots: Array[Dictionary] = []

## Decor id per visible slot (build-bar order = BuildMode.available()).
var _ids: Array[StringName] = []
var _mode: BuildMode


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visible = false
	var box := UIKit.vbox(8)
	add_child(box)
	var top := UIKit.hbox(24)
	status_label = UIKit.label("", &"GoodLabel")
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status_label)
	section_label = UIKit.label("", &"HudDimLabel")
	section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(section_label)
	box.add_child(top)
	slot_row = UIKit.hbox(8)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(slot_row)
	for i: int in MAX_SLOTS:
		slots.append(_make_slot(i))
	empty_label = UIKit.label(Phase3Texts.TEXT_EMPTY_BAR, &"HudLabel")
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.visible = false
	box.add_child(empty_label)
	help_label = UIKit.label(Phase3Texts.BUILD_HELP, &"HudCaptionLabel")
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help_label)


## Pulls everything from `mode` (null = hide the slots).
func sync(mode: BuildMode) -> void:
	_mode = mode
	var decorations := _decorations(mode)
	_ids = mode.available() if mode != null else ([] as Array[StringName])
	if _ids.size() > MAX_SLOTS:
		_ids.resize(MAX_SLOTS)
	var inv := _inventory(mode)
	for i: int in MAX_SLOTS:
		var slot := slots[i]
		var button: Button = slot.button
		button.visible = i < _ids.size()
		if not button.visible:
			continue
		var id := _ids[i]
		var data := decorations.decor(id) if decorations != null else null
		(slot.icon as TextureRect).texture = Database.icon(id)
		var free := decorations != null and decorations.free_build
		(slot.count as Label).text = TEXT_FREE if free else TEXT_COUNT % (inv.count(id) if inv != null else 0)
		(slot.zier as Label).text = Phase3Texts.zier_text(data)
		button.tooltip_text = Phase3Texts.decor_tooltip(data) if data != null else UIKit.item_name(id)
		button.theme_type_variation = STYLE_SELECTED if mode != null and id == mode.selected else STYLE_SLOT
	empty_label.visible = _ids.is_empty()
	slot_row.visible = not _ids.is_empty()
	_sync_status(mode, decorations)


# --- accessors (tests) ----------------------------------------------------------------------

func status_text() -> String:
	return status_label.text


func status_is_warning() -> bool:
	return status_label.theme_type_variation == &"WarningLabel"


func section_text() -> String:
	return section_label.text if section_label.visible else ""


func slot_ids() -> Array[StringName]:
	return _ids.duplicate()


func selected_slot() -> int:
	for i: int in _ids.size():
		if (slots[i].button as Button).theme_type_variation == STYLE_SELECTED:
			return i
	return -1


func slot_count_text(index: int) -> String:
	return (slots[index].count as Label).text if index < _ids.size() else ""


func slot_zier_text(index: int) -> String:
	return (slots[index].zier as Label).text if index < _ids.size() else ""


func slot_tooltip(index: int) -> String:
	return (slots[index].button as Button).tooltip_text if index < _ids.size() else ""


## Same as a mouse click on slot `index`.
func click_slot(index: int) -> void:
	_on_slot_pressed(index)


# --- internals ------------------------------------------------------------------------------

func _make_slot(index: int) -> Dictionary:
	var button := Button.new()
	button.theme_type_variation = STYLE_SLOT
	button.custom_minimum_size = slot_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_on_slot_pressed.bind(index))
	var column := UIKit.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 4.0
	column.offset_bottom = -4.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := UIKit.icon(null, slot_icon_edge)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var zier := UIKit.label("", &"HudCaptionLabel")
	zier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(zier)
	button.add_child(column)
	var key := UIKit.label(str(index + 1), &"HudCaptionLabel")
	key.position = Vector2(8.0, 2.0)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(key)
	var count := UIKit.label("", &"CountLabel")
	count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.offset_left = -60.0
	count.offset_right = -8.0
	count.offset_top = 2.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	button.visible = false
	slot_row.add_child(button)
	return {"button": button, "icon": icon, "count": count, "zier": zier, "key": key}


func _sync_status(mode: BuildMode, decorations: DecorationManager) -> void:
	if mode == null or decorations == null:
		status_label.text = ""
		section_label.visible = false
		return
	var data := decorations.decor(mode.selected) if mode.selected != &"" else null
	var reason := mode.cursor_reason()
	var focused := mode.focused_placement()
	var text := ""
	var warning := false
	if reason == BuildGrid.REASON_OK and data != null:
		text = Phase3Texts.TEXT_VALID % [data.display_name, UIKit.minutes(_place_minutes(mode))]
	elif focused != null and (reason == BuildGrid.REASON_OCCUPIED or data == null):
		var fd := decorations.decor(focused.decor_id)
		text = Phase3Texts.TEXT_REMOVE_HINT % (fd.display_name if fd != null else String(focused.decor_id))
	elif data != null or not _ids.is_empty():
		text = Phase3Texts.reason_text(reason, data, _max_placed(mode))
		warning = true
	status_label.text = text
	status_label.theme_type_variation = &"WarningLabel" if warning else &"GoodLabel"
	var section := _cursor_section(mode, decorations)
	section_label.text = Phase3Texts.section_decor_text(section)
	section_label.visible = section_label.text != ""


## CemeteryStatus.sections() entry of the section under the cursor ({} = none / not buildable).
func _cursor_section(mode: BuildMode, decorations: DecorationManager) -> Dictionary:
	if decorations.mask == null:
		return {}
	var order := decorations.mask.section_at(mode.cursor_cell())
	if order <= 0:
		return {}
	var by := decorations.score_by_section()
	var entry: Dictionary = by.get(order, {})
	var name := ""
	var list: Array = decorations.section_list if not decorations.section_list.is_empty() else Database.sections()
	for s: Variant in list:
		var sd := s as SectionData
		if sd != null and sd.order == order:
			name = sd.display_name
	if name == "":
		return {}
	return {"name": name, "decor": int(entry.get("capped", 0)), "decor_cap": int(entry.get("cap", 0))}


func _on_slot_pressed(index: int) -> void:
	if _mode != null and index < _ids.size():
		_mode.select(_ids[index])
		sync(_mode)


## BuildMode's overrides first, else the world groups (as BuildMode resolves them).
static func _decorations(mode: BuildMode) -> DecorationManager:
	if mode == null:
		return null
	if is_instance_valid(mode.decorations):
		return mode.decorations
	return mode.get_tree().get_first_node_in_group(DecorationManager.GROUP) as DecorationManager if mode.is_inside_tree() else null


static func _inventory(mode: BuildMode) -> Inventory:
	if mode == null:
		return null
	var p: Player = mode.player if is_instance_valid(mode.player) else null
	if p == null and mode.is_inside_tree():
		p = mode.get_tree().get_first_node_in_group(&"player") as Player
	return p.inventory if p != null else null


static func _config(mode: BuildMode) -> DecorConfig:
	return mode.config if mode != null and mode.config != null else DecorConfig.new()


static func _place_minutes(mode: BuildMode) -> int:
	return _config(mode).place_minutes


static func _max_placed(mode: BuildMode) -> int:
	return _config(mode).max_placed
