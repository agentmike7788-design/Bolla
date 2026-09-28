class_name RecipeData
extends Resource
## Crafting recipe (data/recipes/<id>.tres).

@export var id: StringName
@export var display_name: String = ""
@export var inputs: Dictionary[StringName, int] = {}
@export var output_id: StringName
@export var output_amount: int = 1
## Game minutes the craft takes (runs as a timed action).
@export var craft_minutes: int = 30
@export var station: StringName = &"workbench"
## Workbench group (Phase 3 §2.2): &"grave", &"decor" or &"tool".
@export var category: StringName = &"grave"
# Phase 5 (docs/PHASE5_DESIGN.md §2.1, §2.4): runs on its own after the craft minutes (the
# charcoal kiln: Workshop.start_job, at most one per station). New categories: &"material".
@export var background: bool = false
