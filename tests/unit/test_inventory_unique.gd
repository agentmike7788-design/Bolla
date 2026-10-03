extends TestCase
## P4 (docs/PHASE7_DESIGN.md §2.8, §3.4, §10): individual pieces in the Inventory (ItemData.unique) – one
## slot per piece with its uid, add_unique / remove_uid / uids / has_uid, the uid stays through chest,
## shed and cold-box transfers (ChestTransfer.move / move_slot / move_all), save / load with and without
## uid, old saves unchanged, add_item of a unique id (debug pieces with uid ""), remove_item takes the
## newest. The Phase-7 items come from tests/fixtures/items (P7 owns data/items).

var _injected: Array[StringName] = []


func before_each() -> void:
	_injected.clear()
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase7Fixtures.item(id)
			_injected.append(id)


func after_each() -> void:
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()


func _inv(slots: int = 6) -> Inventory:
	var inv := Inventory.new()
	inv.slot_count = slots
	return inv


func test_one_slot_per_piece_with_its_uid() -> void:
	var inv := _inv()
	var changes := [0]
	inv.changed.connect(func() -> void: changes[0] += 1)
	inv.add_item(&"linen", 3)
	assert_true(inv.add_unique(&"specimen_jar", "sp_0001"))
	assert_true(inv.add_unique(&"specimen_jar", "sp_0002"))
	assert_true(inv.add_unique(&"specimen_bundle", "sp_0003"))
	assert_eq(changes[0], 4, "changed once per call")
	var slots := inv.get_slots()
	assert_eq(slots[0], {"id": &"linen", "amount": 3}, "normal slots keep their shape")
	assert_eq(slots[1], {"id": &"specimen_jar", "amount": 1, "uid": "sp_0001"})
	assert_eq(slots[2], {"id": &"specimen_jar", "amount": 1, "uid": "sp_0002"}, "no stacking")
	assert_eq(inv.count(&"specimen_jar"), 2)
	assert_eq(inv.uids(), PackedStringArray(["sp_0001", "sp_0002", "sp_0003"]))
	assert_eq(inv.uids(&"specimen_jar"), PackedStringArray(["sp_0001", "sp_0002"]))
	assert_true(inv.has_uid("sp_0003"))
	assert_false(inv.has_uid("sp_0009"))
	assert_false(inv.has_uid(""))
	assert_eq(inv.uid_item("sp_0003"), &"specimen_bundle")
	inv.free()


func test_add_unique_refusals() -> void:
	var inv := _inv(2)
	assert_false(inv.add_unique(&"specimen_jar", ""), "empty uid")
	assert_true(inv.add_unique(&"specimen_jar", "sp_0001"))
	assert_false(inv.add_unique(&"specimen_jar", "sp_0001"), "the same uid twice")
	assert_false(inv.add_unique(&"linen", "sp_0002"), "not a unique item")
	assert_false(inv.add_unique(&"nope", "sp_0002"), "unknown item")
	assert_true(inv.add_unique(&"bone_specimen", "sp_0002"))
	assert_false(inv.add_unique(&"display_specimen", "sp_0003"), "no free slot")
	assert_false(inv.can_add(&"specimen_jar", 1))
	inv.free()


func test_remove_uid_empties_exactly_that_slot() -> void:
	var inv := _inv()
	inv.add_unique(&"specimen_jar", "sp_0001")
	inv.add_unique(&"specimen_jar", "sp_0002")
	var changes := [0]
	inv.changed.connect(func() -> void: changes[0] += 1)
	assert_false(inv.remove_uid("sp_0009"))
	assert_false(inv.remove_uid(""))
	assert_eq(changes[0], 0, "no change for a refusal")
	assert_true(inv.remove_uid("sp_0001"))
	assert_eq(changes[0], 1)
	assert_eq(inv.get_slots()[0], {})
	assert_eq(inv.uids(), PackedStringArray(["sp_0002"]))
	inv.free()


func test_add_item_and_remove_item_compatibility() -> void:
	var inv := _inv()
	inv.add_unique(&"specimen_jar", "sp_0001")
	assert_eq(inv.add_item(&"specimen_jar", 2), 0, "debug pieces")
	assert_eq(inv.uids(&"specimen_jar"), PackedStringArray(["sp_0001", "", ""]), "debug pieces carry uid \"\"")
	assert_eq(inv.get_slots()[1], {"id": &"specimen_jar", "amount": 1, "uid": ""})
	assert_true(inv.remove_item(&"specimen_jar", 2), "remove_item takes the newest")
	assert_eq(inv.uids(&"specimen_jar"), PackedStringArray(["sp_0001"]))
	assert_false(inv.remove_item(&"specimen_jar", 2), "all or nothing")
	inv.stack_multiplier = 3
	inv.add_item(&"specimen_bundle", 2)
	assert_eq(inv.count(&"specimen_bundle"), 2)
	assert_eq(inv.uids(&"specimen_bundle").size(), 2, "the shed multiplier never stacks pieces")
	inv.free()


func test_save_load_with_and_without_uid() -> void:
	var inv := _inv()
	inv.add_item(&"linen", 4)
	inv.add_unique(&"specimen_jar", "sp_0004")
	inv.add_unique(&"bone_specimen", "sp_0007")
	var state := inv.save_state()
	var back := _inv()
	back.load_state(JSON.parse_string(JSON.stringify(state)) as Dictionary)
	assert_eq(back.get_slots(), inv.get_slots(), "JSON round trip keeps slots and uids")
	assert_eq(back.save_state(), state)
	# Old saves (no uid anywhere) load unchanged.
	var old := {"slots": [{"id": "linen", "amount": 4}, {}, {"id": "wood", "amount": 9}], "currency": {"coin": 3}}
	var plain := _inv()
	plain.load_state(old)
	assert_eq(plain.get_slots()[0], {"id": &"linen", "amount": 4})
	assert_eq(plain.get_slots()[2], {"id": &"wood", "amount": 9})
	assert_eq(plain.uids(), PackedStringArray())
	# A unique slot without uid becomes a debug piece; an amount > 1 splits into pieces.
	var odd := _inv()
	odd.load_state({"slots": [{"id": "specimen_jar", "amount": 1}, {"id": "specimen_jar", "amount": 2, "uid": "sp_0002"},
			{"id": "specimen_jar", "amount": 1, "uid": "sp_0002"}]})
	assert_eq(odd.count(&"specimen_jar"), 3, "the duplicate uid is dropped")
	assert_eq(odd.uids(), PackedStringArray(["", "sp_0002", ""]))
	inv.free()
	back.free()
	plain.free()
	odd.free()


func test_fewer_slots_keep_the_uid() -> void:
	var inv := _inv(4)
	inv.add_item(&"linen", 1)
	inv.add_unique(&"specimen_jar", "sp_0001")
	inv.load_state({"slots": [{}, {}, {}, {"id": "specimen_jar", "amount": 1, "uid": "sp_0003"}]})
	inv.slot_count = 2
	assert_eq(inv.uids(), PackedStringArray(["sp_0003"]), "repacked with its uid")
	inv.free()


func test_chest_shed_and_cold_box_transfers_keep_the_uid() -> void:
	var player := _inv()
	var chest := _inv(4)
	var shed := _inv(4)
	shed.stack_multiplier = 3
	player.add_unique(&"specimen_jar", "sp_0001")
	player.add_unique(&"specimen_bundle", "sp_0002")
	player.add_unique(&"specimen_jar", "sp_0003")
	player.add_item(&"linen", 2)
	assert_eq(ChestTransfer.move_slot(player, chest, 0), 1, "one slot = one piece")
	assert_eq(chest.uids(), PackedStringArray(["sp_0001"]))
	assert_false(player.has_uid("sp_0001"))
	assert_eq(ChestTransfer.move(player, shed, &"specimen_jar", 1), 1, "move(id, n) takes the newest")
	assert_eq(shed.uids(), PackedStringArray(["sp_0003"]))
	assert_eq(ChestTransfer.move(chest, player, &"specimen_jar", 5), 1, "clamped to what is there")
	assert_true(player.has_uid("sp_0001"))
	var moved := ChestTransfer.move_all(player, chest)
	assert_eq(moved, 4, "2 pieces + 2 linen")
	assert_eq(chest.uids(), PackedStringArray(["sp_0001", "sp_0002"]))
	assert_eq(player.uids(), PackedStringArray())
	# Room: a full target takes nothing and nothing is lost.
	var tiny := _inv(1)
	tiny.add_item(&"linen", 1)
	assert_eq(ChestTransfer.move_slot(chest, tiny, 1), 0)
	assert_eq(chest.uids().size(), 2)
	for inv: Inventory in [player, chest, shed, tiny]:
		inv.free()


func test_debug_pieces_move_too() -> void:
	var a := _inv()
	var b := _inv()
	a.add_item(&"specimen_jar", 1)
	assert_eq(ChestTransfer.move_slot(a, b, 0), 1)
	assert_eq([a.count(&"specimen_jar"), b.count(&"specimen_jar")], [0, 1])
	assert_eq(b.uids(), PackedStringArray([""]))
	a.free()
	b.free()


func test_remove_piece() -> void:
	var inv := _inv()
	inv.add_unique(&"specimen_jar", "sp_0001")
	inv.add_item(&"specimen_jar", 1)
	assert_true(inv.remove_piece(&"specimen_jar", ""))
	assert_false(inv.remove_piece(&"specimen_jar", ""))
	assert_false(inv.remove_piece(&"specimen_bundle", "sp_0001"), "id must match")
	assert_true(inv.remove_piece(&"specimen_jar", "sp_0001"))
	assert_eq(inv.count(&"specimen_jar"), 0)
	inv.free()
