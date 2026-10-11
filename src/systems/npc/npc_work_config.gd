class_name NpcWorkConfig
extends Resource
## G8 Runde 4 (user: „ja die sollen eigene arbeitsbewegungen bekommen"): the villagers' work at their work places
## (data/config/npc_work_config.tres). The clips themselves are named by the schedule entries (ScheduleEntry.animation;
## data/npc/*_schedule.tres) or, for schedules built in code, by runtime_clips; this resource says which clips are
## work (the figure interrupts them for the gravekeeper) and how Osric's pipe smokes.

## Clips that are work at a work place: while the gravekeeper stands closer than pause_range (or talks to the figure)
## the figure stops, turns to him and plays pause_clip (talk_clip during the dialogue).
@export var work_clips: Array[StringName] = []
@export var pause_range: float = 2.8
@export var pause_clip: StringName = &"idle"
@export var talk_clip: StringName = &"talk"
## Work places whose work faces another way than the standing spot's own facing (layout waypoint_facing, which
## is for standing and talking): waypoint -> heading in degrees (0 = +Z) while the figure works there. Liesel at
## the washing stones faces the brook (the Phase-7 spot v_wash faces the green).
@export var work_facing: Dictionary[StringName, float] = {}
## Work clips of schedules built in code (key -> clip): &"apprentice_inn" (Jakob helping Rosine in the inn of an
## evening), &"washer_table" (Liesel's corpse wash at the crypt table).
@export var runtime_clips: Dictionary[StringName, StringName] = {}
## Pipe smoke (Osric's evening pipe): clip -> the moments of its cycle (fractions) at which a puff leaves the marker.
@export var puff_clips: Dictionary[StringName, PackedFloat32Array] = {}
## Node of the model the puffs leave from (a bone marker at the pipe bowl); without it puff_fallback above the root.
@export var puff_marker: String = "pipe_smoke"
@export var puff_fallback: Vector3 = Vector3(-0.1, 1.45, 0.25)
@export var puff_amount: int = 7
@export var puff_lifetime: float = 2.6
@export var puff_size: float = 0.055
## Upward drift (m/s²) and the start speed of a puff (m/s).
@export var puff_rise: float = 0.18
@export var puff_speed: float = 0.22
@export var puff_spread_deg: float = 25.0
@export var puff_color: Color = Color(0.8, 0.78, 0.74, 0.6)


## The work clip for a schedule built in code (key of runtime_clips), else `fallback`.
func clip_for(key: StringName, fallback: StringName) -> StringName:
	return runtime_clips.get(key, fallback)


## clip_for of data/config/npc_work_config.tres (`fallback` without it).
static func runtime_clip(key: StringName, fallback: StringName) -> StringName:
	var cfg := Database.config(&"npc_work_config") as NpcWorkConfig
	return cfg.clip_for(key, fallback) if cfg != null else fallback


func is_work(clip: StringName) -> bool:
	return clip != &"" and clip in work_clips


## The working heading (rad) at waypoint `id`, NAN = the waypoint's own facing.
func facing_at(id: StringName) -> float:
	return deg_to_rad(float(work_facing[id])) if work_facing.has(id) else NAN


## The puff moments of `clip` (empty = it does not smoke).
func puffs(clip: StringName) -> PackedFloat32Array:
	return puff_clips.get(clip, PackedFloat32Array())
