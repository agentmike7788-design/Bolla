class_name Workshop
extends Node
## STUB (P1) – Systems/Workshop (docs/PHASE5_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.4, §5.1, §5.2),
## groups &"workshop", &"saveable": built stations, the one background job per station (the
## charcoal kiln), workshop_open, the chapter "Namen in Stein" and the one-time clearing of decor
## on the workyard. W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"workshop"

@export var save_id: String = "workshop"
@export var save_order: int = 30
## Footprint + margin + access of the workyard (the builder fills them from
## layout.workyard.blocked_rects); decor in them is cleared once (post_load, §5.2 step 5).
@export var workyard_rects: Array[Rect2] = []

## Rules; null = data/config/workshop_config.tres (resolved lazily).
var config: WorkshopConfig


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Flag workshop_open.
func is_open() -> bool:
	return false


func is_built(_station_id: StringName) -> bool:
	return false


func built() -> Array[StringName]:
	return []


## Atomic: items + coins at the end of the build; station_built, coins_spent(&"build"); check_goal.
func build(_station_id: StringName, _inv: Inventory) -> bool:
	return false


## Only background recipes; ingredients at once; end = now + craft_minutes.
func start_job(_station_id: StringName, _recipe: RecipeData, _inv: Inventory) -> bool:
	return false


## {} | {recipe, end_total, ready: bool}
func job_of(_station_id: StringName) -> Dictionary:
	return {}


## Yield into the inventory (full → 0, the job stays).
func collect(_station_id: StringName, _inv: Inventory) -> int:
	return 0


func goal_progress() -> Dictionary:
	return {"done": 0, "total": 0, "missing": PackedStringArray()}


## Chapter §1.5 once.
func check_goal() -> void:
	pass


## Idempotent: workshop_open from unlock_flag at the first minute ≥ intro_minute.
func apply_morning(_day: int) -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass


## workshop_open at once when unlock_flag holds; decor on the workyard cleared (§5.2).
func post_load() -> void:
	pass
