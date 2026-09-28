class_name GatherManager
extends Node
## STUB (P2) – Systems/Gathering (docs/PHASE5_DESIGN.md §2.2, §3.1, §3.4, §5.1), groups
## &"gathering", &"saveable": the state of every GatherNode (the nodes themselves are not saved).
## W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"gathering"

@export var save_id: String = "gathering"
@export var save_order: int = 25


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func register(_node_id: String, _data: GatherNodeData) -> void:
	pass


func state_of(_node_id: String) -> Dictionary:
	return {}


func charges(_node_id: String) -> int:
	return 0


func stage(_node_id: String) -> StringName:
	return GatherRules.STAGE_FULL


## After the timed action; 0 = refused. resource_gathered, gather_node_changed;
## alder → stats.trees_felled.
func gather(_node_id: String, _inv: Inventory, _tier: int) -> int:
	return 0


## day_started + post_load.
func refresh(_day: int) -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass


func post_load() -> void:
	pass
