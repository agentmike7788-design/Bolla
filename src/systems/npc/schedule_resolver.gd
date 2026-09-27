class_name ScheduleResolver
extends RefCounted
## Deterministic NPC schedule lookup.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

static func entry_at(schedule: NpcSchedule, minute_of_day: int) -> ScheduleEntry:
	push_warning("STUB ScheduleResolver.entry_at")
	return null


static func progress(entry: ScheduleEntry, minute_f: float) -> float:
	push_warning("STUB ScheduleResolver.progress")
	return 0.0


static func arrival_minute(entry: ScheduleEntry) -> int:
	push_warning("STUB ScheduleResolver.arrival_minute")
	return 0
