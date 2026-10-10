extends TestCase
## W3 QA playthrough bot of Phase 8 (docs/PHASE8_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5, §2.10): Phase8Bot
## plays the Phase-8 arc on the real world from the Phase-7 end states (v6 fixtures). Asserts: no engine errors,
## no warnings, no bot problems (no softlock), value ranges, the coin ledger (start + income − spending = end,
## purse + wage tin), the morning never below 5, and the §10 expectations per strategy; save_load8 = kindly8 day
## by day. The numbers per day are printed ("PLAYTHROUGH8 <strategy>") for docs/reviews/phase8_round1/qa_playthrough.md.
## Env P8QA_ONLY=<strategy,…> runs only those strategies; P8QA_DAYS=<n> plays n days (debugging).

const TIMEOUT := 3600.0
const SLOT := 92
const DAYS := 10

static var kindly_rows: Array[Dictionary] = []
static var kindly_tips: int = -1

var saves_dir := TestCase.user_dir("test_saves_p8_bot")
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


## §10 kindly8: arc A, the chapter B8–B10, the end 75–100, the morning never below 5, ≥ 6 wishes, tips ≤ 25.
func test_kindly8() -> void:
	var bot := await _play_fixture(&"kindly8", "slot_p7_day53_neighbor")
	if bot == null:
		return
	var end := bot.coins_total()
	assert_eq(bot.start8_coins, 48, "the measured start purse (W0 note 1)")
	_expect_chapter(bot, 8, 10)
	assert_true(end >= 75 and end <= 100, "kindly8: end 75–100 (%d)" % end)
	assert_true(bot.visitors.done_wishes().size() >= 6, "≥ 6 wishes (%d)" % bot.visitors.done_wishes().size())
	assert_true(int(bot.income.tip) <= 25, "tips ≤ 25 (%d)" % int(bot.income.tip))
	kindly_rows = bot.rows.duplicate(true)
	kindly_tips = int(bot.income.tip)


## §10 anatomist8: specimens (Phase-7 flags), the chapter, Lenz and Liesel at most „Bekannt", tips below kindly8.
func test_anatomist8() -> void:
	var bot := await _play_fixture(&"anatomist8", "slot_p7_day53_anatomist")
	if bot == null:
		return
	_expect_chapter(bot, 1, 10)
	for npc: StringName in [&"priest", &"washer"]:
		assert_true(RelationshipRules.tier_index(bot.rel.tier(npc)) <= RelationshipRules.tier_index(&"acquainted"),
				"%s at most „Bekannt“ (%s)" % [npc, bot.rel.tier(npc)])
	if kindly_tips >= 0:
		assert_true(int(bot.income.tip) < kindly_tips, "tips %d < kindly8 %d" % [int(bot.income.tip), kindly_tips])
	assert_true(bot.coins_total() <= bot.start8_coins + 50, "end ≤ start + 50 (%d / %d)" % [bot.coins_total(), bot.start8_coins])


## §10 lazy8: no apprentice, no wish – no chapter, no errors, reputation down by one tier at most.
func test_lazy8() -> void:
	var tier_before := -1
	var bot := await _play_fixture(&"lazy8", "slot_p7_day53_neighbor")
	if bot == null:
		return
	assert_eq(bot.chapter8_day, -1, "lazy8: no chapter")
	assert_false(bot.app.is_hired(), "no apprentice")
	assert_eq(bot.visitors.done_wishes().size(), 0, "no wish")
	var first: Dictionary = bot.rows.filter(func(r: Dictionary) -> bool: return bool(r.get("open8", false)))[0]
	tier_before = ReputationRules.tier_index(first.tier) if first.has("tier") else -1
	if tier_before >= 0:
		assert_true(ReputationRules.tier_index(bot.rep.tier()) >= tier_before - 1, "reputation at most one tier down")


## §10 night8: the nights awake – the observations, Lambert caught (reported), the chapter.
func test_night8() -> void:
	var bot := await _play_fixture(&"night8", "slot_p7_day53_neighbor")
	if bot == null:
		return
	_expect_chapter(bot, 1, 10)
	assert_true(bot.observed.size() >= 3, "night8: the night visits observed (%s)" % str(bot.observed))
	assert_eq(bot.robber.fate(), &"reported", "Lambert reported (%s)" % str(bot.robber_log))


func test_night8_let_go() -> void:
	var bot := await _play_fixture(&"night8b", "slot_p7_day53_neighbor")
	if bot == null:
		return
	assert_eq(bot.robber.fate(), &"let_go", "Lambert let go (%s)" % str(bot.robber_log))


## §10 founder8: the founder's end state of Phase 7, 14 days, the chapter by day 68.
func test_founder8() -> void:
	var bot := await _play_fixture(&"founder8", "slot_p7_founder", 14)
	if bot == null:
		return
	assert_true(bot.chapter8_day > 0 and bot.chapter8_day <= 68, "founder8: chapter by day 68 (%d)" % bot.chapter8_day)


func test_save_load8_matches_kindly8() -> void:
	var bot := await _play_fixture(&"save_load8", "slot_p7_day53_neighbor")
	if bot == null:
		return
	assert_true(bot.saved_moments.has("visit"), "saved and loaded during a visit (%s)" % str(bot.saved_moments))
	if kindly_rows.is_empty():
		return
	assert_eq(bot.rows.size(), kindly_rows.size())
	for i: int in mini(bot.rows.size(), kindly_rows.size()):
		assert_eq(bot.rows[i], kindly_rows[i], "day %d identical to kindly8" % bot.rows[i].day)


# --- helpers ----------------------------------------------------------------------------------

func _expect_chapter(bot: Phase8Bot, from_b: int, to_b: int) -> void:
	var b := bot.chapter8_day - bot.open8_day + 1 if bot.chapter8_day > 0 else -1
	assert_true(b >= from_b and b <= to_b, "%s: chapter „Wer heraufkommt“ at B%d (day %d, open %d; goal %s)" % [bot.strategy, b,
			bot.chapter8_day, bot.open8_day, str(bot.life.goal_progress())])
	assert_true(bot.lowest_morning_p8 >= 5, "%s: the morning never below 5 (%d)" % [bot.strategy, bot.lowest_morning_p8])


static func _selected(strategy: StringName) -> bool:
	var only := OS.get_environment("P8QA_ONLY")
	return only == "" or String(strategy) in only.split(",")


func _play_fixture(strategy: StringName, fixture: String, days: int = DAYS) -> Phase8Bot:
	if not _selected(strategy):
		return null
	assert_eq(Phase8Fixtures.install_save_v6(fixture, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, fixture + " loads")
	if err != OK:
		return null
	if OS.get_environment("P8QA_DAYS") != "":
		days = int(OS.get_environment("P8QA_DAYS"))
	return await _play(strategy, days)


func _play(strategy: StringName, days: int) -> Phase8Bot:
	var bot := Phase8Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in days:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d in range" % [strategy, r.day, r.rep])
		assert_true(r.piety >= -100 and r.piety <= 100, "%s day %d: piety %d in range" % [strategy, r.day, r.piety])
		assert_true(r.coins >= 0, "%s day %d: coins %d" % [strategy, r.day, r.coins])
		for v: Variant in (r.get("rel", {}) as Dictionary).values():
			assert_true(int(v) >= 0 and int(v) <= 100, "%s day %d: relationship %d in range" % [strategy, r.day, int(v)])
	bot.unwatch()
	bot.income.valuables = bot.valuables_income
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	var ledger := GameState.coin_ledger()
	var booked := 0
	for reason: StringName in ledger:
		booked += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), booked, "%s: stats.coins_spent = sum of the ledger" % strategy)
	assert_eq(bot.start_coins + bot.total_income() - bot.total_spent(), bot.coins_total(),
			"%s: start + income − spending = end, purse + tin (%s)" % [strategy, bot.ledger_text()])
	print("PLAYTHROUGH8 %s  chapter8 day %d (open day %d)  %s  goal %s  wishes %s  visits %d  alms %s  observed %s  robber %s  dances %d"
			% [strategy, bot.chapter8_day, bot.open8_day, bot.ledger_text(), str(bot.life.goal_progress()), str(bot.wishes_taken.size()),
			bot.visits_served.size(), str(bot.alms_days), str(bot.observed), str(bot.robber_log), bot.dances])
	print(bot.table_p8())
	for line: String in bot.trace8:
		print("TRACE8 %s %s" % [strategy, line])
	for line: String in bot.trace7:
		if line.contains("talk") or line.contains("order") or line.contains("village"):
			print("TRACE7 %s %s" % [strategy, line])
	return bot
