class_name ApprenticePlanner
extends RefCounted
## Pure planning of the apprentice's day (docs/PHASE8_DESIGN.md §2.5.2, §2.5.3, §3.4); reusable (Phase 14 may
## reuse it; no Phase-8 system knows Phase 14). Reads the world (care spots, graves, flowers, candles,
## visits) and changes nothing.
## - The board lines are worked top to bottom; inside a line always the nearest place that needs it
##   (greedy from where he stands). A line whose task starts later (candles from 15:00) waits until then
##   while the lines below go on; Ungelernt tasks and missing tools / candles leave the line out.
## - Places: rake / weed = DirtSpot of that kind with level ≥ 1 in an open section of the area; water = a
##   grave whose flowers wilt today or tomorrow (or are wilted); candle = an occupied grave (FILLED / MARKED)
##   without a burning candle – area „wished" = only graves with an open candle wish.
## - Never: a grave someone mourns at today (Visitors' plan), a locked section, a place twice.
## - Times: walking = ScheduleBuilder.travel_minutes of the straight line (3.2 m per game minute), work =
##   ApprenticeRules.minutes_for; no place runs into lunch (lunch.x–lunch.y on the bench) or past end_minute;
##   the watering can is refilled at the rain barrel (a visible walk) when its fills run out; time left = sweep
##   in front of the hut.
## Entries: {task, spot_id, grave_id, start (the walk begins), walk_minutes, work_start, work_minutes, end, path
## (point ids – waypoints or "@x,y,z"), mistake (ApprenticeRules.mistake, deterministic), kind, consumes}.
## Special tasks: &"refill" (rain barrel), &"lunch" (bench), &"sweep" (hut path).
## state: {levels {task: 0…2}, morale, scolded (bool – yesterday), position (point id where he starts),
## fills (watering can), items {item: count in his box}, done [spot ids done today], world (Node with
## waypoints), tasks {task: ApprenticeTaskData} (tests; else Database), mourned [grave ids] (tests; else
## Visitors), wished [grave ids] (tests; else Visitors' open candle wishes), end_minute (default cfg)}.

const TASK_REFILL := &"refill"
const TASK_LUNCH := &"lunch"
const TASK_SWEEP := &"sweep"
const KIND_LEAVES := &"leaves"
const KIND_WEEDS := &"weeds"
const KIND_FLOWERS := &"flowers"
const KIND_CANDLE := &"candle"
const AREA_ALL := &"all"
const AREA_WISHED := &"wished"
const WP_BARREL := "rain_barrel"
const WP_LUNCH := "apprentice_lunch"
const WP_SWEEP := "apprentice_sweep"
## Where he stands beside a care spot / at the foot end of a grave without a visitor spot (m, towards the camera).
const SPOT_STAND := Vector3(0.0, 0.0, 0.7)
const GRAVE_FOOT := Vector3(0.0, 0.0, 1.9)
const MINUTES_PER_DAY := 1440


static func plan(day: int, from_minute: int, lines: Array[Dictionary], state: Dictionary, tree: SceneTree,
		cfg: ApprenticeConfig) -> Array[Dictionary]:
	if cfg == null:
		cfg = ApprenticeConfig.new()
	var out: Array[Dictionary] = []
	var world: Node = state.get("world") as Node
	var end_minute := int(state.get("end_minute", cfg.end_minute))
	var t := from_minute
	var here := str(state.get("position", ""))
	var lunch_done := t >= cfg.lunch.y
	var fills := int(state.get("fills", 0))
	var items: Dictionary = (state.get("items", {}) as Dictionary).duplicate()
	var used := {}
	for id: Variant in state.get("done", []):
		used[str(id)] = true
	var gc_cfg := _grave_care_config()
	var mourned := _mourned(state, tree, day)
	var wished := _wished(state, tree)
	var pending: Array = []
	for line: Dictionary in lines:
		var task := _task(StringName(str(line.get("task", ""))), state)
		if task == null:
			continue
		var level := int((state.get("levels", {}) as Dictionary).get(String(task.id), (state.get("levels", {}) as Dictionary).get(task.id, 0)))
		if level <= 0:
			continue
		if task.tool_item != &"" and int(items.get(task.tool_item, items.get(String(task.tool_item), 0))) <= 0:
			continue
		pending.append({"task": task, "level": level, "area": StringName(str(line.get("area", AREA_ALL)))})
	var guard := 0
	while t < end_minute and guard < 400:
		guard += 1
		var pick := _next(pending, t, here, used, mourned, wished, items, day, tree, world, cfg, state, lunch_done, end_minute,
				gc_cfg, fills)
		if pick.is_empty():
			# Nothing fits now: lunch if it is due, wait for a later line (sweep), else sweep until the end.
			if not lunch_done and t < cfg.lunch.y:
				if t < cfg.lunch.x:
					# Time left before lunch: he sweeps (until a later line starts, or until lunch).
					var later := _later_start(pending, t)
					var until := later if later >= 0 and later < cfg.lunch.x else cfg.lunch.x
					var before := out.size()
					t = _add_sweep(out, t, until, here, world, day)
					if out.size() > before:
						here = _sweep_point(world, here)
					if until != cfg.lunch.x:
						continue
				var lunch := _stay_entry(TASK_LUNCH, t, t, cfg.lunch.y, here, _named(world, WP_LUNCH, here), world, day)
				if not lunch.is_empty():
					out.append(lunch)
					here = (lunch.path as PackedStringArray)[(lunch.path as PackedStringArray).size() - 1]
				t = cfg.lunch.y
				lunch_done = true
				continue
			var later_start := _later_start(pending, t)
			if later_start >= 0 and later_start < end_minute:
				var count := out.size()
				t = _add_sweep(out, t, later_start, here, world, day)
				if out.size() > count:
					here = _sweep_point(world, here)
				continue
			_add_sweep(out, t, end_minute, here, world, day)
			break
		var task: ApprenticeTaskData = pick.task
		if task.spot_kind == KIND_FLOWERS and fills <= 0:
			var barrel := _named(world, WP_BARREL, here)
			var walk := _walk_minutes(here, barrel, world)
			out.append({"task": TASK_REFILL, "spot_id": "", "grave_id": "", "start": t, "walk_minutes": walk, "work_start": t + walk,
					"work_minutes": gc_cfg.refill_minutes, "end": t + walk + gc_cfg.refill_minutes, "path": _path(here, barrel, world),
					"mistake": false, "kind": TASK_REFILL, "consumes": ""})
			t += walk + gc_cfg.refill_minutes
			here = barrel
			fills = gc_cfg.can_fills
			continue
		out.append(pick.entry)
		used[str(pick.entry.spot_id)] = true
		t = int(pick.entry.end)
		here = str(pick.entry.target)
		(pick.entry as Dictionary).erase("target")
		if task.spot_kind == KIND_FLOWERS:
			fills -= 1
		if task.consumes != &"":
			var key: Variant = task.consumes if items.has(task.consumes) else String(task.consumes)
			items[key] = int(items.get(key, 0)) - (2 if bool(pick.entry.mistake) and task.spot_kind == KIND_CANDLE else 1)
	return out


## Tool / consumable of a board line missing in his box ("Keine Kerzen mehr.") – [item ids].
static func missing_items(lines: Array[Dictionary], items: Dictionary, state: Dictionary = {}) -> Array[StringName]:
	var out: Array[StringName] = []
	for line: Dictionary in lines:
		var task := _task(StringName(str(line.get("task", ""))), state)
		if task == null:
			continue
		for item: StringName in [task.tool_item, task.consumes]:
			if item != &"" and int(items.get(item, items.get(String(item), 0))) <= 0 and not out.has(item):
				out.append(item)
	return out


## The places of one task in an area right now (unordered): [{spot_id, grave_id, pos}].
static func places(task: ApprenticeTaskData, area: StringName, tree: SceneTree, state: Dictionary, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if task == null or tree == null:
		return out
	var mourned := _mourned(state, tree, day)
	var wished := _wished(state, tree)
	match task.spot_kind:
		KIND_LEAVES, KIND_WEEDS:
			var clean := tree.get_first_node_in_group(&"cleanliness")
			for node: Node in tree.get_nodes_in_group(DirtSpot.GROUP):
				var spot := node as DirtSpot
				if spot == null or spot.kind != task.spot_kind or spot.spot_id == "":
					continue
				if not _in_area(spot.section_id, area) or not _section_open(spot.section_id, tree):
					continue
				if spot.grave_id != "" and mourned.has(spot.grave_id):
					continue
				if clean == null or not clean.has_method(&"level") or int(clean.call(&"level", spot.spot_id)) < 1:
					continue
				out.append({"spot_id": spot.spot_id, "grave_id": spot.grave_id, "pos": spot.global_position + SPOT_STAND})
		KIND_FLOWERS, KIND_CANDLE:
			var care := tree.get_first_node_in_group(&"grave_care")
			if care == null:
				return out
			var flowers: Dictionary = {}
			if task.spot_kind == KIND_FLOWERS and care.has_method(&"save_state"):
				var st: Variant = care.call(&"save_state")
				flowers = (st as Dictionary).get("flowers", {}) if st is Dictionary else {}
			var graveyard := tree.get_first_node_in_group(&"graveyard")
			for node: Node in tree.get_nodes_in_group(&"grave_plot"):
				var plot := node as Node3D
				if plot == null:
					continue
				var gid := str(plot.get(&"grave_id"))
				var section := StringName(str(plot.get(&"section_id")))
				if gid == "" or mourned.has(gid) or not _in_area(section, area, task.spot_kind == KIND_CANDLE) \
						or not _section_open(section, tree):
					continue
				if task.spot_kind == KIND_FLOWERS:
					if not _wilts_soon(gid, care, flowers, day):
						continue
				else:
					if area == AREA_WISHED and not wished.has(gid):
						continue
					if bool(care.call(&"candle_lit", gid)) or not _occupied(gid, graveyard):
						continue
				out.append({"spot_id": gid, "grave_id": gid, "pos": _grave_pos(plot, state.get("world") as Node)})
	return out


# --- internals ------------------------------------------------------------------------------------

## The next place: the first pending line (top to bottom) that has a fitting place now – its nearest one.
static func _next(pending: Array, t: int, here: String, used: Dictionary, mourned: Dictionary, wished: Dictionary,
		items: Dictionary, day: int, tree: SceneTree, world: Node, cfg: ApprenticeConfig, state: Dictionary, lunch_done: bool,
		end_minute: int, gc_cfg: GraveCareConfig, fills: int) -> Dictionary:
	var from := ScheduleBuilder.point(world, here) if here != "" else Vector3.ZERO
	for p: Dictionary in pending:
		var task: ApprenticeTaskData = p.task
		if task.from_minute > t:
			continue
		if task.consumes != &"" and int(items.get(task.consumes, items.get(String(task.consumes), 0))) <= 0:
			continue
		var level := int(p.level)
		var work := ApprenticeRules.minutes_for(task, level, int(state.get("morale", cfg.morale_start)), cfg)
		if work <= 0:
			continue
		var limit := end_minute if lunch_done or t >= cfg.lunch.y else cfg.lunch.x
		var extra := 0
		if task.spot_kind == KIND_FLOWERS and fills <= 0:
			extra = _walk_minutes(here, _named(world, WP_BARREL, here), world) + gc_cfg.refill_minutes
		var candidates := places(task, p.area, tree, state, day)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da := _flat(from, a.pos)
			var db := _flat(from, b.pos)
			return da < db or (is_equal_approx(da, db) and str(a.spot_id) < str(b.spot_id)))
		for c: Dictionary in candidates:
			if used.has(str(c.spot_id)) or (str(c.grave_id) != "" and mourned.has(str(c.grave_id))):
				continue
			var target := ScheduleBuilder.point_id(c.pos)
			var walk := _walk_minutes(here, target, world)
			if t + extra + walk + work > limit:
				continue
			if extra > 0:
				# The refill comes first – the place itself is chosen again from the barrel.
				return {"task": task, "entry": {}}
			return {"task": task, "entry": {"task": task.id, "spot_id": str(c.spot_id), "grave_id": str(c.grave_id), "start": t,
					"walk_minutes": walk, "work_start": t + walk, "work_minutes": work, "end": t + walk + work, "path": _path(here, target, world),
					"mistake": ApprenticeRules.mistake(task.id, str(c.spot_id), day, level, bool(state.get("scolded", false)), cfg),
					"kind": task.spot_kind, "consumes": String(task.consumes), "target": target}}
	return {}


## The earliest from_minute > t of a pending line that still has places (-1 = none).
static func _later_start(pending: Array, t: int) -> int:
	var best := -1
	for p: Dictionary in pending:
		var task: ApprenticeTaskData = p.task
		if task.from_minute > t and (best < 0 or task.from_minute < best):
			best = task.from_minute
	return best


static func _add_sweep(out: Array[Dictionary], t: int, until: int, here: String, world: Node, day: int) -> int:
	if until <= t:
		return t
	var e := _stay_entry(TASK_SWEEP, t, t, until, here, _sweep_point(world, here), world, day)
	if not e.is_empty():
		out.append(e)
	return until


static func _sweep_point(world: Node, here: String) -> String:
	return _named(world, WP_SWEEP, here)


## Walk from `here` to `target` from t, then stay (work) from max(arrival, not_before) until `until`.
static func _stay_entry(task: StringName, t: int, not_before: int, until: int, here: String, target: String, world: Node,
		_day: int) -> Dictionary:
	var walk := _walk_minutes(here, target, world)
	var work_start := maxi(t + walk, not_before)
	if work_start >= until:
		return {}
	return {"task": task, "spot_id": "", "grave_id": "", "start": t, "walk_minutes": walk, "work_start": work_start,
			"work_minutes": until - work_start, "end": until, "path": _path(here, target, world), "mistake": false, "kind": task, "consumes": ""}


## W-Welt (W2): on the real graveyard the way around graves, fences and buildings (WorldRoot.route_between), else
## the straight leg.
static func _path(here: String, target: String, world: Node = null) -> PackedStringArray:
	var out := PackedStringArray()
	if here != "" and target != "" and target != here and world != null and world.has_method(&"route_between"):
		return world.call(&"route_between", here, target)
	if here != "":
		out.append(here)
	if target != "" and target != here:
		out.append(target)
	return out


static func _walk_minutes(here: String, target: String, world: Node) -> int:
	if here == "" or target == "" or here == target:
		return 0
	var d := ScheduleBuilder.path_length(_path(here, target, world), world)
	if d <= 0.0001 and not (world != null and world.has_method(&"get_waypoint")):
		var a := ScheduleBuilder.point(world, here)
		var b := ScheduleBuilder.point(world, target)
		d = Vector2(a.x - b.x, a.z - b.z).length()
	return 0 if d <= 0.0001 else maxi(1, ceili(d / _speed() - 0.0001))


## A named waypoint of the world (W-Welt), else `fallback` (where he stands).
static func _named(world: Node, id: String, fallback: String) -> String:
	return id if ScheduleBuilder.has_point(world, id) else fallback


static func _grave_pos(plot: Node3D, world: Node) -> Vector3:
	var gv := "gv_" + str(plot.get(&"grave_id"))
	if ScheduleBuilder.has_point(world, gv):
		return ScheduleBuilder.point(world, gv)
	return plot.to_global(GRAVE_FOOT) if plot.is_inside_tree() else plot.position + GRAVE_FOOT


static func _in_area(section: StringName, area: StringName, wished_ok := false) -> bool:
	return area == AREA_ALL or area == &"" or section == area or (wished_ok and area == AREA_WISHED)


static func _section_open(section: StringName, tree: SceneTree) -> bool:
	var expansion := tree.get_first_node_in_group(&"expansion")
	if expansion == null or not expansion.has_method(&"is_unlocked"):
		return true
	return bool(expansion.call(&"is_unlocked", section))


static func _occupied(grave_id: String, graveyard: Node) -> bool:
	if graveyard == null or not graveyard.has_method(&"get_grave"):
		return false
	var g := graveyard.call(&"get_grave", grave_id) as GraveRecord
	return g != null and (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED)


## Flowers that wilt before the end of tomorrow (or are wilted already); a wreath never needs water.
static func _wilts_soon(grave_id: String, care: Node, flowers: Dictionary, day: int) -> bool:
	var state := StringName(str(care.call(&"flowers_state", grave_id)))
	if state == &"" or state == &"wreath":
		return false
	if state == &"wilted":
		return true
	var f: Variant = flowers.get(grave_id)
	if not f is Dictionary:
		return false
	var watered := int((f as Dictionary).get("watered", (f as Dictionary).get("planted", 0)))
	var cfg := _grave_care_config()
	return watered + cfg.flower_fresh_minutes <= (day + 1) * MINUTES_PER_DAY


## Graves with a visit today (Visitors' plan of this day) – he does not work where someone mourns.
static func _mourned(state: Dictionary, tree: SceneTree, day: int) -> Dictionary:
	var out := {}
	if state.has("mourned"):
		for g: Variant in state.mourned:
			out[str(g)] = true
		return out
	var visitors := tree.get_first_node_in_group(&"visitors") if tree != null else null
	if visitors == null:
		return out
	if visitors.has_method(&"active_visits"):
		for v: Dictionary in visitors.call(&"active_visits"):
			for g: Variant in v.get("graves", []):
				out[str(g)] = true
	if visitors.has_method(&"save_state"):
		var st: Variant = visitors.call(&"save_state")
		if st is Dictionary and int((st as Dictionary).get("plan_day", -1)) == day:
			for v: Variant in (st as Dictionary).get("plan", []):
				if v is Dictionary:
					for g: Variant in (v as Dictionary).get("graves", []):
						out[str(g)] = true
	return out


## Graves with an open candle wish (area „wished").
static func _wished(state: Dictionary, tree: SceneTree) -> Dictionary:
	var out := {}
	if state.has("wished"):
		for g: Variant in state.wished:
			out[str(g)] = true
		return out
	var visitors := tree.get_first_node_in_group(&"visitors") if tree != null else null
	if visitors != null and visitors.has_method(&"open_wishes"):
		for w: Dictionary in visitors.call(&"open_wishes"):
			if str(w.get("kind", "")) == "candle":
				out[str(w.get("grave_id", ""))] = true
	return out


static func _task(id: StringName, state: Dictionary) -> ApprenticeTaskData:
	var tasks: Dictionary = state.get("tasks", {})
	if tasks.has(id):
		return tasks[id] as ApprenticeTaskData
	if tasks.has(String(id)):
		return tasks[String(id)] as ApprenticeTaskData
	return Database.apprentice_task(id) as ApprenticeTaskData


static func _grave_care_config() -> GraveCareConfig:
	var cfg := Database.config(&"grave_care_config") as GraveCareConfig
	return cfg if cfg != null else GraveCareConfig.new()


static func _speed() -> float:
	return ScheduleBuilder._speed()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
