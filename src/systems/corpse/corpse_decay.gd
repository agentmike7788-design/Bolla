class_name CorpseDecay
extends RefCounted
## Decay rules of a CorpseRecord (docs §2.5), used by CorpseManager: freshness as a pure
## function of the minutes since arrival. No state, no autoloads.

const MINUTES_PER_HOUR := 60
## Freshness at arrival (CorpseGenerator sets it); decay is measured from arrival_total_minutes.
const START_FRESHNESS := 1.0
## Freshness is kept on a grid of 1 / FRESHNESS_RESOLUTION: exact threshold times land exactly
## on the threshold, and the 14-digit floats of JSON.from_native save it bit-exactly.
const FRESHNESS_RESOLUTION := 1000000.0


## Docs §2.5 / Phase 4 §2.5: freshness = START_FRESHNESS - decay_per_hour * effective hours
## since arrival (min 0), in one expression from the total-minute difference – no float error
## adds up over the hourly steps – snapped to the FRESHNESS_RESOLUTION grid. Juniper windows
## (record.balm_windows) slow the decay to balm_factor while they overlap [arrival, now];
## Phase 6: cold windows (record.cold_windows) likewise – the stronger factor wins (effective_minutes).
static func freshness_at(record: CorpseRecord, now_total: int, decay_per_hour: float, balm_factor: float = 0.25) -> float:
	var minutes := effective_minutes(record, now_total, balm_factor)
	var value := maxf(0.0, START_FRESHNESS - decay_per_hour * minutes / float(MINUTES_PER_HOUR))
	return roundf(value * FRESHNESS_RESOLUTION) / FRESHNESS_RESOLUTION


## §2.5: minutes since arrival − (1 − balm_factor) × Σ overlap(balm window, [arrival, now]).
## Overlapping windows count once (their union), so 3 × 1 h back to back == 1 × 3 h.
## Phase 6 (§2.2): with cold windows the rate of every minute is min(balm factor while a juniper
## window runs else 1, cold factor while a cold window runs else 1) – cold and smoke never add up.
## The minutes are summed per rate (integers) and reduced once per rate: without cold windows this
## is bit-identical to the Phase-4 formula.
static func effective_minutes(record: CorpseRecord, now_total: int, balm_factor: float) -> float:
	var arrival := record.arrival_total_minutes
	var minutes := maxi(0, now_total - arrival)
	if minutes == 0 or (record.balm_windows.size() < 2 and record.cold_windows.size() < 3):
		return float(minutes)
	if record.cold_windows.size() < 3:
		var balmed := _covered_minutes(record.balm_windows, arrival, now_total)
		return float(minutes) - (1.0 - clampf(balm_factor, 0.0, 1.0)) * float(balmed)
	var by_rate := {}
	var borders := _borders(record, arrival, now_total, true)
	for i: int in borders.size() - 1:
		var rate := rate_at(record, borders[i], balm_factor)
		if rate < 1.0:
			by_rate[rate] = int(by_rate.get(rate, 0)) + borders[i + 1] - borders[i]
	var reduced := 0.0
	for rate: float in by_rate:
		reduced += (1.0 - rate) * float(by_rate[rate])
	return float(minutes) - reduced


## Phase 6: the decay rate factor of the minute `total` – min(balm_factor while a juniper window
## covers it else 1, cold_factor_at(total)).
static func rate_at(record: CorpseRecord, total: int, balm_factor: float) -> float:
	var rate := clampf(balm_factor, 0.0, 1.0) if is_balm_active(record, total) else 1.0
	return minf(rate, cold_factor_at(record, total))


## A juniper window of `record` covers the minute `now_total` (start ≤ now < end).
static func is_balm_active(record: CorpseRecord, now_total: int) -> bool:
	for i: int in range(0, record.balm_windows.size() - 1, 2):
		if record.balm_windows[i] <= now_total and now_total < record.balm_windows[i + 1]:
			return true
	return false


## Minutes from now until the freshness is first below `threshold` (−1 = already below, or it
## never gets there: no decay, threshold ≤ 0). Steps minute-exact across the balm and cold windows; for the UI
## ("noch ≈ 3 h") and CorpseExam.next_loss.
static func minutes_until(record: CorpseRecord, now_total: int, decay_per_hour: float, balm_factor: float, threshold: float) -> int:
	if freshness_at(record, now_total, decay_per_hour, balm_factor) < threshold:
		return -1
	if decay_per_hour <= 0.0 or threshold <= 0.0:
		return -1
	# Effective minutes at which the freshness falls below the threshold (first grid step below).
	var target := (START_FRESHNESS - threshold) * MINUTES_PER_HOUR / decay_per_hour
	var t := maxi(now_total, record.arrival_total_minutes)
	var done := effective_minutes(record, t, balm_factor)
	var factor := clampf(balm_factor, 0.0, 1.0)
	# Walk the segments between window borders after t (each segment has one constant rate;
	# juniper and cold windows, an open cold window runs on).
	var borders: Array[int] = []
	for b: int in _borders(record, t, -1, false):
		if b > t:
			borders.append(b)
	var guess := t
	var seg_start := t
	for border: int in borders + [-1]:
		var rate := minf(factor if is_balm_active(record, seg_start) else 1.0, cold_factor_at(record, seg_start))
		var seg_end := border
		if rate <= 0.0 and seg_end < 0:
			return -1
		var need := target - done
		if seg_end < 0 or (rate > 0.0 and need <= rate * (seg_end - seg_start)):
			guess = seg_start + maxi(0, floori(need / rate) - 1) if rate > 0.0 else seg_start
			break
		done += rate * (seg_end - seg_start)
		seg_start = seg_end
	# Exact on the freshness grid: first minute ≥ guess whose freshness is below the threshold.
	var m := maxi(guess, now_total)
	while m > now_total and freshness_at(record, m - 1, decay_per_hour, balm_factor) < threshold:
		m -= 1
	while freshness_at(record, m, decay_per_hour, balm_factor) >= threshold:
		m += 1
	return m - now_total


## Union length of the windows clipped to [from, to].
static func _covered_minutes(windows: PackedInt32Array, from: int, to: int) -> int:
	var spans: Array[Vector2i] = []
	for i: int in range(0, windows.size() - 1, 2):
		var a := maxi(windows[i], from)
		var b := mini(windows[i + 1], to)
		if b > a:
			spans.append(Vector2i(a, b))
	spans.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return x.x < y.x)
	var total := 0
	var cur_start := -1
	var cur_end := -1
	for span: Vector2i in spans:
		if span.x > cur_end:
			total += maxi(0, cur_end - cur_start)
			cur_start = span.x
			cur_end = span.y
		else:
			cur_end = maxi(cur_end, span.y)
	total += maxi(0, cur_end - cur_start)
	return total


## base_decay_per_hour * the decay_mult of the record's cause; 0 without tables.
static func decay_per_hour(record: CorpseRecord, tables: CorpseTables) -> float:
	if tables == null:
		return 0.0
	return tables.base_decay_per_hour * float(tables.get_cause(record.cause_id).get("decay_mult", 1.0))


# --- Phase 6 (docs/PHASE6_DESIGN.md §2.2, §3.4) -------------------------------------------------

## The cold factor of `record` at the minute `total`: the smallest factor of the cold windows
## [start, end (-1 = open), factor‰] that cover it (start ≤ total < end; an open window runs on),
## 1.0 without one.
static func cold_factor_at(record: CorpseRecord, total: int) -> float:
	var factor := 1.0
	var w := record.cold_windows
	for i: int in range(0, w.size() - 2, 3):
		if w[i] <= total and (w[i + 1] < 0 or total < w[i + 1]):
			factor = minf(factor, clampf(float(w[i + 2]) / 1000.0, 0.0, 1.0))
	return factor


## Sorted distinct window borders of both lists inside [from, to] (to < 0 = no upper limit);
## with_ends adds from and to themselves.
static func _borders(record: CorpseRecord, from: int, to: int, with_ends: bool) -> Array[int]:
	var raw: Array[int] = []
	for i: int in range(0, record.balm_windows.size() - 1, 2):
		raw.append(record.balm_windows[i])
		raw.append(record.balm_windows[i + 1])
	var w := record.cold_windows
	for i: int in range(0, w.size() - 2, 3):
		raw.append(w[i])
		if w[i + 1] >= 0:
			raw.append(w[i + 1])
	if with_ends:
		raw.append(from)
		raw.append(to)
	var out: Array[int] = []
	for b: int in raw:
		if b >= from and (to < 0 or b <= to) and not b in out:
			out.append(b)
	out.sort()
	return out
