class_name Interactable
extends Area3D
## Makes its target (default: parent) interactable. Layer 4, mask 0, monitorable only.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var prompt: String = "Benutzen"
@export var priority: int = 0
@export var enabled: bool = true
@export var target_path: NodePath = ^".."

func get_target() -> Node:
	push_warning("STUB Interactable.get_target")
	return null
