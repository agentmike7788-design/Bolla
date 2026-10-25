extends RefCounted
## Driver of make_v8_saves.gd (loaded after the autoloads exist). See there.
## The Phase-9 end states continue the v7 fixtures (tests/fixtures/saves_v7) with Phase9Bot exactly like
## test_phase9_playthrough.gd (kindly9 / stay9 from slot_p8_day63_kindly, trader9 from slot_p8_day63_anatomist: 12 days;
## founder9 from slot_p8_founder: up to 16 days, until its chapter), then 07:00 of the next morning
## (docs/PHASE10_DESIGN.md §5.3). The two new-game states follow the founder line of the curve10 chain (§10.3):
## slot_p9_day38_village = slot_p6_day37_founder (v5, the village opens on day 37) + one founder7 day (as
## make_v6_saves_driver.gd / make_v7_saves_driver.gd), 07:00 of day 38; slot_p9_day29_new = a new game with Phase5Bot
## crafter (the Phase-5 founder bot, §2.1 „P5 crafter (neues Spiel) 1–30") for 28 days, then day 29 up to 23:00 in the
## hut instead of the bed (or a little later, when the bot's evening ran past 23:00). Not Phase6Bot founder: on the G9 code it reaches roof_and_earth – and village_open – before
## day 29, while §5.3 wants the first settlement with the rent only (no tithe before village_open).

const SLOT_KINDLY := 81
const SLOT_TRADER := 82
const SLOT_STAY := 83
const SLOT_FOUNDER := 84
const SLOT_VILLAGE := 85
const SLOT_NEW := 86
const SLOT_IN := 88
const KINDLY_V7 := "slot_p8_day63_kindly"
const ANATOMIST_V7 := "slot_p8_day63_anatomist"
const FOUNDER_V7 := "slot_p8_founder"
const FOUNDER_V5 := "slot_p6_day37_founder"
## kindly9 / stay9 / trader9: 12 days (test_phase9_playthrough.gd DAYS); founder9: up to 16 days.
const END_DAYS := 12
const FOUNDER_MAX_DAYS := 16
## slot_p9_day29_new: the evening before the first month's first (day 30 = 1. Nebelung), 23:00.
const NEW_DAY := 29
const NEW_MINUTE := 23 * 60


## Phase7Bot with founder7 (make_v6_saves_driver.gd: crafter + Phase 7, keep_p5, optional crypt / chapel).
class FounderBot7 extends Phase7Bot:
	func strategies() -> Dictionary:
		var out := Phase7Bot.P7_STRATEGIES.duplicate()
		out[&"founder7"] = Phase7Bot._with7({}, {}, {"keep_p5": true, "optional": [&"crypt", &"chapel"]}, {})
		return out


## Phase5Bot that stays up on day `stop_day`: instead of the bed it waits in the hut until `stop_minute`.
class EveningStopBot extends Phase5Bot:
	var stop_day: int = -1
	var stop_minute: int = 0
	var stopped: bool = false

	func _sleep() -> void:
		if not stopped and TimeManager.day == stop_day:
			var door := world.get_node_by_layout_id("hut_door") as HutDoor
			var interior := tree.get_first_node_in_group(HutInterior.HUT_GROUP) as HutInterior
			if door.can_interact(player):
				HutPortal.arrive(player, interior.spawn_transform(), true)
			_wait_until(stop_minute)
			stopped = true
			return
		await super._sleep()


var out_dir: String = ""
var tree: SceneTree
var only: PackedStringArray = []


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	SaveManager.save_dir = out_dir
	var ok := true
	if _wanted("kindly"):
		ok = await _make_end(&"kindly9", KINDLY_V7, END_DAYS, SLOT_KINDLY, "slot_p9_day75_kindly") and ok
	if _wanted("trader"):
		ok = await _make_end(&"trader9", ANATOMIST_V7, END_DAYS, SLOT_TRADER, "slot_p9_day75_trader") and ok
	if _wanted("stay"):
		ok = await _make_end(&"stay9", KINDLY_V7, END_DAYS, SLOT_STAY, "slot_p9_day75_stay") and ok
	if _wanted("founder"):
		ok = await _make_end(&"founder9", FOUNDER_V7, FOUNDER_MAX_DAYS, SLOT_FOUNDER, "slot_p9_founder", true) and ok
	if _wanted("village"):
		ok = await _make_village() and ok
	if _wanted("new"):
		ok = await _make_new() and ok
	return ok


func _wanted(key: String) -> bool:
	return only.is_empty() or only.has(key)


func _load_installed(name: String) -> bool:
	var err: Error = await SaveManager.load_game(SLOT_IN)
	DirAccess.remove_absolute(SaveFileIO.slot_path(out_dir, SLOT_IN))
	if err != OK:
		printerr("%s does not load" % name)
		return false
	return true


## A Phase-9 state: a v7 fixture + `days` Phase9Bot days (or until the chapter), then 07:00 of the next morning.
func _make_end(strategy: StringName, v7: String, days: int, slot: int, name: String, until_chapter: bool = false) -> bool:
	if Phase9Fixtures.install_save_v7(v7, out_dir, SLOT_IN) != OK or not await _load_installed(v7):
		return false
	var bot := Phase9Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in days:
		await bot.run_day()
		if until_chapter and bot.chapter9_day > 0:
			break
	bot.unwatch()
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)
	bot._to_room(&"")
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var ok := bot.problems.is_empty() and GameState.flag_on(&"p9_open") and GameState.has_flag(&"who_knows_when_complete")
	_report9(name, bot, ok)
	return _save(slot, name, ok)


## slot_p9_day38_village: the v5 founder (day 37, the village opens) + one founder7 day, 07:00 of day 38.
func _make_village() -> bool:
	if Phase7Fixtures.install_save_v5(FOUNDER_V5, out_dir, SLOT_IN) != OK or not await _load_installed(FOUNDER_V5):
		return false
	var bot := FounderBot7.new(&"founder7", tree)
	bot.bind()
	await bot.run_day()
	bot._to_room(&"")
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var ok := bot.problems.is_empty() and GameState.flag_on(&"village_open") and TimeManager.day == 38 \
			and not GameState.has_flag(&"who_knows_when_complete") and not GameState.flag_on(&"p9_open")
	_report_plain("slot_p9_day38_village", bot, ok)
	return _save(SLOT_VILLAGE, "slot_p9_day38_village", ok)


## slot_p9_day29_new: a new game with Phase5Bot crafter; day 29 ends at 23:00 in the hut (the first month's first is
## the next morning).
func _make_new() -> bool:
	await SaveManager.new_game()
	var bot := EveningStopBot.new(&"crafter", tree)
	bot.flags = bot.flags.duplicate(true)
	bot.stop_day = NEW_DAY
	bot.stop_minute = NEW_MINUTE
	bot.bind()
	for i: int in NEW_DAY:
		await bot.run_day()
		if bot.stopped:
			break
	UIState.clear()
	var ok := bot.stopped and bot.problems.is_empty() and TimeManager.day == NEW_DAY \
			and TimeManager.minute_of_day >= NEW_MINUTE and not GameState.flag_on(&"village_open") \
			and GameState.flag_on(&"bruch_license")
	_report_plain("slot_p9_day29_new", bot, ok)
	return _save(SLOT_NEW, "slot_p9_day29_new", ok)


func _count(graveyard: Graveyard, state: GraveRecord.State, section: StringName = &"") -> int:
	var n := 0
	for g: GraveRecord in graveyard.graves():
		if g.state == state and (section == &"" or graveyard.section_of(g.id) == section):
			n += 1
	return n


func _free(graveyard: Graveyard, section: StringName = &"") -> int:
	return _count(graveyard, GraveRecord.State.EMPTY, section) + _count(graveyard, GraveRecord.State.DUG, section)


func _report9(name: String, bot: Phase9Bot, ok: bool) -> void:
	var g := bot.graveyard
	print("%s: ok=%s strategy %s day %d %s problems=%s coins=%d (purse %d tin %d) holdings=%d rep=%d piety=%d marked=%d free=%d row4_free=%d locked=%d open9=%d chapter9=%d p9_open_day=%s ending=%s case=%s bruch_license=%s village_open=%s hill=%s" % [
			name, ok, bot.strategy, TimeManager.day, TimeManager.format_clock(), bot.problems, bot.coins_total(),
			bot.inv().count(&"coin"), bot._tin(), bot.rep.holdings(bot.inv()), GameState.get_stat(&"reputation"),
			bot.piety.value(), _count(g, GraveRecord.State.MARKED), _free(g), _free(g, Phase9Bot.ROW4),
			_count(g, GraveRecord.State.LOCKED), bot.open9_day, bot.chapter9_day, str(GameState.get_flag(&"p9_open_day")),
			bot.quests.ending(Phase9Bot.MAIN), bot.quests.ending(Phase9Bot.CASE_Q), GameState.flag_on(&"bruch_license"),
			GameState.flag_on(&"village_open"), str(bot.hill.board())])


func _report_plain(name: String, bot: Phase3Bot, ok: bool) -> void:
	var inv := bot.inv()
	print("%s: ok=%s strategy %s day %d %s problems=%s purse=%d holdings=%d rep=%d marked=%d free=%d bruch_license=%s workshop_open=%s village_open=%s (day %s) p8_open=%s p9_open=%s chapters=%s" % [
			name, ok, bot.strategy, TimeManager.day, TimeManager.format_clock(), bot.problems, inv.count(&"coin"),
			bot.rep.holdings(inv), GameState.get_stat(&"reputation"), _count(bot.graveyard, GraveRecord.State.MARKED),
			_free(bot.graveyard), GameState.flag_on(&"bruch_license"), GameState.flag_on(&"workshop_open"),
			GameState.flag_on(&"village_open"), str(GameState.get_flag(&"village_open_day")), GameState.flag_on(&"p8_open"),
			GameState.flag_on(&"p9_open"),
			str([&"cemetery_complete", &"names_in_stone_complete", &"roof_and_earth_complete", &"name_in_village_complete",
				&"who_comes_up_complete", &"who_knows_when_complete"].filter(func(f: StringName) -> bool: return GameState.has_flag(f)))])


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
