class_name PoorBox
extends Node3D
## The poor box in the office (docs/PHASE7_DESIGN.md §2.4, §3.4, §4.3):
## „[E] In die Armenkasse geben (5 Münzen)" → Village.donate (at most 2 steps per day). A blocked step
## shows its reason dimmed (Village.donation_block_reason).

const PROMPT := "[E] In die Armenkasse geben (5 Münzen)"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	var village := _village()
	return village != null and player != null and village.donation_block_reason(player.inventory) == ""


func get_interaction_prompt(player: Player) -> String:
	var village := _village()
	if village == null:
		return ""
	var reason := village.donation_block_reason(player.inventory if player != null else null)
	return PROMPT if reason == "" else "%s – %s" % [PROMPT, reason]


func interact(player: Player) -> void:
	var village := _village()
	if village == null or player == null:
		return
	var reason := village.donation_block_reason(player.inventory)
	if reason != "":
		EventBus.notification_requested.emit(reason, &"warning")
		return
	village.donate(player.inventory)


func _village() -> Village:
	return get_tree().get_first_node_in_group(&"village") as Village if is_inside_tree() else null
