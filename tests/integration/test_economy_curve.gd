extends TestCase
## P1 + W3 (docs/PHASE10_DESIGN.md §2.3, §10.3): Zielkurve curve10 – EconomyCurveBot plays a new game through the
## dignified founder chain (Phase6Bot founder → founder7 → founder8 → founder9; founder10 joins with W3) on the
## Phase-10 tariff and checks the §2.3 bands (holdings every morning, Δ, spending quote, lowest morning per segment, day
## 14, the floors, the open wish list ≥ 1.3 × the income of the next 14 days).
## Always: the band evaluation on a synthetic curve, and a short run (new game to the first Friedhofsgeld on day 4).
## Env P10_CURVE=1: the whole chain to day 91 (≈ 25 min), report printed ("CURVE10 …") and written to
## user://test_economy_curve/curve10.md – the gate run (W3). Until P2's Treasury is in the world the bot runs with
## EconomyCurveBot.ParishEmu (the contract's Friedhofsgeld, stipend off); results: docs/reviews/phase10_wip/balance.md.

const TIMEOUT := 3600.0

var saves_dir := TestCase.user_dir("test_economy_curve")


func before_each() -> void:
	SaveManager.save_dir = saves_dir


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


## A curve inside every §2.3 band passes; leaving a band fails exactly that check.
func test_bands_on_a_synthetic_curve() -> void:
	var bot := EconomyCurveBot.new(tree, 91)
	# Mornings: 5 → 40 by day 14, 66 on day 25, 25 on day 30, 35 on day 40, 60 on day 53, 70 on 63, 80 on 75, 70 on 92;
	# 30 coins spent every day (the quotes), 1000 on the wish list.
	var keys := [[1, 5], [7, 12], [14, 40], [25, 66], [30, 25], [40, 35], [53, 60], [63, 70], [75, 80], [92, 70]]
	var spent := 0
	for i: int in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		for d: int in range(int(a[0]), int(b[0])):
			var h := int(a[1]) + (int(b[1]) - int(a[1])) * (d - int(a[0])) / (int(b[0]) - int(a[0]))
			bot.rows.append({"day": d, "holdings": h, "spent": spent, "stage": "x", "chapters": 0, "wish": 1000})
			spent += 30
	bot.rows.append({"day": 92, "holdings": 70, "spent": spent, "stage": "end", "chapters": 6, "wish": 1000})
	var failed := bot.failed_checks()
	assert_eq(failed.map(func(c: Dictionary) -> String: return c.what), [], "a curve inside the bands")
	assert_eq(bot.checks().size(), EconomyCurveBot.SEGMENTS.size() * 4 + 3 + EconomyCurveBot.CHECKPOINTS.size())
	# One morning at 3 coins on day 50: the floors and P7's band fail, nothing else.
	for r: Dictionary in bot.rows:
		if int(r.day) == 50:
			r.holdings = 3
	var names: Array = bot.failed_checks().map(func(c: Dictionary) -> String: return c.what)
	assert_eq(names, ["P7 Dorf: Polster morgens", "P7 Dorf: morgens min.", "morgens immer", "würdevoll ab Tag 7"])
	# Grundsatz 2: 100 open against ≈ 14 × 30 + Δ income fails at 1.3×.
	for r: Dictionary in bot.rows:
		r.wish = 100
	assert_false(bool(bot.wish_check(30).ok), "100 < 1.3 × the next 14 days' income")


## New game to day 4 with the Friedhofsgeld emulation: the first Schau on Sunday (day 3), paid on Monday 07:40 (day 4),
## prorated 3/7; no stipend; the wish list is recorded every morning.
func test_short_run_pays_the_first_friedhofsgeld() -> void:
	var bot := EconomyCurveBot.new(tree, 4)
	bot.parish_emu_on = true
	await bot.run()
	var emu := bot.emu
	assert_not_null(emu)
	assert_eq(bot.rows.map(func(r: Dictionary) -> int: return int(r.day)), [1, 2, 3, 4, 5], "mornings 1–5")
	assert_eq(bot.problems, PackedStringArray(), "no bot problems")
	assert_eq(emu.schauen.size(), 1, "one Schau (Sunday, day 3)")
	var s: Dictionary = emu.schauen[0]
	assert_eq([int(s.day), int(s.week)], [3, 0])
	var cfg := load("res://data/config/treasury_config.tres") as TreasuryConfig
	var full := int(s.quality) + int(s.need) + int(s.hardship)
	assert_eq(int(s.total), ceili(full * 3.0 / 7.0), "first week prorated 3/7")
	assert_true(int(s.need) == mini(ceili(float(cfg.need_threshold - int(s.holdings)) / cfg.need_divisor), cfg.need_cap), "need")
	assert_eq(int(s.get("paid_day", -1)), 4, "paid on Monday")
	assert_eq(int((bot.income_by_day.get(4, {}) as Dictionary).get("parish", 0)), int(s.total), "booked as parish (Friedhofsgeld)")
	assert_false((bot.income_by_day.get(2, {}) as Dictionary).has("parish"), "no stipend on day 2")
	for r: Dictionary in bot.rows:
		assert_true(int(r.holdings) >= EconomyCurveBot.FLOOR, "day %d: %d coins" % [r.day, r.holdings])
		assert_true(r.has("wish"), "the wish list is measured")
	print("CURVE10 short: schau %s · mornings %s" % [str(s), str(bot.rows.map(func(r: Dictionary) -> int: return int(r.holdings)))])


## P10_CURVE=1: the whole curve (gate run). Asserted are the invariants of the chain (no bot problem, all six chapters of
## Phase 3–9 by day 91, never a negative morning); the §2.3 bands are reported and asserted with P10_CURVE_STRICT=1
## (W3, once P2 / P4 / founder10 are in).
func test_curve10_whole_chain() -> void:
	if OS.get_environment("P10_CURVE") != "1":
		print("CURVE10 skipped (P10_CURVE=1 runs the whole chain to day 91)")
		return
	var bot := EconomyCurveBot.new(tree, 91)
	bot.parish_emu_on = true
	await bot.run()
	var text := bot.report("CURVE10 – neues Spiel bis Tag 91, Kette %s" % str(bot.stage_days))
	print(text)
	DirAccess.make_dir_recursive_absolute(saves_dir)
	var f := FileAccess.open(saves_dir.path_join("curve10.md"), FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	assert_eq(bot.problems, PackedStringArray(), "no bot problems")
	assert_eq(int(bot.row(92).get("chapters", 0)), 6, "all six chapters of Phase 3–9 by day 91")
	for r: Dictionary in bot.rows:
		assert_true(int(r.holdings) >= 0, "day %d" % r.day)
	if OS.get_environment("P10_CURVE_STRICT") == "1":
		assert_eq(bot.failed_checks().map(func(c: Dictionary) -> String: return "%s %s (%s)" % [c.what, c.value, c.band]), [],
				"§2.3 bands")
