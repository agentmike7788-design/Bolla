extends TestCase
## P3 (docs/PHASE8_DESIGN.md §2.5, §3.4, §10): ApprenticeRules – minutes per place by level and morale
## (Angelernt / Geübt, ≥ 4 −10 %, ≤ 1 +20 %, Ungelernt cannot), the deterministic mistake (8 % / 2 %, × 0.5
## after a scolding, never at level 0), the working days (day % 7 == 2, festivals, 3 unpaid days). Config and
## tasks from tests/fixtures/phase8 (Phase8Fixtures).


func test_minutes_by_level_and_morale() -> void:
	var cfg := Phase8Fixtures.apprentice_config()
	var rake := Phase8Fixtures.apprentice_task(&"rake")
	var weed := Phase8Fixtures.apprentice_task(&"weed")
	var water := Phase8Fixtures.apprentice_task(&"water")
	var candle := Phase8Fixtures.apprentice_task(&"candle")
	assert_eq([ApprenticeRules.minutes_for(rake, 1, 3, cfg), ApprenticeRules.minutes_for(rake, 2, 3, cfg)], [15, 10], "§2.5.2 rake 15 / 10")
	assert_eq([ApprenticeRules.minutes_for(weed, 1, 3, cfg), ApprenticeRules.minutes_for(weed, 2, 3, cfg)], [30, 20])
	assert_eq([ApprenticeRules.minutes_for(water, 1, 3, cfg), ApprenticeRules.minutes_for(water, 2, 3, cfg)], [7, 5])
	assert_eq([ApprenticeRules.minutes_for(candle, 1, 3, cfg), ApprenticeRules.minutes_for(candle, 2, 3, cfg)], [5, 4])
	assert_eq(ApprenticeRules.minutes_for(rake, 0, 3, cfg), 0, "Ungelernt: he cannot")
	assert_eq(ApprenticeRules.minutes_for(rake, 3, 3, cfg), 0, "no level 3")
	assert_eq(ApprenticeRules.minutes_for(null, 1, 3, cfg), 0)
	assert_eq(ApprenticeRules.minutes_for(weed, 1, 4, cfg), 27, "morale ≥ 4: −10 %")
	assert_eq(ApprenticeRules.minutes_for(weed, 1, 5, cfg), 27)
	assert_eq(ApprenticeRules.minutes_for(weed, 1, 2, cfg), 30, "morale 2: as listed")
	assert_eq(ApprenticeRules.minutes_for(weed, 1, 1, cfg), 36, "morale ≤ 1: +20 %")
	assert_eq(ApprenticeRules.minutes_for(weed, 1, 0, cfg), 36)
	assert_eq(ApprenticeRules.minutes_for(candle, 2, 5, cfg), 4, "rounded (3.6)")
	assert_eq(ApprenticeRules.minutes_for(candle, 2, 0, cfg), 5, "rounded (4.8)")


func test_mistakes_are_deterministic_with_the_rates() -> void:
	var cfg := Phase8Fixtures.apprentice_config()
	assert_eq(ApprenticeRules.mistake(&"rake", "dirt_l_02", 57, 1, false, cfg), ApprenticeRules.mistake(&"rake", "dirt_l_02", 57, 1, false, cfg))
	var counts := {1: 0, 2: 0, -1: 0}
	var differs := false
	var n := 4000
	for i: int in n:
		var spot := "spot_%d" % (i % 97)
		var day := 50 + floori(i / 97.0)
		if ApprenticeRules.mistake(&"weed", spot, day, 1, false, cfg):
			counts[1] += 1
		if ApprenticeRules.mistake(&"weed", spot, day, 2, false, cfg):
			counts[2] += 1
		if ApprenticeRules.mistake(&"weed", spot, day, 1, true, cfg):
			counts[-1] += 1
		if ApprenticeRules.mistake(&"weed", spot, day, 1, false, cfg) != ApprenticeRules.mistake(&"rake", spot, day, 1, false, cfg):
			differs = true
	assert_almost(float(counts[1]) / n, 0.08, 0.015, "Angelernt 8 %")
	assert_almost(float(counts[2]) / n, 0.02, 0.008, "Geübt 2 %")
	assert_almost(float(counts[-1]) / n, 0.04, 0.012, "scolded: × 0.5")
	assert_true(differs, "the task goes into the draw")
	for i: int in 200:
		assert_false(ApprenticeRules.mistake(&"rake", "s%d" % i, 60, 0, false, cfg), "level 0 never")
	# Geübt errs only where Angelernt would (the same draw, a lower bar).
	for i: int in 500:
		if ApprenticeRules.mistake(&"rake", "s%d" % i, 61, 2, false, cfg):
			assert_true(ApprenticeRules.mistake(&"rake", "s%d" % i, 61, 1, false, cfg))
	var r := ApprenticeRules.roll(&"rake", "x", 3)
	assert_true(r >= 0.0 and r < 1.0)


func test_working_days() -> void:
	var cfg := Phase8Fixtures.apprentice_config()
	assert_true(ApprenticeRules.works_today(54, true, 0, false, cfg))
	assert_false(ApprenticeRules.works_today(54, false, 0, false, cfg), "not hired")
	assert_false(ApprenticeRules.works_today(58, true, 0, false, cfg), "58 % 7 == 2: „Jakob hilft heute im Krug“")
	assert_false(ApprenticeRules.works_today(65, true, 0, false, cfg), "every seventh day")
	assert_true(ApprenticeRules.works_today(59, true, 0, false, cfg))
	assert_false(ApprenticeRules.works_today(55, true, 0, true, cfg), "festival day")
	assert_true(ApprenticeRules.works_today(55, true, 2, false, cfg), "two unpaid days: still comes")
	assert_false(ApprenticeRules.works_today(55, true, 3, false, cfg), "after 3 unpaid days at home")
	var offs := 0
	for day: int in range(50, 64):
		if not ApprenticeRules.works_today(day, true, 0, false, cfg):
			offs += 1
	assert_eq(offs, 2, "two days off in two weeks")
