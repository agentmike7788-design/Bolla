extends RefCounted
## Driver of make_v2_saves.gd (loaded after the autoloads exist). See there.
## Every fixture starts a new game and plays whole days with Phase3Bot (real entities, real
## systems, instant actions); the last day is driven by hand up to the fixture moment.

const SLOT_DAY5 := 21
const SLOT_DAY9 := 22
const SLOT_DAY14 := 23
const SLOT_INTERIOR := 24

var out_dir: String = ""
var tree: SceneTree
var bot: Phase3Bot
var tables: CorpseTables


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	SaveManager.save_dir = out_dir
	tables = Database.corpse_tables() as CorpseTables
	var ok: bool = await _make_day5_table()
	ok = await _make_day9_night() and ok
	ok = await _make_day14_complete() and ok
	ok = await _make_interior() and ok
	return ok


## Day 5, 09:00: Ostwiese cleared, decor placed, some dirt (no tending from day 3 on), the day-5
## corpse (valuables + tattoo) examined on the table, valuables decision still open.
func _make_day5_table() -> bool:
	await _new_game(&"diligent")
	for day: int in range(1, 5):
		if day >= 3:
			bot.flags.tend = false
		await bot.run_day()
	bot._leave_hut()
	bot._gather()
	bot._wait_until(tables.delivery_minute + 10)
	var record := _carry_to_table()
	var table := _table()
	table.interact(bot.player)
	UIState.clear()
	table.request_examine()
	bot._wait_until(9 * 60)
	UIState.clear()
	var ok := record != null and record.location == CorpseRecord.LOCATION_TABLE and record.examined \
			and record.needs_valuables_decision() and record.has_trait(&"tattoo") \
			and bot.expansion.is_unlocked(&"east") and bot.decorations.placements().size() > 0 \
			and _dirt_total() > 0 and TimeManager.day == 5
	_report("day5", ok)
	return _save(SLOT_DAY5, "slot_p3_day5_table", ok)


## Day 9, 23:30: ghosts walking, the day-9 corpse untouched on the bier (decays over night),
## one grave whose valuables were taken.
func _make_day9_night() -> bool:
	await _new_game(&"diligent")
	for day: int in range(1, 9):
		bot.flags.take_valuables = GameState.get_stat(&"valuables_taken") < 1
		await bot.run_day()
	bot._leave_hut()
	bot._gather()
	bot._wait_until(23 * 60 + 30)
	bot.ghosts.reselect()
	bot.ghosts.update_visuals(TimeManager.get_minute_f())
	UIState.clear()
	var on_bier := 0
	for r: CorpseRecord in bot.manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF and not r.examined:
			on_bier += 1
	var ok := TimeManager.day == 9 and on_bier == 1 and GameState.get_stat(&"valuables_taken") == 1 \
			and not bot.ghosts.active_ghosts().is_empty()
	_report("day9", ok)
	return _save(SLOT_DAY9, "slot_p3_day9_night", ok)


## Day 14, 09:00: cemetery_complete, 12 graves, valuables taken twice, the trait corpses of days
## 3–5 (strange_wound / letter / tattoo) buried, ghosts heard, gifts given.
func _make_day14_complete() -> bool:
	await _new_game(&"diligent")
	for day: int in range(1, 14):
		bot.flags.take_valuables = GameState.get_stat(&"valuables_taken") < 2
		await bot.run_day()
	bot._leave_hut()
	bot._wait_until(9 * 60)
	UIState.clear()
	var marked := 0
	for g: GraveRecord in bot.graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			marked += 1
	var buried_traits := {}
	for r: CorpseRecord in bot.manager.records():
		if r.location == CorpseRecord.LOCATION_BURIED:
			for t: StringName in r.traits:
				buried_traits[t] = true
	var ok := GameState.has_flag(&"cemetery_complete") and marked == 12 \
			and GameState.get_stat(&"valuables_taken") == 2 and bot.gifts > 0 \
			and buried_traits.has(&"strange_wound") and buried_traits.has(&"letter") and buried_traits.has(&"tattoo") \
			and not bot.ghosts.heard_moods().is_empty()
	_report("day14", ok)
	return _save(SLOT_DAY14, "slot_p3_day14_complete", ok)


## Day 3, 19:30: the gravekeeper inside the hut (a carried corpse cannot go in), the day-3
## corpse lying on the ground in front of the morgue table, chest filled.
func _make_interior() -> bool:
	await _new_game(&"diligent")
	for day: int in range(1, 3):
		await bot.run_day()
	bot._leave_hut()
	bot._gather()
	bot._wait_until(tables.delivery_minute + 10)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	var ok := record != null
	if ok:
		bot.manager.get_corpse_node(record.id).interact(bot.player)
		var table := _table()
		var p := table.global_position + Vector3(0.0, 0.0, 2.2)
		bot.player.global_position = Vector3(p.x, bot.world.ground_height(Vector2(p.x, p.z)), p.z)
		bot.player.rotation = Vector3.ZERO
		for attempt: int in 8:
			if bot.player._try_drop():
				break
			bot.player.rotation.y += PI / 4.0
		ok = record.location == CorpseRecord.LOCATION_GROUND
	var interior := bot.world.get_node("HutInterior") as HutInterior
	var chest := interior.get_node("Entities/chest") as Chest
	chest.storage.add_item(&"wood", 6)
	chest.storage.add_item(&"stone", 4)
	chest.storage.add_item(&"linen", 2)
	chest.storage.add_item(&"seeds", 1)
	bot._wait_until(19 * 60 + 30)
	HutPortal.arrive(bot.player, interior.spawn_transform(), true)
	UIState.clear()
	ok = ok and bot.player.in_interior and chest.storage.count(&"wood") == 6 and TimeManager.day == 3
	_report("interior", ok)
	return _save(SLOT_INTERIOR, "slot_p3_interior", ok)


# --- helpers ----------------------------------------------------------------------------------

func _new_game(strategy: StringName) -> void:
	await SaveManager.new_game()
	bot = Phase3Bot.new(strategy, tree)
	bot.flags = bot.flags.duplicate()
	bot.bind()


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


func _dirt_total() -> int:
	var n := 0
	for id: String in bot.clean.spot_ids():
		n += bot.clean.level(id)
	return n


func _report(name: String, ok: bool) -> void:
	print("%s: ok=%s day %d %s problems=%s rep=%d coins=%d" % [name, ok, TimeManager.day, TimeManager.format_clock(),
			bot.problems, GameState.get_stat(&"reputation"), bot.inv().count(&"coin")])


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
