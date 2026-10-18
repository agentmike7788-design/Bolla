class_name WalkTempo
extends RefCounted
## G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1): the pace of the schedule walks measured on the
## real world. A walk is an entry with travel_minutes > 0; its pace = flat polyline length / travel_minutes (m per game
## minute). Gaits: &"cart" (pushing the handcart, or riding on it – sit_cart), &"run" (run / climb: no walk, exempt),
## else &"walk" (walk and every *_walk cycle; walk_stiff / walk_bundle play the plain walk). The band of each gait is
## NpcConfig (walk_min/max_m_per_minute, cart_min/max_m_per_minute) – data/config/npc_config.tres.

const GAIT_WALK := &"walk"
const GAIT_CART := &"cart"
const GAIT_RUN := &"run"
const NPC_DIR := "res://data/npc/"
const RUN_ANIMS: Array[StringName] = [&"run", &"climb"]
const CART_ANIMS: Array[StringName] = [&"push_cart", &"sit_cart"]
const INDOOR_PREFIX := "v_in_"
## A step of one or two minutes may be slower than the band (whole minutes, rounded up – a 0.9 m hop takes 2).
const SHORT_MINUTES := 2


static func gait(e: ScheduleEntry) -> StringName:
	if e.with_cart or e.animation in CART_ANIMS:
		return GAIT_CART
	if e.animation in RUN_ANIMS:
		return GAIT_RUN
	return GAIT_WALK


## The region node an entry's waypoints live in: the village RegionRoot for &"village", else the world.
static func region_node(world: Node, e: ScheduleEntry) -> Node:
	if e.region == &"village":
		var v := world.get_node_or_null("Regions/Village")
		if v != null:
			return v
	return world


## [min, max] m per game minute of `g` (NpcConfig; run: no band → [0, INF]).
static func band(g: StringName, cfg: NpcConfig = null) -> Vector2:
	if cfg == null:
		cfg = config()
	match g:
		GAIT_CART:
			return Vector2(cfg.cart_min_m_per_minute, cfg.cart_max_m_per_minute)
		GAIT_RUN:
			return Vector2(0.0, INF)
	return Vector2(cfg.walk_min_m_per_minute, cfg.walk_max_m_per_minute)


static func config() -> NpcConfig:
	var cfg := Database.config(&"npc_config") as NpcConfig
	return cfg if cfg != null else NpcConfig.new()


## Every walk of the data schedules on `world`: [{npc, index, start, travel, length, pace, gait, region, flag,
## animation, path, from, to, ok}] (ok: pace inside the gait's band).
static func data_walks(world: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files := DirAccess.get_files_at(NPC_DIR)
	var ids: Array[String] = []
	for f: String in files:
		if f.ends_with("_schedule.tres"):
			ids.append(f.trim_suffix("_schedule.tres"))
	ids.sort()
	for id: String in ids:
		var sched := load(NPC_DIR + id + "_schedule.tres") as NpcSchedule
		if sched == null:
			continue
		out.append_array(schedule_walks(sched, world, id))
	return out


static func schedule_walks(sched: NpcSchedule, world: Node, label: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cfg := config()
	for i: int in sched.entries.size():
		var e := sched.entries[i]
		if e == null or e.travel_minutes <= 0 or e.path.size() < 2:
			continue
		out.append(measure(e, world, label, i, cfg))
	return out


static func measure(e: ScheduleEntry, world: Node, label: String, index: int = -1, cfg: NpcConfig = null) -> Dictionary:
	if cfg == null:
		cfg = config()
	var node := region_node(world, e) if world != null else null
	var length := ScheduleBuilder.path_length(e.path, node)
	var g := gait(e)
	var pace := length / float(maxi(e.travel_minutes, 1))
	var b := band(g, cfg)
	return {"npc": label, "index": index, "start": e.start_minute, "travel": e.travel_minutes, "length": length,
			"pace": pace, "gait": g, "region": e.region, "flag": e.today_flag, "animation": e.animation,
			"path": e.path, "from": e.path[0], "to": e.path[e.path.size() - 1],
			"ok": g == GAIT_RUN or (pace <= b.y + 0.0001 and (pace >= b.x - 0.0001 or e.travel_minutes <= SHORT_MINUTES))}


## Game minutes a walk of `length` m takes at the gait's target pace (at least 1 for any distance).
static func minutes_for(length: float, g: StringName = GAIT_WALK, cfg: NpcConfig = null) -> int:
	if cfg == null:
		cfg = config()
	if length <= 0.0001:
		return 0
	var v := cfg.cart_m_per_minute if g == GAIT_CART else cfg.walk_m_per_minute
	return maxi(1, ceili(length / maxf(v, 0.01) - 0.0001))


static func hhmm(minute: int) -> String:
	var m := posmod(minute, 1440)
	return "%02d:%02d" % [m / 60, m % 60]


static func header() -> String:
	return "npc\tflag\tstart\tarrive\tminutes\tlength_m\tm_per_min\tm_per_s\tspeed_scale\tgait\tanimation\tok\tpath"


static func line(r: Dictionary) -> String:
	var spm := 0.5
	var real := float(r.pace) / spm
	var designed := 1.14 if r.gait == GAIT_CART else 1.65
	return "%s\t%s\t%s\t%s\t%d\t%.1f\t%.2f\t%.2f\t%.2f\t%s\t%s\t%s\t%s" % [r.npc, r.flag, hhmm(int(r.start)),
			hhmm(int(r.start) + int(r.travel)), int(r.travel), float(r.length), float(r.pace), real, real / designed,
			r.gait, r.animation, "ok" if r.ok else "FAST" if float(r.pace) > band(r.gait).y else "SLOW", " ".join(r.path)]
