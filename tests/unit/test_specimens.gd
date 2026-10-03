extends TestCase
## P4 (docs/PHASE7_DESIGN.md §2.6, §2.6.1–§2.6.3, §3.4, §10): SpecimenRules and Systems/Specimens – clarity
## (a jar keeps it, a bundle falls linearly to 0 in 600 min, × 0.25 in the cold box: windows, a multi-day
## jump, a load inside a window), spoiled, the clarity words, Quast's prices (§2.6.1 incl. the university
## standing and „Befreundet"), the finding priority with the effective cause and the seed roll, the
## pieces made at the table (inputs, uid, label), sale / expertise / lecture / medicine / return exclude
## each other, seal / bone / display, the spoil note once, kept, save / load.

class ManagerDouble extends CorpseManager:
	func _ready() -> void:
		pass

	func put(r: CorpseRecord) -> void:
		_records[r.id] = r

	func refresh_decay(_id: String) -> void:
		pass


class RelDouble extends Relationships:
	var sold := 0
	var returned := 0
	var adds: Array = []
	var surgeon_tier := &"stranger"

	func tier(npc_id: StringName) -> StringName:
		return surgeon_tier if npc_id == &"surgeon" else &"stranger"

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		adds.append([npc_id, delta])
		return 0

	func on_specimen_sold() -> void:
		sold += 1

	func on_specimen_returned() -> void:
		returned += 1


class PietyDouble extends Piety:
	var changes: Array = []

	func _ready() -> void:
		pass

	func change(delta: int, reason: String) -> void:
		changes.append([delta, reason])


var cfg: AnatomyConfig
var world: Node
var manager: ManagerDouble
var specimens: Specimens
var rel: RelDouble
var piety: PietyDouble
var deductions: Deductions
var lectures: Lectures
var inv: Inventory
var changes: Array = []
var notes: Array = []
var _injected: Array[StringName] = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": 3, "minute_of_day": 600})
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase7Fixtures.item(id)
			_injected.append(id)
	cfg = Phase7Fixtures.anatomy_config()
	world = Node.new()
	world.name = "SpecimenWorld"
	manager = ManagerDouble.new()
	world.add_child(manager)
	specimens = Specimens.new()
	specimens.config = cfg
	specimens.findings = Phase7Fixtures.findings()
	world.add_child(specimens)
	rel = RelDouble.new()
	world.add_child(rel)
	piety = PietyDouble.new()
	world.add_child(piety)
	deductions = Deductions.new()
	deductions.deductions = Phase7Fixtures.deductions()
	world.add_child(deductions)
	lectures = Lectures.new()
	lectures.config = cfg
	world.add_child(lectures)
	tree.root.add_child(world)
	inv = Inventory.new()
	inv.slot_count = 12
	changes.clear()
	notes.clear()
	EventBus.specimen_changed.connect(_on_change)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.specimen_changed.disconnect(_on_change)
	EventBus.notification_requested.disconnect(_on_note)
	if is_instance_valid(world):
		world.free()
	inv.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	GameState.reset()


func _on_change(uid: String, state: StringName) -> void:
	changes.append([uid, state])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _corpse(id: String = "c_1", cause: StringName = &"fever", traits: Array[StringName] = [], freshness: float = 0.9) -> CorpseRecord:
	var r := Phase4Fixtures.corpse(traits, cause, freshness)
	r.id = id
	r.display_name = "Hedwig Lamprecht"
	r.age = 58
	r.location = CorpseRecord.LOCATION_TABLE
	r.room = &"crypt"
	manager.put(r)
	return r


func _take(organ: StringName, container: StringName, corpse_id: String = "c_1") -> String:
	for id: StringName in SpecimenRules.harvest_inputs(organ, container, cfg):
		inv.add_item(id, SpecimenRules.harvest_inputs(organ, container, cfg)[id])
	return specimens.harvest(corpse_id, organ, container, inv)


# --- clarity ------------------------------------------------------------------------------------

func test_jar_keeps_its_clarity_bundle_falls_in_600_minutes() -> void:
	var jar := Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_JAR, 0.9, null, 1000)
	var bundle := Phase7Fixtures.specimen(&"liver", SpecimenRecord.CONTAINER_BUNDLE, 0.9, null, 1000)
	assert_almost(SpecimenRules.clarity(jar, 1000 + 50000, cfg), 0.9, 1e-6, "a jar keeps forever")
	assert_almost(SpecimenRules.clarity(bundle, 1000, cfg), 0.9, 1e-6)
	assert_almost(SpecimenRules.clarity(bundle, 1180, cfg), 0.63, 1e-6, "§2.6.1: liver bundle after 3 h")
	assert_almost(SpecimenRules.clarity(bundle, 1300, cfg), 0.45, 1e-6, "half way")
	assert_false(SpecimenRules.is_spoiled(bundle, 1599, cfg))
	assert_true(SpecimenRules.is_spoiled(bundle, 1600, cfg), "10 h")
	assert_almost(SpecimenRules.clarity(bundle, 9000, cfg), 0.0)
	assert_false(SpecimenRules.is_spoiled(jar, 99999, cfg), "jars never spoil")


func test_cold_box_slows_a_bundle_by_a_quarter() -> void:
	var b := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_BUNDLE, 1.0, null, 0)
	b.cold_windows = PackedInt32Array([60, 460, 250])
	# 60 warm + 400 × 0.25 = 100 + 40 warm after → 200 effective at 500.
	assert_almost(SpecimenRules.effective_minutes(b, 500), 200.0, 1e-6)
	assert_almost(SpecimenRules.clarity(b, 500, cfg), 1.0 - 200.0 / 600.0, 1e-6)
	var open := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_BUNDLE, 1.0, null, 0)
	open.cold_windows = PackedInt32Array([0, -1, 250])
	assert_false(SpecimenRules.is_spoiled(open, 2399, cfg), "≈ 40 h in the cold box")
	assert_true(SpecimenRules.is_spoiled(open, 2400, cfg))
	# A multi-day jump is one expression of the minute difference.
	var stepwise := 0.0
	for t: int in [600, 1200, 1800]:
		stepwise = SpecimenRules.clarity(open, t, cfg)
	assert_almost(stepwise, SpecimenRules.clarity(open, 1800, cfg), 1e-9)
	# Load in the middle of a window: the saved open window runs on.
	var back := SpecimenRecord.from_dict(JSON.parse_string(JSON.stringify(open.to_dict())) as Dictionary)
	assert_almost(SpecimenRules.clarity(back, 1500, cfg), SpecimenRules.clarity(open, 1500, cfg), 1e-9)


func test_note_cold_opens_and_closes_a_window() -> void:
	_corpse()
	var uid := _take(&"stomach", SpecimenRecord.CONTAINER_BUNDLE)
	var spec := specimens.get_record(uid)
	var t0 := TimeManager.total_minutes()
	specimens.note_cold(uid, true)
	specimens.note_cold(uid, true)
	assert_eq(spec.cold_windows, PackedInt32Array([t0, -1, 250]), "one open window")
	TimeManager.advance(120)
	specimens.note_cold(uid, false)
	assert_eq(spec.cold_windows, PackedInt32Array([t0, t0 + 120, 250]))
	assert_almost(specimens.clarity(uid), 0.9 * (1.0 - 30.0 / 600.0), 1e-6)
	var jar := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	specimens.note_cold(jar, true)
	assert_eq(specimens.get_record(jar).cold_windows, PackedInt32Array(), "only bundles")


func test_clarity_words() -> void:
	var words := []
	for c: float in [1.0, 0.8, 0.79, 0.6, 0.59, 0.45, 0.44, 0.3]:
		words.append(SpecimenRules.clarity_word(c, cfg))
	assert_eq(words, ["sehr gut", "sehr gut", "gut", "gut", "trüb", "trüb", "kaum lesbar", "kaum lesbar"])


# --- prices -------------------------------------------------------------------------------------

func test_prices_of_section_2_6_1() -> void:
	var heart := Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_JAR, 0.9, null, 0)
	assert_eq(SpecimenRules.price(heart, 0, false, cfg), 7, "heart jar 0.9")
	assert_eq(SpecimenRules.price(heart, 0, true, cfg), 8, "Quast „Befreundet\" +1")
	var eyes := Phase7Fixtures.specimen(&"eyes", SpecimenRecord.CONTAINER_JAR, 0.8, null, 0)
	assert_eq(SpecimenRules.price(eyes, 0, false, cfg), 8, "eyes 0.8")
	var liver := Phase7Fixtures.specimen(&"liver", SpecimenRecord.CONTAINER_BUNDLE, 0.9, null, 0)
	assert_eq(SpecimenRules.price(liver, 180, false, cfg), 2, "liver bundle after 3 h")
	assert_eq(SpecimenRules.price(liver, 600, false, cfg), 0, "spoiled: nothing")
	var bone := Phase7Fixtures.specimen(&"hand", SpecimenRecord.CONTAINER_BONE, 0.4, null, 0)
	assert_eq(SpecimenRules.price(bone, 0, false, cfg), 10, "the bone specimen = base price")
	var display := Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_DISPLAY, 0.9, null, 0)
	assert_eq(SpecimenRules.price(display, 0, false, cfg), 12, "heart display")
	assert_eq(SpecimenRules.price(null, 0, false, cfg), 0)


func test_sale_price_adds_the_university_standing() -> void:
	_corpse()
	var uid := _take(&"heart", SpecimenRecord.CONTAINER_JAR)
	assert_eq(specimens.sale_price(uid), 7)
	GameState.stats[&"university_standing"] = 1
	assert_eq(specimens.sale_price(uid), 8, "+1 per level")
	GameState.stats[&"university_standing"] = 4
	assert_eq(specimens.sale_price(uid), 9, "at most +2")
	rel.surgeon_tier = &"friend"
	assert_eq(specimens.sale_price(uid), 10)


# --- findings -----------------------------------------------------------------------------------

func _finding(organ: StringName, cause: StringName, traits: Array[StringName] = [], hidden: StringName = &"", seed: int = 1) -> StringName:
	var r := Phase4Fixtures.corpse(traits, cause)
	r.hidden_cause = hidden
	r.seed = seed
	var spec := Phase7Fixtures.specimen(organ, SpecimenRecord.CONTAINER_JAR, 0.9, r)
	var f := SpecimenRules.finding_for(spec, r, Phase7Fixtures.findings())
	return f.id if f != null else &""


func test_finding_priority_and_conditions() -> void:
	assert_eq(_finding(&"heart", &"old_age", [&"strange_wound"]), &"b_still_heart", "marked beats old age (priority)")
	assert_eq(_finding(&"heart", &"old_age"), &"b_old_heart")
	assert_eq(_finding(&"heart", &"fever"), &"b_plain", "fallback")
	assert_eq(_finding(&"stomach", &"fever", [], &"arsenic"), &"b_white_stomach", "hidden cause counts")
	assert_eq(_finding(&"stomach", &"poisoned"), &"b_white_stomach", "either field matches")
	assert_eq(_finding(&"stomach", &"fever"), &"b_empty_stomach")
	assert_eq(_finding(&"liver", &"fever", [], &"arsenic"), &"b_pale_liver")
	assert_eq(_finding(&"liver", &"old_age", [], &"drink"), &"b_hard_liver")
	assert_eq(_finding(&"lung", &"drowned_millpond", [], &"dead_before_water"), &"b_dry_lungs")
	assert_eq(_finding(&"lung", &"drowned_millpond"), &"b_wet_lungs")
	assert_eq(_finding(&"lung", &"fever"), &"b_spotted_lungs")
	assert_eq(_finding(&"lung", &"fever", [], &"arsenic"), &"b_plain", "the effective cause is arsenic")
	assert_eq(_finding(&"eyes", &"moor_cold"), &"b_moor_eyes")
	assert_eq(_finding(&"eyes", &"fever"), &"b_fever_eyes")
	assert_eq(_finding(&"hand", &"fever", [&"tattoo"]), &"b_oath_hand")
	assert_eq(_finding(&"hand", &"fever"), &"b_worker_hand", "always")


func test_kidney_stones_one_in_four_from_the_seed() -> void:
	var hits := 0
	for s: int in 400:
		var id := _finding(&"kidneys", &"fever", [], &"", s * 7919 + 17)
		assert_true(id in [&"b_stones", &"b_plain"])
		if id == &"b_stones":
			hits += 1
	assert_true(hits > 60 and hits < 140, "≈ 1 in 4 (%d / 400)" % hits)
	assert_eq(_finding(&"kidneys", &"fever", [], &"", 12345), _finding(&"kidneys", &"fever", [], &"", 12345), "deterministic")


# --- harvest rules ------------------------------------------------------------------------------

func test_harvest_block_reasons_in_order() -> void:
	var r := _corpse()
	inv.add_item(&"anatomy_case", 1)
	inv.add_item(&"prep_jar", 2)
	inv.add_item(&"spirits", 2)
	var room := &"crypt"
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, false, cfg), "-", "no card without anatomy_known")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, &"", true, cfg), "-", "only the crypt table")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), "")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"brain", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_UNKNOWN, "no such organ")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"eyes", &"bundle", inv, room, true, cfg), SpecimenRules.TEXT_ONLY_JAR)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"hand", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_ONLY_BUNDLE)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"eyes", &"jar", inv, room, true, cfg), "Es fehlt: kleines Präparatglas",
			"the eyes need the small dark jar")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"hand", &"bundle", inv, room, true, cfg).begins_with("Es fehlt:"), true)
	r.harvested = [&"hair", &"teeth", &"heart", &"lung"] as Array[StringName]
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_TAKEN)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"liver", &"jar", inv, room, true, cfg), "", "hair / teeth do not count")
	r.harvested.append(&"stomach")
	assert_eq(SpecimenRules.harvest_block_reason(r, &"liver", &"jar", inv, room, true, cfg), "Mehr nimmst du ihr nicht.", "at most 3")
	r.harvested = [] as Array[StringName]
	r.freshness = 0.29
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_TOO_LATE)
	r.freshness = 0.3
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), "", "exactly 0.3")
	inv.remove_item(&"anatomy_case", 1)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_NO_TOOL)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", null, room, true, cfg), SpecimenRules.TEXT_NO_TOOL)
	inv.add_item(&"anatomy_case", 1)
	r.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), SpecimenRules.TEXT_DRESSED)
	r.dress = CorpseRecord.DRESS_NONE
	var full := Inventory.new()
	full.slot_count = 3
	full.add_item(&"anatomy_case", 1)
	full.add_item(&"prep_jar", 1)
	full.add_item(&"spirits", 1)
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", full, room, true, cfg), SpecimenRules.TEXT_FULL, "room for the piece")
	full.free()
	r.location = CorpseRecord.LOCATION_GROUND
	assert_eq(SpecimenRules.harvest_block_reason(r, &"heart", &"jar", inv, room, true, cfg), "-", "only on the table")


# --- the pieces ---------------------------------------------------------------------------------

func test_harvest_makes_a_named_piece_and_takes_the_inputs() -> void:
	_corpse()
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	var uid := specimens.harvest("c_1", &"heart", &"jar", inv)
	assert_eq(uid, "sp_0001")
	assert_eq([inv.count(&"prep_jar"), inv.count(&"spirits")], [0, 0], "jar + spirits gone")
	assert_eq(inv.uids(&"specimen_jar"), PackedStringArray(["sp_0001"]))
	var spec := specimens.get_record(uid)
	assert_eq([spec.organ, spec.container, spec.corpse_id, spec.corpse_name, spec.day], [&"heart", &"jar", "c_1", "Hedwig Lamprecht", 3])
	assert_almost(spec.clarity_at_harvest, 0.9, 1e-6, "clarity = freshness at the end")
	assert_eq(specimens.label(uid), "Herz – Hedwig Lamprecht, 58 – Klarheit sehr gut")
	assert_eq(changes, [["sp_0001", &"taken"]])
	assert_eq(specimens.harvest("c_1", &"lung", &"jar", inv), "", "no inputs left")
	var eyes := _take(&"eyes", &"jar")
	assert_eq(inv.uid_item(eyes), &"specimen_jar")
	assert_eq(inv.count(&"prep_jar_small"), 0, "the small dark jar")
	var hand := _take(&"hand", &"bundle")
	assert_eq(inv.uid_item(hand), &"specimen_bundle", "the hand only in linen")
	assert_eq([inv.count(&"linen"), inv.count(&"beeswax")], [0, 0])
	assert_eq(specimens.harvest("c_1", &"eyes", &"bundle", inv), "", "eyes never in a bundle")
	assert_eq(specimens.harvest("nobody", &"heart", &"jar", inv), "")
	assert_eq(specimens.held(), PackedStringArray([uid, eyes, hand]))
	assert_eq(specimens.of_corpse("c_1").size(), 3)


func test_sell_once_and_the_village_hears_of_it() -> void:
	_corpse()
	var uid := _take(&"heart", &"jar")
	var paid := []
	var on_pay := func(n: int, reason: String) -> void: paid.append([n, reason])
	EventBus.payment_received.connect(on_pay)
	assert_eq(specimens.sell(uid, inv), 7)
	EventBus.payment_received.disconnect(on_pay)
	assert_eq(paid, [[7, "Präparat an Quast: Herz"]])
	assert_eq(inv.count(&"coin"), 7)
	assert_false(inv.has_uid(uid))
	assert_eq(specimens.get_record(uid).state, &"sold")
	assert_eq(GameState.get_stat(&"specimens_sold"), 1)
	assert_eq(rel.sold, 1)
	assert_eq(rel.adds, [], "inner organs: only the villagers' specimen_delta")
	assert_eq(specimens.sell(uid, inv), 0, "once")
	assert_eq(specimens.return_block_reason(uid, "g_1"), Specimens.TEXT_GONE, "sold pieces do not come back")
	var eyes := _take(&"eyes", &"jar")
	specimens.sell(eyes, inv)
	assert_eq(rel.adds, [[&"priest", -2], [&"washer", -2]], "eyes / hand: priest −6, washer −5 in all")


func test_sale_expertise_lecture_medicine_return_exclude_each_other() -> void:
	_corpse()
	var a := _take(&"stomach", &"jar")
	var result := specimens.expertise(a, inv)
	assert_eq(result.finding, &"b_empty_stomach")
	assert_eq(result.teaching, &"l_stomach")
	assert_true(result.learned)
	assert_eq(specimens.get_record(a).state, &"researched")
	assert_false(inv.has_uid(a), "the piece stays with Quast")
	assert_eq(deductions.cards("c_1"), PackedStringArray(["b_empty_stomach", "l_stomach"]))
	assert_eq(rel.adds, [[&"surgeon", 3]])
	assert_eq(GameState.get_stat(&"specimens_researched"), 1)
	for f: Callable in [func() -> bool: return specimens.sell(a, inv) > 0, func() -> bool: return not specimens.expertise(a, inv).is_empty(),
			func() -> bool: return specimens.consume(a, inv, &"lectured")]:
		assert_false(f.call())
	var b := _take(&"liver", &"jar")
	assert_false(specimens.consume(b, inv, &"sold"), "only lectured / used")
	assert_true(specimens.consume(b, inv, &"used"))
	assert_false(specimens.consume(b, inv, &"lectured"))
	assert_eq(specimens.sell(b, inv), 0)
	assert_eq(changes.back(), [b, &"used"])


func test_inspect_keeps_the_piece_and_gives_a_card() -> void:
	_corpse("c_1", &"fever", [] as Array[StringName], 0.9).hidden_cause = &"arsenic"
	var jar := _take(&"stomach", &"jar")
	assert_eq(specimens.inspect(jar), &"b_white_stomach")
	assert_true(inv.has_uid(jar))
	assert_eq(specimens.get_record(jar).finding_id, &"b_white_stomach")
	assert_eq(deductions.finding_cards("c_1"), PackedStringArray(["b_white_stomach"]))
	var bundle := _take(&"lung", &"bundle")
	assert_eq(specimens.inspect(bundle), &"", "no bundle at the pult")
	manager.get_record("c_1").freshness = 0.4
	var cloudy := _take(&"heart", &"jar")
	assert_eq(specimens.inspect(cloudy), &"", "clarity below 0.5")


func test_seal_bone_display() -> void:
	_corpse()
	var lung := _take(&"lung", &"bundle")
	TimeManager.advance(60)
	assert_false(specimens.seal(lung, inv), "jar + spirits missing")
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	assert_true(specimens.seal(lung, inv))
	var spec := specimens.get_record(lung)
	assert_eq([spec.container, inv.uid_item(lung)], [&"jar", &"specimen_jar"], "same uid, new item")
	assert_almost(spec.sealed_clarity, 0.9 * (1.0 - 60.0 / 600.0), 1e-6, "the clarity of the moment")
	TimeManager.advance(2000)
	assert_almost(specimens.clarity(lung), spec.sealed_clarity, 1e-9, "kept from then on")
	inv.add_item(&"beeswax", 1)
	inv.add_item(&"ink", 1)
	assert_true(specimens.make_display(lung, inv))
	assert_eq([spec.container, inv.uid_item(lung)], [&"display", &"display_specimen"])
	var hand := _take(&"hand", &"bundle")
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	assert_false(specimens.seal(hand, inv), "the hand is not put in a jar")
	inv.add_item(&"beeswax", 1)
	inv.add_item(&"linen", 1)
	assert_true(specimens.make_bone(hand, inv))
	assert_eq([specimens.get_record(hand).container, inv.uid_item(hand)], [&"bone", &"bone_specimen"])
	TimeManager.advance(5000)
	assert_false(specimens.is_spoiled(hand), "a bone specimen never spoils")
	var late := _take(&"kidneys", &"bundle")
	TimeManager.advance(600)
	assert_true(specimens.is_spoiled(late))
	assert_false(specimens.seal(late, inv), "spoiled: no longer sealable")
	assert_eq(specimens.sell(late, inv), 0, "nor saleable")
	assert_eq(specimens.label(late), "Nieren – Hedwig Lamprecht, 58 – verdorben")


func test_spoil_note_once_and_after_load() -> void:
	_corpse()
	var uid := _take(&"liver", &"bundle")
	TimeManager.advance(599)
	specimens.check_spoiled(TimeManager.total_minutes())
	assert_eq(notes.filter(func(t: String) -> bool: return t.contains("verdorben")), [])
	TimeManager.advance(1)
	specimens.check_spoiled(TimeManager.total_minutes())
	specimens.check_spoiled(TimeManager.total_minutes() + 60)
	assert_eq(notes.filter(func(t: String) -> bool: return t.contains("verdorben")), ["Das Bündel von Hedwig Lamprecht ist verdorben."])
	assert_eq(changes.back(), [uid, &"spoiled"])
	var state := specimens.save_state()
	specimens.load_state(state)
	specimens.check_spoiled(TimeManager.total_minutes())
	assert_eq(notes.filter(func(t: String) -> bool: return t.contains("verdorben")).size(), 1, "not again after a load")


func test_return_to_grave() -> void:
	var r := _corpse()
	var heart := _take(&"heart", &"jar")
	var hand := _take(&"hand", &"bundle")
	r.harvested = [&"heart", &"hand"] as Array[StringName]
	var graveyard := Graveyard.new()
	var g := GraveRecord.new()
	g.id = "g_1"
	g.state = GraveRecord.State.FILLED
	g.corpse_id = "c_1"
	var other := GraveRecord.new()
	other.id = "g_2"
	other.state = GraveRecord.State.MARKED
	other.corpse_id = "c_9"
	graveyard.load_state({"graves": [g.to_dict(), other.to_dict()]})
	world.add_child(graveyard)
	assert_eq(specimens.return_block_reason(heart, "g_2"), Specimens.TEXT_NOT_HERE)
	assert_eq(specimens.return_block_reason(heart, "g_1"), "")
	assert_true(specimens.return_to_grave(heart, "g_1", inv))
	assert_eq(r.returned, [&"heart"] as Array[StringName])
	assert_eq(piety.changes.back(), [3, "Präparat beigesetzt: Herz"])
	TimeManager.advance(700)
	assert_true(specimens.is_spoiled(hand))
	assert_eq(specimens.return_block_reason(hand, "g_1"), "", "a spoiled bundle may still go back")
	assert_true(specimens.return_to_grave(hand, "g_1", inv))
	assert_eq(piety.changes.back()[0], 5, "eyes / hand +5")
	assert_eq([rel.returned, GameState.get_stat(&"specimens_returned")], [2, 2])
	assert_false(specimens.return_to_grave(heart, "g_1", inv), "once")
	assert_eq(specimens.get_record(heart).state, &"returned")


func test_kept_counts_held_unspoiled_pieces() -> void:
	_corpse()
	_take(&"heart", &"jar")
	_corpse("c_2")
	var b := _take(&"heart", &"bundle", "c_2")
	assert_eq(specimens.kept(&"heart"), 2)
	TimeManager.advance(600)
	assert_eq(specimens.kept(&"heart"), 1, "a spoiled bundle is not kept")
	assert_eq(specimens.kept(&"lung"), 0)
	assert_true(specimens.get_record(b) != null)


func test_save_load_round_trip() -> void:
	_corpse()
	var a := _take(&"heart", &"jar")
	var b := _take(&"lung", &"bundle")
	specimens.note_cold(b, true)
	specimens.sell(a, inv)
	var state := specimens.save_state()
	assert_eq(state.next, 3)
	var json := JSON.parse_string(JSON.stringify(state)) as Dictionary
	var other := Specimens.new()
	other.load_state(json)
	assert_eq(JSON.stringify(JSON.from_native(other.save_state())), JSON.stringify(JSON.from_native(state)), "identical after a JSON round trip")
	assert_eq(other.held(), PackedStringArray([b]))
	assert_eq(other.get_record(a).state, &"sold")
	other.load_state({"records": [{"uid": "sp_0041", "organ": "liver"}]})
	assert_eq(other.save_state().next, 42, "next follows the highest uid")
	other.load_state({"records": "broken", "next": "x"})
	assert_eq(other.save_state(), {}, "tolerant")
	other.free()
	var fresh := Specimens.new()
	assert_eq(fresh.save_state(), {}, "fresh: nothing to save")
	fresh.free()
