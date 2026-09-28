class_name Stonemasonry
extends Node
## STUB (P4) – Systems/Stonemasonry (docs/PHASE5_DESIGN.md §2.5, §3.1, §3.4, §5.1), groups
## &"stonemasonry", &"saveable": carving designed stones for one grave each at the mason's bench,
## the rack of finished stones (WorkshopConfig.ready_slots) and setting them at the grave.
## W1 (P4) fills the bodies; the signatures are the contract.

const GROUP := &"stonemasonry"

@export var save_id: String = "stonemasonry"
@export var save_order: int = 35


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## [{grave_id, name, section, marker, quality, ready: bool}]
func eligible_graves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


## {quality_before, quality_after, lines, text, fits, minutes, inputs, missing, block_reason}
func preview(_grave_id: String, _design: StoneDesign) -> Dictionary:
	return {}


func order_block_reason(_grave_id: String, _design: StoneDesign, _inv: Inventory) -> String:
	return ""


## After the timed action; takes the material atomically; order_id | "";
## stone_order_changed(&"ready"); stats.crafted.
func carve(_grave_id: String, _design: StoneDesign, _inv: Inventory) -> String:
	return ""


func ready_stones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


func ready_for(_grave_id: String) -> Dictionary:
	return {}


func discard(_order_id: String) -> bool:
	return false


## From GravePlot after 20 min → Graveyard.set_designed_stone; quality difference.
func set_stone(_grave_id: String, _inv: Inventory) -> int:
	return 0


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
