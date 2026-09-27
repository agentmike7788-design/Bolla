class_name MorgueTable
extends Node3D
## Examination table (group morgue_table).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var corpse_id: String = ""

func can_interact(player: Player) -> bool:
	push_warning("STUB MorgueTable.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB MorgueTable.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB MorgueTable.interact")


func request_examine() -> void:
	push_warning("STUB MorgueTable.request_examine")


func request_shroud() -> void:
	push_warning("STUB MorgueTable.request_shroud")


func decide_valuables(take: bool) -> void:
	push_warning("STUB MorgueTable.decide_valuables")


func request_pick_up() -> void:
	push_warning("STUB MorgueTable.request_pick_up")
