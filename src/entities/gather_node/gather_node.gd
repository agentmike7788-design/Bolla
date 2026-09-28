class_name GatherNode
extends Node3D
## STUB (P2) – Entities/gather_<id> (docs/PHASE5_DESIGN.md §2.2, §3.4, §4.2–4.4): an Interactable
## gather node; its model follows GatherManager.stage (full / empty / regrowing). The elder bush
## node is a child of the existing bush instance without a model of its own. Minutes:
## ActionConfig.tool_minutes(data.minutes, player.tool_tier(data.tool_kind)). W1 (P2).

@export var node_id: String = ""
@export var kind: StringName = &""
## &"" = no section gate (bruch / quarry: ExpansionManager.is_unlocked).
@export var section_id: StringName = &""


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
