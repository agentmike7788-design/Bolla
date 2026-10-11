class_name Festivals
extends Node
## Systems/Festivals (docs/PHASE8_DESIGN.md §2.7, §3.1, §3.3, §3.4, §5.1), groups &"festivals",
## &"saveable": the Kathreintanz (day 54, 19:00–23:00 in the inn; dropped when before p8_open_day) and the
## Lichtgang (day 58; once shifted to p8_open_day + 3), the day flags (fest_kathrein_day / fest_lights_day =
## the effective day), presence (≥ 30 minutes in the inn → +2 with the guests, once) and dances (≥
## „Bekannt", 2 partners, +3), Osric's 12 candles (07:40), the early ghosts (17:00, display), the 18:00
## evaluation (lights_all / lights_some) and the end (lights_held).
## The days are computed once (the first morning with p8_open) and saved – no second Lichtgang.
## Other systems read today() / running() / the day flags (no visits, no robber, Jakob free, Ilse away).
## Saved (§5.1): {days, state, presence, danced, lights_result, candles, early, morning_day}.

const GROUP := &"festivals"
const KATHREIN := &"fest_kathrein"
const LIGHTS := &"fest_lights"
const STATE_ANNOUNCED := &"announced"
const STATE_RUNNING := &"running"
const STATE_ENDED := &"ended"
const STATE_CANCELLED := &"cancelled"
const STATES: Array[StringName] = [&"announced", &"running", &"ended", &"cancelled"]
const OPEN_FLAG := &"p8_open"
const OPEN_DAY_FLAG := &"p8_open_day"
const HELD_FLAG := &"lights_held"
const LIGHTS_ALL_FLAG := &"lights_all"
const MINUTES_PER_DAY := 1440
const MORNING_MINUTE := 360
const PLAYER_GROUP := &"player"
const GRAVEYARD_GROUP := &"graveyard"
const GRAVE_CARE_GROUP := &"grave_care"
const RELATIONSHIPS_GROUP := &"relationships"
const REPUTATION_GROUP := &"reputation"
const PIETY_GROUP := &"piety"
const VISITORS_GROUP := &"visitors"
const GHOSTS_GROUP := &"ghosts"
const NPC_GROUP := &"npc"
const PRIEST_NPC := &"npc_priest"
const APPRENTICE_NPC := &"npc_apprentice"
const ROAD_END := &"road_end"
const GRAVEYARD_REGION := &"graveyard"
const LIGHTS_LENZ := &"lights_lenz"
const LIGHTS_CROWD := "lights_crowd_%d"
const CROWD_SPOTS := 8
const FALLBACK_ROUTE: PackedStringArray = ["road_end", "road_mid", "gate_outside", "gate_inside"]
const VILLAGE_REGION := &"village"
const DEFAULT_ROOM := &"inn"
const DEFAULT_CANDLE := &"grave_candle"
const STAT_DANCES := &"dances"
const REASON_PRESENCE := "Kathreintanz"
const REASON_DANCE := "Getanzt am Kathreintanz"
const REASON_LIGHTS := "Lichtgang: kein Grab ohne Licht"
const REASON_LIGHTS_SOME := "Lichtgang"

@export var save_id: String = "festivals"
@export var save_order: int = 75

## Festivals by id; empty = Database.festivals() (tests inject fixtures).
var fest_table: Dictionary[StringName, FestivalData] = {}
## The villagers lights_all reaches (rel_all); empty = the npc ids of Database.friend_stories() (the
## seven living).
var villager_ids: Array[StringName] = []
## Households whose goodwill lights_all raises; empty = Database.kin_list() without villager_id.
var household_ids: Array[StringName] = []
## The kin of the procession; empty = Database.kin_list() (tests inject fixtures).
var kin_table: Array[KinData] = []
## Relationship tiers (dance ≥ „Bekannt"); null = data/config/relationship_config.tres.
var relationship_config: RelationshipConfig

## Effective day per festival (−1 = falls out); a missing id = not computed yet.
var _days: Dictionary[StringName, int] = {}
var _state: Dictionary[StringName, StringName] = {}
## Kathrein: total minute since the player is in the inn during the window (−1 = not there); done once.
var _presence_since: int = -1
var _presence_done: bool = false
var _danced: Array[StringName] = []
var _lights_result: StringName = &""
var _candles_given: bool = false
var _early_done: bool = false
## Lichtgang: the participants (npc layout ids) whose own candles stand on their graves.
var _kin_lit: Array[StringName] = []
var _morning_day: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


## FestivalData of `fest_id` or null.
func festival(fest_id: StringName) -> FestivalData:
	if not fest_table.is_empty():
		return fest_table.get(fest_id)
	return Database.festival(fest_id) as FestivalData


## All festivals (by calendar_day).
func all_festivals() -> Array[FestivalData]:
	var out: Array[FestivalData] = []
	var list: Array = fest_table.values() if not fest_table.is_empty() else Database.festivals()
	for f: Variant in list:
		if f is FestivalData:
			out.append(f)
	out.sort_custom(func(a: FestivalData, b: FestivalData) -> bool:
		return a.calendar_day < b.calendar_day or (a.calendar_day == b.calendar_day and String(a.id) < String(b.id)))
	return out


## The effective day (after the shift) or −1.
func fest_day(fest_id: StringName) -> int:
	return int(_days.get(fest_id, -1))


## The festival of today or &"".
func today() -> StringName:
	for id: StringName in _days:
		if _days[id] > 0 and _days[id] == TimeManager.day:
			return id
	return &""


## The festival whose window runs now or &"".
func running() -> StringName:
	var id := today()
	return id if id != &"" and _state.get(id, &"") == STATE_RUNNING else &""


## announced | running | ended | cancelled | &"".
func state(fest_id: StringName) -> StringName:
	return _state.get(fest_id, &"")


## Day flag, the announcement (after p8_open; the days are computed once).
func apply_morning(day: int) -> void:
	if day <= _morning_day or not GameState.flag_on(OPEN_FLAG):
		return
	_morning_day = day
	_compute_days()
	for f: FestivalData in all_festivals():
		var d := fest_day(f.id)
		if d > 0 and f.day_flag != &"" and GameState.get_flag(f.day_flag) != d:
			GameState.set_flag(f.day_flag, d)
		if d == day and state(f.id) == &"":
			_set_state(f.id, STATE_ANNOUNCED)
			if f.id == LIGHTS:
				apply_procession()
			var text := str(f.effects.get("announce", ""))
			if FestivalRules.shifted(f, d) and str(f.effects.get("shift_line", "")) != "":
				text = (text + " " if text != "" else "") + str(f.effects.shift_line)
			if text != "":
				EventBus.notification_requested.emit(text, &"info")


## Window, Osric's candles, presence, early ghosts, the 18:00 evaluation, the end.
func apply_minute(day: int, minute: int) -> void:
	var id := today()
	if id == &"" or day != TimeManager.day:
		return
	var f := festival(id)
	if f == null:
		return
	var st := state(id)
	if st == STATE_ENDED or st == STATE_CANCELLED:
		return
	if id == LIGHTS:
		_lights_minute(f, minute)
	if minute >= f.window.y:
		_end(f)
		return
	if FestivalRules.in_window(f, minute) and st != STATE_RUNNING:
		_set_state(id, STATE_RUNNING)
	if running() == id and id == KATHREIN:
		_presence_minute(f, minute)


func dance_block_reason(npc_id: StringName) -> String:
	var f := festival(KATHREIN)
	var rel := _first(RELATIONSHIPS_GROUP)
	var value := int(rel.call(&"value", npc_id)) if rel != null and rel.has_method(&"value") else 0
	var need := StringName(str(f.effects.get("dance_tier", "acquainted"))) if f != null else &"acquainted"
	var tier := RelationshipRules.tier(value, _rel_cfg())
	return FestivalRules.dance_block_reason(f, npc_id, {"running": running() == KATHREIN, "in_room": _player_in_room(f),
			"present": FestivalRules.guests_at(f, TimeManager.minute_of_day).has(npc_id), "danced": _danced,
			"tier_ok": RelationshipRules.tier_index(tier) >= RelationshipRules.tier_index(need), "name": _npc_name(npc_id)})


## +3 (effects.dance_rel), the partner noted, stats.dances; the 15 minutes pass (§1.3, not cancellable).
func dance(npc_id: StringName) -> bool:
	if dance_block_reason(npc_id) != "":
		return false
	var f := festival(KATHREIN)
	_danced.append(npc_id)
	_rel_add(npc_id, int(f.effects.get("dance_rel", 3)), REASON_DANCE)
	GameState.add_stat(STAT_DANCES, 1)
	# W1-Anschluss 6 (W-Welt): the village talks about it (NpcLife reactions, the partner and the hostess).
	_life_event(&"kathrein_danced", [npc_id, &"innkeeper"] as Array[StringName])
	var minutes := int(f.effects.get("dance_minutes", 15))
	if minutes > 0:
		TimeManager.advance(minutes)
	return true


## (burning, occupied) for the objective line.
func lights_count() -> Vector2i:
	var graves := _occupied_graves()
	var care := _first(GRAVE_CARE_GROUP)
	var lit := 0
	if care != null and care.has_method(&"candle_lit"):
		for gid: String in graves:
			if bool(care.call(&"candle_lit", gid)):
				lit += 1
	return Vector2i(lit, graves.size())


## The 18:00 evaluation of the Lichtgang (once): lights_all (reputation +3, villagers +2, Lenz +3,
## households goodwill +2, piety lights_all, flag lights_all) or lights_some (reputation +1).
func evaluate_lights() -> StringName:
	if _lights_result != &"":
		return _lights_result
	var f := festival(LIGHTS)
	var count := lights_count()
	_lights_result = FestivalRules.lights_result(count.x, count.y, f)
	if _lights_result == FestivalRules.RESULT_ALL:
		var all := FestivalRules.effect(f, "lights_all")
		_rep_event(StringName(str(all.get("rep_event", "lights_all"))), REASON_LIGHTS)
		var rel_all := int(all.get("rel_all", 2))
		var extra: Variant = all.get("rel", {})
		for npc: StringName in _villagers():
			var delta := rel_all + (int((extra as Dictionary).get(npc, (extra as Dictionary).get(String(npc), 0))) if extra is Dictionary else 0)
			_rel_add(npc, delta, REASON_LIGHTS)
		var visitors := _first(VISITORS_GROUP)
		if visitors != null and visitors.has_method(&"add_goodwill"):
			for kin: StringName in _households():
				visitors.call(&"add_goodwill", kin, int(all.get("goodwill", 2)))
		var piety := _first(PIETY_GROUP)
		if piety != null and piety.has_method(&"event"):
			piety.call(&"event", StringName(str(all.get("piety_event", "lights_all"))), REASON_LIGHTS)
		GameState.set_flag(LIGHTS_ALL_FLAG, true)
		_life_event(&"lights_all", [] as Array[StringName])
	elif _lights_result == FestivalRules.RESULT_SOME:
		var some := FestivalRules.effect(f, "lights_some")
		_rep_event(StringName(str(some.get("rep_event", "lights_some"))), REASON_LIGHTS_SOME)
	return _lights_result


## &"" | all | some | none.
## §2.7.2 the procession of today's Lichtgang: [{npc, graves, arrive, at_grave, stand, leave, lead}] – Lenz in
## front, then every household and villager with a dead on the hill (Visitors.kin_for_grave; the
## villagers' fixed graves), Jakob with his mother's lantern. Pure plan (not saved).
func procession_plan() -> Array[Dictionary]:
	var f := festival(LIGHTS)
	var participants: Array = [{"npc": PRIEST_NPC, "graves": PackedStringArray(), "lead": true}]
	var by_kin := {}
	var visitors := _first(VISITORS_GROUP)
	if visitors != null and visitors.has_method(&"kin_for_grave"):
		for gid: String in _occupied_graves():
			var kin := StringName(str(visitors.call(&"kin_for_grave", gid)))
			if kin != &"":
				if not by_kin.has(kin):
					by_kin[kin] = PackedStringArray()
				var list: PackedStringArray = by_kin[kin]
				list.append(gid)
				by_kin[kin] = list
	for k: Variant in _kin_data():
		var kin := k as KinData
		if kin == null or kin.npc_path_id == &"":
			continue
		var graves: PackedStringArray = by_kin.get(kin.kin_id, PackedStringArray())
		for gid: String in kin.fixed_graves:
			if not graves.has(gid):
				graves.append(gid)
		if not graves.is_empty():
			participants.append({"npc": kin.npc_path_id, "graves": graves})
	participants.append({"npc": APPRENTICE_NPC, "graves": PackedStringArray()})
	return FestivalRules.procession(f, participants)


## Runtime schedules of the procession (ScheduleBuilder, Npc.set_runtime_schedule; rebuilt from plan +
## clock after a load). Npc not in the world are skipped.
func apply_procession() -> void:
	if not is_inside_tree() or today() != LIGHTS:
		return
	var npcs := {}
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		# W3 (QA8-15): the procession walks on the graveyard – the village figures of the same name (npc_priest in
		# Hollerbrück) keep their own schedule (else Lenz walked „road_end" in the village and not up the hill).
		var region: Variant = node.get(&"region_id")
		if region != null and StringName(str(region)) != GRAVEYARD_REGION:
			continue
		npcs[StringName(node.name)] = node
		var id: Variant = node.get(&"npc_id")
		if id != null and str(id) != "":
			npcs[StringName(str(id))] = node
	var world := get_tree().current_scene
	var crowd := 0
	for entry: Dictionary in procession_plan():
		var npc: Node = npcs.get(entry.npc)
		if npc == null or not npc.has_method(&"set_runtime_schedule"):
			continue
		var graves: PackedStringArray = entry.graves
		var spot: StringName
		if graves.is_empty():
			spot = LIGHTS_LENZ if bool(entry.lead) else StringName(LIGHTS_CROWD % (crowd % CROWD_SPOTS + 1))
			if not bool(entry.lead):
				crowd += 1
		else:
			spot = StringName("gv_" + graves[0])
		var route := _route(world, graves[0] if not graves.is_empty() else "")
		# W-Welt (W2): Lenz, Jakob and the crowd walk the baked route up to their place (else they stood at the
		# gate and appeared at the Kirchhof).
		if graves.is_empty() and world != null and world.has_method(&"visitor_route"):
			var to_spot: PackedStringArray = world.call(&"visitor_route", String(spot))
			if not to_spot.is_empty():
				route = to_spot
		var back := route.duplicate()
		back.reverse()
		var entries: Array[ScheduleEntry] = [
			ScheduleBuilder.walk(ROAD_END, route, int(entry.arrive), GRAVEYARD_REGION, world),
			ScheduleBuilder.stay(spot, int(entry.at_grave), &"mourn_stand" if not graves.is_empty() else &"idle"),
			ScheduleBuilder.walk(spot, back, int(entry.leave), GRAVEYARD_REGION, world),
		]
		npc.call(&"set_runtime_schedule", ScheduleBuilder.build(entries))


## Runtime schedules are not saved: rebuilt from plan + clock.
func post_load() -> void:
	if today() == LIGHTS and state(LIGHTS) != STATE_ENDED:
		apply_procession()
		# W1-Anschluss 6 (W-Welt): the early ghosts' window is display only – set it again after a load.
		var f := festival(LIGHTS)
		var early := FestivalRules.effect(f, "early_ghosts") if f != null else {}
		var ghosts := _first(GHOSTS_GROUP)
		if _early_done and not early.is_empty() and ghosts != null and ghosts.has_method(&"set_early_window"):
			ghosts.call(&"set_early_window", int(early.get("from", 1020)), int(early.get("minutes", 30)), _lit_graves())


func _life_event(event: StringName, npcs: Array[StringName]) -> void:
	var life := _first(&"npc_life")
	if life != null and life.has_method(&"note_event"):
		life.call(&"note_event", event, npcs)


func lights_result() -> StringName:
	return _lights_result


## Partners danced with this Kathrein.
func danced() -> Array[StringName]:
	return _danced.duplicate()


## The Kathrein presence was rewarded.
func presence_done() -> bool:
	return _presence_done


## §5.1.
func save_state() -> Dictionary:
	var days := {}
	for id: StringName in _days:
		days[String(id)] = _days[id]
	var states := {}
	for id: StringName in _state:
		states[String(id)] = String(_state[id])
	var danced_ids: Array = []
	for id: StringName in _danced:
		danced_ids.append(String(id))
	return {"days": days, "state": states, "presence": {"since": _presence_since, "done": _presence_done},
			"danced": danced_ids, "lights_result": String(_lights_result), "candles": _candles_given, "early": _early_done,
			"kin_lit": _kin_lit.map(func(id: StringName) -> String: return String(id)),
			"morning_day": _morning_day}


## Tolerant: unknown states dropped, days ≥ −1.
func load_state(data: Dictionary) -> void:
	_days.clear()
	_state.clear()
	_danced.clear()
	var days: Variant = data.get("days", {})
	if days is Dictionary:
		for key: Variant in days:
			var v: Variant = days[key]
			if v is int or v is float:
				_days[StringName(str(key))] = maxi(-1, int(v))
	var states: Variant = data.get("state", {})
	if states is Dictionary:
		for key: Variant in states:
			var s := StringName(str(states[key]))
			if s in STATES:
				_state[StringName(str(key))] = s
	var presence: Variant = data.get("presence", {})
	_presence_since = -1
	_presence_done = false
	if presence is Dictionary:
		var since: Variant = (presence as Dictionary).get("since", -1)
		_presence_since = maxi(-1, int(since)) if (since is int or since is float) else -1
		_presence_done = _flag_value((presence as Dictionary).get("done", false))
	var partners: Variant = data.get("danced", [])
	if partners is Array:
		for v: Variant in partners:
			if (v is String or v is StringName) and not _danced.has(StringName(str(v))):
				_danced.append(StringName(str(v)))
	var result := StringName(str(data.get("lights_result", "")))
	_lights_result = result if result in [FestivalRules.RESULT_ALL, FestivalRules.RESULT_SOME, FestivalRules.RESULT_NONE] else &""
	_candles_given = _flag_value(data.get("candles", false))
	_early_done = _flag_value(data.get("early", false))
	_kin_lit.clear()
	var lit: Variant = data.get("kin_lit", [])
	if lit is Array:
		for v: Variant in lit:
			if (v is String or v is StringName) and not _kin_lit.has(StringName(str(v))):
				_kin_lit.append(StringName(str(v)))
	var morning: Variant = data.get("morning_day", 0)
	_morning_day = maxi(0, int(morning)) if (morning is int or morning is float) else 0


# --- internals -------------------------------------------------------------------------------------

func _compute_days() -> void:
	var open_day := int(GameState.get_flag(OPEN_DAY_FLAG, 0)) if GameState.get_flag(OPEN_DAY_FLAG, 0) is int \
			or GameState.get_flag(OPEN_DAY_FLAG, 0) is float else 0
	if open_day <= 0:
		open_day = TimeManager.day
	for f: FestivalData in all_festivals():
		if _days.has(f.id):
			continue
		var d := FestivalRules.effective_day(f, open_day)
		# §2.7.2: once per game – a Lichtgang already held stays the one.
		if f.shift_rule == FestivalData.SHIFT_OPEN_PLUS and GameState.flag_on(HELD_FLAG):
			d = -1
		_days[f.id] = d
		if d < 0:
			_set_state(f.id, STATE_CANCELLED)


func _lights_minute(f: FestivalData, minute: int) -> void:
	var candles_at := int(f.effects.get("candles_minute", 460))
	if not _candles_given and minute >= candles_at:
		var inv := _player_inventory()
		if inv != null:
			inv.add_item(StringName(str(f.effects.get("candle_item", DEFAULT_CANDLE))), int(f.effects.get("candles", 12)))
			_candles_given = true
			var line := str(f.effects.get("candles_line", ""))
			if line != "":
				EventBus.notification_requested.emit(line, &"reward")
	var early := FestivalRules.effect(f, "early_ghosts")
	if not _early_done and not early.is_empty() and minute >= int(early.get("from", 1020)) and minute < f.window.y:
		_early_done = true
		var ghosts := _first(GHOSTS_GROUP)
		if ghosts != null and ghosts.has_method(&"set_early_window"):
			ghosts.call(&"set_early_window", int(early.get("from", 1020)), int(early.get("minutes", 30)), _lit_graves())
	# The families put their own lights on their graves when they reach them (§2.7.2 17:00–17:40).
	if minute >= FestivalRules._pair(f.effects.get("at_graves"), Vector2i(1020, 1060)).x and minute < f.window.y:
		for entry: Dictionary in procession_plan():
			var who: StringName = entry.npc
			if _kin_lit.has(who) or minute < int(entry.at_grave) or (entry.graves as PackedStringArray).is_empty():
				continue
			_kin_lit.append(who)
			_kin_lights(entry.graves)
	if _lights_result == &"" and minute >= int(f.effects.get("check_minute", 1080)):
		evaluate_lights()


## A family's own candles on `graves` (GraveCare.light with a candle of their own each).
func _kin_lights(graves: PackedStringArray) -> void:
	var care := _first(GRAVE_CARE_GROUP)
	if care == null or not care.has_method(&"light"):
		return
	var f := festival(LIGHTS)
	var candle := StringName(str(f.effects.get("candle_item", DEFAULT_CANDLE))) if f != null else DEFAULT_CANDLE
	for gid: String in graves:
		if care.has_method(&"candle_lit") and bool(care.call(&"candle_lit", gid)):
			continue
		var own := Inventory.new()
		own.slot_count = 1
		own.add_item(candle, 1)
		care.call(&"light", gid, own)
		own.free()


## The route up to `grave` (the world's visitor route when it has one, else road_end → gate).
func _route(world: Node, grave: String) -> PackedStringArray:
	if world != null and grave != "" and world.has_method(&"visitor_route"):
		var r: Variant = world.call(&"visitor_route", grave)
		if r is PackedStringArray and not (r as PackedStringArray).is_empty():
			return r
	var out := FALLBACK_ROUTE.duplicate()
	if grave != "":
		out.append("gv_" + grave)
	return out


func _kin_data() -> Array:
	return kin_table if not kin_table.is_empty() else Database.kin_list()


func _presence_minute(f: FestivalData, minute: int) -> void:
	if _presence_done:
		return
	if not _player_in_room(f):
		_presence_since = -1
		return
	var now := TimeManager.total_minutes()
	if _presence_since < 0:
		_presence_since = now
	if FestivalRules.presence_reached(f, _presence_since, now):
		_presence_done = true
		var gain := int(f.effects.get("presence_rel", 2))
		for npc: StringName in FestivalRules.guests_at(f, minute):
			_rel_add(npc, gain, REASON_PRESENCE)


func _end(f: FestivalData) -> void:
	if f.id == LIGHTS and _lights_result == &"":
		evaluate_lights()
	_set_state(f.id, STATE_ENDED)
	if f.id == LIGHTS:
		GameState.set_flag(HELD_FLAG, true)
	var line := str(f.effects.get("end_line", ""))
	if line != "":
		EventBus.notification_requested.emit(line, &"info")


func _set_state(id: StringName, s: StringName) -> void:
	if _state.get(id, &"") == s:
		return
	_state[id] = s
	EventBus.festival_changed.emit(id, s)


func _player_in_room(f: FestivalData) -> bool:
	var player := _first(PLAYER_GROUP)
	if player == null:
		return false
	var room := StringName(str(f.effects.get("room", DEFAULT_ROOM))) if f != null else DEFAULT_ROOM
	return StringName(str(player.get(&"region_id"))) == VILLAGE_REGION and StringName(str(player.get(&"interior_id"))) == room


func _occupied_graves() -> PackedStringArray:
	var out := PackedStringArray()
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	for g: GraveRecord in graveyard.call(&"graves"):
		if g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED:
			out.append(g.id)
	return out


func _lit_graves() -> PackedStringArray:
	var out := PackedStringArray()
	var care := _first(GRAVE_CARE_GROUP)
	if care == null or not care.has_method(&"candle_lit"):
		return out
	for gid: String in _occupied_graves():
		if bool(care.call(&"candle_lit", gid)):
			out.append(gid)
	return out


func _villagers() -> Array[StringName]:
	if not villager_ids.is_empty():
		return villager_ids.duplicate()
	var out: Array[StringName] = []
	for s: Variant in Database.friend_stories():
		if s is FriendStoryData:
			out.append((s as FriendStoryData).npc_id)
	return out


func _households() -> Array[StringName]:
	if not household_ids.is_empty():
		return household_ids.duplicate()
	var out: Array[StringName] = []
	for k: Variant in _kin_data():
		if k is KinData and (k as KinData).villager_id == &"":
			out.append((k as KinData).kin_id)
	return out


func _rel_add(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(RELATIONSHIPS_GROUP)
	if rel != null and rel.has_method(&"add") and delta != 0:
		rel.call(&"add", npc_id, delta, reason)


func _rep_event(kind: StringName, reason: String) -> void:
	var rep := _first(REPUTATION_GROUP)
	if rep != null and rep.has_method(&"event"):
		rep.call(&"event", kind, reason)


func _npc_name(npc_id: StringName) -> String:
	var v := Database.villager(npc_id) as Resource
	var n: Variant = v.get(&"display_name") if v != null else null
	return str(n) if n != null and str(n) != "" else String(npc_id)


func _player_inventory() -> Inventory:
	var player := _first(PLAYER_GROUP)
	if player == null:
		return null
	var inv: Variant = player.get(&"inventory")
	return inv as Inventory if inv is Inventory else null


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= MORNING_MINUTE and day > _morning_day:
		apply_morning(day)
	apply_minute(day, minute)


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _rel_cfg() -> RelationshipConfig:
	if relationship_config == null:
		relationship_config = Database.config(&"relationship_config") as RelationshipConfig
		if relationship_config == null:
			relationship_config = RelationshipConfig.new()
	return relationship_config


## A saved yes/no: true only for a real bool true (a damaged save may hold a string or a number there –
## `== true` on a String is an engine error in GDScript 4).
static func _flag_value(v: Variant) -> bool:
	return v is bool and bool(v)
