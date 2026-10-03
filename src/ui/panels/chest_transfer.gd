class_name ChestTransfer
extends RefCounted
## Pure transfer rules of the chest panel (docs §11): moves items between two Inventory
## nodes through their public API only. Every move is atomic and loses nothing: only what
## the target can take leaves the source, the rest stays where it was. CURRENCY items
## (coins) never move – they stay with the player. A move that changes something emits
## `changed` exactly once on each inventory; a move of nothing emits nothing.


## True for items that may be stored: known to the Database and not CURRENCY.
static func is_transferable(id: StringName) -> bool:
	if id == &"" or not Database.has_item(id):
		return false
	var item := Database.item(id) as ItemData
	return item != null and item.category != ItemData.Category.CURRENCY


## Largest n <= amount with target.can_add(id, n) (can_add grows monotonic with free room).
static func fit(target: Inventory, id: StringName, amount: int) -> int:
	if not is_instance_valid(target) or amount <= 0:
		return 0
	if target.can_add(id, amount):
		return amount
	var lo := 0
	var hi := amount
	while hi - lo > 1:
		var mid := lo + ((hi - lo) >> 1)
		if target.can_add(id, mid):
			lo = mid
		else:
			hi = mid
	return lo


## Moves up to `amount` of `id` from `source` to `target`; returns how many moved.
## Clamped to what the source holds and what the target can take; currency moves 0.
static func move(source: Inventory, target: Inventory, id: StringName, amount: int) -> int:
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return 0
	if amount <= 0 or not is_transferable(id):
		return 0
	if is_unique(id):
		return _move_pieces(source, target, id, amount)
	var n := fit(target, id, mini(amount, source.count(id)))
	if n <= 0 or not source.remove_item(id, n):
		return 0
	var rest := target.add_item(id, n)
	if rest > 0:
		# can_add promised room – should never happen; put the rest back (never lose items).
		push_warning("[ChestTransfer] target refused %d × '%s' – returned to the source" % [rest, id])
		source.add_item(id, rest)
	return n - rest


## Moves the stack in slot `index` of `source` (index into source.get_slots()): the whole
## stack, or a single item when `one`. Returns how many moved (0 for empty / bad slots).
static func move_slot(source: Inventory, target: Inventory, index: int, one: bool = false) -> int:
	var slot := slot_at(source, index)
	if slot.is_empty():
		return 0
	var amount := 1 if one else int(slot.get("amount", 0))
	var id := StringName(slot.get("id", &""))
	if slot.has("uid") and is_transferable(id) and source != target and is_instance_valid(target):
		return 1 if _move_piece(source, target, id, str(slot["uid"])) else 0
	return move(source, target, id, amount)


## Phase 7 (docs/PHASE7_DESIGN.md §3.4): ItemData.unique – a piece with its own slot and uid.
static func is_unique(id: StringName) -> bool:
	if id == &"" or not Database.has_item(id):
		return false
	var item := Database.item(id) as ItemData
	return item != null and item.unique


## Up to `amount` pieces of `id`, the newest (last slots) first, each with its uid; returns how many
## moved. Each piece is one move (changed once per piece on each side).
static func _move_pieces(source: Inventory, target: Inventory, id: StringName, amount: int) -> int:
	var list := source.uids(id)
	var moved := 0
	var i := list.size() - 1
	while i >= 0 and moved < amount:
		if not target.can_add(id, 1) or not _move_piece(source, target, id, list[i]):
			break
		moved += 1
		i -= 1
	return moved


## One piece (uid "" = a debug piece) from source to target; false = no room / not there.
static func _move_piece(source: Inventory, target: Inventory, id: StringName, uid: String) -> bool:
	if not target.can_add(id, 1):
		return false
	if uid == "":
		if not source.remove_piece(id, ""):
			return false
		if target.add_item(id, 1) > 0:
			push_warning("[ChestTransfer] target refused the piece '%s' – returned to the source" % id)
			source.add_item(id, 1)
			return false
		return true
	if not source.remove_uid(uid):
		return false
	if not target.add_unique(id, uid):
		push_warning("[ChestTransfer] target refused the piece '%s' – returned to the source" % uid)
		source.add_unique(id, uid)
		return false
	return true


## Moves every transferable item of `source` that fits into `target` (in slot order).
## Returns the total moved; `changed` fires once per moved item kind on each side.
static func move_all(source: Inventory, target: Inventory) -> int:
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return 0
	var moved := 0
	for id: StringName in item_ids(source):
		moved += move(source, target, id, source.count(id))
	return moved


## True if move_all(source, target) would move at least one item.
static func can_move_any(source: Inventory, target: Inventory) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return false
	for id: StringName in item_ids(source):
		if target.can_add(id, 1):
			return true
	return false


## Distinct transferable item ids of `inv`, in slot order.
static func item_ids(inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	if not is_instance_valid(inv):
		return out
	for slot: Dictionary in inv.get_slots():
		if slot.is_empty():
			continue
		var id := StringName(slot.get("id", &""))
		if is_transferable(id) and not id in out:
			out.append(id)
	return out


## Copy of slot `index` of `inv` ({} when empty or out of range).
static func slot_at(inv: Inventory, index: int) -> Dictionary:
	if not is_instance_valid(inv) or index < 0:
		return {}
	var slots := inv.get_slots()
	return slots[index] if index < slots.size() else {}
