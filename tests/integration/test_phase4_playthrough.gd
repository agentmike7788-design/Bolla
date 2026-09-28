extends TestCase
## W3 QA playthrough bot of Phase 4 (docs/PHASE4_DESIGN.md §10, §1.3, §2.7, §2.11, §2.15):
## Phase4Bot plays 24–28 in-game days of the real graveyard world from a new game under the
## moral strategies. Asserts: no engine errors and no warnings, value ranges (quality, reputation,
## piety, coins), no bot problems (every action the strategy wants is possible – no softlock),
## the chapter six_pits for every strategy (harvester slower but not blocked), all five main
## insights and „Andächtig“ for the reverent player, „Hartherzig“ for the harvester, lost finds
## / stench / key fallback for the procrastinator, save/load every morning = reverent.
## The per-day numbers are printed ("PLAYTHROUGH4 <strategy>") for
## docs/reviews/phase4_wip/qa_playthrough.md.

const TIMEOUT := 600.0

## Rows of the reverent run (save_load4 must match them).
static var reverent_rows: Array[Dictionary] = []

var saves_dir := TestCase.user_dir("test_saves_p4_bot")
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


func test_reverent() -> void:
	var bot := await _play(&"reverent", 24)
	var last: Dictionary = bot.rows.back()
	assert_true(bot.chapter_day > 0 and bot.chapter_day <= 22, "reverent: chapter six_pits by day 22 (%d)" % bot.chapter_day)
	assert_eq(bot.journal.insights().filter(func(i: StringName) -> bool: return i != &"i_kranich").size(), 5,
			"all 5 main insights (%s)" % str(bot.journal.insights()))
	assert_eq(last.piety_tier, &"devout", "„Andächtig“ (%d)" % last.piety)
	assert_eq(last.utilized, 0, "never harvested")
	assert_true(last.prepared >= 12, "prepared %d" % last.prepared)
	reverent_rows = bot.rows.duplicate(true)


func test_harvester() -> void:
	var bot := await _play(&"harvester", 28)
	var last: Dictionary = bot.rows.back()
	assert_true(bot.chapter_day > 0 and bot.chapter_day <= 28, "harvester: chapter six_pits by day 28 (%d)" % bot.chapter_day)
	assert_true(last.piety <= -60, "„Hartherzig“ (%d)" % last.piety)
	assert_true(last.utilized >= 20, "harvested %d" % last.utilized)
	assert_true(bot.ilse_income > 0, "sold at the wall")


func test_procrastinator() -> void:
	var bot := await _play(&"procrastinator", 28)
	var last: Dictionary = bot.rows.back()
	assert_true(last.lost >= 3, "lost finds %d" % last.lost)
	assert_true(bot.stench_events >= 1, "stench at the gate")
	assert_true(bot.key_fallback, "the key fallback on day 12")
	assert_true(bot.chapter_day > 0, "procrastinator: chapter six_pits reached (%d)" % bot.chapter_day)


func test_mixed() -> void:
	var bot := await _play(&"mixed", 24)
	var last: Dictionary = bot.rows.back()
	assert_has([&"matter_of_fact", &"callous"], last.piety_tier, "mixed: „Sachlich“ or „Abgebrüht“ (%d)" % last.piety)
	assert_true(last.utilized > 0 and last.utilized <= 12, "hair on odd days only (%d)" % last.utilized)
	assert_true(bot.chapter_day > 0, "mixed: chapter six_pits (%d)" % bot.chapter_day)


func test_save_load_every_morning_matches_reverent() -> void:
	var bot := await _play(&"save_load4", 24)
	assert_true(bot.chapter_day > 0, "chapter six_pits with a reload every morning")
	if reverent_rows.is_empty():
		return  # run alone (filter): nothing to compare with
	assert_eq(bot.rows.size(), reverent_rows.size())
	for i: int in mini(bot.rows.size(), reverent_rows.size()):
		assert_eq(bot.rows[i], reverent_rows[i], "day %d identical to reverent" % (i + 1))


# --- helpers ----------------------------------------------------------------------------------

func _play(strategy: StringName, days: int) -> Phase4Bot:
	var bot := Phase4Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	var coins_in := {"n": 0}
	var on_pay := func(n: int, _reason: String) -> void: coins_in.n += n
	EventBus.payment_received.connect(on_pay)
	for i: int in days:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.quality >= 0 and r.quality <= 270, "%s day %d: quality %d in range" % [strategy, r.day, r.quality])
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d in range" % [strategy, r.day, r.rep])
		assert_true(r.piety >= -100 and r.piety <= 100, "%s day %d: piety %d in range" % [strategy, r.day, r.piety])
		assert_true(r.coins >= 0, "%s day %d: coins %d" % [strategy, r.day, r.coins])
	EventBus.payment_received.disconnect(on_pay)
	bot.unwatch()
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	print("PLAYTHROUGH4 %s  chapter day %d  spent(Osric) %d  gifts %d  income %d (burials %d / %d = %.1f, stipend %d)  ilse +%d/−%d  valuables %d  stench %d  key_fallback %s  stories %s"
			% [strategy, bot.chapter_day, bot.spent, bot.gifts, coins_in.n, bot.burial_income, bot.burials_paid,
			float(bot.burial_income) / maxf(1.0, float(bot.burials_paid)), bot.stipend_income, bot.ilse_income, bot.ilse_spent,
			bot.valuables_income, bot.stench_events, bot.key_fallback, str(bot.arrived_stories)])
	print(bot.table_p4())
	return bot
