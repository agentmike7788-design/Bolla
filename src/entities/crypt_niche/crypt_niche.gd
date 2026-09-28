class_name CryptNiche
extends Node3D
## A cold niche inside the crypt (docs/PHASE6_DESIGN.md §2.2, §3.4, §4.8): slot_id niche_1…6, open
## from min_level (1/1/2/2/3/3). „[E] In die Kühlnische legen" (carrying, free, open) · „[E] Leiche
## aus der Nische nehmen" (hands free, occupied) · „Die Nische ist noch vermauert." (dimmed). The
## occupancy comes from the records (location &"niche", slot_id); the niche saves nothing. Laying a
## corpse down opens its cold window (CorpseManager.put_down → niche_factor of the crypt level).

const GROUP := &"crypt_niche"
const MANAGER_GROUP := &"corpse_manager"
const BUILDINGS_GROUP := &"buildings"
const SLOT_NAME := "slot_corpse"
const CHILL_NAME := "chill"
const PROMPT_PUT := "[E] In die Kühlnische legen"
const PROMPT_TAKE := "[E] Leiche aus der Nische nehmen"
const TEXT_SEALED := "Die Nische ist noch vermauert."
const TEXT_OCCUPIED := "Die Nische ist belegt."

@export var slot_id: String
@export var min_level: int = 1

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP, true)


## Buildings.level(&"crypt") ≥ min_level.
func is_open() -> bool:
	return crypt_level() >= min_level


## Corpse id in this niche ("" = free), from the records.
func occupant() -> String:
	var manager := _manager()
	if manager == null or slot_id == "":
		return ""
	return manager.corpse_in_slot(CorpseRecord.LOCATION_NICHE, slot_id)


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or not is_open():
		return false
	if _is_carrying(player):
		return occupant() == ""
	return occupant() != ""


func get_interaction_prompt(player: Player) -> String:
	if not is_open():
		return TEXT_SEALED
	var id := occupant()
	if player != null and _is_carrying(player):
		return TEXT_OCCUPIED if id != "" else PROMPT_PUT
	return PROMPT_TAKE if id != "" else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var manager := _manager()
	if manager == null:
		return
	if _is_carrying(player):
		var slot := slot_node()
		manager.put_down(player.carried_id, CorpseRecord.LOCATION_NICHE, slot.global_transform, slot, room(), slot_id)
	else:
		manager.pick_up(occupant(), player)


## The crypt room id (CryptConfig.room_id) – niches only stand in the crypt.
func room() -> StringName:
	var cfg := Database.config(&"crypt_config") as CryptConfig
	return cfg.room_id if cfg != null else &"crypt"


## The model's slot_corpse marker (the corpse is parented to it), else the niche itself.
func slot_node() -> Node3D:
	var slot := find_child(SLOT_NAME, true, false) as Node3D
	return slot if slot != null else self


## The model's chill marker (CorpseDecayVisual puts the cold breath there), else the slot.
func chill_node() -> Node3D:
	var chill := find_child(CHILL_NAME, true, false) as Node3D
	return chill if chill != null else slot_node()


## Buildings.level(&"crypt") of the node in group "buildings" (0 without one).
func crypt_level() -> int:
	var buildings := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	if buildings == null or not buildings.has_method(&"level"):
		return 0
	return int(buildings.call(&"level", &"crypt"))


## The niche with `slot_id` in `tree` (null = none).
static func find(tree: SceneTree, niche_slot: String) -> CryptNiche:
	if tree == null or niche_slot == "":
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is CryptNiche and (node as CryptNiche).slot_id == niche_slot:
			return node as CryptNiche
	return null


func _manager() -> CorpseManager:
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
