class_name NpcLod
extends Node
## STUB (P1) – Systems/NpcLod (docs/PHASE7_DESIGN.md §3.1, §3.4, §9): 2 Hz (NpcConfig.governor_hz);
## ranks the Npc of the active region by distance to the camera focus: the nearest max_full → level 0,
## up to lod_rest_distance → 1, beyond → 2; reports a villager closer than remark_distance to
## Relationships.remark (once per person and day). Not saved. W1 (P1) fills the bodies; the
## signatures are the contract.

const GROUP := &"npc_lod"

var config: NpcConfig


func _init() -> void:
	add_to_group(GROUP)


func update_now() -> void:
	pass


## 0 full · 1 reduced · 2 resting.
func lod_of(_npc: Npc) -> int:
	return 0
