class_name WorkshopConfig
extends Resource
## Workshop unlock, flags and the chapter "Namen in Stein" (docs/PHASE5_DESIGN.md §1.2, §1.5,
## §2.1): data/config/workshop_config.tres.

## Phase-3 goal that opens Phase 5.
@export var unlock_flag: StringName = &"cemetery_complete"
## Set by Workshop.apply_morning (first minute ≥ intro_minute) or Workshop.post_load.
@export var open_flag: StringName = &"workshop_open"
## Osric's Steinbruchbrief (opens the Ostpforte, the clay pit, flax, the quarry).
@export var license_flag: StringName = &"bruch_license"
## 06:00
@export var intro_minute: int = 360
@export var goal_stations: Array[StringName] = [&"mason", &"loom", &"forge"]
@export var goal_tiers: Dictionary[StringName, int] = {&"shovel": 1, &"axe": 1, &"pickaxe": 2}
## Master stones (stone_master with an inscription) set.
@export var goal_master_stones: int = 1
@export var chapter_id: StringName = &"names_in_stone"
@export var goal_flag: StringName = &"names_in_stone_complete"
## Places for finished stones at the mason's bench.
@export var ready_slots: int = 3
