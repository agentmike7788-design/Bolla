extends TestCase
## W3 QA playthrough bot of Phase 7 (docs/PHASE7_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5, §2.10):
## Phase7Bot plays the Phase-7 arc on the real world from the Phase-6 end state (v5 fixture
## slot_p6_day40_reverent, 13 days = B1…B13). Asserts: no engine errors and no warnings, value ranges,
## no bot problems (every action the strategy wants is possible – no softlock), the chapter „Ein Name
## im Dorf", the coin ledger (income by source, spending by purpose = the stats, start + income −
## spending = end) against the §2.10 calculation, the strategy expectations of §10 and – save_load7 –
## a reload every morning + once in the Holderkrug = neighbor7. The per-day numbers are printed
## ("PLAYTHROUGH7 <strategy>") for docs/reviews/phase7_wip/qa_playthrough.md.
## Env P7QA_ONLY=<strategy,…> runs only those strategies; P7QA_DAYS=<n> plays n days (debugging).

const TIMEOUT := 2400.0
const SLOT := 91
const FIXTURE := "slot_p6_day40_reverent"
const DAYS := 13

## Rows of the neighbor7 run (save_load7 must match them).
static var neighbor_rows: Array[Dictionary] = []
static var neighbor_end: int = -1

var saves_dir := TestCase.user_dir("test_saves_p7_bot")
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


## §1.4 arc A / §2.10 / §10 neighbor7: the chapter by B13 (day 52) and not before B11 (G7 Runde 2, B7-1: ≈ day 10–13
## after village_open), the end 30–110 (§2.10: ≈ 63 with chapel 3 and crypt 3), the morning never below 5 (G7 Runde 2), ≥ 6 orders (§10: 8), piety not fallen, the
## Lindenacker consecrated and open, D1 buried with its order.
func test_neighbor7() -> void:
	var bot := await _play_fixture(&"neighbor7")
	if bot == null:
		return
	var end := bot.inv().count(&"coin")
	neighbor_end = end
	assert_eq(bot.start_coins, 20, "the measured start purse (W0 note 1)")
	assert_true(bot.chapter7_day > 0 and bot.chapter7_day <= 52, "neighbor7: chapter by B13 (%d)" % bot.chapter7_day)
	assert_true(bot.chapter7_day - bot.open7_day >= 10, "neighbor7: chapter not before B11 (%d, open %d)" % [bot.chapter7_day, bot.open7_day])
	assert_true(end >= 30 and end <= 110, "end 30–110 (%d)" % end)
	assert_true(bot.lowest_morning_p7 >= 5, "morning never below 5 (%d)" % bot.lowest_morning_p7)
	assert_true(bot.orders.done_count() >= 6, "≥ 6 orders (%d)" % bot.orders.done_count())
	assert_true(GameState.get_stat(&"piety") >= 90, "piety not fallen (%d)" % GameState.get_stat(&"piety"))
	assert_eq(GameState.get_stat(&"specimens_taken"), 0, "no specimens")
	neighbor_rows = bot.rows.duplicate(true)


## §10 anatomist7: the case; heart, eyes and hand of every delivery but D1; chapter reached; the priest
## and Liesel at most „Bekannt"; the end ≤ neighbor7 + 40 (the anatomy is no dominant income, §2.10).
func test_anatomist7() -> void:
	var bot := await _play_fixture(&"anatomist7")
	if bot == null:
		return
	var end := bot.inv().count(&"coin")
	assert_true(GameState.flag_on(&"anatomy_known"), "the case accepted")
	assert_true(GameState.get_stat(&"specimens_taken") >= 9, "specimens taken (%d)" % GameState.get_stat(&"specimens_taken"))
	assert_true(bot.chapter7_day > 0, "anatomist7: chapter (%d)" % bot.chapter7_day)
	assert_true(bot.chapter7_day - bot.open7_day >= 10, "anatomist7: chapter not before B11 (%d, open %d)" % [bot.chapter7_day, bot.open7_day])
	assert_true(bot.lowest_morning_p7 >= 5, "morning never below 5 (%d)" % bot.lowest_morning_p7)
	for npc: StringName in [&"priest", &"washer"]:
		assert_true(RelationshipRules.tier_index(bot.rel.tier(npc)) <= RelationshipRules.tier_index(&"acquainted"),
				"%s at most „Bekannt“ (%s, %d)" % [npc, bot.rel.tier(npc), bot.rel.value(npc)])
	if neighbor_end >= 0:
		assert_true(end <= neighbor_end + 40, "end %d ≤ neighbor7 %d + 40" % [end, neighbor_end])
	for g: GraveRecord in bot.graveyard.graves():
		if bot.graveyard.section_of(g.id) != &"linden" or g.corpse_id == "":
			continue
		var c := bot.manager.get_record(g.corpse_id)
		if c != null and c.story_id == &"" and not c.harvested.is_empty():
			assert_ne(bot.ghosts.mood_of(g.id), GhostMood.CONTENT, "robbed %s not content" % g.id)


func test_save_load7_matches_neighbor7() -> void:
	var bot := await _play_fixture(&"save_load7")
	if bot == null:
		return
	assert_true(bot.saved_in_inn, "saved and loaded once in the Holderkrug")
	if neighbor_rows.is_empty():
		return  # run alone (filter): nothing to compare with
	assert_eq(bot.rows.size(), neighbor_rows.size())
	for i: int in mini(bot.rows.size(), neighbor_rows.size()):
		assert_eq(bot.rows[i], neighbor_rows[i], "day %d identical to neighbor7" % bot.rows[i].day)


# --- helpers ----------------------------------------------------------------------------------

static func _selected(strategy: StringName) -> bool:
	var only := OS.get_environment("P7QA_ONLY")
	return only == "" or String(strategy) in only.split(",")


func _play_fixture(strategy: StringName) -> Phase7Bot:
	if not _selected(strategy):
		return null
	assert_eq(Phase7Fixtures.install_save_v5(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	if err != OK:
		return null
	var days := int(OS.get_environment("P7QA_DAYS")) if OS.get_environment("P7QA_DAYS") != "" else DAYS
	return await _play(strategy, days)


func _play(strategy: StringName, days: int) -> Phase7Bot:
	var bot := Phase7Bot.new(strategy, tree)
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
	for reason: Variant in bot.spent_by:
		assert_true(ledger.has(StringName(str(reason))), "%s: ledger knows %s" % [strategy, reason])
	var booked := 0
	for reason: StringName in ledger:
		booked += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), booked, "%s: stats.coins_spent = sum of the ledger" % strategy)
	assert_eq(bot.start_coins + bot.total_income() - bot.total_spent(), bot.inv().count(&"coin"),
			"%s: start + income − spending = end (%s)" % [strategy, bot.ledger_text()])
	if bot.chapter7_day > 0:
		var goal := bot.village.goal_progress()
		print("PLAYTHROUGH7 %s goal %s" % [strategy, str(goal)])
	print("PLAYTHROUGH7 %s  chapter7 day %d (open day %d)  %s  orders %s  village days %s  organs %d  lectures %s  levels %s"
			% [strategy, bot.chapter7_day, bot.open7_day, bot.ledger_text(), str(bot.orders_done.map(func(o: Dictionary) -> String: return "%s@%d" % [o.id, o.day])),
			str(bot.village_days), bot.organs_taken.size(), str(bot.lectures_held), str(bot.buildings.levels())])
	print(bot.table_p7())
	for line: String in bot.trace7:
		print("TRACE7 %s %s" % [strategy, line])
	for line: String in bot.trace6:
		if line.contains("waits") or line.contains("built") or line.contains("open:"):
			print("TRACE6 %s %s" % [strategy, line])
	return bot
