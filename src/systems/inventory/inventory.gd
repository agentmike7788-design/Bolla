class_name Inventory
extends Node
## Slot inventory (child "Inventory" of the player). CURRENCY items have no slot.
## Item rules (max_stack, category) come from Database.item(id) as ItemData.
## Adding fills existing stacks first, then empty slots in index order; removing is
## all-or-nothing and takes from the last stacks first. `changed` fires exactly once
## per call that actually changed the contents (never for no-ops or refusals).

signal changed

## Changing it keeps the contents: slots beyond the new count are repacked into free space.
@export var slot_count: int = 16:
	set = _set_slot_count

## slot_count entries: {} (empty) or {"id": StringName, "amount": int} with 1 <= amount <= max_stack.
var _slots: Array[Dictionary] = []
## CURRENCY items held outside the slots: StringName -> int (> 0, no stack limit).
var _currency: Dictionary[StringName, int] = {}


func _init() -> void:
	_slots = _empty_slots(slot_count)


## Returns the amount that did not fit. Unknown id → warning, returns amount. amount <= 0 → 0.
func add_item(id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var item := _item(id)
	if item == null:
		push_warning("[Inventory] unknown item '%s' – %d not added" % [id, amount])
		return amount
	if _is_currency(item):
		_set_currency(id, int(_currency.get(id, 0)) + amount)
		changed.emit()
		return 0
	var rest := _insert(id, amount, _stack_limit(item))
	if rest < amount:
		changed.emit()
	return rest


## All or nothing: false (and no change) if fewer than amount are held. amount <= 0 → true.
func remove_item(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if count(id) < amount:
		return false
	var rest := amount
	if _currency.has(id):
		var take := mini(rest, _currency[id])
		_set_currency(id, _currency[id] - take)
		rest -= take
	var i := _slots.size() - 1
	while rest > 0 and i >= 0:
		var slot := _slots[i]
		if _slot_holds(slot, id):
			var take := mini(rest, int(slot["amount"]))
			var left := int(slot["amount"]) - take
			_slots[i] = _make_slot(id, left) if left > 0 else {}
			rest -= take
		i -= 1
	changed.emit()
	return true


## Total held, over all stacks (or the currency purse).
func count(id: StringName) -> int:
	var total := int(_currency.get(id, 0))
	for slot: Dictionary in _slots:
		if _slot_holds(slot, id):
			total += int(slot["amount"])
	return total


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


## True if add_item(id, amount) would store everything. Unknown id → false; amount <= 0 → true.
func can_add(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var item := _item(id)
	if item == null:
		return false
	if _is_currency(item):
		return true
	return _free_space(id, _stack_limit(item)) >= amount


## Exactly slot_count copies: {id: StringName, amount: int} or {} – CURRENCY never appears.
func get_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		out.append(slot.duplicate())
	return out


func clear() -> void:
	if _is_empty():
		return
	_slots = _empty_slots(slot_count)
	_currency.clear()
	changed.emit()


## Plain StringNames/ints only: {"slots": [slot_count × ({} | {id, amount})], "currency": {id: amount}}.
func save_state() -> Dictionary:
	var slots: Array = []
	for slot: Dictionary in _slots:
		slots.append(slot.duplicate())
	var currency: Dictionary = {}
	for id: StringName in _currency:
		currency[id] = _currency[id]
	return {"slots": slots, "currency": currency}


## Replaces everything. Slots keep their saved index; entries that no longer fit there
## (fewer slots, smaller max_stack) are repacked; unknown or invalid entries are dropped
## with a warning. Always emits `changed` once.
func load_state(data: Dictionary) -> void:
	_slots = _empty_slots(slot_count)
	_currency.clear()
	var pending: Array[Dictionary] = []
	var saved_slots: Variant = data.get("slots", [])
	if saved_slots is Array:
		var list: Array = saved_slots
		for i: int in list.size():
			if list[i] is Dictionary and (list[i] as Dictionary).is_empty():
				continue
			_restore(list[i], i, pending)
	var saved_currency: Variant = data.get("currency", {})
	if saved_currency is Dictionary:
		var purse: Dictionary = saved_currency
		for key: Variant in purse:
			_restore({"id": key, "amount": purse[key]}, -1, pending)
	for entry: Dictionary in pending:
		_insert_or_warn(StringName(entry["id"]), int(entry["amount"]))
	changed.emit()


func _set_slot_count(value: int) -> void:
	var new_count := maxi(value, 0)
	slot_count = new_count
	if _slots.size() == new_count:
		return
	var old := _slots
	_slots = _empty_slots(new_count)
	var overflow: Array[Dictionary] = []
	for i: int in old.size():
		if old[i].is_empty():
			continue
		if i < new_count:
			_slots[i] = old[i]
		else:
			overflow.append(old[i])
	for entry: Dictionary in overflow:
		_insert_or_warn(StringName(entry["id"]), int(entry["amount"]))
	changed.emit()


## Places one saved entry: currency into the purse, slot items at `index` when that slot
## is free (excess beyond max_stack and index -1 go to `pending` for repacking).
func _restore(raw: Variant, index: int, pending: Array[Dictionary]) -> void:
	var entry: Dictionary = raw if raw is Dictionary else {}
	var raw_id: Variant = entry.get("id")
	var raw_amount: Variant = entry.get("amount")
	if not (raw_id is String or raw_id is StringName) or not (raw_amount is int or raw_amount is float):
		push_warning("[Inventory] invalid saved entry %s dropped" % var_to_str(raw))
		return
	var id := StringName(raw_id)
	var amount := int(raw_amount)
	if amount <= 0:
		return
	var item := _item(id)
	if item == null:
		push_warning("[Inventory] unknown saved item '%s' (%d) dropped" % [id, amount])
		return
	if _is_currency(item):
		_set_currency(id, int(_currency.get(id, 0)) + amount)
		return
	if index >= 0 and index < _slots.size() and _slots[index].is_empty():
		var placed := mini(amount, _stack_limit(item))
		_slots[index] = _make_slot(id, placed)
		amount -= placed
	if amount > 0:
		pending.append(_make_slot(id, amount))


func _insert_or_warn(id: StringName, amount: int) -> void:
	var item := _item(id)
	var rest := _insert(id, amount, _stack_limit(item)) if item != null else amount
	if rest > 0:
		push_warning("[Inventory] no room for %d × '%s' – dropped" % [rest, id])


## Fills existing stacks of id, then empty slots in index order. Returns what did not fit.
func _insert(id: StringName, amount: int, limit: int) -> int:
	var rest := amount
	for i: int in _slots.size():
		if rest == 0:
			break
		var slot := _slots[i]
		if _slot_holds(slot, id) and int(slot["amount"]) < limit:
			var take := mini(rest, limit - int(slot["amount"]))
			_slots[i] = _make_slot(id, int(slot["amount"]) + take)
			rest -= take
	for i: int in _slots.size():
		if rest == 0:
			break
		if _slots[i].is_empty():
			var take := mini(rest, limit)
			_slots[i] = _make_slot(id, take)
			rest -= take
	return rest


func _free_space(id: StringName, limit: int) -> int:
	var space := 0
	for slot: Dictionary in _slots:
		if slot.is_empty():
			space += limit
		elif _slot_holds(slot, id):
			space += maxi(limit - int(slot["amount"]), 0)
	return space


func _set_currency(id: StringName, amount: int) -> void:
	if amount > 0:
		_currency[id] = amount
	else:
		_currency.erase(id)


func _is_empty() -> bool:
	if not _currency.is_empty():
		return false
	for slot: Dictionary in _slots:
		if not slot.is_empty():
			return false
	return true


func _item(id: StringName) -> ItemData:
	if not Database.has_item(id):
		return null
	return Database.item(id) as ItemData


func _is_currency(item: ItemData) -> bool:
	return item.category == ItemData.Category.CURRENCY


func _stack_limit(item: ItemData) -> int:
	return maxi(item.max_stack, 1)


func _slot_holds(slot: Dictionary, id: StringName) -> bool:
	return not slot.is_empty() and StringName(slot["id"]) == id


func _make_slot(id: StringName, amount: int) -> Dictionary:
	return {"id": id, "amount": amount}


func _empty_slots(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({})
	return out
