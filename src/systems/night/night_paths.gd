class_name NightPaths
extends Node
## Systems/NightPaths (docs/PHASE8_DESIGN.md §1.6, §3.1, §3.3, §3.4, §5.1), groups &"night_paths", &"saveable",
## save_id night_paths / 78: the two sick-light sequences (NightPathData np_ott, np_kehr) relative to
## p8_open_day – the sick lights, the night visits of Quast / Lenz / Liesel, observing them on the way out
## (≤ 12 m from the house door, region village, not inside) → JournalManager.add_clue, Gerhard Ott's death
## (02:10, flag ott_dead = the calendar day; StoryDirector delivers D2).
## The visits walk in the village by P6's schedule entries with today_flag night_visit_<npc>_day (set here to
## the calendar day of the visit). Clock-driven: every event between the last processed minute and now is
## handled once in time order (saved as last_total – a load replays nothing).

const GROUP := &"night_paths"
const PHASES: Array[StringName] = [&"enter", &"leave", &"observed"]
const OPEN_FLAG := &"p8_open"
const OPEN_DAY_FLAG := &"p8_open_day"
const REGION_VILLAGE := &"village"
const STAT_OBSERVED := &"night_visits_observed"

@export var save_id: String = "night_paths"
@export var save_order: int = 78

## Tests: the paths (empty = Database.night_paths()).
var path_data: Array[NightPathData] = []
## Tests: house → door position (empty = the village region's waypoint v_<house>_door).
var door_positions: Dictionary = {}

var _observed: PackedStringArray = []
var _deaths: Dictionary = {}
var _last_total: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	if _last_total < 0:
		_last_total = TimeManager.total_minutes()


## Houses with the sick light in the window at (day, minute) – SickLight, the map (from c_n_veit on), the moods.
func sick_houses(day: int, minute: int) -> PackedStringArray:
	var out := PackedStringArray()
	if not _open():
		return out
	var now := (day - 1) * NightPathRules.MINUTES_PER_DAY + minute
	for path: NightPathData in _paths():
		if NightPathRules.burning(path, _open_day(), now) and not out.has(String(path.house)):
			out.append(String(path.house))
	return out


## {} | {npc_id, enter_minute, leave_minute, night, clue_id, enter, leave} – the next visit of `path_id` not yet
## over at (day, minute).
func next_visit(path_id: StringName, day: int, minute: int) -> Dictionary:
	var path := _path(path_id)
	if path == null or not _open():
		return {}
	var now := (day - 1) * NightPathRules.MINUTES_PER_DAY + minute
	for v: Dictionary in NightPathRules.visits(path, _open_day()):
		if int(v.leave) > now:
			return {"npc_id": v.npc_id, "enter_minute": v.enter_minute, "leave_minute": v.leave_minute, "night": v.night,
					"clue_id": v.clue_id, "enter": v.enter, "leave": v.leave}
	return {}


## WatchSpot: until 10 minutes before the next visit, ≤ 120 (0 = no sick light tonight / nothing to wait for).
func wait_minutes(spot_id: StringName) -> int:
	if not _open():
		return 0
	for path: NightPathData in _paths():
		if path.watch_spot == spot_id:
			return NightPathRules.wait_minutes(path, _open_day(), TimeManager.total_minutes())
	return 0


## Death (flag), observing on the way out (≤ 12 m, region village), the visit flags.
func apply_minute(day: int, minute: int) -> void:
	var now := (day - 1) * NightPathRules.MINUTES_PER_DAY + minute
	if not _open():
		_last_total = now
		return
	var from := _last_total if _last_total >= 0 else now - 1
	if now <= from:
		return
	_last_total = now
	var events: Array = []
	for path: NightPathData in _paths():
		for v: Dictionary in NightPathRules.visits(path, _open_day()):
			if int(v.enter) > from and int(v.enter) <= now:
				events.append([int(v.enter), 1, path, v, &"enter"])
			if int(v.leave) > from and int(v.leave) <= now:
				events.append([int(v.leave), 2, path, v, &"leave"])
			var flag := NightPathRules.visit_flag(StringName(v.npc_id))
			var vday := floori(float(v.enter) / NightPathRules.MINUTES_PER_DAY) + 1
			if vday == day and now <= int(v.leave):
				GameState.set_flag(flag, day)
		var death := NightPathRules.death_total(path, _open_day())
		if death > from and death <= now:
			events.append([death, 0, path, {}, &"death"])
	events.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for e: Array in events:
		var path: NightPathData = e[2]
		var v: Dictionary = e[3]
		match e[4]:
			&"death":
				var dday := floori(float(e[0]) / NightPathRules.MINUTES_PER_DAY) + 1
				_deaths[String(path.id)] = dday
				GameState.set_flag(path.death_flag, dday)
			&"enter":
				EventBus.night_visit.emit(path.id, StringName(v.npc_id), &"enter")
			&"leave":
				EventBus.night_visit.emit(path.id, StringName(v.npc_id), &"leave")
				if int(e[0]) == now:
					_try_observe(path, v)


func observed(clue_id: StringName) -> bool:
	return _observed.has(String(clue_id))


## The day `path_id`'s patient died (−1 = not / not yet).
func death_day(path_id: StringName) -> int:
	return int(_deaths.get(String(path_id), -1))


## {observed, deaths, last_total} (§5.1).
func save_state() -> Dictionary:
	var obs: Array = []
	for id: String in _observed:
		obs.append(id)
	return {"observed": obs, "deaths": _deaths.duplicate(), "last_total": _last_total}


func load_state(data: Dictionary) -> void:
	_observed = PackedStringArray()
	var o: Variant = data.get("observed", [])
	if o is Array or o is PackedStringArray:
		for id: Variant in o:
			if not _observed.has(str(id)):
				_observed.append(str(id))
	_deaths = {}
	var d: Variant = data.get("deaths", {})
	if d is Dictionary:
		for key: Variant in d:
			var v: Variant = (d as Dictionary)[key]
			if v is int or v is float:
				_deaths[str(key)] = int(v)
	var t: Variant = data.get("last_total", -1)
	_last_total = int(t) if t is int or t is float else TimeManager.total_minutes()


# --- internals -----------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	apply_minute(day, minute)


## The visitor comes out: the gravekeeper ≤ 12 m from the door in the village (not inside) sees it.
func _try_observe(path: NightPathData, v: Dictionary) -> void:
	var player := _first(&"player") as Node3D
	if player == null or not player.is_inside_tree():
		return
	if StringName(str(player.get(&"region_id"))) != REGION_VILLAGE or bool(player.get(&"in_interior")):
		return
	var door: Variant = _door(path.house)
	if not door is Vector3:
		return
	var p := player.global_position
	if Vector2(p.x - (door as Vector3).x, p.z - (door as Vector3).z).length() > NightPathRules.OBSERVE_DISTANCE:
		return
	var clue := String(v.get("clue_id", ""))
	GameState.add_stat(STAT_OBSERVED, 1)
	EventBus.night_visit.emit(path.id, StringName(v.npc_id), &"observed")
	if clue == "" or _observed.has(clue):
		return
	_observed.append(clue)
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", StringName(clue), "", false)


func _door(house: StringName) -> Variant:
	if door_positions.has(house):
		return door_positions[house]
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"region_root"):
		if StringName(str(node.get(&"region_id"))) == REGION_VILLAGE and node.has_method(&"get_waypoint"):
			return node.call(&"get_waypoint", NightPathRules.door_waypoint(house))
	return null


func _paths() -> Array[NightPathData]:
	if not path_data.is_empty():
		return path_data
	var out: Array[NightPathData] = []
	for res: Resource in Database.night_paths():
		if res is NightPathData:
			out.append(res as NightPathData)
	return out


func _path(path_id: StringName) -> NightPathData:
	for p: NightPathData in _paths():
		if p.id == path_id:
			return p
	return null


func _open() -> bool:
	return GameState.flag_on(OPEN_FLAG)


func _open_day() -> int:
	var d: Variant = GameState.get_flag(OPEN_DAY_FLAG, 0)
	return int(d) if d is int or d is float else 0


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
