class_name DialogueRunner
extends RefCounted
## Runs a DialogueData (conditions/actions mini-language, docs §3.4).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

func start(data: DialogueData, context: Dictionary) -> void:
	push_warning("STUB DialogueRunner.start")


func current_node() -> DialogueNode:
	push_warning("STUB DialogueRunner.current_node")
	return null


func current_text() -> String:
	push_warning("STUB DialogueRunner.current_text")
	return ""


func available_choices() -> Array[DialogueChoice]:
	push_warning("STUB DialogueRunner.available_choices")
	return []


func choose(index: int) -> void:
	push_warning("STUB DialogueRunner.choose")


func is_finished() -> bool:
	push_warning("STUB DialogueRunner.is_finished")
	return false


static func check_condition(cond: String, context: Dictionary) -> bool:
	push_warning("STUB DialogueRunner.check_condition")
	return false


static func apply_action(action: String, context: Dictionary) -> void:
	push_warning("STUB DialogueRunner.apply_action")
