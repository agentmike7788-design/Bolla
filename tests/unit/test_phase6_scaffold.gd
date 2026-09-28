extends TestCase
## Lead / W0 (docs/PHASE6_DESIGN.md §12): the Phase-6 scaffold – every stub class loads with its
## contract signature, every new data class / config .tres holds valid contract values, the
## extensions of existing data classes, the 7 EventBus signals, no new input actions, the appended
## corpse locations, Database folders, save format v5 + migration chain 1 → … → 5, and the W1
## fixtures (tests/fixtures/phase6, Phase6Fixtures).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["BuildingRules", "Buildings", "ShedSupply", "BuildingSite", "ShedStore", "ChapelRules", "ChapelRites", "Catafalque", "ChapelAltar", "MournerSet", "OssuaryRules", "Ossuary", "OssuaryShelf", "SealedPassage"]
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/buildings/building_rules.gd": "BuildingRules",
	"res://src/systems/buildings/buildings.gd": "Buildings",
	"res://src/systems/buildings/shed_supply.gd": "ShedSupply",
	"res://src/entities/building_site/building_site.gd": "BuildingSite",
	"res://src/entities/shed_store/shed_store.gd": "ShedStore",
	# P2
	"res://src/entities/crypt_niche/crypt_niche.gd": "CryptNiche",
	# P3
	"res://src/systems/ossuary/ossuary_rules.gd": "OssuaryRules",
	"res://src/systems/ossuary/ossuary.gd": "Ossuary",
	"res://src/entities/ossuary_shelf/ossuary_shelf.gd": "OssuaryShelf",
	"res://src/entities/sealed_passage/sealed_passage.gd": "SealedPassage",
	# P4
	"res://src/systems/chapel/chapel_rules.gd": "ChapelRules",
	"res://src/systems/chapel/chapel_rites.gd": "ChapelRites",
	"res://src/entities/catafalque/catafalque.gd": "Catafalque",
	"res://src/entities/chapel_altar/chapel_altar.gd": "ChapelAltar",
	"res://src/entities/mourner_set/mourner_set.gd": "MournerSet",
	# P6
	"res://src/world/interiors/interior_room.gd": "InteriorRoom",
	"res://src/world/interiors/room_exit.gd": "RoomExit",
	"res://src/entities/building_door/building_door.gd": "BuildingDoor",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"BuildingRules": ["next_level", "upgrade_block_reason", "missing", "goal_progress"],
	"Buildings": ["is_open", "level", "levels", "upgrade_block_reason", "upgrade", "apply_levels", "goal_progress", "check_goal",
			"apply_morning", "save_state", "load_state", "post_load"],
	"ShedSupply": ["shortfall", "available", "fetch_block_reason", "fetch", "store_surplus"],
	"BuildingSite": ["refresh", "request_upgrade", "request_fetch", "can_interact", "get_interaction_prompt", "interact"],
	"ShedStore": ["apply_level", "store", "save_state", "load_state", "interact"],
	"CryptNiche": ["is_open", "occupant", "can_interact", "get_interaction_prompt", "interact"],
	"OssuaryRules": ["liftable", "lift_block_reason", "capacity", "label"],
	"Ossuary": ["capacity", "used", "lift_block_reason", "lift", "pending", "reinterred", "reinter", "on_crypt_level",
			"passage_state", "look_at_passage", "save_state", "load_state"],
	"OssuaryShelf": ["refresh", "can_interact", "get_interaction_prompt", "interact"],
	"SealedPassage": ["refresh", "can_interact", "get_interaction_prompt", "interact"],
	"ChapelRules": ["service_block_reason", "devotion_block_reason", "devotion_bonus"],
	"ChapelRites": ["level", "service_block_reason", "hold_service", "devotion_block_reason", "hold_devotion", "devotion_level",
			"eligible_devotions", "services_buried", "save_state", "load_state"],
	"Catafalque": ["occupant", "can_interact", "get_interaction_prompt", "interact"],
	"ChapelAltar": ["request_service", "request_devotion", "can_interact", "get_interaction_prompt", "interact"],
	"MournerSet": ["show_mourners", "hide_mourners"],
	"InteriorRoom": ["spawn_transform", "camera_profile", "apply_room", "apply_level", "find"],
	"RoomExit": ["can_interact", "get_interaction_prompt", "interact"],
	"BuildingDoor": ["is_open", "exit_transform", "can_interact", "get_interaction_prompt", "interact"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["BuildingRules", "next_level", 2], ["BuildingRules", "upgrade_block_reason", 4], ["BuildingRules", "missing", 2],
	["BuildingRules", "goal_progress", 4],
	["Buildings", "level", 1], ["Buildings", "upgrade_block_reason", 2], ["Buildings", "upgrade", 2], ["Buildings", "apply_morning", 1],
	["ShedSupply", "shortfall", 2], ["ShedSupply", "available", 2], ["ShedSupply", "fetch_block_reason", 5], ["ShedSupply", "fetch", 3],
	["ShedSupply", "store_surplus", 3],
	["BuildingSite", "request_upgrade", 0], ["BuildingSite", "request_fetch", 0],
	["ShedStore", "apply_level", 1], ["ShedStore", "store", 0],
	["OssuaryRules", "liftable", 3], ["OssuaryRules", "lift_block_reason", 8], ["OssuaryRules", "capacity", 2], ["OssuaryRules", "label", 1],
	["Ossuary", "lift_block_reason", 2], ["Ossuary", "lift", 2], ["Ossuary", "reinter", 1], ["Ossuary", "on_crypt_level", 1],
	["ChapelRules", "service_block_reason", 5], ["ChapelRules", "devotion_block_reason", 5], ["ChapelRules", "devotion_bonus", 4],
	["ChapelRites", "service_block_reason", 2], ["ChapelRites", "hold_service", 2], ["ChapelRites", "devotion_block_reason", 2],
	["ChapelRites", "hold_devotion", 2], ["ChapelRites", "devotion_level", 1],
	["ChapelAltar", "request_service", 0], ["ChapelAltar", "request_devotion", 1],
	["MournerSet", "show_mourners", 1], ["MournerSet", "hide_mourners", 0],
	["InteriorRoom", "apply_room", 1], ["InteriorRoom", "apply_level", 1], ["InteriorRoom", "find", 2],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/entities/workbench/workbench.gd": ["request_fetch", "request_store"],  # P1
	"res://src/entities/build_site/build_site.gd": ["request_fetch", "request_store"],  # P1
	"res://src/systems/corpse/corpse_decay.gd": ["cold_factor_at", "effective_minutes", "minutes_until"],  # P2
	"res://src/systems/corpse/corpse_manager.gd": ["put_down", "corpse_in_slot", "cold_factor_for", "restart_cold",
			"relocate_table_corpse", "mark_service"],  # P2
	"res://src/entities/morgue_table/morgue_table.gd": ["is_active"],  # P2
	"res://src/systems/graveyard/graveyard.gd": ["lift_old"],  # P3
	"res://src/systems/ghosts/ghost_mood.gd": ["score"],  # P4 (+ devotion)
	"res://src/entities/player/player.gd": ["set_in_interior"],  # P6 (+ room)
	"res://src/world/hut_interior/hut_portal.gd": ["travel", "arrive"],  # P6 (+ room)
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_3_to_4", "migrate_4_to_5"],  # P6
	"res://src/systems/buildings/building_data.gd": ["level_data", "max_level"],  # W0 (data class)
}
## [script, method, args] of the extended signatures of existing classes.
const EXISTING_ARITY := [
	["res://src/entities/workbench/workbench.gd", "request_fetch", 1],
	["res://src/entities/workbench/workbench.gd", "request_store", 0],
	["res://src/entities/build_site/build_site.gd", "request_fetch", 1],
	["res://src/entities/build_site/build_site.gd", "request_store", 0],
	["res://src/systems/corpse/corpse_decay.gd", "cold_factor_at", 2],
	["res://src/systems/corpse/corpse_decay.gd", "effective_minutes", 3],
	["res://src/systems/corpse/corpse_manager.gd", "put_down", 6],
	["res://src/systems/corpse/corpse_manager.gd", "corpse_in_slot", 2],
	["res://src/systems/corpse/corpse_manager.gd", "cold_factor_for", 2],
	["res://src/systems/corpse/corpse_manager.gd", "restart_cold", 1],
	["res://src/systems/corpse/corpse_manager.gd", "relocate_table_corpse", 3],
	["res://src/systems/corpse/corpse_manager.gd", "mark_service", 2],
	["res://src/systems/graveyard/graveyard.gd", "lift_old", 1],
	["res://src/systems/ghosts/ghost_mood.gd", "score", 7],
	["res://src/entities/player/player.gd", "set_in_interior", 2],
	["res://src/world/hut_interior/hut_portal.gd", "travel", 5],
	["res://src/world/hut_interior/hut_portal.gd", "arrive", 4],
	["res://src/systems/save/save_migration.gd", "migrate_4_to_5", 2],
]
## Saveable stubs: [class, save_id, save_order, identity group] (§3.1).
const SAVEABLES := [
	["Buildings", "buildings", 32, &"buildings"],
	["Ossuary", "ossuary", 36, &"ossuary"],
	["ChapelRites", "chapel", 37, &"chapel_rites"],
]
const SIGNALS := {
	"building_upgraded": 2, "interior_room_changed": 1, "bones_lifted": 1, "bones_reinterred": 2,
	"funeral_held": 3, "devotion_held": 2, "shed_supply_moved": 2,
}
const DATA_CLASSES := {
	"BuildingData": "res://src/systems/buildings/building_data.gd",
	"BuildingLevelData": "res://src/systems/buildings/building_level_data.gd",
	"BuildingsConfig": "res://src/systems/buildings/buildings_config.gd",
	"ShedConfig": "res://src/systems/buildings/shed_config.gd",
	"CryptConfig": "res://src/systems/corpse/crypt_config.gd",
	"OldGraveData": "res://src/systems/ossuary/old_grave_data.gd",
	"ChapelConfig": "res://src/systems/chapel/chapel_config.gd",
}
const SCENES := {
	"res://src/entities/building_site/building_site.tscn": true, "res://src/entities/shed_store/shed_store.tscn": true,
	"res://src/entities/crypt_niche/crypt_niche.tscn": true, "res://src/entities/ossuary_shelf/ossuary_shelf.tscn": true,
	"res://src/entities/sealed_passage/sealed_passage.tscn": true, "res://src/entities/catafalque/catafalque.tscn": true,
	"res://src/entities/chapel_altar/chapel_altar.tscn": true, "res://src/entities/building_door/building_door.tscn": true,
	"res://src/entities/mourner_set/mourner_set.tscn": false,
}


func test_stub_scripts_load_with_their_class_names() -> void:
	var global := _global_classes()
	for path: String in STUBS:
		var script := load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		assert_true(script.can_instantiate(), path + " parses")
		var cls: String = STUBS[path]
		assert_eq(global.get(cls), path, "class_name %s → %s" % [cls, path])
		if not IMPLEMENTED.has(cls):
			assert_true(script.source_code.contains("## STUB ("), cls + " is marked as stub")
		var names := _methods(script)
		for method: String in METHODS.get(cls, []):
			assert_true(names.has(method), "%s.%s" % [cls, method])


func test_contract_arities() -> void:
	for spec: Array in ARITY:
		_assert_arity(_path_of(spec[0]), spec[1], spec[2], spec[0])
	for spec: Array in EXISTING_ARITY:
		_assert_arity(spec[0], spec[1], spec[2], String(spec[0]).get_file())


func test_data_classes_are_registered() -> void:
	var global := _global_classes()
	for cls: String in DATA_CLASSES:
		assert_eq(global.get(cls), DATA_CLASSES[cls], cls)
		var res: Resource = (load(DATA_CLASSES[cls]) as GDScript).new()
		assert_true(res is Resource, cls)


func test_building_data_helpers() -> void:
	var empty := BuildingData.new()
	assert_eq([empty.max_level(), empty.level_data(1), empty.allows_corpse], [0, null, true])
	var crypt := Phase6Fixtures.building(&"crypt")
	assert_eq(crypt.max_level(), 3)
	assert_null(crypt.level_data(0), "level 0 is the site")
	assert_null(crypt.level_data(4))
	assert_eq(crypt.level_data(2).title, "Kühlgewölbe")
	var l := BuildingLevelData.new()
	assert_eq([l.level, l.minutes, l.coins, l.inputs, l.adds, l.model], [1, 180, 0, {} as Dictionary[StringName, int], PackedStringArray(), null])


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	var b := Buildings.new()
	assert_eq(b.site_rects, [] as Array[Rect2], "Buildings.site_rects export")
	assert_eq([b.level(&"crypt"), b.level(&"chapel"), b.level(&"shed")], [0, 0, 0], "§12: stub level 0 (old table active)")
	b.free()
	for cls: String in ["BuildingSite", "CryptNiche", "OssuaryShelf", "SealedPassage", "Catafalque", "ChapelAltar", "MournerSet",
			"InteriorRoom", "RoomExit", "BuildingDoor"]:
		var n: Node = (load(_path_of(cls)) as GDScript).new()
		assert_true(n is Node3D, cls)
		n.free()
	var room := InteriorRoom.new()
	assert_true(room.is_in_group(InteriorRoom.GROUP))
	assert_eq([room.room_id, room.hide_when_inactive, room.building_id, room.active], [&"hut", false, &"", false])
	room.free()
	for path: String in SCENES:
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene == null:
			continue
		var inst := scene.instantiate()
		assert_eq(inst.get_node_or_null(^"Interactable") != null, SCENES[path], path + " Interactable")
		inst.free()


func test_shed_store_is_a_chest() -> void:
	var store := (load("res://src/entities/shed_store/shed_store.tscn") as PackedScene).instantiate() as ShedStore
	assert_true(store is Chest)
	assert_eq([store.save_id, store.save_order], ["shed_store", 61], "§3.1")
	tree.root.add_child(store)
	assert_true(store.store() == store.storage, "store() = storage")
	assert_eq(store.save_state().keys(), ["storage"], "§5.1 {storage}")
	store.queue_free()
	await wait_frames(1)


func test_stub_members_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	var table: Node = (load("res://src/entities/morgue_table/morgue_table.gd") as GDScript).new()
	assert_eq([table.get(&"room"), table.get(&"requires_level"), table.get(&"retire_at_level")], [&"", 0, 0], "MorgueTable (P2)")
	assert_true(table.call(&"is_active"), "W0: the old table stays active")
	table.free()
	var plot: Node = (load("res://src/entities/grave/grave_plot.gd") as GDScript).new()
	assert_eq(plot.get(&"pit_variant"), &"", "GravePlot.pit_variant (P3)")
	plot.free()
	var inv := Inventory.new()
	assert_eq([inv.stack_multiplier, inv.stack_categories], [1, [] as Array[int]], "Inventory stack fields (P1)")
	inv.free()
	assert_eq(CorpseDecay.cold_factor_at(CorpseRecord.new(), 100), 1.0, "stub: no cold")
	assert_eq(GhostMood.score(9, 1, 0, null, GhostConfig.new(), 0, 3), GhostMood.score(9, 1, 0, null, GhostConfig.new()) + 3,
			"P4: the devotion bonus is added")


func test_player_interior_id() -> void:
	var player: Player = (load("res://src/entities/player/player.tscn") as PackedScene).instantiate()
	assert_eq(player.interior_id, &"")
	player.set_in_interior(true)
	assert_eq(player.interior_id, &"hut", "§3.4: empty room + inside → hut")
	player.set_in_interior(true, &"crypt")
	assert_eq(player.interior_id, &"crypt")
	player.set_in_interior(false, &"crypt")
	assert_eq([player.in_interior, player.interior_id], [false, &""])
	player.free()


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 7, "§3.3: 7 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – the devotion panel pages with the Phase-4 actions [ / ].
	for action: String in ["journal_page_prev", "journal_page_next", "interact", "ui_cancel"]:
		assert_true(InputMap.has_action(action), action)


func test_appended_corpse_locations() -> void:
	assert_eq(CorpseRecord.LOCATIONS, [&"dropoff", &"carried", &"table", &"ground", &"buried", &"niche", &"catafalque"] as Array[StringName])
	assert_eq([CorpseRecord.LOCATION_NICHE, CorpseRecord.LOCATION_CATAFALQUE], [&"niche", &"catafalque"])


func test_corpse_record_phase6_fields() -> void:
	var r := CorpseRecord.new()
	assert_eq([r.room, r.slot_id, r.cold_windows, r.service_held, r.service_day], [&"", "", PackedInt32Array(), false, 0])
	r.id = "c_1"
	r.location = CorpseRecord.LOCATION_NICHE
	r.room = &"crypt"
	r.slot_id = "niche_2"
	r.cold_windows = PackedInt32Array([38400, 38500, 400, 38500, -1, 300])
	r.service_held = true
	r.service_day = 32
	var back := CorpseRecord.from_dict(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict()))) as Dictionary)
	var native := CorpseRecord.from_dict(r.to_dict())
	for copy: CorpseRecord in [native]:
		assert_eq([copy.location, copy.room, copy.slot_id, copy.cold_windows, copy.service_held, copy.service_day],
				[&"niche", &"crypt", "niche_2", r.cold_windows, true, 32], "round trip")
	assert_eq(back.to_dict().keys(), r.to_dict().keys(), "JSON round trip keeps the keys")
	# Tolerant: missing keys = defaults; malformed triples dropped.
	var old := CorpseRecord.from_dict({"id": "c_2", "location": "table"})
	assert_eq([old.room, old.slot_id, old.cold_windows, old.service_held, old.service_day], [&"", "", PackedInt32Array(), false, 0])
	var odd := CorpseRecord.from_dict({"cold_windows": [10, 5, 400, 20, -1, 500.0, 30, 40, 0, 50, 60], "service_day": "x"})
	assert_eq(odd.cold_windows, PackedInt32Array([20, -1, 500]), "only valid triples")
	assert_eq(odd.service_day, 0)


func test_extended_data_classes() -> void:
	var e := EconomyConfig.new()
	assert_eq(e.quality_service, 1)
	assert_eq(e.quality_max, 20, "W0-Notizen: 20 since P4")
	assert_eq(Phase6Fixtures.economy_config().quality_max, 20)
	assert_eq(GhostConfig.new().devotion_robbed_cap, 8)
	var lines := GhostLines.new()
	assert_eq([lines.by_service, lines.by_devotion], [PackedStringArray(), {} as Dictionary[StringName, PackedStringArray]])
	assert_eq(ReputationConfig.new().event_points[&"reinterred"], 1)
	var piety := PietyConfig.new()
	assert_eq([piety.events[&"service"], piety.events[&"devotion"], piety.events[&"reinterred"]], [1, 1, 1])
	var d := DecayVisualConfig.new()
	assert_eq([d.niche_fly_scale, d.niche_wisp_scale, d.niche_chill_particles], [0.0, 0.5, 2])
	var ic := InteriorConfig.new()
	assert_eq([ic.fog_enabled, ic.fog_density, ic.shaft_role_as_window], [false, 0.0, false])
	# The hut's config is unchanged (fog off).
	var hut := Database.config(&"interior_config") as InteriorConfig
	assert_false(hut.fog_enabled)


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase6Fixtures.CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase6Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		var defaults: Resource = (real.get_script() as GDScript).new()
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
				assert_eq(defaults.get(prop.name), fixture.get(prop.name), "%s.%s = class default" % [name, prop.name])


func test_buildings_and_config_values() -> void:
	var c := Phase6Fixtures.buildings_config()
	assert_eq([c.unlock_flag, c.open_flag, c.intro_minute], [&"names_in_stone_complete", &"buildings_open", 360])
	assert_eq(c.goal_levels, {&"crypt": 2, &"chapel": 2, &"shed": 2})
	assert_eq([c.goal_services, c.goal_reinterred, c.chapter_id, c.goal_flag, c.cleared_flag],
			[1, 1, &"roof_and_earth", &"roof_and_earth_complete", &"building_sites_cleared"])
	# §2.1 table: coins, minutes per level.
	var expected := {&"crypt": [[20, 30, 35], [180, 210, 240], 1, true], &"chapel": [[25, 30, 40], [240, 210, 240], 2, true],
			&"shed": [[10, 15, 20], [120, 120, 150], 3, false]}
	var mandatory := 0
	var total := 0
	for b: BuildingData in Phase6Fixtures.buildings():
		assert_not_null(b)
		var e: Array = expected[b.id]
		var coins := []
		var minutes := []
		for lvl: int in [1, 2, 3]:
			var l := b.level_data(lvl)
			coins.append(l.coins)
			minutes.append(l.minutes)
			assert_true(l.title != "" and l.coin_part_label != "" and l.text != "" and not l.adds.is_empty(), "%s %d texts" % [b.id, lvl])
			for item: StringName in l.inputs:
				assert_true(item in [&"wood", &"stone", &"clay", &"workstone", &"iron_bar", &"iron_fittings", &"linen", &"gold_leaf"],
						"%s %d input %s" % [b.id, lvl, item])
			total += l.coins
			if lvl <= 2:
				mandatory += l.coins
		assert_eq([coins, minutes, b.order, b.allows_corpse], e, String(b.id))
		assert_eq([b.site_id, b.door_id, b.room_id], ["site_" + String(b.id), "door_" + String(b.id), b.id])
		assert_true(b.prompt_enter.begins_with("[E] ") and b.prompt_exit.begins_with("[E] "), String(b.id))
	assert_eq([mandatory, total], [130, 225], "§2.1 sums")
	assert_eq(Phase6Fixtures.building(&"crypt").level_data(1).inputs, {&"stone": 12, &"wood": 6, &"clay": 4, &"iron_fittings": 2})
	assert_eq(Phase6Fixtures.building(&"chapel").level_data(3).inputs, {&"workstone": 4, &"gold_leaf": 2, &"linen": 3, &"iron_fittings": 2})
	assert_eq(Phase6Fixtures.building(&"crypt").prompt_exit, "[E] Hinaufgehen")


func test_crypt_chapel_shed_config_values() -> void:
	var k := Phase6Fixtures.crypt_config()
	assert_eq([Array(k.niches_by_level), Array(k.ossuary_by_level)], [[0, 2, 4, 6], [0, 3, 5, 6]])
	for i: int in 4:
		assert_almost(k.niche_factor_by_level[i], [1.0, 0.5, 0.4, 0.3][i])
		assert_almost(k.room_factor_by_level[i], [1.0, 0.8, 0.7, 0.6][i])
	assert_eq([k.stench_exempt, k.lift_minutes, k.reinter_minutes, k.reinter_fee, k.box_item, k.full_item, k.min_rest_years,
			k.passage_level, k.grille_level, k.passage_clue, k.room_id, k.niche_wait_minutes],
			[true, 60, 20, 4, &"bone_box", &"bone_box_full", 30, 2, 3, &"c_crypt_draft", &"crypt", 60])
	var ch := Phase6Fixtures.chapel_config()
	assert_eq([ch.service_minutes, ch.service_start_min, ch.service_start_max, ch.candle_item, ch.candle_amount, ch.service_needs_dress,
			ch.devotion_minutes, ch.devotion_robbed_cap, ch.room_id], [45, 480, 1020, &"altar_candle", 1, true, 30, 8, &"chapel"])
	assert_almost(ch.service_min_freshness, 0.3)
	assert_eq([Array(ch.service_fee_by_level), Array(ch.service_rep_by_level), Array(ch.mourners_by_level), Array(ch.devotion_mood_by_level)],
			[[0, 3, 5, 7], [0, 1, 2, 3], [0, 0, 2, 4], [0, 1, 2, 3]])
	var s := Phase6Fixtures.shed_config()
	assert_eq([Array(s.slots_by_level), Array(s.stack_mult_by_level), s.stack_categories, s.fetch_min_level,
			Array(s.fetch_minutes_by_level), s.store_min_level, s.excluded_items],
			[[0, 24, 32, 40], [1, 1, 1, 2], [ItemData.Category.RESOURCE, ItemData.Category.MATERIAL] as Array[int], 2, [0, 0, 10, 0], 3,
			[&"bone_box_full"] as Array[StringName]])


func test_old_grave_fixtures() -> void:
	var cfg := Phase6Fixtures.crypt_config()
	var liftable := PackedStringArray()
	for g: OldGraveData in Phase6Fixtures.old_graves():
		assert_not_null(g)
		assert_true(g.display_name != "" and g.born_year < g.died_year and g.stone_model != null, g.grave_id)
		var ok := Phase6Fixtures.YEAR - g.died_year >= cfg.min_rest_years
		assert_eq(ok, g.reinter_line != "", "%s: reinter_line only for liftable graves" % g.grave_id)
		if ok:
			liftable.append(g.grave_id)
	assert_eq(liftable, Phase6Fixtures.LIFTABLE_IDS, "§2.3: 6 liftable, old_01 / old_08 in their rest period")
	assert_eq(liftable.size(), cfg.ossuary_by_level[3], "= the ossuary places on level 3")
	var agnes := Phase6Fixtures.old_grave("old_02")
	assert_eq([agnes.display_name, agnes.born_year, agnes.died_year], ["Agnes Hollweg", 1741, 1789])
	assert_eq(Phase6Fixtures.old_grave("old_02", 1820).died_year, 1820, "override for rest-period tests")
	assert_eq(Phase6Fixtures.old_grave("old_02").died_year, 1789, "the fixture itself is unchanged")
	assert_eq(Phase6Fixtures.old_grave_record("old_04").state, GraveRecord.State.OLD)
	# The old graves are the plots of the approved layout.
	var ids := PackedStringArray()
	for g: Variant in Phase6Fixtures.layout_p5().get("old_graves", []):
		ids.append(str((g as Dictionary).get("id", "")))
	assert_eq(ids, Phase6Fixtures.OLD_GRAVE_IDS)


func test_item_recipe_clue_fixtures() -> void:
	var stacks := {&"altar_candle": 10, &"bone_box": 5, &"bone_box_full": 3}
	for id: StringName in Phase6Fixtures.ITEM_IDS:
		var item := Phase6Fixtures.item(id)
		assert_not_null(item, String(id))
		if item != null:
			assert_eq([item.id, item.category, item.max_stack], [id, ItemData.Category.MATERIAL, stacks[id]], String(id))
			assert_true(item.display_name != "")
	var box := Phase6Fixtures.recipe(&"bone_box")
	assert_eq([box.inputs, box.output_id, box.output_amount, box.craft_minutes, box.station, box.background],
			[{&"wood": 3}, &"bone_box", 1, 15, &"workbench", false])
	var clue := Phase6Fixtures.clue(&"c_crypt_draft")
	assert_eq([clue.id, clue.title], [&"c_crypt_draft", "Der kalte Zug"])
	assert_true(clue.kind in ClueData.KINDS)


func test_other_config_fixtures() -> void:
	for kind: StringName in Phase6Fixtures.EXTENDED_CONFIG_NAMES:
		assert_not_null(Phase6Fixtures.config(kind), String(kind))
	var e := Phase6Fixtures.economy_config()
	assert_eq([e.quality_service, e.quality_max], [1, 20])
	# §2.7: 20 = the Phase-5 maximum 19 + „Ausgesegnet".
	assert_eq(Phase5Fixtures.economy_config().quality_max + e.quality_service, e.quality_max)
	assert_eq(Phase6Fixtures.reputation_config().event_points[&"reinterred"], 1)
	var p := Phase6Fixtures.piety_config().events
	assert_eq([p[&"service"], p[&"devotion"], p[&"reinterred"]], [1, 1, 1])
	assert_eq(Phase6Fixtures.ghost_config().devotion_robbed_cap, 8)
	var d := Phase6Fixtures.decay_visual_config()
	assert_eq([d.niche_fly_scale, d.niche_wisp_scale, d.niche_chill_particles], [0.0, 0.5, 2])
	var lines := Phase6Fixtures.ghost_lines()
	assert_eq(lines.by_service.size(), 3)
	assert_eq(lines.by_devotion.keys(), [&"default", &"robbed"])
	assert_eq(lines.by_design.keys(), Phase5Fixtures.ghost_lines().by_design.keys(), "Phase-5 lines kept")


func test_room_fixtures() -> void:
	var crypt := Phase6Fixtures.room_config(&"crypt")
	assert_eq([crypt.camera_distance, crypt.camera_zoom_min, crypt.camera_zoom_max], [10.0, 8.0, 12.0])
	assert_true(crypt.fog_enabled and crypt.shaft_role_as_window)
	assert_almost(crypt.fog_density, 0.02)
	assert_true(crypt.lantern_shadow_below > 1.0, "crypt lantern shadow always on")
	assert_eq([crypt.sun_day_energy, crypt.sun_night_energy], [0.0, 0.0], "no sun underground")
	assert_true(crypt.window_day_color.is_equal_approx(Color("#9AA8B8")))
	var chapel := Phase6Fixtures.room_config(&"chapel")
	assert_eq([chapel.camera_distance, chapel.camera_zoom_min, chapel.camera_zoom_max, chapel.fog_enabled], [11.0, 9.0, 13.0, false])
	assert_eq([chapel.candle_night_energy, chapel.candle_day_energy], [0.6, 0.2])
	var shed := Phase6Fixtures.room_config(&"shed")
	assert_eq([shed.camera_distance, shed.camera_zoom_min, shed.camera_zoom_max], [8.0, 7.0, 10.0])
	assert_eq(Phase6Fixtures.room_config(&"hut").camera_distance, 9.0, "hut unchanged")
	var origins := []
	for id: StringName in Phase6Fixtures.ROOMS:
		origins.append((Phase6Fixtures.ROOMS[id] as Dictionary).origin)
	assert_eq(origins, [Vector3(0, 0, -200), Vector3(60, 0, -200), Vector3(120, 0, -200), Vector3(180, 0, -200)], "§4.7: 60 m apart")
	assert_eq(Phase6Fixtures.NICHES.size(), 6)
	var per_level := [0, 0, 0, 0]
	for slot: String in Phase6Fixtures.NICHES:
		for lvl: int in range(int(Phase6Fixtures.NICHES[slot]), 4):
			per_level[lvl] += 1
	assert_eq(per_level, Array(Phase6Fixtures.crypt_config().niches_by_level), "niches open per level = niches_by_level")


func test_fixture_helpers() -> void:
	var b := Phase6Fixtures.crypt_at(2, tree)
	assert_true(b.is_inside_tree())
	assert_eq(tree.get_first_node_in_group(Buildings.GROUP), b, "found through the group")
	assert_eq([b.level(&"crypt"), b.level(&"chapel"), b.level(&"shed")], [2, 0, 0])
	b.free()
	var all := Phase6Fixtures.buildings_at({&"crypt": 3, &"chapel": 1, &"shed": 2})
	assert_eq(all.levels(), {&"crypt": 3, &"chapel": 1, &"shed": 2} as Dictionary[StringName, int])
	all.free()
	var r := Phase6Fixtures.record_in(CorpseRecord.LOCATION_NICHE, &"crypt", "niche_1", PackedInt32Array([500, -1, 500]))
	assert_eq([r.location, r.room, r.slot_id, r.cold_windows], [&"niche", &"crypt", "niche_1", PackedInt32Array([500, -1, 500])])
	var s := Phase6Fixtures.service_corpse(0.5)
	assert_eq([s.location, s.room, s.dress, s.freshness, s.service_held], [&"catafalque", &"chapel", &"gown", 0.5, false])
	var g := Phase6Fixtures.serviced_grave(31)
	assert_eq([g.state, g.marker_id], [GraveRecord.State.MARKED, &"wooden_cross"])
	var inv := Phase6Fixtures.inv_with({&"altar_candle": 2})
	assert_eq(inv.count(&"altar_candle"), 2)
	inv.free()
	assert_true(Phase6Fixtures.layout_p5().get("sections", []).size() > 0, "layout_p5.json readable")


func test_layout_p5_is_the_approved_layout() -> void:
	# W0: data/world/graveyard_layout.json is still the approved Phase-5 layout (W-Welt changes it in W2).
	assert_eq(FileAccess.get_file_as_string(Phase6Fixtures.LAYOUT_P5).length() > 0, true)
	assert_true(Phase6Fixtures.layout_p5().has("workyard"), "Phase-5 layout (workyard)")


func test_database_phase6_folders() -> void:
	# The real data folders are the owners' (P1 buildings, P3 old graves) – empty until W1.
	for b: Resource in Database.buildings():
		assert_true(b.get("id") != &"", "keyed by id")
	for g: Resource in Database.old_graves():
		assert_true(str(g.get("grave_id")) != "", "keyed by grave_id")
	assert_null(Database.building(&"nope"))
	assert_null(Database.old_grave("nope"))
	for name: StringName in Phase6Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	# Room configs: data/config/interiors/<room_id>.tres (P6), missing → interior_config.
	assert_eq(Database.interior_config(&"nope"), Database.config(&"interior_config"))
	assert_eq(Database.interior_config(&"hut"), Database.config(&"interior_config"), "the hut uses interior_config")
	var orders: Array = []
	for b: Resource in Database.buildings():
		orders.append(int(b.get("order")))
	var sorted := orders.duplicate()
	sorted.sort()
	assert_eq(orders, sorted, "buildings sorted by order")


func test_save_format_v5_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 5)
	assert_eq(SaveFileIO.FORMAT_VERSION, 5)
	assert_eq(SaveManager.FORMAT_VERSION, 5)
	assert_eq(SaveMigration.V5_EMPTY_NODES, PackedStringArray(["buildings", "ossuary", "chapel", "shed_store"]))
	var state := {"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {}}}
	assert_eq(SaveMigration.migrate(state, 5), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 6), {}, "newer → corrupt")
	var v5 := SaveMigration.migrate_4_to_5(state, {"day": 5})
	assert_false(is_same(v5, state), "deep copy")
	assert_eq(state.nodes, {"corpse_manager": {}}, "input unchanged")
	if not IMPLEMENTED.has("SaveMigration"):
		assert_eq(v5, state, "W0: identity")
	var from_v4 := SaveMigration.migrate(state, 4, {"day": 5})
	assert_true(from_v4.get("autoloads") is Dictionary and from_v4.get("nodes") is Dictionary)
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("workshop"), "v1 → … → v5 chain")


func test_save_v4_fixtures_exist() -> void:
	for name: String in Phase6Fixtures.SAVES_V4:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase6Fixtures.save_v4_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 4, name)


# --- helpers ----------------------------------------------------------------------------------

func _assert_arity(path: String, method: String, args: int, label: String) -> void:
	var script := load(path) as GDScript
	var found := false
	for m: Dictionary in script.get_script_method_list():
		if String(m.name) == method:
			found = true
			assert_eq((m.args as Array).size(), args, "%s.%s arguments" % [label, method])
	assert_true(found, "%s.%s" % [label, method])


func _global_classes() -> Dictionary:
	var global := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		global[String(entry["class"])] = String(entry["path"])
	return global


func _methods(script: GDScript) -> Dictionary:
	var names := {}
	for m: Dictionary in script.get_script_method_list():
		names[String(m.name)] = true
	return names


func _path_of(cls: String) -> String:
	for path: String in STUBS:
		if STUBS[path] == cls:
			return path
	return ""
