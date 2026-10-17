class_name QuestEndingData
extends Resource
## One ending of a chain (docs/PHASE9_DESIGN.md §2.2.7, §3.4): q_who_knows away / stay / public / silent.

@export var id: StringName
@export var title: String
@export_multiline var summary: String
## Set when the ending is chosen (q_end_away …).
@export var flag: StringName
## Flag with which the ending is „settled" (sieber_gone / D3 buried); &"" = settled at once.
@export var settle_on: StringName = &""
## Closing line of the chapter panel (§2.11).
@export_multiline var closing_line: String
