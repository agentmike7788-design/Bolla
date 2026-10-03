class_name CollectionShelf
extends Chest
## The collection shelf next to the pult in the crypt (docs/PHASE7_DESIGN.md §2.7, §3.4, §5.1): a Chest
## with 7 compartments, one organ each (save_id "collection_shelf", save_order 63); [E] opens the panel
## COLLECTION_PANEL (&"collection"; Chest.PANEL stays &"chest" – a constant cannot be redefined) with
## {shelf, storage, inventory, player}. The panel moves pieces only through place / take.
## - The pieces stay the player's (state held): placed pieces still count as taken (the ghost stays
##   robbed); taken out they can be sold, returned … again.
## - The organ of a piece comes from its SpecimenRecord (Specimens); the storage holds the unique slots
##   (Inventory.add_unique / remove_uid), so the organ map is derived and never saved twice.
## - After placing: CollectionRules.completed_sets → each set once: Quast's coins (payment_received),
##   Ansehen bei der Universität (+standing, 0…4, never falling; stats.university_standing), the set's
##   flag (set_complete: university_letter), collection_set_completed. Taking out never undoes a set.
## - stats.specimens_collected = pieces on the shelf now.
## - Usable while the pult is built (Workshop.is_built(&"pult"); no Workshop in the tree = usable).

const COLLECTION_PANEL := &"collection"
const PROMPT_SHELF := "[E] Sammlung ansehen"
const SLOT_COUNT := 7
const SPECIMENS_GROUP := &"specimens"
const WORKSHOP_GROUP := &"workshop"
const COIN := &"coin"
const STAT_STANDING := &"university_standing"
const STAT_COLLECTED := &"specimens_collected"
const FORMAT_PAYMENT := "Die Universität zahlt für die Aufstellung: %s"
const FORMAT_SET_NOTE := "Satz „%s“ vollständig. Die Universität zahlt für die Aufstellung."
const NOTE_KIND := &"info"
const TEXT_TAKEN := "In diesem Fach steht schon etwas."
const TEXT_NOT_ACCEPTED := "Ins Regal kommen nur Gläser, Schau- und Knochenpräparate."
const TEXT_NOT_HELD := "Das Präparat musst du dabeihaben."
const TEXT_FULL := "Kein Platz im Inventar"

## The station whose building puts the shelf up.
@export var requires_station: StringName = &"pult"

## Tests: the Specimens system / the sets; null / empty = the tree (group specimens) / Database.
var specimens: Specimens
var sets: Array[CollectionSetData] = []

var _standing: int = 0
var _sets_done: PackedStringArray = []


func _init() -> void:
	save_id = "collection_shelf"
	save_order = 63


func _ready() -> void:
	super._ready()
	storage.slot_count = SLOT_COUNT


## Ansehen bei der Universität 0…4 (never falls).
func standing() -> int:
	return _standing


func sets_done() -> PackedStringArray:
	return _sets_done.duplicate()


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
	return PROMPT_SHELF


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(COLLECTION_PANEL, {"shelf": self, "storage": storage, "inventory": player.inventory,
			"player": player})


## {organ: SpecimenRecord} of the filled compartments.
func shelf_organs() -> Dictionary:
	var out := {}
	var sp := _specimens()
	if sp == null:
		return out
	for uid: String in storage.uids():
		var rec := sp.get_record(uid)
		if rec != null and not out.has(rec.organ):
			out[rec.organ] = rec
	return out


## uid in the compartment of `organ` ("" = empty).
func uid_at(organ: StringName) -> String:
	var rec: Variant = shelf_organs().get(organ)
	return (rec as SpecimenRecord).uid if rec is SpecimenRecord else ""


## "" or why `uid` cannot be placed from `inv`.
func place_block_reason(uid: String, inv: Inventory) -> String:
	var sp := _specimens()
	var rec := sp.get_record(uid) if sp != null else null
	if rec == null or not CollectionRules.accepts(_item_of(rec), rec):
		return TEXT_NOT_ACCEPTED
	if inv == null or not inv.has_uid(uid):
		return TEXT_NOT_HELD
	if shelf_organs().has(rec.organ):
		return TEXT_TAKEN
	return ""


## From `inv` into the organ's compartment; then the sets (once each, coins into `inv`).
func place(uid: String, inv: Inventory) -> bool:
	if place_block_reason(uid, inv) != "":
		return false
	var rec := _specimens().get_record(uid)
	var item := _item_of(rec)
	if not storage.add_unique(item, uid):
		return false
	if not inv.remove_uid(uid):
		storage.remove_uid(uid)
		return false
	_note_collected()
	_check_sets(inv)
	return true


## Back from the shelf into `inv` (the sets stay done).
func take(uid: String, inv: Inventory) -> bool:
	if inv == null or not storage.has_uid(uid):
		return false
	var item := _stored_item(uid)
	if item == &"" or not storage.remove_uid(uid):
		return false
	if not inv.add_unique(item, uid):
		storage.add_unique(item, uid)
		EventBus.notification_requested.emit(TEXT_FULL, &"warning")
		return false
	_note_collected()
	return true


## {storage, sets_done, standing} (§5.1).
func save_state() -> Dictionary:
	return {"storage": storage.save_state(), "sets_done": Array(_sets_done), "standing": _standing}


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	var st: Variant = data.get("standing")
	_standing = clampi(int(st), 0, CollectionRules.MAX_STANDING) if (st is int or st is float) else 0
	_sets_done = PackedStringArray()
	var done: Variant = data.get("sets_done")
	if done is Array or done is PackedStringArray:
		for id: Variant in done:
			if not _sets_done.has(str(id)):
				_sets_done.append(str(id))


# --- internals ------------------------------------------------------------------------------

func _check_sets(inv: Inventory) -> void:
	var all := _sets()
	for set_id: StringName in CollectionRules.completed_sets(shelf_organs(), all, _sets_done):
		var data: CollectionSetData = null
		for s: CollectionSetData in all:
			if s.id == set_id:
				data = s
		_sets_done.append(String(set_id))
		_standing = CollectionRules.add_standing(_standing, data.standing)
		GameState.stats[STAT_STANDING] = maxi(GameState.get_stat(STAT_STANDING), _standing)
		if data.sets_flag != &"":
			GameState.set_flag(data.sets_flag, true)
		if data.reward_coins > 0 and inv != null:
			inv.add_item(COIN, data.reward_coins)
			EventBus.payment_received.emit(data.reward_coins, FORMAT_PAYMENT % data.title)
		EventBus.notification_requested.emit(FORMAT_SET_NOTE % data.title, NOTE_KIND)
		EventBus.collection_set_completed.emit(set_id, _standing)


func _note_collected() -> void:
	GameState.stats[STAT_COLLECTED] = storage.uids().size()


func _item_of(rec: SpecimenRecord) -> StringName:
	return CollectionRules.ITEM_OF_CONTAINER.get(rec.container, &"") if rec != null else &""


func _stored_item(uid: String) -> StringName:
	for id: StringName in Specimens.ITEMS:
		if storage.uids(id).has(uid):
			return id
	return &""


func _specimens() -> Specimens:
	if specimens != null and is_instance_valid(specimens):
		return specimens
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(SPECIMENS_GROUP) as Specimens


func _sets() -> Array[CollectionSetData]:
	if not sets.is_empty():
		return sets
	var out: Array[CollectionSetData] = []
	for res: Resource in Database.collection_sets():
		var s := res as CollectionSetData
		if s != null:
			out.append(s)
	return out
