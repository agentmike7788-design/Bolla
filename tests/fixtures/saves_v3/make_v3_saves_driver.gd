extends RefCounted
## Driver of make_v3_saves.gd (loaded after the autoloads exist). See there.
## Every fixture starts a new game and plays whole days with Phase4Bot (real entities, real
## systems, instant actions, Ilse through the real DialogueRunner); the last day is driven by
## hand up to the fixture moment (docs/PHASE5_DESIGN.md §5.2 "Fixtures").

const SLOT_DAY7 := 31
const SLOT_DAY13 := 32
const SLOT_DAY20_REVERENT := 33
const SLOT_DAY20_MIXED := 34
const SLOT_DAY25 := 35
const SLOT_INTERIOR := 36

## Phase-4 tools that migrate to the tool belt (§5.2 1).
const TOOLS: Array[StringName] = [&"scrub_brush", &"comb", &"rake", &"shears", &"pliers"]
## Decor in the later workyard (§5.2 "interior"): wooden bench in front of the hut (loom site),
## grave vase next to the workbench (mason site).
const BENCH_AT := Vector2(-8.6, -1.3)
const VASE_AT := Vector2(-0.5, -10.6)
## Footprint + station_margin 0.6 + 1.0 m access south (§2.1, §4.1 V2) of the two sites.
const LOOM_SITE := Rect2(-8.6 - 1.1 - 0.6, -1.3 - 0.9 - 0.6, 2.2 + 1.2, 1.8 + 1.2 + 1.0)
const MASON_SITE := Rect2(-0.5 - 1.3 - 0.6, -10.6 - 0.8 - 0.6, 2.6 + 1.2, 1.6 + 1.2 + 1.0)

var out_dir: String = ""
var tree: SceneTree
var bot: Phase4Bot
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
	if _wanted("day7"):
		ok = await _make_day7_table() and ok
	if _wanted("day13"):
		ok = await _make_day13_complete() and ok
	if _wanted("day20r"):
		ok = await _make_day20(&"reverent", SLOT_DAY20_REVERENT, "slot_p4_day20_reverent") and ok
	if _wanted("day20m"):
		ok = await _make_day20(&"mixed", SLOT_DAY20_MIXED, "slot_p4_day20_mixed") and ok
	if _wanted("day25"):
		ok = await _make_day25_harvester() and ok
	if _wanted("interior"):
		ok = await _make_interior() and ok
	return ok


func _wanted(key: String) -> bool:
	return only.is_empty() or only.has(key)


## Day 7, 10:00 (mixed – an odd day, a harvester's day): the day-7 corpse on the table with 2 of
## 4 examination steps, juniper window running, the braid taken; brush, comb, rake, shears and
## pliers in inventory slots.
func _make_day7_table() -> bool:
	await _new_game(&"mixed")
	await _play_days(6)
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
		if bot.care.harvest_block_reason(record.id, &"hair", bot.inv()) == "":
			table.interact(bot.player)
			UIState.clear()
			table.request_harvest(&"hair")
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
				and record.is_harvested(&"hair") and TimeManager.day == 7 and _tools_in_slots(TOOLS)
		print("day7: steps %d window %s hair %s tools %s" % [steps, window, record.is_harvested(&"hair"), str(_slot_ids())])
	_report("day7", ok)
	return _save(SLOT_DAY7, "slot_p4_day7_table", ok)


## Day 13, 09:00 (reverent): cemetery_complete set, Holunderwinkel open, deliveries running
## (fewer than 18 graves marked).
func _make_day13_complete() -> bool:
	await _new_game(&"reverent")
	await _play_days(12)
	bot._leave_hut()
	bot._wait_until(9 * 60)
	UIState.clear()
	var marked := _marked()
	var ok := GameState.has_flag(&"cemetery_complete") and bot.expansion.is_unlocked(&"elder") \
			and marked >= 12 and marked < 18 and not GameState.has_flag(&"six_pits_complete") and TimeManager.day == 13
	print("day13: marked %d cemetery_complete %s elder %s" % [marked, GameState.has_flag(&"cemetery_complete"),
			bot.expansion.is_unlocked(&"elder")])
	_report("day13", ok)
	return _save(SLOT_DAY13, "slot_p4_day13_complete", ok)


## Day 20, 07:00: chapter six_pits, 18 graves (reverent: ≈ 121 coins, reputation 100; mixed:
## robbed graves with restless ghosts).
func _make_day20(strategy: StringName, slot: int, name: String) -> bool:
	await _new_game(strategy)
	await _play_days(19)
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var marked := _marked()
	var ok := GameState.has_flag(&"six_pits_complete") and marked == 18 and TimeManager.day == 20
	if strategy == &"reverent":
		ok = ok and GameState.get_stat(&"reputation") == 100
	else:
		ok = ok and _robbed_restless() > 0
	print("%s: marked %d coins %d rep %d robbed-restless %d" % [name, marked, bot.inv().count(&"coin"),
			GameState.get_stat(&"reputation"), _robbed_restless()])
	_report(name, ok)
	return _save(slot, name, ok)


## Day 25, 07:00 (harvester): chapter reached, ≈ 179 coins.
func _make_day25_harvester() -> bool:
	await _new_game(&"harvester")
	await _play_days(24)
	bot._leave_hut()
	bot._wait_until(7 * 60)
	UIState.clear()
	var ok := GameState.has_flag(&"six_pits_complete") and TimeManager.day == 25
	print("day25: marked %d coins %d" % [_marked(), bot.inv().count(&"coin")])
	_report("day25", ok)
	return _save(SLOT_DAY25, "slot_p4_day25_harvester", ok)


## Day 9, 20:00 (reverent): the gravekeeper inside the hut, rake and comb in the chest, pliers
## in the inventory; a wooden bench (loom site) and a grave vase (mason site) standing in the
## later workyard.
func _make_interior() -> bool:
	await _new_game(&"reverent")
	await _play_days(8)
	bot._leave_hut()
	bot._gather()
	var bench := bot.world.get_node_by_layout_id("workbench") as Workbench
	var placed_bench := ""
	var placed_vase := ""
	for i: int in 3:
		if bot.inv().count(&"decor_bench_wood") > 0:
			break
		if bot.inv().count(&"wood") < 5:
			var node := bot.world.get_node_by_layout_id("res_wood") as ResourceNode
			while node.can_interact(bot.player):
				node.interact(bot.player)
		bot._craft(bench, &"decor_bench_wood")
	placed_bench = bot._place_near(&"decor_bench_wood", BENCH_AT, &"yard")
	if bot.inv().count(&"decor_grave_vase") == 0:
		if bot.inv().count(&"seeds") == 0:
			bot._buy(&"seeds", 1)
		if bot.inv().count(&"stone") < 5:
			var node := bot.world.get_node_by_layout_id("res_stone") as ResourceNode
			while node.can_interact(bot.player):
				node.interact(bot.player)
		bot._craft(bench, &"decor_grave_vase")
	placed_vase = bot._place_near(&"decor_grave_vase", VASE_AT, &"yard")
	bot._wait_until(20 * 60)
	var interior := bot.world.get_node("HutInterior") as HutInterior
	var chest := interior.get_node("Entities/chest") as Chest
	for item: StringName in [&"rake", &"comb"]:
		if bot.inv().remove_item(item, 1):
			chest.storage.add_item(item, 1)
	HutPortal.arrive(bot.player, interior.spawn_transform(), true)
	UIState.clear()
	var d_bench := _dist(placed_bench, BENCH_AT)
	var d_vase := _dist(placed_vase, VASE_AT)
	var ok := bot.player.in_interior and chest.storage.count(&"rake") == 1 and chest.storage.count(&"comb") == 1 \
			and bot.inv().count(&"pliers") == 1 and not bot.inv().has(&"rake") and not bot.inv().has(&"comb") \
			and _in_site(placed_bench, LOOM_SITE) and _in_site(placed_vase, MASON_SITE) and TimeManager.day == 9
	print("interior: bench %s (%.2f m) vase %s (%.2f m) slots %s" % [placed_bench, d_bench, placed_vase, d_vase, str(_slot_ids())])
	_report("interior", ok)
	return _save(SLOT_INTERIOR, "slot_p4_interior_chest_tools", ok)


# --- helpers ----------------------------------------------------------------------------------

func _new_game(strategy: StringName) -> void:
	await SaveManager.new_game()
	bot = Phase4Bot.new(strategy, tree)
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


func _tools_in_slots(ids: Array[StringName]) -> bool:
	var slot_ids := _slot_ids()
	for id: StringName in ids:
		if not slot_ids.has(id):
			return false
	return true


func _slot_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in bot.inv().get_slots():
		if s is Dictionary and not (s as Dictionary).is_empty():
			out.append(StringName(str((s as Dictionary).get("id", ""))))
	return out


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
