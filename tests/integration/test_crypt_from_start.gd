extends TestCase
## P8-pre (04.10.2026, user: „Die Treppe in meinem Friedhof soll immer da sein – da muss ich ja die
## Leichen runterbringen und bearbeiten."): the crypt stands at level 1 from the start of a game.
## - New game (real SaveManager): crypt 1 without a build, buildings not open; portal, stair and door
##   there (site model l1, sod cover gone, door open); the crypt table is the one active table, the old
##   table in front of the hut is hidden without collision; no upgrade prompt before buildings_open.
##   The first dead goes from the bier through the real BuildingDoor onto the crypt table (objective
##   lines „Bring die Leiche hinunter in die Gruft" → „Leg die Leiche auf den Gruft-Tisch"), with the
##   crypt's room cold; save → load keeps crypt 1 and the corpse below.
## - Old saves (v1–v5, crypt 0): post_load lifts the crypt to 1, the corpse on the old table goes onto
##   the crypt table with all its state and one note; a resave → load brings no second note.
## - Upgrade: from buildings_open the site offers „Gruft ausbauen (Stufe 2)", levels 2 and 3 build.

const TIMEOUT := 300.0
const SLOT := 7
const RESAVE_SLOT := 8
const NOTE := CorpseManager.NOTE_RELOCATED

var saves_dir := TestCase.user_dir("test_crypt_from_start")
var world: WorldRoot
var player: Player
var notes: PackedStringArray = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_new_game_has_the_crypt_the_stair_and_the_crypt_table() -> void:
	await SaveManager.new_game()
	_bind()
	TimeManager.running = false
	var buildings := world.get_node("Systems/Buildings") as Buildings
	assert_eq(buildings.level(&"crypt"), 1, "the crypt stands from day 1")
	assert_eq([buildings.level(&"chapel"), buildings.level(&"shed")], [0, 0], "the other buildings are sites")
	assert_false(buildings.is_open(), "Phase 6 is not open yet")
	assert_eq(int(buildings.save_state().levels.crypt), 1, "level 1 is saved")
	# Outside: portal + stair (l1 model), no sod over the pit, the door open; no upgrade before Phase 6.
	var site := world.get_node("Entities/site_crypt") as BuildingSite
	assert_true(site.visible, "the crypt portal is there")
	assert_not_null(site.get_node_or_null("Model"), "the level-1 model")
	assert_not_null(site.get_node("Model").find_child("door_outside", true, false), "the l1 model (door marker)")
	var cover := world.get_node_or_null("Entities/site_crypt_cover") as SiteCover
	assert_not_null(cover, "the sod cover node")
	assert_false(cover.visible, "the stair pit is open")
	assert_eq(site.get_interaction_prompt(player), "", "no upgrade prompt before buildings_open")
	assert_false(site.can_interact(player))
	for id: StringName in [&"chapel", &"shed"]:
		assert_false((world.get_node("Entities/site_%s" % id) as Node3D).visible, "%s site hidden before Phase 6" % id)
	var door := BuildingDoor.find(tree, &"crypt")
	assert_true(door.is_open() and door.can_interact(player), "the crypt door lets the gravekeeper in")
	# Exactly one active table: the crypt table; the old one is gone from the hut.
	var old := world.get_node_by_layout_id("morgue_table") as MorgueTable
	var crypt_table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	assert_false(old.is_active() or old.visible, "no table in front of the hut")
	assert_false(old.can_interact(player))
	for shape: Node in old.find_children("*", "CollisionShape3D", true, false):
		assert_true((shape as CollisionShape3D).disabled, "the old table has no collision")
	assert_true(crypt_table.is_active(), "the crypt table works")
	assert_eq(crypt_table.panel_title(), "Gruft-Tisch")
	var active := tree.get_nodes_in_group(&"morgue_table").filter(func(n: Node) -> bool: return (n as MorgueTable).is_active())
	assert_eq(active.size(), 1, "one active table")
	assert_eq(InteriorRoom.find(tree, &"crypt").level, 1, "the crypt room shows level 1")
	# The first dead: bier → down the stair → crypt table.
	var manager := world.corpse_manager
	var record := manager.try_daily_delivery(1)
	assert_not_null(record, "Osric's first dead")
	(world.get_node("UI") as UIRoot).hud.refresh_all()
	assert_eq(_objective(), Phase6Texts.OBJ_TO_CRYPT, "objective at the bier")
	manager.get_corpse_node(record.id).interact(player)
	assert_eq(player.carried_id, record.id)
	assert_eq(_objective(), Phase6Texts.OBJ_TO_CRYPT, "objective while carrying outside")
	door.interact(player)
	for i: int in 120:
		if player.interior_id == &"crypt":
			break
		await tree.process_frame
	assert_eq(player.interior_id, &"crypt", "carried down through the door")
	assert_eq(player.carried_id, record.id, "the dead goes along")
	assert_eq(_objective(), Phase6Texts.OBJ_ON_CRYPT_TABLE, "objective in the crypt")
	assert_true(crypt_table.can_interact(player))
	assert_eq(crypt_table.get_interaction_prompt(player), MorgueTable.PROMPT_PUT_DOWN)
	crypt_table.interact(player)
	assert_eq([record.location, record.room], [CorpseRecord.LOCATION_TABLE, &"crypt"], "on the crypt table")
	assert_eq(crypt_table.corpse_id, record.id)
	assert_eq(old.corpse_id, "", "the old table sees nothing")
	assert_almost(manager.cold_factor_for(record.location, record.room), 0.8, 0.001, "the crypt's room cold from day 1")
	assert_eq(record.cold_windows.size(), 3, "a cold window is open")
	assert_eq(_objective(), ObjectiveResolver.TEXT_EXAMINE)
	# Save → load: crypt 1, the dead still below.
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	assert_eq(await SaveManager.load_game(RESAVE_SLOT), OK)
	_bind()
	var again := world.corpse_manager.get_record(record.id)
	assert_eq((world.get_node("Systems/Buildings") as Buildings).level(&"crypt"), 1)
	assert_eq([again.location, again.room], [CorpseRecord.LOCATION_TABLE, &"crypt"], "still on the crypt table")
	assert_false(notes.has(NOTE), "a new game never needs the relocation note")


func test_old_saves_get_the_crypt_and_the_table_corpse_goes_down() -> void:
	var cases: Array[Array] = [["v1", "slot_day3"], ["v2", "slot_p3_day5_table"], ["v3", "slot_p4_day7_table"],
			["v4", "slot_p5_day16_table"], ["v4", "slot_p5_day16_carry"], ["v4", "slot_p5_interior"]]
	for c: Array in cases:
		notes.clear()
		assert_eq(_install(String(c[0]), String(c[1])), OK, "%s installed" % c[1])
		var before := _table_corpse_in_file(String(c[0]), String(c[1]))
		assert_eq(await SaveManager.load_game(SLOT), OK, "%s loads" % c[1])
		_bind()
		var buildings := world.get_node("Systems/Buildings") as Buildings
		assert_eq(buildings.level(&"crypt"), 1, "%s: crypt 0 → 1" % c[1])
		assert_true((world.get_node("Entities/site_crypt") as Node3D).visible, "%s: the portal stands" % c[1])
		assert_false((world.get_node("Entities/site_crypt_cover") as SiteCover).visible, "%s: the stair pit is open" % c[1])
		var old := world.get_node_by_layout_id("morgue_table") as MorgueTable
		assert_false(old.is_active() or old.visible, "%s: the old table is gone" % c[1])
		for r: CorpseRecord in world.corpse_manager.records():
			if r.location == CorpseRecord.LOCATION_TABLE:
				assert_eq(r.room, &"crypt", "%s: %s lies on the crypt table" % [c[1], r.id])
		if before != "":
			var moved := world.corpse_manager.get_record(before)
			assert_eq([moved.location, moved.room], [CorpseRecord.LOCATION_TABLE, &"crypt"], "%s: the table corpse went down" % c[1])
			var crypt_table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
			assert_eq(crypt_table.corpse_id, before)
			var node := world.corpse_manager.get_corpse_node(before)
			assert_true(node.global_position.distance_to(crypt_table.slot_transform().origin) < 0.05, "%s: the node lies on the slot" % c[1])
			assert_eq(_count(notes, NOTE), 1, "%s: one note" % c[1])
		else:
			assert_eq(_count(notes, NOTE), 0, "%s: nothing on the old table, no note" % c[1])
		# Resave → load: stays repaired, no second note.
		notes.clear()
		assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
		assert_eq(await SaveManager.load_game(RESAVE_SLOT), OK)
		_bind()
		assert_eq((world.get_node("Systems/Buildings") as Buildings).level(&"crypt"), 1)
		assert_eq(_count(notes, NOTE), 0, "%s: the note only once" % c[1])


func test_the_crypt_still_upgrades_to_2_and_3() -> void:
	await SaveManager.new_game()
	_bind()
	TimeManager.running = false
	var buildings := world.get_node("Systems/Buildings") as Buildings
	var site := world.get_node("Entities/site_crypt") as BuildingSite
	buildings.open()
	await tree.process_frame
	assert_eq(site.get_interaction_prompt(player), "[E] Gruft ausbauen (Stufe 2)")
	var inv := player.inventory
	inv.stack_multiplier = 20
	for lvl: int in [2, 3]:
		var data := buildings.building(&"crypt").level_data(lvl)
		for id: StringName in data.inputs:
			inv.add_item(id, int(data.inputs[id]))
		inv.add_item(&"coin", data.coins)
		var coins := inv.count(&"coin")
		assert_eq(buildings.upgrade_block_reason(&"crypt", inv), "", "level %d affordable" % lvl)
		assert_true(buildings.upgrade(&"crypt", inv), "level %d built" % lvl)
		assert_eq(buildings.level(&"crypt"), lvl)
		assert_eq(coins - inv.count(&"coin"), data.coins, "level %d costs its coins" % lvl)
	assert_eq(site.get_interaction_prompt(player), "", "fully built")
	assert_eq((world.get_node("Systems/Ossuary") as Ossuary).capacity(), 6)
	# Level 1 is free and never built: its data costs nothing.
	var l1 := buildings.building(&"crypt").level_data(1)
	assert_eq([l1.coins, l1.inputs.size()], [0, 0], "crypt 1 costs nothing")


# --- helpers ------------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player() if world != null else null


func _objective() -> String:
	var hud := (world.get_node("UI") as UIRoot).hud
	hud.refresh_all()
	return hud.objective_text()


func _install(version: String, name: String) -> Error:
	match version:
		"v1":
			return Phase3Fixtures.install_save_v1(name, saves_dir, SLOT)
		"v2":
			return Phase4Fixtures.install_save_v2(name, saves_dir, SLOT)
		"v3":
			return Phase5Fixtures.install_save_v3(name, saves_dir, SLOT)
		"v4":
			return Phase6Fixtures.install_save_v4(name, saves_dir, SLOT)
	return Phase7Fixtures.install_save_v5(name, saves_dir, SLOT)


## Id of the corpse on the table in the fixture file ("" = none), read straight from the JSON.
func _table_corpse_in_file(version: String, name: String) -> String:
	var dir: String = {"v1": "saves_v1", "v2": "saves_v2", "v3": "saves_v3", "v4": "saves_v4"}.get(version, "saves_v5")
	var text := FileAccess.get_file_as_string("res://tests/fixtures/%s/%s.json" % [dir, name])
	var found := [""]
	var parsed: Variant = JSON.parse_string(text)
	_walk_json(parsed, found)
	if String(found[0]) == "" and parsed is Dictionary and (parsed as Dictionary).has("data"):
		_walk_json(JSON.to_native((parsed as Dictionary).data), found)
	return String(found[0])


func _walk_json(value: Variant, found: Array) -> void:
	if value is Dictionary:
		var d := value as Dictionary
		if str(d.get("location", "")) == "table" and d.has("id") and str(d.get("room", "")) == "":
			found[0] = str(d.id)
			return
		for v: Variant in d.values():
			_walk_json(v, found)
	elif value is Array:
		for v: Variant in value:
			_walk_json(v, found)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


static func _count(list: PackedStringArray, text: String) -> int:
	var n := 0
	for s: String in list:
		if s == text:
			n += 1
	return n
