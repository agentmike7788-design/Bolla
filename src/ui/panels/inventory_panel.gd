class_name InventoryPanel
extends UIPanel
## &"inventory" – context {inventory: Inventory}. Slot grid with icons, counts and
## tooltips (name + description), coins (outside the slots) and the reputation label.

const TEXT_TITLE := "Inventar"
const TEXT_COINS := "Münzen"
const TEXT_REPUTATION := "Ruf"
const TEXT_REPUTATION_VALUE := "%s (%s)"
const TEXT_HINT := "[I] oder [Esc] schließen"
const TOOLTIP_FORMAT := "%s\n%s"
const COIN_ITEM := &"coin"
const GRID_COLUMNS := 4
const DEFAULT_SLOTS := 16

@export var slot_edge: float = 104.0
@export var icon_edge: float = 72.0

var _grid: GridContainer
var _coins: Label
var _reputation: Label
var _inventory: Inventory


func _build() -> void:
	var box := UIKit.vbox(16)
	add_child(box)
	_make_header(box, TEXT_TITLE)
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
	for i: int in total:
		_grid.add_child(_make_slot(slots[i] if i < slots.size() else {}))
	_coins.text = str(_inventory.count(COIN_ITEM) if is_instance_valid(_inventory) else 0)
	_reputation.text = TEXT_REPUTATION_VALUE % [GameState.reputation_label(), UIKit.signed(GameState.get_stat(&"reputation"))]


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
