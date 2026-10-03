class_name PultStore
extends Chest
## The cold box (slate drawer) of the preparation desk in the crypt (docs/PHASE7_DESIGN.md §2.6, §2.7,
## §3.4): a Chest with 8 slots (save_id "pult_store", save_order 62), [E] opens the &"chest" panel; takes
## everything the chest takes (unique pieces keep their uid – ChestTransfer). Bundles spoil × 0.25 in
## here: every Inventory.changed compares the bundle uids with the last ones and tells
## Specimens.note_cold(uid, true) for each bundle that came in, (uid, false) for each that left. Loading
## only takes the new list (the open windows are in the saved records).
## Usable while the pult is built (Workshop.is_built(&"pult"); no Workshop in the tree = usable).

const PROMPT_COLD := "[E] Kühlfach öffnen"
const SLOT_COUNT := 8
const SPECIMENS_GROUP := &"specimens"
const WORKSHOP_GROUP := &"workshop"

## The station whose building puts the cold box up.
@export var requires_station: StringName = &"pult"

## Tests: the Specimens system; null = the tree (group specimens).
var specimens: Specimens

## Bundle uids in the box at the last change.
var _bundles: PackedStringArray = []
var _loading: bool = false


func _init() -> void:
	save_id = "pult_store"
	save_order = 62


func _ready() -> void:
	super._ready()
	storage.slot_count = SLOT_COUNT
	_bundles = _current_bundles()
	storage.changed.connect(_on_storage_changed)


## The cold box inventory (= storage).
func store() -> Inventory:
	return storage


## Bundle uids in the box now.
func bundles() -> PackedStringArray:
	return _current_bundles()


## The pult is built (or no Workshop exists).
func is_active() -> bool:
	if requires_station == &"" or not is_inside_tree():
		return true
	var shop := get_tree().get_first_node_in_group(WORKSHOP_GROUP)
	return shop == null or not shop.has_method(&"is_built") or bool(shop.call(&"is_built", requires_station))


func can_interact(player: Player) -> bool:
	return super.can_interact(player) and is_active()


func get_interaction_prompt(player: Player) -> String:
	if not is_active():
		return ""
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	return PROMPT_COLD


func load_state(data: Dictionary) -> void:
	_loading = true
	super.load_state(data)
	_loading = false
	_bundles = _current_bundles()


func _on_storage_changed() -> void:
	var now := _current_bundles()
	if _loading:
		_bundles = now
		return
	var sp := _specimens()
	if sp != null:
		for uid: String in now:
			if not _bundles.has(uid):
				sp.note_cold(uid, true)
		for uid: String in _bundles:
			if not now.has(uid):
				sp.note_cold(uid, false)
	_bundles = now


func _current_bundles() -> PackedStringArray:
	return storage.uids(Specimens.ITEM_BUNDLE) if storage != null else PackedStringArray()


func _specimens() -> Specimens:
	if specimens != null and is_instance_valid(specimens):
		return specimens
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens
