class_name ChestPanel
extends UIPanel
## &"chest" – context {storage: Inventory, inventory: Inventory, chest: Node} (docs §11).
## Two slot grids side by side: "Truhe" (storage) and "Tasche" (the player's inventory).
## Click on a slot moves its whole stack to the other side, Shift+click a single item;
## "Alles nehmen" / "Alles einlagern" move everything that fits. Every move goes through
## ChestTransfer (atomic, only what fits moves, nothing is lost). Coins stay with the
## player and are only shown in the bag header. Refreshes on both inventories' `changed`.

const SIDE_CHEST := &"chest"
const SIDE_BAG := &"bag"
const TEXT_TITLE := "Truhe"
const TEXT_CHEST := "Truhe"
const TEXT_BAG := "Tasche"
const TEXT_USED := "%d / %d belegt"
const TEXT_TAKE_ALL := "Alles nehmen"
const TEXT_STORE_ALL := "Alles einlagern"
const TEXT_HINT := "Klick: Stapel verschieben · Umschalt+Klick: ein Stück · [Esc] schließen"
const TEXT_CHEST_FULL := "In der Truhe ist kein Platz mehr."
const TEXT_BAG_FULL := "In der Tasche ist kein Platz mehr."
const TOOLTIP_FORMAT := "%s\n%s"
const COIN_ITEM := &"coin"
const GRID_COLUMNS := 4
const DEFAULT_SLOTS := 16
const NOTE_WARNING := &"warning"

@export var slot_edge: float = 104.0
@export var icon_edge: float = 72.0

var take_all_button: Button
var store_all_button: Button

var _storage: Inventory
var _bag: Inventory
var _chest_grid: GridContainer
var _bag_grid: GridContainer
var _used_label: Label
var _coins: Label
## side -> slot buttons in slot order.
var _buttons: Dictionary[StringName, Array] = {SIDE_CHEST: [], SIDE_BAG: []}
## True while a bulk move runs: `changed` refreshes are folded into one at the end.
var _bulk: bool = false


func _build() -> void:
	var box := UIKit.vbox(16)
	add_child(box)
	_make_header(box, TEXT_TITLE)
	var columns := UIKit.hbox(24)
	box.add_child(columns)
	# Chest side.
	var chest_box := _make_side(columns)
	var chest_head := UIKit.hbox(10)
	chest_head.add_child(UIKit.label(TEXT_CHEST, &"SubheaderLabel"))
	chest_head.add_child(UIKit.spacer())
	_used_label = UIKit.label("", &"DimLabel")
	chest_head.add_child(_used_label)
	chest_box.add_child(chest_head)
	_chest_grid = _make_grid(chest_box)
	take_all_button = UIKit.button(TEXT_TAKE_ALL)
	take_all_button.pressed.connect(take_all)
	chest_box.add_child(take_all_button)
	# Bag side.
	var bag_box := _make_side(columns)
	var bag_head := UIKit.hbox(10)
	bag_head.add_child(UIKit.label(TEXT_BAG, &"SubheaderLabel"))
	bag_head.add_child(UIKit.spacer())
	bag_head.add_child(UIKit.icon(Database.icon(COIN_ITEM), 30.0))
	_coins = UIKit.label("0", &"SubheaderLabel")
	bag_head.add_child(_coins)
	bag_box.add_child(bag_head)
	_bag_grid = _make_grid(bag_box)
	store_all_button = UIKit.button(TEXT_STORE_ALL, &"AccentButton")
	store_all_button.pressed.connect(store_all)
	bag_box.add_child(store_all_button)
	var bottom := UIKit.hbox(16)
	var hint := UIKit.label(TEXT_HINT, &"DimLabel")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(hint)
	var close_button := UIKit.button(TEXT_CLOSE)
	close_button.pressed.connect(request_close)
	bottom.add_child(close_button)
	box.add_child(bottom)


func _on_opened() -> void:
	_storage = _inventory_from(&"storage")
	_bag = _player_inventory()
	for inv: Inventory in [_storage, _bag]:
		if inv != null and not inv.changed.is_connected(_on_inventory_changed):
			inv.changed.connect(_on_inventory_changed)


func _on_closed() -> void:
	for inv: Inventory in [_storage, _bag]:
		if is_instance_valid(inv) and inv.changed.is_connected(_on_inventory_changed):
			inv.changed.disconnect(_on_inventory_changed)
	_storage = null
	_bag = null
	_bulk = false


func _refresh() -> void:
	_fill(SIDE_CHEST, _chest_grid, _storage)
	_fill(SIDE_BAG, _bag_grid, _bag)
	var used := 0
	for slot: Dictionary in shown_slots(SIDE_CHEST):
		if not slot.is_empty():
			used += 1
	_used_label.text = TEXT_USED % [used, _buttons[SIDE_CHEST].size()]
	_coins.text = str(_bag.count(COIN_ITEM) if is_instance_valid(_bag) else 0)
	take_all_button.disabled = not ChestTransfer.can_move_any(_storage, _bag)
	store_all_button.disabled = not ChestTransfer.can_move_any(_bag, _storage)


## Keyboard focus: first filled bag slot, else first filled chest slot, else the first slot.
func focus_default() -> void:
	if not is_visible_in_tree():
		return
	for side: StringName in [SIDE_BAG, SIDE_CHEST]:
		var slots := shown_slots(side)
		for i: int in slots.size():
			if not slots[i].is_empty():
				slot_button(side, i).grab_focus()
				return
	var first := slot_button(SIDE_CHEST, 0)
	if first != null:
		first.grab_focus()
	else:
		super.focus_default()


# --- actions ------------------------------------------------------------------------------

## Moves the stack of slot `index` on `side` to the other side (`one` = a single item).
## Returns how many items moved; a warning note tells when nothing fitted.
func click_slot(side: StringName, index: int, one: bool = false) -> int:
	var from := _inventory_of(side)
	var to := _inventory_of(_other(side))
	if not is_instance_valid(from) or not is_instance_valid(to):
		return 0
	var slot := ChestTransfer.slot_at(from, index)
	if slot.is_empty() or not ChestTransfer.is_transferable(StringName(slot.get("id", &""))):
		return 0
	var moved := ChestTransfer.move_slot(from, to, index, one)
	if moved == 0:
		EventBus.notification_requested.emit(TEXT_CHEST_FULL if side == SIDE_BAG else TEXT_BAG_FULL, NOTE_WARNING)
	return moved


## "Alles nehmen": chest → bag, whatever fits. Returns how many items moved.
func take_all() -> int:
	return _bulk_move(_storage, _bag, TEXT_BAG_FULL)


## "Alles einlagern": bag → chest, whatever fits (coins stay). Returns how many moved.
func store_all() -> int:
	return _bulk_move(_bag, _storage, TEXT_CHEST_FULL)


# --- queries (tests, screenshots) --------------------------------------------------------

## Items shown on `side`, in slot order ({id, amount} or {}).
func shown_slots(side: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Button in _buttons.get(side, []):
		if b.has_meta(&"item_id"):
			out.append({"id": b.get_meta(&"item_id"), "amount": b.get_meta(&"amount")})
		else:
			out.append({})
	return out


func slot_button(side: StringName, index: int) -> Button:
	var list: Array = _buttons.get(side, [])
	return list[index] as Button if index >= 0 and index < list.size() else null


func coins_text() -> String:
	return _coins.text


func used_text() -> String:
	return _used_label.text


# --- internals ----------------------------------------------------------------------------

func _make_side(parent: Container) -> VBoxContainer:
	var section := UIKit.panel(&"SectionPanel")
	parent.add_child(section)
	var box := UIKit.vbox(14)
	section.add_child(box)
	return box


func _make_grid(parent: Container) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	parent.add_child(grid)
	return grid


## Shows `inv` on `side`; slot buttons are created once per slot count and then only
## updated, so keyboard focus survives every refresh.
func _fill(side: StringName, grid: GridContainer, inv: Inventory) -> void:
	var slots: Array[Dictionary] = []
	if is_instance_valid(inv):
		slots = inv.get_slots()
	var total := maxi(slots.size(), inv.slot_count if is_instance_valid(inv) else DEFAULT_SLOTS)
	var list: Array = _buttons[side]
	if list.size() != total:
		UIKit.clear_children(grid)
		list.clear()
		for i: int in total:
			var b := _make_slot_button(side, i)
			grid.add_child(b)
			list.append(b)
	for i: int in total:
		_show_slot(list[i] as Button, slots[i] if i < slots.size() else {})


func _make_slot_button(side: StringName, index: int) -> Button:
	var b := UIKit.button("", &"SlotButton")
	b.custom_minimum_size = Vector2(slot_edge, slot_edge)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UIKit.icon(null, icon_edge)
	icon.name = "Icon"
	center.add_child(icon)
	b.add_child(center)
	var count := UIKit.label("", &"CountLabel")
	count.name = "Count"
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -8.0
	count.offset_bottom = -4.0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	b.pressed.connect(_on_slot_pressed.bind(side, index))
	b.gui_input.connect(_on_slot_gui_input.bind(b, side, index))
	return b


func _show_slot(b: Button, slot: Dictionary) -> void:
	var icon := b.get_node(^"Center/Icon") as TextureRect
	var count := b.get_node(^"Count") as Label
	if slot.is_empty():
		b.remove_meta(&"item_id")
		b.remove_meta(&"amount")
		b.tooltip_text = ""
		icon.texture = null
		count.text = ""
		return
	var id := StringName(slot.get("id", &""))
	var amount := int(slot.get("amount", 0))
	b.set_meta(&"item_id", id)
	b.set_meta(&"amount", amount)
	b.tooltip_text = TOOLTIP_FORMAT % [UIKit.item_name(id), UIKit.item_description(id)]
	icon.texture = Database.icon(id)
	count.text = str(amount)


func _bulk_move(from: Inventory, to: Inventory, full_text: String) -> int:
	if not ChestTransfer.can_move_any(from, to):
		return 0
	_bulk = true
	var moved := ChestTransfer.move_all(from, to)
	_bulk = false
	refresh()
	if not ChestTransfer.item_ids(from).is_empty():
		# Something stayed behind: the other side is full.
		EventBus.notification_requested.emit(full_text, NOTE_WARNING)
	return moved


func _inventory_of(side: StringName) -> Inventory:
	return _storage if side == SIDE_CHEST else _bag


func _other(side: StringName) -> StringName:
	return SIDE_BAG if side == SIDE_CHEST else SIDE_CHEST


func _inventory_from(key: StringName) -> Inventory:
	var inv: Variant = context.get(key)
	return inv if is_instance_valid(inv) and inv is Inventory else null


func _on_inventory_changed() -> void:
	if not _bulk:
		refresh()


## Keyboard / plain mouse press: the whole stack, Shift held = a single item.
func _on_slot_pressed(side: StringName, index: int) -> void:
	click_slot(side, index, Input.is_key_pressed(KEY_SHIFT))


## Shift + left click moves a single item (handled here so `pressed` does not fire too).
func _on_slot_gui_input(event: InputEvent, b: Button, side: StringName, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or not mb.shift_pressed:
		return
	b.accept_event()
	b.grab_focus()
	click_slot(side, index, true)
