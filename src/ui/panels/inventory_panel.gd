class_name InventoryPanel
extends UIPanel
## &"inventory" – context {inventory: Inventory}. Slot grid with icons, counts and
## tooltips (name + description), coins (outside the slots) and the reputation label.
## Phase 5 (docs/PHASE5_DESIGN.md §2.3, §7): 20 slots as 5 × 4; above them the tool belt
## (Inventory.tools(), not in get_slots): shovel / axe / pickaxe with the tier name (tier 0 as
## „Alte Schaufel", pale), tier pips and a tooltip with the effect („Graben dauert 35 statt 60
## Minuten."), then the care and harvest tools (rake, brush, comb, shears, pliers).

const TEXT_TITLE := "Inventar"
const TEXT_COINS := "Münzen"
const TEXT_REPUTATION := "Ruf"
## Tier + trend arrow (Phase 3 §7), no raw value.
const TEXT_REPUTATION_VALUE := "%s %s"
const TEXT_HINT := "[I] oder [Esc] schließen"
const TOOLTIP_FORMAT := "%s\n%s"
const COIN_ITEM := &"coin"
const GRID_COLUMNS := 4
## From this many slots on the grid has 5 columns (20 = 5 × 4).
const WIDE_FROM := 20
const WIDE_COLUMNS := 5
const PIP_ON := "●"
const PIP_OFF := "○"
const DEFAULT_SLOTS := 16

@export var slot_edge: float = 104.0
@export var icon_edge: float = 72.0
@export var belt_cell_width: float = 184.0
## W3 (G5 QA): the tier tools' effect shows in this fixed line under the belt instead of a floating
## tooltip (that covered the care-tool row); 3 lines at the panel width.
@export var belt_info_height: float = 72.0

var _grid: GridContainer
var _coins: Label
var _reputation: Label
var _inventory: Inventory
var _belt: HBoxContainer
var _belt_other: HBoxContainer
var _belt_box: VBoxContainer
var _belt_info: Label
## tool kind -> its belt cell (tier tools) · item id -> cell (other tools)
var belt_cells: Dictionary[StringName, Control] = {}


func _build() -> void:
	var box := UIKit.vbox(16)
	add_child(box)
	_make_header(box, TEXT_TITLE)
	_belt_box = UIKit.vbox(6)
	_belt_box.add_child(UIKit.label(Phase5Texts.BELT_TITLE, &"AccentLabel"))
	_belt = UIKit.hbox(8)
	_belt_box.add_child(_belt)
	_belt_other = UIKit.hbox(8)
	_belt_box.add_child(_belt_other)
	_belt_info = UIKit.label(Phase5Texts.BELT_HINT, &"DimLabel", true)
	_belt_info.custom_minimum_size = Vector2(0.0, belt_info_height)
	_belt_info.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_belt_info.add_theme_font_size_override(&"font_size", 18)
	_belt_box.add_child(_belt_info)
	box.add_child(_belt_box)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	box.add_child(_grid)
	box.add_child(UIKit.separator())
	var coins := UIKit.hbox(10)
	coins.add_child(UIKit.icon(Database.icon(COIN_ITEM), 34.0))
	coins.add_child(UIKit.label(TEXT_COINS, &"DimLabel"))
	_coins = UIKit.label("0", &"SubheaderLabel")
	coins.add_child(_coins)
	coins.add_child(UIKit.spacer())
	coins.add_child(UIKit.label(TEXT_REPUTATION, &"DimLabel"))
	_reputation = UIKit.label("", &"SubheaderLabel")
	_reputation.mouse_filter = Control.MOUSE_FILTER_STOP
	coins.add_child(_reputation)
	box.add_child(coins)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _on_opened() -> void:
	var inv: Variant = context.get("inventory")
	_inventory = inv if is_instance_valid(inv) and inv is Inventory else null
	if _inventory != null:
		_inventory.changed.connect(refresh)


func _on_closed() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	_inventory = null


func _refresh() -> void:
	UIKit.clear_children(_grid)
	var slots: Array[Dictionary] = []
	if is_instance_valid(_inventory):
		slots = _inventory.get_slots()
	var total := maxi(slots.size(), _inventory.slot_count if is_instance_valid(_inventory) else DEFAULT_SLOTS)
	_grid.columns = WIDE_COLUMNS if total >= WIDE_FROM else GRID_COLUMNS
	_refresh_belt()
	for i: int in total:
		_grid.add_child(_make_slot(slots[i] if i < slots.size() else {}))
	_coins.text = str(_inventory.count(COIN_ITEM) if is_instance_valid(_inventory) else 0)
	var rep := CemeteryStatus.reputation(get_tree() if is_inside_tree() else null)
	_reputation.text = TEXT_REPUTATION_VALUE % [str(rep.label), Phase3Texts.arrow(int(rep.forecast))]
	_reputation.tooltip_text = Phase3Texts.reputation_tooltip(rep)


## Items shown in the grid, in slot order ({id, amount}).
func shown_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: Node in _grid.get_children():
		if slot.is_queued_for_deletion():
			continue
		if slot.has_meta(&"item_id"):
			out.append({"id": slot.get_meta(&"item_id"), "amount": slot.get_meta(&"amount")})
		else:
			out.append({})
	return out


## Belt cells: {kind_or_id: {name, tier, tooltip}} – tests.
func belt_entries() -> Dictionary:
	var out := {}
	for key: StringName in belt_cells:
		var cell := belt_cells[key]
		out[key] = {"name": cell.get_meta(&"name", ""), "tier": cell.get_meta(&"tier", 0),
				"tooltip": cell.get_meta(&"info", cell.tooltip_text)}
	return out


func _refresh_belt() -> void:
	UIKit.clear_children(_belt)
	UIKit.clear_children(_belt_other)
	belt_cells.clear()
	show_belt_info("")
	var on_belt := is_instance_valid(_inventory) and _inventory.tool_belt
	_belt_box.visible = on_belt
	if not on_belt:
		return
	var tools := Database.config(&"tool_config") as ToolConfig
	if tools == null:
		tools = ToolConfig.new()
	var actions := _action_config()
	var tiered := {}
	for kind: StringName in tools.kinds:
		var tier := ToolRules.tier(_inventory, kind)
		var name := ToolRules.tool_name(kind, tier, tools)
		var icon_id := &""
		for id: StringName in _inventory.tools():
			var item := Database.item(id) as ItemData if Database.has_item(id) else null
			if item != null and item.tool_kind == kind:
				tiered[id] = true
				if item.tool_tier == tier:
					icon_id = id
		var pale := icon_id == &""
		if pale:
			icon_id = _tool_item_id(kind, 1)
		var cell := _belt_cell(icon_id, pale, name if name != "" else "%s: %s" % [tools.labels.get(kind, String(kind)), Phase5Texts.BELT_NO_TOOL],
				tier, Phase5Texts.belt_tooltip(kind, tier, actions, tools), true)
		cell.set_meta(&"tier", tier)
		_belt.add_child(cell)
		belt_cells[kind] = cell
	for id: StringName in _inventory.tools():
		if tiered.has(id):
			continue
		var cell := _belt_cell(id, false, UIKit.item_name(id), -1, TOOLTIP_FORMAT % [UIKit.item_name(id), UIKit.item_description(id)], false)
		_belt_other.add_child(cell)
		belt_cells[id] = cell


## One belt cell. Tier tools: icon, name and tier pips side by side (a pale icon for „Altes Beil" /
## no pickaxe); the care and harvest tools: a small icon cell, the name in the tooltip.
func _belt_cell(icon_id: StringName, pale: bool, name: String, tier: int, tooltip: String, tiered: bool) -> Control:
	var cell := UIKit.panel(&"SlotPanel")
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = tooltip
	cell.set_meta(&"name", name)
	var icon := UIKit.icon(Database.icon(icon_id) if icon_id != &"" else null, 34.0 if tiered else 46.0)
	icon.modulate = Color(1, 1, 1, 0.3) if pale else Color(1, 1, 1, 1)
	if not tiered:
		cell.custom_minimum_size = Vector2(62.0, 62.0)
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
		cell.add_child(center)
		return cell
	# The effect goes into the info line under the belt (no floating tooltip over the care tools).
	cell.tooltip_text = ""
	cell.set_meta(&"info", tooltip)
	cell.mouse_entered.connect(show_belt_info.bind(tooltip))
	cell.mouse_exited.connect(show_belt_info.bind(""))
	cell.custom_minimum_size = Vector2(belt_cell_width, 72.0)
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts := UIKit.vbox(0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := UIKit.label(name, &"DimLabel" if tier <= 0 else &"")
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = belt_cell_width - 52.0
	label.add_theme_font_size_override(&"font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(label)
	var pips := UIKit.label("%s  %s" % [PIP_ON.repeat(maxi(tier, 0)) + PIP_OFF.repeat(maxi(2 - tier, 0)), Phase5Texts.BELT_TIER % tier],
			&"AccentLabel" if tier > 0 else &"DimLabel")
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(pips)
	row.add_child(texts)
	cell.add_child(row)
	return cell


## The info line under the belt: a tier tool's effect while hovered (lines joined), else the hint.
func show_belt_info(text: String) -> void:
	if _belt_info == null:
		return
	_belt_info.text = Phase5Texts.BELT_HINT if text == "" else " · ".join(text.split("\n"))


## The info line's text (tests, screenshot director).
func belt_info_text() -> String:
	return _belt_info.text if _belt_info != null else ""


## Item id of the `kind` tool at `tier` (Database), &"" if none.
static func _tool_item_id(kind: StringName, tier: int) -> StringName:
	for res: Resource in Database.items():
		var item := res as ItemData
		if item != null and item.tool_kind == kind and item.tool_tier == tier:
			return item.id
	return &""


func coins_text() -> String:
	return _coins.text


func reputation_text() -> String:
	return _reputation.text


func _make_slot(slot: Dictionary) -> Control:
	var cell := UIKit.panel(&"SlotPanel")
	cell.custom_minimum_size = Vector2(slot_edge, slot_edge)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	if slot.is_empty():
		return cell
	var id := StringName(slot.get("id", &""))
	var amount := int(slot.get("amount", 0))
	cell.set_meta(&"item_id", id)
	cell.set_meta(&"amount", amount)
	cell.tooltip_text = TOOLTIP_FORMAT % [UIKit.item_name(id), UIKit.item_description(id)]
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(UIKit.icon(Database.icon(id), icon_edge))
	cell.add_child(center)
	var count := UIKit.label(str(amount), &"CountLabel")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cell.add_child(count)
	return cell
