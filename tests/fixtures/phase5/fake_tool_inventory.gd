extends "res://tests/fixtures/fake_inventory.gd"
## Test double of the Phase-5 tool belt (docs/PHASE5_DESIGN.md §2.3): the unlimited
## FakeInventory plus a belt {item_id: 1} returned by tools(). count / has see the belt too (like
## the real Inventory once P3 delivers it). Made by Phase5Fixtures.inv_with_tools.

var belt: Dictionary[StringName, int] = {}


func tools() -> Dictionary[StringName, int]:
	return belt.duplicate()


func count(id: StringName) -> int:
	return int(items.get(id, 0)) + int(belt.get(id, 0))


func has(id: StringName, amount: int = 1) -> bool:
	return count(id) >= amount


func remove_item(id: StringName, amount: int) -> bool:
	if belt.has(id) and amount == 1 and int(items.get(id, 0)) == 0:
		belt.erase(id)
		changed.emit()
		return true
	return super.remove_item(id, amount)
