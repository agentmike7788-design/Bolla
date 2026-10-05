class_name Fiddler
extends Node3D
## STUB (P4) – the fiddler from the „Stumpf" at the inn stove (docs/PHASE8_DESIGN.md §2.7.1, §3.4, §8.1):
## seated, no rig; the bow arm (child mesh `bow`) sways in GDScript only inside the festival window.
## No interaction.
## W1 (P4) fills the bodies; the signatures are the contract.

## Shown while this GameState flag equals TimeManager.day.
@export var fest_flag: StringName = &"fest_kathrein_day"


func refresh() -> void:
	pass
