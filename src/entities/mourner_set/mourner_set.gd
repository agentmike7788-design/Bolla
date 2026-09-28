class_name MournerSet
extends Node3D
## STUB (P4) – up to 4 silent mourners at the markers pew_seat_1…4 inside the chapel
## (docs/PHASE6_DESIGN.md §2.4, §3.4): shown with a 0.6 s fade at the start of a service, hidden at
## its end; no names, no dialogue. W1 (P4) fills the bodies; the signatures are the contract.

const FADE_SECONDS := 0.6
const SEAT_PREFIX := "pew_seat_"


func show_mourners(_count: int) -> void:
	pass


func hide_mourners() -> void:
	pass
