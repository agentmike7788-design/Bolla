class_name NightPathRules
extends RefCounted
## Pure sick-light rules (docs/PHASE8_DESIGN.md §1.6, §3.2.1, W0 note 10): the nights of a NightPathData
## relative to p8_open_day (a minute before 06:00 belongs to the night that began the evening before – Liesel's
## watch 02:40 has night_offset 4), the window the sick light burns in (from 16:00 of the first night's day to
## 06:00 after the last night), the visits as total minutes, the death, the observation distance, the door
## waypoints of the houses. Deterministic, no tree.

const MINUTES_PER_DAY := 1440
## Minutes before this belong to the night of the evening before.
const NIGHT_END_MINUTE := 360
## The sick light is put into the window in the afternoon of the first night (16:00).
const LIGHT_FROM_MINUTE := 960
## §1.3: observed when ≤ 12 m from the house door as the person comes out.
const OBSERVE_DISTANCE := 12.0
## §1.3: waiting in the shadow ends 10 minutes before the next visit, at most 120 minutes.
const WAIT_BEFORE := 10
const WAIT_MAX := 120


## The calendar day of `minute` in night `night_offset` after `open_day`.
static func calendar_day(open_day: int, night_offset: int, minute: int) -> int:
	return open_day + night_offset + (1 if minute < NIGHT_END_MINUTE else 0)


## Total minute of `minute` in night `night_offset` after `open_day`.
static func total(open_day: int, night_offset: int, minute: int) -> int:
	return (calendar_day(open_day, night_offset, minute) - 1) * MINUTES_PER_DAY + minute


## Vector2i(from_total, to_total) the sick light of `path` burns (to exclusive).
static func light_window(path: NightPathData, open_day: int) -> Vector2i:
	if path == null:
		return Vector2i(-1, -1)
	var from := (open_day + path.start_offset - 1) * MINUTES_PER_DAY + LIGHT_FROM_MINUTE
	var to := (open_day + path.end_offset) * MINUTES_PER_DAY + NIGHT_END_MINUTE
	return Vector2i(from, to)


static func burning(path: NightPathData, open_day: int, now_total: int) -> bool:
	var w := light_window(path, open_day)
	return w.x >= 0 and now_total >= w.x and now_total < w.y


## [{npc_id, night, enter, leave, clue_id, animation, index}] of `path` in time order (total minutes).
static func visits(path: NightPathData, open_day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if path == null:
		return out
	for i: int in path.visits.size():
		var v := path.visits[i]
		if v == null:
			continue
		out.append({"npc_id": v.npc_id, "night": v.night_offset, "enter": total(open_day, v.night_offset, v.enter_minute),
				"leave": total(open_day, v.night_offset, v.leave_minute), "clue_id": v.clue_id, "animation": v.animation,
				"index": i, "enter_minute": v.enter_minute, "leave_minute": v.leave_minute})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.enter) < int(b.enter))
	return out


## Total minute of the death in `path` (−1 = nobody dies).
static func death_total(path: NightPathData, open_day: int) -> int:
	if path == null or path.death_offset < 0 or path.death_flag == &"":
		return -1
	return total(open_day, path.death_offset, path.death_minute)


## Minutes to wait at the watch spot at `now`: until WAIT_BEFORE before the next event (the next visitor
## coming, or the one inside coming out), at most WAIT_MAX; 0 = nothing to wait for.
static func wait_minutes(path: NightPathData, open_day: int, now_total: int) -> int:
	if not burning(path, open_day, now_total):
		return 0
	for v: Dictionary in visits(path, open_day):
		var target := -1
		if int(v.enter) - WAIT_BEFORE > now_total:
			target = int(v.enter) - WAIT_BEFORE
		elif int(v.leave) - WAIT_BEFORE > now_total:
			target = int(v.leave) - WAIT_BEFORE
		if target > now_total:
			return mini(target - now_total, WAIT_MAX)
	return 0


## The door waypoint of a house (house_ott → v_ott_door, §4.6 D1).
static func door_waypoint(house: StringName) -> StringName:
	return StringName("v_%s_door" % String(house).trim_prefix("house_"))


## GameState flag the night visitor's village schedule entries use as today_flag (= the calendar day).
static func visit_flag(npc_id: StringName) -> StringName:
	return StringName("night_visit_%s_day" % npc_id)
