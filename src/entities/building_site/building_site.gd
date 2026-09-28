class_name BuildingSite
extends Node3D
## STUB (P1) – Entities/site_<id> (docs/PHASE6_DESIGN.md §2.1, §3.4, §4): visible from
## buildings_open; the model of the current level (0 = BuildingData.model_site), collision and the
## prompt „[E] Bauplatz: Gruft" / „[E] Gruft ausbauen (Stufe 2)" at the marker "build". [E] opens
## the building panel (&"building"); request_upgrade runs the TimedAction → Buildings.upgrade.
## W1 (P1) fills the bodies; the signatures are the contract.

const PANEL := &"building"
const PROMPT_SITE := "[E] Bauplatz: %s"
const PROMPT_UPGRADE := "[E] %s ausbauen (Stufe %d)"
const BUILDINGS_GROUP := &"buildings"

@export var building_id: StringName

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Model of the level, collision, prompt.
func refresh() -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Panel &"building": TimedAction minutes (not cancellable) → Buildings.upgrade.
func request_upgrade() -> void:
	pass


## Shed ≥ 2: fetch the missing building materials (ShedSupply).
func request_fetch() -> void:
	pass
