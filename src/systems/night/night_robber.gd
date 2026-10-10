class_name NightRobber
extends Node
## Systems/NightRobber (docs/PHASE8_DESIGN.md §2.6.3, §3.1, §3.3, §3.4, §5.1, §14.4), groups &"night_robber",
## &"saveable", save_id night_robber / 77: Lambert Grell, visible and without a fight.
## - 00:00 of day N + 1 decides night N (RobberRules): a target grave (fresh ≤ 5 days, no mortsafe, no candle,
##   not disturbed, no night watch; not the night of the lights); the first such night for sure, then 35 % with
##   a pause of 2 nights; the freshest grave. Saved – a load decides nothing anew.
## - 01:30 he comes from the forest behind the Lindenacker (robber_event arrived; the runtime schedule of the
##   graveyard Npc npc_robber through ScheduleBuilder), 01:50–05:00 he digs. A candle lit or a mortsafe set
##   before 01:30 keeps him away.
## - The gravekeeper ≤ 10 m in the graveyard while he digs: the first time he startles and runs (fled; the
##   care spot +1 – only dug at), later he stumbles and sits (seen → dialogue robber → resolve).
## - Undisturbed until 05:00: GraveCare.set_disturbed (care spot 3, ghost −3), the morning note; after the third
##   disturbed night Fenner's watchman catches him (caught_watch, no reputation).
## - He takes nothing and never harms anyone; the dead always stays in the grave (§14.4).

const GROUP := &"night_robber"
const FATES: Array[StringName] = [&"", &"reported", &"let_go", &"caught_watch"]
const EVENTS: Array[StringName] = [&"arrived", &"seen", &"fled", &"caught", &"disturbed", &"gone"]
const STATE_NONE := &""
const STATE_FLED := &"fled"
const STATE_SITTING := &"sitting"
const STATE_DONE := &"done"
const OPEN_FLAG := &"p8_open"
const OPEN_DAY_FLAG := &"p8_open_day"
const LIGHTS_DAY_FLAG := &"fest_lights_day"
const KNOWN_FLAG := &"robber_known"
const REGION_GRAVEYARD := &"graveyard"
const STAT_ENCOUNTERS := &"robber_encounters"
const CLUE_ROBBER := &"c_n_robber"
const NOTE_MINUTE := 360
const MINUTES_PER_DAY := 1440
const DIRT_PREFIX := "dirt_"
const NPC_NAME := "npc_robber"
const NOTE_DISTURBED := "Am Grab von %s ist die Erde aufgeworfen. Ein Spaten war hier, nicht deiner."
const NOTE_CAUGHT := "Fenners Nachtwächter hat einen mit Spaten am Lindenacker gefasst. „Drei offene Gräber, Totengräber. Drei.“"
const REASON_REPORT := "Den Nachtgräber zum Schultheiß gebracht"
const REASON_LET_GO := "Den Nachtgräber laufen lassen"
## Dialogue choices (DialogueActions robber_resolve:<choice>, P6).
const CHOICE_ASK := &"ask"
const CHOICE_REPORT := &"report"
const CHOICE_LET_GO := &"let_go"

@export var save_id: String = "night_robber"
@export var save_order: int = 77

## Rules; null = data/config/robber_config.tres (resolved lazily).
var config: RobberConfig

var _target_day: int = 0
var _target: String = ""
var _encounters: int = 0
var _disturbed: int = 0
var _last_night: int = -1
var _fate: StringName = &""
## Tonight: &"" (coming / digging) | fled | sitting | done.
var _state: StringName = &""
var _decided: int = -1
var _pending_note: String = ""
var _last_total: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	if _last_total < 0:
		_last_total = TimeManager.total_minutes()


## Grave id or "" – the target of night `day` (the night after that day; deterministic, saved from 00:00).
func tonight_target(day: int) -> String:
	return _target if day == _target_day else ""


## The phase of the robber now: &"" (none) | &"coming" | &"digging" | &"fled" | &"sitting" | &"gone".
func phase() -> StringName:
	if _target == "" or _fate != &"" and _state != STATE_SITTING:
		return &""
	var m := _night_minute()
	if m < 0:
		return &""
	var cfg := _cfg()
	if _state == STATE_FLED:
		return &"fled" if m < cfg.dig_until else &""
	if _state == STATE_SITTING:
		return &"sitting"
	if _state == STATE_DONE:
		return &""
	if m < cfg.arrive_minute:
		return &""
	if m < cfg.dig_from:
		return &"coming"
	if m < cfg.dig_until:
		return &"digging"
	return &""


## Appearance, digging, noticing, 05:00 disturbed (time_tick drives it; events between the last minute and now
## are handled once).
func apply_minute(day: int, minute: int) -> void:
	var now := (day - 1) * MINUTES_PER_DAY + minute
	if not GameState.flag_on(OPEN_FLAG):
		_last_total = now
		return
	var from := _last_total if _last_total >= 0 else now - 1
	if now < from:
		from = now - 1
	_last_total = now
	# 00:00 of day N + 1: decide night N.
	var night := day - 1
	if _decided < night and from < (day - 1) * MINUTES_PER_DAY + _cfg().arrive_minute:
		_decide(night)
	var base := (_target_day) * MINUTES_PER_DAY
	if _target != "" and _target_day == night:
		var cfg := _cfg()
		if _between(from, now, base + cfg.arrive_minute):
			_arrive()
		if _state == STATE_NONE and now >= base + cfg.dig_from and now < base + cfg.dig_until:
			_check_notice()
		if _between(from, now, base + cfg.dig_until):
			_dawn()
	if _pending_note != "" and minute >= NOTE_MINUTE:
		EventBus.notification_requested.emit(NOTE_DISTURBED % _dead_name(_pending_note), &"warning")
		_pending_note = ""


func encounters() -> int:
	return _encounters


## &"" | &"reported" | &"let_go" | &"caught_watch".
func fate() -> StringName:
	return _fate


## Disturbed nights so far.
func disturbed_count() -> int:
	return _disturbed


## Dialogue robber (second encounter): &"ask" (who pays him → c_n_robber), &"report" (to the mayor: reputation
## robber_reported, Fenner +4), &"let_go" (piety robber_let_go, Liesel +2, Fenner −2). Only while he sits.
func resolve(choice: StringName) -> void:
	if _state != STATE_SITTING:
		return
	var life := _first(&"npc_life")
	match choice:
		CHOICE_ASK:
			var journal := _first(&"journal")
			if journal != null and journal.has_method(&"add_clue"):
				journal.call(&"add_clue", CLUE_ROBBER, "", false)
			return
		CHOICE_REPORT, &"reported":
			_fate = &"reported"
			var rep := _first(&"reputation")
			if rep != null and rep.has_method(&"event"):
				rep.call(&"event", _cfg().report_rep, REASON_REPORT)
			_rel(RobberRules.MAYOR, RobberRules.REPORT_MAYOR, REASON_REPORT)
			if life != null and life.has_method(&"note_event"):
				life.call(&"note_event", &"robber_reported", [] as Array[StringName])
		CHOICE_LET_GO:
			_fate = &"let_go"
			var piety := _first(&"piety")
			if piety != null and piety.has_method(&"event"):
				piety.call(&"event", _cfg().let_go_piety, REASON_LET_GO)
			_rel(RobberRules.WASHER, RobberRules.LET_GO_WASHER, REASON_LET_GO)
			_rel(RobberRules.MAYOR, RobberRules.LET_GO_MAYOR, REASON_LET_GO)
			if life != null and life.has_method(&"note_event"):
				life.call(&"note_event", &"robber_let_go", [&"washer", &"beggar"] as Array[StringName])
		_:
			return
	_state = STATE_DONE
	_clear_schedule()
	EventBus.robber_event.emit(&"gone", _target)


## {target_day, target, encounters, disturbed, last_night, fate, state, decided, pending_note, last_total} (§5.1).
func save_state() -> Dictionary:
	return {"target_day": _target_day, "target": _target, "encounters": _encounters, "disturbed": _disturbed,
			"last_night": _last_night, "fate": String(_fate), "state": String(_state), "decided": _decided,
			"pending_note": _pending_note, "last_total": _last_total}


func load_state(data: Dictionary) -> void:
	_target_day = _int(data.get("target_day"), 0)
	_target = str(data.get("target", ""))
	_encounters = maxi(0, _int(data.get("encounters"), 0))
	_disturbed = maxi(0, _int(data.get("disturbed"), 0))
	_last_night = _int(data.get("last_night"), -1)
	if _last_night == 0:
		_last_night = -1
	var f := StringName(str(data.get("fate", "")))
	_fate = f if f in FATES else &""
	var s := StringName(str(data.get("state", "")))
	_state = s if s in [STATE_NONE, STATE_FLED, STATE_SITTING, STATE_DONE] else STATE_NONE
	_decided = _int(data.get("decided"), _target_day if _target != "" else -1)
	_pending_note = str(data.get("pending_note", ""))
	_last_total = _int(data.get("last_total"), TimeManager.total_minutes())


# --- internals -----------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	apply_minute(day, minute)


func _decide(night: int) -> void:
	_decided = night
	if _target != "" and _target_day == night:
		return
	_target = ""
	_state = STATE_NONE
	var cfg := _cfg()
	var lights: Variant = GameState.get_flag(LIGHTS_DAY_FLAG, -1)
	var friendship := _first(&"friendship")
	var watch := friendship != null and friendship.has_method(&"night_watch_tonight") and bool(friendship.call(&"night_watch_tonight"))
	if not RobberRules.night_open(night, _open_day(), _int(lights, -1), watch, _fate, cfg):
		return
	var candidates := _candidates(night)
	if candidates.is_empty():
		return
	if not RobberRules.comes(night, _last_night, _open_day(), cfg):
		return
	_target = RobberRules.freshest(candidates)
	_target_day = night


func _candidates(night: int) -> Array:
	var out: Array = []
	var graveyard := _first(&"graveyard") as Graveyard
	if graveyard == null:
		return out
	var care := _first(&"grave_care") as GraveCare
	var corpses := _first(&"corpse_manager") as CorpseManager
	var midnight := (night) * MINUTES_PER_DAY
	for grave: GraveRecord in graveyard.graves():
		var occupied := grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED
		if not occupied:
			continue
		var record := corpses.get_record(grave.corpse_id) if corpses != null else null
		var buried := record.buried_day if record != null and record.buried_day > 0 else grave.completed_day
		var mortsafe := care != null and care.has_mortsafe(grave.id)
		var candle := care != null and care.candle_lit_at(grave.id, midnight)
		var disturbed := grave.disturbed or (care != null and care.is_disturbed(grave.id))
		if RobberRules.is_target(buried, night, occupied, mortsafe, candle, disturbed, _cfg()):
			out.append({"grave_id": grave.id, "buried_day": buried})
	return out


## 01:30: he comes – unless the grave got a candle or a mortsafe since midnight.
func _arrive() -> void:
	if _state != STATE_NONE:
		return
	var care := _first(&"grave_care") as GraveCare
	var at := _target_day * MINUTES_PER_DAY + _cfg().arrive_minute
	if care != null and (care.candle_lit_at(_target, at) or care.has_mortsafe(_target)):
		_state = STATE_DONE
		return
	_last_night = _target_day
	_apply_schedule()
	EventBus.robber_event.emit(&"arrived", _target)


## The gravekeeper ≤ notice_distance m in the graveyard while he digs.
func _check_notice() -> void:
	var player := _first(&"player") as Node3D
	if player == null or not player.is_inside_tree():
		return
	if StringName(str(player.get(&"region_id"))) != REGION_GRAVEYARD or bool(player.get(&"in_interior")):
		return
	var plot := GraveView.plot_of(_target, get_tree())
	if plot == null:
		return
	var p := player.global_position
	var g := plot.global_position
	if Vector2(p.x - g.x, p.z - g.z).length() > _cfg().notice_distance:
		return
	GameState.add_stat(STAT_ENCOUNTERS, 1)
	GameState.set_flag(KNOWN_FLAG, true)
	if _encounters == 0:
		_encounters = 1
		_state = STATE_FLED
		var clean := _first(&"cleanliness")
		if clean != null and clean.has_method(&"set_level") and clean.has_method(&"level"):
			var spot := DIRT_PREFIX + _target
			clean.call(&"set_level", spot, mini(int(clean.call(&"level", spot)) + 1, 3))
		_flee_schedule()
		EventBus.robber_event.emit(&"fled", _target)
	else:
		_encounters += 1
		_state = STATE_SITTING
		_sit_schedule()
		EventBus.robber_event.emit(&"seen", _target)


## 05:00: undisturbed → the grave is disturbed (the dead stays); he leaves either way.
func _dawn() -> void:
	match _state:
		STATE_NONE:
			var care := _first(&"grave_care") as GraveCare
			if care != null:
				care.set_disturbed(_target)
			_disturbed += 1
			_pending_note = _target
			_state = STATE_DONE
			var life := _first(&"npc_life")
			if life != null and life.has_method(&"note_event"):
				life.call(&"note_event", &"grave_disturbed", [] as Array[StringName])
			EventBus.robber_event.emit(&"disturbed", _target)
			if _disturbed >= _cfg().watch_catch_after and _fate == &"":
				_fate = &"caught_watch"
				EventBus.notification_requested.emit(NOTE_CAUGHT, &"info")
				EventBus.robber_event.emit(&"caught", _target)
		STATE_SITTING:
			_state = STATE_DONE
			EventBus.robber_event.emit(&"gone", _target)
		_:
			_state = STATE_DONE
	_clear_schedule()


func _between(from: int, now: int, t: int) -> bool:
	return t > from and t <= now


## Minute of night `_target_day` now (relative to 00:00 of the following day; −1 = another night).
func _night_minute() -> int:
	var now := TimeManager.total_minutes()
	var rel := now - _target_day * MINUTES_PER_DAY
	return rel if rel >= -720 and rel < 720 else -1


func _rel(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"add"):
		rel.call(&"add", npc_id, delta, reason)


# --- the visible robber (runtime schedule of npc_robber) -----------------------------------------

func _npc() -> Node:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		if String(node.name) == NPC_NAME:
			return node
	return null


func _route() -> PackedStringArray:
	var out := PackedStringArray(["robber_far", "robber_fence_out"])
	# W-Welt (W2): from the fence over the south strip around the graves (WorldRoot.route_between), not straight.
	var world := _first(&"world")
	if world != null and world.has_method(&"route_between"):
		out.append_array(world.call(&"route_between", "robber_fence_in", "gv_" + _target))
	else:
		out.append_array(PackedStringArray(["robber_fence_in", "gv_" + _target]))
	return out


func _apply_schedule() -> void:
	var npc := _npc()
	if npc == null or not npc.has_method(&"set_runtime_schedule"):
		return
	var cfg := _cfg()
	var world := _first(&"world")
	# W-Welt (W2, §4.7 Räuberweg): out of the forest to the fence, over it (climb, one minute), then the route.
	var route := _route()
	var to_fence := ScheduleBuilder.walk(&"robber_far", PackedStringArray(["robber_fence_out"]), cfg.arrive_minute, &"", world)
	var over := _climb(&"robber_fence_out", &"robber_fence_in", cfg.arrive_minute + to_fence.travel_minutes)
	var to_grave := ScheduleBuilder.walk(&"robber_fence_in", route.slice(route.find("robber_fence_in") + 1), over.start_minute + 1, &"", world)
	var entries: Array[ScheduleEntry] = [to_fence, over, to_grave,
		ScheduleBuilder.stay(StringName("gv_" + _target), cfg.dig_from, &"dig_night", &"robber"),
	]
	npc.call(&"set_runtime_schedule", ScheduleBuilder.build(entries))


## One minute over the south fence of the Lindenacker (the walk entry's gait climb, Npc._moving_anim).
func _climb(from_wp: StringName, to_wp: StringName, start: int) -> ScheduleEntry:
	var e := ScheduleBuilder.walk(from_wp, PackedStringArray([String(to_wp)]), start, &"", null)
	e.travel_minutes = 1
	e.animation = &"climb"
	return e


func _flee_schedule() -> void:
	var npc := _npc()
	if npc == null or not npc.has_method(&"set_runtime_schedule"):
		return
	var back := _route()
	back.reverse()
	# W-Welt (W2): at a run to the fence, over it, into the forest (§2.6.3 „läuft zum Südzaun").
	var world := _first(&"world")
	var cut := back.find("robber_fence_in")
	var now := TimeManager.minute_of_day
	var to_fence := ScheduleBuilder.walk(StringName("gv_" + _target), back.slice(0, cut + 1), now, &"", world)
	to_fence.animation = &"run"
	to_fence.travel_minutes = maxi(1, ceili(to_fence.travel_minutes * 0.5))
	var over := _climb(&"robber_fence_in", &"robber_fence_out", now + to_fence.travel_minutes)
	var away := ScheduleBuilder.walk(&"robber_fence_out", back.slice(cut + 2), over.start_minute + 1, &"", world)
	away.animation = &"run"
	away.travel_minutes = maxi(1, ceili(away.travel_minutes * 0.5))
	var entries: Array[ScheduleEntry] = [to_fence, over, away]
	npc.call(&"set_runtime_schedule", ScheduleBuilder.build(entries))


func _sit_schedule() -> void:
	var npc := _npc()
	if npc == null or not npc.has_method(&"set_runtime_schedule"):
		return
	var entries: Array[ScheduleEntry] = [ScheduleBuilder.stay(StringName("gv_" + _target), TimeManager.minute_of_day, &"sit_ground", &"robber")]
	npc.call(&"set_runtime_schedule", ScheduleBuilder.build(entries))


func _clear_schedule() -> void:
	var npc := _npc()
	if npc != null and npc.has_method(&"clear_runtime_schedule"):
		npc.call(&"clear_runtime_schedule")


func _dead_name(grave_id: String) -> String:
	var graveyard := _first(&"graveyard") as Graveyard
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	var corpses := _first(&"corpse_manager") as CorpseManager
	var record := corpses.get_record(grave.corpse_id) if corpses != null and grave != null else null
	return record.display_name if record != null and record.display_name != "" else grave_id


func _open_day() -> int:
	return _int(GameState.get_flag(OPEN_DAY_FLAG, 0), 0)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	return fallback


func _cfg() -> RobberConfig:
	if config == null:
		config = Database.config(&"robber_config") as RobberConfig
	if config == null:
		config = RobberConfig.new()
	return config
