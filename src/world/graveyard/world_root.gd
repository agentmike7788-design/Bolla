class_name WorldRoot
extends Node3D
## Root of the graveyard world scene.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var corpse_manager: CorpseManager
var graveyard: Graveyard
var is_world_ready: bool = false

func get_waypoint(id: StringName) -> Vector3:
	push_warning("STUB WorldRoot.get_waypoint")
	return Vector3.ZERO


func get_player() -> Player:
	push_warning("STUB WorldRoot.get_player")
	return null


func get_node_by_layout_id(id: String) -> Node:
	push_warning("STUB WorldRoot.get_node_by_layout_id")
	return null
