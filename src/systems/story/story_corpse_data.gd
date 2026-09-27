class_name StoryCorpseData
extends Resource
## A fixed story corpse S1–S5 (docs/PHASE4_DESIGN.md §2.11): data/story/<id>.tres.

@export var id: StringName
## Delivery order (1 … 5).
@export var order: int = 0
@export var earliest_day: int = 1
@export var display_name: String = ""
@export var age: int = 0
@export var cause_id: StringName = &""
@export var traits: Array[StringName] = []
## Story corpses carry no valuables (0, no trait).
@export var valuables_coins: int = 0
## Corpse look index (−1 = derived from name / age as before).
@export var look: int = -1
## FindData ids (story_only) of this corpse.
@export var finds: Array[StringName] = []
## Osric's notification on arrival.
@export_multiline var arrival_note: String = ""
@export var is_finale: bool = false
