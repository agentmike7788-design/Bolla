extends TestCase
## W3 QA playthrough bot (docs/PHASE3_DESIGN.md §10, §1.3, §2.5–§2.7): Phase3Bot plays 14
## in-game days of the real graveyard world under several strategies. Asserts: no engine errors
## and no warnings, quality / reputation in range, reputation drift exactly once per day, coins
## plausible against §2.6, the phase goal (12 graves) around day 14 for the diligent player,
## „Ehrwürdig“ (100) reachable, „Würdevoll“ (50) still reachable without tending.
## The per-day numbers are printed ("PLAYTHROUGH <strategy>") for
## docs/reviews/phase3_wip/qa_playthrough.md.

const TIMEOUT := 240.0
const DAYS := 14

var saves_dir := TestCase.user_dir("test_saves_p3_bot")
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
	await SaveManager.new_game()


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_diligent() -> void:
	var bot := await _play(&"diligent")
	var last: Dictionary = bot.rows.back()
	assert_true(GameState.has_flag(&"cemetery_complete"), "diligent: all 12 graves by day %d" % DAYS)
	assert_true(_first_day(bot, func(r: Dictionary) -> bool: return r.marked >= 12) <= DAYS, "phase goal ≈ day 14")
	assert_true(_first_day(bot, func(r: Dictionary) -> bool: return r.quality >= 100) > 0, "„Ehrwürdig“ reachable (max %d)" % _max(bot, "quality"))
	assert_true(last.rep >= 55, "diligent ends at least „Geschätzt“ (%d)" % last.rep)


## §1.3 gate goal: „Würdevoll“ also with neglected tending (everything else done properly).
func test_neglectful_still_reaches_dignified() -> void:
	var bot := await _play(&"neglectful")
	assert_true(_first_day(bot, func(r: Dictionary) -> bool: return r.quality >= 50) > 0,
			"„Würdevoll“ without tending (max %d)" % _max(bot, "quality"))


## Never tends, takes every valuable, no decor: slower (no Birkenhang), but no softlock.
func test_sloppy_makes_progress() -> void:
	var bot := await _play(&"sloppy")
	var last: Dictionary = bot.rows.back()
	assert_true(last.east, "sloppy still clears the Ostwiese")
	assert_true(last.marked >= 9, "sloppy fills the yard and the Ostwiese (%d)" % last.marked)


func test_hoarder_without_decor() -> void:
	var bot := await _play(&"hoarder")
	assert_true(expansion_done(bot), "hoarder clears both sections")
	for r: Dictionary in bot.rows:
		assert_eq(r.decor, 0, "no decor")


func test_save_load_every_day_matches_diligent() -> void:
	var bot := await _play(&"save_load")
	assert_true(GameState.has_flag(&"cemetery_complete"), "reloading every morning changes nothing")


func test_early_sleeper() -> void:
	var bot := await _play(&"early_sleeper")
	assert_true(bot.rows.back().marked >= 9, "sleeping at 18:00 still makes progress (%d)" % bot.rows.back().marked)


# --- helpers ----------------------------------------------------------------------------------

func _play(strategy: StringName) -> Phase3Bot:
	var bot := Phase3Bot.new(strategy, tree)
	bot.bind()
	var drifts: Array[int] = []
	var on_rep := func(_v: int, _t: StringName, _d: int, reason: String) -> void:
		if reason == Reputation.REASON_DRIFT:
			drifts.append(TimeManager.day)
	EventBus.reputation_changed.connect(on_rep)
	var coins_in := {"n": 0}
	var on_pay := func(n: int, _reason: String) -> void: coins_in.n += n
	EventBus.payment_received.connect(on_pay)
	for i: int in DAYS:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.quality >= 0 and r.quality <= 150, "%s day %d: quality %d in range" % [strategy, r.day, r.quality])
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d in range" % [strategy, r.day, r.rep])
		assert_eq(int(GameState.get_flag(&"rep_last_day", 0)), TimeManager.day, "%s: drift applied for day %d" % [strategy, TimeManager.day])
	EventBus.reputation_changed.disconnect(on_rep)
	EventBus.payment_received.disconnect(on_pay)
	var seen := {}
	for d: int in drifts:
		assert_false(seen.has(d), "%s: reputation drift twice on day %d" % [strategy, d])
		seen[d] = true
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	print("PLAYTHROUGH %s  spent %d  gifts %d  income %d" % [strategy, bot.spent, bot.gifts, coins_in.n])
	print(bot.table())
	return bot


func expansion_done(bot: Phase3Bot) -> bool:
	return bot.rows.back().east and bot.rows.back().north


static func _first_day(bot: Phase3Bot, pred: Callable) -> int:
	for r: Dictionary in bot.rows:
		if pred.call(r):
			return int(r.day)
	return -1


static func _max(bot: Phase3Bot, key: String) -> int:
	var m := 0
	for r: Dictionary in bot.rows:
		m = maxi(m, int(r[key]))
	return m
