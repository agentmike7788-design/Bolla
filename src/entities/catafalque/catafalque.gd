class_name Catafalque
extends Node3D
## The catafalque before the altar inside the chapel (docs/PHASE6_DESIGN.md §2.4, §3.4), group
## &"catafalque": carrying + free → „[E] Auf den Katafalk legen" (CorpseManager.put_down at
## LOCATION_CATAFALQUE, room chapel, on the model's slot_corpse marker); hands free + occupied →
## „[E] Leiche aufnehmen". The occupancy comes from the CorpseManager records – nothing is saved here.

const GROUP := &"catafalque"
const MANAGER_GROUP := &"corpse_manager"
const SLOT_NAME := "slot_corpse"
const PROMPT_PUT := "[E] Auf den Katafalk legen"
const PROMPT_TAKE := "[E] Leiche aufnehmen"
const PROMPT_OCCUPIED := "Der Katafalk ist belegt"

## Room the corpse lies in (ChapelConfig.room_id).
@export var room: StringName = &"chapel"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP, true)


## Corpse id on the catafalque ("" = free), from the records.
func occupant() -> String:
	var manager := _manager()
	if manager == null:
		return ""
	for record: CorpseRecord in manager.records():
		if record.location == CorpseRecord.LOCATION_CATAFALQUE:
			return record.id
	return ""


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy():
		return false
	if _is_carrying(player):
		return occupant() == ""
	return occupant() != ""


func get_interaction_prompt(player: Player) -> String:
	var id := occupant()
	if player != null and _is_carrying(player):
		return PROMPT_OCCUPIED if id != "" else PROMPT_PUT
	return PROMPT_TAKE if id != "" else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var manager := _manager()
	if manager == null:
		return
	if _is_carrying(player):
		# §4.7: corpses in the rooms hang under the world's Corpses container, not under the room.
		manager.put_down(player.carried_id, CorpseRecord.LOCATION_CATAFALQUE, slot_node().global_transform, null, room)
	else:
		manager.pick_up(occupant(), player)


## The model's slot_corpse marker (the corpse lies at its transform).
func slot_node() -> Node3D:
	var slot := find_child(SLOT_NAME, true, false) as Node3D
	return slot if slot != null else self


func _manager() -> CorpseManager:
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
