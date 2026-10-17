class_name QuestChoiceData
extends Resource
## One choice of a choice step (docs/PHASE9_DESIGN.md §2.1, §3.4). Chosen is chosen (no way back); the
## consequences are never shown as numbers beforehand.

@export var id: StringName
@export var label: String
## Dialogue-condition syntax; a choice whose conditions fail is dimmed with block_text.
@export var conditions: PackedStringArray = []
## Dimmed with a reason (ending A without the letter).
@export var block_text: String = ""
## DialogueActions syntax (rel_add, rep_event, piety_event, set_flag, goodwill …).
@export var actions: PackedStringArray = []
## Sets the ending of the chain (else the next step).
@export var ending: StringName = &""
