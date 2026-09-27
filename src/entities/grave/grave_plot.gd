class_name GravePlot
extends Node3D
## One grave place (group grave_plot). Visual follows GraveRecord.state.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var grave_id: String = ""
@export var is_old: bool = false

func can_interact(player: Player) -> bool:
	push_warning("STUB GravePlot.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB GravePlot.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB GravePlot.interact")


func request_marker(marker_id: StringName) -> void:
	push_warning("STUB GravePlot.request_marker")
