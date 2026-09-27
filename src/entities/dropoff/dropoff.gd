class_name Dropoff
extends Node3D
## Bier at the gate where the carter leaves corpses (group dropoff). No own state: it is free
## while no CorpseRecord has location &"dropoff". The corpse itself is the interactable.

const GROUP := &"dropoff"
const MANAGER_GROUP := &"corpse_manager"
const SLOT_NAME := "slot_corpse"


func _init() -> void:
	add_to_group(GROUP, true)


func is_free() -> bool:
	var manager := get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager if is_inside_tree() else null
	if manager == null:
		return true
	for record: CorpseRecord in manager.records():
		if record.location == CorpseRecord.LOCATION_DROPOFF:
			return false
	return true


## Global transform of the bier's slot_corpse marker (+X = the corpse's long axis).
func slot_transform() -> Transform3D:
	var slot := find_child(SLOT_NAME, true, false) as Node3D
	return slot.global_transform if slot != null else global_transform
