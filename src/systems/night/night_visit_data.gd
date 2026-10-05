class_name NightVisitData
extends Resource
## One night visit of a sick-light path (docs/PHASE8_DESIGN.md §1.6, §3.4) – sub-resource of NightPathData.

## priest | surgeon | washer.
@export var npc_id: StringName
## Night = p8_open_day + night_offset (a minute < 360 belongs to the night that began the evening before).
@export var night_offset: int
## Minutes of day of going in / coming out (leave < enter: after midnight).
@export var enter_minute: int
@export var leave_minute: int
## Clue on observing it (c_n_quast_visit, c_n_lenz_visit, c_n_liesel_watch).
@export var clue_id: StringName
@export var animation: StringName = &"walk"
