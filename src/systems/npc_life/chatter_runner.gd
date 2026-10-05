class_name ChatterRunner
extends Node
## STUB (P1) – Systems/ChatterRunner (docs/PHASE8_DESIGN.md §2.1.2, §3.1, §3.4), group &"chatter",
## not saved: 2 Hz; starts a chatter (ChatterData) when both speakers are at the place in its window
## and the gravekeeper is ≤ 10 m away in the same region; one chatter per region at once, each once a
## day (the list lives in NpcLife); EventBus.chatter_line per line. Pure display (ch_rumor_robber sets
## robber_known). Runs from village_open on (§1.2).
## W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"chatter"


func _init() -> void:
	add_to_group(GROUP, true)


func update_now() -> void:
	pass


## The chatter running in the region or &"".
func running(_region_id: StringName) -> StringName:
	return &""


## From day + the saved list in NpcLife (once per day).
func seen_today(_chatter_id: StringName) -> bool:
	return false
