class_name VisitRules
extends RefCounted
## Pure visit-plan rules (docs/PHASE8_DESIGN.md §2.1.4, §2.2.2, §2.2.3, §3.2.1): the next visit day of a grave
## (first visit the day after the burial, every 3 (+0/1 seed) days during the 21 days of mourning, then every
## 7; at the opening the graves in mourning spread over the first three days, older ones by seed mod 7), the
## villagers' visit days (every n days from p8_open_day + first_offset, past the night of the lights), the
## flowers, the slot assignment (≤ 3 a day, ≤ 2 at once) and the visible timeline of one visit (arriving →
## at each grave: lay flowers 2 · mourn 30 (a further grave of the round 15 in all) · look 2 → waiting 10 →
## leaving 12 → gone). Deterministic, no tree.

const PHASE_ARRIVING := &"arriving"
const PHASE_MOURNING := &"mourning"
const PHASE_WAITING := &"waiting"
const PHASE_LEAVING := &"leaving"
const PHASE_GONE := &"gone"
## Steps inside the mourning phase at one grave (the Npc animation, §2.2.3).
const STEP_WALK := &"walk"
const STEP_LAY := &"lay_flowers"
const STEP_MOURN := &"mourn"
const STEP_LOOK := &"look"
## §2.2.3: ≈ 8 minutes from road_end up the carriage road and through the gate, 3–10 to the grave (default 5
## without a baked route), ≈ 12 back; lay 2, look 2; a further grave of a household's round ≈ 15 in all.
const ROAD_MINUTES := 8
const DEFAULT_ROUTE_MINUTES := 5
const LEAVE_MINUTES := 12
const LAY_MINUTES := 2
const LOOK_MINUTES := 2
const ROUND_GRAVE_MINUTES := 15
## A visit ends before the evening: no visit at night (§2.2.2).
const LAST_START_MINUTE := 960


## Deterministic 0…n−1 of a value list (Array hash, like the mourning ribbon).
static func pick(values: Array, n: int) -> int:
	return posmod(hash(values), maxi(n, 1))


## The day a household should next come to the grave buried on `buried_day` (§2.2.2). `last` = day of the
## last visit (−1 = none yet), `open_day` = p8_open_day.
static func next_due(grave_id: String, buried_day: int, last: int, open_day: int, cfg: VisitorConfig) -> int:
	if last < 0:
		var first := buried_day + cfg.first_delay_days
		if first >= open_day:
			return first
		# Opened later: a grave still in mourning on one of the first three days, an older one by seed mod 7.
		if open_day - buried_day < cfg.mourning_days:
			return open_day + pick([grave_id, buried_day, "open"], 3)
		return open_day + pick([grave_id, buried_day, "open"], cfg.interval_late)
	if last - buried_day < cfg.mourning_days:
		return last + cfg.interval_mourning + pick([grave_id, last], 2)
	return last + cfg.interval_late


## The first day of a household's round: the earliest due day of its graves (−1 = none).
static func household_due(dues: Array) -> int:
	var best := -1
	for d: Variant in dues:
		if int(d) >= 0 and (best < 0 or int(d) < best):
			best = int(d)
	return best


## The next visit day of a villager (§2.1.4): `last` = the last visit day (−1 = none): p8_open_day +
## first_offset, then every `every` days; a day on the night of the lights moves one day on.
static func villager_due(last: int, open_day: int, first_offset: int, every: int, lights_day: int) -> int:
	var due := open_day + first_offset if last < 0 else last + maxi(every, 1)
	if lights_day > 0 and due == lights_day:
		due += 1
	return due


## The visitor brings flowers: always on the first visit and during the mourning time, later by chance
## (flowers_chance_late, seeded) – never without a bouquet model.
static func brings_flowers(first: bool, in_mourning: bool, has_bouquet: bool, kin_id: StringName, day: int, cfg: VisitorConfig) -> bool:
	if not has_bouquet:
		return false
	if first or in_mourning:
		return true
	return float(pick([String(kin_id), day, "flowers"], 1000)) / 1000.0 < cfg.flowers_chance_late


## Minutes of one visit before the end of the last look (arriving + the graves), for `graves` graves.
static func graves_minutes(graves: int, flowers: bool, cfg: VisitorConfig) -> int:
	if graves <= 0:
		return 0
	var first := (LAY_MINUTES if flowers else 0) + cfg.mourn_minutes + LOOK_MINUTES
	return first + (graves - 1) * ROUND_GRAVE_MINUTES


## Total length of a visit (with `waits` the 10 minutes of waiting).
static func duration(travel: int, graves: int, flowers: bool, waits: bool, cfg: VisitorConfig) -> int:
	return travel + graves_minutes(graves, flowers, cfg) + (cfg.wait_minutes if waits else 0) + LEAVE_MINUTES


## The segments of a visit starting at `start` (total or day minutes – the unit of `start`):
## [{phase, step, grave_index, from, to}] in order; the last one is gone (to = from).
static func timeline(start: int, travel: int, graves: int, flowers: bool, waits: bool, cfg: VisitorConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := start
	out.append({"phase": PHASE_ARRIVING, "step": STEP_WALK, "grave_index": 0, "from": t, "to": t + travel})
	t += travel
	for i: int in graves:
		if i == 0:
			if flowers:
				out.append({"phase": PHASE_MOURNING, "step": STEP_LAY, "grave_index": i, "from": t, "to": t + LAY_MINUTES})
				t += LAY_MINUTES
			out.append({"phase": PHASE_MOURNING, "step": STEP_MOURN, "grave_index": i, "from": t, "to": t + cfg.mourn_minutes})
			t += cfg.mourn_minutes
		else:
			var walk := 2
			out.append({"phase": PHASE_MOURNING, "step": STEP_WALK, "grave_index": i, "from": t, "to": t + walk})
			t += walk
			if flowers:
				out.append({"phase": PHASE_MOURNING, "step": STEP_LAY, "grave_index": i, "from": t, "to": t + LAY_MINUTES})
				t += LAY_MINUTES
			var mourn := ROUND_GRAVE_MINUTES - walk - LOOK_MINUTES - (LAY_MINUTES if flowers else 0)
			out.append({"phase": PHASE_MOURNING, "step": STEP_MOURN, "grave_index": i, "from": t, "to": t + mourn})
			t += mourn
		out.append({"phase": PHASE_MOURNING, "step": STEP_LOOK, "grave_index": i, "from": t, "to": t + LOOK_MINUTES})
		t += LOOK_MINUTES
	if waits:
		out.append({"phase": PHASE_WAITING, "step": &"wait", "grave_index": maxi(graves - 1, 0), "from": t, "to": t + cfg.wait_minutes})
		t += cfg.wait_minutes
	out.append({"phase": PHASE_LEAVING, "step": STEP_WALK, "grave_index": maxi(graves - 1, 0), "from": t, "to": t + LEAVE_MINUTES})
	t += LEAVE_MINUTES
	out.append({"phase": PHASE_GONE, "step": &"", "grave_index": maxi(graves - 1, 0), "from": t, "to": t})
	return out


## The segment of `timeline` at minute `now` (before the start: {}; after the end: the gone segment).
static func segment_at(segments: Array[Dictionary], now: int) -> Dictionary:
	if segments.is_empty() or now < int(segments[0].from):
		return {}
	for s: Dictionary in segments:
		if now < int(s.to):
			return s
	return segments.back()


## The minute the look at grave `index` ends (the view is taken then).
static func look_end(segments: Array[Dictionary], index: int) -> int:
	for s: Dictionary in segments:
		if s.step == STEP_LOOK and int(s.grave_index) == index:
			return int(s.to)
	return -1


## The minute the visit is over (gone).
static func end_minute(segments: Array[Dictionary]) -> int:
	return int(segments.back().from) if not segments.is_empty() else -1


## Slot minutes for the households of the day: each takes the next slot in order, villagers keep their own
## minutes; ≤ max_visits_day visits in all and ≤ max_concurrent at once (`windows` = [from, to] of the
## villagers' visits). Returns one minute per household (−1 = no room today → tomorrow).
static func assign_slots(households: int, windows: Array, length: int, cfg: VisitorConfig) -> PackedInt32Array:
	var out := PackedInt32Array()
	var taken: Array = windows.duplicate()
	var room := maxi(cfg.max_visits_day - windows.size(), 0)
	var slot_i := 0
	for h: int in households:
		var minute := -1
		while room > 0 and slot_i < cfg.slots.size():
			var s := cfg.slots[slot_i]
			slot_i += 1
			if _overlaps(taken, s, s + length) < cfg.max_concurrent:
				minute = s
				break
		if minute >= 0:
			taken.append([minute, minute + length])
			room -= 1
		out.append(minute)
	return out


static func _overlaps(windows: Array, from: int, to: int) -> int:
	var n := 0
	for w: Variant in windows:
		if w is Array and (w as Array).size() >= 2 and int(w[0]) < to and from < int(w[1]):
			n += 1
	return n
