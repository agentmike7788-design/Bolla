class_name ClearableObstacle
extends Node3D
## STUB (P1) – docs/PHASE3_DESIGN.md §3.4. Obstacle of a new section (bramble, rubble, stump,
## hedge, fence_gap). Group &"clearable"; Interactable priority 8. Prompt e.g.
## "[E] Brombeeren roden (30 Min) → +1 Holz"; state only from ExpansionManager (not saved).

const GROUP := &"clearable"

@export var obstacle_id: String = ""
@export var section_id: StringName = &""
## ClearableData id (data/clearables/<kind>.tres).
@export var kind: StringName = &""
## Local XZ rect: build block + grass mask while not cleared.
@export var footprint: Rect2 = Rect2(-1, -1, 2, 2)


func _init() -> void:
	add_to_group(GROUP)


## footprint in world XZ.
func world_rect() -> Rect2:
	return footprint


## Model / collision; a fence_gap then shows repaired_model.
func apply_cleared(_cleared: bool) -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
