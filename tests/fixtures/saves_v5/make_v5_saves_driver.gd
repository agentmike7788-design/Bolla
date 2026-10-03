extends RefCounted
## Driver of make_v5_saves.gd (loaded after the autoloads exist). See there.
## The Phase-6 end states continue the v4 fixtures (tests/fixtures/saves_v4) with Phase6Bot exactly
## like test_phase6_playthrough.gd (reverent6 / harvester6 10 days, mender6 11 days); the founder
## plays a new game for 36 days. The special states are captured inside a bot day the first time
## the situation arises (docs/PHASE7_DESIGN.md §5.2 "Fixtures").

const SLOT_DAY40_REVERENT := 51
const SLOT_DAY45_HARVESTER := 52
const SLOT_DAY41_MENDER := 53
const SLOT_DAY37_FOUNDER := 54
const SLOT_DAY37_EVE := 55
const SLOT_CRYPT_TABLE := 56
const SLOT_CHAPEL_CARRY := 57
const SLOT_V4 := 58


## Phase6Bot that stops on the evening of the roof_and_earth chapter (day37_eve) or saves the
## first time a corpse lies on the crypt table (crypt_table) / is carried into the chapel
## (chapel_carry).
class CaptureBot extends Phase6Bot:
	var mode: StringName = &""
	var captured: bool = false
	var save_cb: Callable

	func _sleep() -> void:
		if mode == &"eve" and not captured and GameState.has_flag(&"roof_and_earth_complete"):
			_to_room(&"")
			_wait_until(20 * 60)
			captured = true
			return
		await super._sleep()

	func _work_at_table(record: CorpseRecord, table: MorgueTable) -> void:
		if mode == &"crypt" and not captured and crypt_level() >= 1 and record.location == CorpseRecord.LOCATION_TABLE \
				and record.room == &"crypt" and not record.examined and record.harvested.is_empty():
			table.interact(player)
			UIState.clear()
			for step: StringName in [CorpseRecord.STEP_CLOTHING, CorpseRecord.STEP_HANDS]:
				table.request_exam_step(step)
			var reason := care.harvest_block_reason(record.id, &"hair", inv())
			if reason == "":
				table.request_harvest(&"hair")
			UIState.clear()
			var steps := 0
			for step: StringName in CorpseRecord.STEPS:
				if record.is_step_done(step):
					steps += 1
			var cw := record.cold_windows
			var open := cw.size() >= 3 and cw[cw.size() - 2] == -1
			print("crypt_table: %s steps %d hair %s (%s) cold %s interior %s" % [record.id, steps, record.is_harvested(&"hair"),
					reason, str(cw), player.interior_id])
			if steps == 2 and record.is_harvested(&"hair") and open and player.interior_id == &"crypt":
				captured = save_cb.call()
		super._work_at_table(record, table)

	func _to_room(id: StringName) -> bool:
		var ok := super._to_room(id)
		if mode == &"chapel" and not captured and ok and id == &"chapel" and player.carried_id != "":
			var record := manager.get_record(player.carried_id)
			print("chapel_carry: %s %s interior %s" % [record.id, record.location, player.interior_id])
			if record.location == CorpseRecord.LOCATION_CARRIED:
				captured = save_cb.call()
		return ok


var out_dir: String = ""
var tree: SceneTree
var bot: Phase6Bot
var only: PackedStringArray = []


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	SaveManager.save_dir = out_dir
	var ok := true
	if _wanted("day40r"):
		ok = await _make_end(&"reverent6", "slot_p5_day30_reverent", SLOT_DAY40_REVERENT, "slot_p6_day40_reverent", 10, 40) and ok
	if _wanted("day45h"):
		ok = await _make_end(&"harvester6", "slot_p5_day35_harvester", SLOT_DAY45_HARVESTER, "slot_p6_day45_harvester", 10, 45) and ok
	if _wanted("day41m"):
		ok = await _make_end(&"mender6", "slot_p5_day30_mender", SLOT_DAY41_MENDER, "slot_p6_day41_mender", 11, 41) and ok
	if _wanted("day37f"):
		ok = await _make_founder() and ok
	if _wanted("day37eve"):
		ok = await _make_capture(&"eve", &"reverent6", "slot_p5_day30_reverent", SLOT_DAY37_EVE, "slot_p6_day37_eve") and ok
	if _wanted("crypt"):
		ok = await _make_capture(&"crypt", &"harvester6", "slot_p5_day35_harvester", SLOT_CRYPT_TABLE, "slot_p6_crypt_table") and ok
	if _wanted("chapel"):
		ok = await _make_capture(&"chapel", &"reverent6", "slot_p5_day30_reverent", SLOT_CHAPEL_CARRY, "slot_p6_chapel_carry") and ok
	return ok


func _wanted(key: String) -> bool:
	return only.is_empty() or only.has(key)


func _load_v4(v4_fixture: String) -> bool:
	if Phase6Fixtures.install_save_v4(v4_fixture, out_dir, SLOT_V4) != OK:
		return false
	var err: Error = await SaveManager.load_game(SLOT_V4)
	DirAccess.remove_absolute(SaveFileIO.slot_path(out_dir, SLOT_V4))
	if err != OK:
		printerr("%s does not load" % v4_fixture)
		return false
	return true


## A Phase-6 end state: the v4 fixture + n bot days, then 07:00 of the next day.
func _make_end(strategy: StringName, v4_fixture: String, slot: int, name: String, days: int, day: int) -> bool:
	if not await _load_v4(v4_fixture):
		return false
	bot = Phase6Bot.new(strategy, tree)
	bot.bind()
	await _play_days(days)
	_morning()
	var ok := GameState.has_flag(&"roof_and_earth_complete") and TimeManager.day == day
	_report(name, ok)
	return _save(slot, name, ok)


## founder: a new game for 36 days (roof_and_earth ≤ day 36), then 07:00 of day 37.
func _make_founder() -> bool:
	await SaveManager.new_game()
	bot = Phase6Bot.new(&"founder", tree)
	bot.flags = bot.flags.duplicate(true)
	bot.bind()
	await _play_days(36)
	_morning()
	var ok := GameState.has_flag(&"roof_and_earth_complete") and TimeManager.day == 37
	print("day37_founder: chapters %d / %d / %d" % [bot.chapter_day, bot.chapter5_day, bot.chapter6_day])
	_report("slot_p6_day37_founder", ok)
	return _save(SLOT_DAY37_FOUNDER, "slot_p6_day37_founder", ok)


## A state captured inside a bot day (see CaptureBot); at most 14 days.
func _make_capture(mode: StringName, strategy: StringName, v4_fixture: String, slot: int, name: String) -> bool:
	if not await _load_v4(v4_fixture):
		return false
	var cb := CaptureBot.new(strategy, tree)
	cb.mode = mode
	bot = cb
	bot.bind()
	var saved := [false]
	cb.save_cb = func() -> bool:
		UIState.clear()
		var ok := _check_capture(mode)
		_report(name, ok)
		saved[0] = _save(slot, name, ok)
		return saved[0]
	for i: int in 14:
		await bot.run_day()
		if cb.captured:
			break
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)
	if mode == &"eve" and cb.captured:
		UIState.clear()
		var ok := _check_capture(mode)
		_report(name, ok)
		saved[0] = _save(slot, name, ok)
	if not cb.captured or not saved[0]:
		printerr("%s: not captured" % name)
	return cb.captured and saved[0]


func _check_capture(mode: StringName) -> bool:
	match mode:
		&"eve":
			return GameState.has_flag(&"roof_and_earth_complete") and TimeManager.minute_of_day >= 1200
		&"crypt":
			return bot.player.interior_id == &"crypt"
		&"chapel":
			return bot.player.interior_id == &"chapel" and bot.player.carried_id != ""
	return false


func _morning() -> void:
	bot._to_room(&"")
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()


func _play_days(n: int) -> void:
	for i: int in n:
		await bot.run_day()
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)


func _marked() -> int:
	var n := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			n += 1
	return n


func _report(name: String, ok: bool) -> void:
	var old := 0
	var free := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == GraveRecord.State.OLD:
			old += 1
		elif g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG:
			free += 1
	print("%s: ok=%s day %d %s problems=%s rep=%d coins=%d piety=%d marked=%d old=%d free=%d levels=%s reinterred=%d chapter6=%d" % [
			name, ok, TimeManager.day, TimeManager.format_clock(), bot.problems, GameState.get_stat(&"reputation"),
			bot.inv().count(&"coin"), bot.piety.value(), _marked(), old, free, str(bot.buildings.levels()),
			bot.ossuary.reinterred().size(), bot.chapter6_day])


func _save(slot: int, name: String, ok: bool) -> bool:
	if not ok:
		printerr("fixture '%s': unexpected state" % name)
		return false
	if SaveManager.save_game(slot) != OK:
		printerr("fixture '%s': save failed" % name)
		return false
	var dst := out_dir.path_join(name + ".json")
	DirAccess.remove_absolute(dst)
	var err := DirAccess.rename_absolute(SaveFileIO.slot_path(out_dir, slot), dst)
	print("wrote ", dst, " day ", TimeManager.day, " ", TimeManager.format_clock())
	return err == OK
