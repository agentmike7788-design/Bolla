class_name Visitors
extends Node
## Systems/Visitors (docs/PHASE8_DESIGN.md §2.1.4, §2.2, §3.1, §3.3, §3.4, §5.1), groups &"visitors",
## &"saveable", save_id visitors / 71: the daily visit plan (06:00, deterministic, saved), the visible visit
## (its phases from plan + clock; the runtime schedule of the kin Npc through ScheduleBuilder), the look at the
## grave (GraveView → Reputation, goodwill), wishes, tips (in the talk or on the stone – TipStone), noise at a
## mourner.
## - Plan (VisitRules): households (KinData without villager_id) visit the graves whose dead carry their house
##   (CorpseRecord.kin_house), all graves of the house in one round; villagers (Esch, Theres, Liesel) their
##   fixed graves every n days from p8_open_day + first_offset (flag visit_<npc>_day = the day, for their
##   graveyard Npc). ≤ 3 visits a day in the slots, ≤ 2 at once; nothing before p8_open, on the night of the
##   lights or at a DUG grave; the overflow comes tomorrow.
## - Clock: every minute the visits move through arriving → mourning (lay the bouquet → GraveCare.place_bouquet,
##   mourn, look → GraveView) → waiting (only with a tip or a wish to offer) → leaving → gone. A load stands
##   everyone where plan + clock put them; nothing is replayed (viewed / ended are saved).
## - Wishes (WishRules): offered in the talk with a visitor (goodwill ≥ 2, one per grave, 3 open), checked at
##   the next look: done → tip 1–3 (≤ 4 a day; villagers +4 relationship instead), reputation wish_done,
##   goodwill +2; not done → goodwill −2, no reputation. An offered wish not accepted lapses with the visit.
## - Tips: handed in the talk (hand_tip) or left on the stone when the visit ends (take_tip, TipStone).

const GROUP := &"visitors"
const PHASES: Array[StringName] = [&"arriving", &"mourning", &"waiting", &"leaving", &"gone"]
const WISH_STATES: Array[StringName] = [&"offered", &"accepted", &"done", &"failed"]
const PAYMENT_REASON := "Trinkgeld"
const COIN := &"coin"
const OPEN_FLAG := &"p8_open"
const OPEN_DAY_FLAG := &"p8_open_day"
## GameState flag (int day) of the night of the lights (FestivalData fest_lights.day_flag, P4).
const LIGHTS_DAY_FLAG := &"fest_lights_day"
## visit_<villager_id>_day = the visit day (the villager's graveyard Npc entries use it as today_flag).
const VISIT_FLAG_FORMAT := "visit_%s_day"
const PLAN_MINUTE := 360
const MINUTES_PER_DAY := 1440
const STAT_SEEN := &"visits_seen"
const STAT_TOTAL := &"visits_total"
const STAT_WISHES_DONE := &"wishes_done"
const STAT_WISHES_FAILED := &"wishes_failed"
const STAT_TIPS := &"tips_coins"
const EVENT_WISH_DONE := &"wish_done"
const EVENT_NOISE := &"visit_noise"
const EVENT_NOISE_LIFE := &"noise_at_grave"
const KIND_TIP := &"tip"
## §2.2.5: Esch lays 2 iron fittings once instead of coins.
const SMITH := &"smith"
const SMITH_GIFT := &"iron_fittings"
const SMITH_GIFT_COUNT := 2
const FLAG_SMITH_GIFT := &"smith_wish_fittings"
const D1_STORY := &"d1_hagedorn"
const S5_STORY := &"s5_moor"
const FLAG_NOT_LORENZ := &"insight_not_lorenz"
## The player counts as having seen a visit when ≤ SEEN_DISTANCE m from the grave at the look.
const SEEN_DISTANCE := 30.0
const NOISE_LINE := "Pst. Er hört das noch."
const REASON_VIEW := "Besuch am Grab von %s"
const REASON_WISH := "Wunsch erfüllt (%s)"
const REASON_NOISE := "Lärm am Grab"
const TEXT_FITTINGS := "Ulrich Esch hat zwei Eisenbeschläge an den Stein gelehnt."
## §2.13 leading lines after the look (P6 may override in the kin dialogues).
const VIEW_LINES: Dictionary[StringName, String] = {
	&"disturbed": "Wer war das? Wer war an ihm?",
	&"neglected": "Das Unkraut ist schneller als du, Totengräber.",
	&"bare": "Noch kein Name. Das kommt, sagt man.",
	&"kept": "Sauber. Das hätte ihm gefallen.",
	&"bonus": "Jemand hat ihm ein Licht hingestellt.",
	&"specimen": "Beim Quast, sagen sie, steht ein Glas. Mit seinem Namen.",
}

@export var save_id: String = "visitors"
@export var save_order: int = 71

## Rules; null = data/config/visitor_config.tres (resolved lazily).
var config: VisitorConfig
## Tests: the kin (empty = Database.kin_list()).
var kin_data: Array[KinData] = []
## Tests: the villagers' data (circle) by npc_id (empty = Database.villager / villagers()).
var villager_data: Dictionary[StringName, VillagerData] = {}

var _plan_day: int = -1
## The plan was made with Phase 8 open (an opening after 06:00 plans the rest of that day once more).
var _planned_open: bool = false
var _plan: Array[Dictionary] = []
var _goodwill: Dictionary[StringName, int] = {}
## grave → day of the last look; kin → day of a villager's last visit.
var _last_visit: Dictionary = {}
var _last_kin: Dictionary = {}
var _wishes: Array[Dictionary] = []
var _tips_day: int = -1
var _tips_coins: int = 0
var _stones: Dictionary = {}
var _pleased_day: int = -1
var _pleased: int = 0
var _noise_day: int = 0
var _rumor_seen: PackedStringArray = []
var _next_wish: int = 1
## visit_id → the phase last announced (not saved; a load announces nothing).
var _announced: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- plan ----------------------------------------------------------------------------------------

## 06:00, deterministic; [{visit_id, kin_id, graves, slot, …}] saved. Closes yesterday's visits first.
func plan_day(day: int) -> Array[Dictionary]:
	_finish_all()
	_plan.clear()
	_announced.clear()
	_plan_day = day
	_planned_open = _open() and day >= _open_day()
	var cfg := _cfg()
	if not _open() or day < _open_day() or _lights_day() == day:
		return _plan.duplicate(true)
	# Planned late (the opening after 06:00, a load without a plan): only visits still to come today.
	var late := TimeManager.day == day and TimeManager.minute_of_day > PLAN_MINUTE
	var now_minute := TimeManager.minute_of_day
	var villagers: Array[Dictionary] = []
	var windows: Array = []
	var households: Array = []
	for kin: KinData in _kin():
		var graves := graves_of(kin.kin_id)
		if graves.is_empty():
			continue
		if kin.villager_id != &"":
			var due := VisitRules.villager_due(int(_last_kin.get(String(kin.kin_id), -1)), _open_day(), kin.first_offset,
					kin.visit_every_days, _lights_day())
			if due > day:
				continue
			var travel := _travel(kin, graves)
			var start := kin.visit_minute - travel
			var e := _entry(kin, graves, start, travel, day)
			villagers.append(e)
			windows.append([start, start + VisitRules.duration(travel, graves.size(), bool(e.flowers), true, cfg)])
		else:
			var dues: Array = []
			for g: String in graves:
				dues.append(_grave_due(g))
			var due := VisitRules.household_due(dues)
			if due >= 0 and due <= day:
				households.append([due, String(kin.kin_id), kin, graves])
	households.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	villagers.resize(mini(villagers.size(), cfg.max_visits_day))
	var length := VisitRules.duration(VisitRules.ROAD_MINUTES + VisitRules.DEFAULT_ROUTE_MINUTES, 1, true, true, cfg)
	var slots := VisitRules.assign_slots(households.size(), windows.slice(0, villagers.size()), length, cfg)
	var list: Array[Dictionary] = villagers.duplicate()
	for i: int in households.size():
		if slots[i] < 0 or (late and slots[i] < now_minute):
			continue
		var kin: KinData = households[i][2]
		var graves: PackedStringArray = households[i][3]
		list.append(_entry(kin, graves, slots[i], _travel(kin, graves), day))
	if late:
		var keep: Array[Dictionary] = []
		for e: Dictionary in list:
			if int(e.start) >= now_minute:
				keep.append(e)
		list = keep
	list.sort_custom(_by_start)
	for i: int in list.size():
		var e := list[i]
		e["visit_id"] = "v_%d_%d" % [day, i + 1]
		_plan.append(e)
		var kin := _kin_data(StringName(str(e.kin_id)))
		if kin != null and kin.villager_id != &"":
			GameState.set_flag(StringName(VISIT_FLAG_FORMAT % kin.villager_id), day)
	return _plan.duplicate(true)


## The visit of `kin_id` today ({} = none).
func visit_of(kin_id: StringName) -> Dictionary:
	for v: Dictionary in _plan:
		if StringName(str(v.get("kin_id", ""))) == kin_id:
			return _public(v)
	return {}


## Visits on the graveyard now (arriving … leaving), each with its "phase" and "grave_id".
func active_visits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Dictionary in _plan:
		var phase := phase_of(v)
		if phase != &"" and phase != &"gone":
			out.append(_public(v))
	return out


## The phase of a plan entry now (&"" = not yet; W0 / fixture key "phase" wins).
func phase_of(v: Dictionary) -> StringName:
	var fixed := StringName(str(v.get("phase", "")))
	if fixed != &"":
		return fixed
	var seg := VisitRules.segment_at(_segments(v), _now_rel(v))
	return StringName(seg.get("phase", &""))


## {phase, step, grave_id} of the visit `visit_id` now ({} = unknown) – the Npc animation, the map, the UI.
func visit_state(visit_id: String) -> Dictionary:
	var v := _find(visit_id)
	if v.is_empty():
		return {}
	var seg := {} if v.has("phase") else VisitRules.segment_at(_segments(v), _now_rel(v))
	var graves: Array = v.get("graves", [])
	var index := clampi(int(seg.get("grave_index", 0)), 0, maxi(graves.size() - 1, 0))
	return {"phase": phase_of(v), "step": seg.get("step", &""), "grave_id": str(graves[index]) if not graves.is_empty() else ""}


## A waiting visitor (or {}), for the dialogue condition visit_waiting and the objective line.
func waiting_visit() -> Dictionary:
	for v: Dictionary in _plan:
		if phase_of(v) == &"waiting":
			return _public(v)
	return {}


## Someone of `kin` looked at `grave_id` on day `day` (ghost line by_visited).
func visited_on(grave_id: String, day: int) -> bool:
	return int(_last_visit.get(grave_id, -1)) == day


## A visitor mourns at `grave_id` now (the apprentice leaves it alone, §2.2.3).
func mourning_at(grave_id: String) -> bool:
	for v: Dictionary in _plan:
		var phase := phase_of(v)
		if phase == &"mourning" or phase == &"waiting":
			var st := visit_state(str(v.get("visit_id", "")))
			if str(st.get("grave_id", "")) == grave_id or (v.has("phase") and Array(v.get("graves", [])).has(grave_id)):
				return true
	return false


# --- goodwill & kin ------------------------------------------------------------------------------

## 0…10 (start VisitorConfig.goodwill_start).
func goodwill(kin_id: StringName) -> int:
	return int(_goodwill.get(kin_id, _cfg().goodwill_start))


func add_goodwill(kin_id: StringName, delta: int) -> void:
	if kin_id == &"":
		return
	_goodwill[kin_id] = clampi(goodwill(kin_id) + delta, 0, 10)


## The kin of the dead in `grave_id` (CorpseRecord.kin_house → KinData; fixed graves) or &"".
func kin_for_grave(grave_id: String) -> StringName:
	for kin: KinData in _kin():
		if kin.villager_id != &"" and graves_of(kin.kin_id).has(grave_id):
			return kin.kin_id
	var corpse := _corpse_of(grave_id)
	if corpse == null:
		return &""
	var house := _house_of(corpse)
	if house == &"":
		return &""
	for kin: KinData in _kin():
		if kin.villager_id == &"" and kin.house == house:
			return kin.kin_id
	return &""


## The graves `kin_id` visits: a household the occupied graves of its house, a villager the fixed graves (+
## Liesel: the graves of her circle, D1 and – with insight_not_lorenz – S5).
func graves_of(kin_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	var kin := _kin_data(kin_id)
	var graveyard := _graveyard()
	if kin == null or graveyard == null:
		return out
	var houses: Array[StringName] = []
	if kin.villager_id == &"":
		houses.append(kin.house)
	else:
		for g: String in kin.fixed_graves:
			var grave := graveyard.get_grave(g)
			if grave != null and grave.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED, GraveRecord.State.OLD]:
				out.append(g)
		if kin.fixed_graves.is_empty():
			if kin.house != &"":
				houses.append(kin.house)
			var v := _villager(kin.villager_id)
			if v != null:
				for h: StringName in v.circle:
					if not houses.has(h):
						houses.append(h)
	if houses.is_empty():
		return out
	for grave: GraveRecord in graveyard.graves():
		if grave.state != GraveRecord.State.FILLED and grave.state != GraveRecord.State.MARKED:
			continue
		var corpse := _corpse(grave.corpse_id)
		if corpse == null:
			continue
		if corpse.story_id == S5_STORY and not GameState.flag_on(FLAG_NOT_LORENZ):
			continue
		var house := _house_of(corpse)
		if corpse.story_id == S5_STORY and kin.villager_id != &"" and kin.fixed_graves.is_empty():
			house = kin.house
		if houses.has(house) and not out.has(grave.id):
			out.append(grave.id)
	return out


# --- wishes --------------------------------------------------------------------------------------

## {} | {wish_id, kind, grave_id, text} – the wish of a visitor in the talk (goodwill ≥ 2, one open wish per
## grave, max_open open in all). The same visit offers the same wish again.
func offer_wish(visit_id: String) -> Dictionary:
	var v := _find(visit_id)
	if v.is_empty():
		return {}
	var offered := str(v.get("offered", ""))
	if offered != "":
		var w := _wish(offered)
		if not w.is_empty() and str(w.state) == "offered":
			return _wish_card(w)
		if not w.is_empty():
			return {}
	var kin_id := StringName(str(v.get("kin_id", "")))
	var choice := _wish_choice(v)
	if choice.is_empty():
		return {}
	var id := "w_%04d" % _next_wish
	_next_wish += 1
	var data := Database.wish(choice.template) as WishData
	var w := {"wish_id": id, "kind": String(data.kind) if data != null else "", "grave_id": choice.grave_id,
			"kin_id": String(kin_id), "state": "offered", "day": TimeManager.day, "candle_seen": false,
			"template": String(choice.template)}
	if data != null and data.kind == WishRules.KIND_LINE:
		w["line"] = data.line_text
	_wishes.append(w)
	v["offered"] = id
	EventBus.wish_changed.emit(id, &"offered")
	return _wish_card(w)


## A wish could be offered in the talk with the visit `visit_id` (dialogue condition wish_offerable).
func wish_offerable(visit_id: String) -> bool:
	var v := _find(visit_id)
	if v.is_empty():
		return false
	var offered := str(v.get("offered", ""))
	if offered != "":
		return str(_wish(offered).get("state", "")) == "offered"
	return not _wish_choice(v).is_empty()


## „Das mache ich." – offered → accepted.
func accept_wish(wish_id: String) -> bool:
	var w := _wish(wish_id)
	if w.is_empty() or str(w.state) != "offered":
		return false
	w["state"] = "accepted"
	EventBus.wish_changed.emit(wish_id, &"accepted")
	return true


## Offered or accepted wishes [{wish_id, kind, grave_id, kin_id, state, day, candle_seen}].
func open_wishes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in _wishes:
		if str(w.get("state", "")) in ["offered", "accepted"]:
			out.append(w.duplicate(true))
	return out


## Wishes done (the chapter goal §1.5: count and different kin).
func done_wishes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in _wishes:
		if str(w.get("state", "")) == "done":
			out.append(w.duplicate(true))
	return out


## Number of different kin with a wish done.
func done_kin_count() -> int:
	var seen := {}
	for w: Dictionary in done_wishes():
		seen[str(w.get("kin_id", ""))] = true
	return seen.size()


# --- tips ----------------------------------------------------------------------------------------

## In the talk; otherwise TipStone. Returns the coins.
func hand_tip(visit_id: String, inv: Inventory) -> int:
	var v := _find(visit_id)
	if v.is_empty() or inv == null:
		return 0
	var coins := int(v.get("tip", 0))
	if coins <= 0 or not inv.can_add(COIN, coins):
		return 0
	v["tip"] = 0
	_pay(coins, inv)
	return coins


## The coins a visitor will hand over (0 = none) – the dialogue's tip_hand line.
func tip_of(visit_id: String) -> int:
	return int(_find(visit_id).get("tip", 0))


## (coins, kin index) or (0, -1). The index is the position of the kin id in Database.kin_list() (−1 =
## unknown kin).
func tip_on_stone(grave_id: String) -> Vector2i:
	var t: Variant = _stones.get(grave_id)
	if not t is Array or (t as Array).size() < 2 or int((t as Array)[0]) <= 0:
		return Vector2i(0, -1)
	var kin_id := str((t as Array)[1])
	var index := -1
	var list := Database.kin_list()
	for i: int in list.size():
		if String(list[i].get(&"kin_id")) == kin_id:
			index = i
	return Vector2i(int((t as Array)[0]), index)


## The name of who left the coins on `grave_id` ("" = nothing there) – TipStone's prompt.
func tip_giver(grave_id: String) -> String:
	var t: Variant = _stones.get(grave_id)
	if not t is Array or (t as Array).size() < 2:
		return ""
	var kin := _kin_data(StringName(str((t as Array)[1])))
	return kin.display_name if kin != null else ""


## Graves with coins on the stone (the map, the tooltip).
func stones() -> PackedStringArray:
	var out := PackedStringArray()
	for g: Variant in _stones:
		if tip_on_stone(String(g)).x > 0:
			out.append(String(g))
	return out


## Takes the coins on the stone (once). Returns the coins.
func take_tip(grave_id: String, inv: Inventory) -> int:
	var coins := tip_on_stone(grave_id).x
	if coins <= 0 or inv == null or not inv.can_add(COIN, coins):
		return 0
	_stones.erase(grave_id)
	_pay(coins, inv)
	EventBus.grave_care_changed.emit(grave_id, KIND_TIP, false)
	return coins


# --- noise & phases ------------------------------------------------------------------------------

## Player TimedAction with the keyword noisy (ActionConfig.noisy_actions) at `pos`: once per visit a bubble,
## reputation visit_noise −1 at most once a day.
func note_noise(pos: Vector3, action_id: StringName) -> void:
	if not _is_noisy(action_id):
		return
	var cfg := _cfg()
	for v: Dictionary in _plan:
		if phase_of(v) != &"mourning" or bool(v.get("noise", false)):
			continue
		var st := visit_state(str(v.visit_id))
		var plot := GraveView.plot_of(str(st.get("grave_id", "")), get_tree() if is_inside_tree() else null)
		if plot == null:
			continue
		var p := plot.global_position
		if Vector2(p.x - pos.x, p.z - pos.z).length() > cfg.noise_distance:
			continue
		v["noise"] = true
		_say(v, NOISE_LINE)
		var life := _first(&"npc_life")
		if life != null and life.has_method(&"note_event"):
			life.call(&"note_event", EVENT_NOISE_LIFE, [] as Array[StringName])
		if _noise_day != TimeManager.day:
			_noise_day = TimeManager.day
			_rep_event(EVENT_NOISE, REASON_NOISE, true)


## From the Npc plan (the look, the end): &"waiting" / &"leaving" take the pending looks, &"gone" ends the
## visit as well (idempotent – the clock does the same).
func on_visit_phase(visit_id: String, phase: StringName) -> void:
	var v := _find(visit_id)
	if v.is_empty():
		return
	if phase == &"waiting" or phase == &"leaving" or phase == &"gone":
		var graves: Array = v.get("graves", [])
		while int(v.get("viewed", 0)) < graves.size():
			_look(v, int(v.get("viewed", 0)))
	if phase == &"gone":
		_end(v)


## The current minute (helper; time_tick calls it).
func apply_minute(day: int, minute: int) -> void:
	if minute >= PLAN_MINUTE and (_plan_day != day or (not _planned_open and _open() and _plan.is_empty())):
		plan_day(day)
	for v: Dictionary in _plan:
		_advance(v)


# --- save ----------------------------------------------------------------------------------------

## {plan_day, plan, goodwill, last_visit, last_kin, wishes, tips_today, tips_on_stone, pleased_today,
## pleased_day, noise_day, rumor_seen, next_wish} (§5.1).
func save_state() -> Dictionary:
	var gw := {}
	for k: StringName in _goodwill:
		gw[String(k)] = _goodwill[k]
	var rumor: Array = []
	for id: String in _rumor_seen:
		rumor.append(id)
	return {"plan_day": _plan_day, "plan": _plan.duplicate(true), "goodwill": gw, "last_visit": _last_visit.duplicate(),
			"last_kin": _last_kin.duplicate(), "wishes": _wishes.duplicate(true), "tips_today": {"day": _tips_day, "coins": _tips_coins},
			"tips_on_stone": _stones.duplicate(true), "pleased_today": _pleased, "pleased_day": _pleased_day,
			"noise_day": _noise_day, "rumor_seen": rumor, "next_wish": _next_wish, "plan_open": _planned_open}


## Tolerant: damaged entries are dropped; a plan of another day stays until the next 06:00 replans.
func load_state(data: Dictionary) -> void:
	_plan_day = _int(data.get("plan_day"), -1)
	_planned_open = typeof(data.get("plan_open")) != TYPE_BOOL or bool(data.get("plan_open"))
	_plan.clear()
	var plan: Variant = data.get("plan", [])
	if plan is Array:
		for v: Variant in plan:
			if v is Dictionary and (v as Dictionary).has("kin_id") and (v as Dictionary).get("graves") is Array:
				var e: Dictionary = (v as Dictionary).duplicate(true)
				for key: String in ["slot", "start", "travel", "viewed", "laid", "tip", "day"]:
					if e.has(key):
						e[key] = _int(e[key], 0)
				_plan.append(e)
	_goodwill.clear()
	var gw: Variant = data.get("goodwill", {})
	if gw is Dictionary:
		for key: Variant in gw:
			_goodwill[StringName(str(key))] = clampi(_int((gw as Dictionary)[key], _cfg().goodwill_start), 0, 10)
	_last_visit = _int_map(data.get("last_visit", {}))
	_last_kin = _int_map(data.get("last_kin", {}))
	_wishes.clear()
	var wishes: Variant = data.get("wishes", [])
	var per_grave := {}
	if wishes is Array:
		for w: Variant in wishes:
			if not w is Dictionary or not (w as Dictionary).has("wish_id"):
				continue
			var e: Dictionary = (w as Dictionary).duplicate(true)
			e["day"] = _int(e.get("day"), 0)
			var open := str(e.get("state", "")) in ["offered", "accepted"]
			var g := str(e.get("grave_id", ""))
			if open and per_grave.has(g):
				continue
			if open:
				per_grave[g] = true
			_wishes.append(e)
	var tips: Variant = data.get("tips_today", {})
	_tips_day = _int((tips as Dictionary).get("day"), -1) if tips is Dictionary else -1
	_tips_coins = maxi(_int((tips as Dictionary).get("coins"), 0), 0) if tips is Dictionary else 0
	var stones: Variant = data.get("tips_on_stone", {})
	_stones = {}
	if stones is Dictionary:
		for g: Variant in stones:
			var t: Variant = (stones as Dictionary)[g]
			if t is Array and (t as Array).size() >= 2 and _int((t as Array)[0], 0) > 0:
				_stones[str(g)] = [_int((t as Array)[0], 0), str((t as Array)[1])]
	_pleased = maxi(_int(data.get("pleased_today"), 0), 0)
	_pleased_day = _int(data.get("pleased_day"), -1)
	_noise_day = _int(data.get("noise_day"), 0)
	_rumor_seen = PackedStringArray()
	var rumor: Variant = data.get("rumor_seen", [])
	if rumor is Array or rumor is PackedStringArray:
		for id: Variant in rumor:
			_rumor_seen.append(str(id))
	_next_wish = maxi(_int(data.get("next_wish"), 1), 1)
	for w: Dictionary in _wishes:
		var n := str(w.wish_id).trim_prefix("w_")
		if n.is_valid_int():
			_next_wish = maxi(_next_wish, n.to_int() + 1)
	_announced.clear()
	for v: Dictionary in _plan:
		_announced[str(v.get("visit_id", ""))] = phase_of(v)


# --- internals: the visit ------------------------------------------------------------------------

func _entry(kin: KinData, graves: PackedStringArray, start: int, travel: int, day: int) -> Dictionary:
	var first := false
	var mourning := false
	for g: String in graves:
		if not _last_visit.has(g):
			first = true
		var corpse := _corpse_of(g)
		if corpse != null and corpse.buried_day > 0 and day - corpse.buried_day < _cfg().mourning_days:
			mourning = true
	var flowers := VisitRules.brings_flowers(first, mourning, kin.bouquet_model != &"", kin.kin_id, day, _cfg())
	return {"visit_id": "", "kin_id": String(kin.kin_id), "graves": Array(graves), "slot": start + (travel if kin.villager_id != &"" else 0),
			"start": start, "travel": travel, "day": day, "flowers": flowers, "laid": 0, "viewed": 0, "waits": false, "tip": 0,
			"ended": false, "noise": false, "offered": ""}


static func _by_start(a: Dictionary, b: Dictionary) -> bool:
	if int(a.start) != int(b.start):
		return int(a.start) < int(b.start)
	return str(a.kin_id) < str(b.kin_id)


func _segments(v: Dictionary) -> Array[Dictionary]:
	var travel := int(v.get("travel", VisitRules.ROAD_MINUTES + VisitRules.DEFAULT_ROUTE_MINUTES))
	var start := int(v.get("start", int(v.get("slot", 570))))
	return VisitRules.timeline(start, travel, (v.get("graves", []) as Array).size(), bool(v.get("flowers", false)),
			bool(v.get("waits", false)), _cfg())


## Minutes of the day relative to the plan day (a visit of yesterday reads as long over).
func _now_rel(v: Dictionary) -> int:
	var day := int(v.get("day", _plan_day))
	return TimeManager.total_minutes() - (day - 1) * MINUTES_PER_DAY


func _advance(v: Dictionary) -> void:
	if v.has("phase") or bool(v.get("ended", false)):
		return
	var now := _now_rel(v)
	var segs := _segments(v)
	var graves: Array = v.get("graves", [])
	if bool(v.get("flowers", false)):
		while int(v.get("laid", 0)) < graves.size():
			var i := int(v.get("laid", 0))
			var lay_end := -1
			for s: Dictionary in segs:
				if s.step == VisitRules.STEP_LAY and int(s.grave_index) == i:
					lay_end = int(s.to)
			if lay_end < 0 or now < lay_end:
				break
			v["laid"] = i + 1
			var care := _first(&"grave_care") as GraveCare
			if care != null:
				care.place_bouquet(str(graves[i]))
	while int(v.get("viewed", 0)) < graves.size():
		var i := int(v.get("viewed", 0))
		if now < VisitRules.look_end(segs, i):
			break
		_look(v, i)
		segs = _segments(v)
	_announce(v)
	if now >= VisitRules.end_minute(_segments(v)):
		_end(v)


func _announce(v: Dictionary) -> void:
	var id := str(v.get("visit_id", ""))
	var phase := phase_of(v)
	if phase == &"" or _announced.get(id, &"") == phase:
		return
	_announced[id] = phase
	var st := visit_state(id)
	if phase == &"arriving":
		_apply_schedule(v)
	EventBus.visitor_changed.emit(id, StringName(str(v.kin_id)), str(st.get("grave_id", "")), phase)


## The look at grave `index` of the visit (GraveView): reputation, goodwill, wishes due, the bubble.
func _look(v: Dictionary, index: int) -> void:
	var graves: Array = v.get("graves", [])
	if index >= graves.size():
		return
	v["viewed"] = index + 1
	var grave_id := str(graves[index])
	var kin_id := StringName(str(v.kin_id))
	var cfg := _cfg()
	var tree := get_tree() if is_inside_tree() else null
	var seen := GraveView.view(grave_id, tree, cfg)
	var view := StringName(seen.view)
	var dead := _dead_name(grave_id)
	var effect: Dictionary = cfg.view_effects.get(view, {})
	var rep_event := StringName(str(effect.get("rep_event", "")))
	if rep_event == &"visit_pleased":
		if _pleased_day != TimeManager.day:
			_pleased_day = TimeManager.day
			_pleased = 0
		if _pleased < cfg.pleased_cap_day:
			_pleased += 1
			_rep_event(rep_event, REASON_VIEW % dead, false)
	elif rep_event != &"":
		_rep_event(rep_event, REASON_VIEW % dead, true)
	add_goodwill(kin_id, int(effect.get("goodwill", 0)))
	var line: String = VIEW_LINES.get(view, "")
	if bool(seen.bonus):
		add_goodwill(kin_id, int((cfg.view_effects.get(&"bonus", {}) as Dictionary).get("goodwill", 0)))
		if view == &"kept":
			line = VIEW_LINES[&"bonus"]
	var rumor := str(seen.specimen_rumor)
	if rumor != "" and not _rumor_seen.has(rumor):
		_rumor_seen.append(rumor)
		var spec: Dictionary = cfg.view_effects.get(&"specimen", {})
		_rep_event(StringName(str(spec.get("rep_event", ""))), REASON_VIEW % dead, true)
		add_goodwill(kin_id, int(spec.get("goodwill", 0)))
		line = VIEW_LINES[&"specimen"]
	_last_visit[grave_id] = TimeManager.day
	_check_wishes(v, grave_id)
	if _player_near(grave_id):
		GameState.add_stat(STAT_SEEN, 1)
	_say(v, line)
	EventBus.grave_viewed.emit(grave_id, kin_id, view)
	if index == graves.size() - 1:
		v["waits"] = int(v.get("tip", 0)) > 0 or not _wish_choice(v).is_empty()
		var kin := _kin_data(kin_id)
		if kin != null and kin.villager_id != &"":
			_last_kin[String(kin_id)] = TimeManager.day


## The accepted wishes of this kin at `grave_id` from an earlier day: done or failed now.
func _check_wishes(v: Dictionary, grave_id: String) -> void:
	var kin_id := str(v.kin_id)
	var tree := get_tree() if is_inside_tree() else null
	for w: Dictionary in _wishes:
		if str(w.get("grave_id", "")) != grave_id or str(w.get("kin_id", "")) != kin_id:
			continue
		if str(w.get("state", "")) != "accepted" or int(w.get("day", 0)) >= TimeManager.day:
			continue
		if WishRules.fulfilled(w, tree):
			_wish_done(v, w)
		else:
			_wish_failed(w)


func _wish_done(v: Dictionary, w: Dictionary) -> void:
	var cfg := _cfg()
	var kin_id := StringName(str(w.kin_id))
	var kin := _kin_data(kin_id)
	w["state"] = "done"
	w["done_day"] = TimeManager.day
	GameState.add_stat(STAT_WISHES_DONE, 1)
	if kin != null and kin.villager_id != &"":
		var rel := _first(&"relationships")
		if rel != null and rel.has_method(&"add"):
			rel.call(&"add", kin.villager_id, cfg.villager_wish_rel, REASON_WISH % kin.display_name)
		if kin.villager_id == SMITH and not GameState.flag_on(FLAG_SMITH_GIFT):
			var inv := _player_inventory()
			if inv != null and inv.can_add(SMITH_GIFT, SMITH_GIFT_COUNT):
				inv.add_item(SMITH_GIFT, SMITH_GIFT_COUNT)
				GameState.set_flag(FLAG_SMITH_GIFT, true)
				EventBus.notification_requested.emit(TEXT_FITTINGS, &"info")
	else:
		if _tips_day != TimeManager.day:
			_tips_day = TimeManager.day
			_tips_coins = 0
		var coins := WishRules.tip(goodwill(kin_id), _quality(str(w.grave_id)), _tips_coins, cfg)
		if coins > 0:
			_tips_coins += coins
			v["tip"] = int(v.get("tip", 0)) + coins
			v["tip_grave"] = str(w.grave_id)
	_rep_event(EVENT_WISH_DONE, REASON_WISH % (kin.display_name if kin != null else String(kin_id)), false)
	add_goodwill(kin_id, cfg.wish_goodwill)
	var life := _first(&"npc_life")
	if life != null and life.has_method(&"note_event"):
		life.call(&"note_event", EVENT_WISH_DONE, _circle_of(kin))
	var data := Database.wish(StringName(str(w.get("template", "")))) as WishData
	if data != null:
		_say(v, data.done_text)
	EventBus.wish_changed.emit(str(w.wish_id), &"done")
	if life != null and life.has_method(&"check_goal"):
		life.call(&"check_goal")


func _wish_failed(w: Dictionary) -> void:
	w["state"] = "failed"
	GameState.add_stat(STAT_WISHES_FAILED, 1)
	add_goodwill(StringName(str(w.kin_id)), _cfg().wish_fail_goodwill)
	EventBus.wish_changed.emit(str(w.wish_id), &"failed")


## The end of a visit: a tip not handed lies on the stone; an offered wish not accepted lapses.
func _end(v: Dictionary) -> void:
	if bool(v.get("ended", false)):
		return
	var graves: Array = v.get("graves", [])
	while int(v.get("viewed", 0)) < graves.size():
		_look(v, int(v.get("viewed", 0)))
	v["ended"] = true
	GameState.add_stat(STAT_TOTAL, 1)
	var coins := int(v.get("tip", 0))
	if coins > 0:
		var g := str(v.get("tip_grave", graves.back() if not graves.is_empty() else ""))
		var before := tip_on_stone(g).x
		_stones[g] = [before + coins, str(v.kin_id)]
		v["tip"] = 0
		EventBus.grave_care_changed.emit(g, KIND_TIP, true)
	var offered := str(v.get("offered", ""))
	if offered != "":
		for i: int in range(_wishes.size() - 1, -1, -1):
			if str(_wishes[i].wish_id) == offered and str(_wishes[i].state) == "offered":
				_wishes.remove_at(i)
	_clear_schedule(v)
	if _announced.get(str(v.get("visit_id", "")), &"") != &"gone":
		_announced[str(v.get("visit_id", ""))] = &"gone"
		EventBus.visitor_changed.emit(str(v.visit_id), StringName(str(v.kin_id)), str(graves.back()) if not graves.is_empty() else "", &"gone")


## Closes every visit of the current plan (a new plan, a time skip over the night).
func _finish_all() -> void:
	for v: Dictionary in _plan:
		if not v.has("phase") and not bool(v.get("ended", false)) and int(v.get("viewed", 0)) > 0:
			_end(v)
		elif not v.has("phase") and not bool(v.get("ended", false)) and _now_rel(v) >= int(v.get("start", 0)):
			_end(v)


## {grave_id, template} of the wish this visit could offer ({} = none).
func _wish_choice(v: Dictionary) -> Dictionary:
	var cfg := _cfg()
	var kin_id := StringName(str(v.get("kin_id", "")))
	if goodwill(kin_id) < cfg.goodwill_wish_min or open_wishes().size() >= cfg.max_open:
		return {}
	var tree := get_tree() if is_inside_tree() else null
	for g: Variant in v.get("graves", []):
		var grave_id := str(g)
		if _has_open_wish(grave_id):
			continue
		var template := WishRules.choose(grave_id, kin_id, TimeManager.day, tree)
		if template != &"":
			return {"grave_id": grave_id, "template": template}
	return {}


func _has_open_wish(grave_id: String) -> bool:
	for w: Dictionary in _wishes:
		if str(w.get("grave_id", "")) == grave_id and str(w.get("state", "")) in ["offered", "accepted"]:
			return true
	return false


func _wish(wish_id: String) -> Dictionary:
	for w: Dictionary in _wishes:
		if str(w.get("wish_id", "")) == wish_id:
			return w
	return {}


func _wish_card(w: Dictionary) -> Dictionary:
	var data := Database.wish(StringName(str(w.get("template", "")))) as WishData
	return {"wish_id": str(w.wish_id), "kind": StringName(str(w.kind)), "grave_id": str(w.grave_id),
			"text": data.ask_text if data != null else ""}


func _find(visit_id: String) -> Dictionary:
	for v: Dictionary in _plan:
		if str(v.get("visit_id", "")) == visit_id:
			return v
	return {}


## A copy of the entry with "phase" and the current "grave_id".
func _public(v: Dictionary) -> Dictionary:
	var out := v.duplicate(true)
	var st := visit_state(str(v.get("visit_id", "")))
	out["phase"] = phase_of(v)
	out["grave_id"] = st.get("grave_id", "")
	return out


func _pay(coins: int, inv: Inventory) -> void:
	inv.add_item(COIN, coins)
	GameState.add_stat(STAT_TIPS, coins)
	EventBus.payment_received.emit(coins, PAYMENT_REASON)


func _say(v: Dictionary, line: String) -> void:
	if line == "":
		return
	var kin := _kin_data(StringName(str(v.get("kin_id", ""))))
	if kin == null:
		return
	EventBus.villager_remarked.emit(kin.villager_id if kin.villager_id != &"" else kin.kin_id, line)


## Reputation event; `minus` = an event the Rosine favour may cancel (Friendship.consume_shield).
func _rep_event(kind: StringName, reason: String, minus: bool) -> void:
	if kind == &"":
		return
	if minus:
		var friendship := _first(&"friendship")
		if friendship != null and friendship.has_method(&"consume_shield") and bool(friendship.call(&"consume_shield", kind)):
			return
	var rep := _first(&"reputation")
	if rep != null and rep.has_method(&"event"):
		rep.call(&"event", kind, reason)


## The kin Npc on the graveyard walks its visit (ScheduleBuilder → Npc.set_runtime_schedule; households only –
## the villagers' graveyard Npc use their data entries with visit_<npc>_day).
func _apply_schedule(v: Dictionary) -> void:
	var kin := _kin_data(StringName(str(v.get("kin_id", ""))))
	if kin == null or kin.villager_id != &"":
		return
	var npc := _npc_node(kin)
	if npc == null or not npc.has_method(&"set_runtime_schedule"):
		return
	var entries: Array[ScheduleEntry] = []
	for s: Dictionary in _segments(v):
		var graves: Array = v.get("graves", [])
		var g := str(graves[clampi(int(s.grave_index), 0, maxi(graves.size() - 1, 0))]) if not graves.is_empty() else ""
		var wp := StringName("gv_" + g)
		var anim: StringName = &"idle"
		match StringName(s.step):
			VisitRules.STEP_LAY:
				anim = &"lay_flowers"
			VisitRules.STEP_MOURN:
				anim = &"kneel" if kin.kneels else &"mourn_stand"
			VisitRules.STEP_LOOK:
				anim = &"idle_low"
		if s.phase == VisitRules.PHASE_GONE:
			continue
		if StringName(s.step) == VisitRules.STEP_WALK and s.phase == VisitRules.PHASE_ARRIVING:
			entries.append(ScheduleBuilder.walk(&"road_end", _route(g), int(s.from), &"", _first(&"world")))
		elif StringName(s.step) == VisitRules.STEP_WALK and s.phase == VisitRules.PHASE_LEAVING:
			var back := _route(g)
			back.reverse()
			entries.append(ScheduleBuilder.walk(wp, back, int(s.from), &"", _first(&"world")))
		else:
			entries.append(ScheduleBuilder.stay(wp, int(s.from), anim, kin.dialogue_id))
	# W-Welt (W2): the walks are timed on the world's waypoints (with `self` they took 0 minutes – a jump), and the
	# figure carries the name for its talk prompt.
	var sched := ScheduleBuilder.build(entries)
	sched.display_name = kin.display_name
	npc.call(&"set_runtime_schedule", sched)


func _clear_schedule(v: Dictionary) -> void:
	var kin := _kin_data(StringName(str(v.get("kin_id", ""))))
	var npc := _npc_node(kin) if kin != null else null
	if npc != null and npc.has_method(&"clear_runtime_schedule"):
		npc.call(&"clear_runtime_schedule")


## The baked visitor route to the plot (W-Welt: the world's visitor_route(plot)), else the gate route.
func _route(grave_id: String) -> PackedStringArray:
	var world := _first(&"world")
	if world != null and world.has_method(&"visitor_route"):
		var r: Variant = world.call(&"visitor_route", grave_id)
		if r is PackedStringArray and not (r as PackedStringArray).is_empty():
			return r
	return PackedStringArray(["road_end", "road_mid", "gate_outside", "gate_inside", "gv_" + grave_id])


## Walking minutes up to the first grave: ScheduleBuilder's polyline time when it knows the route, else the
## contract default (8 + 5).
func _travel(kin: KinData, graves: PackedStringArray) -> int:
	var fallback := VisitRules.ROAD_MINUTES + VisitRules.DEFAULT_ROUTE_MINUTES
	if graves.is_empty() or not is_inside_tree() or _npc_node(kin) == null:
		return fallback
	var entry := ScheduleBuilder.walk(&"road_end", _route(graves[0]), 0, &"", _first(&"world"))
	return entry.travel_minutes if entry != null and entry.travel_minutes > 0 else fallback


func _npc_node(kin: KinData) -> Node:
	if kin == null or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"npc"):
		if String(node.name) == String(kin.npc_path_id):
			return node
	return null


# --- internals: lookups --------------------------------------------------------------------------

func _on_time_tick(day: int, minute: int) -> void:
	apply_minute(day, minute)


func _grave_due(grave_id: String) -> int:
	var corpse := _corpse_of(grave_id)
	var buried := corpse.buried_day if corpse != null and corpse.buried_day > 0 else 0
	if buried <= 0:
		var grave := _graveyard().get_grave(grave_id)
		buried = grave.completed_day if grave != null else 0
	return VisitRules.next_due(grave_id, buried, int(_last_visit.get(grave_id, -1)), _open_day(), _cfg())


func _house_of(corpse: CorpseRecord) -> StringName:
	if corpse.kin_house != &"":
		return corpse.kin_house
	return CorpseManager.STORY_KIN.get(corpse.story_id, &"")


func _circle_of(kin: KinData) -> Array[StringName]:
	var out: Array[StringName] = []
	if kin == null:
		return out
	var list: Array = villager_data.values() if not villager_data.is_empty() else Database.villagers()
	for v: Variant in list:
		var vd := v as VillagerData
		if vd != null and (vd.circle.has(kin.house) or vd.npc_id == kin.villager_id):
			out.append(vd.npc_id)
	return out


func _villager(npc_id: StringName) -> VillagerData:
	if not villager_data.is_empty():
		return villager_data.get(npc_id)
	return Database.villager(npc_id) as VillagerData


func _dead_name(grave_id: String) -> String:
	var corpse := _corpse_of(grave_id)
	if corpse != null and corpse.display_name != "":
		return corpse.display_name
	var old := Database.old_grave(grave_id) as OldGraveData
	return old.display_name if old != null and old.display_name != "" else grave_id


func _quality(grave_id: String) -> int:
	var graveyard := _graveyard()
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	return grave.quality if grave != null else 0


func _player_near(grave_id: String) -> bool:
	var player := _first(&"player") as Node3D
	var plot := GraveView.plot_of(grave_id, get_tree() if is_inside_tree() else null)
	if player == null or plot == null or bool(player.get(&"in_interior")):
		return false
	return player.global_position.distance_to(plot.global_position) <= SEEN_DISTANCE


func _is_noisy(action_id: StringName) -> bool:
	var cfg := Database.config(&"action_config") as ActionConfig
	var list: Array[StringName] = cfg.noisy_actions if cfg != null else ActionConfig.new().noisy_actions
	return list.has(action_id)


func _kin() -> Array[KinData]:
	if not kin_data.is_empty():
		return kin_data
	var out: Array[KinData] = []
	for res: Resource in Database.kin_list():
		if res is KinData:
			out.append(res as KinData)
	return out


func _kin_data(kin_id: StringName) -> KinData:
	for kin: KinData in _kin():
		if kin.kin_id == kin_id:
			return kin
	return null


func _corpse_of(grave_id: String) -> CorpseRecord:
	var graveyard := _graveyard()
	var grave := graveyard.get_grave(grave_id) if graveyard != null else null
	return _corpse(grave.corpse_id) if grave != null else null


func _corpse(corpse_id: String) -> CorpseRecord:
	var manager := _first(&"corpse_manager") as CorpseManager
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _graveyard() -> Graveyard:
	return _first(&"graveyard") as Graveyard


func _player_inventory() -> Inventory:
	var player := _first(&"player")
	return player.get(&"inventory") as Inventory if player != null else null


func _open() -> bool:
	return GameState.flag_on(OPEN_FLAG)


func _open_day() -> int:
	return _int(GameState.get_flag(OPEN_DAY_FLAG, 0), 0)


func _lights_day() -> int:
	return _int(GameState.get_flag(LIGHTS_DAY_FLAG, -1), -1)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	if v is String and (v as String).is_valid_int():
		return (v as String).to_int()
	return fallback


static func _int_map(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key: Variant in raw:
			var v: Variant = (raw as Dictionary)[key]
			if v is int or v is float:
				out[str(key)] = roundi(float(v))
	return out


func _cfg() -> VisitorConfig:
	if config == null:
		config = Database.config(&"visitor_config") as VisitorConfig
	if config == null:
		config = VisitorConfig.new()
	return config
