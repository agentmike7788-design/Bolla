class_name ScheduleBuilder
extends RefCounted
## STUB (P1) – runtime schedules (docs/PHASE8_DESIGN.md §2.2.3, §2.5.1, §2.7, §2.6.3, §3.4): visits, the
## apprentice, festivals and the robber build NpcSchedules from ScheduleEntries at runtime
## (Npc.set_runtime_schedule; not saved – rebuilt from plan + clock).
## W1 (P1) fills the bodies; the signatures are the contract.


## A walk along `path` (waypoint ids; from_wp first) from start_minute; travel_minutes from the
## polyline: length / NpcConfig.walk_m_per_minute (3.2).
static func walk(_from_wp: StringName, _path: PackedStringArray, _start_minute: int, _region: StringName, _world: Node) -> ScheduleEntry:
	return ScheduleEntry.new()


## Staying at at_wp from start_minute with `animation`.
static func stay(_at_wp: StringName, _start_minute: int, _animation: StringName, _dialogue_id: StringName = &"", _visible := true) -> ScheduleEntry:
	return ScheduleEntry.new()


## Sorted by start_minute, gaps = invisible.
static func build(_entries: Array[ScheduleEntry]) -> NpcSchedule:
	return NpcSchedule.new()
