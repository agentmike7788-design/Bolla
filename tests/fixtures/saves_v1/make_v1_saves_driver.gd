extends RefCounted
## Driver of make_v1_saves.gd (loaded after the autoloads exist). See there.

const DAY3 := 11
const DAY7 := 12
const INTERIOR := 13

var out_dir: String = ""
var world: WorldRoot
var player: Player
var manager: CorpseManager
var graveyard: Graveyard
var table: MorgueTable
var tables: CorpseTables


var tree: SceneTree


func run(scene_tree: SceneTree, dir: String) -> bool:
	tree = scene_tree
	out_dir = dir
	SaveManager.save_dir = out_dir
	tables = Database.corpse_tables() as CorpseTables
	var ok: bool = await _make_day3()
	ok = await _make_day7_complete() and ok
	ok = await _make_interior() and ok
	return ok


## Day 3, 10:xx: plot_01 (cross) + plot_02 (gravestone, valuables left) finished, the day-3
## corpse examined on the table, plot_03 dug open, some wood gathered.
func _make_day3() -> bool:
	await _new_game()
	_finish_day(1, "plot_01", &"wooden_cross", false)
	_finish_day(2, "plot_02", &"gravestone_simple", false)
	TimeManager.set_time(3, tables.delivery_minute)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	manager.get_corpse_node(record.id).interact(player)
	table.interact(player)
	table.request_examine()
	(world.get_node_by_layout_id("plot_03") as GravePlot).interact(player)
	var wood := world.get_node_by_layout_id("res_wood") as ResourceNode
	wood.interact(player)
	wood.interact(player)
	return _save(DAY3, "slot_day3", GraveRecord.State.DUG == graveyard.get_grave("plot_03").state \
			and record.location == CorpseRecord.LOCATION_TABLE)


## Day 7: all six graves MARKED over days 1–6 (valuables taken on days 2 and 4 → reputation −2),
## flag slice_complete set by the real Graveyard.
func _make_day7_complete() -> bool:
	await _new_game()
	var markers: Array[StringName] = [&"wooden_cross", &"gravestone_simple", &"wooden_cross",
			&"gravestone_simple", &"wooden_cross", &"gravestone_simple"]
	for day: int in range(1, 7):
		_finish_day(day, "plot_%02d" % day, markers[day - 1], day == 2 or day == 4)
	TimeManager.set_time(7, 9 * 60)
	UIState.clear()
	var ok := GameState.has_flag(&"slice_complete") and GameState.get_stat(&"reputation") == -2 \
			and GameState.get_stat(&"burials") == 6
	return _save(DAY7, "slot_day7_complete", ok)


## Day 2 evening: one grave finished, the day-2 corpse lying on the bier, the gravekeeper inside
## the hut, chest holding wood/stone/linen.
func _make_interior() -> bool:
	await _new_game()
	_finish_day(1, "plot_01", &"wooden_cross", false)
	TimeManager.set_time(2, tables.delivery_minute)
	var interior := world.get_node("HutInterior") as HutInterior
	var chest := interior.get_node("Entities/chest") as Chest
	chest.storage.add_item(&"wood", 7)
	chest.storage.add_item(&"stone", 3)
	chest.storage.add_item(&"linen", 2)
	TimeManager.set_time(2, 19 * 60 + 15)
	HutPortal.arrive(player, interior.spawn_transform(), true)
	return _save(INTERIOR, "slot_interior", player.in_interior and chest.storage.count(&"wood") == 7)


## Delivery of `day` → table → examine (+ valuables decision) → shroud → dig → bury → marker.
func _finish_day(day: int, plot_id: String, marker: StringName, take_valuables: bool) -> void:
	TimeManager.set_time(day, tables.delivery_minute)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert(record != null, "delivery on day %d" % day)
	manager.get_corpse_node(record.id).interact(player)
	table.interact(player)
	table.request_examine()
	if record.needs_valuables_decision():
		table.decide_valuables(take_valuables)
	player.inventory.add_item(&"shroud", 1)
	table.request_shroud()
	var plot := world.get_node_by_layout_id(plot_id) as GravePlot
	plot.interact(player)
	table.request_pick_up()
	plot.interact(player)
	player.inventory.add_item(marker, 1)
	plot.interact(player)
	assert(graveyard.get_grave(plot_id).state == GraveRecord.State.MARKED, plot_id + " marked")
	UIState.clear()


func _new_game() -> void:
	await SaveManager.new_game()
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	manager = world.corpse_manager
	graveyard = world.graveyard
	table = world.get_node_by_layout_id("morgue_table") as MorgueTable
	TimeManager.running = false


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
	for r: CorpseRecord in manager.records():
		if r.location == location:
			return r
	return null
