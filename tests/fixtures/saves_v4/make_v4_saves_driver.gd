extends RefCounted
## Driver of make_v4_saves.gd (loaded after the autoloads exist). See there.
## The Phase-5 end states continue the v3 fixtures (tests/fixtures/saves_v3) with Phase5Bot for
## 10 days, exactly like test_phase5_playthrough.gd (reverent5 / mender / harvester5); the new-game
## states play crafter from day 1. The last day is driven by hand up to the fixture moment
## (docs/PHASE6_DESIGN.md §5.2 "Fixtures").

const SLOT_DAY30_REVERENT := 41
const SLOT_DAY35_HARVESTER := 42
const SLOT_DAY30_MENDER := 43
const SLOT_DAY16_TABLE := 44
const SLOT_DAY16_CARRY := 45
const SLOT_DAY20_CRAFTER := 46
const SLOT_INTERIOR := 47
const SLOT_V3 := 48

## Wooden bench on the later crypt site (§5.2 "interior", §4.1).
const BENCH_AT := Vector2(-9.0, 6.9)
## Crypt footprint x −10.4…−7.6 · z 5.6…8.2 + station margin 0.6 + access 1.0 m south (§4.1 G2).
const CRYPT_SITE := Rect2(-10.4 - 0.6, 5.6 - 0.6, 2.8 + 1.2, 2.6 + 1.2 + 1.0)


## Stops before going to bed on the evening names_in_stone_complete was reached (day20_crafter).
class ChapterStopBot extends Phase5Bot:
	var stop_on_chapter: bool = false
	var stopped: bool = false

	func _sleep() -> void:
		if stop_on_chapter and not stopped and GameState.has_flag(&"names_in_stone_complete"):
			_wait_until(20 * 60)
			stopped = true
			return
		await super._sleep()


var out_dir: String = ""
var tree: SceneTree
var bot: Phase5Bot
var tables: CorpseTables
var only: PackedStringArray = []


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	SaveManager.save_dir = out_dir
	tables = Database.corpse_tables() as CorpseTables
	var ok := true
	if _wanted("day30r"):
		ok = await _make_end(&"reverent5", "slot_p4_day20_reverent", SLOT_DAY30_REVERENT, "slot_p5_day30_reverent", 30) and ok
	if _wanted("day35h"):
		ok = await _make_end(&"harvester5", "slot_p4_day25_harvester", SLOT_DAY35_HARVESTER, "slot_p5_day35_harvester", 35) and ok
	if _wanted("day30m"):
		ok = await _make_end(&"mender", "slot_p4_day20_mixed", SLOT_DAY30_MENDER, "slot_p5_day30_mender", 30) and ok
	if _wanted("day16t"):
		ok = await _make_day16_table() and ok
	if _wanted("day16c"):
		ok = await _make_day16_carry() and ok
	if _wanted("day20c"):
		ok = await _make_crafter_chapter() and ok
	if _wanted("interior"):
		ok = await _make_interior() and ok
	return ok


func _wanted(key: String) -> bool:
	return only.is_empty() or only.has(key)


## A Phase-5 end state: the v3 fixture + 10 bot days, then 07:00 of the next day.
func _make_end(strategy: StringName, v3_fixture: String, slot: int, name: String, day: int) -> bool:
	if Phase5Fixtures.install_save_v3(v3_fixture, out_dir, SLOT_V3) != OK:
		return false
	var err: Error = await SaveManager.load_game(SLOT_V3)
	DirAccess.remove_absolute(SaveFileIO.slot_path(out_dir, SLOT_V3))
	if err != OK:
		printerr("%s: %s does not load" % [name, v3_fixture])
		return false
	bot = Phase5Bot.new(strategy, tree)
	bot.bind()
	await _play_days(10)
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var old := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == GraveRecord.State.OLD:
			old += 1
	var ok := GameState.has_flag(&"names_in_stone_complete") and TimeManager.day == day and _marked() == 18 and old == 8
	if strategy == &"harvester5":
		ok = ok and _robbed_restless() > 0
	elif strategy == &"mender":
		# The mender set master stones for the robbed graves first: robbed, but no longer restless.
		ok = ok and not _robbed_moods().is_empty()
	print("%s: marked %d old %d coins %d rep %d robbed-restless %d fully-robbed %d robbed moods %s" % [name, _marked(), old,
			bot.inv().count(&"coin"), GameState.get_stat(&"reputation"), _robbed_restless(), _fully_robbed(), str(_robbed_moods())])
	_report(name, ok)
	return _save(slot, name, ok)


## crafter, day 16, 10:00: workshop_open, deliveries running, the day's corpse on the table in
## front of the hut with 2 of 4 steps (clothing + hands), a juniper window running, the braid taken.
func _make_day16_table() -> bool:
	await _new_game(&"crafter")
	await _play_days(15)
	bot._leave_hut()
	bot._gather()
	bot._wait_until(tables.delivery_minute + 10)
	var record := _carry_to_table()
	var table := _table()
	var ok := record != null
	if ok:
		for step: StringName in [CorpseRecord.STEP_CLOTHING, CorpseRecord.STEP_HANDS]:
			table.interact(bot.player)
			UIState.clear()
			table.request_exam_step(step)
		var reason := bot.care.harvest_block_reason(record.id, &"hair", bot.inv())
		if reason == "":
			table.interact(bot.player)
			UIState.clear()
			table.request_harvest(&"hair")
		else:
			print("day16_table: hair blocked: ", reason)
		if bot.inv().count(&"juniper") == 0:
			bot._buy(&"juniper", 1)
		table.interact(bot.player)
		UIState.clear()
		table.request_balm()
		bot._wait_until(10 * 60)
		UIState.clear()
		var steps := 0
		for step: StringName in CorpseRecord.STEPS:
			if record.is_step_done(step):
				steps += 1
		var now := TimeManager.total_minutes()
		var window := record.balm_windows.size() >= 2 and record.balm_windows[0] <= now and now < record.balm_windows[1]
		ok = record.location == CorpseRecord.LOCATION_TABLE and steps == 2 and window \
				and record.is_harvested(&"hair") and TimeManager.day == 16 and GameState.has_flag(&"workshop_open")
		print("day16_table: steps %d window %s hair %s" % [steps, window, record.is_harvested(&"hair")])
	_report("day16_table", ok)
	return _save(SLOT_DAY16_TABLE, "slot_p5_day16_table", ok)


## crafter, day 16, 08:10: the gravekeeper carries the day's corpse outside.
func _make_day16_carry() -> bool:
	await _new_game(&"crafter")
	await _play_days(15)
	bot._leave_hut()
	bot._gather()
	bot._wait_until(tables.delivery_minute + 10)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	var ok := record != null
	if ok:
		bot.manager.get_corpse_node(record.id).interact(bot.player)
		UIState.clear()
		bot._wait_until(8 * 60 + 10)
		ok = record.location == CorpseRecord.LOCATION_CARRIED and not bot.player.in_interior and TimeManager.day == 16 \
				and GameState.has_flag(&"workshop_open")
		print("day16_carry: location %s" % record.location)
	_report("day16_carry", ok)
	return _save(SLOT_DAY16_CARRY, "slot_p5_day16_carry", ok)


## crafter from a new game up to the evening names_in_stone was reached (Phase 6 opens the next
## morning). The bot stops before bed (20:00, or later if it was still working).
func _make_crafter_chapter() -> bool:
	await SaveManager.new_game()
	var stop_bot := ChapterStopBot.new(&"crafter", tree)
	stop_bot.stop_on_chapter = true
	bot = stop_bot
	bot.flags = bot.flags.duplicate()
	bot.bind()
	for i: int in 30:
		await bot.run_day()
		if stop_bot.stopped:
			break
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)
	UIState.clear()
	var ok := stop_bot.stopped and GameState.has_flag(&"names_in_stone_complete")
	print("day20_crafter: chapter5 day %d, now day %d %s" % [bot.chapter5_day, TimeManager.day, TimeManager.format_clock()])
	_report("day20_crafter", ok)
	return _save(SLOT_DAY20_CRAFTER, "slot_p5_day20_crafter", ok)


## crafter, day 12, 22:00: inside the hut; a wooden bench on the later crypt site (−9.0 | 6.9),
## placed through BuildMode like a player.
func _make_interior() -> bool:
	await _new_game(&"crafter")
	await _play_days(11)
	bot._leave_hut()
	bot._gather()
	var bench := bot.world.get_node_by_layout_id("workbench") as Workbench
	for i: int in 3:
		if bot.inv().count(&"decor_bench_wood") > 0:
			break
		if bot.inv().count(&"wood") < 5:
			var node := bot.world.get_node_by_layout_id("res_wood") as ResourceNode
			while node.can_interact(bot.player):
				node.interact(bot.player)
		bot._craft(bench, &"decor_bench_wood")
	var placed := bot._place_near(&"decor_bench_wood", BENCH_AT, &"yard")
	bot._wait_until(22 * 60)
	var interior := bot.world.get_node("HutInterior") as HutInterior
	HutPortal.arrive(bot.player, interior.spawn_transform(), true)
	UIState.clear()
	var d := _dist(placed, BENCH_AT)
	var ok := bot.player.in_interior and _in_site(placed, CRYPT_SITE) and TimeManager.day == 12
	print("interior: bench %s (%.2f m from the site centre)" % [placed, d])
	_report("interior", ok)
	return _save(SLOT_INTERIOR, "slot_p5_interior", ok)


# --- helpers ----------------------------------------------------------------------------------

func _new_game(strategy: StringName) -> void:
	await SaveManager.new_game()
	bot = Phase5Bot.new(strategy, tree)
	bot.flags = bot.flags.duplicate()
	bot.bind()


func _play_days(n: int) -> void:
	for i: int in n:
		await bot.run_day()
	if not bot.problems.is_empty():
		printerr("bot problems: ", bot.problems)


func _table() -> MorgueTable:
	return bot.world.get_node_by_layout_id("morgue_table") as MorgueTable


func _carry_to_table() -> CorpseRecord:
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	if record == null:
		return null
	bot.manager.get_corpse_node(record.id).interact(bot.player)
	_table().interact(bot.player)
	UIState.clear()
	return record


func _marked() -> int:
	var n := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			n += 1
	return n


## Graves whose corpse was harvested and whose ghost mood is restless.
func _robbed_restless() -> int:
	var n := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state != GraveRecord.State.MARKED:
			continue
		var r := bot.manager.get_record(g.corpse_id)
		if r == null or r.harvested.is_empty():
			continue
		if StringName(str(bot.ghosts.mood_info(g.id).get("mood", ""))) == &"restless":
			n += 1
	return n


## {grave_id: mood} of the graves whose corpse was harvested.
func _robbed_moods() -> Dictionary:
	var out := {}
	for g: GraveRecord in bot.graveyard.graves():
		var r := bot.manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if g.state == GraveRecord.State.MARKED and r != null and not r.harvested.is_empty():
			out[g.id] = str(bot.ghosts.mood_info(g.id).get("mood", ""))
	return out


## Graves whose corpse lost hair and teeth.
func _fully_robbed() -> int:
	var n := 0
	for g: GraveRecord in bot.graveyard.graves():
		var r := bot.manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if r != null and r.is_harvested(&"hair") and r.is_harvested(&"teeth"):
			n += 1
	return n


func _dist(uid: String, target: Vector2) -> float:
	if uid == "":
		return INF
	var p := bot.decorations.get_placement(uid)
	return INF if p == null else (bot.decorations.centre_of(p) - target).length()


func _in_site(uid: String, rect: Rect2) -> bool:
	var p := bot.decorations.get_placement(uid) if uid != "" else null
	return p != null and rect.has_point(bot.decorations.centre_of(p))


func _report(name: String, ok: bool) -> void:
	print("%s: ok=%s day %d %s problems=%s rep=%d coins=%d piety=%d" % [name, ok, TimeManager.day, TimeManager.format_clock(),
			bot.problems, GameState.get_stat(&"reputation"), bot.inv().count(&"coin"), bot.piety.value()])


func _save(slot: int, name: String, ok: bool) -> bool:
	if not ok:
		printerr("fixture '%s': unexpected state" % name)
		return false
	if SaveManager.save_game(slot) != OK:
		return false
	var dst := out_dir.path_join(name + ".json")
	DirAccess.remove_absolute(dst)
	var err := DirAccess.rename_absolute(SaveFileIO.slot_path(out_dir, slot), dst)
	print("wrote ", dst, " day ", TimeManager.day, " ", TimeManager.format_clock())
	return err == OK


func _record_at(location: StringName) -> CorpseRecord:
	for r: CorpseRecord in bot.manager.records():
		if r.location == location:
			return r
	return null
