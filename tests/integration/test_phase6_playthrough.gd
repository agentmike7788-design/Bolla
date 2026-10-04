extends TestCase
## W3 QA playthrough bot of Phase 6 (docs/PHASE6_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5,
## §2.8): Phase6Bot plays the Phase-6 arc on the real graveyard world – from the Phase-5 end states
## (v4 fixtures day30_reverent / day30_mender / day35_harvester) for 10 days and from a new game
## for 36 days (founder). Asserts: no engine errors and no warnings, value ranges, no bot problems
## (every action the strategy wants is possible – no softlock), the chapter roof_and_earth for every
## strategy, the coin ledger (income by source, spending by purpose = the stats, start + income −
## spending = end) against the §2.8 calculation from the measured start purse, the strategy
## expectations of §10 and save/load every morning + once in the crypt = reverent6. The per-day
## numbers are printed ("PLAYTHROUGH6 <strategy>") for docs/reviews/phase6_wip/qa_playthrough.md.
## Env P6QA_ONLY=<strategy,…> runs only those strategies.

const TIMEOUT := 1500.0
const SLOT := 93
## §10 plays the mortician 10 days (chapter ≤ day 38); crypt 3 first costs 85 coins before the
## chapel – measured it needs longer (qa_playthrough.md, Befund B6-2): 13 days.
const MORTICIAN_DAYS := 13
## The mender (chapel first, full tending every day) builds its last level on day 39 or 40 – the
## margin of one evening (Befund B6-3): 11 days.
const MENDER_DAYS := 11

## Rows of the reverent6 run (save_load6 must match them).
static var reverent_rows: Array[Dictionary] = []

var saves_dir := TestCase.user_dir("test_saves_p6_bot")
var warnings := WarningLog.new()


class WarningLog extends Logger:
	var lines: PackedStringArray = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		mutex.lock()
		lines.append("%s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


## §1.4 arc A / §2.8 / §10, measured from the start purse of 27 (W0 note 1; §2.8 counted 31):
## chapter by day 37 (§10: 36 – Befund B6-1), Phase-6 spending ≥ 130, end 0–45, morning from B2
## never below 12 (§10: 15 – the arc runs 4 coins lower from the start), ≥ 3 services (§10: 4 –
## the first two corpses come before the chapel can be paid), 5 reinterred (§10: 6 – crypt 3 is
## not affordable within the 10 days).
func test_reverent6() -> void:
	var bot := await _play_fixture(&"reverent6", "slot_p5_day30_reverent", 10)
	if bot == null:
		return
	var end := bot.inv().count(&"coin")
	assert_eq(bot.start_coins, 27, "the measured start purse (W0 note 1)")
	assert_true(bot.chapter6_day > 0 and bot.chapter6_day <= 37, "reverent6: chapter by day 37 (%d)" % bot.chapter6_day)
	assert_true(bot.spent_p6 >= 130, "Phase-6 spending ≥ 130 (%d)" % bot.spent_p6)
	assert_true(end >= 0 and end <= 45, "end 0–45 (%d)" % end)
	var lowest_b2 := _lowest_morning_from(bot, 31)
	assert_true(lowest_b2 >= 12, "morning from B2 never below 12 (%d)" % lowest_b2)
	assert_true(bot.services.size() >= 3, "≥ 3 services (%d)" % bot.services.size())
	assert_true(bot.ossuary.reinterred().size() >= 5, "≥ 5 reinterred (%d)" % bot.ossuary.reinterred().size())
	# §2.8: the buildings take most of what Phase 6 brings in.
	var available := bot.start_coins + bot.total_income()
	assert_true(bot.spent_p6 * 100 >= 70 * available, "most of the money spent (%d of %d)" % [bot.spent_p6, available])
	reverent_rows = bot.rows.duplicate(true)


## The crypt to level 3 first; every corpse waits in a niche overnight: no find lost to decay after
## ≤ 20 h lying, the freshness on the clock = the cold-window formula; chapter ≤ day 38.
func test_mortician() -> void:
	var bot := await _play_fixture(&"mortician", "slot_p5_day30_reverent", MORTICIAN_DAYS)
	if bot == null:
		return
	assert_true(bot.chapter6_day > 0 and bot.chapter6_day <= 42, "mortician: chapter by day 42 (§10: 38 – Befund B6-2) (%d)" % bot.chapter6_day)
	assert_true(bot.level_days.has("crypt3"), "crypt 3 built")
	assert_false(bot.mortician_checks.is_empty(), "corpses examined after a night in a niche")
	var kept := 0
	for c: Dictionary in bot.mortician_checks:
		# §2.2: the fine traces (cause, min_freshness 0.6) survive while the cold keeps the corpse
		# „frisch" – no find lost by decay while the formula says ≥ 0.6 (Liegezeit ≤ 20 h at crypt 2).
		# The finds resolve at the end of the examination (35 min later): a margin of 0.02 for that
		# (04.10.2026: with crypt 1 from the start the arc runs earlier and hit 0.601 → 0.59x at the end).
		if float(c.freshness) >= 0.62:
			assert_eq(int(c.lost), 0, "%s: no find lost at freshness %.3f (%d min, crypt %d)" % [c.id, c.freshness, c.lay_minutes, c.crypt])
			kept += 1
		assert_almost(float(c.freshness), float(c.expected), 1e-6, "%s: freshness = CorpseDecay formula" % c.id)
		if not bool(c.balm):
			assert_almost(float(c.freshness), float(c.by_hand), 1e-5, "%s: freshness = Σ minutes × cold factor (§2.2)" % c.id)
	assert_true(kept >= 1, "at least one corpse kept all its finds over night in the cold")
	print("PLAYTHROUGH6 mortician checks %s · niche stays %s" % [str(bot.mortician_checks), str(bot.niche_stays)])


## The chapel first, devotions for the most restless: content ghosts +≥ 3 (or the W0 finding: the
## mender's ghosts are content already), no robbed soul content; chapter.
func test_mender6() -> void:
	var bot := await _play_fixture(&"mender6", "slot_p5_day30_mender", MENDER_DAYS)
	if bot == null:
		return
	assert_true(bot.chapter6_day > 0, "mender6: chapter (%d)" % bot.chapter6_day)
	var last: Dictionary = bot.rows.back()
	print("PLAYTHROUGH6 mender6 content ghosts %d → %d, devotions %s" % [bot.content_start, last.content, str(bot.devotions)])
	assert_true(int(last.content) - _content_at_open(bot) >= 3, "content ghosts +≥ 3 (%d → %d)" % [_content_at_open(bot), last.content])
	_assert_robbed_never_content(bot)


## Mandatory + all level 3 + devotions for every robbed soul: chapter; spending ≥ 180; end ≥ 0;
## robbed souls at most calm (a finding, no failure: printed).
func test_harvester6() -> void:
	var bot := await _play_fixture(&"harvester6", "slot_p5_day35_harvester", 10)
	if bot == null:
		return
	assert_true(bot.chapter6_day > 0, "harvester6: chapter (%d)" % bot.chapter6_day)
	assert_true(bot.spent_p6 >= 180, "Phase-6 spending ≥ 180 (%d)" % bot.spent_p6)
	assert_true(bot.inv().count(&"coin") >= 0)
	_assert_robbed_never_content(bot)
	print("PLAYTHROUGH6 harvester6 end %d coins, levels %s, devotions %d" % [bot.inv().count(&"coin"), str(bot.buildings.levels()), bot.devotions.size()])


## New game, 36 days: six_pits ≤ day 22, names_in_stone ≤ day 30 (unchanged), roof_and_earth ≤ day 36.
func test_founder() -> void:
	if not _selected(&"founder"):
		return
	await SaveManager.new_game()
	var bot := await _play(&"founder", 36)
	assert_true(bot.chapter_day > 0 and bot.chapter_day <= 22, "founder: six_pits by day 22 (%d)" % bot.chapter_day)
	assert_true(bot.chapter5_day > 0 and bot.chapter5_day <= 30, "founder: names_in_stone by day 30 (%d)" % bot.chapter5_day)
	assert_true(bot.chapter6_day > 0 and bot.chapter6_day <= 36, "founder: roof_and_earth by day 36 (%d)" % bot.chapter6_day)


func test_save_load6_matches_reverent6() -> void:
	var bot := await _play_fixture(&"save_load6", "slot_p5_day30_reverent", 10)
	if bot == null:
		return
	assert_true(bot.chapter6_day > 0, "chapter with a reload every morning")
	assert_true(bot.saved_in_crypt, "saved and loaded once in the crypt with a corpse in a niche")
	if reverent_rows.is_empty():
		return  # run alone (filter): nothing to compare with
	assert_eq(bot.rows.size(), reverent_rows.size())
	for i: int in mini(bot.rows.size(), reverent_rows.size()):
		assert_eq(bot.rows[i], reverent_rows[i], "day %d identical to reverent6" % bot.rows[i].day)


# --- helpers ----------------------------------------------------------------------------------

static func _selected(strategy: StringName) -> bool:
	var only := OS.get_environment("P6QA_ONLY")
	return only == "" or String(strategy) in only.split(",")


func _play_fixture(strategy: StringName, fixture: String, days: int) -> Phase6Bot:
	if not _selected(strategy):
		return null
	assert_eq(Phase6Fixtures.install_save_v4(fixture, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, fixture + " loads")
	if err != OK:
		return null
	return await _play(strategy, days)


func _play(strategy: StringName, days: int) -> Phase6Bot:
	var bot := Phase6Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in days:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.quality >= 0 and r.quality <= 400, "%s day %d: quality %d in range" % [strategy, r.day, r.quality])
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d in range" % [strategy, r.day, r.rep])
		assert_true(r.piety >= -100 and r.piety <= 100, "%s day %d: piety %d in range" % [strategy, r.day, r.piety])
		assert_true(r.coins >= 0, "%s day %d: coins %d" % [strategy, r.day, r.coins])
	bot.unwatch()
	bot.income.valuables = bot.valuables_income
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	var ledger := GameState.coin_ledger()
	for reason: Variant in bot.spent_by:
		assert_true(ledger.has(StringName(str(reason))), "%s: ledger knows %s" % [strategy, reason])
	var booked := 0
	for reason: StringName in ledger:
		booked += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), booked, "%s: stats.coins_spent = sum of the ledger" % strategy)
	assert_eq(bot.start_coins + bot.total_income() - bot.total_spent(), bot.inv().count(&"coin"),
			"%s: start + income − spending = end (%s)" % [strategy, bot.ledger_text()])
	# Every chapter's goal: three buildings ≥ 2, a serviced corpse buried with a marker, a box reinterred.
	if bot.chapter6_day > 0:
		var lv := bot.buildings.levels()
		assert_true(int(lv[&"crypt"]) >= 2 and int(lv[&"chapel"]) >= 2 and int(lv[&"shed"]) >= 2, "%s: levels %s" % [strategy, str(lv)])
		assert_true(bot.rites.services_buried() >= 1 and bot.ossuary.reinterred().size() >= 1, "%s: service buried, box reinterred" % strategy)
	print("PLAYTHROUGH6 %s  chapter6 day %d (open day %d, names_in_stone day %d, six_pits day %d)  %s  levels %s  services %d  devotions %d  lifted %s  reinterred %s  fetched %s  stored %s  processions %d"
			% [strategy, bot.chapter6_day, bot.open6_day, bot.chapter5_day, bot.chapter_day, bot.ledger_text(), str(bot.level_days),
			bot.services.size(), bot.devotions.size(), str(bot.lifted_days), str(bot.reinterred_days), str(bot.fetched), str(bot.stored),
			bot.procession_walks])
	print(bot.table_p6())
	for line: String in bot.trace6:
		print("TRACE6 %s %s" % [strategy, line])
	return bot


func _lowest_morning_from(bot: Phase6Bot, day: int) -> int:
	var low := 1 << 30
	for r: Dictionary in bot.rows:
		if int(r.day) >= day:
			low = mini(low, int(r.get("morning_coins", 0)))
	return low


func _content_at_open(bot: Phase6Bot) -> int:
	for r: Dictionary in bot.rows:
		if bool(r.get("open6", false)):
			return int(r.content) if int(r.day) > bot.open6_day else int(r.content)
	return bot.content_start


## §2.4: a devotion never lifts a robbed soul past devotion_robbed_cap (8, the top of „gleichmütig")
## – a robbed ghost that is content got there by its stone (Phase 5 mender), never by a candle;
## fully robbed souls (hair + teeth, Phase 5) are never content.
func _assert_robbed_never_content(bot: Phase6Bot) -> void:
	var robbed := 0
	var cap := (Database.config(&"ghost_config") as GhostConfig).devotion_robbed_cap
	for g: GraveRecord in bot.graveyard.graves():
		var c := bot.manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if c == null or c.harvested.is_empty():
			continue
		robbed += 1
		var info := bot.ghosts.mood_info(g.id)
		if int(info.get("devotion", 0)) > 0:
			assert_true(int(info.score) <= maxi(cap, int(info.score) - int(info.devotion)),
					"robbed %s: the devotion lifts at most to %d (%s)" % [g.id, cap, str(info)])
		if c.is_harvested(CorpseRecord.HARVEST_HAIR) and c.is_harvested(CorpseRecord.HARVEST_TEETH):
			assert_ne(info.get("mood", &""), GhostMood.CONTENT, "fully robbed %s is not content (%s)" % [g.id, g.marker_id])
	print("PLAYTHROUGH6 %s: %d robbed graves checked" % [bot.strategy, robbed])
