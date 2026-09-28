class_name BuildingsConfig
extends Resource
## Rules of the buildings (docs/PHASE6_DESIGN.md §1.2, §1.5, §2.1): data/config/buildings_config.tres.

## Phase 6 opens on the first morning (first minute ≥ intro_minute) after unlock_flag.
@export var unlock_flag: StringName = &"names_in_stone_complete"
@export var open_flag: StringName = &"buildings_open"
@export var intro_minute: int = 360
## Chapter „Unter Dach und Erde": minimum levels, held services (buried + marked), reinterred boxes.
@export var goal_levels: Dictionary[StringName, int] = {&"crypt": 2, &"chapel": 2, &"shed": 2}
@export var goal_services: int = 1
@export var goal_reinterred: int = 1
@export var chapter_id: StringName = &"roof_and_earth"
@export var goal_flag: StringName = &"roof_and_earth_complete"
## Set once the decor on the site rects was cleared (§5.2 step 5).
@export var cleared_flag: StringName = &"building_sites_cleared"
