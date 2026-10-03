extends RefCounted
## P7 test doubles (test_pult, test_medicines, test_collection): unique pieces in an inventory and the
## Specimens calls the pult makes, independent of the P4 implementation (W1 runs in parallel). Records
## come in through the W0 contract Specimens.load_state({"next", "records"}) and are read with
## get_record; consume / note_cold are recorded here.


## FakeInventory (unlimited, dictionary-backed) + unique pieces {uid: item_id} with add_unique /
## remove_uid / uids / has_uid (Inventory contract §3.4). save / load keep the pieces.
class UniqueInventory extends "res://tests/fixtures/fake_inventory.gd":
	var pieces: Dictionary = {}
	var room: int = 99

	func add_unique(id: StringName, uid: String) -> bool:
		if uid == "" or pieces.has(uid) or pieces.size() >= room:
			return false
		pieces[uid] = id
		changed.emit()
		return true

	func remove_uid(uid: String) -> bool:
		if not pieces.has(uid):
			return false
		pieces.erase(uid)
		changed.emit()
		return true

	func uids(id: StringName = &"") -> PackedStringArray:
		var out := PackedStringArray()
		for uid: String in pieces:
			if id == &"" or pieces[uid] == id:
				out.append(uid)
		return out

	func has_uid(uid: String) -> bool:
		return pieces.has(uid)

	func save_state() -> Dictionary:
		return {"items": items.duplicate(), "pieces": pieces.duplicate()}

	func load_state(data: Dictionary) -> void:
		items = (data.get("items", {}) as Dictionary).duplicate()
		pieces = (data.get("pieces", {}) as Dictionary).duplicate()
		changed.emit()


## Specimens whose consume / note_cold are recorded (the records from load_state, W0 contract).
class FakeSpecimens extends Specimens:
	var consumed: Array = []
	var cold: Array = []

	func consume(uid: String, inv: Inventory, state: StringName) -> bool:
		var rec := get_record(uid)
		if rec == null or rec.state != SpecimenRecord.STATE_HELD or inv == null or not inv.remove_uid(uid):
			return false
		rec.state = state
		consumed.append([uid, state])
		return true

	func note_cold(uid: String, entering: bool) -> void:
		cold.append([uid, entering])


## FakeSpecimens holding `records`.
static func specimens_with(records: Array) -> FakeSpecimens:
	var s := FakeSpecimens.new()
	var list: Array = []
	for r: SpecimenRecord in records:
		list.append(r.to_dict())
	s.load_state({"next": 1, "records": list})
	return s


## The item id of a record's container.
static func item_of(rec: SpecimenRecord) -> StringName:
	match rec.container:
		SpecimenRecord.CONTAINER_BUNDLE:
			return Specimens.ITEM_BUNDLE
		SpecimenRecord.CONTAINER_DISPLAY:
			return Specimens.ITEM_DISPLAY
		SpecimenRecord.CONTAINER_BONE:
			return Specimens.ITEM_BONE
	return Specimens.ITEM_JAR
