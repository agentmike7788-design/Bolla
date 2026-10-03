extends TestCase
## P2 (docs/PHASE7_DESIGN.md §2.1, §2.4, §3.4, §5.1, §10): RelationshipRules and Relationships – the
## start value (reputation bonus, piety bonus only for piety_sensitive villagers), the tiers 15/40/70,
## the clamp 0…100, a talk +1 once per day, gifts only liked and once per day, the round / donation
## gains, the specimen sold / returned deltas (eyes / hand weigh more), count_at_least, the remark
## precedence (friend → piety → specimens → reputation) once per day, save / load (§5.1 format,
## tolerant). Villagers from tests/fixtures/phase7 (Phase7Fixtures), the clock set directly.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")

var rel: Relationships
var inv: Inventory
var changes: Array = []
var remarks: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	GameState.stats[&"reputation"] = 40  # Geachtet
	GameState.stats[&"piety"] = 0  # Sachlich
	TimeManager.day = 5
	TimeManager.minute_of_day = 600
	rel = Relationships.new()
	rel.config = Phase7Fixtures.relationship_config()
	rel.anatomy_config = Phase7Fixtures.anatomy_config()
	for v: VillagerData in Phase7Fixtures.villagers():
		rel.villagers[v.npc_id] = v
	tree.root.add_child(rel)
	inv = FakeInventory.new()
	tree.root.add_child(inv)
	changes.clear()
	remarks.clear()
	EventBus.relationship_changed.connect(_on_changed)
	EventBus.villager_remarked.connect(_on_remark)


func after_each() -> void:
	EventBus.relationship_changed.disconnect(_on_changed)
	EventBus.villager_remarked.disconnect(_on_remark)
	rel.free()
	inv.free()
	GameState.reset()
	TimeManager.reset()


func _on_changed(npc_id: StringName, value: int, tier: StringName, delta: int, reason: String) -> void:
	changes.append([npc_id, value, tier, delta, reason])


func _on_remark(npc_id: StringName, text: String) -> void:
	remarks.append([npc_id, text])


# --- rules ----------------------------------------------------------------------------------

func test_tiers_at_15_40_70() -> void:
	var cfg := Phase7Fixtures.relationship_config()
	var expect := {0: &"stranger", 14: &"stranger", 15: &"acquainted", 39: &"acquainted", 40: &"trusted", 69: &"trusted",
			70: &"friend", 100: &"friend"}
	for v: int in expect:
		assert_eq(RelationshipRules.tier(v, cfg), expect[v], "value %d" % v)
	assert_eq([RelationshipRules.word(&"stranger"), RelationshipRules.word(&"acquainted"), RelationshipRules.word(&"trusted"),
			RelationshipRules.word(&"friend"), RelationshipRules.word(&"nope")], ["Fremd", "Bekannt", "Vertraut", "Befreundet", ""])
	assert_true(RelationshipRules.at_least(&"friend", &"trusted"))
	assert_false(RelationshipRules.at_least(&"acquainted", &"trusted"))
	var odd := RelationshipConfig.new()
	odd.tier_thresholds = PackedInt32Array([10])
	assert_eq(RelationshipRules.tier(50, odd), &"trusted", "broken thresholds → defaults")


func test_start_value_reputation_and_piety_bonus() -> void:
	var cfg := Phase7Fixtures.relationship_config()
	var rosine := Phase7Fixtures.villager_data(&"innkeeper")  # 25, not piety sensitive
	var liesel := Phase7Fixtures.villager_data(&"washer")  # 10, piety sensitive
	var rep_tiers: Array[StringName] = ReputationRules.TIERS
	var expect_rosine := [15, 20, 25, 30, 35]
	for i: int in rep_tiers.size():
		assert_eq(RelationshipRules.start_value(rosine, rep_tiers[i], &"devout", cfg), expect_rosine[i], String(rep_tiers[i]))
	var piety_tiers: Array[StringName] = PietyRules.TIERS
	var expect_liesel := [5, 10, 10, 13, 15]
	for i: int in piety_tiers.size():
		assert_eq(RelationshipRules.start_value(liesel, &"respected", piety_tiers[i], cfg), expect_liesel[i], String(piety_tiers[i]))
	assert_eq(RelationshipRules.start_value(liesel, &"disreputable", &"hardhearted", cfg), 0, "clamped at 0")
	assert_eq(RelationshipRules.start_value(null, &"respected", &"devout", cfg), 0)


# --- meeting, add, clamp ----------------------------------------------------------------------

func test_meet_once_with_start_value() -> void:
	assert_false(rel.met(&"mayor"))
	assert_eq([rel.value(&"mayor"), rel.tier(&"mayor")], [0, &"stranger"])
	rel.meet(&"mayor")
	assert_true(rel.met(&"mayor"))
	assert_eq([rel.value(&"mayor"), rel.tier(&"mayor")], [30, &"acquainted"], "Fenner starts at 30 (Geachtet +0)")
	assert_eq(changes, [[&"mayor", 30, &"acquainted", 30, Relationships.REASON_MEET]])
	rel.meet(&"mayor")
	assert_eq(changes.size(), 1, "only once")
	GameState.stats[&"reputation"] = 90  # Gerühmt
	GameState.stats[&"piety"] = 80  # Andächtig
	rel.meet(&"washer")
	assert_eq(rel.value(&"washer"), 25, "Liesel 10 + 10 (Gerühmt) + 5 (Andächtig)")
	rel.meet(&"carter")
	assert_false(rel.met(&"carter"), "Osric has no relationship in Phase 7")


func test_add_clamps_and_meets_first() -> void:
	assert_eq(rel.add(&"smith", 6, "Auftrag"), 21, "Esch 15 + 6 – met on the way")
	assert_true(rel.met(&"smith"))
	assert_eq(rel.add(&"smith", 200, "x"), 100)
	assert_eq(rel.add(&"smith", -300, "y"), 0)
	assert_eq(changes.back(), [&"smith", 0, &"stranger", -100, "y"])
	var n := changes.size()
	assert_eq(rel.add(&"smith", -5, "z"), 0)
	assert_eq(changes.size(), n, "no change, no signal")
	assert_eq(rel.add(&"council", 5, "Tafel"), 0, "the council has no relationship")
	assert_false(rel.met(&"council"))


func test_talk_plus_one_once_per_day() -> void:
	rel.note_talk(&"grocer")
	assert_eq(rel.value(&"grocer"), 21, "Theres 20 + talk 1")
	rel.note_talk(&"grocer")
	assert_eq(rel.value(&"grocer"), 21, "once per day")
	assert_true(rel.talked_today(&"grocer"))
	TimeManager.day = 6
	assert_false(rel.talked_today(&"grocer"))
	rel.note_talk(&"grocer")
	assert_eq(rel.value(&"grocer"), 22)
	TimeManager.day = 30
	assert_eq(rel.value(&"grocer"), 22, "no decay")


func test_gift_only_liked_and_once_per_day() -> void:
	inv.add_item(&"honey_cake", 2)
	inv.add_item(&"linen", 1)
	assert_eq(rel.gift_block_reason(&"priest", &"linen", inv), Relationships.TEXT_GIFT_DISLIKED)
	assert_false(rel.give_gift(&"priest", &"linen", inv))
	assert_eq(rel.gift_block_reason(&"priest", &"elder_wine", inv), Relationships.TEXT_GIFT_MISSING)
	assert_eq(rel.gift_block_reason(&"carter", &"honey_cake", inv), Relationships.TEXT_GIFT_UNKNOWN)
	assert_eq(rel.gift_block_reason(&"priest", &"honey_cake", inv), "")
	assert_true(rel.give_gift(&"priest", &"honey_cake", inv))
	assert_eq(rel.value(&"priest"), 29, "Lenz 25 + gift 4")
	assert_eq(inv.count(&"honey_cake"), 1)
	assert_eq(GameState.get_stat(&"gifts_given"), 1)
	assert_eq(rel.gift_block_reason(&"priest", &"honey_cake", inv), Relationships.TEXT_GIFT_TODAY)
	assert_false(rel.give_gift(&"priest", &"honey_cake", inv))
	assert_true(rel.give_gift(&"mayor", &"honey_cake", inv), "another villager the same day")
	TimeManager.day = 6
	inv.add_item(&"honey_cake", 1)
	assert_true(rel.give_gift(&"priest", &"honey_cake", inv), "next day")
	assert_eq([rel.value(&"priest"), GameState.get_stat(&"gifts_given")], [33, 3])


func test_round_and_donation_gains() -> void:
	assert_eq([rel.gain(&"round"), rel.gain(&"donation"), rel.gain(&"talk"), rel.gain(&"gift"), rel.gain(&"order_failed")],
			[2, 1, 1, 4, -4])
	assert_eq(rel.gain(&"nope"), 0)
	# Village.buy_round (P3) calls add(round) for everyone in the inn.
	for id: StringName in [&"smith", &"priest", &"mayor"]:
		rel.add(id, rel.gain(&"round"), "Runde")
	assert_eq([rel.value(&"smith"), rel.value(&"priest"), rel.value(&"mayor")], [17, 27, 32])
	rel.add(&"mayor", rel.gain(&"donation"), "Armenkasse")
	assert_eq(rel.value(&"mayor"), 33)


func test_specimen_sold_and_returned_deltas() -> void:
	for id: StringName in Phase7Fixtures.VILLAGER_IDS:
		rel.meet(id)
	rel.on_specimen_sold()
	assert_eq([rel.value(&"priest"), rel.value(&"washer"), rel.value(&"oldwoman"), rel.value(&"surgeon"), rel.value(&"smith")],
			[21, 7, 28, 22, 15], "Pfarrer −4, Liesel −3, Hagedorn −2, Quast +2, others 0")
	rel.on_specimen_sold(&"eyes")
	assert_eq([rel.value(&"priest"), rel.value(&"washer"), rel.value(&"oldwoman"), rel.value(&"surgeon")], [15, 2, 26, 24],
			"eyes: Pfarrer −6, Liesel −5")
	rel.on_specimen_sold(&"heart")
	assert_eq([rel.value(&"priest"), rel.value(&"washer")], [11, 0], "heart = the base deltas; clamped at 0")
	rel.on_specimen_returned()
	assert_eq([rel.value(&"priest"), rel.value(&"washer"), rel.value(&"surgeon")], [12, 2, 26], "Pfarrer +1, Liesel +2, Quast unchanged (3 sales +2)")
	assert_eq(changes.back()[4], Relationships.REASON_SPECIMEN_RETURNED)


func test_count_at_least() -> void:
	var r := Phase7Fixtures.villager(&"washer", 42, null, {&"priest": 70, &"mayor": 39, &"smith": 40})
	assert_eq(r.count_at_least(&"trusted"), 3)
	assert_eq(r.count_at_least(&"friend"), 1)
	assert_eq(r.count_at_least(&"acquainted"), 4)
	assert_eq(r.count_at_least(&"stranger"), 4)
	r.free()


# --- remarks ----------------------------------------------------------------------------------

func _talker() -> VillagerData:
	var v := VillagerData.new()
	v.npc_id = &"talker"
	v.start_value = 20
	v.remarks = {
		&"friend": PackedStringArray(["F"]), &"piety_devout": PackedStringArray(["D"]), &"piety_hardhearted": PackedStringArray(["H"]),
		&"specimens": PackedStringArray(["S"]), &"rep_disreputable": PackedStringArray(["V"]),
		&"rep_respected": PackedStringArray(["G1", "G2"]),
	}
	rel.villagers[&"talker"] = v
	return v


func test_remark_precedence_and_once_per_day() -> void:
	_talker()
	assert_eq(rel.remark(&"talker"), "G2", "Geachtet, day 5 → pool[5 % 2]")
	assert_eq(remarks, [[&"talker", "G2"]])
	assert_eq(rel.remark(&"talker"), "", "once per day")
	assert_eq(remarks.size(), 1)
	assert_eq(rel.remark_text(&"talker", 6), "G1")
	GameState.stats[&"reputation"] = 5
	assert_eq(rel.remark_text(&"talker", 6), "V", "Verrufen")
	GameState.stats[&"reputation"] = 60
	assert_eq(rel.remark_text(&"talker", 6), "G1", "Geschätzt without a line → Geachtet")
	GameState.stats[&"specimens_sold"] = Relationships.REMARK_SPECIMENS_AFTER
	assert_eq(rel.remark_text(&"talker", 6), "S", "many specimens before the reputation")
	GameState.stats[&"piety"] = -80
	assert_eq(rel.remark_text(&"talker", 6), "H", "Hartherzig before specimens")
	GameState.stats[&"piety"] = 80
	assert_eq(rel.remark_text(&"talker", 6), "D", "Andächtig")
	GameState.stats[&"piety"] = 30
	assert_eq(rel.remark_text(&"talker", 6), "S", "Rücksichtsvoll has no own line")
	rel.add(&"talker", 60, "x")
	assert_eq(rel.tier(&"talker"), &"friend")
	assert_eq(rel.remark_text(&"talker", 6), "F", "Befreundet first")
	TimeManager.day = 6
	assert_eq(rel.remark(&"talker"), "F", "next day again")
	assert_eq(rel.remark(&"nobody"), "")


func test_real_villager_data_has_six_to_eight_remarks() -> void:
	for id: StringName in Phase7Fixtures.VILLAGER_IDS:
		var v := Database.villager(id) as VillagerData
		assert_not_null(v, String(id))
		if v == null:
			continue
		var n := 0
		for key: StringName in v.remarks:
			n += v.remarks[key].size()
			assert_true(key in [&"friend", &"specimens"] or String(key).begins_with("rep_") or String(key).begins_with("piety_"),
					"%s key %s" % [id, key])
		# §2.4 "6–8 Zeilen"; villagers with the two piety_* lines carry them on top of
		# 5 × rep_ + friend + specimens, so they may have 9.
		var most := 9 if v.remarks.has(&"piety_devout") else 8
		assert_true(n >= 6 and n <= most, "%s: 6–%d remarks (%d)" % [id, most, n])
		for t: StringName in ReputationRules.TIERS:
			assert_true(v.remarks.has(StringName("rep_" + String(t))), "%s rep_%s" % [id, t])
		var f := Phase7Fixtures.villager_data(id)
		assert_eq([v.display_name, v.shop_id, v.gifts_liked, v.start_value, v.specimen_delta, v.returned_delta, v.piety_sensitive],
				[f.display_name, f.shop_id, f.gifts_liked, f.start_value, f.specimen_delta, f.returned_delta, f.piety_sensitive],
				"%s = fixture §2.1" % id)
	assert_eq(Database.villagers().size(), 8)


# --- save / load ------------------------------------------------------------------------------

func test_save_load_roundtrip_and_tolerance() -> void:
	rel.note_talk(&"innkeeper")
	inv.add_item(&"honey_cake", 1)
	rel.give_gift(&"innkeeper", &"honey_cake", inv)
	_talker()
	rel.remark(&"talker")
	var state := rel.save_state()
	assert_eq(state.keys(), ["values", "met", "talk_day", "gift_day", "remark_day"], "§5.1")
	assert_eq(state.values, {"innkeeper": 30})
	assert_eq(state.met, ["innkeeper"])
	assert_eq([state.talk_day, state.gift_day, state.remark_day], [{"innkeeper": 5}, {"innkeeper": 5}, {"talker": 5}])
	var other := Relationships.new()
	other.villagers = rel.villagers
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state, "JSON round trip identical")
	other.note_talk(&"innkeeper")
	assert_eq(other.value(&"innkeeper"), 30, "talk_day survives the load")
	assert_eq(other.remark(&"talker"), "", "remark_day survives the load")
	other.load_state({"values": {"smith": 250, "priest": -3, "washer": "x"}, "met": ["smith", "priest", "smith"], "talk_day": "bad"})
	assert_eq([other.value(&"smith"), other.value(&"priest"), other.value(&"washer")], [100, 0, 0], "clamped, damaged dropped")
	assert_eq(other.met_ids(), [&"smith", &"priest"] as Array[StringName])
	other.load_state({})
	assert_eq(other.save_state(), {"values": {}, "met": [], "talk_day": {}, "gift_day": {}, "remark_day": {}})
	other.free()
