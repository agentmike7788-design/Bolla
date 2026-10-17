class_name QuestConfig
extends Resource
## The chain core (docs/PHASE9_DESIGN.md §2.1, §1.2, §1.5, §3.4): data/config/quest_config.tres.
## Opening of Phase 9 (p9_open on the first morning after the Phase-8 chapter), the chapter
## „Wer weiß, wann?" and the journal tab „Vorhaben".

## Set by Quests.apply_morning (first minute ≥ intro_minute after unlock_flag) / Quests.post_load (v7 states).
@export var open_flag: StringName = &"p9_open"
## Day of the opening (GameState flag, int).
@export var open_day_flag: StringName = &"p9_open_day"
## The Phase-8 chapter flag that unlocks the chains.
@export var unlock_flag: StringName = &"who_comes_up_complete"
## 06:00 – the morning check (idempotent).
@export var intro_minute: int = 360
## §1.5: the chapter.
@export var chapter_id: StringName = &"who_knows_when"
@export var goal_flag: StringName = &"who_knows_when_complete"
## §1.5 (1): the main chain ended (A, B, C or silent).
@export var goal_main: StringName = &"q_who_knows"
## §1.5 (2): „Briefe ohne Antwort" up to step l4 and ≥ 5 letters decided.
@export var goal_letters: StringName = &"q_letters"
@export var goal_letters_step: StringName = &"l4"
@export var goal_letters_decided: int = 5
## §1.5 (3): ≥ 2 larger requests done since p9_open.
@export var goal_large_requests: int = 2
## §2.1: exactly one entry pinned to the HUD objective line.
@export var max_pinned: int = 1
