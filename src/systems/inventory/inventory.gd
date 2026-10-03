class_name Inventory
extends Node
## Slot inventory (child "Inventory" of the player). CURRENCY items have no slot.
## With `tool_belt` (the player), TOOL items have no slot either: they hang on the belt, at most
## max_stack per id (docs/PHASE5_DESIGN.md §2.3). count / has / remove_item / can_add include the
## belt; get_slots never shows it.
## Item rules (max_stack, category) come from Database.item(id) as ItemData.
## Adding fills existing stacks first, then empty slots in index order; removing is
## all-or-nothing and takes from the last stacks first. `changed` fires exactly once
## per call that actually changed the contents (never for no-ops or refusals).

signal changed

## Changing it keeps the contents: slots beyond the new count are repacked into free space.
@export var slot_count: int = 16:
	set = _set_slot_count
## Phase 5 §2.3, §3.4: TOOL items hang on the belt outside the slots (the player: true).
## Switching it on moves TOOL items out of the slots onto the belt (one `changed`).
@export var tool_belt: bool = false:
	set = _set_tool_belt
## Phase 6 §2.5, §3.4: the stack limit of an item whose category is in stack_categories
## (empty = all) is max_stack × stack_multiplier (the shed on level 3). save / load unchanged.
@export var stack_multiplier: int = 1
@export var stack_categories: Array[int] = []

## slot_count entries: {} (empty) or {"id": StringName, "amount": int} with 1 <= amount <= max_stack.
var _slots: Array[Dictionary] = []
## CURRENCY items held outside the slots: StringName -> int (> 0, no stack limit).
var _currency: Dictionary[StringName, int] = {}
## TOOL items on the belt (only with tool_belt): StringName -> int (1 <= amount <= max_stack).
var _tools: Dictionary[StringName, int] = {}


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
	if _on_belt(item):
		var take := mini(amount, _belt_space(id, item))
		if take <= 0:
			return amount
		_tools[id] = int(_tools.get(id, 0)) + take
		changed.emit()
		return amount - take
	if item.unique:
		push_warning("[Inventory] add_item of the unique item '%s' – pieces without uid (debug only)" % id)
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
	if rest > 0 and _tools.has(id):
		var take := mini(rest, _tools[id])
		_set_tool(id, _tools[id] - take)
		rest -= take
	changed.emit()
	return true


## Total held, over all stacks, the currency purse and the tool belt.
func count(id: StringName) -> int:
	var total := int(_currency.get(id, 0)) + int(_tools.get(id, 0))
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
	if _on_belt(item):
		return _belt_space(id, item) >= amount
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
	_tools.clear()
	changed.emit()


## Plain StringNames/ints only: {"slots": [slot_count × ({} | {id, amount})], "currency": {id: amount}}
## + "tools": {id: amount} with a tool belt.
func save_state() -> Dictionary:
	var slots: Array = []
	for slot: Dictionary in _slots:
		slots.append(slot.duplicate())
	var currency: Dictionary = {}
	for id: StringName in _currency:
		currency[id] = _currency[id]
	var out := {"slots": slots, "currency": currency}
	if tool_belt:
		var belt: Dictionary = {}
		for id: StringName in _tools:
			belt[id] = _tools[id]
		out["tools"] = belt
	return out


## Replaces everything. Slots keep their saved index; entries that no longer fit there
## (fewer slots, smaller max_stack) are repacked; unknown or invalid entries are dropped
## with a warning. With a tool belt, TOOL items from old slots move onto the belt (Phase-4
## saves); "tools" entries without a belt (or beyond max_stack) are repacked like other items.
## Always emits `changed` once.
func load_state(data: Dictionary) -> void:
	_slots = _empty_slots(slot_count)
	_currency.clear()
	_tools.clear()
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
	var saved_tools: Variant = data.get("tools", {})
	if saved_tools is Dictionary:
		var belt: Dictionary = saved_tools
		for key: Variant in belt:
			_restore({"id": key, "amount": belt[key]}, -1, pending)
	for entry: Dictionary in pending:
		_insert_entry_or_warn(entry)
	changed.emit()


# --- Phase 7 (docs/PHASE7_DESIGN.md §2.8, §3.4) – individual pieces (ItemData.unique) ------------
# One slot per piece, slot {"id", "amount": 1, "uid"}; normal slots stay {"id", "amount"}. save / load
# keep "uid" (missing = ""). add_item of a unique id makes pieces with uid "" (debug / tests, warning);
# remove_item(id, n) takes the newest (the last slots), as for stacks.

## A unique piece `id` with `uid` into the first free slot; false = no free slot, not a unique item,
## empty uid or a uid already held here (nothing changes).
func add_unique(id: StringName, uid: String) -> bool:
	var item := _item(id)
	if item == null or not item.unique or uid == "" or has_uid(uid):
		if item != null and not item.unique:
			push_warning("[Inventory] add_unique: '%s' is not a unique item" % id)
		return false
	for i: int in _slots.size():
		if _slots[i].is_empty():
			_slots[i] = _make_piece(id, uid)
			changed.emit()
			return true
	return false


## The slot holding `uid` emptied; false = not here ("" never matches – debug pieces go through
## remove_piece / remove_item).
func remove_uid(uid: String) -> bool:
	if uid == "":
		return false
	for i: int in _slots.size():
		if _slot_uid(_slots[i]) == uid:
			_slots[i] = {}
			changed.emit()
			return true
	return false


## The last piece of `id` with exactly `uid` ("" = a debug piece) removed; false = none.
## ChestTransfer moves debug pieces with it.
func remove_piece(id: StringName, uid: String) -> bool:
	for i: int in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if _slot_holds(slot, id) and slot.has("uid") and _slot_uid(slot) == uid:
			_slots[i] = {}
			changed.emit()
			return true
	return false


## The uids of the unique pieces (of `id`; &"" = all), slot order (debug pieces with uid "" too).
func uids(id: StringName = &"") -> PackedStringArray:
	var out := PackedStringArray()
	for slot: Dictionary in _slots:
		if slot.is_empty() or not slot.has("uid"):
			continue
		if id == &"" or StringName(slot["id"]) == id:
			out.append(_slot_uid(slot))
	return out


func has_uid(uid: String) -> bool:
	if uid == "":
		return false
	for slot: Dictionary in _slots:
		if _slot_uid(slot) == uid:
			return true
	return false


## Item id of the piece `uid` (&"" = not here).
func uid_item(uid: String) -> StringName:
	if uid == "":
		return &""
	for slot: Dictionary in _slots:
		if _slot_uid(slot) == uid:
			return StringName(slot["id"])
	return &""


static func _slot_uid(slot: Dictionary) -> String:
	var v: Variant = slot.get("uid", "")
	return str(v) if v is String or v is StringName else ""


func _make_piece(id: StringName, uid: String) -> Dictionary:
	return {"id": id, "amount": 1, "uid": uid}


func _is_unique_id(id: StringName) -> bool:
	var item := _item(id)
	return item != null and item.unique


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
		_insert_entry_or_warn(entry)
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
	if _on_belt(item):
		var take := mini(amount, _belt_space(id, item))
		if take > 0:
			_tools[id] = int(_tools.get(id, 0)) + take
			amount -= take
		if amount <= 0:
			return
	if item.unique:
		_restore_piece(id, _slot_uid(entry), amount, index, pending)
		return
	if index >= 0 and index < _slots.size() and _slots[index].is_empty():
		var placed := mini(amount, _stack_limit(item))
		_slots[index] = _make_slot(id, placed)
		amount -= placed
	if amount > 0:
		pending.append(_make_slot(id, amount))


## Phase 7: a saved unique piece keeps its uid (one per slot); an amount > 1 (damaged save) keeps
## the uid on the first piece only, a uid already placed is dropped with a warning.
func _restore_piece(id: StringName, uid: String, amount: int, index: int, pending: Array[Dictionary]) -> void:
	if uid != "" and (has_uid(uid) or _pending_has_uid(pending, uid)):
		push_warning("[Inventory] saved piece '%s' (%s) twice – dropped" % [uid, id])
		return
	for n: int in amount:
		var piece := _make_piece(id, uid if n == 0 else "")
		if n == 0 and index >= 0 and index < _slots.size() and _slots[index].is_empty():
			_slots[index] = piece
		else:
			pending.append(piece)


static func _pending_has_uid(pending: Array[Dictionary], uid: String) -> bool:
	for entry: Dictionary in pending:
		if _slot_uid(entry) == uid:
			return true
	return false


## A pending / overflow entry: a unique piece (has "uid") into the first free slot, else stacked.
func _insert_entry_or_warn(entry: Dictionary) -> void:
	if not entry.has("uid"):
		_insert_or_warn(StringName(entry["id"]), int(entry["amount"]))
		return
	for i: int in _slots.size():
		if _slots[i].is_empty():
			_slots[i] = _make_piece(StringName(entry["id"]), _slot_uid(entry))
			return
	push_warning("[Inventory] no room for the piece '%s' (%s) – dropped" % [_slot_uid(entry), entry["id"]])


func _insert_or_warn(id: StringName, amount: int) -> void:
	var item := _item(id)
	var rest := _insert(id, amount, _stack_limit(item)) if item != null else amount
	if rest > 0:
		push_warning("[Inventory] no room for %d × '%s' – dropped" % [rest, id])


## Fills existing stacks of id, then empty slots in index order (never the belt: a second copy
## of a belt tool from a save keeps a slot, nothing is lost). Returns what did not fit.
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
			_slots[i] = _make_piece(id, "") if _is_unique_id(id) else _make_slot(id, take)
			rest -= 1 if _is_unique_id(id) else take
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
	if not _currency.is_empty() or not _tools.is_empty():
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
	if item.unique:
		return 1
	var limit := maxi(item.max_stack, 1)
	if stack_multiplier > 1 and (stack_categories.is_empty() or stack_categories.has(int(item.category))):
		limit *= stack_multiplier
	return limit


func _slot_holds(slot: Dictionary, id: StringName) -> bool:
	return not slot.is_empty() and StringName(slot["id"]) == id


func _make_slot(id: StringName, amount: int) -> Dictionary:
	return {"id": id, "amount": amount}


func _empty_slots(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({})
	return out


## Phase 5 §3.4: a copy of the tool belt {item_id: amount} (always {} without tool_belt).
func tools() -> Dictionary[StringName, int]:
	return _tools.duplicate()


func _set_tool_belt(value: bool) -> void:
	if tool_belt == value:
		return
	tool_belt = value
	var moved := false
	if value:
		for i: int in _slots.size():
			var slot := _slots[i]
			if slot.is_empty():
				continue
			var id := StringName(slot["id"])
			var item := _item(id)
			if item == null or not _on_belt(item):
				continue
			var take := mini(int(slot["amount"]), _belt_space(id, item))
			if take <= 0:
				continue
			_tools[id] = int(_tools.get(id, 0)) + take
			var left := int(slot["amount"]) - take
			_slots[i] = _make_slot(id, left) if left > 0 else {}
			moved = true
	else:
		var old := _tools.duplicate()
		_tools.clear()
		for id: StringName in old:
			_insert_or_warn(id, old[id])
			moved = true
	if moved:
		changed.emit()


func _on_belt(item: ItemData) -> bool:
	return tool_belt and item.category == ItemData.Category.TOOL


func _belt_space(id: StringName, item: ItemData) -> int:
	return maxi(_stack_limit(item) - int(_tools.get(id, 0)), 0)


func _set_tool(id: StringName, amount: int) -> void:
	if amount > 0:
		_tools[id] = amount
	else:
		_tools.erase(id)
