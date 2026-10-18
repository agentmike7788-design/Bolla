class_name StrangerBell
extends Node
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §2.5.1 „läutet einmal kurz die Torglocke", Lead W2): when Brenneisen arrives at
## the gate (Stranger: stranger_event arrived / gate, 14:10, once a day) the gate bell rings and visibly swings
## (GateBell.ring with its cue; the HUD line is the Stranger's own, so no second note). Display / sound only.

const BELL_GROUP := &"gate_bell"
const KIND_ARRIVED := &"arrived"
const AT_GATE := "gate"

## How often it rang for him (tests).
var rings: int = 0


func _ready() -> void:
	EventBus.stranger_event.connect(_on_stranger_event)


func _on_stranger_event(kind: StringName, detail: String) -> void:
	if kind != KIND_ARRIVED or detail != AT_GATE or not is_inside_tree():
		return
	var bell := get_tree().get_first_node_in_group(BELL_GROUP)
	if bell != null and bell.has_method(&"ring"):
		bell.call(&"ring", "")
		rings += 1
