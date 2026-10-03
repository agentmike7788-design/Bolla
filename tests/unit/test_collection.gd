extends TestCase
## P7 (docs/PHASE7_DESIGN.md §2.7, §3.4, §5.1, §10): CollectionRules and the CollectionShelf – one organ
## per compartment, no bundle, the sets (chest, body, senses and hand, the teaching collection with a
## display specimen) rewarded once – also after taking out and placing again –, the university standing
## 0…4 (never falling) with stats.university_standing, the price bonus ≤ 2, the university letter flag,
## collection_set_completed, save / load (§5.1). Unique pieces through test doubles (P4 in parallel).

const Doubles := preload("res://tests/unit/pult_test_doubles.gd")
const SHELF_SCENE := "res://src/entities/collection_shelf/collection_shelf.tscn"

var shelf: CollectionShelf
var inv: Doubles.UniqueInventory
var specs: Doubles.FakeSpecimens
var completed: Array = []
var payments: Array = []


func before_each() -> void:
	GameState.reset()
	inv = Doubles.UniqueInventory.new()
	tree.root.add_child(inv)
	specs = null
	shelf = null
	completed.clear()
	payments.clear()
	EventBus.collection_set_completed.connect(_on_set)
	EventBus.payment_received.connect(_on_payment)


func after_each() -> void:
	EventBus.collection_set_completed.disconnect(_on_set)
	EventBus.payment_received.disconnect(_on_payment)
	if shelf != null:
		shelf.free()
	if specs != null:
		specs.free()
	inv.free()
	GameState.reset()


func _on_set(set_id: StringName, standing: int) -> void:
	completed.append([set_id, standing])


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


## A shelf with a uid-capable storage and FakeSpecimens holding one piece per organ in `organs`
## (display: those as display specimens, the hand as a bone specimen) – all in the player's inventory.
func _shelf(organs: Array, display: Array = []) -> Dictionary:
	var pieces := Phase7Fixtures.shelf_with(organs, display)
	var records: Array = pieces.values()
	specs = Doubles.specimens_with(records)
	var uids := {}
	for organ: Variant in pieces:
		var rec: SpecimenRecord = pieces[organ]
		inv.add_unique(Doubles.item_of(rec), rec.uid)
		uids[organ] = rec.uid
	shelf = (load(SHELF_SCENE) as PackedScene).instantiate() as CollectionShelf
	var old := shelf.get_node(^"Storage")
	shelf.remove_child(old)
	old.free()
	var storage := Doubles.UniqueInventory.new()
	storage.name = "Storage"
	shelf.add_child(storage)
	shelf.specimens = specs
	shelf.sets = Phase7Fixtures.collection_sets()
	tree.root.add_child(shelf)
	return uids


# --- rules ----------------------------------------------------------------------------------

func test_slot_for_and_accepts() -> void:
	assert_eq([CollectionRules.slot_for(&"heart"), CollectionRules.slot_for(&"hand"), CollectionRules.slot_for(&"hair")], [0, 6, -1])
	var jar := Phase7Fixtures.specimen(&"liver")
	var bundle := Phase7Fixtures.specimen(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	var display := Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_DISPLAY)
	var bone := Phase7Fixtures.specimen(&"hand", SpecimenRecord.CONTAINER_BONE)
	assert_true(CollectionRules.accepts(Specimens.ITEM_JAR, jar))
	assert_true(CollectionRules.accepts(Specimens.ITEM_DISPLAY, display))
	assert_true(CollectionRules.accepts(Specimens.ITEM_BONE, bone))
	assert_false(CollectionRules.accepts(Specimens.ITEM_BUNDLE, bundle), "no bundle")
	assert_false(CollectionRules.accepts(Specimens.ITEM_JAR, bundle))
	assert_false(CollectionRules.accepts(Specimens.ITEM_DISPLAY, jar), "item id must match the container")
	jar.state = &"sold"
	assert_false(CollectionRules.accepts(Specimens.ITEM_JAR, jar), "only held pieces")
	assert_false(CollectionRules.accepts(Specimens.ITEM_JAR, null))


func test_completed_sets_rules() -> void:
	var sets := Phase7Fixtures.collection_sets()
	var none := PackedStringArray()
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with([&"heart"]), sets, none), [] as Array[StringName])
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with([&"heart", &"lung"]), sets, none), [&"set_chest"] as Array[StringName])
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with([&"stomach", &"liver", &"kidneys", &"eyes", &"hand"]), sets, none),
			[&"set_body", &"set_senses"] as Array[StringName])
	var all := AnatomyConfig.ORGANS.duplicate()
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with(all), sets, PackedStringArray(["set_chest", "set_body", "set_senses"])),
			[] as Array[StringName], "the teaching collection needs a display specimen")
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with(all, [&"lung"]), sets, PackedStringArray(["set_chest", "set_body", "set_senses"])),
			[&"set_complete"] as Array[StringName])
	assert_eq(CollectionRules.completed_sets(Phase7Fixtures.shelf_with([&"heart", &"lung"]), sets, PackedStringArray(["set_chest"])),
			[] as Array[StringName], "done sets never again")


func test_price_bonus_and_standing() -> void:
	assert_eq([CollectionRules.price_bonus(0), CollectionRules.price_bonus(1), CollectionRules.price_bonus(2),
			CollectionRules.price_bonus(4), CollectionRules.price_bonus(-1)], [0, 1, 2, 2, 0])
	assert_eq([CollectionRules.add_standing(3, 1), CollectionRules.add_standing(4, 1), CollectionRules.add_standing(2, -1)], [4, 4, 2])


func test_set_data_matches_the_contract() -> void:
	var expect := {  # §2.7: organs, needs_display, coins, standing, flag
		&"set_chest": [[&"heart", &"lung"], false, 5, 1, &""],
		&"set_body": [[&"stomach", &"liver", &"kidneys"], false, 6, 1, &""],
		&"set_senses": [[&"eyes", &"hand"], false, 8, 1, &""],
		&"set_complete": [AnatomyConfig.ORGANS, true, 15, 1, &"university_letter"],
	}
	assert_eq(Database.collection_sets().size(), 4)
	for id: StringName in expect:
		var s := Database.collection_set(id) as CollectionSetData
		assert_not_null(s, String(id))
		if s == null:
			continue
		var e: Array = expect[id]
		assert_eq([Array(s.organs), s.needs_display, s.reward_coins, s.standing, s.sets_flag], [Array(e[0]), e[1], e[2], e[3], e[4]], String(id))
		assert_eq(s.title, Phase7Fixtures.collection_set(id).title)


# --- the shelf --------------------------------------------------------------------------------

func test_shelf_scene_and_prompt() -> void:
	_shelf([])
	assert_eq([shelf.save_id, shelf.save_order, shelf.storage.slot_count], ["collection_shelf", 63, 7])
	assert_eq(shelf.get_interaction_prompt(null), CollectionShelf.PROMPT_SHELF)
	assert_true(shelf.is_active(), "no Workshop in the tree")
	assert_false(shelf.can_interact(null))


func test_place_one_organ_per_compartment_no_bundle() -> void:
	var uids := _shelf([&"heart"])
	var second := Phase7Fixtures.specimen(&"heart")
	var bundle := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_BUNDLE)
	specs.load_state({"records": [specs.get_record(uids[&"heart"]).to_dict(), second.to_dict(), bundle.to_dict()]})
	inv.add_unique(Specimens.ITEM_JAR, second.uid)
	inv.add_unique(Specimens.ITEM_BUNDLE, bundle.uid)
	assert_eq(shelf.place_block_reason(uids[&"heart"], inv), "")
	assert_true(shelf.place(uids[&"heart"], inv))
	assert_false(inv.has_uid(uids[&"heart"]))
	assert_true(shelf.storage.has_uid(uids[&"heart"]))
	assert_eq(shelf.uid_at(&"heart"), uids[&"heart"])
	assert_eq(GameState.get_stat(&"specimens_collected"), 1)
	assert_eq(shelf.place_block_reason(second.uid, inv), CollectionShelf.TEXT_TAKEN, "one heart only")
	assert_false(shelf.place(second.uid, inv))
	assert_true(inv.has_uid(second.uid))
	assert_eq(shelf.place_block_reason(bundle.uid, inv), CollectionShelf.TEXT_NOT_ACCEPTED, "no bundle")
	assert_false(shelf.place(bundle.uid, inv))
	assert_eq(shelf.place_block_reason("sp_nope", inv), CollectionShelf.TEXT_NOT_ACCEPTED)
	assert_eq(shelf.place_block_reason(uids[&"heart"], inv), CollectionShelf.TEXT_NOT_HELD, "already on the shelf")
	assert_eq(specs.get_record(uids[&"heart"]).state, SpecimenRecord.STATE_HELD, "still the player's (robbed ghost stays robbed)")


func test_take_back_out() -> void:
	var uids := _shelf([&"liver"])
	assert_true(shelf.place(uids[&"liver"], inv))
	assert_true(shelf.take(uids[&"liver"], inv))
	assert_true(inv.has_uid(uids[&"liver"]))
	assert_eq(inv.pieces[uids[&"liver"]], Specimens.ITEM_JAR, "same item id, same uid")
	assert_eq(shelf.uid_at(&"liver"), "")
	assert_eq(GameState.get_stat(&"specimens_collected"), 0)
	assert_false(shelf.take(uids[&"liver"], inv), "not on the shelf")
	assert_true(shelf.place(uids[&"liver"], inv))
	inv.room = inv.pieces.size()
	assert_false(shelf.take(uids[&"liver"], inv), "no room → stays on the shelf")
	assert_true(shelf.storage.has_uid(uids[&"liver"]))


func test_sets_rewarded_once_even_after_take_and_place() -> void:
	var uids := _shelf([&"heart", &"lung"])
	assert_true(shelf.place(uids[&"heart"], inv))
	assert_eq(completed, [])
	assert_true(shelf.place(uids[&"lung"], inv))
	assert_eq(completed, [[&"set_chest", 1]])
	assert_eq(inv.count(&"coin"), 5)
	assert_eq(payments.size(), 1)
	assert_eq(payments[0][0], 5)
	assert_eq([shelf.standing(), shelf.sets_done(), GameState.get_stat(&"university_standing")], [1, PackedStringArray(["set_chest"]), 1])
	assert_true(shelf.take(uids[&"lung"], inv))
	assert_eq(shelf.standing(), 1, "never falls")
	assert_true(shelf.place(uids[&"lung"], inv))
	assert_eq([completed.size(), inv.count(&"coin"), shelf.standing()], [1, 5, 1], "once")


func test_all_sets_standing_four_and_the_letter() -> void:
	var uids := _shelf(AnatomyConfig.ORGANS.duplicate(), [&"heart"])
	for organ: StringName in AnatomyConfig.ORGANS:
		assert_true(shelf.place(uids[organ], inv), String(organ))
	assert_eq(completed, [[&"set_chest", 1], [&"set_body", 2], [&"set_senses", 3], [&"set_complete", 4]])
	assert_eq(inv.count(&"coin"), 5 + 6 + 8 + 15)
	assert_eq([shelf.standing(), GameState.get_stat(&"university_standing")], [4, 4])
	assert_true(GameState.flag_on(&"university_letter"), "Empfehlungsschreiben (hook Phase 9/10)")
	assert_eq(GameState.get_stat(&"specimens_collected"), 7)
	assert_eq(CollectionRules.price_bonus(shelf.standing()), 2)
	assert_eq(shelf.shelf_organs().size(), 7)
	assert_eq((shelf.shelf_organs()[&"heart"] as SpecimenRecord).container, SpecimenRecord.CONTAINER_DISPLAY)
	assert_eq((shelf.shelf_organs()[&"hand"] as SpecimenRecord).container, SpecimenRecord.CONTAINER_BONE)


func test_save_load() -> void:
	var uids := _shelf([&"heart", &"lung"])
	shelf.place(uids[&"heart"], inv)
	shelf.place(uids[&"lung"], inv)
	var state := shelf.save_state()
	assert_eq(state.keys(), ["storage", "sets_done", "standing"], "§5.1")
	assert_eq([state.sets_done, state.standing], [["set_chest"], 1])
	assert_eq((state.storage.pieces as Dictionary).size(), 2)
	shelf.load_state({})
	assert_eq([shelf.standing(), shelf.sets_done(), shelf.shelf_organs().size()], [0, PackedStringArray(), 0])
	shelf.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq([shelf.standing(), shelf.sets_done(), shelf.shelf_organs().size()], [1, PackedStringArray(["set_chest"]), 2])
	assert_true(shelf.place(uids[&"heart"], inv) == false, "loaded pieces keep their compartment")
	shelf.load_state({"standing": 9, "sets_done": ["set_body", "set_body"], "storage": {}})
	assert_eq([shelf.standing(), shelf.sets_done()], [4, PackedStringArray(["set_body"])], "tolerant")
