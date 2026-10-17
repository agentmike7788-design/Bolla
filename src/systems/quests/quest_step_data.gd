class_name QuestStepData
extends Resource
## One step of a chain (docs/PHASE9_DESIGN.md §2.1, §3.4) – a sub-resource of QuestData. Strictly in order;
## visible once the previous one is done; events before that count (checked when it becomes visible).

const ON_FLAG := &"flag"
const ON_CLUE := &"clue"
const ON_INSIGHT := &"insight"
const ON_ORDER := &"order"
const ON_NOTE := &"note"
const ON_CHOICE := &"choice"
const ON_ENDING := &"ending"
const COMPLETE_ON: Array[StringName] = [ON_FLAG, ON_CLUE, ON_INSIGHT, ON_ORDER, ON_NOTE, ON_CHOICE, ON_ENDING]

@export var id: StringName
## Journal („Vorhaben") + HUD.
@export var title: String
@export var hint: String
## &"flag" | &"clue" | &"insight" | &"order" | &"note" | &"choice" | &"ending"
@export var complete_on: StringName
## Flags / clues / insights / orders / note keys.
@export var complete_ids: Array[StringName] = []
## 0 = all; else ≥ n (notes: different arguments).
@export var complete_count: int = 0
## Orders of category quest offered with the step.
@export var order_ids: Array[StringName] = []
## A choice step: 2–4 choices (complete_on choice).
@export var choices: Array[QuestChoiceData] = []
## Deadline: GameState flag (a day) + offset, checked at 06:00; when it passes, fallback_choice applies.
@export var deadline_flag: StringName = &""
@export var deadline_offset: int = 0
@export var fallback_choice: StringName = &""
