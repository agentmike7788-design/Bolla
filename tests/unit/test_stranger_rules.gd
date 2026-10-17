extends TestCase
## P5 (docs/PHASE9_DESIGN.md §2.5, §3.4, §10): StrangerRules – the visit days (p9_open_day + 2, every 5 days for
## 3 days), presence by region and window (outside the gate 14:10–15:30, the village, the Holderkrug – never inside
## the cemetery), the offers' conditions (soil only from a fresh grave, the register extract, specimens × 1.5, the
## ledger only after the main chain), the questions.

var cfg: StrangerConfig


func before_each() -> void:
	cfg = Phase9Fixtures.stranger_config()


func test_visit_days() -> void:
	assert_eq(StrangerRules.visit_days(63, cfg), PackedInt32Array([65, 66, 67, 70, 71, 72, 75, 76, 77, 80, 81, 82]))
	assert_eq([StrangerRules.visit_start(63, 1, cfg), StrangerRules.visit_start(63, 2, cfg)],
			[Phase9Fixtures.stranger_day(1), Phase9Fixtures.stranger_day(2)], "B3, B8")
	assert_eq([StrangerRules.visit_of(64, 63, cfg), StrangerRules.visit_of(65, 63, cfg), StrangerRules.visit_of(67, 63, cfg),
			StrangerRules.visit_of(68, 63, cfg), StrangerRules.visit_of(72, 63, cfg)], [0, 1, 1, 0, 2])
	assert_eq(StrangerRules.last_day(63, cfg), 82)
	assert_eq(StrangerRules.visit_days(-1, cfg), PackedInt32Array(), "before p9_open")
	assert_eq(StrangerRules.visit_days(48, cfg)[0], 50, "relative to every opening day (founder)")


func test_present_by_region_and_window() -> void:
	var state := {"open_day": 63}
	var gate := func(day: int, minute: int) -> bool: return StrangerRules.present(day, minute, &"graveyard", state, cfg)
	assert_false(gate.call(65, 849))
	assert_true(gate.call(65, 850), "14:10 outside the gate")
	assert_true(gate.call(65, 929))
	assert_false(gate.call(65, 930), "15:30 gone")
	assert_false(gate.call(68, 860), "not between the visits")
	assert_true(gate.call(71, 900))
	assert_eq(StrangerRules.spot(&"graveyard"), &"stranger_gate", "the only cemetery spot: outside the gate")
	assert_true(StrangerRules.present(65, 570, &"village", state, cfg), "09:30 over the Holderbrücke")
	assert_false(StrangerRules.present(65, 820, &"village", state, cfg), "walking up to the gate")
	assert_true(StrangerRules.present(65, 1000, &"village", state, cfg))
	assert_true(StrangerRules.present(65, 1100, &"inn", state, cfg), "18:00–21:00 at his table")
	assert_false(StrangerRules.present(65, 1260, &"inn", state, cfg))
	assert_false(StrangerRules.present(65, 900, &"moon", state, cfg))
	for minute: int in range(0, 1440, 10):
		var at_gate := StrangerRules.present(66, minute, &"graveyard", state, cfg)
		assert_eq(at_gate, minute >= 850 and minute < 930, "graveyard only in the gate window (%d)" % minute)
	assert_false(StrangerRules.present(65, 900, &"graveyard", {"open_day": -1}, cfg))
	assert_false(StrangerRules.present(65, 900, &"graveyard", {"open_day": 63, "left": true}, cfg))
	var ended := {"open_day": 63, "ending": "fenner", "ending_day": 70}
	assert_true(StrangerRules.present(70, 900, &"graveyard", ended, cfg), "the day of the ending he still walks")
	assert_false(StrangerRules.present(71, 900, &"graveyard", ended, cfg), "after it never again")
	assert_false(StrangerRules.present(75, 600, &"village", ended, cfg))


func test_offer_conditions() -> void:
	var inv := Inventory.new()
	var soil := Phase9Fixtures.stranger_offer(&"so_soil")
	var register := Phase9Fixtures.stranger_offer(&"so_register")
	var specimen := Phase9Fixtures.stranger_offer(&"so_specimen")
	var kladde := Phase9Fixtures.stranger_offer(&"so_kladde")
	assert_eq(StrangerRules.offer_block_reason(soil, inv, {}), StrangerRules.TEXT_NO_FRESH)
	assert_eq(StrangerRules.offer_block_reason(soil, inv, {"soil_ready": true}), StrangerRules.TEXT_SOIL)
	inv.add_item(&"soil_pouch", 1)
	assert_eq(StrangerRules.offer_block_reason(soil, inv, {}), "")
	assert_eq(StrangerRules.fresh_days(soil), 5)
	assert_eq(StrangerRules.offer_block_reason(register, inv, {}), StrangerRules.TEXT_NOT_WITH_YOU)
	inv.add_item(&"register_extract", 1)
	assert_eq(StrangerRules.offer_block_reason(register, inv, {}), "")
	assert_false(StrangerRules.offer_visible(specimen, {}), "specimens only with anatomy_known")
	GameState.set_flag(&"anatomy_known", true)
	assert_true(StrangerRules.offer_visible(specimen, {}))
	assert_eq(StrangerRules.offer_block_reason(specimen, inv, {}), StrangerRules.TEXT_NO_SPECIMEN)
	assert_eq(StrangerRules.offer_block_reason(specimen, inv, {"specimen_uid": "sp_0001"}), "")
	assert_false(StrangerRules.offer_visible(kladde, {"quest_ended": []}), "the ledger only after the main chain")
	assert_eq(StrangerRules.offer_block_reason(kladde, inv, {"quest_ended": []}), StrangerRules.TEXT_NOT_YET)
	var ended := {"quest_ended": [&"q_who_knows"] as Array[StringName]}
	assert_true(StrangerRules.offer_visible(kladde, ended))
	assert_eq(StrangerRules.offer_block_reason(kladde, inv, ended), StrangerRules.TEXT_NOT_WITH_YOU)
	inv.add_item(&"lorenz_ledger_2", 1)
	assert_eq(StrangerRules.offer_block_reason(kladde, inv, ended), "")
	assert_eq(StrangerRules.offer_block_reason(soil, null, {}), StrangerRules.TEXT_NO_INVENTORY)
	assert_eq(StrangerRules.offer_block_reason(null, inv, {}), StrangerRules.TEXT_UNKNOWN)
	for o: StrangerOfferData in Phase9Fixtures.stranger_offers():
		assert_false(o.note.contains("+") or o.note.contains("−") or o.note.contains("Pietät"), "§7.4: no number – %s" % o.id)
		assert_false(o.item in [&"corpse", &"body"], "§14.4: never a corpse")
	inv.free()


func test_specimen_price_and_questions() -> void:
	assert_eq([StrangerRules.specimen_price(6, cfg), StrangerRules.specimen_price(5, cfg), StrangerRules.specimen_price(0, cfg)], [9, 8, 0],
			"Quast's price × 1.5")
	assert_eq(StrangerRules.question(1, cfg), "Wie tief graben Sie im Frost?")
	assert_eq(StrangerRules.question(2, cfg), cfg.questions[1], "a new one each visit")
	assert_eq(StrangerRules.question(7, cfg), cfg.questions[0])
	assert_eq(StrangerRules.question(0, cfg), "")
	assert_eq(StrangerRules.question(1, StrangerConfig.new()), "", "no questions in the class default")
