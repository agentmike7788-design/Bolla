class_name CollectionShelf
extends Chest
## STUB (P7) – the collection shelf next to the pult in the crypt (docs/PHASE7_DESIGN.md §2.7, §3.4, §5.1):
## a Chest with 7 slots, one organ per slot (save_id "collection_shelf", save_order 63); [E] opens the
## panel COLLECTION_PANEL (&"collection"; Chest.PANEL stays &"chest" – a constant cannot be redefined).
## After placing: CollectionRules.completed_sets → the reward once (payment_received),
## stats.university_standing, collection_set_completed.
## W0: standing() / sets_done() answer from load_state({"storage", "sets_done", "standing"}) so W1 tests
## can set them (Phase7Fixtures.shelf_with); everything else is inert.
## W1 (P7) fills the bodies; the signatures are the contract.

const COLLECTION_PANEL := &"collection"
const PROMPT_SHELF := "[E] Sammlung ansehen"
const SLOT_COUNT := 7

## W0 stub store (P7 may rename it – the fixtures use load_state only).
var _standing: int = 0
var _sets_done: PackedStringArray = []


func _init() -> void:
	save_id = "collection_shelf"
	save_order = 63


## Ansehen bei der Universität 0…4 (never falls).
func standing() -> int:
	return _standing


func sets_done() -> PackedStringArray:
	return _sets_done.duplicate()


func place(_uid: String, _inv: Inventory) -> bool:
	return false


func take(_uid: String, _inv: Inventory) -> bool:
	return false


## {storage, sets_done, standing} (§5.1).
func save_state() -> Dictionary:
	return {"storage": storage.save_state()}


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	var st: Variant = data.get("standing")
	_standing = clampi(int(st), 0, 4) if (st is int or st is float) else 0
	_sets_done = PackedStringArray()
	var done: Variant = data.get("sets_done")
	if done is Array or done is PackedStringArray:
		for id: Variant in done:
			_sets_done.append(str(id))
