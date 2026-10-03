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
# Phase 7 (docs/PHASE7_DESIGN.md §2.9, §3.4; logic StoryDirector, P6)
## Due at the earliest after_days after the day stored in this GameState flag (D1:
## village_open_day + 8; &"" = earliest_day only).
@export var after_flag: StringName = &""
@export var after_days: int = 0
## A place in this section stays reserved until the corpse is buried (&"" = any section).
@export var section: StringName = &""
## Only due while this flag is set (D1: linden_consecrated).
@export var requires_flag: StringName = &""
## Set at 00:00 of the delivery day (D1: hagedorn_dead – her Npc disappears).
@export var due_flag: StringName = &""
