extends TestCase
## G8 Runde 6 „Bitten vom Hügel" – the bot measurement of days 1–14 (docs/reviews/phase8_round6/bitten.md): HillBot
## plays the real world from a new game without and with the requests, once as the „duty" player of the user's
## criticism (only the corpses and their graves) and once as Phase4Bot's reverent player. Printed per day: the end of
## the daytime work, the idle time until 18:00, requests done, their coins ("HILLBOT <strategy>"). Asserted: no bot
## problems and no warnings; the duty player's idle on days 2–12 shrinks with the requests; the requests pay little
## (≤ 3 coins a day on average, ≤ 45 over the two weeks, the reputation from them ≤ 30) – the coin goals of the bot
## tests (Phase 3/4: ≈ 11 per grave, coins never negative) keep, because no other bot accepts a request.

const TIMEOUT := 900.0
const DAYS := 14

static var idle_before: Dictionary = {}

var saves_dir := TestCase.user_dir("test_saves_hill_bot")
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


func test_a_duty_player_without_requests() -> void:
	var bot := await _play(&"duty")
	idle_before[&"duty"] = _idle(bot)
	assert_eq(bot.hill_done, 0, "nothing accepted, nothing done")


func test_b_duty_player_with_requests() -> void:
	var bot := await _play(&"duty_requests")
	var idle := _idle(bot)
	assert_true(bot.hill_done >= 6, "requests done over two weeks (%d)" % bot.hill_done)
	assert_true(bot.hill_coins <= 45, "a few coins (%d)" % bot.hill_coins)
	assert_true(float(bot.hill_coins) / float(DAYS - 1) <= 3.0, "≤ 3 coins a day on average")
	assert_true(bot.hill_rep <= 30, "a little reputation (%d)" % bot.hill_rep)
	if idle_before.has(&"duty"):
		assert_true(idle < int(idle_before[&"duty"]), "idle on days 2–12 shrinks (%d → %d min)" % [int(idle_before[&"duty"]), idle])
	print("HILLBOT idle days 2–12: duty %s min → with requests %d min" % [str(idle_before.get(&"duty", "?")), idle])


func test_c_reverent_without_requests() -> void:
	var bot := await _play(&"reverent")
	idle_before[&"reverent"] = _idle(bot)


func test_d_reverent_with_requests() -> void:
	var bot := await _play(&"reverent_requests")
	assert_true(bot.hill_done >= 6, "requests done (%d)" % bot.hill_done)
	assert_true(bot.hill_coins <= 45, "a few coins (%d)" % bot.hill_coins)
	print("HILLBOT idle days 2–12: reverent %s min → with requests %d min" % [str(idle_before.get(&"reverent", "?")), _idle(bot)])


## Idle minutes of days 2–12 (sum).
func _idle(bot: HillBot) -> int:
	var n := 0
	for r: Dictionary in bot.rows:
		if int(r.day) >= 2 and int(r.day) <= 12:
			n += int(r.idle)
	return n


func _play(strategy: StringName) -> HillBot:
	var bot := HillBot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in DAYS:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.coins >= 0, "%s day %d: coins %d" % [strategy, r.day, r.coins])
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d" % [strategy, r.day, r.rep])
	bot.unwatch()
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings" % strategy)
	print("HILLBOT %s  requests done %d failed %d  coins from requests %d  reputation from requests %+d  request work %d min  coins day %d: %d"
			% [strategy, bot.hill_done, bot.hill_failed, bot.hill_coins, bot.hill_rep, bot.hill_minutes, DAYS, int(bot.rows.back().coins)])
	print(bot.table_hill())
	return bot
