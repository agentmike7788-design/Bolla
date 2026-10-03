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
## Phase 7 (docs/PHASE7_DESIGN.md §3.4): entries with a today_flag count only on `day` ≥ 0 while that
## GameState flag equals `day` (the priest's consecration day), and such a valid entry wins a tie of
## start_minute over a plain one. day -1 (every call before Phase 7) skips them – bit-identical.
static func entry_at(schedule: NpcSchedule, minute_of_day: int, day: int = -1) -> ScheduleEntry:
	if schedule == null or schedule.entries.is_empty():
		push_warning("[ScheduleResolver] entry_at(): schedule has no entries")
		return null
	var t := posmod(minute_of_day, MINUTES_PER_DAY)
	var active: ScheduleEntry = null
	var latest: ScheduleEntry = null
	for entry: ScheduleEntry in schedule.entries:
		if entry == null:
			continue
		if entry.today_flag != &"" and not is_today(entry.today_flag, day):
			continue
		if _later(entry, latest):
			latest = entry
		if entry.start_minute <= t and _later(entry, active):
			active = entry
	return active if active != null else latest


## Whether the GameState flag `flag` holds the number `day` (day < 0: never).
static func is_today(flag: StringName, day: int) -> bool:
	if day < 0 or flag == &"" or not GameState.has_flag(flag):
		return false
	var value: Variant = GameState.get_flag(flag)
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and int(value) == day


## `entry` replaces `current`: a later start, or the same start unless `current` is a (valid)
## today_flag entry and `entry` is not.
static func _later(entry: ScheduleEntry, current: ScheduleEntry) -> bool:
	if current == null or entry.start_minute > current.start_minute:
		return true
	if entry.start_minute < current.start_minute:
		return false
	return entry.today_flag != &"" or current.today_flag == &""


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
