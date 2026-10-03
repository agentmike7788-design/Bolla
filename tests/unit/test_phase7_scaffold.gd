extends TestCase
## Lead / W0 (docs/PHASE7_DESIGN.md §12): the Phase-7 scaffold – every stub class loads with its
## contract signature, every new data class / config .tres holds valid contract values, the extensions
## of existing data classes, the 11 EventBus signals, no new input actions, the appended harvest kinds,
## Database folders, save format v6 + migration chain 1 → … → 6, and the W1 fixtures
## (tests/fixtures/phase7, Phase7Fixtures).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["RegionRoot", "RegionPortal", "RegionTravel", "HouseDoor", "NpcLod"]
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/world/regions/region_root.gd": "RegionRoot",
	"res://src/world/regions/region_portal.gd": "RegionPortal",
	"res://src/world/regions/region_travel.gd": "RegionTravel",
	"res://src/entities/house_door/house_door.gd": "HouseDoor",
	"res://src/systems/npc/npc_lod.gd": "NpcLod",
	# P2
	"res://src/systems/village/shop_rules.gd": "ShopRules",
	"res://src/systems/village/village_shops.gd": "VillageShops",
	"res://src/systems/village/relationship_rules.gd": "RelationshipRules",
	"res://src/systems/village/relationships.gd": "Relationships",
	"res://src/entities/shop_counter/shop_counter.gd": "ShopCounter",
	# P3
	"res://src/systems/village/order_rules.gd": "OrderRules",
	"res://src/systems/village/orders.gd": "Orders",
	"res://src/systems/village/village.gd": "Village",
	"res://src/entities/village_board/village_board.gd": "VillageBoard",
	"res://src/entities/mourning_ribbon/mourning_ribbon.gd": "MourningRibbon",
	"res://src/entities/poor_box/poor_box.gd": "PoorBox",
	"res://src/entities/register_copy/register_copy.gd": "RegisterCopy",
	# P4
	"res://src/systems/anatomy/specimen_rules.gd": "SpecimenRules",
	"res://src/systems/anatomy/specimens.gd": "Specimens",
	# P7
	"res://src/entities/pult_store/pult_store.gd": "PultStore",
	"res://src/systems/anatomy/pult_rules.gd": "PultRules",
	"res://src/systems/anatomy/collection_rules.gd": "CollectionRules",
	"res://src/entities/collection_shelf/collection_shelf.gd": "CollectionShelf",
	# P8
	"res://src/systems/anatomy/lecture_rules.gd": "LectureRules",
	"res://src/systems/anatomy/lectures.gd": "Lectures",
	"res://src/systems/anatomy/deduction_rules.gd": "DeductionRules",
	"res://src/systems/anatomy/deductions.gd": "Deductions",
	"res://src/entities/lecture_set/lecture_set.gd": "LectureSet",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"RegionRoot": ["get_waypoint", "get_waypoint_facing", "ground_height", "spawn_transform", "camera_profile", "apply_region",
			"find", "current"],
	"RegionTravel": ["block_reason", "travel"],
	"RegionPortal": ["can_interact", "get_interaction_prompt", "interact"],
	"HouseDoor": ["is_open_now", "next_opening", "exit_transform", "can_interact", "interact", "find"],
	"NpcLod": ["update_now", "lod_of"],
	"RelationshipRules": ["tier", "start_value", "word"],
	"Relationships": ["value", "tier", "met", "meet", "add", "note_talk", "gift_block_reason", "give_gift", "count_at_least",
			"remark", "on_specimen_sold", "on_specimen_returned", "save_state", "load_state"],
	"ShopRules": ["price", "buy_price", "buy_block_reason", "sell_block_reason"],
	"VillageShops": ["shop", "is_open", "offers", "wants", "buy", "sell", "save_state", "load_state"],
	"ShopCounter": ["can_interact", "get_interaction_prompt", "interact"],
	"OrderRules": ["offer_block_reason", "bury_result", "stone_matches", "deliver_ready", "board_pick"],
	"Orders": ["offers", "active", "state", "accept", "turn_in", "complete", "note_grave_completed", "note_stone_set",
			"note_section_progress", "note_harvest", "apply_morning", "done_count", "done_givers", "save_state", "load_state"],
	"Village": ["is_open", "apply_morning", "post_load", "apply_minute", "consecration_price", "pay_consecration", "consecrate",
			"buy_round", "donate", "mourning_house", "goal_progress", "check_goal", "save_state", "load_state"],
	"VillageBoard": ["can_interact", "get_interaction_prompt", "interact"],
	"PoorBox": ["can_interact", "get_interaction_prompt", "interact"],
	"RegisterCopy": ["can_interact", "get_interaction_prompt", "interact"],
	"MourningRibbon": ["refresh"],
	"SpecimenRules": ["harvest_block_reason", "clarity", "is_spoiled", "clarity_word", "price", "finding_for"],
	"Specimens": ["get_record", "held", "of_corpse", "label", "harvest", "sell", "expertise", "inspect", "consume", "make_bone",
			"seal", "make_display", "return_block_reason", "return_to_grave", "note_cold", "check_spoiled", "kept",
			"save_state", "load_state", "post_load"],
	"PultStore": ["store"],
	"PultRules": ["medicine_block_reason", "seal_block_reason", "display_block_reason", "bone_block_reason", "inspect_block_reason"],
	"CollectionRules": ["slot_for", "accepts", "completed_sets", "price_bonus"],
	"CollectionShelf": ["standing", "sets_done", "place", "take", "save_state", "load_state"],
	"LectureRules": ["is_lecture_night", "block_reason", "fee", "rumor"],
	"Lectures": ["invited", "tonight", "door_open", "hold", "learn", "known_teachings", "apply_morning", "save_state", "load_state"],
	"DeductionRules": ["matches", "find"],
	"Deductions": ["add_card", "cards", "can_deduce", "deduce", "deduced", "save_state", "load_state"],
	"LectureSet": ["show_lecture", "hide_lecture"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["RegionRoot", "get_waypoint", 1], ["RegionRoot", "spawn_transform", 1], ["RegionRoot", "apply_region", 1],
	["RegionRoot", "ground_height", 1], ["RegionRoot", "find", 2], ["RegionRoot", "current", 1],
	["RegionTravel", "block_reason", 2], ["RegionTravel", "travel", 5],
	["HouseDoor", "find", 2], ["NpcLod", "lod_of", 1],
	["RelationshipRules", "tier", 2], ["RelationshipRules", "start_value", 4], ["RelationshipRules", "word", 1],
	["Relationships", "add", 3], ["Relationships", "gift_block_reason", 3], ["Relationships", "give_gift", 3],
	["Relationships", "count_at_least", 1], ["Relationships", "remark", 1],
	["ShopRules", "price", 4], ["ShopRules", "buy_price", 3], ["ShopRules", "buy_block_reason", 7], ["ShopRules", "sell_block_reason", 5],
	["VillageShops", "buy", 4], ["VillageShops", "sell", 4], ["VillageShops", "offers", 1], ["VillageShops", "wants", 1],
	["OrderRules", "offer_block_reason", 5], ["OrderRules", "bury_result", 3], ["OrderRules", "stone_matches", 2],
	["OrderRules", "deliver_ready", 2], ["OrderRules", "board_pick", 4],
	["Orders", "offers", 1], ["Orders", "accept", 1], ["Orders", "turn_in", 2], ["Orders", "note_grave_completed", 2],
	["Orders", "note_stone_set", 1], ["Orders", "note_section_progress", 3], ["Orders", "note_harvest", 1], ["Orders", "apply_morning", 1],
	["Village", "apply_morning", 1], ["Village", "apply_minute", 2], ["Village", "pay_consecration", 1], ["Village", "buy_round", 1],
	["Village", "donate", 1], ["Village", "mourning_house", 1],
	["SpecimenRules", "harvest_block_reason", 7], ["SpecimenRules", "clarity", 3], ["SpecimenRules", "is_spoiled", 3],
	["SpecimenRules", "clarity_word", 2], ["SpecimenRules", "price", 4], ["SpecimenRules", "finding_for", 3],
	["Specimens", "harvest", 4], ["Specimens", "sell", 2], ["Specimens", "expertise", 2], ["Specimens", "inspect", 1],
	["Specimens", "consume", 3], ["Specimens", "make_bone", 2], ["Specimens", "seal", 2], ["Specimens", "make_display", 2],
	["Specimens", "return_block_reason", 2], ["Specimens", "return_to_grave", 3], ["Specimens", "note_cold", 2],
	["Specimens", "check_spoiled", 1], ["Specimens", "kept", 1],
	["PultRules", "medicine_block_reason", 5], ["PultRules", "seal_block_reason", 4], ["PultRules", "display_block_reason", 3],
	["PultRules", "bone_block_reason", 4], ["PultRules", "inspect_block_reason", 3],
	["CollectionRules", "slot_for", 1], ["CollectionRules", "accepts", 2], ["CollectionRules", "completed_sets", 3],
	["CollectionRules", "price_bonus", 1], ["CollectionShelf", "place", 2], ["CollectionShelf", "take", 2],
	["LectureRules", "is_lecture_night", 3], ["LectureRules", "block_reason", 5], ["LectureRules", "fee", 3], ["LectureRules", "rumor", 4],
	["Lectures", "door_open", 1], ["Lectures", "hold", 2], ["Lectures", "learn", 1], ["Lectures", "apply_morning", 1],
	["DeductionRules", "matches", 3], ["DeductionRules", "find", 3],
	["Deductions", "add_card", 2], ["Deductions", "cards", 1], ["Deductions", "deduce", 3], ["Deductions", "deduced", 1],
	["LectureSet", "show_lecture", 1],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/entities/player/player.gd": ["set_region"],  # P1
	"res://src/world/camera/camera_rig.gd": ["set_base_profile"],  # P1
	"res://src/entities/npc/npc.gd": ["set_lod"],  # P1
	"res://src/systems/npc/schedule_resolver.gd": ["entry_at"],  # P1 (+ day)
	"res://src/systems/expansion/expansion_manager.gd": ["try_unlock"],  # P3
	"res://src/systems/graveyard/graveyard.gd": ["replace_old_marker"],  # P3
	"res://src/systems/inventory/inventory.gd": ["add_unique", "remove_uid", "uids", "has_uid"],  # P4
	"res://src/systems/corpse/corpse_care.gd": ["organ_block_reason", "harvest_organ"],  # P4
	"res://src/entities/morgue_table/morgue_table.gd": ["request_organ"],  # P4
	"res://src/entities/corpse/corpse.gd": ["set_covered"],  # P4
	"res://src/systems/ghosts/ghost_mood.gd": ["robbed_count", "robbed_penalty"],  # P4
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_4_to_5", "migrate_5_to_6"],  # P6
	"res://src/systems/anatomy/specimen_record.gd": ["to_dict", "from_dict"],  # W0 (data class)
}
## [script, method, args] of the extended signatures of existing classes.
const EXISTING_ARITY := [
	["res://src/entities/player/player.gd", "set_region", 1],
	["res://src/world/camera/camera_rig.gd", "set_base_profile", 1],
	["res://src/entities/npc/npc.gd", "set_lod", 1],
	["res://src/systems/npc/schedule_resolver.gd", "entry_at", 3],
	["res://src/systems/expansion/expansion_manager.gd", "try_unlock", 1],
	["res://src/systems/graveyard/graveyard.gd", "replace_old_marker", 2],
	["res://src/systems/inventory/inventory.gd", "add_unique", 2],
	["res://src/systems/inventory/inventory.gd", "remove_uid", 1],
	["res://src/systems/inventory/inventory.gd", "uids", 1],
	["res://src/systems/inventory/inventory.gd", "has_uid", 1],
	["res://src/systems/corpse/corpse_care.gd", "organ_block_reason", 4],
	["res://src/systems/corpse/corpse_care.gd", "harvest_organ", 4],
	["res://src/entities/morgue_table/morgue_table.gd", "request_organ", 2],
	["res://src/entities/corpse/corpse.gd", "set_covered", 1],
	["res://src/systems/ghosts/ghost_mood.gd", "robbed_count", 1],
	["res://src/systems/save/save_migration.gd", "migrate_5_to_6", 2],
]
## Saveable chests (§3.1): [scene, class, save_id, save_order].
const CHESTS := [
	["res://src/entities/pult_store/pult_store.tscn", "PultStore", "pult_store", 62],
	["res://src/entities/collection_shelf/collection_shelf.tscn", "CollectionShelf", "collection_shelf", 63],
]
const SIGNALS := {
	"region_changed": 1, "shop_trade": 4, "relationship_changed": 5, "villager_remarked": 2, "order_changed": 2,
	"specimen_changed": 2, "screen_veil_changed": 1, "ground_consecrated": 1, "collection_set_completed": 2,
	"lecture_held": 4, "cause_deduced": 2,
}
const DATA_CLASSES := {
	"RegionConfig": "res://src/world/regions/region_config.gd",
	"NpcConfig": "res://src/systems/npc/npc_config.gd",
	"VillagerData": "res://src/systems/village/villager_data.gd",
	"ShopData": "res://src/systems/village/shop_data.gd",
	"RelationshipConfig": "res://src/systems/village/relationship_config.gd",
	"VillageConfig": "res://src/systems/village/village_config.gd",
	"OrderData": "res://src/systems/village/order_data.gd",
	"OrdersConfig": "res://src/systems/village/orders_config.gd",
	"AnatomyConfig": "res://src/systems/anatomy/anatomy_config.gd",
	"SpecimenFindingData": "res://src/systems/anatomy/specimen_finding_data.gd",
	"MedicineData": "res://src/systems/anatomy/medicine_data.gd",
	"CollectionSetData": "res://src/systems/anatomy/collection_set_data.gd",
	"TeachingData": "res://src/systems/anatomy/teaching_data.gd",
	"DeductionData": "res://src/systems/anatomy/deduction_data.gd",
}
const SCENES := {
	"res://src/entities/region_portal/region_portal.tscn": true, "res://src/entities/house_door/house_door.tscn": true,
	"res://src/entities/shop_counter/shop_counter.tscn": true, "res://src/entities/village_board/village_board.tscn": true,
	"res://src/entities/poor_box/poor_box.tscn": true, "res://src/entities/register_copy/register_copy.tscn": true,
	"res://src/entities/pult_store/pult_store.tscn": true, "res://src/entities/collection_shelf/collection_shelf.tscn": true,
	"res://src/entities/mourning_ribbon/mourning_ribbon.tscn": false, "res://src/entities/lecture_set/lecture_set.tscn": false,
}
const ORGANS: Array[StringName] = [&"heart", &"lung", &"stomach", &"liver", &"kidneys", &"eyes", &"hand"]


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
	assert_eq(global.get("SpecimenRecord"), "res://src/systems/anatomy/specimen_record.gd")
	assert_eq(global.get("Phase7Fixtures"), "res://tests/fixtures/phase7/phase7_fixtures.gd")


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in Phase7Fixtures.SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	var lod := NpcLod.new()
	assert_true(lod.is_in_group(NpcLod.GROUP))
	assert_false(lod.is_in_group(&"saveable"), "NpcLod is not saved (§3.1)")
	lod.free()
	for cls: String in ["RegionRoot", "RegionPortal", "HouseDoor", "ShopCounter", "VillageBoard", "MourningRibbon", "PoorBox",
			"RegisterCopy", "LectureSet"]:
		var n: Node = (load(_path_of(cls)) as GDScript).new()
		assert_true(n is Node3D, cls)
		n.free()
	var root := RegionRoot.new()
	assert_true(root.is_in_group(RegionRoot.GROUP))
	assert_eq([root.region_id, root.hide_when_inactive, root.active], [&"graveyard", true, false])
	root.free()
	var portal := RegionPortal.new()
	assert_eq([portal.requires_flag, portal.prompt], [&"village_open", "[E] Nach Hollerbrück (30 Min)"])
	portal.free()
	for path: String in SCENES:
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene == null:
			continue
		var inst := scene.instantiate()
		assert_eq(inst.get_node_or_null(^"Interactable") != null, SCENES[path], path + " Interactable")
		inst.free()


func test_chest_stubs() -> void:
	for spec: Array in CHESTS:
		var chest := (load(spec[0]) as PackedScene).instantiate() as Chest
		assert_not_null(chest, spec[1])
		if chest == null:
			continue
		assert_eq([chest.save_id, chest.save_order], [spec[2], spec[3]], "%s §3.1" % spec[1])
		tree.root.add_child(chest)
		assert_true(chest.is_in_group(&"saveable"))
		assert_true(chest.storage != null, spec[1] + " storage")
		assert_true(chest.save_state().has("storage"), "§5.1 {storage, …}")
		chest.queue_free()
	await wait_frames(1)
	assert_eq(PultStore.SLOT_COUNT, 8)
	assert_eq([CollectionShelf.SLOT_COUNT, CollectionShelf.COLLECTION_PANEL], [7, &"collection"])


func test_stub_members_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	var player: Player = (load("res://src/entities/player/player.tscn") as PackedScene).instantiate()
	assert_eq(player.region_id, &"graveyard", "Player.region_id (P1)")
	player.set_region(&"village")
	assert_eq(player.region_id, &"village")
	player.free()
	var npc := Npc.new()
	assert_eq([npc.region_id, npc.hide_flag], [&"graveyard", &""], "Npc (P1)")
	npc.free()
	var room := InteriorRoom.new()
	assert_eq(room.region_id, &"graveyard", "InteriorRoom.region_id (P1)")
	room.free()
	var exit := RoomExit.new()
	assert_eq(exit.door_id, &"", "RoomExit.door_id (P1)")
	exit.free()
	var inv := Inventory.new()
	assert_eq([inv.uids(), inv.has_uid("sp_0001")], [PackedStringArray(), false], "Inventory uid stubs (P4)")
	inv.free()
	# ScheduleResolver: the old two-argument calls stay bit-identical.
	var carter := Database.schedule(&"carter") as NpcSchedule
	for minute: int in [0, 420, 460, 600, 700, 1100, 1300]:
		assert_eq(ScheduleResolver.entry_at(carter, minute), ScheduleResolver.entry_at(carter, minute, -1), "entry_at %d" % minute)
	assert_eq(GhostMood.robbed_penalty(null), 0)


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 11, "§3.3: 11 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – panels over [E], Esc closes, [ / ] page.
	for action: String in ["journal_page_prev", "journal_page_next", "interact", "ui_cancel"]:
		assert_true(InputMap.has_action(action), action)


func test_appended_harvest_kinds() -> void:
	assert_eq(CorpseRecord.HARVEST_KINDS, [&"hair", &"teeth", &"heart", &"lung", &"stomach", &"liver", &"kidneys", &"eyes", &"hand"] as Array[StringName],
			"§3.4: the seven organs appended")
	assert_eq(CorpseRecord.ORGAN_KINDS, ORGANS)
	assert_eq(AnatomyConfig.ORGANS, ORGANS)
	assert_eq(GhostMood.ROBBED_KINDS, [&"hair", &"teeth"] as Array[StringName], "Phase-6 robbed count unchanged until P4")


func test_corpse_record_phase7_fields() -> void:
	var r := CorpseRecord.new()
	assert_eq([r.hidden_cause, r.returned, r.revealed_cause], [&"", [] as Array[StringName], &""])
	r.id = "c_1"
	r.harvested = [&"hair", &"heart", &"eyes"] as Array[StringName]
	r.returned = [&"heart"] as Array[StringName]
	r.hidden_cause = &"arsenic"
	r.revealed_cause = &"arsenic"
	var back := CorpseRecord.from_dict(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict()))) as Dictionary)
	var native := CorpseRecord.from_dict(r.to_dict())
	assert_eq([native.harvested, native.returned, native.hidden_cause, native.revealed_cause],
			[r.harvested, r.returned, &"arsenic", &"arsenic"], "round trip")
	assert_eq(back.to_dict().keys(), r.to_dict().keys(), "JSON round trip keeps the keys")
	assert_eq(r.to_dict().size(), 38, "35 Phase-6 record fields + 3")
	var old := CorpseRecord.from_dict({"id": "c_2", "harvested": ["hair"]})
	assert_eq([old.hidden_cause, old.returned, old.revealed_cause], [&"", [] as Array[StringName], &""], "tolerant")
	var odd := CorpseRecord.from_dict({"harvested": ["teeth", "liver"], "returned": ["liver", "heart", "liver", 3]})
	assert_eq(odd.returned, [&"liver"] as Array[StringName], "returned ⊆ harvested, unique")


func test_extended_data_classes() -> void:
	# W0-Notizen 4: the organ maluses / corpse_balm are fixture values until P4 / P7 (class default unchanged).
	var e := Phase7Fixtures.economy_config()
	for organ: StringName in ORGANS:
		assert_eq(e.harvest_malus[organ], -3 if organ in [&"eyes", &"hand"] else -2, "harvest_malus %s" % organ)
	assert_eq([e.harvest_malus[&"hair"], e.harvest_malus[&"teeth"], e.quality_max], [-1, -2, 20], "§2.11 quality_max stays 20")
	var rep := ReputationConfig.new().event_points
	assert_eq([rep[&"organ_taken"], rep[&"organ_taken_grave"], rep[&"lecture_rumor"], rep[&"donation"], rep[&"order_failed"]],
			[-3, -5, -4, 1, -1])
	var piety := PietyConfig.new().events
	assert_eq([piety[&"organ_taken"], piety[&"lecture_attended"], piety[&"specimen_returned"], piety[&"specimen_returned_grave"]],
			[-6, -3, 3, 5])
	assert_eq(Phase7Fixtures.prep_config().balm_items, [&"juniper", &"herb_bundle", &"corpse_balm"] as Array[StringName], "juniper stays first")
	var lines := GhostLines.new()
	assert_eq([lines.by_organ, lines.by_returned], [PackedStringArray(), PackedStringArray()])
	assert_false(ItemData.new().unique)
	assert_eq(SectionData.new().unlock_flag, &"")
	var s := StoryCorpseData.new()
	assert_eq([s.after_flag, s.after_days, s.section, s.requires_flag, s.due_flag], [&"", 0, &"", &"", &""])
	var entry := ScheduleEntry.new()
	assert_eq([entry.region, entry.today_flag], [&"", &""], "\"\" = graveyard")
	assert_eq(CorpseTables.new().hidden_causes, {} as Dictionary[StringName, Array])
	# The data files are unchanged until their owners (P4 / P7) take them over.
	assert_false((Database.config(&"economy_config") as EconomyConfig).harvest_malus.has(&"heart"), "economy_config.tres is P4's")


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase7Fixtures.CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase7Fixtures.config(name)
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


func test_village_relationship_orders_npc_config_values() -> void:
	var v := Phase7Fixtures.village_config()
	assert_eq([v.unlock_flag, v.open_flag, v.intro_minute, v.round_price, v.round_minutes, v.donation_step, v.donation_steps_per_day],
			[&"roof_and_earth_complete", &"village_open", 360, 5, 15, 5, 2])
	assert_eq(v.consecration_price_by_tier, {&"stranger": 10, &"acquainted": 10, &"trusted": 5, &"friend": 0} as Dictionary[StringName, int])
	assert_eq([v.consecration_section, v.consecration_end_minute, v.mourning_houses.size()], [&"linden", 630, 6])
	assert_eq([v.goal_orders, v.goal_givers, v.goal_trusted, v.goal_insight, v.chapter_id, v.goal_flag],
			[6, 4, 3, &"i_deathbook", &"name_in_village", &"name_in_village_complete"])
	var r := Phase7Fixtures.relationship_config()
	assert_eq([Array(r.tier_thresholds), Array(r.rep_start_bonus), Array(r.piety_start_bonus)], [[15, 40, 70], [-10, -5, 0, 5, 10], [-5, 0, 0, 3, 5]])
	assert_eq(r.gains, {&"talk": 1, &"gift": 4, &"round": 2, &"donation": 1, &"order_failed": -4} as Dictionary[StringName, int])
	assert_eq([r.discount_tier, r.discount, r.discount_min_price, r.surcharge_rep_tier, r.surcharge, r.friend_buy_bonus, r.friend_buy_min_price],
			[&"trusted", 1, 4, &"disreputable", 1, 1, 3])
	assert_eq(RelationshipRules.TIERS, [&"stranger", &"acquainted", &"trusted", &"friend"] as Array[StringName])
	var o := Phase7Fixtures.orders_config()
	assert_eq([o.max_active, o.board_offers, o.board_giver, o.refresh_minute], [4, 2, &"council", 360])
	var n := Phase7Fixtures.npc_config()
	assert_eq([n.lod_full_distance, n.lod_rest_distance, n.max_full, n.governor_hz, n.remark_distance], [26.0, 40.0, 6, 2.0, 4.0])
	assert_almost(n.reduced_interval, 0.2)
	assert_eq(OrderData.KINDS, [&"deliver", &"bury", &"stone", &"tend", &"donate", &"section"] as Array[StringName])


func test_anatomy_config_values() -> void:
	var a := Phase7Fixtures.anatomy_config()
	assert_eq(a.organs.keys().size(), 7)
	var expected := {  # §2.6 table: minutes, base price, quality, piety, mood, return piety, containers
		&"heart": [20, 7, -2, -8, -5, 3, [&"jar", &"bundle"]], &"lung": [20, 4, -2, -6, -5, 3, [&"jar", &"bundle"]],
		&"stomach": [20, 5, -2, -6, -5, 3, [&"jar", &"bundle"]], &"liver": [20, 5, -2, -6, -5, 3, [&"jar", &"bundle"]],
		&"kidneys": [20, 4, -2, -6, -5, 3, [&"jar", &"bundle"]], &"eyes": [25, 9, -3, -12, -8, 5, [&"jar"]],
		&"hand": [30, 10, -3, -12, -8, 5, [&"bundle"]],
	}
	for organ: StringName in ORGANS:
		var row := a.organ(organ)
		var e: Array = expected[organ]
		assert_eq([row.minutes, row.base_price, row.quality, row.piety, row.mood, row.return_piety, row.containers], e, String(organ))
		assert_eq(int(row.quality), Phase7Fixtures.economy_config().harvest_malus[organ], "%s quality = harvest_malus" % organ)
		assert_eq(StringName(row.reputation_event), &"organ_taken_grave" if organ in [&"eyes", &"hand"] else &"organ_taken")
		assert_eq(bool(row.medicine), organ in [&"lung", &"stomach", &"liver", &"kidneys"], "%s medicine" % organ)
		assert_true(row.has("res_tag") and row.has("res_weight") and row.has("sell_rel") and row.has("lecture_bonus"), String(organ))
	assert_eq(a.organ(&"hand").res_role, &"frame")
	assert_eq([a.max_per_corpse, a.tool_item, a.room_id, a.known_flag, a.bundle_minutes, a.sound_cue], [3, &"anatomy_case", &"crypt", &"anatomy_known", 600, &"anatomy_tool"])
	assert_almost(a.min_freshness, 0.3)
	assert_almost(a.pult_cold_factor, 0.25)
	assert_eq([a.jar_inputs, a.small_jar_inputs, a.bundle_inputs, a.hand_inputs],
			[{&"prep_jar": 1, &"spirits": 1}, {&"prep_jar_small": 1, &"spirits": 1}, {&"linen": 1}, {&"linen": 1, &"beeswax": 1}])
	assert_eq([a.inspect_minutes, a.expertise_minutes, a.bone_minutes, a.return_minutes, a.seal_minutes, a.display_minutes], [20, 30, 60, 10, 5, 40])
	assert_eq(a.basic_teachings, [&"l_lung", &"l_liver"] as Array[StringName])
	assert_eq([a.lecture.every_days, a.lecture.start, a.lecture.window, a.lecture.minutes, a.lecture.fee, a.lecture.piety, a.lecture.rumor_rep],
			[3, 1380, 90, 60, 4, -3, -4])
	assert_eq(a.lecture.rumor_rel, {&"priest": -3, &"washer": -2})


func test_specimen_record_round_trip() -> void:
	var s := Phase7Fixtures.specimen(&"liver", SpecimenRecord.CONTAINER_BUNDLE, 0.8)
	s.cold_windows = PackedInt32Array([700, -1, 250])
	s.state = &"lectured"
	s.finding_id = &"b_hard_liver"
	var back := SpecimenRecord.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary)
	assert_eq(back.to_dict(), SpecimenRecord.from_dict(s.to_dict()).to_dict(), "JSON round trip")
	assert_eq([back.uid, back.organ, back.container, back.cold_windows, back.state, back.finding_id, back.corpse_name],
			[s.uid, &"liver", &"bundle", s.cold_windows, &"lectured", &"b_hard_liver", "Hedwig Lamprecht"])
	assert_almost(back.clarity_at_harvest, 0.8)
	var odd := SpecimenRecord.from_dict({"container": "pot", "state": "eaten", "clarity_at_harvest": 4, "cold_windows": [5, 2, 1]})
	assert_eq([odd.container, odd.state, odd.clarity_at_harvest, odd.cold_windows], [&"jar", &"held", 1.0, PackedInt32Array()], "tolerant")
	assert_eq(SpecimenRecord.STATES, [&"held", &"sold", &"researched", &"lectured", &"used", &"returned"] as Array[StringName])


func test_villager_and_schedule_fixtures() -> void:
	var starts := {&"innkeeper": 25, &"smith": 15, &"grocer": 20, &"priest": 25, &"mayor": 30, &"surgeon": 20, &"washer": 10, &"oldwoman": 30}
	var deltas := {&"priest": [-4, 1], &"washer": [-3, 2], &"oldwoman": [-2, 0], &"surgeon": [2, 0]}
	for v: VillagerData in Phase7Fixtures.villagers():
		assert_not_null(v)
		assert_eq(v.start_value, starts[v.npc_id], String(v.npc_id))
		assert_eq(v.dialogue_id, StringName("v_" + String(v.npc_id)))
		assert_eq([v.specimen_delta, v.returned_delta], deltas.get(v.npc_id, [0, 0]), String(v.npc_id))
		assert_eq(v.piety_sensitive, v.npc_id in [&"priest", &"washer"])
		assert_eq(v.gifts_liked.size(), 2)
		if v.shop_id != &"":
			assert_eq(Phase7Fixtures.shop(v.shop_id).npc_id, v.npc_id, "%s keeps %s" % [v.npc_id, v.shop_id])
		var s := Phase7Fixtures.schedule(v.npc_id)
		assert_not_null(s, "%s schedule" % v.npc_id)
		var ids := _waypoint_ids()
		for e: ScheduleEntry in s.entries:
			if e.region == &"village":
				for wp: String in e.path:
					assert_true(ids.has(wp), "%s: waypoint %s (§4.4)" % [v.npc_id, wp])
	var priest := Phase7Fixtures.schedule(&"priest")
	var today := priest.entries.filter(func(e: ScheduleEntry) -> bool: return e.today_flag != &"")
	assert_eq(today.size(), 4, "the consecration day: up, at the Lindenacker 09:20, down, gone")
	for e: ScheduleEntry in today:
		assert_eq([e.today_flag, e.region], [&"linden_consecration_day", &""], "graveyard region")
	var carter := Phase7Fixtures.schedule(&"carter")
	var real := Database.schedule(&"carter") as NpcSchedule
	assert_eq(carter.entries.size(), real.entries.size() + 7, "Osric: the graveyard entries + 7 village entries")
	for i: int in real.entries.size():
		assert_eq(carter.entries[i].start_minute, real.entries[i].start_minute, "carter entry %d unchanged" % i)
		assert_eq(carter.entries[i].region, &"")


func test_shop_and_order_fixtures() -> void:
	for s: ShopData in Phase7Fixtures.shops():
		assert_not_null(s)
		assert_eq(s.coin_reason, &"village")
		for item: StringName in s.sells:
			assert_true(int(s.sells[item].price) >= 1 and int(s.sells[item].per_day) >= 1, "%s sells %s" % [s.id, item])
	assert_eq(Phase7Fixtures.shop(&"grocer").sells[&"gold_leaf"].requires_tier, &"friend")
	assert_eq(Phase7Fixtures.shop(&"inn").buys[&"elderberries"], {"price": 2, "per_day": 10})
	var givers := {}
	var board := 0
	for o: OrderData in Phase7Fixtures.orders():
		assert_not_null(o)
		assert_true(o.kind in OrderData.KINDS, String(o.id))
		assert_true(o.title != "" and o.request_text != "", String(o.id))
		givers[o.giver] = true
		if o.board:
			board += 1
			assert_eq(o.giver, &"council")
		for dep: StringName in o.requires_orders:
			assert_true(Phase7Fixtures.ORDER_IDS.has(dep), "%s requires %s" % [o.id, dep])
	assert_eq(Phase7Fixtures.orders().size(), 23)
	assert_eq(board, 6)
	assert_eq(givers.size(), 9, "§2.5: Fenner, Rosine, Esch, Theres, Lenz, Quast, Liesel, Hagedorn, Gemeinde")
	assert_eq(Phase7Fixtures.order(&"o_fenner_linden").accept_flag, &"linden_granted")
	var h := Phase7Fixtures.order(&"o_hagedorn_place")
	assert_eq([h.target, h.extra_rel, h.fail_rel, h.conditions.unharvested], ["d1_hagedorn", {&"washer": 8}, {&"washer": -10, &"priest": -5}, true])
	var donate := 0
	for id: StringName in [&"o_fenner_bridge", &"o_lenz_poor"]:
		donate += Phase7Fixtures.order(id).coins
	assert_eq(donate, 32, "§2.5: the donation orders cost 32 coins")


func test_anatomy_fixtures() -> void:
	var findings := Phase7Fixtures.findings()
	assert_eq(findings.size(), 15)
	var finding_ids := {}
	for f: SpecimenFindingData in findings:
		assert_not_null(f)
		assert_true(f.organ == &"" or f.organ in ORGANS, String(f.id))
		assert_true(f.text != "", String(f.id))
		finding_ids[f.id] = true
	var teaching_ids := {}
	for t: TeachingData in Phase7Fixtures.teachings():
		assert_true(t.organ in ORGANS and t.text != "", String(t.id))
		teaching_ids[t.id] = true
	assert_eq(teaching_ids.size(), 7, "one teaching per organ")
	for d: DeductionData in Phase7Fixtures.deductions():
		for card: StringName in d.needs_all + d.needs_any:
			var known := finding_ids.has(card) or teaching_ids.has(card) or Database.find(card) != null
			assert_true(known, "%s: card %s exists" % [d.id, card])
		if d.clue_id != &"":
			assert_not_null(Phase7Fixtures.clue(d.clue_id), "%s → %s" % [d.id, d.clue_id])
	assert_eq(Phase7Fixtures.deduction(&"d_arsenic").needs_any, [&"b_white_stomach", &"b_pale_liver"] as Array[StringName])
	var outputs := {&"antidote": 2, &"bitter_drops": 2, &"dropsy_powder": 1}
	for m: MedicineData in Phase7Fixtures.medicines():
		assert_eq(m.amount, outputs[m.id], String(m.id))
		for organ: StringName in m.organs:
			assert_true(bool(Phase7Fixtures.anatomy_config().organ(organ).medicine), "%s from %s" % [m.id, organ])
	var coins := 0
	for s: CollectionSetData in Phase7Fixtures.collection_sets():
		coins += s.reward_coins
		assert_eq(s.standing, 1)
	assert_eq(coins, 34, "§2.7: ≈ 34 coins once")
	assert_true(Phase7Fixtures.collection_set(&"set_complete").needs_display)
	assert_eq(Phase7Fixtures.collection_set(&"set_complete").organs, ORGANS)


func test_item_recipe_station_fixtures() -> void:
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		var item := Phase7Fixtures.item(id)
		assert_not_null(item, String(id))
		if item == null:
			continue
		assert_eq(item.id, id)
		assert_eq(item.unique, Phase7Fixtures.UNIQUE_ITEMS.has(id), "%s unique" % id)
		if item.unique:
			assert_eq(item.max_stack, 1)
		assert_true(item.display_name != "" and item.description.length() >= 20, String(id))
	assert_eq(Phase7Fixtures.item(&"anatomy_case").category, ItemData.Category.TOOL)
	for id: StringName in Phase7Fixtures.RECIPE_IDS:
		var r := Phase7Fixtures.recipe(id)
		assert_eq([r.station, r.output_id], [&"pult", id], String(id))
	assert_eq(Phase7Fixtures.recipe(&"wound_salve").output_amount, 2)
	var pult := Phase7Fixtures.pult_station()
	assert_eq([pult.build_inputs, pult.build_coins, pult.build_minutes], [{&"wood": 6, &"iron_fittings": 2, &"stone": 2}, 12, 90])
	assert_eq(Phase7Fixtures.prep_config().balm_items[0], &"juniper")
	assert_true(Phase7Fixtures.shed_config().excluded_items.has(&"specimen_jar"))
	assert_eq(Phase7Fixtures.corpse_tables().hidden_causes[&"fever"], [{"id": &"arsenic", "chance": 0.12}])


func test_story_section_journal_fixtures() -> void:
	var s := Phase7Fixtures.linden_section()
	assert_eq([s.id, s.order, s.decor_cap, s.counts_for_cemetery, s.is_burial, s.requires_flag, s.unlock_flag],
			[&"linden", 8, 6, false, true, &"linden_granted", &"linden_consecrated"])
	var d := Phase7Fixtures.d1_story()
	assert_eq([d.order, d.age, d.cause_id, d.traits, d.after_flag, d.after_days, d.section, d.requires_flag, d.due_flag],
			[6, 81, &"old_age", [&"strange_wound"] as Array[StringName], &"village_open_day", 8, &"linden", &"linden_consecrated", &"hagedorn_dead"])
	for id: StringName in d.finds:
		var f := Phase7Fixtures.find(id)
		assert_true(f != null and f.story_only, String(id))
	assert_eq(Phase7Fixtures.find(&"f_d1_mark").clue_id, &"c_v_hagedorn")
	for id: StringName in Phase7Fixtures.CLUE_IDS:
		var c := Phase7Fixtures.clue(id)
		assert_true(c != null and c.kind in ClueData.KINDS and c.text != "", String(id))
	var deathbook := Phase7Fixtures.insight(&"i_deathbook")
	assert_eq([deathbook.requires, deathbook.sets_flag, deathbook.optional],
			[[&"c_v_deathbook", &"c_v_washing", &"c_v_three_visitors"] as Array[StringName], &"insight_deathbook", false])
	var burn := Phase7Fixtures.insight(&"i_burn_it")
	assert_true(burn.optional and burn.requires.has(&"c_warning_letter"))
	assert_not_null(Database.clue(&"c_warning_letter"), "Phase-4 clue exists")


func test_region_room_layout_fixtures() -> void:
	var g := Phase7Fixtures.region(&"graveyard")
	var v := Phase7Fixtures.region(&"village")
	assert_eq([g.origin, g.managed_paths], [Vector3.ZERO, PackedStringArray(["Decor", "Lights", "Grass"])])
	assert_eq([v.origin, v.managed_paths, v.travel_minutes, v.camera_distance, v.camera_zoom_min, v.camera_zoom_max],
			[Vector3(0, 0, 400), PackedStringArray(["."]), 30, 22.0, 12.0, 24.0])
	assert_almost(v.fade_seconds, 0.8)
	for id: StringName in Phase7Fixtures.ROOMS:
		var c := Phase7Fixtures.room_config(id)
		var spec: Dictionary = Phase7Fixtures.ROOMS[id]
		assert_eq([c.camera_distance, c.camera_zoom_min, c.camera_zoom_max], [spec.distance, spec.zoom.x, spec.zoom.y], String(id))
	var layout := Phase7Fixtures.village_layout()
	assert_eq((layout.get("waypoints", {}) as Dictionary).size(), 20, "§4.4 outdoor waypoints")
	var doors := 0
	for e: Variant in layout.get("entities", []):
		if str((e as Dictionary).get("type")) == "HouseDoor":
			doors += 1
			var id := StringName(str(e.id))
			assert_eq(Array(e.open_windows), Phase7Fixtures.OPEN_WINDOWS[id], String(id))
	assert_eq(doors, 3)
	assert_eq((Phase7Fixtures.linden_layout().get("plots", {}) as Dictionary).keys(), Array(Phase7Fixtures.LINDEN_PLOTS))
	assert_true(Phase7Fixtures.layout_p6().get("sections", []).size() > 0, "layout_p6.json readable")


func test_fixture_helpers() -> void:
	var r := Phase7Fixtures.region_at(&"village", tree)
	assert_eq(RegionRoot.find(tree, &"village"), r, "found through the group")
	assert_eq(r.config.origin, Vector3(0, 0, 400))
	r.free()
	var rel := Phase7Fixtures.villager(&"washer", 42, null, {&"priest": 12})
	assert_eq([rel.value(&"washer"), rel.value(&"priest"), rel.met(&"washer"), rel.met(&"smith")], [42, 12, true, false])
	rel.free()
	var o := Phase7Fixtures.order_in(&"o_fenner_well", &"accepted", null, {&"o_rosine_berries": &"completed"})
	assert_eq([o.state(&"o_fenner_well"), o.state(&"o_rosine_berries"), o.state(&"ob_wood")], [&"accepted", &"completed", &""])
	o.free()
	var sp := Phase7Fixtures.specimen(&"heart")
	var sp2 := Phase7Fixtures.specimen(&"heart")
	assert_ne(sp.uid, sp2.uid, "unique uids")
	assert_eq([sp.organ, sp.container, sp.corpse_name, sp.state], [&"heart", &"jar", "Hedwig Lamprecht", &"held"])
	var shelf := Phase7Fixtures.shelf_with([&"heart", &"lung", &"hand"], [&"heart"])
	assert_eq([(shelf[&"heart"] as SpecimenRecord).container, (shelf[&"lung"] as SpecimenRecord).container,
			(shelf[&"hand"] as SpecimenRecord).container], [&"display", &"jar", &"bone"])
	var lec := Phase7Fixtures.lecture_night(6, null, [&"l_heart"])
	assert_true(lec.invited())
	assert_eq(lec.known_teachings(), PackedStringArray(["l_lung", "l_liver", "l_heart"]))
	lec.free()
	assert_eq(Phase7Fixtures.lecture_minute(3), 2 * 1440 + 1410)
	var ded := Phase7Fixtures.cards_for("c_0012", [&"b_white_stomach", &"l_stomach"])
	assert_eq(ded.cards("c_0012"), PackedStringArray(["b_white_stomach", "l_stomach"]))
	assert_eq(ded.cards("c_0013"), PackedStringArray())
	ded.free()
	var shops := Phase7Fixtures.shop_with({&"grocer": {&"linen": 4}})
	assert_true(shops is VillageShops)
	shops.free()
	var flags := GameState.flags.duplicate(true)
	assert_false(Phase7Fixtures.linden_open(null), "no world")
	assert_true(GameState.has_flag(&"linden_consecrated") and GameState.has_flag(&"village_open"))
	GameState.flags = flags
	var inv := Phase7Fixtures.inv_with({&"spirits": 2, &"prep_jar": 1})
	assert_eq([inv.count(&"spirits"), inv.count(&"prep_jar")], [2, 1])
	inv.free()


func test_database_phase7_folders() -> void:
	# The real data folders are the owners' (P2 villagers/shops, P3 orders, P4 findings, P7 medicines/sets,
	# P8 teachings/deductions, P1 regions) – empty until W1.
	for list: Array in [Database.shops(), Database.orders(), Database.villagers(), Database.findings(), Database.medicines(),
			Database.collection_sets(), Database.teachings(), Database.deductions()]:
		for res: Resource in list:
			assert_true(res != null, "loaded")
	assert_null(Database.shop(&"nope"))
	assert_null(Database.order_data(&"nope"))
	assert_null(Database.villager(&"nope"))
	assert_null(Database.finding(&"nope"))
	assert_null(Database.medicine(&"nope"))
	assert_null(Database.collection_set(&"nope"))
	assert_null(Database.teaching(&"nope"))
	assert_null(Database.deduction(&"nope"))
	assert_null(Database.region_config(&"nope"))
	for name: StringName in Phase7Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	var orders: Array = []
	for o: Resource in Database.orders():
		orders.append(int(o.get("order")))
	var sorted := orders.duplicate()
	sorted.sort()
	assert_eq(orders, sorted, "orders sorted by order")


func test_save_format_v6_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 6)
	assert_eq(SaveFileIO.FORMAT_VERSION, 6)
	assert_eq(SaveManager.FORMAT_VERSION, 6)
	assert_eq(SaveMigration.V6_EMPTY_NODES, PackedStringArray(["village", "relationships", "village_shops", "orders", "specimens",
			"pult_store", "collection_shelf", "lectures", "deductions"]))
	var state := {"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {}}}
	assert_eq(SaveMigration.migrate(state, 6), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 7), {}, "newer → corrupt")
	var v6 := SaveMigration.migrate_5_to_6(state, {"day": 5})
	assert_false(is_same(v6, state), "deep copy")
	assert_eq(state.nodes, {"corpse_manager": {}}, "input unchanged")
	if not IMPLEMENTED.has("SaveMigration"):
		assert_eq(v6, state, "W0: identity")
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("buildings"), "v1 → … → v6 chain")


func test_save_v5_fixtures_exist() -> void:
	for name: String in Phase7Fixtures.SAVES_V5:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase7Fixtures.save_v5_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 5, name)


# --- helpers ----------------------------------------------------------------------------------

func _waypoint_ids() -> Dictionary:
	var out := {}
	var layout := Phase7Fixtures.village_layout()
	for id: Variant in layout.get("waypoints", {}):
		out[str(id)] = true
	for room: Variant in layout.get("interior_waypoints", {}):
		for id: Variant in layout.interior_waypoints[room]:
			out[str(id)] = true
	return out


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
