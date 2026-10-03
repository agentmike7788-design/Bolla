class_name DeductionData
extends Resource
## A cause-of-death deduction in the journal (docs/PHASE7_DESIGN.md §2.6.5, §3.4): data/anatomy/deductions/<id>.tres.

@export var id: StringName
## The cause the player has to choose (CorpseTables cause or arsenic, dead_before_water, drink, unexplained).
@export var cause_id: StringName
## At least one of these cards (e.g. b_white_stomach | b_pale_liver).
@export var needs_any: Array[StringName] = []
## All of these (findings, finds, teachings).
@export var needs_all: Array[StringName] = []
## Clue added the first time (&"" = none).
@export var clue_id: StringName = &""
@export_multiline var text: String
## true: the cause becomes CorpseRecord.revealed_cause (death notice „gedeutet: …").
@export var reveals_cause: bool = true
