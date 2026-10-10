class_name ChatterRunner
extends Node
## Systems/ChatterRunner (docs/PHASE8_DESIGN.md §2.1.2, §3.1, §3.4), group &"chatter", not saved.
## 2 Hz (update_now) it starts a chatter (ChatterData) when
## - the village is open (village_open, §1.2 – pure display, the Phase-7 values never change),
## - the gravekeeper is in the chatter's region, in no dialogue / panel, and ≤ chatter_distance (10 m) from the
##   place,
## - the minute lies in its window, its conditions hold (dialogue syntax + the chatter keys below),
## - both speakers stand at the place (Npc of that region, present, not walking, ≤ PLACE_RADIUS; place "" =
##   the two stand ≤ PAIR_RADIUS apart – Martha Kehr at her grave and Jakob working nearby),
## - no other chatter runs in the region and it has not run today (NpcLife keeps the once-per-day list).
## Then the two turn to each other (Npc.set_chatter_target, talk) and say the lines alternately, one every
## chatter_line_seconds (3.5 s real time) – EventBus.chatter_line(chatter_id, npc_id, text) for the bubbles.
## A speaker leaving or the gravekeeper changing region ends it. sets_flag (only ch_rumor_robber →
## robber_known) is set at the start; stats.chatters_seen counts from p8_open.
## Chatter keys: p8_open · open_days_gte:<n> (days since p8_open_day) · sick_light (a sick light tonight) ·
## mood:<npc>:<mood> · fest_day:<id> / fest_today:<id> · fest_eve:<id> (the day before) · fest_after:<id> (the
## day after) · apprentice_hired; a leading "!" negates.

const GROUP := &"chatter"
const FLAG_VILLAGE_OPEN := &"village_open"
const STAT_CHATTERS := &"chatters_seen"
## Speakers count as „at the place" within this distance (m) of the waypoint.
const PLACE_RADIUS := 3.0
## place "": the two speakers stand at most this far apart (m).
const PAIR_RADIUS := 8.0
const SICK_LIGHT_MINUTE := NpcLife.SICK_LIGHT_MINUTE

## Rules; null = data/config/npc_life_config.tres.
var config: NpcLifeConfig
## Tests: the chatters instead of Database.chatters().
var chatters: Array[ChatterData] = []
## Tests: the gravekeeper's region / position instead of RegionRoot.current and the player.
var region_override: StringName = &""
var player_override: Variant = null

## region → {id, data, speakers [Npc, Npc], index, elapsed}
var _running: Dictionary[StringName, Dictionary] = {}
## chatter_id → day (without an NpcLife in the tree).
var _seen: Dictionary[StringName, int] = {}
var _elapsed: float = 0.0
var _modal: bool = false


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.ui_modal_changed.connect(func(open: bool) -> void: _modal = open)
	EventBus.region_changed.connect(_on_region_changed.unbind(1))


func _process(delta: float) -> void:
	advance(delta)
	_elapsed += delta
	if _elapsed >= 0.5:
		_elapsed = 0.0
		update_now()


## Checks every chatter of the gravekeeper's region; starts at most one per region.
func update_now() -> void:
	if not is_inside_tree():
		return
	_check_running()
	if not GameState.flag_on(FLAG_VILLAGE_OPEN) or _modal:
		return
	var region := _region()
	if region == &"" or _running.has(region):
		return
	var player_pos: Variant = _player_pos()
	if player_pos == null:
		return
	var minute := TimeManager.minute_of_day
	for c: ChatterData in _list():
		if c == null or c.region != region or seen_today(c.id):
			continue
		if minute < c.window.x or minute >= c.window.y:
			continue
		if c.npcs.size() < 2 or c.lines.is_empty():
			continue
		var speakers := _speakers(c)
		if speakers.is_empty():
			continue
		var place := _place_pos(c, speakers)
		if Vector2(place.x - (player_pos as Vector3).x, place.z - (player_pos as Vector3).z).length() > _cfg().chatter_distance:
			continue
		if not conditions_met(c):
			continue
		_start(c, speakers)
		return


## The chatter running in the region or &"".
func running(region_id: StringName) -> StringName:
	var r: Dictionary = _running.get(region_id, {})
	return StringName(str(r.get("id", ""))) if not r.is_empty() else &""


## From day + the saved list in NpcLife (once per day).
func seen_today(chatter_id: StringName) -> bool:
	var life := _life()
	if life != null:
		return life.chatter_seen_today(chatter_id)
	return int(_seen.get(chatter_id, -1)) == TimeManager.day


## Real-time progress of the running chatters (one line every chatter_line_seconds).
func advance(delta: float) -> void:
	var step := maxf(_cfg().chatter_line_seconds, 0.01)
	for region: StringName in _running.keys():
		var r: Dictionary = _running[region]
		r.elapsed = float(r.elapsed) + delta
		while _running.has(region) and float(r.elapsed) >= step:
			r.elapsed = float(r.elapsed) - step
			_next_line(region)


## Stops the chatter of `region` (the speakers turn back).
func stop(region_id: StringName) -> void:
	var r: Dictionary = _running.get(region_id, {})
	if r.is_empty():
		return
	for npc: Variant in r.speakers:
		if is_instance_valid(npc):
			(npc as Npc).set_chatter_target(null)
	_running.erase(region_id)


## Every condition of `c` holds (dialogue syntax + the chatter keys).
func conditions_met(c: ChatterData) -> bool:
	for cond: String in c.conditions:
		if not _check(cond):
			return false
	return true


# --- internals ------------------------------------------------------------------------------------

func _start(c: ChatterData, speakers: Array[Npc]) -> void:
	var life := _life()
	if life != null:
		life.note_chatter(c.id)
	else:
		_seen[c.id] = TimeManager.day
	if c.sets_flag != &"":
		GameState.set_flag(c.sets_flag, true)
	if GameState.flag_on(NpcLife.FLAG_OPEN):
		GameState.add_stat(STAT_CHATTERS, 1)
	speakers[0].set_chatter_target(speakers[1])
	speakers[1].set_chatter_target(speakers[0])
	_running[c.region] = {"id": c.id, "data": c, "speakers": speakers, "index": 0, "elapsed": 0.0}
	_say(c, 0)


func _next_line(region: StringName) -> void:
	var r: Dictionary = _running[region]
	var c: ChatterData = r.data
	r.index = int(r.index) + 1
	if int(r.index) >= c.lines.size():
		stop(region)
		return
	_say(c, int(r.index))


func _say(c: ChatterData, index: int) -> void:
	EventBus.chatter_line.emit(c.id, c.npcs[index % 2], c.lines[index])


## A speaker gone or walking away, or the gravekeeper in another region → the chatter ends.
func _check_running() -> void:
	var region := _region()
	for key: StringName in _running.keys():
		var r: Dictionary = _running[key]
		var ok := key == region
		for npc: Variant in r.speakers:
			if not is_instance_valid(npc) or not (npc as Npc).is_present() or (npc as Npc).is_walking():
				ok = false
		if not ok:
			stop(key)


func _on_region_changed() -> void:
	_check_running()


## Both speakers present at the place ([] = not both there).
func _speakers(c: ChatterData) -> Array[Npc]:
	var out: Array[Npc] = []
	for id: StringName in [c.npcs[0], c.npcs[1]]:
		var npc := _find(id, c.region)
		if npc == null:
			out.clear()
			return out
		out.append(npc)
	if c.place == &"":
		var d := Vector2(out[0].global_position.x - out[1].global_position.x, out[0].global_position.z - out[1].global_position.z)
		if d.length() > PAIR_RADIUS:
			out.clear()
		return out
	var place := _waypoint(out[0], c.place)
	for npc: Npc in out:
		var d := Vector2(npc.global_position.x - place.x, npc.global_position.z - place.z)
		if d.length() > PLACE_RADIUS:
			out.clear()
			return out
	return out


func _place_pos(c: ChatterData, speakers: Array[Npc]) -> Vector3:
	if c.place == &"":
		return (speakers[0].global_position + speakers[1].global_position) * 0.5
	return _waypoint(speakers[0], c.place)


## The present, standing Npc of `id` (npc_id, or the node npc_<id>) in `region`.
func _find(id: StringName, region: StringName) -> Npc:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null or npc.region_id != region:
			continue
		if npc.npc_id != id and String(npc.name) != "npc_" + String(id):
			continue
		if npc.is_present() and not npc.is_walking():
			return npc
	return null


func _waypoint(npc: Npc, id: StringName) -> Vector3:
	var w := npc._world()
	if w != null and w.has_method(&"get_waypoint"):
		return w.call(&"get_waypoint", id)
	return npc.global_position


func _check(cond: String) -> bool:
	var text := cond.strip_edges()
	var negate := false
	while text.begins_with("!"):
		negate = not negate
		text = text.substr(1).strip_edges()
	var parts := text.split(":")
	var key := parts[0]
	var day := TimeManager.day
	var result := false
	match key:
		"p8_open":
			result = GameState.flag_on(NpcLife.FLAG_OPEN)
		"open_days_gte":
			var since: Variant = GameState.get_flag(NpcLife.FLAG_OPEN_DAY, 0)
			result = parts.size() > 1 and GameState.flag_on(NpcLife.FLAG_OPEN) and (since is int or since is float) \
					and int(since) > 0 and day - int(since) >= int(parts[1])
		"sick_light":
			var paths := get_tree().get_first_node_in_group(&"night_paths")
			result = paths != null and paths.has_method(&"sick_houses") \
					and not (paths.call(&"sick_houses", day, SICK_LIGHT_MINUTE) as PackedStringArray).is_empty()
		"mood":
			var life := _life()
			result = parts.size() > 2 and life != null and life.mood(StringName(parts[1])) == StringName(parts[2])
		"fest_day", "fest_today", "fest_eve", "fest_after":
			var fest := get_tree().get_first_node_in_group(&"festivals")
			if parts.size() > 1 and fest != null and fest.has_method(&"fest_day"):
				var fd := int(fest.call(&"fest_day", StringName(parts[1])))
				var offset := {"fest_day": 0, "fest_today": 0, "fest_eve": 1, "fest_after": -1}[key] as int
				result = fd >= 0 and fd == day + offset
		"apprentice_hired":
			var app := get_tree().get_first_node_in_group(&"apprentice")
			result = (app != null and app.has_method(&"is_hired") and bool(app.call(&"is_hired"))) \
					or GameState.flag_on(&"apprentice_hired")
		_:
			return DialogueConditions.check(cond, {})
	return result != negate


func _region() -> StringName:
	if region_override != &"":
		return region_override
	return RegionRoot.current(get_tree())


func _player_pos() -> Variant:
	if player_override is Vector3:
		return player_override
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	return player.global_position if player != null else null


func _list() -> Array[ChatterData]:
	if not chatters.is_empty():
		return chatters
	var out: Array[ChatterData] = []
	for res: Resource in Database.chatters():
		if res is ChatterData:
			out.append(res as ChatterData)
	return out


func _life() -> NpcLife:
	return get_tree().get_first_node_in_group(NpcLife.GROUP) as NpcLife if is_inside_tree() else null


func _cfg() -> NpcLifeConfig:
	if config == null:
		config = Database.config(&"npc_life_config") as NpcLifeConfig
		if config == null:
			config = NpcLifeConfig.new()
	return config
