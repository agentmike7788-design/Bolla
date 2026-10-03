class_name SpecimenFindingData
extends Resource
## A finding card of a specimen (docs/PHASE7_DESIGN.md §2.6.3, §3.4): data/anatomy/findings/<id>.tres.
## SpecimenRules.finding_for picks the first matching finding by `priority` (higher first), then
## by the order of §2.6.3; b_plain (priority 0, no condition) is the fallback of every organ.

@export var id: StringName
## The organ this finding belongs to (&"" = every organ, b_plain).
@export var organ: StringName
## Higher wins.
@export var priority: int = 0
## Conditions (all optional, &"" = any): the story corpse, the hidden cause (CorpseRecord.hidden_cause),
## the shown cause (CorpseRecord.cause_id), a trait (strange_wound, tattoo).
@export var story_id: StringName = &""
@export var hidden_cause: StringName = &""
@export var cause_id: StringName = &""
@export var requires_trait: StringName = &""
@export_multiline var text: String
## Clue added to the journal with the card (&"" = none).
@export var clue_id: StringName = &""
## Death notice „laut Quast: Arsenik" (&"" = none).
@export var reveals_cause: StringName = &""
