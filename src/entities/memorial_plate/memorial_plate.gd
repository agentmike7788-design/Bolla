class_name MemorialPlate
extends Node3D
## STUB (P4) – the name plate „Konrad Wackernagel" on the memorial board of the church
## (docs/PHASE8_DESIGN.md §2.4 Rosine 2, §3.4, §4.6 D7): visible from friend_innkeeper_2 on. No interaction.
## W1 (P4) fills the bodies; the signatures are the contract.

const FLAG := &"friend_innkeeper_2"


## Visible ⇔ FLAG.
func refresh() -> void:
	pass
