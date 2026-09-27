class_name DirtSpot
extends Node3D
## STUB (P3) – docs/PHASE3_DESIGN.md §2.4, §3.4. One weeds / leaves spot (group &"dirt_spot",
## Interactable priority 6). Grave spots are named dirt_<plot_id> and carry grave_id.

const GROUP := &"dirt_spot"

@export var spot_id: String = ""
@export var section_id: StringName = &""
## &"weeds" or &"leaves".
@export var kind: StringName = &"weeds"
@export var grave_id: String = ""
@export var start_progress: float = 0.0


func _init() -> void:
	add_to_group(GROUP)


## Models ph_env_weeds_1..3 / ph_env_leaves_1..3; level 0 = nothing.
func show_level(_level: int) -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
