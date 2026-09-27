extends Inventory
## Test double: unlimited dictionary-backed inventory (no slots, no Database).
## Lets modules test against Inventory before/without the real implementation.

var items: Dictionary = {}


func add_item(id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	items[id] = int(items.get(id, 0)) + amount
	changed.emit()
	return 0


func remove_item(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if int(items.get(id, 0)) < amount:
		return false
	items[id] = int(items[id]) - amount
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


func count(id: StringName) -> int:
	return int(items.get(id, 0))


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func can_add(_id: StringName, _amount: int) -> bool:
	return true


func get_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in items:
		out.append({"id": id, "amount": items[id]})
	return out


func clear() -> void:
	items.clear()
	changed.emit()


func save_state() -> Dictionary:
	return {"items": items.duplicate()}


func load_state(data: Dictionary) -> void:
	items = (data.get("items", {}) as Dictionary).duplicate()
	changed.emit()
