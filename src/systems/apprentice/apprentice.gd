class_name Apprentice
extends Node
## Systems/Apprentice (docs/PHASE8_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1), groups &"apprentice", &"saveable"
## (save_order 73): Jakob Wackernagel.
## - hire (Rosine step 1): flag apprentice_hired, event apprentice_hired (NpcLife); he works from the next day.
## - Working day (ApprenticeRules.works_today; not on the hire day): 08:15 up the coach road to the chalk
##   board, 08:25 reading the list (the day plan – ApprenticePlanner – is made then, saved with its progress),
##   08:30 work, 12:00 lunch on the bench, 15:30 tools back to his box and the wage from the tin, 15:40 home.
##   Everything is shown by the runtime schedule of npc_apprentice (graveyard) and npc_apprentice_v
##   (village: 07:30 breakfast in the inn, over the bridge; 17:00–21:00 helping in the inn; a day off in the
##   inn) – rebuilt from plan + clock, never saved.
## - The effect of a place comes at its end (apply_minute, catching up after a skip), through the same calls
##   as the player's: CleanlinessManager.tend_by, GraveCare.water / light / refill. A mistake
##   (ApprenticeRules.mistake, planned deterministically) has its effect (neighbour spot +1 leaves, flowers
##   torn / trodden, a broken candle), a speech bubble (chatter_line) and counts for the day.
## - Teaching (start_teach: he comes within 2 m and watches, following the gravekeeper) → the next fitting
##   player job (note_player_job) ≤ teach_distance makes the task Angelernt; 12 own places → Geübt
##   (apprentice_level_changed).
## - Praise / scolding once per day (scolding only after a mistake today or yesterday): morale ±1;
##   scolded → mistakes × 0.5 tomorrow, Rosine −1 (jakob_scolded).
## - The wage (3) at 15:30 from ApprenticeBox.coins (with the debt of earlier days when it fits); none →
##   „Jakob geht heute ohne Lohn heim.", Rosine −2, morale −2; after unpaid_limit days in a row he stays at
##   home until the whole debt lies in the tin (then he comes the next morning).
## Never: corpses, graves, stones, stations, buildings, the crypt, the chapel, the shed, the hut, the night
## (§2.5.6) – the planner only knows care spots, flowers and candles.

const GROUP := &"apprentice"
const TASKS: Array[StringName] = [&"rake", &"weed", &"water", &"candle"]
const LEVEL_UNTRAINED := 0
const LEVEL_TAUGHT := 1
const LEVEL_PRACTISED := 2
const AREAS: Array[StringName] = [&"yard", &"east", &"north", &"elder", &"linden", &"all", &"wished"]
const TEXT_NOT_SHOWN := "Das hast du mir noch nicht gezeigt."
const TEXT_NOT_HIRED := "Jakob arbeitet nicht für dich."
const TEXT_KNOWS := "Das kann er schon."
const TEXT_ABSENT := "Jakob ist nicht da."
const TEXT_TOO_FAR := "Jakob ist zu weit weg."
const TEXT_WATCHING := "Jakob schaut dir schon zu."
const TEXT_UNKNOWN_TASK := "Das ist keine Arbeit für Jakob."
const TEXT_TAUGHT := {
	&"rake": "Ah. Von unten nach oben, nicht hin und her.",
	&"weed": "Mit der Wurzel. Sonst kommt es wieder.",
	&"water": "Unten an die Wurzeln, nicht auf die Blüten.",
	&"candle": "Erst den Docht, dann das Glas. Verstanden.",
}
const TEXT_PRACTISED := "Jakob kann jetzt %s, ohne nachzudenken."
const TEXT_UNPAID := "Jakob geht heute ohne Lohn heim."
const TEXT_STAYS_HOME := "Jakob bleibt daheim, bis die Schuld in der Dose liegt."
const TEXT_MISSING := {&"grave_candle": "Keine Kerzen mehr.", &"apprentice_rake": "Ich hab keinen Rechen.",
		&"watering_can": "Ich hab keine Gießkanne."}
const COIN_REASON := &"apprentice"
const REASON_SCOLDED := "Jakob getadelt"
const REASON_UNPAID := "Jakob ohne Lohn"
const EVENT_HIRED := &"apprentice_hired"
const EVENT_SCOLDED := &"jakob_scolded"
const INNKEEPER := &"innkeeper"
const BUBBLE_ID := &"apprentice"
const MORALE_MAX := 5
## Teaching: he comes this close (m), and is re-sent when the gravekeeper moves farther than FOLLOW_SLACK.
const WATCH_DISTANCE := 2.0
const FOLLOW_SLACK := 1.5
## „Jakob auf dem Friedhof, ≤ 30 m" (§1.3).
const TEACH_RANGE := 30.0
## Waypoints of the hut corner (W-Welt §4.3; places without a waypoint use the entity, else are left out).
const WP_ROAD := "road_end"
const ROUTE_IN: PackedStringArray = ["road_end", "road_mid", "gate_outside", "gate_inside"]
const WP_BOARD := "apprentice_board"
const WP_BOX := "apprentice_box"
const V_INN := "v_in_inn_jakob"
const V_ROUTE_OUT: PackedStringArray = ["v_in_inn_jakob", "v_inn_door", "v_bridge", "v_road_in"]
const V_ROUTE_IN: PackedStringArray = ["v_road_in", "v_bridge", "v_inn_door", "v_in_inn_jakob"]
const V_BREAKFAST := 450
const V_LEAVE := 465
const V_EVENING := 1020
const V_NIGHT := 1260
const DIALOGUE := &"v_apprentice"
const TASK_FIRST_DAY := &"apprentice_first_day"
const TASK_DAY_OFF := &"jakob_day_off"
const STAT_DAYS := &"apprentice_days"
const STAT_JOBS := &"apprentice_jobs"
const STAT_MISTAKES := &"apprentice_mistakes"
const STAT_WAGE := &"apprentice_wage"
const ANIM := {&"rake": &"rake", &"weed": &"weed", &"water": &"water", &"candle": &"candle", &"refill": &"water",
		&"lunch": &"sit_eat", &"sweep": &"sweep"}

@export var save_id: String = "apprentice"
@export var save_order: int = 73

## Rules; null = data/config/apprentice_config.tres (resolved lazily).
var config: ApprenticeConfig
## Tests: the box / the Npc instead of the tree's (group apprentice_box; Npc npc_id == config.npc_id).
var box: ApprenticeBox
var npc: Npc
var village_npc: Npc
## Tests: tasks {id: ApprenticeTaskData} for the planner (else Database).
var tasks: Dictionary = {}

var _hired: bool = false
var _hire_day: int = 0
var _levels: Dictionary[StringName, int] = {}
var _jobs: Dictionary[StringName, int] = {}
var _board: Array[Dictionary] = []
var _morale: int = 3
var _unpaid: int = 0
var _debt: int = 0
var _teach: StringName = &""
## The day the daily state belongs to (mistakes_today, judged, wage).
var _day: int = 0
var _plan_day: int = 0
var _plan: Array[Dictionary] = []
var _progress: int = 0
var _praised_day: int = 0
var _scolded_day: int = 0
var _judged_day: int = 0
var _mistakes_today: int = 0
var _last_mistake_day: int = 0
var _wage_day: int = 0
var _missing: Array[StringName] = []
## Teaching: where he stands watching (point id) and since when (minute of day).
var _watch_point: String = ""
var _watch_minute: int = -1
## Orders.note_task bookkeeping (P4): the first working day reported, the last day off reported.
var _first_day_done: bool = false
var _day_off_noted: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- state ----------------------------------------------------------------------------------------

func is_hired() -> bool:
	return _hired


## Rosine step 1: flag apprentice_hired, apprentice_hired event; he starts the next morning.
func hire() -> void:
	if _hired:
		return
	_hired = true
	_hire_day = TimeManager.day
	_morale = _cfg().morale_start
	GameState.set_flag(_cfg().hire_flag, true)
	var life := _first(&"npc_life")
	if life != null and life.has_method(&"note_event"):
		life.call(&"note_event", EVENT_HIRED, [] as Array[StringName])
	refresh_npcs()


## 0 Ungelernt · 1 Angelernt · 2 Geübt.
func level(task_id: StringName) -> int:
	return clampi(int(_levels.get(task_id, 0)), LEVEL_UNTRAINED, LEVEL_PRACTISED)


## Places done of this task (practice).
func jobs(task_id: StringName) -> int:
	return int(_jobs.get(task_id, 0))


## [{task, area}].
func board_lines() -> Array[Dictionary]:
	return _board.duplicate(true)


## At most board_lines lines of known tasks and areas. Before the board is read (08:25) they hold today;
## later they hold from the next place on (the running one is finished).
func set_board_lines(lines: Array[Dictionary]) -> void:
	var clean: Array[Dictionary] = []
	for line: Dictionary in lines:
		var task := StringName(str(line.get("task", "")))
		var area := StringName(str(line.get("area", "all")))
		if task in TASKS and area in AREAS and clean.size() < _cfg().board_lines:
			clean.append({"task": String(task), "area": String(area)})
	_board = clean
	if _plan_day == TimeManager.day and works_today(TimeManager.day) and TimeManager.minute_of_day < _cfg().end_minute:
		_replan_from_running(TimeManager.minute_of_day)


func teach_block_reason(task_id: StringName, player: Player) -> String:
	if not _hired:
		return TEXT_NOT_HIRED
	if not task_id in TASKS:
		return TEXT_UNKNOWN_TASK
	if level(task_id) > LEVEL_UNTRAINED:
		return TEXT_KNOWS
	if _teach != &"":
		return TEXT_WATCHING
	if not on_graveyard():
		return TEXT_ABSENT
	if player != null and _flat(player.global_position, position_now()) > TEACH_RANGE:
		return TEXT_TOO_FAR
	return ""


## Jakob comes within 2 m and watches (following the gravekeeper) until the next fitting player job.
func start_teach(task_id: StringName) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null
	if teach_block_reason(task_id, player) != "":
		return
	_teach = task_id
	_watch_minute = TimeManager.minute_of_day
	_send_to_watch(player.global_position if player != null else position_now())


## The task being shown (&"" = none).
func teaching() -> StringName:
	return _teach


## A finished player action (kind leaves / weeds / water / candle, or the task id) → Angelernt when he
## watched it within teach_distance.
func note_player_job(task_kind: StringName, pos: Vector3) -> void:
	var task := _task_of_kind(task_kind)
	if task == &"" or task != _teach or level(task) > LEVEL_UNTRAINED:
		return
	if _flat(pos, position_now()) > _cfg().teach_distance:
		return
	_teach = &""
	_watch_point = ""
	_watch_minute = -1
	_set_level(task, LEVEL_TAUGHT)
	_bubble(str(TEXT_TAUGHT.get(task, "Verstanden.")))
	if _plan_day == TimeManager.day and works_today(TimeManager.day):
		_replan_from(TimeManager.minute_of_day, position_point())
	else:
		refresh_npcs()


## Once per day (praise or scolding): morale +1.
func praise() -> bool:
	if not _hired or _judged_day == TimeManager.day:
		return false
	_judged_day = TimeManager.day
	_praised_day = TimeManager.day
	_morale = mini(_morale + 1, MORALE_MAX)
	return true


## After a mistake (today or yesterday), once per day: morale −1, mistakes × 0.5 tomorrow, Rosine −1
## (jakob_scolded).
func scold() -> bool:
	var day := TimeManager.day
	if not _hired or _judged_day == day or _last_mistake_day <= 0 or day - _last_mistake_day > 1:
		return false
	_judged_day = day
	_scolded_day = day
	_morale = maxi(_morale - 1, 0)
	_rel_add(INNKEEPER, _gain(&"jakob_scolded", -1), REASON_SCOLDED)
	var life := _first(&"npc_life")
	if life != null and life.has_method(&"note_event"):
		life.call(&"note_event", EVENT_SCOLDED, [INNKEEPER] as Array[StringName])
	return true


## The scolding of yesterday halves today's mistakes.
func scolded_yesterday(day: int = -1) -> bool:
	var d := day if day > 0 else TimeManager.day
	return _scolded_day > 0 and _scolded_day == d - 1


## A mistake today (dialogue apprentice_mistake_today).
func mistakes_today() -> int:
	return _mistakes_today if _day == TimeManager.day else 0


## 0…5.
func morale() -> int:
	return _morale


func unpaid_days() -> int:
	return _unpaid


## Coins he is still owed.
func debt() -> int:
	return _debt


## Items missing for the board ("Keine Kerzen mehr." in the evening at the board).
func missing_items() -> Array[StringName]:
	return _missing.duplicate()


## 15:30 from ApprenticeBox.coins: the wage (and the debt when it fits). false = no wage today.
func pay_wage() -> bool:
	var cfg := _cfg()
	_wage_day = TimeManager.day
	var b := _box()
	var coins := b.coins if b != null else 0
	if coins >= cfg.wage:
		var take := cfg.wage + (_debt if coins >= cfg.wage + _debt else 0)
		if take > cfg.wage:
			_debt = 0
		b.coins -= take
		_unpaid = 0
		GameState.note_coins_spent(take, COIN_REASON)
		GameState.add_stat(STAT_WAGE, take)
		return true
	_unpaid += 1
	_debt += cfg.wage
	_morale = maxi(_morale - 2, 0)
	_rel_add(INNKEEPER, _gain(&"jakob_unpaid", -2), REASON_UNPAID)
	EventBus.notification_requested.emit(TEXT_UNPAID if _unpaid < cfg.unpaid_limit else TEXT_STAYS_HOME, &"info")
	return false


## He works on `day` (hired before that day, not his day off, no festival, not too many unpaid days).
func works_today(day: int) -> bool:
	return _hired and day > _hire_day and ApprenticeRules.works_today(day, _hired, _unpaid, _fest_today(day), _cfg())


## He is on the graveyard now (a working day between arrival and leaving).
func on_graveyard() -> bool:
	var m := TimeManager.minute_of_day
	return works_today(TimeManager.day) and m >= _cfg().arrive_minute and m < _cfg().end_minute + 10


## From the board + the state at start_minute, saved with the progress.
func today_plan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _plan_day == TimeManager.day:
		out.assign(_plan.duplicate(true))
	return out


## Index of the next place whose effect is still to come.
func progress() -> int:
	return _progress


## time_tick: the day (morning debt, plan at 08:25), the effects of finished places, the wage at 15:30,
## following while he watches. Also catches up after a time skip.
func apply_minute(day: int, minute: int) -> void:
	if not _hired:
		return
	var cfg := _cfg()
	if day != _day:
		_new_day(day)
	if not works_today(day):
		# P4 (of_rosine_return_2 „Ein Tag für Jakob"): a day off of a hired apprentice, reported at 15:30.
		if day > _hire_day and _unpaid < cfg.unpaid_limit and minute >= cfg.end_minute and _day_off_noted != day:
			_day_off_noted = day
			_note_task(TASK_DAY_OFF)
		return
	if _plan_day != day and minute >= board_minute():
		_make_plan(day)
	if _plan_day == day:
		_apply_effects(day, minute)
	if minute >= cfg.end_minute and _wage_day != day:
		pay_wage()
		# P4 (of_rosine_1 „Der Junge"): his first working day is done.
		if not _first_day_done:
			_first_day_done = true
			_note_task(TASK_FIRST_DAY)
	if _teach != &"":
		if minute >= cfg.end_minute:
			_teach = &""
			_watch_point = ""
			refresh_npcs()
		else:
			_follow()


# --- npcs -----------------------------------------------------------------------------------------

## Rebuilds the runtime schedules of the graveyard and the village Npc from plan + clock.
func refresh_npcs() -> void:
	var g := _npc()
	if g != null:
		g.set_runtime_schedule(graveyard_schedule(TimeManager.day))
	var v := _village_npc()
	if v != null:
		v.set_runtime_schedule(village_schedule(TimeManager.day))


## The graveyard day of `day`: up the road, the board, the plan (walk + work per place), teaching, the box,
## home. Empty (hidden) on a day he does not work.
func graveyard_schedule(day: int) -> NpcSchedule:
	var cfg := _cfg()
	var entries: Array[ScheduleEntry] = []
	if not works_today(day):
		return ScheduleBuilder.build(entries)
	var world := _world()
	var board := _place(WP_BOARD)
	var route := _known(ROUTE_IN, world)
	if board != "":
		route.append(board)
	# W-Welt (W2): the baked way up to the board around the old graves (WorldRoot.visitor_route).
	if board != "" and world != null and world.has_method(&"visitor_route"):
		var baked: PackedStringArray = world.call(&"visitor_route", board)
		if not baked.is_empty():
			route = baked
	if route.is_empty():
		return ScheduleBuilder.build(entries)
	entries.append(ScheduleBuilder.walk(StringName(route[0]), route.slice(1), cfg.arrive_minute, &"graveyard", world))
	var here := route[route.size() - 1]
	entries.append(ScheduleBuilder.stay(StringName(here), board_minute(), &"read_board", DIALOGUE))
	var teaching := _teach != &"" and _watch_point != "" and _watch_minute >= 0
	var cut := _watch_minute if teaching else 99999
	if _plan_day == day:
		for e: Dictionary in _plan:
			if int(e.start) >= cut:
				break
			var path: PackedStringArray = e.path
			if path.size() >= 2 and int(e.walk_minutes) > 0:
				entries.append(ScheduleBuilder.walk(StringName(path[0]), path.slice(1), int(e.start), &"graveyard", world))
			if not path.is_empty():
				here = path[path.size() - 1]
			var anim: StringName = ANIM.get(StringName(str(e.task)), &"idle")
			entries.append(ScheduleBuilder.stay(StringName(here), int(e.work_start), anim, DIALOGUE))
	if teaching:
		var from := position_point_at(cut, here)
		var watch := ScheduleBuilder.walk(StringName(from), _way(world, from, _watch_point), cut, &"graveyard", world)
		entries.append(watch)
		entries.append(ScheduleBuilder.stay(StringName(_watch_point), cut + watch.travel_minutes, &"watch", DIALOGUE))
		here = _watch_point
	var box_wp := _place(WP_BOX)
	if box_wp == "":
		box_wp = here
	var to_box := ScheduleBuilder.walk(StringName(here), _way(world, here, box_wp), cfg.end_minute, &"graveyard", world)
	entries.append(to_box)
	entries.append(ScheduleBuilder.stay(StringName(box_wp), cfg.end_minute + to_box.travel_minutes, &"idle", DIALOGUE))
	var out := PackedStringArray()
	for i: int in range(route.size() - 1, -1, -1):
		if route[i] != board:
			out.append(route[i])
	if box_wp != board and not out.is_empty():
		out = _way(world, box_wp, out[0]) + out.slice(1)
	if not out.is_empty():
		entries.append(ScheduleBuilder.walk(StringName(box_wp), out, cfg.end_minute + 10, &"graveyard", world))
	return ScheduleBuilder.build(entries)


## W-Welt (W2): the way from `a` to `b` on the graveyard (WorldRoot.route_between, without `a`), else [b].
static func _way(world: Node, a: String, b: String) -> PackedStringArray:
	if world != null and world.has_method(&"route_between") and a != "" and b != "" and a != b:
		return (world.call(&"route_between", a, b) as PackedStringArray).slice(1)
	return PackedStringArray([b])


## The village day: a working day breakfast in the inn (07:30), over the bridge (07:45), helping Rosine
## 17:00–21:00; a day off in the inn all day; not hired: empty (the data schedule, if any, is P6's).
func village_schedule(day: int) -> NpcSchedule:
	var entries: Array[ScheduleEntry] = []
	var v := _village_npc()
	var world: Node = v._world() if v != null else null
	if not _hired or not ScheduleBuilder.has_point(world, V_INN):
		return ScheduleBuilder.build(entries)
	if day > _hire_day and works_today(day):
		entries.append(ScheduleBuilder.stay(StringName(V_INN), V_BREAKFAST, &"idle", DIALOGUE))
		var out := _known(V_ROUTE_OUT, world)
		if out.size() >= 2:
			var leave := ScheduleBuilder.walk(StringName(out[0]), out.slice(1), V_LEAVE, &"village", world)
			entries.append(leave)
			entries.append(ScheduleBuilder.stay(StringName(out[out.size() - 1]), V_LEAVE + maxi(leave.travel_minutes, 1), &"idle", &"",
					false))
		var back := _known(V_ROUTE_IN, world)
		if back.size() >= 2:
			entries.append(ScheduleBuilder.walk(StringName(back[0]), back.slice(1), V_EVENING - 15, &"village", world))
		entries.append(ScheduleBuilder.stay(StringName(V_INN), V_EVENING, &"idle", DIALOGUE))
	else:
		entries.append(ScheduleBuilder.stay(StringName(V_INN), V_BREAKFAST, &"idle", DIALOGUE))
	entries.append(ScheduleBuilder.stay(StringName(V_INN), V_NIGHT, &"idle", &"", false))
	for e: ScheduleEntry in entries:
		e.region = &"village"
	return ScheduleBuilder.build(entries)


## When he reads the board: 08:25 (start_minute − 5), later when the walk up from the road end takes longer.
func board_minute() -> int:
	var cfg := _cfg()
	var route := _known(ROUTE_IN, _world())
	var board := _place(WP_BOARD)
	if board != "":
		route.append(board)
	return maxi(cfg.start_minute - 5, cfg.arrive_minute + ScheduleBuilder.travel_minutes(route, _world()))


## When the work begins: 08:30 (start_minute), at least 5 minutes after reading the board.
func work_minute() -> int:
	return maxi(_cfg().start_minute, board_minute() + 5)


## Where he is now (the Npc, else the end of the current plan step / the watch point).
func position_now() -> Vector3:
	var g := _npc()
	if g != null and g.is_inside_tree():
		return g.global_position
	return ScheduleBuilder.point(_world(), position_point())


## The point id where he stands now (watch point, current plan step, the board).
func position_point() -> String:
	if _teach != &"" and _watch_point != "":
		return _watch_point
	return position_point_at(TimeManager.minute_of_day, _place(WP_BOARD))


func position_point_at(minute: int, fallback: String) -> String:
	var here := fallback
	if _plan_day != TimeManager.day:
		return here
	for e: Dictionary in _plan:
		if int(e.start) > minute:
			break
		var path: PackedStringArray = e.path
		if not path.is_empty():
			here = path[path.size() - 1] if minute >= int(e.work_start) or path.size() < 2 else path[0]
	return here


# --- save -----------------------------------------------------------------------------------------

## {hired, hire_day, levels, jobs, teach, board, plan_day, plan, progress, morale, unpaid, debt, praised_day,
## scolded_day, judged_day, mistakes_today, last_mistake_day, wage_day, day, missing} (§5.1).
func save_state() -> Dictionary:
	var plan: Array = []
	for e: Dictionary in _plan:
		var d := e.duplicate(true)
		d["path"] = Array(e.path as PackedStringArray)
		d["task"] = str(e.task)
		d["kind"] = str(e.kind)
		plan.append(d)
	return {"hired": _hired, "hire_day": _hire_day, "levels": _names_out(_levels), "jobs": _names_out(_jobs),
			"teach": String(_teach), "watch_point": _watch_point, "watch_minute": _watch_minute, "board": _board.duplicate(true),
			"plan_day": _plan_day, "plan": plan, "progress": _progress, "morale": _morale, "unpaid": _unpaid, "debt": _debt,
			"praised_day": _praised_day, "scolded_day": _scolded_day, "judged_day": _judged_day, "mistakes_today": _mistakes_today,
			"last_mistake_day": _last_mistake_day, "wage_day": _wage_day, "day": _day, "first_day_done": _first_day_done,
			"day_off_noted": _day_off_noted,
			"missing": _missing.map(func(i: StringName) -> String: return String(i))}


## Tolerant: missing / damaged keys fall back to the defaults ({} = not hired); levels clamped 0…2.
func load_state(data: Dictionary) -> void:
	_hired = typeof(data.get("hired")) == TYPE_BOOL and bool(data.get("hired"))
	_hire_day = maxi(_int(data.get("hire_day"), 0), 0)
	_levels.clear()
	var levels: Variant = data.get("levels", {})
	if levels is Dictionary:
		for key: Variant in levels:
			if StringName(str(key)) in TASKS:
				_levels[StringName(str(key))] = clampi(_int(levels[key], 0), LEVEL_UNTRAINED, LEVEL_PRACTISED)
	_jobs.clear()
	var jobs_done: Variant = data.get("jobs", {})
	if jobs_done is Dictionary:
		for key: Variant in jobs_done:
			_jobs[StringName(str(key))] = maxi(_int(jobs_done[key], 0), 0)
	_board.clear()
	var board: Variant = data.get("board", [])
	if board is Array:
		for line: Variant in board:
			if line is Dictionary and _board.size() < _cfg().board_lines:
				_board.append({"task": str((line as Dictionary).get("task", "")), "area": str((line as Dictionary).get("area", "all"))})
	_morale = clampi(_int(data.get("morale"), _cfg().morale_start), 0, MORALE_MAX)
	_unpaid = maxi(_int(data.get("unpaid"), 0), 0)
	_debt = maxi(_int(data.get("debt"), _unpaid * _cfg().wage), 0)
	var teach := StringName(str(data.get("teach", "")))
	_teach = teach if teach in TASKS else &""
	_watch_point = str(data.get("watch_point", "")) if _teach != &"" else ""
	_watch_minute = _int(data.get("watch_minute"), -1) if _teach != &"" else -1
	_plan_day = _int(data.get("plan_day"), 0)
	_plan.clear()
	var plan: Variant = data.get("plan", [])
	if plan is Array:
		for raw: Variant in plan:
			var e := _entry_in(raw)
			if not e.is_empty():
				_plan.append(e)
	if _plan_day != TimeManager.day:
		_plan.clear()
		_plan_day = 0
	_progress = clampi(_int(data.get("progress"), 0), 0, _plan.size())
	_praised_day = _int(data.get("praised_day"), 0)
	_scolded_day = _int(data.get("scolded_day"), 0)
	_judged_day = _int(data.get("judged_day"), maxi(_praised_day, _scolded_day))
	_mistakes_today = maxi(_int(data.get("mistakes_today"), 0), 0)
	_last_mistake_day = _int(data.get("last_mistake_day"), 0)
	_wage_day = _int(data.get("wage_day"), 0)
	_first_day_done = data.get("first_day_done") is bool and bool(data.get("first_day_done"))
	_day_off_noted = _int(data.get("day_off_noted"), 0)
	_day = _int(data.get("day"), TimeManager.day if not data.is_empty() else 0)
	_missing.clear()
	var missing: Variant = data.get("missing", [])
	if missing is Array:
		for m: Variant in missing:
			_missing.append(StringName(str(m)))
	if is_inside_tree():
		refresh_npcs.call_deferred()


func post_load() -> void:
	refresh_npcs()


# --- internals ------------------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_minute(day, minute)


## A new day: the daily state, the debt from the tin in the morning (then he comes), the day off.
func _new_day(day: int) -> void:
	var cfg := _cfg()
	_day = day
	_mistakes_today = 0
	if _plan_day != day:
		_plan.clear()
		_progress = 0
		# W-Welt (W2, test_phase8_loop): like load_state – a plan of an earlier day is gone, so a day without work
		# (a festival) saves plan_day 0 before and after a load.
		_plan_day = 0
	_teach = &""
	_watch_point = ""
	_watch_minute = -1
	if _unpaid >= cfg.unpaid_limit:
		var b := _box()
		if b != null and b.coins >= _debt and _debt > 0:
			b.coins -= _debt
			GameState.note_coins_spent(_debt, COIN_REASON)
			GameState.add_stat(STAT_WAGE, _debt)
			_debt = 0
			_unpaid = 0
	if works_today(day):
		GameState.add_stat(STAT_DAYS, 1)
	refresh_npcs()


func _make_plan(day: int) -> void:
	_plan_day = day
	_progress = 0
	var items := _box_items()
	_missing = ApprenticePlanner.missing_items(_board, items, _planner_state(items, ""))
	_plan = ApprenticePlanner.plan(day, work_minute(), _board, _planner_state(items, _place(WP_BOARD)), get_tree(), _cfg())
	refresh_npcs()


## Board changed after 08:25: the running place is finished, the rest is planned anew from its end.
func _replan_from_running(minute: int) -> void:
	var keep := _progress
	while keep < _plan.size() and int(_plan[keep].start) <= minute:
		keep += 1
	var from := maxi(minute, work_minute())
	var here := _place(WP_BOARD)
	if keep > 0:
		from = maxi(from, int(_plan[keep - 1].end))
		var path: PackedStringArray = _plan[keep - 1].path
		if not path.is_empty():
			here = path[path.size() - 1]
	_plan.resize(keep)
	_plan.append_array(ApprenticePlanner.plan(_plan_day, from, _board, _planner_state(_box_items(), here), get_tree(), _cfg()))
	refresh_npcs()


## After teaching: the places not reached are dropped, the rest of the day is planned from `minute` at `here`.
func _replan_from(minute: int, here: String) -> void:
	_plan.resize(_progress)
	var done := {}
	for e: Dictionary in _plan:
		done[str(e.spot_id)] = true
	var state := _planner_state(_box_items(), here)
	state["done"] = done.keys()
	_plan.append_array(ApprenticePlanner.plan(_plan_day, maxi(minute, work_minute()), _board, state, get_tree(), _cfg()))
	refresh_npcs()


func _planner_state(items: Dictionary, here: String) -> Dictionary:
	var state := {"levels": _names_out(_levels), "morale": _morale, "scolded": scolded_yesterday(_plan_day if _plan_day > 0 else -1),
			"position": here, "fills": _fills(), "items": items, "world": _world()}
	if not tasks.is_empty():
		state["tasks"] = tasks
	var done: Array = []
	for e: Dictionary in _plan:
		done.append(str(e.spot_id))
	state["done"] = done
	return state


func _apply_effects(day: int, minute: int) -> void:
	while _progress < _plan.size() and int(_plan[_progress].end) <= minute:
		if _teach != &"" and int(_plan[_progress].start) >= _watch_minute:
			return
		var e: Dictionary = _plan[_progress]
		_progress += 1
		_effect(e, day)


func _effect(e: Dictionary, day: int) -> void:
	var task := StringName(str(e.task))
	var spot := str(e.spot_id)
	var grave := str(e.grave_id)
	var care := _first(&"grave_care")
	match task:
		ApprenticePlanner.TASK_REFILL:
			if care != null:
				care.call(&"refill", GraveCare.OWNER_APPRENTICE)
			return
		ApprenticePlanner.TASK_LUNCH, ApprenticePlanner.TASK_SWEEP:
			return
	if grave != "" and _mourned_now(grave):
		return
	var mistake := bool(e.get("mistake", false))
	var done := false
	match task:
		&"rake", &"weed":
			var clean := _first(&"cleanliness")
			done = clean != null and bool(clean.call(&"tend_by", spot, GROUP))
			if done and task == &"weed" and mistake:
				# Only a mistake where grave flowers grow (§2.5.2: „sonst kein Fehler").
				mistake = care != null and StringName(str(care.call(&"flowers_state", grave))) in [&"fresh", &"wilted"]
				if mistake and care.has_method(&"tear_flowers"):
					care.call(&"tear_flowers", grave)
			if done and task == &"rake" and mistake:
				var neighbour := _neighbour_leaves(spot)
				if neighbour != "":
					clean.call(&"set_level", neighbour, int(clean.call(&"level", neighbour)) + 1)
		&"water":
			done = care != null and bool(care.call(&"water", grave, true))
			if done and mistake and care.has_method(&"wilt_flowers"):
				care.call(&"wilt_flowers", grave)
		&"candle":
			var b := _box()
			if care != null and b != null:
				if mistake:
					b.storage.remove_item(&"grave_candle", 1)
				done = bool(care.call(&"light", grave, b.storage))
	if not done:
		return
	_jobs[task] = jobs(task) + 1
	GameState.add_stat(STAT_JOBS, 1)
	if mistake:
		_mistakes_today += 1
		_last_mistake_day = day
		GameState.add_stat(STAT_MISTAKES, 1)
		var data := _task_data(task)
		if data != null and data.mistake_text != "":
			_bubble(data.mistake_text)
	EventBus.apprentice_job_done.emit(task, spot, mistake)
	if level(task) == LEVEL_TAUGHT and jobs(task) >= _cfg().practice_jobs:
		_set_level(task, LEVEL_PRACTISED)
		var data := _task_data(task)
		EventBus.notification_requested.emit(TEXT_PRACTISED % (data.label if data != null else String(task)), &"info")


func _set_level(task: StringName, value: int) -> void:
	if level(task) == value:
		return
	_levels[task] = value
	if value == LEVEL_TAUGHT:
		_jobs[task] = 0
	EventBus.apprentice_level_changed.emit(task, value)


func _send_to_watch(target: Vector3) -> void:
	var from := position_now()
	var dir := Vector3(from.x - target.x, 0.0, from.z - target.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	var spot := target + dir.normalized() * WATCH_DISTANCE
	spot.y = target.y
	_watch_point = ScheduleBuilder.point_id(spot)
	refresh_npcs()


## While watching: when the gravekeeper is farther than WATCH_DISTANCE + FOLLOW_SLACK, he follows.
func _follow() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if player == null or _watch_point == "":
		return
	var at := ScheduleBuilder.point(null, _watch_point)
	if _flat(player.global_position, at) <= WATCH_DISTANCE + FOLLOW_SLACK:
		return
	var g := _npc()
	if g != null and g.is_walking():
		return
	_watch_minute = TimeManager.minute_of_day
	var target := player.global_position
	var from := at
	var dir := Vector3(from.x - target.x, 0.0, from.z - target.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	_watch_point = ScheduleBuilder.point_id(target + dir.normalized() * WATCH_DISTANCE)
	refresh_npcs()


func _neighbour_leaves(spot_id: String) -> String:
	if not is_inside_tree():
		return ""
	var origin: DirtSpot = null
	for node: Node in get_tree().get_nodes_in_group(DirtSpot.GROUP):
		if (node as DirtSpot).spot_id == spot_id:
			origin = node as DirtSpot
	if origin == null:
		return ""
	var best := ""
	var best_d := INF
	for node: Node in get_tree().get_nodes_in_group(DirtSpot.GROUP):
		var s := node as DirtSpot
		if s == null or s == origin or s.kind != CleanlinessManager.KIND_LEAVES:
			continue
		var d := _flat(s.global_position, origin.global_position)
		if d < best_d or (is_equal_approx(d, best_d) and s.spot_id < best):
			best_d = d
			best = s.spot_id
	return best


func _mourned_now(grave_id: String) -> bool:
	var visitors := _first(&"visitors")
	if visitors == null or not visitors.has_method(&"active_visits"):
		return false
	for v: Dictionary in visitors.call(&"active_visits"):
		if (v.get("graves", []) as Array).has(grave_id):
			return true
	return false


func _fest_today(day: int) -> bool:
	var fest := _first(&"festivals")
	if fest == null or not fest.has_method(&"fest_day"):
		return false
	for res: Resource in Database.festivals():
		if int(fest.call(&"fest_day", StringName(str(res.get(&"id"))))) == day:
			return true
	return day == TimeManager.day and fest.has_method(&"today") and StringName(str(fest.call(&"today"))) != &""


func _fills() -> int:
	var care := _first(&"grave_care")
	return int(care.call(&"can_fill", GraveCare.OWNER_APPRENTICE)) if care != null else 0


func _box_items() -> Dictionary:
	var out := {}
	var b := _box()
	if b == null or b.storage == null:
		return out
	for slot: Dictionary in b.storage.get_slots():
		if not slot.is_empty():
			out[StringName(slot.id)] = int(out.get(StringName(slot.id), 0)) + int(slot.amount)
	return out


func _task_of_kind(kind: StringName) -> StringName:
	match kind:
		&"leaves", &"rake":
			return &"rake"
		&"weeds", &"weed":
			return &"weed"
		&"water", &"flowers":
			return &"water"
		&"candle":
			return &"candle"
	return &""


func _task_data(task: StringName) -> ApprenticeTaskData:
	if tasks.has(task):
		return tasks[task] as ApprenticeTaskData
	return Database.apprentice_task(task) as ApprenticeTaskData


## A waypoint of the hut corner, else the entity of that layout id (standing 0.9 m in front of it), else "".
func _place(id: String) -> String:
	var world := _world()
	if ScheduleBuilder.has_point(world, id):
		return id
	if world != null and world.has_method(&"get_node_by_layout_id"):
		var node := world.call(&"get_node_by_layout_id", id) as Node3D
		if node != null and node.is_inside_tree():
			return ScheduleBuilder.point_id(node.to_global(Vector3(0, 0, 0.9)))
	return ""


static func _known(ids: PackedStringArray, world: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in ids:
		if ScheduleBuilder.has_point(world, id):
			out.append(id)
	return out


func _note_task(action_id: StringName) -> void:
	var orders := _first(&"orders")
	if orders != null and orders.has_method(&"note_task"):
		orders.call(&"note_task", action_id)


func _bubble(text: String) -> void:
	EventBus.chatter_line.emit(BUBBLE_ID, GROUP, text)


func _rel_add(npc_id: StringName, delta: int, reason: String) -> void:
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"add") and delta != 0:
		rel.call(&"add", npc_id, delta, reason)


func _gain(kind: StringName, fallback: int) -> int:
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"gain"):
		var g := int(rel.call(&"gain", kind))
		return g if g != 0 else fallback
	return fallback


func _box() -> ApprenticeBox:
	if box == null and is_inside_tree():
		box = get_tree().get_first_node_in_group(ApprenticeBox.GROUP) as ApprenticeBox
	return box


func _npc() -> Npc:
	if npc == null and is_inside_tree():
		npc = _find_npc(RegionRoot.GRAVEYARD)
	return npc if is_instance_valid(npc) else null


func _village_npc() -> Npc:
	if village_npc == null and is_inside_tree():
		village_npc = _find_npc(&"village")
	return village_npc if is_instance_valid(village_npc) else null


func _find_npc(region: StringName) -> Npc:
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var n := node as Npc
		if n != null and n.npc_id == _cfg().npc_id and n.region_id == region:
			return n
	return null


func _world() -> Node:
	var g := _npc()
	return g._world() if g != null else null


func _first(group: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group)


func _cfg() -> ApprenticeConfig:
	if config == null:
		config = Database.config(&"apprentice_config") as ApprenticeConfig
		if config == null:
			config = ApprenticeConfig.new()
	return config


static func _entry_in(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d := (raw as Dictionary).duplicate(true)
	for key: String in ["start", "walk_minutes", "work_start", "work_minutes", "end"]:
		if not (d.get(key) is int or d.get(key) is float):
			return {}
		d[key] = int(d[key])
	var path := PackedStringArray()
	if d.get("path") is Array or d.get("path") is PackedStringArray:
		for p: Variant in d.path:
			path.append(str(p))
	d["path"] = path
	d["task"] = StringName(str(d.get("task", "")))
	d["kind"] = StringName(str(d.get("kind", "")))
	d["spot_id"] = str(d.get("spot_id", ""))
	d["grave_id"] = str(d.get("grave_id", ""))
	d["mistake"] = d.get("mistake") is bool and bool(d.mistake)
	d["consumes"] = str(d.get("consumes", ""))
	return d


static func _names_out(values: Dictionary[StringName, int]) -> Dictionary:
	var out := {}
	for k: StringName in values:
		out[String(k)] = values[k]
	return out


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
