class_name MourningRibbon
extends Node3D
## STUB (P3) – the black ribbon at the marker `ribbon` of a house (docs/PHASE7_DESIGN.md §2.9, §3.4):
## visible while Village.mourning_house(day) == house_id (derived, not saved). Presentation only.
## W1 (P3) fills the bodies; the signatures are the contract.

@export var house_id: StringName


## Shows / hides the ribbon after Village.mourning_house.
func refresh() -> void:
	pass
