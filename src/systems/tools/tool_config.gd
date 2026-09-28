class_name ToolConfig
extends Resource
## Tool kinds of the tool belt (docs/PHASE5_DESIGN.md §2.3, §3.4): data/config/tool_config.tres.
## Tier 0 is always there (no item) except for the pickaxe.

@export var kinds: Array[StringName] = [&"shovel", &"axe", &"pickaxe"]
@export var labels: Dictionary[StringName, String] = {&"shovel": "Schaufel", &"axe": "Axt", &"pickaxe": "Spitzhacke"}
## Name of the tier-0 tool ("" = none: the pickaxe starts at tier 1).
@export var base_names: Dictionary[StringName, String] = {&"shovel": "Alte Schaufel", &"axe": "Altes Beil", &"pickaxe": ""}
## Where the next tier comes from ("Holzfälleraxt nötig – Esse").
@export var source_hint: Dictionary[StringName, String] = {&"shovel": "Esse", &"axe": "Esse", &"pickaxe": "Osric"}
