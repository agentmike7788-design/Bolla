class_name ScheduleBuilder
extends RefCounted
## Runtime schedules (docs/PHASE8_DESIGN.md §2.2.3, §2.5.1, §2.7, §2.6.3, §3.4): visits, the apprentice,
## festivals and the robber build NpcSchedules from ScheduleEntries at runtime and hand them to
## Npc.set_runtime_schedule – not saved, rebuilt from plan + clock (a load shows the same figure at the
## same spot). The entries are the ordinary ScheduleEntry resources, so ScheduleResolver and the Npc
## evaluate them exactly like a data schedule.
## - walk: travel_minutes from the polyline (flat waypoint distances) / NpcConfig.walk_m_per_minute
##   (3.2 m per game minute = 1.6 m/s at 0.5 s per minute), at least one minute for any distance.
## - stay: standing at one waypoint with an animation (kneel, mourn_stand, rake …).
## - build: sorted by start_minute (equal starts keep their order – the later one wins, as in data);
##   gaps are invisible: before the first entry (from 00:00) and after a closing walk (the figure has
##   left through the gate / over the bridge).

const ACTIVITY_WALK := &"walk"
const ACTIVITY_STAY := &"stay"
const ACTIVITY_GONE := &"home"
const ANIM_IDLE := &"idle"
const MINUTES_PER_DAY := 1440

## Tests / callers without the Database: overrides NpcConfig.walk_m_per_minute when > 0.
static var walk_speed_override: float = 0.0


## A walk along `path` (waypoint ids; from_wp first – prepended unless path starts with it) from
## start_minute; travel_minutes from the polyline: length / NpcConfig.walk_m_per_minute (3.2). The figure
## stands (idle) at the last waypoint after arriving. region: &"" / &"graveyard" | &"village".
static func walk(from_wp: StringName, path: PackedStringArray, start_minute: int, region: StringName, world: Node) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	var full := PackedStringArray()
	if from_wp != &"":
		full.append(String(from_wp))
	for id: String in path:
		if id == "" or (not full.is_empty() and full[full.size() - 1] == id):
			continue
		full.append(id)
	e.path = full
	e.start_minute = posmod(start_minute, MINUTES_PER_DAY)
	e.activity = ACTIVITY_WALK
	e.animation = ANIM_IDLE
	e.region = _region(region)
	e.travel_minutes = travel_minutes(full, world)
	return e


## Staying at at_wp from start_minute with `animation` (dialogue_id &"" = no talk; visible false = gone).
static func stay(at_wp: StringName, start_minute: int, animation: StringName, dialogue_id: StringName = &"", visible := true) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.path = PackedStringArray([String(at_wp)]) if at_wp != &"" else PackedStringArray()
	e.start_minute = posmod(start_minute, MINUTES_PER_DAY)
	e.activity = ACTIVITY_STAY if visible else ACTIVITY_GONE
	e.animation = animation if animation != &"" else ANIM_IDLE
	e.dialogue_id = dialogue_id
	e.visible = visible
	return e


## Sorted by start_minute, gaps = invisible (before the first entry; after a closing walk). The region of
## stays without one follows the entry before (a schedule never mixes regions – one Npc per region).
static func build(entries: Array[ScheduleEntry]) -> NpcSchedule:
	var s := NpcSchedule.new()
	var indexed: Array = []
	for i: int in entries.size():
		if entries[i] != null:
			indexed.append([entries[i].start_minute, i, entries[i]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var sorted: Array[ScheduleEntry] = []
	for item: Array in indexed:
		sorted.append(item[2])
	if sorted.is_empty():
		return s
	var region := &""
	for e: ScheduleEntry in sorted:
		if e.region != &"":
			region = e.region
			break
	for e: ScheduleEntry in sorted:
		if e.region == &"":
			e.region = region
	var out: Array[ScheduleEntry] = []
	var first := sorted[0]
	if first.start_minute > 0:
		out.append(_gone(_first_wp(first), 0, region))
	out.append_array(sorted)
	var last := sorted[sorted.size() - 1]
	if last.activity == ACTIVITY_WALK and last.visible and last.start_minute + last.travel_minutes < MINUTES_PER_DAY:
		out.append(_gone(_last_wp(last), last.start_minute + maxi(last.travel_minutes, 0), region))
	s.entries = out
	return s


## Game minutes for the polyline (flat distances between the waypoints of `world`); 0 for a single
## waypoint or no world, else at least 1.
static func travel_minutes(path: PackedStringArray, world: Node) -> int:
	var length := path_length(path, world)
	if length <= 0.0001:
		return 0
	return maxi(1, ceili(length / _speed()))


## Flat length (m) of the waypoint polyline in `world` (0 without a world that knows get_waypoint).
static func path_length(path: PackedStringArray, world: Node) -> float:
	if world == null or not world.has_method(&"get_waypoint") or path.size() < 2:
		return 0.0
	var total := 0.0
	var prev: Vector3 = world.call(&"get_waypoint", StringName(path[0]))
	for k: int in range(1, path.size()):
		var p: Vector3 = world.call(&"get_waypoint", StringName(path[k]))
		total += Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
	return total


static func _speed() -> float:
	if walk_speed_override > 0.0:
		return walk_speed_override
	var cfg := Database.config(&"npc_config") as NpcConfig
	var v := cfg.walk_m_per_minute if cfg != null else NpcConfig.new().walk_m_per_minute
	return maxf(v, 0.01)


static func _gone(wp: String, minute: int, region: StringName) -> ScheduleEntry:
	var e := stay(StringName(wp), minute, ANIM_IDLE, &"", false)
	e.region = region
	return e


static func _first_wp(e: ScheduleEntry) -> String:
	return e.path[0] if not e.path.is_empty() else ""


static func _last_wp(e: ScheduleEntry) -> String:
	return e.path[e.path.size() - 1] if not e.path.is_empty() else ""


static func _region(region: StringName) -> StringName:
	return &"" if region == &"graveyard" else region
