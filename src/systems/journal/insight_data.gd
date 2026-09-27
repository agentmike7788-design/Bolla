class_name InsightData
extends Resource
## An insight = exactly the required clues linked (docs/PHASE4_DESIGN.md §2.12):
## data/journal/insights/<id>.tres.

@export var id: StringName
@export var order: int = 0
@export var title: String = ""
## The open question shown once one required clue is found.
@export var question: String = ""
@export_multiline var text: String = ""
## 2–3 ClueData ids, order irrelevant.
@export var requires: Array[StringName] = []
@export var sets_flag: StringName = &""
@export var optional: bool = false
## Story corpse renamed on unlock (S5 → "Kaspar Dorn").
@export var rename_story: StringName = &""
@export var rename_to: String = ""
