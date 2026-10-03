extends TestCase
## P7 (docs/PHASE7_DESIGN.md §2.6, §2.7, §2.8, §3.4, §10): the preparation desk – the station pult
## (6 wood, 2 iron fittings, 2 stone + 12 coins, 90 min; only from village_open with the crypt ≥ 1),
## the cold box PultStore (8 slots; Specimens.note_cold for bundles in / out, not on loading), the
## rules for sealing a bundle, the display and the bone specimen and inspecting (the piece stays, the
## card once), the shed exclusions of the four specimen items. Unique pieces through test doubles.

const Doubles := preload("res://tests/unit/pult_test_doubles.gd")
const STORE_SCENE := "res://src/entities/pult_store/pult_store.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class FakeBuildings extends Node:
	var levels: Dictionary = {}

	func _init() -> void:
		add_to_group(&"buildings")

	func level(id: StringName) -> int:
		return int(levels.get(id, 0))


class FakeWorkshop extends Node:
	var built: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"workshop")

	func is_built(id: StringName) -> bool:
		return built.has(id)


var cfg: AnatomyConfig
var inv: Doubles.UniqueInventory
var specs: Doubles.FakeSpecimens
var nodes: Array[Node] = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	cfg = Phase7Fixtures.anatomy_config()
	inv = Doubles.UniqueInventory.new()
	specs = null
	nodes.clear()


func after_each() -> void:
	for n: Node in nodes:
		if is_instance_valid(n):
			n.free()
	inv.free()
	if specs != null:
		specs.free()
	GameState.reset()
	TimeManager.reset()


func _keep(n: Node) -> Node:
	nodes.append(n)
	tree.root.add_child(n)
	return n


func _held(organ: StringName, container: StringName = SpecimenRecord.CONTAINER_JAR, clarity: float = 0.9) -> SpecimenRecord:
	var rec := Phase7Fixtures.specimen(organ, container, clarity)
	inv.add_unique(Doubles.item_of(rec), rec.uid)
	return rec


# --- station ----------------------------------------------------------------------------------

func test_station_data_matches_the_contract() -> void:
	var s := Database.station(&"pult") as StationData
	assert_not_null(s)
	if s == null:
		return
	var f := Phase7Fixtures.pult_station()
	assert_eq([s.build_inputs, s.build_coins, s.build_minutes, s.panel, s.prebuilt, s.site_id],
			[{&"wood": 6, &"iron_fittings": 2, &"stone": 2}, 12, 90, &"crafting", false, "pult"], "§2.7")
	assert_eq([s.display_name, s.coin_part_label, s.prompt_use], [f.display_name, f.coin_part_label, f.prompt_use])
	assert_false((Database.config(&"workshop_config") as WorkshopConfig).goal_stations.has(&"pult"), "not a Phase-5 goal")


func test_build_only_from_village_open_with_crypt_level_one() -> void:
	var shop := Workshop.new()
	shop.station_table = {&"pult": Phase7Fixtures.pult_station(), &"mason": Phase5Fixtures.stations()[0]}
	_keep(shop)
	GameState.set_flag(&"workshop_open", true)
	var bag := FakeInventory.new()
	nodes.append(bag)
	bag.add_item(&"wood", 6)
	bag.add_item(&"iron_fittings", 2)
	bag.add_item(&"stone", 2)
	bag.add_item(&"coin", 12)
	assert_eq(shop.build_block_reason(&"pult", bag), PultRules.TEXT_SITE_CLOSED, "before village_open")
	assert_false(shop.site_available(&"pult"))
	assert_true(shop.site_available(&"mason"), "Phase-5 stations unchanged")
	GameState.set_flag(&"village_open", true)
	assert_eq(shop.build_block_reason(&"pult", bag), PultRules.TEXT_SITE_CLOSED, "no crypt (level 0)")
	var buildings := _keep(FakeBuildings.new()) as FakeBuildings
	buildings.levels[&"crypt"] = 1
	assert_eq(shop.build_block_reason(&"pult", bag), "")
	bag.remove_item(&"coin", 1)
	assert_true(shop.build_block_reason(&"pult", bag).begins_with("Es fehlt"), "12 coins needed")
	bag.add_item(&"coin", 1)
	var spent: Array = []
	var on_spent := func(amount: int, reason: StringName) -> void: spent.append([amount, reason])
	EventBus.coins_spent.connect(on_spent)
	assert_true(shop.build(&"pult", bag))
	EventBus.coins_spent.disconnect(on_spent)
	assert_true(shop.is_built(&"pult"))
	assert_eq([bag.count(&"wood"), bag.count(&"iron_fittings"), bag.count(&"stone"), bag.count(&"coin")], [0, 0, 0, 0])
	assert_eq(spent, [[12, &"build"]], "„Glaswaren und Wachstuch von Quast“ under build")
	assert_eq(PultRules.site_block_reason(true, 0), PultRules.TEXT_SITE_CLOSED)
	assert_eq(PultRules.site_block_reason(false, 3), PultRules.TEXT_SITE_CLOSED)
	assert_eq(PultRules.site_block_reason(true, 1), "")


# --- cold box -------------------------------------------------------------------------------

func _store() -> PultStore:
	var store := (load(STORE_SCENE) as PackedScene).instantiate() as PultStore
	var old := store.get_node(^"Storage")
	store.remove_child(old)
	old.free()
	var storage := Doubles.UniqueInventory.new()
	storage.name = "Storage"
	store.add_child(storage)
	specs = Doubles.specimens_with([])
	store.specimens = specs
	_keep(store)
	return store


func test_cold_box_notes_bundles_in_and_out() -> void:
	var store := _store()
	assert_eq([store.save_id, store.save_order, store.store().slot_count], ["pult_store", 62, 8])
	assert_eq(store.store(), store.storage)
	assert_eq(store.get_interaction_prompt(null), PultStore.PROMPT_COLD)
	store.storage.add_unique(Specimens.ITEM_BUNDLE, "sp_0001")
	assert_eq(specs.cold, [["sp_0001", true]])
	store.storage.add_unique(Specimens.ITEM_JAR, "sp_0002")
	store.storage.add_item(&"linen", 2)
	assert_eq(specs.cold.size(), 1, "jars and other items: no window")
	store.storage.add_unique(Specimens.ITEM_BUNDLE, "sp_0003")
	store.storage.remove_uid("sp_0001")
	assert_eq(specs.cold, [["sp_0001", true], ["sp_0003", true], ["sp_0001", false]])
	assert_eq(store.bundles(), PackedStringArray(["sp_0003"]))
	var state := store.save_state()
	specs.cold.clear()
	store.load_state({})
	store.load_state(state)
	assert_eq(specs.cold, [], "loading opens or closes no window")
	store.storage.remove_uid("sp_0003")
	assert_eq(specs.cold, [["sp_0003", false]], "after loading the list is known")


func test_cold_box_needs_the_pult() -> void:
	var store := _store()
	var shop := _keep(FakeWorkshop.new()) as FakeWorkshop
	assert_false(store.is_active())
	assert_eq(store.get_interaction_prompt(null), "")
	shop.built.append(&"pult")
	assert_true(store.is_active())


# --- seal, display, bone, inspect -----------------------------------------------------------------

func test_seal_rules() -> void:
	var bundle := _held(&"heart", SpecimenRecord.CONTAINER_BUNDLE)
	assert_eq(PultRules.seal_block_reason(bundle, inv, 0, cfg), PultRules.FORMAT_MISSING % WorkshopRules.describe({&"prep_jar": 1, &"spirits": 1}))
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	assert_eq(PultRules.seal_block_reason(bundle, inv, 0, cfg), "")
	assert_eq(PultRules.seal_block_reason(_held(&"heart"), inv, 0, cfg), PultRules.TEXT_NOT_BUNDLE)
	assert_eq(PultRules.seal_block_reason(_held(&"hand", SpecimenRecord.CONTAINER_BUNDLE), inv, 0, cfg), PultRules.TEXT_HAND_NO_SEAL)
	var spoiled := _held(&"lung", SpecimenRecord.CONTAINER_BUNDLE, 0.0)
	assert_eq(PultRules.seal_block_reason(spoiled, inv, 0, cfg), PultRules.TEXT_SPOILED, "a spoiled bundle only goes back to the grave")
	assert_true(PultRules.spoiled(spoiled, 0, cfg))
	assert_false(PultRules.spoiled(bundle, 0, cfg))
	var other := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_BUNDLE)
	assert_eq(PultRules.seal_block_reason(other, inv, 0, cfg), PultRules.TEXT_NOT_HELD)
	assert_eq(PultRules.seal_block_reason(null, inv, 0, cfg), PultRules.TEXT_NO_PIECE)


func test_display_rules() -> void:
	var jar := _held(&"eyes")
	assert_eq(PultRules.display_block_reason(jar, inv, cfg), PultRules.FORMAT_MISSING % WorkshopRules.describe({&"beeswax": 1, &"ink": 1}))
	inv.add_item(&"beeswax", 1)
	inv.add_item(&"ink", 1)
	assert_eq(PultRules.display_block_reason(jar, inv, cfg), "")
	assert_eq(PultRules.display_block_reason(_held(&"lung", SpecimenRecord.CONTAINER_BUNDLE), inv, cfg), PultRules.TEXT_SEAL_FIRST)
	assert_eq(PultRules.display_block_reason(_held(&"heart", SpecimenRecord.CONTAINER_DISPLAY), inv, cfg), PultRules.TEXT_JAR_ONLY)
	assert_eq(PultRules.display_block_reason(_held(&"hand", SpecimenRecord.CONTAINER_BONE), inv, cfg), PultRules.TEXT_JAR_ONLY)
	jar.state = &"lectured"
	assert_eq(PultRules.display_block_reason(jar, inv, cfg), PultRules.TEXT_GONE)
	assert_eq(PultRules.DISPLAY_INPUTS, {&"beeswax": 1, &"ink": 1} as Dictionary[StringName, int], "§2.7: Glas + 1 beeswax + 1 ink")


func test_bone_rules() -> void:
	var hand := _held(&"hand", SpecimenRecord.CONTAINER_BUNDLE)
	assert_eq(PultRules.bone_block_reason(hand, inv, 0, cfg), PultRules.FORMAT_MISSING % WorkshopRules.describe({&"beeswax": 1, &"linen": 1}))
	inv.add_item(&"beeswax", 1)
	inv.add_item(&"linen", 1)
	assert_eq(PultRules.bone_block_reason(hand, inv, 0, cfg), "")
	assert_eq(PultRules.bone_block_reason(_held(&"heart", SpecimenRecord.CONTAINER_BUNDLE), inv, 0, cfg), PultRules.TEXT_HAND_ONLY)
	assert_eq(PultRules.bone_block_reason(_held(&"hand", SpecimenRecord.CONTAINER_BONE), inv, 0, cfg), PultRules.TEXT_HAND_ONLY, "already bone")
	assert_eq(PultRules.bone_block_reason(_held(&"hand", SpecimenRecord.CONTAINER_BUNDLE, 0.0), inv, 0, cfg), PultRules.TEXT_SPOILED)
	assert_eq(PultRules.BONE_INPUTS, {&"beeswax": 1, &"linen": 1} as Dictionary[StringName, int], "§2.7: Hand-Bündel + 1 beeswax + 1 linen")


func test_inspect_rules_piece_stays_card_once() -> void:
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"heart"), 0, cfg), "", "a jar need not be carried")
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"hand", SpecimenRecord.CONTAINER_BONE), 0, cfg), "")
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_DISPLAY), 0, cfg), "")
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_BUNDLE), 0, cfg),
			PultRules.TEXT_INSPECT_BUNDLE)
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_JAR, 0.49), 0, cfg),
			PultRules.TEXT_INSPECT_DIM, "clarity ≥ 0.5")
	assert_eq(PultRules.inspect_block_reason(Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_JAR, 0.5), 0, cfg), "")
	var done := Phase7Fixtures.specimen(&"stomach")
	done.finding_id = &"b_white_stomach"
	assert_eq(PultRules.inspect_block_reason(done, 0, cfg), PultRules.TEXT_INSPECTED, "the card once")
	var sold := Phase7Fixtures.specimen(&"stomach")
	sold.state = &"sold"
	assert_eq(PultRules.inspect_block_reason(sold, 0, cfg), PultRules.TEXT_GONE)
	assert_eq(PultRules.inspect_block_reason(null, 0, cfg), PultRules.TEXT_NO_PIECE)


# --- shed ---------------------------------------------------------------------------------------

func test_shed_never_stores_specimens() -> void:
	var shed := Database.config(&"shed_config") as ShedConfig
	var expect: Array[StringName] = [&"specimen_jar", &"specimen_bundle", &"display_specimen", &"bone_specimen"]
	for id: StringName in expect:
		assert_true(shed.excluded_items.has(id), "data: %s" % id)
		assert_true(ShedConfig.new().excluded_items.has(id), "class default: %s" % id)
		assert_false(ShedSupply.storable(id, shed), id)
		assert_true((Database.item(id) as ItemData).unique, "%s is unique" % id)
	assert_eq(shed.excluded_items, Phase7Fixtures.shed_config().excluded_items, "data == fixture")
	for id: StringName in [&"bone_box_full", &"bone_box", &"altar_candle"]:
		assert_true(shed.excluded_items.has(id), "Phase 6 kept: %s" % id)
