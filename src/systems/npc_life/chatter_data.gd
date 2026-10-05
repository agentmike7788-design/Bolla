class_name ChatterData
extends Resource
## One chatter – two people exchanging 2–4 speech bubbles (docs/PHASE8_DESIGN.md §2.1.2, §3.4):
## data/npc_life/chatter/<id>.tres. Pure display (only ch_rumor_robber sets a flag).

@export var id: StringName
## Region of the place (&"village" | &"graveyard").
@export var region: StringName = &"village"
## [a, b] – the two speakers (villager npc ids, apprentice, beggar, peddler, kin ids for mourners).
@export var npcs: Array[StringName] = []
## Waypoint of the meeting.
@export var place: StringName
## Minutes of day [from, to].
@export var window: Vector2i
## Dialogue syntax (rel_tier, flag, rep_tier …) + mood:<npc>:<mood>, fest_day:<id>, sick_light.
@export var conditions: PackedStringArray = []
## Lines alternating a / b, 2–4.
@export var lines: PackedStringArray = []
## Flag set when the chatter has run (only ch_rumor_robber → robber_known).
@export var sets_flag: StringName = &""
