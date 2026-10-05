class_name SickLight
extends Node3D
## STUB (P7) – the sick light in a window (docs/PHASE8_DESIGN.md §1.6, §3.1, §3.4, §4.6 D3, §4.9): at the
## marker light_window of house_ott / house_kehr; the existing window light stays on all night and a candle
## (emissive material, no new light) stands in the window while NightPaths.sick_houses has the house.
## Pure display, no interaction.
## W1 (P7) fills the bodies; the signatures are the contract.

@export var house: StringName = &""


## Candle on ⇔ the house is in NightPaths.sick_houses(now).
func refresh() -> void:
	pass
