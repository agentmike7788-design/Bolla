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
