extends TestCase
## W3 QA playthrough bot of Phase 5 (docs/PHASE5_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5,
## §2.8): Phase5Bot plays the Phase-5 arc on the real graveyard world – from the Phase-4 end states
## (v3 fixtures day20_reverent / day20_mixed / day25_harvester) for 10 days and from a new game
## for 30 days (crafter). Asserts: no engine errors and no warnings, value ranges, no bot problems
## (every action the strategy wants is possible – no softlock), the chapter names_in_stone for
## every strategy, the coin ledger (income by source, spending by purpose = the stats, start +
## income − spending = end) against the §2.8 calculation, the strategy expectations of §10 and
## save/load every morning = reverent5. The per-day numbers are printed ("PLAYTHROUGH5 <strategy>")
## for docs/reviews/phase5_wip/qa_playthrough.md.

const TIMEOUT := 900.0
const SLOT := 91

## Rows of the reverent5 run (save_load5 must match them).
static var reverent_rows: Array[Dictionary] = []

var saves_dir := TestCase.user_dir("test_saves_p5_bot")
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


## §1.4 arc A / §2.8: chapter ≤ day 28, Phase-5 spending ≥ 100, end 10–45, morning never < 10
## (the user: "never below ≈ 15"), ≥ 6 graves set anew, 3 gilded stones.
func test_reverent5() -> void:
	var bot := await _play_fixture(&"reverent5", "slot_p4_day20_reverent", 10)
	if bot == null:
		return
	var end := bot.inv().count(&"coin")
	assert_true(bot.chapter5_day > 0 and bot.chapter5_day <= 28, "reverent5: chapter by day 28 (%d)" % bot.chapter5_day)
	assert_true(bot.spent_p5 >= 100, "Phase-5 spending ≥ 100 (%d)" % bot.spent_p5)
	assert_true(end >= 10 and end <= 45, "end 10–45 (%d)" % end)
	assert_true(bot.lowest_morning_p5 >= 10, "morning never below 10 (%d)" % bot.lowest_morning_p5)
	# §2.8 / the user: most of the surplus spent, never poor (≈ 15).
	var available := bot.start_coins + bot.total_income()
	assert_true(bot.spent_p5 * 100 >= 75 * available, "most of the surplus spent (%d of %d)" % [bot.spent_p5, available])
	assert_true(bot.lowest_morning_p5 >= 15, "never below ≈ 15 in the morning (%d)" % bot.lowest_morning_p5)
	assert_true(bot.stones_set.size() >= 6, "≥ 6 graves set anew (%d)" % bot.stones_set.size())
	assert_eq(bot.gilded, 3, "gold for 3 stones")
	reverent_rows = bot.rows.duplicate(true)


## All tools on tier 2 by day 25; measured minutes = the §2.3 table; chapter ≤ day 29.
func test_toolsmith() -> void:
	var bot := await _play_fixture(&"toolsmith", "slot_p4_day20_reverent", 10)
	if bot == null:
		return
	for kind: String in ["shovel", "axe", "pickaxe"]:
		var day := int(bot.tier_days.get(kind + "2", 99))
		assert_true(day <= 25, "toolsmith: %s tier 2 by day 25 (%d)" % [kind, day])
	assert_true(bot.chapter5_day > 0 and bot.chapter5_day <= 29, "toolsmith: chapter by day 29 (%d)" % bot.chapter5_day)
	assert_true(bot.inv().count(&"coin") >= 0)
	# §2.3: alder 50 / 35, boulder 50 (/ 35), rubble 25 / 20, ore 30 / 25, workstone 25, clay 30 / 25 / 20.
	var table := {"alder@1": 50, "alder@2": 35, "boulder@1": 50, "rubble_face@1": 25, "rubble_face@2": 20,
			"ore_vein@1": 30, "ore_vein@2": 25, "workstone_ledge@2": 25, "clay_pit@0": 30, "clay_pit@1": 25, "clay_pit@2": 20}
	var checked := 0
	for key: String in table:
		if bot.action_minutes.has(key):
			checked += 1
			assert_eq(int(bot.action_minutes[key]), int(table[key]), "§2.3 minutes %s" % key)
	assert_true(checked >= 6, "measured %d actions of the table (%s)" % [checked, str(bot.action_minutes)])
	print("PLAYTHROUGH5 toolsmith minutes %s · tier days %s" % [str(bot.action_minutes), str(bot.tier_days)])


## Master stones first for robbed graves: content ghosts +≥ 3, no fully robbed ghost content.
func test_mender() -> void:
	var bot := await _play_fixture(&"mender", "slot_p4_day20_mixed", 10)
	if bot == null:
		return
	assert_true(bot.chapter5_day > 0, "mender: chapter (%d)" % bot.chapter5_day)
	var last: Dictionary = bot.rows.back()
	assert_true(int(last.content) - bot.content_start >= 3, "content ghosts +≥ 3 (%d → %d)" % [bot.content_start, last.content])
	_assert_fully_robbed_not_content(bot)


## Mandatory only, no gold: chapter; end ≥ 60 (a finding, no failure: printed); fully robbed
## ghosts stay restless.
func test_harvester5() -> void:
	var bot := await _play_fixture(&"harvester5", "slot_p4_day25_harvester", 10)
	if bot == null:
		return
	assert_true(bot.chapter5_day > 0, "harvester5: chapter (%d)" % bot.chapter5_day)
	assert_eq(bot.gilded, 0, "no gold")
	_assert_fully_robbed_not_content(bot)
	print("PLAYTHROUGH5 harvester5 end %d coins (§2.8 expects ≈ 70–80, ≥ 60)" % bot.inv().count(&"coin"))


## New game, 30 days: six_pits ≤ day 22 (unchanged), names_in_stone ≤ day 30, Phase-5 spending
## ≥ 100, end 15–80, ≥ 4 gowns from the loom.
func test_crafter() -> void:
	if not _selected(&"crafter"):
		return
	await SaveManager.new_game()
	var bot := await _play(&"crafter", 30)
	assert_true(bot.chapter_day > 0 and bot.chapter_day <= 22, "crafter: six_pits by day 22 (%d)" % bot.chapter_day)
	assert_true(bot.chapter5_day > 0 and bot.chapter5_day <= 30, "crafter: names_in_stone by day 30 (%d)" % bot.chapter5_day)
	assert_true(bot.spent_p5 >= 100, "Phase-5 spending ≥ 100 (%d)" % bot.spent_p5)
	var end := bot.inv().count(&"coin")
	assert_true(end >= 15 and end <= 80, "end 15–80 (%d)" % end)
	assert_true(bot.loom_gowns >= 4, "≥ 4 gowns from the loom (%d)" % bot.loom_gowns)
	assert_true(bot.lowest_morning_p5 >= 10, "Phase 5: morning never below 10 (%d)" % bot.lowest_morning_p5)


func test_save_load5_matches_reverent5() -> void:
	var bot := await _play_fixture(&"save_load5", "slot_p4_day20_reverent", 10)
	if bot == null:
		return
	assert_true(bot.chapter5_day > 0, "chapter with a reload every morning")
	if reverent_rows.is_empty():
		return  # run alone (filter): nothing to compare with
	assert_eq(bot.rows.size(), reverent_rows.size())
	for i: int in mini(bot.rows.size(), reverent_rows.size()):
		assert_eq(bot.rows[i], reverent_rows[i], "day %d identical to reverent5" % bot.rows[i].day)


# --- helpers ----------------------------------------------------------------------------------

## Env P5QA_ONLY=<strategy,…> runs only those strategies (the runner filters by file only).
static func _selected(strategy: StringName) -> bool:
	var only := OS.get_environment("P5QA_ONLY")
	return only == "" or String(strategy) in only.split(",")


func _play_fixture(strategy: StringName, fixture: String, days: int) -> Phase5Bot:
	if not _selected(strategy):
		return null
	assert_eq(Phase5Fixtures.install_save_v3(fixture, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, fixture + " loads")
	if err != OK:
		return null
	# The fixtures were saved at 07:00; the bot's day starts from there.
	return await _play(strategy, days)


func _play(strategy: StringName, days: int) -> Phase5Bot:
	var bot := Phase5Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in days:
		await bot.run_day()
		var r: Dictionary = bot.rows.back() if not bot.rows.is_empty() else {}
		assert_false(r.is_empty(), "%s: day %d recorded" % [strategy, i + 1])
		if r.is_empty():
			break
		assert_true(r.quality >= 0 and r.quality <= 380, "%s day %d: quality %d in range" % [strategy, r.day, r.quality])
		assert_true(r.rep >= 0 and r.rep <= 100, "%s day %d: reputation %d in range" % [strategy, r.day, r.rep])
		assert_true(r.piety >= -100 and r.piety <= 100, "%s day %d: piety %d in range" % [strategy, r.day, r.piety])
		assert_true(r.coins >= 0, "%s day %d: coins %d" % [strategy, r.day, r.coins])
	bot.unwatch()
	bot.income.valuables = bot.valuables_income
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	# Ledger: the spending by purpose is what GameState booked; start + income − spending = end.
	var ledger := GameState.coin_ledger()
	for reason: Variant in bot.spent_by:
		assert_true(ledger.has(StringName(str(reason))), "%s: ledger knows %s" % [strategy, reason])
	var booked := 0
	for reason: StringName in ledger:
		booked += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), booked, "%s: stats.coins_spent = sum of the ledger" % strategy)
	assert_eq(bot.start_coins + bot.total_income() - bot.total_spent(), bot.inv().count(&"coin"),
			"%s: start + income − spending = end (%s)" % [strategy, bot.ledger_text()])
	print("PLAYTHROUGH5 %s  chapter5 day %d (open day %d, six_pits day %d)  %s  gathered %s  stones %d (gilded %d)  loom gowns %d  tier days %s"
			% [strategy, bot.chapter5_day, bot.open_day, bot.chapter_day, bot.ledger_text(), str(bot.gathered),
			bot.stones_set.size(), bot.gilded, bot.loom_gowns, str(bot.tier_days)])
	print(bot.table_p5())
	for line: String in bot.loom_trace:
		print("LOOM5 ", line)
	for r: Dictionary in bot.rows:
		print("STOCK5 %s day %d: %s, loom gowns %d" % [strategy, r.day, r.get("stock", ""), int(r.get("loom_gowns", 0))])
	return bot


## No ghost of a grave whose corpse lost hair and teeth is content (§2.5: a stone does not give
## back what was taken).
func _assert_fully_robbed_not_content(bot: Phase5Bot) -> void:
	var robbed := 0
	for g: GraveRecord in bot.graveyard.graves():
		var c := bot.manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if c == null or not (c.is_harvested(CorpseRecord.HARVEST_HAIR) and c.is_harvested(CorpseRecord.HARVEST_TEETH)):
			continue
		robbed += 1
		assert_ne(bot.ghosts.mood_of(g.id), GhostMood.CONTENT, "fully robbed %s is not content (%s)" % [g.id, g.marker_id])
	print("PLAYTHROUGH5 %s: %d fully robbed graves checked" % [bot.strategy, robbed])
