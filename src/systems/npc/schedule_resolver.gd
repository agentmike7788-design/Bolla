class_name ScheduleResolver
extends RefCounted
## Deterministic NPC schedule lookup (docs/VERTICAL_SLICE_DESIGN.md §3.4).
## Pure functions of the schedule data and a clock time; the entries of a schedule
## do not have to be sorted in the resource.

const MINUTES_PER_DAY := 1440


## Entry active at minute_of_day (wrapped into 0..1439): the latest entry with
## start_minute <= t; before the first start of the day the latest entry of the day
## (the one running over midnight). Equal starts: the later array entry wins.
## null (with a warning) for a null or empty schedule.
## Phase 7 (§3.4, P1): `day` ≥ 0 – entries with a today_flag count only when that flag == day (and win
## a tie of start_minute); day -1 (every call before Phase 7) skips them. STUB (P1): `day` is not read
## yet (no schedule has a today_flag entry before P6).
static func entry_at(schedule: NpcSchedule, minute_of_day: int, _day: int = -1) -> ScheduleEntry:
	if schedule == null or schedule.entries.is_empty():
		push_warning("[ScheduleResolver] entry_at(): schedule has no entries")
		return null
	var t := posmod(minute_of_day, MINUTES_PER_DAY)
	var active: ScheduleEntry = null
	var latest: ScheduleEntry = null
	for entry: ScheduleEntry in schedule.entries:
		if entry == null:
			continue
		if latest == null or entry.start_minute >= latest.start_minute:
			latest = entry
		if entry.start_minute <= t and (active == null or entry.start_minute >= active.start_minute):
			active = entry
	return active if active != null else latest


## Travel progress 0..1 along entry.path at minute_f:
## clamp(wrap(minute_f - start, 0, 1440) / travel_minutes, 0, 1); no travel time → 1.
static func progress(entry: ScheduleEntry, minute_f: float) -> float:
	if entry == null:
		push_warning("[ScheduleResolver] progress(): no entry")
		return 0.0
	if entry.travel_minutes <= 0:
		return 1.0
	var elapsed := wrapf(minute_f - float(entry.start_minute), 0.0, float(MINUTES_PER_DAY))
	return clampf(elapsed / float(entry.travel_minutes), 0.0, 1.0)


## Minute of day at which the NPC reaches the end of entry.path: (start + travel) % 1440.
## -1 (with a warning) without an entry.
static func arrival_minute(entry: ScheduleEntry) -> int:
	if entry == null:
		push_warning("[ScheduleResolver] arrival_minute(): no entry")
		return -1
	return posmod(entry.start_minute + maxi(entry.travel_minutes, 0), MINUTES_PER_DAY)
