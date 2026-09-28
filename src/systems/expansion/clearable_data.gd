class_name ClearableData
extends Resource
## One obstacle kind (docs/PHASE3_DESIGN.md §2.1): data/clearables/<kind>.tres.

@export var id: StringName
@export var display_name: String = ""
## Verb of the prompt, e.g. "roden" → "[E] Brombeeren roden (30 Min)".
@export var verb: String = ""
@export var minutes: int = 30
@export var animation: StringName = &"dig"
## Items consumed when clearing (fence_gap: 2 wood, 1 iron_fittings).
@export var cost: Dictionary[StringName, int] = {}
## Items gained when clearing.
@export var yield_items: Dictionary[StringName, int] = {}
@export var model: PackedScene
## Only fence_gap: shown once repaired (ph_prop_fence_iron).
@export var repaired_model: PackedScene
# Phase 5 (docs/PHASE5_DESIGN.md §2.3): tool kind whose tier sets the minutes
# (ActionConfig.tool_minutes; &"" = none) and the minimum tier needed (boulder: pickaxe 1).
@export var tool_kind: StringName = &""
@export var min_tier: int = 0
