extends RefCounted
## Driver of make_v6_saves.gd (loaded after the autoloads exist). See there.
## The Phase-7 end states continue the v5 fixtures (tests/fixtures/saves_v5) with Phase7Bot exactly
## like test_phase7_playthrough.gd (neighbor7 / anatomist7 13 days from slot_p6_day40_reverent); the
## founder continues slot_p6_day37_founder with founder7 (§10 of PHASE7_DESIGN: crafter + Phase 7) until
## its chapter. The special states are captured inside a bot day the first time the situation arises
## (docs/PHASE8_DESIGN.md §5.2 "Fixtures").

const SLOT_NEIGHBOR := 61
const SLOT_ANATOMIST := 62
const SLOT_EVE := 63
const SLOT_FOUNDER := 64
const SLOT_MID_INN := 65
const SLOT_CRYPT := 66
const SLOT_V5 := 68
const REFERENCE := "slot_p6_day40_reverent"
const FOUNDER_V5 := "slot_p6_day37_founder"
## neighbor7 / anatomist7: 13 days (B1…B13) → 07:00 of day 53 (test_phase7_playthrough.gd).
const END_DAYS := 13
const FOUNDER_MAX_DAYS := 20


## Phase7Bot that stops on the evening of the name_in_village chapter (eve), saves the first time it
## stands in the Holderkrug in the middle of Phase 7 (inn) or the first time a Phase-7 corpse lies
## unwashed on the crypt table with the gravekeeper in the crypt (crypt). Knows founder7. The inn is
## captured on a village day at least INN_AFTER_OPEN days after village_open (mitten in Phase 7).
class CaptureBot extends Phase7Bot:
	const INN_AFTER_OPEN := 4
	var mode: StringName = &""
	var captured: bool = false
	var save_cb: Callable

	func strategies() -> Dictionary:
		var out := Phase7Bot.P7_STRATEGIES.duplicate()
		out[&"founder7"] = Phase7Bot._with7({}, {}, {"keep_p5": true, "optional": [&"crypt", &"chapel"]}, {})
		return out

	func _sleep() -> void:
		if mode == &"eve" and not captured and GameState.has_flag(&"name_in_village_complete"):
			_to_room(&"")
			_wait_until(20 * 60)
			captured = true
			return
		await super._sleep()

	func _save_and_load_in_inn() -> void:
		if mode != &"inn" or captured:
			return
		if GameState.has_flag(&"name_in_village_complete") or open7_day < 0 or TimeManager.day < open7_day + INN_AFTER_OPEN:
			return
		if player.interior_id != &"inn" or player.region_id != &"village":
			return
		print("mid_inn: day %d %s interior %s region %s" % [TimeManager.day, TimeManager.format_clock(), player.interior_id, player.region_id])
		captured = save_cb.call()
		saved_in_inn = captured

	func _work_at_table(record: CorpseRecord, table: MorgueTable) -> void:
		if mode == &"crypt" and not captured and p7_open() and record.location == CorpseRecord.LOCATION_TABLE \
				and record.room == &"crypt" and player.interior_id == &"crypt" and not record.washed and not record.is_dressed():
			print("crypt_corpse: %s day %d %s examined %s" % [record.id, TimeManager.day, TimeManager.format_clock(), record.examined])
			captured = save_cb.call()
		super._work_at_table(record, table)


var out_dir: String = ""
var tree: SceneTree
var bot: Phase7Bot
var only: PackedStringArray = []


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	SaveManager.save_dir = out_dir
	var ok := true
	if _wanted("neighbor"):
		ok = await _make_end(&"neighbor7", SLOT_NEIGHBOR, "slot_p7_day53_neighbor") and ok
	if _wanted("anatomist"):
		ok = await _make_end(&"anatomist7", SLOT_ANATOMIST, "slot_p7_day53_anatomist") and ok
	if _wanted("eve"):
		ok = await _make_capture(&"eve", &"neighbor7", REFERENCE, SLOT_EVE, "slot_p7_day50_eve") and ok
	if _wanted("founder"):
		ok = await _make_founder() and ok
	if _wanted("inn"):
		ok = await _make_capture(&"inn", &"neighbor7", REFERENCE, SLOT_MID_INN, "slot_p7_mid_inn") and ok
	if _wanted("crypt"):
		ok = await _make_capture(&"crypt", &"neighbor7", REFERENCE, SLOT_CRYPT, "slot_p7_crypt_corpse") and ok
	return ok


func _wanted(key: String) -> bool:
	return only.is_empty() or only.has(key)


func _load_v5(v5_fixture: String) -> bool:
	if Phase7Fixtures.install_save_v5(v5_fixture, out_dir, SLOT_V5) != OK:
		return false
	var err: Error = await SaveManager.load_game(SLOT_V5)
	DirAccess.remove_absolute(SaveFileIO.slot_path(out_dir, SLOT_V5))
	if err != OK:
		printerr("%s does not load" % v5_fixture)
		return false
	return true


## A Phase-7 end state: the reference v5 fixture + 13 bot days, then 07:00 of day 53.
func _make_end(strategy: StringName, slot: int, name: String) -> bool:
	if not await _load_v5(REFERENCE):
		return false
	bot = Phase7Bot.new(strategy, tree)
	bot.bind()
	await _play_days(END_DAYS)
	_morning()
	# The anatomist's last lecture night runs past midnight: its 13 bot days end on the morning of day 54.
	var ok := GameState.has_flag(&"name_in_village_complete") and TimeManager.day >= 40 + END_DAYS
	print("%s: chapter flag %s, day %d (open %d)" % [name, GameState.has_flag(&"name_in_village_complete"), TimeManager.day, bot.open7_day])
	_report(name, ok)
	return _save(slot, name, ok)


## founder7: the v5 founder (new game, day 37) until the name_in_village chapter, then 07:00 of the
## next day.
func _make_founder() -> bool:
	if not await _load_v5(FOUNDER_V5):
		return false
	var cb := CaptureBot.new(&"founder7", tree)
	bot = cb
	bot.bind()
	for i: int in FOUNDER_MAX_DAYS:
		await bot.run_day()
		if GameState.has_flag(&"name_in_village_complete"):
			break
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)
	_morning()
	var ok := GameState.has_flag(&"name_in_village_complete")
	print("slot_p7_founder: chapters %d / %d / %d / %d (open7 %d)" % [bot.chapter_day, bot.chapter5_day, bot.chapter6_day,
			bot.chapter7_day, bot.open7_day])
	_report("slot_p7_founder", ok)
	return _save(SLOT_FOUNDER, "slot_p7_founder", ok)


## A state captured inside a bot day (see CaptureBot); at most 14 days.
func _make_capture(mode: StringName, strategy: StringName, v5_fixture: String, slot: int, name: String) -> bool:
	if not await _load_v5(v5_fixture):
		return false
	var cb := CaptureBot.new(strategy, tree)
	cb.mode = mode
	if mode == &"inn":
		cb.flags["save_in_inn"] = true
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
			return GameState.has_flag(&"name_in_village_complete") and TimeManager.minute_of_day >= 1200 \
					and bot.player.region_id == &"graveyard"
		&"inn":
			return bot.player.interior_id == &"inn" and bot.player.region_id == &"village" \
					and GameState.has_flag(&"village_open") and not GameState.has_flag(&"name_in_village_complete")
		&"crypt":
			return bot.player.interior_id == &"crypt" and GameState.has_flag(&"village_open")
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


func _count(state: GraveRecord.State, section: StringName = &"") -> int:
	var n := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == state and (section == &"" or bot.graveyard.section_of(g.id) == section):
			n += 1
	return n


func _report(name: String, ok: bool) -> void:
	var trusted := 0
	for id: StringName in Phase7Bot.VILLAGERS:
		if RelationshipRules.tier_index(bot.rel.tier(id)) >= RelationshipRules.tier_index(&"trusted"):
			trusted += 1
	var linden_free := _count(GraveRecord.State.EMPTY, &"linden") + _count(GraveRecord.State.DUG, &"linden")
	print("%s: ok=%s day %d %s problems=%s rep=%d coins=%d piety=%d marked=%d linden_marked=%d linden_free=%d trusted=%d levels=%s orders=%d chapter7=%d specimens=%d sold=%d" % [
			name, ok, TimeManager.day, TimeManager.format_clock(), bot.problems, GameState.get_stat(&"reputation"),
			bot.inv().count(&"coin"), bot.piety.value(), _count(GraveRecord.State.MARKED), _count(GraveRecord.State.MARKED, &"linden"),
			linden_free, trusted, str(bot.buildings.levels()), bot.orders.done_count(), bot.chapter7_day,
			GameState.get_stat(&"specimens_taken"), GameState.get_stat(&"specimens_sold")])


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
