class_name InteractionDetector
extends Area3D
## Picks the best Interactable around the player every physics frame.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

signal focus_changed(interactable: Interactable)

var focused: Interactable

func _physics_process(_delta: float) -> void:
	pass
