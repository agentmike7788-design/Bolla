class_name RegionPortal
extends Node3D
## STUB (P1) – the way to another region (docs/PHASE7_DESIGN.md §3.4, §4.1): Entities/road_exit on the
## graveyard (the milestone at the end of the coach road) and Village/Entities/road_out (the
## Holderbrücke). Rules: RegionTravel.block_reason; only from requires_flag. Scene:
## src/entities/region_portal/region_portal.tscn. W1 (P1) fills the bodies; the signatures are the contract.

@export var target_region: StringName
@export var target_spawn: StringName
@export var requires_flag: StringName = &"village_open"
@export var prompt: String = "[E] Nach Hollerbrück (30 Min)"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
