extends TestCase
## P7 (docs/PHASE7_DESIGN.md §2.7, §2.8, §3.4, §10): medicines from specimens at the pult – only the
## allowed organs (antidote: stomach or liver; bitter drops: liver; dropsy powder: kidneys; never heart,
## eyes or hand), only a held jar (a bundle must be sealed first; display / bone are not used), clarity
## ≥ 0.45, the ingredients, room; make_medicine consumes the piece (Specimens.consume … used), takes the
## ingredients and gives 2 / 2 / 1; Quast's recipe book (anatomy_known) is needed. Data == fixtures.

const Doubles := preload("res://tests/unit/pult_test_doubles.gd")

var cfg: AnatomyConfig
var inv: Doubles.UniqueInventory
var specs: Doubles.FakeSpecimens
var notes: Array = []


func before_each() -> void:
	GameState.reset()
	GameState.set_flag(&"anatomy_known", true)
	cfg = Phase7Fixtures.anatomy_config()
	inv = Doubles.UniqueInventory.new()
	specs = null
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	inv.free()
	if specs != null:
		specs.free()
	GameState.reset()


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


## A held piece of `organ` in the inventory, through FakeSpecimens.
func _held(organ: StringName, container: StringName = SpecimenRecord.CONTAINER_JAR, clarity: float = 0.9) -> SpecimenRecord:
	var rec := Phase7Fixtures.specimen(organ, container, clarity)
	if specs != null:
		specs.free()
	specs = Doubles.specimens_with([rec])
	inv.add_unique(Doubles.item_of(rec), rec.uid)
	return specs.get_record(rec.uid)


func _ingredients(med: MedicineData) -> void:
	for id: StringName in med.inputs:
		inv.add_item(id, med.inputs[id])


func test_allowed_organs_only() -> void:
	var antidote := Phase7Fixtures.medicine(&"antidote")
	var drops := Phase7Fixtures.medicine(&"bitter_drops")
	var powder := Phase7Fixtures.medicine(&"dropsy_powder")
	for med: MedicineData in [antidote, drops, powder]:
		_ingredients(med)
	var expect := {  # organ → [antidote, bitter_drops, dropsy_powder] allowed
		&"stomach": [true, false, false], &"liver": [true, true, false], &"kidneys": [false, false, true],
		&"lung": [false, false, false],
	}
	for organ: StringName in expect:
		var spec := _held(organ)
		var row: Array = expect[organ]
		var meds := [antidote, drops, powder]
		for i: int in meds.size():
			var reason := PultRules.medicine_block_reason(meds[i], spec, inv, 0, cfg)
			assert_eq(reason == "", row[i], "%s → %s: %s" % [organ, (meds[i] as MedicineData).id, reason])
			if not row[i]:
				assert_true(reason.begins_with("Dafür braucht es:"), reason)
	for organ: StringName in [&"heart", &"eyes", &"hand"]:
		var spec := _held(organ, SpecimenRecord.CONTAINER_BUNDLE if organ == &"hand" else SpecimenRecord.CONTAINER_JAR)
		for med: MedicineData in [antidote, drops, powder]:
			assert_eq(PultRules.medicine_block_reason(med, spec, inv, 0, cfg), PultRules.TEXT_NO_MEDICINE,
					"§2.7: no medicine from %s" % organ)
	assert_eq(PultRules.medicine_block_reason(antidote, _held(&"stomach"), inv, 0, cfg), "")
	assert_eq(PultRules.FORMAT_WRONG_ORGAN % "Magen oder Leber",
			PultRules.medicine_block_reason(antidote, _held(&"kidneys"), inv, 0, cfg))


func test_jar_clarity_ingredients_and_room() -> void:
	var drops := Phase7Fixtures.medicine(&"bitter_drops")
	var bundle := _held(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	_ingredients(drops)
	assert_eq(PultRules.medicine_block_reason(drops, bundle, inv, 0, cfg), PultRules.TEXT_SEAL_FIRST)
	assert_eq(PultRules.medicine_block_reason(drops, _held(&"liver", SpecimenRecord.CONTAINER_DISPLAY), inv, 0, cfg),
			PultRules.TEXT_JAR_ONLY)
	assert_eq(PultRules.medicine_block_reason(drops, _held(&"liver", SpecimenRecord.CONTAINER_JAR, 0.44), inv, 0, cfg),
			PultRules.TEXT_TOO_DIM, "below 0.45")
	assert_eq(PultRules.medicine_block_reason(drops, _held(&"liver", SpecimenRecord.CONTAINER_JAR, 0.45), inv, 0, cfg), "",
			"0.45 is enough")
	var spec := _held(&"liver")
	inv.remove_item(&"herbs", 1)
	assert_eq(PultRules.medicine_block_reason(drops, spec, inv, 0, cfg), PultRules.FORMAT_MISSING % WorkshopRules.describe({&"herbs": 1}))
	inv.add_item(&"herbs", 1)
	inv.remove_uid(spec.uid)
	assert_eq(PultRules.medicine_block_reason(drops, spec, inv, 0, cfg), PultRules.TEXT_NOT_HELD)
	inv.add_unique(Specimens.ITEM_JAR, spec.uid)
	spec.state = &"sold"
	assert_eq(PultRules.medicine_block_reason(drops, spec, inv, 0, cfg), PultRules.TEXT_GONE)
	assert_eq(PultRules.medicine_block_reason(null, spec, inv, 0, cfg), PultRules.TEXT_UNKNOWN)
	assert_eq(PultRules.medicine_block_reason(drops, null, inv, 0, cfg), PultRules.TEXT_NO_PIECE)


func test_make_medicine_consumes_the_piece_and_gives_the_output() -> void:
	var expect := {&"antidote": [&"stomach", 2], &"bitter_drops": [&"liver", 2], &"dropsy_powder": [&"kidneys", 1]}
	var made := 0
	for id: StringName in expect:
		var med := Phase7Fixtures.medicine(id)
		var spec := _held(expect[id][0])
		_ingredients(med)
		var before := {}
		for item: StringName in med.inputs:
			before[item] = inv.count(item)
		assert_true(PultRules.make_medicine(med, spec.uid, inv, specs, 0, cfg), String(id))
		made += 1
		assert_eq(inv.count(id), expect[id][1], "%s amount" % id)
		assert_false(inv.has_uid(spec.uid), "the piece is gone")
		assert_eq(specs.consumed.back(), [spec.uid, &"used"])
		assert_eq(specs.get_record(spec.uid).state, &"used")
		for item: StringName in med.inputs:
			assert_eq(inv.count(item), int(before[item]) - med.inputs[item], "%s %s taken" % [id, item])
		assert_eq(GameState.get_stat(&"medicines_made"), made)
		assert_false(PultRules.make_medicine(med, spec.uid, inv, specs, 0, cfg), "used up")
	assert_eq(notes.size(), 3)


func test_make_medicine_refused_changes_nothing() -> void:
	var med := Phase7Fixtures.medicine(&"antidote")
	var spec := _held(&"heart")
	_ingredients(med)
	assert_false(PultRules.make_medicine(med, spec.uid, inv, specs, 0, cfg))
	assert_true(inv.has_uid(spec.uid))
	assert_eq([inv.count(&"herb_bundle"), inv.count(&"antidote"), specs.consumed], [1, 0, []])
	var stomach := _held(&"stomach")
	GameState.set_flag(&"anatomy_known", false)
	assert_false(PultRules.book_known(cfg))
	assert_false(PultRules.make_medicine(med, stomach.uid, inv, specs, 0, cfg), "Quast's recipe book is needed")
	GameState.set_flag(&"anatomy_known", true)
	assert_false(PultRules.make_medicine(med, stomach.uid, inv, null, 0, cfg))
	assert_eq(GameState.get_stat(&"medicines_made"), 0)


func test_medicines_for() -> void:
	var meds := Phase7Fixtures.medicines()
	var ids := func(list: Array[MedicineData]) -> Array: return list.map(func(m: MedicineData) -> StringName: return m.id)
	assert_eq(ids.call(PultRules.medicines_for(&"liver", meds)), [&"antidote", &"bitter_drops"])
	assert_eq(ids.call(PultRules.medicines_for(&"kidneys", meds)), [&"dropsy_powder"])
	assert_eq(ids.call(PultRules.medicines_for(&"heart", meds)), [])


func test_medicine_data_matches_the_contract() -> void:
	assert_eq(Database.medicines().size(), 3)
	var expect := {  # §2.7: organs, inputs, minutes, amount
		&"antidote": [[&"stomach", &"liver"], {&"herb_bundle": 1, &"spirits": 1}, 30, 2],
		&"bitter_drops": [[&"liver"], {&"herbs": 2, &"spirits": 1}, 30, 2],
		&"dropsy_powder": [[&"kidneys"], {&"herbs": 1, &"beeswax": 1}, 20, 1],
	}
	for id: StringName in expect:
		var m := Database.medicine(id) as MedicineData
		assert_not_null(m, String(id))
		if m == null:
			continue
		var e: Array = expect[id]
		assert_eq([Array(m.organs), m.inputs, m.minutes, m.amount, m.output], [e[0], e[1], e[2], e[3], id], String(id))
		assert_almost(m.min_clarity, 0.45)
		for organ: StringName in m.organs:
			assert_true(bool(cfg.organ(organ).medicine), "%s: organ marked as medicine" % id)
			assert_false(organ in [&"heart", &"eyes", &"hand"])
		var item := Database.item(id) as ItemData
		assert_not_null(item, "item %s" % id)
		assert_eq([item.category, item.max_stack], [ItemData.Category.CRAFTED, 5], String(id))
		assert_true(item.description.contains("nach Quast"), "only the label „nach Quast“")
	# Quast buys the medicines (§2.7: 7 / 6 / 8).
	var surgeon := Database.shop(&"surgeon") as ShopData
	assert_eq([surgeon.buys[&"antidote"].price, surgeon.buys[&"bitter_drops"].price, surgeon.buys[&"dropsy_powder"].price], [7, 6, 8])
