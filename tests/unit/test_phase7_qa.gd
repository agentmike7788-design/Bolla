extends TestCase
## W3 QA of Phase 7 (docs/PHASE7_DESIGN.md §10, docs/reviews/phase7_wip/qa_playthrough.md): regression
## tests for the review findings that need no world (the world ones are in
## tests/integration/test_phase7_qa.gd).
## QA7-01 a sale of eyes / hand changes each villager once, by AnatomyConfig.organs[*].sell_rel ·
## QA7-02 the order / village tiers are RelationshipRules' · QA7-03 the Phase-7 reputation / piety events
## are in the data (no class-default fallback) · QA7-04 a cold window of length 0 is dropped (save / load
## identical) · QA7-05 the schedules of the G7 motifs (Theres and Liesel at the well with Fenner at the
## board and Wiebke at her gate; Osric walks into the Holderkrug at night; Quast at the lectern on a
## lecture night, also after midnight) · QA7-06 the shop discount reads at 720p.

var world: Node
var specimens: Specimens
var rel: Relationships
var inv: Inventory
var changes: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": 42, "minute_of_day": 600})
	changes.clear()


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	if is_instance_valid(inv):
		inv.free()
	GameState.reset()
	TimeManager.reset()


func _sale_world() -> void:
	world = Node.new()
	world.name = "QA7World"
	rel = Relationships.new()
	rel.config = Phase7Fixtures.relationship_config()
	rel.anatomy_config = Phase7Fixtures.anatomy_config()
	for v: VillagerData in Phase7Fixtures.villagers():
		rel.villagers[v.npc_id] = v
	world.add_child(rel)
	specimens = Specimens.new()
	specimens.config = Phase7Fixtures.anatomy_config()
	world.add_child(specimens)
	tree.root.add_child(world)
	inv = Inventory.new()
	inv.slot_count = 12
	for id: StringName in Phase7Fixtures.VILLAGER_IDS:
		rel.meet(id)
		rel.add(id, 30, "QA: far from the clamp")


func _held(organ: StringName, container: StringName = SpecimenRecord.CONTAINER_JAR) -> String:
	var spec := Phase7Fixtures.specimen(organ, container, 0.9, null, TimeManager.total_minutes())
	var records: Array = []
	for uid: String in specimens.held():
		records.append(specimens.get_record(uid).to_dict())
	records.append(spec.to_dict())
	specimens.load_state({"next": 1, "records": records})
	assert_true(inv.add_unique(SpecimenRules.item_for(container), spec.uid))
	return spec.uid


func _on_rel(npc_id: StringName, _value: int, _tier: StringName, delta: int, _reason: String) -> void:
	changes.append([npc_id, delta])


# --- QA7-01 -----------------------------------------------------------------------------------------

func test_qa7_01_eyes_and_hand_sales_change_each_villager_once() -> void:
	_sale_world()
	var before := {}
	for id: StringName in Phase7Fixtures.VILLAGER_IDS:
		before[id] = rel.value(id)
	EventBus.relationship_changed.connect(_on_rel)
	var eyes := _held(&"eyes")
	assert_true(specimens.sell(eyes, inv) > 0, "Quast buys the eyes")
	EventBus.relationship_changed.disconnect(_on_rel)
	var row: Dictionary = Phase7Fixtures.anatomy_config().organ(&"eyes").sell_rel
	for id: StringName in [&"priest", &"washer", &"oldwoman"]:
		assert_eq(rel.value(id) - int(before[id]), int(row[id]), "%s: the eyes' sell_rel (%d)" % [id, int(row[id])])
	assert_eq(rel.value(&"surgeon") - int(before[&"surgeon"]), 2, "Quast +2 (specimen_delta)")
	var per := {}
	for c: Array in changes:
		per[c[0]] = int(per.get(c[0], 0)) + 1
	for id: Variant in per:
		assert_eq(per[id], 1, "%s hears of the sale once (one relationship_changed)" % id)
	# The inner organs keep the villagers' own specimen_delta (priest −4, washer −3).
	var p := rel.value(&"priest")
	var w := rel.value(&"washer")
	assert_true(specimens.sell(_held(&"liver"), inv) > 0)
	assert_eq([rel.value(&"priest") - p, rel.value(&"washer") - w], [-4, -3])


func test_qa7_01_the_sale_needs_no_base_organ_row() -> void:
	# With the heart's row changed in the data, an eye sale still yields exactly the eyes' deltas – the
	# old code added (eyes − heart) on top of specimen_delta.
	_sale_world()
	var cfg := Phase7Fixtures.anatomy_config().duplicate(true) as AnatomyConfig
	var heart: Dictionary = cfg.organs[&"heart"].duplicate(true)
	heart["sell_rel"] = {&"priest": -1, &"washer": -1, &"oldwoman": -1}
	cfg.organs[&"heart"] = heart
	specimens.config = cfg
	rel.anatomy_config = cfg
	var p := rel.value(&"priest")
	assert_true(specimens.sell(_held(&"hand", SpecimenRecord.CONTAINER_BONE), inv) > 0)
	assert_eq(rel.value(&"priest") - p, int(cfg.organ(&"hand").sell_rel[&"priest"]), "hand: priest −6, whatever the heart's row says")


# --- QA7-02 -----------------------------------------------------------------------------------------

func test_qa7_02_order_tiers_are_relationship_rules() -> void:
	var cfg := Phase7Fixtures.relationship_config()
	var broken := cfg.duplicate(true) as RelationshipConfig
	broken.tier_thresholds = PackedInt32Array([20])
	for v: int in range(0, 101):
		assert_eq(OrderRules.rel_tier(v, cfg), RelationshipRules.tier(v, cfg), "value %d" % v)
		assert_eq(OrderRules.rel_tier(v, broken), RelationshipRules.tier(v, broken), "malformed thresholds, value %d" % v)
	for t: StringName in RelationshipRules.TIERS:
		assert_eq(OrderRules.tier_index(t), RelationshipRules.tier_index(t))
		assert_eq(OrderRules.tier_word(t), RelationshipRules.word(t))
	assert_eq(OrderRules.TIERS, RelationshipRules.TIERS)


# --- QA7-03 -----------------------------------------------------------------------------------------

func test_qa7_03_phase7_events_are_listed_in_the_data() -> void:
	var rep := load("res://data/config/reputation_config.tres") as ReputationConfig
	var kinds: Array[StringName] = [&"organ_taken", &"organ_taken_grave", &"lecture_rumor", &"donation", &"order_failed",
			&"marker_upgrade", &"section_unlocked"]
	var anatomy := load("res://data/config/anatomy_config.tres") as AnatomyConfig
	for organ: StringName in AnatomyConfig.ORGANS:
		var kind := StringName(str(anatomy.organ(organ).get("reputation_event", "organ_taken")))
		if not kind in kinds:
			kinds.append(kind)
	for kind: StringName in kinds:
		assert_true(rep.event_points.has(kind), "reputation_config.tres lists %s (no class-default fallback)" % kind)
		assert_eq(rep.event_points[kind], ReputationConfig.new().event_points[kind], "%s = §2.11" % kind)
	var piety := load("res://data/config/piety_config.tres") as PietyConfig
	for kind: StringName in [&"organ_taken", &"lecture_attended", &"specimen_returned", &"specimen_returned_grave"]:
		assert_true(piety.events.has(kind), "piety_config.tres lists " + String(kind))


# --- QA7-04 -----------------------------------------------------------------------------------------

func test_qa7_04_cold_window_of_length_zero_is_dropped() -> void:
	_sale_world()
	var uid := _held(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	specimens.note_cold(uid, true)
	specimens.note_cold(uid, false)
	assert_eq(specimens.get_record(uid).cold_windows, PackedInt32Array(), "in and out in the same minute: no window")
	specimens.note_cold(uid, true)
	TimeManager.advance(30)
	specimens.note_cold(uid, false)
	var w := specimens.get_record(uid).cold_windows
	assert_eq(w.size(), 3, "a real window stays")
	assert_eq(w[1] - w[0], 30)
	# Open and closed in one minute again (seal at once): still only the 30-minute window.
	specimens.note_cold(uid, true)
	specimens.note_cold(uid, false)
	var saved := specimens.save_state()
	var other := Specimens.new()
	other.config = Phase7Fixtures.anatomy_config()
	other.load_state(saved.duplicate(true))
	assert_eq(other.save_state(), saved, "save → load identical")
	assert_eq(other.get_record(uid).cold_windows, w)
	other.free()


func test_qa7_04_sealing_inside_the_minute_it_went_in_leaves_no_window() -> void:
	_sale_world()
	var uid := _held(&"liver", SpecimenRecord.CONTAINER_BUNDLE)
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	specimens.note_cold(uid, true)
	assert_true(specimens.seal(uid, inv), "sealed")
	assert_eq(specimens.get_record(uid).cold_windows, PackedInt32Array())
	var saved := specimens.save_state()
	var other := Specimens.new()
	other.load_state(saved.duplicate(true))
	assert_eq(other.save_state(), saved)
	other.free()


# --- QA7-05 -----------------------------------------------------------------------------------------

func _at(npc_id: StringName, minute: int, day: int) -> ScheduleEntry:
	return ScheduleResolver.entry_at(Database.schedule(npc_id) as NpcSchedule, minute, day)


static func _end(e: ScheduleEntry) -> String:
	return String(e.path[e.path.size() - 1]) if e != null and not e.path.is_empty() else ""


func test_qa7_05_theres_and_liesel_meet_at_the_well() -> void:
	# p7_03 „Anger am Nachmittag": Theres and Liesel at the well, Wiebke at her gate, Fenner at the board.
	var together: Array[int] = []
	for minute: int in range(0, 1440):
		var g := _at(&"grocer", minute, 41)
		var w := _at(&"washer", minute, 41)
		if g.visible and w.visible and g.travel_minutes == 0 and w.travel_minutes == 0 and _end(g) == "v_well" and _end(w) == "v_well_w":
			together.append(minute)
	assert_false(together.is_empty(), "Theres and Liesel stand at the well together (Liesel on its west side, v_well_w)")
	assert_eq([together.front(), together.back()], [965, 989], "16:05–16:30")
	var at := 975
	assert_eq(_end(_at(&"mayor", at, 41)), "v_board", "Fenner at the board")
	var o := _at(&"oldwoman", at, 41)
	assert_true(o.visible and _end(o) == "v_hagedorn_gate", "Wiebke at her gate")
	# Theres keeps her shop hours (§2.2: 07:25 on, home at 18:00), only her break moved.
	var shop := 0
	for minute: int in range(0, 1440):
		var e := _at(&"grocer", minute, 41)
		if e.visible and e.activity == &"shop":
			shop += 1
	assert_eq(shop, (960 - 445) + (1080 - 995), "shop minutes unchanged (25 min break)")


func test_qa7_05_osric_walks_into_the_holderkrug_at_night() -> void:
	var walk := _at(&"carter", 1318, 41)
	assert_eq(walk.region, &"village")
	assert_true(walk.visible and walk.travel_minutes > 0, "on his way at 21:58")
	assert_eq(_end(walk), "v_inn_door", "to the Holderkrug's door")
	assert_eq(_end(_at(&"carter", 1320, 41)), "v_in_inn_corner", "inside at 22:00")
	# The graveyard routine stays: the village walk falls into his „home" time on the graveyard.
	var graveyard := NpcSchedule.new()
	for e: ScheduleEntry in (Database.schedule(&"carter") as NpcSchedule).entries:
		if e.region == &"":
			graveyard.entries.append(e)
	assert_false(ScheduleResolver.entry_at(graveyard, 1318, 41).visible)


func test_qa7_05_quast_at_the_lectern_on_a_lecture_night() -> void:
	var lectures := Phase7Fixtures.lecture_night(42, tree)
	# The flags come from the clock (hour_changed): day 42 is a lecture night (42 % 3 == 0).
	TimeManager.load_state({"day": 42, "minute_of_day": 1370})
	TimeManager.advance(20)
	assert_eq(int(GameState.get_flag(Lectures.FLAG_NIGHT, -1)), 42, "lecture_night_day = 42")
	var e := _at(&"surgeon", 1390, 42)
	assert_true(e.visible and e.dialogue_id == &"v_surgeon", "Quast is there to be asked (23:10)")
	assert_eq(_end(e), "v_in_surgery_lectern", "at the lectern")
	# After midnight (00:00–00:30 belong to the night of day 42; the lecture may run until 01:30).
	TimeManager.advance(1440 - 1390 + 15)
	assert_eq(TimeManager.day, 43)
	assert_eq(int(GameState.get_flag(Lectures.FLAG_AFTER, -1)), 43)
	var late := _at(&"surgeon", 15, 43)
	assert_true(late.visible and _end(late) == "v_in_surgery_lectern", "still at the lectern at 00:15")
	assert_false(_at(&"surgeon", 100, 43).visible, "home at 01:40")
	# Not a lecture night: at home as before.
	assert_false(_at(&"surgeon", 1390, 43).visible, "day 43, 23:10: home")
	assert_false(_at(&"surgeon", 1390, 41).visible, "day 41, 23:10: home")
	assert_false(_at(&"surgeon", 15, 42).visible, "day 42, 00:15 (after day 41): home")
	# The ordinary day is untouched (the shop entries).
	assert_eq(_end(_at(&"surgeon", 600, 42)), "v_in_surgery_desk")
	lectures.free()


# --- QA7-06 -----------------------------------------------------------------------------------------

func test_qa7_06_discount_reads_at_720p() -> void:
	var shown := Phase7Texts.shop_price(6, 5)
	assert_true(shown.discount)
	var bb := String(shown.bb)
	assert_true(bb.contains("[s]") and bb.contains("→") and bb.contains("#f2a93b"), "struck, arrow, the new price in amber: " + bb)
	assert_eq(String(Phase7Texts.shop_price(3, 3).bb), "3 Münzen", "no discount: plain")
