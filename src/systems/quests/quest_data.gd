class_name QuestData
extends Resource
## One chain (docs/PHASE9_DESIGN.md §2.1, §3.4): data/quests/<id>.tres – q_who_knows (main, 6 steps),
## q_letters (side, 5 steps), q_case (side, 5 steps). An ordered list of steps; a step is done by an event
## that already exists (flag, clue, insight, order of category quest, note, choice, ending).

const KIND_MAIN := &"main"
const KIND_SIDE := &"side"
const KINDS: Array[StringName] = [KIND_MAIN, KIND_SIDE]

@export var id: StringName
## &"main" | &"side"
@export var kind: StringName = &"side"
@export var title: String
@export_multiline var summary: String
## npc_id of the giver (&"" = none; shown in „Vorhaben").
@export var giver: StringName = &""
## Dialogue-condition syntax (DialogueConditions), e.g. "p9_open"; all must hold.
@export var open_conditions: PackedStringArray = []
@export var steps: Array[QuestStepData] = []
@export var endings: Array[QuestEndingData] = []
## Sort order (Database.quests).
@export var order: int = 0
