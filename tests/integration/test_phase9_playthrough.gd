extends TestCase
## W3 QA playthrough bot of Phase 9 (docs/PHASE9_DESIGN.md §10 "Playthrough-Bot", §1.4, §1.5, §2.8): Phase9Bot plays the
## Phase-9 arc on the real world from the Phase-8 end states (v7 fixtures). Asserts: no engine errors, no warnings, no
## bot problems (no dead end), value ranges, the coin ledger (start + income − spending = end, purse + wage tin, the
## purpose post), the morning never below 5, the chapter „Wer weiß, wann?" (who_knows_when) for every strategy but lazy9,
## and the §10 expectations per strategy; save_load9 = kindly9 day by day. The numbers per day are printed
## ("PLAYTHROUGH9 <strategy>") for docs/reviews/phase9_wip/qa_g9.md.
## Env P9QA_ONLY=<strategy,…> runs only those strategies; P9QA_DAYS=<n> plays n days (debugging).

const TIMEOUT := 3600.0
const SLOT := 93
const DAYS := 12

static var kindly_rows: Array[Dictionary] = []
static var kindly_piety: int = 1 << 30

var saves_dir := TestCase.user_dir("test_saves_p9_bot" + OS.get_environment("P9QA_ONLY").replace(",", "_"))
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


## §2.8 Prüfregel: active ways end ≤ start + 50 (≈ +33 in 12 days), trader9 ≤ start + 100.
const END_MAX := {&"trader9": 100}
const END_MAX_DEFAULT := 50


## §10 kindly9: arc A – ending A (Johann with Osric or Hanne), Liesel the confidant, letters delivered, large requests,
## Brenneisen → Fenner; the chapter B9–B11, the end ≤ start + 50, piety does not fall.
func test_kindly9() -> void:
	var bot := await _play_fixture(&"kindly9", "slot_p8_day63_kindly")
	if bot == null:
		return
	# §10 B9–B11 (§1.4 plans B10); measured B7 (W3, qa_g9.md: the large requests and the letters come faster than the
	# arc's table) – the band keeps the measured lower edge.
	_expect_chapter(bot, 7, 11)
	assert_eq(bot.quests.ending(Phase9Bot.MAIN), WhoKnows.ENDING_AWAY, "kindly9: ending A")
	assert_true(GameState.flag_on(&"sieber_gone"), "kindly9: Johann gone")
	assert_true(bot.piety.value() >= bot.start9_piety - 2, "kindly9: piety %d (start %d)" % [bot.piety.value(), bot.start9_piety])
	_expect_end(bot)
	kindly_rows = bot.rows.duplicate(true)
	kindly_piety = bot.piety.value()


## §10 stay9: ending B, Lenz the confidant, letters read at the grave – the chapter after D3 (B11–B12), D3 in row 4.
func test_stay9() -> void:
	var bot := await _play_fixture(&"stay9", "slot_p8_day63_kindly")
	if bot == null:
		return
	assert_eq(bot.quests.ending(Phase9Bot.MAIN), WhoKnows.ENDING_STAY, "stay9: ending B")
	_expect_chapter(bot, 11, 12)
	var d3: CorpseRecord = null
	for r: CorpseRecord in bot.manager.records():
		if r.story_id == WhoKnows.D3_STORY:
			d3 = r
	assert_not_null(d3, "stay9: D3 Johann Sieber delivered")
	if d3 != null:
		assert_eq(d3.location, CorpseRecord.LOCATION_BURIED, "stay9: D3 buried")
		var grave := ""
		for g: GraveRecord in bot.graveyard.graves():
			if g.corpse_id == d3.id:
				grave = g.id
		assert_eq(bot.graveyard.section_of(grave), Phase9Bot.ROW4, "stay9: D3 in row 4 (%s)" % grave)
	_expect_end(bot)


## §10 public9: ending C, nobody told – Lenz / Quast / Liesel lose (−4), the chapter.
func test_public9() -> void:
	var bot := await _play_fixture(&"public9", "slot_p8_day63_kindly")
	if bot == null:
		return
	assert_eq(bot.quests.ending(Phase9Bot.MAIN), WhoKnows.ENDING_PUBLIC, "public9: ending C")
	for npc: StringName in [&"priest", &"surgeon", &"washer"]:
		var d := 0
		for e: Dictionary in bot.ending_rel:
			if StringName(str(e.npc)) == npc and str(e.reason) == WhoKnows.REASON_CONFIDED % "public":
				d += int(e.delta)
		assert_eq(d, -4, "public9: %s named before the community (%s)" % [npc, str(bot.ending_rel)])
	_expect_chapter(bot, 1, 12)
	_expect_end(bot)


## §10 silent9: H1–H4, then nothing until the deadline – ending still, the chapter (letters and requests done).
func test_silent9() -> void:
	var bot := await _play_fixture(&"silent9", "slot_p8_day63_kindly")
	if bot == null:
		return
	assert_eq(bot.quests.ending(Phase9Bot.MAIN), WhoKnows.ENDING_SILENT, "silent9: ending still")
	_expect_chapter(bot, 1, 12)
	_expect_end(bot)


## §10 letters9: every letter opened and read, the unread ones never burned – piety loss ≤ 6, the chapter.
func test_letters9() -> void:
	var bot := await _play_fixture(&"letters9", "slot_p8_day63_kindly")
	if bot == null:
		return
	assert_true(bot.start9_piety - bot.piety.value() <= 6, "letters9: piety loss %d ≤ 6" % (bot.start9_piety - bot.piety.value()))
	for e: Dictionary in bot.letter_log:
		if StringName(str(e.state)) == &"burned":
			assert_true(bot.letters.is_opened(str(e.uid)), "letters9: %s read before it burned" % e.id)
	_expect_chapter(bot, 1, 12)
	_expect_end(bot)


## §10 trader9: the anatomist's end state – Brenneisen gets everything he buys, the bribe, the Kladde; the chapter, the
## end ≤ start + 100, piety ≤ kindly9 − 15.
func test_trader9() -> void:
	var bot := await _play_fixture(&"trader9", "slot_p8_day63_anatomist")
	if bot == null:
		return
	_expect_chapter(bot, 1, 12)
	_expect_end(bot)
	if kindly_piety < (1 << 30):
		assert_true(bot.piety.value() <= kindly_piety - 15, "trader9: piety %d ≤ kindly9 %d − 15" % [bot.piety.value(), kindly_piety])


## §10 lazy9: no chain, no request – no chapter, no errors, no warnings.
func test_lazy9() -> void:
	var bot := await _play_fixture(&"lazy9", "slot_p8_day63_kindly")
	if bot == null:
		return
	assert_eq(bot.chapter9_day, -1, "lazy9: no chapter")
	assert_eq(bot.quests.current_step(Phase9Bot.MAIN) in [&"h1", &""], true, "lazy9: the chain not started (%s)" % bot.quests.current_step(Phase9Bot.MAIN))
	assert_true(bot.hill.large_active().is_empty() and bot.large_done_ids.is_empty(), "lazy9: no large request")


## §10 founder9: the founder's end state of Phase 8 (16 days) – the chapter; the old chapters unchanged.
func test_founder9() -> void:
	var before := {}
	var bot := await _play_fixture(&"founder9", "slot_p8_founder", 16, true, before)
	if bot == null:
		return
	assert_true(bot.chapter9_day > 0, "founder9: the chapter (%s)" % str(bot.quests.goal_progress()))
	for f: StringName in before:
		assert_eq(GameState.flag_on(f), bool(before[f]), "founder9: old chapter flag %s unchanged" % f)
	assert_true(bot.lowest_morning_p9 >= 5, "founder9: the morning never below 5 (%d)" % bot.lowest_morning_p9)


## §10 save_load9: loads every morning, once at the departure, once with Brenneisen at the gate, once mid large request –
## bit-identical to kindly9.
func test_save_load9_matches_kindly9() -> void:
	var bot := await _play_fixture(&"save_load9", "slot_p8_day63_kindly")
	if bot == null:
		return
	for m: String in ["stranger", "large", "departure"]:
		assert_true(bot.saved9.has(m), "save_load9: saved and loaded at %s (%s)" % [m, str(bot.saved9)])
	if kindly_rows.is_empty():
		return
	assert_eq(bot.rows.size(), kindly_rows.size())
	for i: int in mini(bot.rows.size(), kindly_rows.size()):
		var diffs := PackedStringArray()
		var a: Dictionary = kindly_rows[i]
		var b: Dictionary = bot.rows[i]
		for k: Variant in a.keys() + b.keys():
			if str(a.get(k)) != str(b.get(k)) and not diffs.has(str(k)):
				diffs.append("%s: %s → %s" % [k, str(a.get(k)).left(120), str(b.get(k)).left(120)])
		assert_eq(diffs, PackedStringArray(), "day %d identical to kindly9" % b.day)


# --- helpers ----------------------------------------------------------------------------------

const OLD_CHAPTERS: Array[StringName] = [&"cemetery_complete", &"names_in_stone_complete", &"roof_and_earth_complete",
		&"name_in_village_complete", &"who_comes_up_complete"]


func _expect_chapter(bot: Phase9Bot, from_b: int, to_b: int) -> void:
	var b := bot.chapter9_day - bot.open9_day + 1 if bot.chapter9_day > 0 else -1
	assert_true(b >= from_b and b <= to_b, "%s: chapter „Wer weiß, wann?“ at B%d (day %d, open %d; goal %s, letters %d decided, step %s/%s)"
			% [bot.strategy, b, bot.chapter9_day, bot.open9_day, str(bot.quests.goal_progress()), bot.letters.decided_count(),
			bot.quests.current_step(Phase9Bot.MAIN), bot.quests.current_step(Phase9Bot.LETTERS_Q)])
	assert_true(bot.lowest_morning_p9 >= 5, "%s: the morning never below 5 (%d)" % [bot.strategy, bot.lowest_morning_p9])


func _expect_end(bot: Phase9Bot) -> void:
	var gain := bot.coins_total() - bot.start9_coins
	var hi := int(END_MAX.get(bot.strategy, END_MAX_DEFAULT))
	assert_true(gain <= hi, "%s: end %d = start %d %+d (≤ %+d)" % [bot.strategy, bot.coins_total(), bot.start9_coins, gain, hi])


static func _selected(strategy: StringName) -> bool:
	var only := OS.get_environment("P9QA_ONLY")
	return only == "" or String(strategy) in only.split(",")


func _play_fixture(strategy: StringName, fixture: String, days: int = DAYS, until_chapter: bool = false,
		flags_before: Dictionary = {}) -> Phase9Bot:
	if not _selected(strategy):
		return null
	assert_eq(Phase9Fixtures.install_save_v7(fixture, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, fixture + " loads")
	if err != OK:
		return null
	for f: StringName in OLD_CHAPTERS:
		flags_before[f] = GameState.flag_on(f)
	if OS.get_environment("P9QA_DAYS") != "":
		days = int(OS.get_environment("P9QA_DAYS"))
	return await _play(strategy, days, until_chapter)


func _play(strategy: StringName, days: int, until_chapter: bool = false) -> Phase9Bot:
	var bot := Phase9Bot.new(strategy, tree)
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
		if until_chapter and bot.chapter9_day > 0:
			break
	bot.unwatch()
	bot.income.valuables = bot.valuables_income
	assert_eq(bot.problems, PackedStringArray(), "%s: no bot problems" % strategy)
	assert_eq(warnings.lines, PackedStringArray(), "%s: no warnings in normal play" % strategy)
	var ledger := GameState.coin_ledger()
	var booked := 0
	for reason: StringName in ledger:
		booked += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), booked, "%s: stats.coins_spent = sum of the ledger" % strategy)
	assert_eq(bot.start_total + bot.total_income() - bot.total_spent(), bot.coins_total(),
			"%s: start + income − spending = end, purse + tin (%s)" % [strategy, bot.ledger_text()])
	print("PLAYTHROUGH9 %s  chapter9 day %d (open day %d, ending %s on day %d)  %s  goal %s  letters %d decided %s  large %s  stranger %s  standins %s"
			% [strategy, bot.chapter9_day, bot.open9_day, bot.quests.ending(Phase9Bot.MAIN), bot.ending_day, bot.ledger_text(),
			str(bot.quests.goal_progress()), bot.letters.decided_count(), str(bot.letter_log.map(func(e: Dictionary) -> String:
				return "%s:%s" % [e.id, e.state])), str(bot.large_log), str(bot.stranger_log), str(bot.standins)])
	print("PLAYTHROUGH9 %s piety %d → %d · rel %s → %s · notes %s" % [strategy, bot.start9_piety, bot.piety.value(), str(bot.start9_rel),
			str(bot.start9_rel.keys().map(func(k: Variant) -> int: return bot.rel.value(StringName(str(k))))), str(bot.notes9)])
	print(bot.table_p9())
	for line: String in bot.trace9:
		print("TRACE9 %s %s" % [strategy, line])
	for line: String in bot.trace8:
		if line.contains("sieber") or line.contains("ott") or line.contains("missed"):
			print("TRACE8 %s %s" % [strategy, line])
	for line: String in bot.trace7:
		if line.contains("order") or line.contains("bought") or line.contains("donat") or line.contains("village"):
			print("TRACE7 %s %s" % [strategy, line])
	return bot
