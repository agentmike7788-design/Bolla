class_name FriendStepData
extends Resource
## One step of a friendship story (docs/PHASE8_DESIGN.md §2.4, §3.4) – sub-resource of FriendStoryData.

@export var step: int
@export var title: String
## Relationship needed (step 1 ≥ 40, step 2 ≥ 55, step 3 ≥ 70).
@export var min_value: int
## Dialogue syntax (insight_not_lorenz, robber_known, apprentice_level_gte:2 …).
@export var conditions: PackedStringArray = []
## of_<npc>_<n>[_alt]; the first variant whose conditions hold.
@export var order_ids: Array[StringName] = []
## Dialogue nodes of the offer / the end.
@export var start_node: StringName
@export var end_node: StringName
## Reward: relationship +6 / +8 / +10, reputation on single steps, a flag (friend_<npc>_<n>).
@export var reward_rel: int
@export var reward_rep: int = 0
@export var reward_flag: StringName = &""
## At least gap_days after the step before; fallback_event = the substitute date (§2.4 „Ersatz").
@export var gap_days: int = 1
@export var fallback_event: StringName = &""
