extends RefCounted
## Driver of make_v7_saves.gd (loaded after the autoloads exist). See there.
## The Phase-8 end states continue the v6 fixtures (tests/fixtures/saves_v6) with Phase8Bot exactly like
## test_phase8_playthrough.gd (kindly8 / anatomist8 / night8b: 10 days; founder8: up to 21 days, until its
## chapter), then 07:00 of the next morning. The middle of Phase 8 is kindly8 after 5 days. The two hill states
## (docs/PHASE8_DESIGN.md „G8 Runde 6") are taken inside a bot morning: HillBot (duty_requests) from a new game,
## and Phase7Bot (founder7, as in make_v6_saves_driver.gd) on the v5 founder for the village board – one request
## accepted on the board's first morning, saved at 10:00 (docs/PHASE9_DESIGN.md §5.3 "Fixtures").

const SLOT_KINDLY := 71
const SLOT_ANATOMIST := 72
const SLOT_LETGO := 73
const SLOT_FOUNDER := 74
const SLOT_MID := 75
const SLOT_DAY2 := 76
const SLOT_VILLAGE := 77
const SLOT_IN := 78
const NEIGHBOR_V6 := "slot_p7_day53_neighbor"
const ANATOMIST_V6 := "slot_p7_day53_anatomist"
const FOUNDER_V6 := "slot_p7_founder"
const FOUNDER_V5 := "slot_p6_day37_founder"
## kindly8 / anatomist8 / night8b: 10 days (test_phase8_playthrough.gd DAYS).
const END_DAYS := 10
const MID_DAYS := 5
const FOUNDER_MAX_DAYS := 21
## Saved at 10:00 of the board's morning (§5.3 slot_p8_day2_hill).
const HILL_SAVE_MINUTE := 600
## After Osric pinned the requests (HillRequestsConfig.post_minute 07:44).
const HILL_READ_MINUTE := 470


## Phase7Bot with founder7 (make_v6_saves_driver.gd: crafter + Phase 7, keep_p5, optional crypt / chapel).
class FounderBot7 extends Phase7Bot:
	func strategies() -> Dictionary:
		var out := Phase7Bot.P7_STRATEGIES.duplicate()
		out[&"founder7"] = Phase7Bot._with7({}, {}, {"keep_p5": true, "optional": [&"crypt", &"chapel"]}, {})
		return out


## night8b that first asks Lambert who pays him (robber.tres: „Wer zahlt dich?“ → node who, action
## add_clue:c_n_robber), then lets him go as night8b does – §5.3 wants the let-go state with c_n_robber.
class AskLetGoBot extends Phase8Bot:
	func _robber_watch() -> void:
		var ask := func(kind: StringName, _target: String) -> void:
			if kind == &"seen":
				DialogueActions.run_all(["add_clue:c_n_robber"] as Array[String], {"inventory": inv(), "player": player,
						"speaker": world.get_node_by_layout_id("npc_robber")})
		EventBus.robber_event.connect(ask)
		await super._robber_watch()
		EventBus.robber_event.disconnect(ask)


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
		ok = await _make_end(&"kindly8", NEIGHBOR_V6, END_DAYS, SLOT_KINDLY, "slot_p8_day63_kindly") and ok
	if _wanted("anatomist"):
		ok = await _make_end(&"anatomist8", ANATOMIST_V6, END_DAYS, SLOT_ANATOMIST, "slot_p8_day63_anatomist") and ok
	if _wanted("letgo"):
		ok = await _make_end(&"night8b", NEIGHBOR_V6, END_DAYS, SLOT_LETGO, "slot_p8_day63_letgo") and ok
	if _wanted("founder"):
		ok = await _make_end(&"founder8", FOUNDER_V6, FOUNDER_MAX_DAYS, SLOT_FOUNDER, "slot_p8_founder", true) and ok
	if _wanted("mid"):
		ok = await _make_end(&"kindly8", NEIGHBOR_V6, MID_DAYS, SLOT_MID, "slot_p8_mid") and ok
	if _wanted("day2"):
		ok = await _make_day2() and ok
	if _wanted("village"):
		ok = await _make_village() and ok
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


## A Phase-8 state: a v6 fixture + `days` Phase8Bot days (or until the chapter), then 07:00 of the next morning.
func _make_end(strategy: StringName, v6: String, days: int, slot: int, name: String, until_chapter: bool = false) -> bool:
	if Phase8Fixtures.install_save_v6(v6, out_dir, SLOT_IN) != OK or not await _load_installed(v6):
		return false
	var bot: Phase8Bot = AskLetGoBot.new(strategy, tree) if strategy == &"night8b" else Phase8Bot.new(strategy, tree)
	bot.bind()
	bot.watch()
	for i: int in days:
		await bot.run_day()
		if until_chapter and bot.chapter8_day > 0:
			break
	bot.unwatch()
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)
	bot._to_room(&"")
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var chapter := GameState.has_flag(&"who_comes_up_complete")
	var ok := bot.problems.is_empty() and GameState.flag_on(&"p8_open")
	if name == "slot_p8_mid":
		ok = ok and not chapter
	elif strategy != &"night8b":
		ok = ok and chapter
	if strategy == &"night8b":
		var journal := tree.get_first_node_in_group(&"journal")
		ok = ok and bot.robber.fate() == &"let_go" and journal != null and bool(journal.call(&"has_clue", &"c_n_robber"))
	_report8(name, bot, ok)
	return _save(slot, name, ok)


## slot_p8_day2_hill: a new game, HillBot duty_requests day 1; day 2: the board read after 07:44, one request
## accepted, 10:00.
func _make_day2() -> bool:
	await SaveManager.new_game()
	var bot := HillBot.new(&"duty_requests", tree)
	bot.bind()
	await bot.run_day()
	bot._leave_hut()
	bot._wait_until(HILL_READ_MINUTE)
	var accepted := _accept_one(bot.hill, func(id: StringName) -> bool: return bot._doable(id))
	bot._wait_until(HILL_SAVE_MINUTE)
	UIState.clear()
	var ok := accepted != &"" and bot.problems.is_empty() and TimeManager.day == 2 and bot.hill.board().size() == 2 \
			and bot.hill.active().size() == 1
	_report_hill("slot_p8_day2_hill", bot.hill, bot.inv(), ok)
	return _save(SLOT_DAY2, "slot_p8_day2_hill", ok)


## slot_p8_day30_village_hill: the v5 founder (day 37, the village opens) + one founder7 day; on the next morning
## the village board's request is accepted, 10:00.
func _make_village() -> bool:
	if Phase7Fixtures.install_save_v5(FOUNDER_V5, out_dir, SLOT_IN) != OK or not await _load_installed(FOUNDER_V5):
		return false
	var bot := FounderBot7.new(&"founder7", tree)
	bot.bind()
	await bot.run_day()
	var hill := bot.world.get_node("Systems/HillRequests") as HillRequests
	bot._to_room(&"")
	bot._leave_hut()
	bot._wait_until(HILL_READ_MINUTE)
	var accepted := _accept_one(hill, func(_id: StringName) -> bool: return true)
	bot._wait_until(HILL_SAVE_MINUTE)
	UIState.clear()
	var ok := accepted != &"" and bot.problems.is_empty() and GameState.flag_on(&"village_open") \
			and hill.active().size() == 1
	_report_hill("slot_p8_day30_village_hill", hill, bot.inv(), ok)
	return _save(SLOT_VILLAGE, "slot_p8_day30_village_hill", ok)


## The first offered request (board order) that may be accepted and that `doable` allows.
func _accept_one(hill: HillRequests, doable: Callable) -> StringName:
	for id: StringName in hill.offered():
		if hill.accept_reason(id) == "" and bool(doable.call(id)) and hill.accept(id):
			return id
	printerr("no request to accept: board %s offered %s" % [str(hill.board()), str(hill.offered())])
	return &""


func _count(graveyard: Graveyard, state: GraveRecord.State, section: StringName = &"") -> int:
	var n := 0
	for g: GraveRecord in graveyard.graves():
		if g.state == state and (section == &"" or graveyard.section_of(g.id) == section):
			n += 1
	return n


func _report8(name: String, bot: Phase8Bot, ok: bool) -> void:
	var g := bot.graveyard
	var linden_free := _count(g, GraveRecord.State.EMPTY, &"linden") + _count(g, GraveRecord.State.DUG, &"linden")
	var row3_free := _count(g, GraveRecord.State.EMPTY, &"linden_row3") + _count(g, GraveRecord.State.DUG, &"linden_row3")
	print("%s: ok=%s strategy %s day %d %s problems=%s coins=%d (purse %d tin %d) rep=%d piety=%d marked=%d linden_free=%d row3_free=%d open8=%d chapter8=%d p8_open_day=%s who_comes_up=%s robber=%s anatomy=%s specimens=%d clue_robber=%s hill=%s" % [
			name, ok, bot.strategy, TimeManager.day, TimeManager.format_clock(), bot.problems, bot.coins_total(),
			bot.inv().count(&"coin"), bot._tin(), GameState.get_stat(&"reputation"), bot.piety.value(),
			_count(g, GraveRecord.State.MARKED), linden_free, row3_free, bot.open8_day, bot.chapter8_day,
			str(GameState.get_flag(&"p8_open_day")), GameState.has_flag(&"who_comes_up_complete"), bot.robber.fate(),
			GameState.has_flag(&"anatomy_known"), GameState.get_stat(&"specimens_taken"),
			bool(bot.tree.get_first_node_in_group(&"journal").call(&"has_clue", &"c_n_robber")), str((bot.world.get_node("Systems/HillRequests") as HillRequests).board())])


func _report_hill(name: String, hill: HillRequests, inv: Inventory, ok: bool) -> void:
	print("%s: ok=%s day %d %s coins=%d village_open=%s board=%s offered=%s active=%s" % [name, ok, TimeManager.day,
			TimeManager.format_clock(), inv.count(&"coin"), GameState.flag_on(&"village_open"), str(hill.board()),
			str(hill.offered()), str(hill.active())])


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
