class_name NpcLifeConfig
extends Resource
## Village life of Phase 8 (docs/PHASE8_DESIGN.md §1.2, §1.5, §2.1, §3.4): data/config/npc_life_config.tres.
## The class defaults carry the contract values (data == fixture == class default until the hand-over).

## Phase 8 opens with the Phase-7 chapter (§1.2): the first minute ≥ intro_minute (06:00) after
## unlock_flag sets open_flag and stores the day in open_day_flag.
@export var open_flag: StringName = &"p8_open"
@export var open_day_flag: StringName = &"p8_open_day"
@export var unlock_flag: StringName = &"name_in_village_complete"
@export var intro_minute: int = 360
## §2.1.1: one mood per villager and day, rolled at 06:00 from day and npc_id.
@export var moods: Array[StringName] = [&"plain", &"cheerful", &"low", &"cross"]
@export var mood_weights: Dictionary[StringName, int] = {&"plain": 70, &"cheerful": 15, &"low": 10, &"cross": 5}
## Precedence rules of §2.1.1 in order (the first that matches wins): {trigger, mood, npcs (empty =
## everyone / the circle / the person, see trigger), days (how far back the cause counts: 0 = today,
## 1 = yesterday, 2 = today or yesterday), events (the NpcLife events that count; rumor only)}.
## Triggers: festival (a festival day, everyone) · mourning_circle (a mourning ribbon at a house of
## VillagerData.circle, the circle) · own_step (a story step of this person, the person) · rumor (bad
## talk about the gravekeeper) · sick_light (a sick light in the village).
@export var mood_rules: Array[Dictionary] = [
	{"trigger": &"festival", "mood": &"cheerful", "npcs": [], "days": 0, "events": []},
	{"trigger": &"mourning_circle", "mood": &"low", "npcs": [], "days": 2, "events": []},
	{"trigger": &"own_step", "mood": &"cheerful", "npcs": [], "days": 1, "events": []},
	{"trigger": &"rumor", "mood": &"cross", "npcs": [&"priest", &"washer"], "days": 1, "events": [&"lecture_rumor", &"specimen_sold_villager"]},
	{"trigger": &"rumor", "mood": &"cross", "npcs": [&"mayor"], "days": 1, "events": [&"grave_disturbed"]},
	{"trigger": &"sick_light", "mood": &"low", "npcs": [&"surgeon", &"priest", &"washer"], "days": 0, "events": []},
]
## Relationship of the talk of the day by mood (cheerful +2, cross 0; §2.1.1).
@export var talk_gain_by_mood: Dictionary[StringName, int] = {&"plain": 1, &"cheerful": 2, &"low": 1, &"cross": 0}
## „[Zuhören]" (mood low): 10 minutes, once per day and person.
@export var listen_minutes: int = 10
## §2.1.2: a chatter starts when the gravekeeper is ≤ chatter_distance m away; 3.5 s per line.
@export var chatter_distance: float = 10.0
@export var chatter_line_seconds: float = 3.5
## §2.1.3: event → days the remark stays valid (2).
@export var reactions: Dictionary[StringName, int] = {&"apprentice_hired": 2, &"jakob_scolded": 2, &"wish_done": 2,
		&"grave_disturbed": 2, &"robber_reported": 2, &"robber_let_go": 2, &"lights_all": 2, &"kathrein_danced": 2,
		&"noise_at_grave": 2}
## §1.5: the chapter „Wer heraufkommt".
@export var goal_levels: int = 2
@export var goal_wishes: int = 5
@export var goal_kin: int = 3
@export var goal_steps: int = 6
@export var goal_full_stories: int = 1
@export var goal_insight: StringName = &"i_underlined"
@export var chapter_id: StringName = &"who_comes_up"
@export var goal_flag: StringName = &"who_comes_up_complete"
