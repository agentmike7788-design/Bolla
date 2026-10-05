class_name FestDecor
extends Node3D
## STUB (P4) – the Kathrein decoration of the inn (docs/PHASE8_DESIGN.md §2.7.1, §3.4, §4.6 D6): fir green
## and ribbons on two beams, the tables against the wall – shown only on the festival day (fest_flag).
## Pure display, no interaction.
## W1 (P4) fills the bodies; the signatures are the contract.

## Shown while this GameState flag equals TimeManager.day (fest_kathrein_day).
@export var fest_flag: StringName = &"fest_kathrein_day"


func refresh() -> void:
	pass
