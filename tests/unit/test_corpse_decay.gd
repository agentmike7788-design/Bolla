extends TestCase
## P2 (docs/PHASE6_DESIGN.md §2.2, §3.4, §10): CorpseDecay with cold windows – cold_factor_at,
## effective_minutes / freshness_at over juniper AND cold windows (rate = min(…), never added up),
## the factor table of §2.2, overlaps, multi-day jumps, loading in the middle of a window, and
## minutes_until across both lists (checked against a minute-by-minute walk).

## Base decay 0.05/h (rate 1.0): fresh (≥ 0.6) for 8 h.
const RATE := 0.05
const FRESH := 0.6
const BALM := 0.25


func _record(balm: PackedInt32Array = PackedInt32Array(), cold: PackedInt32Array = PackedInt32Array(), arrival: int = 0) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = "corpse_decay"
	r.arrival_total_minutes = arrival
	r.last_decay_total = arrival
	r.balm_windows = balm
	r.cold_windows = cold
	return r


## First minute ≥ now whose freshness is below `threshold`, walked minute by minute.
func _walk(r: CorpseRecord, now: int, threshold: float, limit: int = 10000) -> int:
	for m: int in range(now, now + limit):
		if CorpseDecay.freshness_at(r, m, RATE, BALM) < threshold:
			return m - now
	return -1


func test_cold_factor_at() -> void:
	assert_eq(CorpseDecay.cold_factor_at(_record(), 100), 1.0, "no windows")
	var r := _record(PackedInt32Array(), PackedInt32Array([100, 200, 500, 300, -1, 800]))
	assert_eq(CorpseDecay.cold_factor_at(r, 99), 1.0, "before")
	assert_almost(CorpseDecay.cold_factor_at(r, 100), 0.5, 0.000001, "start inclusive")
	assert_almost(CorpseDecay.cold_factor_at(r, 199), 0.5, 0.000001)
	assert_eq(CorpseDecay.cold_factor_at(r, 200), 1.0, "end exclusive, gap")
	assert_almost(CorpseDecay.cold_factor_at(r, 300), 0.8, 0.000001, "open window")
	assert_almost(CorpseDecay.cold_factor_at(r, 100000), 0.8, 0.000001, "an open window runs on")
	var both := _record(PackedInt32Array(), PackedInt32Array([0, 100, 700, 50, 150, 400]))
	assert_almost(CorpseDecay.cold_factor_at(both, 60), 0.4, 0.000001, "overlap: the stronger one")


func test_factor_table_of_section_2_2() -> void:
	# §2.2: at rate 1.0 a corpse stays fresh 8 h; niche 0.5 / 0.4 / 0.3 → 16 / 20 / 26.7 h,
	# crypt room 0.8 / 0.7 / 0.6 → 10 / 11.4 / 13.3 h.
	assert_eq(CorpseDecay.minutes_until(_record(), 0, RATE, BALM, FRESH), 481, "8 h (first minute below)")
	var hours := {500: 16.0, 400: 20.0, 300: 26.6667, 800: 10.0, 700: 11.4286, 600: 13.3333}
	for permille: int in hours:
		var r := _record(PackedInt32Array(), PackedInt32Array([0, -1, permille]))
		var m := CorpseDecay.minutes_until(r, 0, RATE, BALM, FRESH)
		var h: float = hours[permille]
		assert_true(m >= int(h * 60.0) and m <= ceili(h * 60.0) + 1, "‰%d: %d min ≈ %.2f h" % [permille, m, h])
		assert_eq(m, _walk(r, 0, FRESH), "‰%d: minute-exact" % permille)


func test_effective_minutes_with_cold_only() -> void:
	var r := _record(PackedInt32Array(), PackedInt32Array([100, 400, 500]))
	assert_almost(CorpseDecay.effective_minutes(r, 100, BALM), 100.0)
	assert_almost(CorpseDecay.effective_minutes(r, 400, BALM), 100.0 + 150.0)
	assert_almost(CorpseDecay.effective_minutes(r, 1000, BALM), 1000.0 - 150.0)
	assert_almost(CorpseDecay.effective_minutes(r, 250, BALM), 100.0 + 75.0, 0.0001, "inside the window")
	var open := _record(PackedInt32Array(), PackedInt32Array([100, -1, 300]))
	assert_almost(CorpseDecay.effective_minutes(open, 1100, BALM), 100.0 + 300.0, 0.0001, "open window up to now")


func test_cold_and_juniper_take_the_stronger_factor() -> void:
	# Juniper 200…500 (× 0.25), cold 100…-1 (× 0.5): 0–100 rate 1, 100–200 cold 0.5, 200–500
	# juniper 0.25 (not 0.125), 500–700 cold 0.5.
	var r := _record(PackedInt32Array([200, 500]), PackedInt32Array([100, -1, 500]))
	assert_almost(CorpseDecay.effective_minutes(r, 700, BALM), 100.0 + 50.0 + 75.0 + 100.0)
	assert_almost(CorpseDecay.rate_at(r, 150, BALM), 0.5)
	assert_almost(CorpseDecay.rate_at(r, 300, BALM), 0.25, 0.000001, "no adding up")
	# A weaker juniper (0.8) inside a stronger cold (0.3): the cold wins.
	var cold := _record(PackedInt32Array([0, 600]), PackedInt32Array([0, -1, 300]))
	assert_almost(CorpseDecay.effective_minutes(cold, 600, 0.8), 180.0)
	assert_almost(CorpseDecay.freshness_at(cold, 600, RATE, 0.8), 1.0 - RATE * 3.0, 0.0000005)


func test_without_cold_windows_the_phase4_formula_is_bit_identical() -> void:
	var balm := PackedInt32Array([130, 190, 170, 400, 900, 960])
	var r := _record(balm)
	var now := 1500
	var covered := 60 + 210 + 60
	assert_eq(CorpseDecay.effective_minutes(r, now, BALM), float(now) - (1.0 - BALM) * float(covered))
	var with_cold := _record(balm, PackedInt32Array([2000, -1, 500]))
	assert_eq(CorpseDecay.effective_minutes(with_cold, now, BALM), CorpseDecay.effective_minutes(r, now, BALM),
			"a cold window after now changes nothing (bit-identical)")


func test_multi_day_jump_is_a_pure_function_of_the_minutes() -> void:
	var r := _record(PackedInt32Array([1000, 1600]), PackedInt32Array([460, 1440, 500, 1440, 3000, 400, 3000, -1, 300]), 460)
	var jump := CorpseDecay.freshness_at(r, 460 + 3 * 1440, RATE, BALM)
	# Hourly evaluation of the same function ends on the same value (no accumulation).
	var last := 0.0
	for t: int in range(460, 460 + 3 * 1440 + 1, 60):
		last = CorpseDecay.freshness_at(r, t, RATE, BALM)
	assert_eq(last, jump)
	# Piecewise by hand: 460–1000 × 0.5 (270), 1000–1440 juniper 0.25 (110), 1440–1600 juniper
	# (40), 1600–3000 × 0.4 (560), 3000–4780 × 0.3 (534).
	assert_almost(CorpseDecay.effective_minutes(r, 460 + 3 * 1440, BALM), 270.0 + 110.0 + 40.0 + 560.0 + 534.0, 0.0001)


func test_loading_in_the_middle_of_a_window() -> void:
	var r := _record(PackedInt32Array([500, 800]), PackedInt32Array([460, 700, 500, 700, -1, 400]), 460)
	var copy := CorpseRecord.from_dict(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict())))))
	for t: int in [600, 750, 1000, 5000]:
		assert_eq(CorpseDecay.freshness_at(copy, t, RATE, BALM), CorpseDecay.freshness_at(r, t, RATE, BALM), "t=%d" % t)
		assert_eq(CorpseDecay.minutes_until(copy, t, RATE, BALM, 0.3), CorpseDecay.minutes_until(r, t, RATE, BALM, 0.3))


func test_minutes_until_across_both_lists() -> void:
	var cases: Array[CorpseRecord] = [
		_record(PackedInt32Array([100, 300]), PackedInt32Array([50, -1, 500])),
		_record(PackedInt32Array([200, 260, 400, 700]), PackedInt32Array([0, 150, 800, 150, 450, 400, 450, -1, 300])),
		_record(PackedInt32Array(), PackedInt32Array([0, 100, 500, 300, -1, 700])),
		_record(PackedInt32Array([0, 2000]), PackedInt32Array([500, -1, 300])),
	]
	for r: CorpseRecord in cases:
		for now: int in [0, 120, 333, 700]:
			for threshold: float in [0.9, 0.6, 0.3, 0.1]:
				var expected := -1 if CorpseDecay.freshness_at(r, now, RATE, BALM) < threshold else _walk(r, now, threshold)
				assert_eq(CorpseDecay.minutes_until(r, now, RATE, BALM, threshold), expected,
						"%s now %d thr %.1f" % [r.cold_windows, now, threshold])


func test_minutes_until_with_a_frozen_segment() -> void:
	# Juniper factor 0 inside a cold window: nothing happens there, the cold runs on after it.
	var r := _record(PackedInt32Array([0, 600]), PackedInt32Array([0, -1, 500]))
	assert_eq(CorpseDecay.minutes_until(r, 0, RATE, 0.0, 0.9), 600 + 241, "0 in the window, then 2 h × 0.5")
