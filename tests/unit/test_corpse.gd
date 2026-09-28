extends TestCase
## M3: CorpseRecord helpers + dict round-trip, CorpseGenerator determinism and tables (§2.5).

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const REAL_TABLES := "res://data/corpses/corpse_tables.tres"
const RANDOM_DAY := 5

var tables: CorpseTables


func before_each() -> void:
	tables = load(FIXTURE_TABLES) as CorpseTables


# --- seed_for ---

func test_seed_for_formula() -> void:
	assert_eq(CorpseGenerator.seed_for(1, 0), 1 * 7919 + 17)
	assert_eq(CorpseGenerator.seed_for(2, 0), 2 * 7919 + 17)
	assert_eq(CorpseGenerator.seed_for(3, 2), 3 * 7919 + 17 + 104729 * 2)
	assert_eq(CorpseGenerator.seed_for(0, 0), 17)


func test_seed_for_is_unique_for_day_and_index() -> void:
	var seen := {}
	for day: int in range(1, 15):
		for index: int in 4:
			var s := CorpseGenerator.seed_for(day, index)
			assert_false(seen.has(s), "seed collision day %d index %d" % [day, index])
			seen[s] = true


# --- generator ---

func test_generate_is_deterministic_for_20_seeds() -> void:
	for i: int in 20:
		var s := CorpseGenerator.seed_for(RANDOM_DAY, i)
		var a := CorpseGenerator.generate(s, tables, RANDOM_DAY)
		var b := CorpseGenerator.generate(s, tables, RANDOM_DAY)
		assert_eq(a.to_dict(), b.to_dict(), "seed %d" % s)
		assert_eq(a.seed, s)


func test_generate_varies_between_seeds() -> void:
	var names := {}
	var causes := {}
	var ages := {}
	for i: int in 20:
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(RANDOM_DAY, i), tables, RANDOM_DAY)
		names[r.display_name] = true
		causes[r.cause_id] = true
		ages[r.age] = true
	assert_true(names.size() > 3, "names vary: %s" % str(names.keys()))
	assert_eq(causes.size(), 2, "both fixture causes appear")
	assert_true(ages.size() > 5, "ages vary")


func test_generate_uses_tables() -> void:
	for i: int in 20:
		var r := CorpseGenerator.generate(1000 + i, tables, RANDOM_DAY)
		var parts := r.display_name.split(" ")
		assert_eq(parts.size(), 2, r.display_name)
		assert_has(tables.first_names, parts[0])
		assert_has(tables.last_names, parts[1])
		assert_true(r.age >= tables.age_min and r.age <= tables.age_max, "age %d" % r.age)
		assert_false(tables.get_cause(r.cause_id).is_empty(), "cause %s" % r.cause_id)
		assert_almost(r.freshness, 1.0)
		assert_eq(r.id, "", "the manager assigns ids")
		assert_eq(r.location, &"dropoff")
		assert_false(r.examined)
		assert_false(r.shrouded)
		for t: StringName in r.traits:
			assert_false(tables.get_trait(t).is_empty(), "trait %s from table" % t)


func test_valuables_coins_only_with_valuables() -> void:
	var with_valuables := 0
	var without := 0
	for i: int in 40:
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(RANDOM_DAY, i), tables, RANDOM_DAY)
		if r.has_trait(&"valuables"):
			with_valuables += 1
			assert_true(r.valuables_coins >= tables.valuables_coins_min and r.valuables_coins <= tables.valuables_coins_max,
					"coins %d in range" % r.valuables_coins)
		else:
			without += 1
			assert_eq(r.valuables_coins, 0)
	assert_true(with_valuables > 0 and without > 0, "chance 0.5 gives both")


func test_forced_traits_day_1_none() -> void:
	for i: int in 20:
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(1, i), tables, 1)
		assert_eq(r.traits, [], "day 1 is the tutorial")
		assert_eq(r.valuables_coins, 0)


func test_forced_traits_day_2_exactly_valuables() -> void:
	for i: int in 20:
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(2, i), tables, 2)
		assert_eq(r.traits, [&"valuables"])
		assert_true(r.valuables_coins >= 5 and r.valuables_coins <= 8)


func test_forced_traits_are_used_even_if_the_seed_would_roll_others() -> void:
	var custom := tables.duplicate() as CorpseTables
	custom.traits = [{"id": &"valuables", "chance": 1.0}, {"id": &"letter", "chance": 1.0}]
	custom.forced_traits_by_day = {4: PackedStringArray(["letter"])}
	assert_eq(CorpseGenerator.generate(99, custom, 4).traits, [&"letter"])
	assert_eq(CorpseGenerator.generate(99, custom, 5).traits, [&"valuables", &"letter"], "day without entry is random")


func test_random_traits_follow_chance() -> void:
	var custom := tables.duplicate() as CorpseTables
	custom.traits = [{"id": &"valuables", "chance": 0.0}, {"id": &"letter", "chance": 1.0}]
	for i: int in 20:
		assert_eq(CorpseGenerator.generate(i, custom, RANDOM_DAY).traits, [&"letter"])


func test_weighted_cause_never_picks_zero_weight() -> void:
	var custom := tables.duplicate() as CorpseTables
	custom.causes = [{"id": &"a", "weight": 0.0}, {"id": &"b", "weight": 1.0}, {"id": &"c", "weight": -2.0}]
	for i: int in 30:
		assert_eq(CorpseGenerator.generate(i, custom, RANDOM_DAY).cause_id, &"b")


func test_weighted_cause_distribution() -> void:
	var custom := tables.duplicate() as CorpseTables
	custom.causes = [{"id": &"rare", "weight": 1.0}, {"id": &"common", "weight": 9.0}]
	var common := 0
	for i: int in 200:
		if CorpseGenerator.generate(i * 31, custom, RANDOM_DAY).cause_id == &"common":
			common += 1
	assert_true(common > 150 and common < 200, "about 90%% common, got %d/200" % common)


func test_generate_does_not_touch_global_rng() -> void:
	seed(4242)
	var expected := randi()
	seed(4242)
	CorpseGenerator.generate(7, tables, RANDOM_DAY)
	assert_eq(randi(), expected)
	seed(1)
	var a := CorpseGenerator.generate(7, tables, RANDOM_DAY).to_dict()
	seed(2)
	assert_eq(CorpseGenerator.generate(7, tables, RANDOM_DAY).to_dict(), a, "global seed has no influence")


func test_generate_without_tables_returns_null() -> void:
	assert_null(CorpseGenerator.generate(1, null, 1))


func test_generate_with_empty_tables() -> void:
	var empty := CorpseTables.new()
	var r := CorpseGenerator.generate(3, empty, RANDOM_DAY)
	assert_not_null(r)
	assert_eq(r.cause_id, &"")
	assert_eq(r.traits, [])
	assert_true(r.display_name != "")


func test_real_tables_content() -> void:
	var real := load(REAL_TABLES) as CorpseTables
	assert_not_null(real)
	assert_true(real.first_names.size() >= 18)
	assert_true(real.last_names.size() >= 18)
	assert_eq(real.causes.size(), 7, "Phase 4: + moor_cold (S5 only, weight 0)")
	for c: Dictionary in real.causes:
		assert_true(c.id is StringName, "cause id is a StringName")
		assert_true(String(c.label) != "" and String(c.description) != "")
		if c.id == &"moor_cold":
			# Phase 4 §2.5: only the story corpse S5, never rolled; decays at half speed.
			assert_eq([float(c.weight), float(c.decay_mult)], [0.0, 0.5])
			continue
		assert_true(float(c.weight) > 0.0)
		assert_true(float(c.decay_mult) >= 0.75 and float(c.decay_mult) <= 1.5, "decay_mult of %s" % c.id)
		assert_true(int(c.base_payment) >= 2 and int(c.base_payment) <= 4, "base_payment of %s" % c.id)
	var trait_ids: Array = []
	for t: Dictionary in real.traits:
		trait_ids.append(t.id)
		assert_true(String(t.reveal_text) != "" and String(t.label) != "")
	assert_eq(trait_ids, [&"valuables", &"letter", &"tattoo", &"strange_wound"])
	assert_almost(float(real.get_trait(&"valuables").chance), 0.35)
	assert_eq(real.forced_traits_by_day.get(1), PackedStringArray())
	assert_eq(real.forced_traits_by_day.get(2), PackedStringArray(["valuables"]))
	assert_eq(real.forced_traits_by_day.get(3), PackedStringArray(["strange_wound"]))
	assert_eq(real.forced_traits_by_day.get(4), PackedStringArray(["valuables", "letter"]))
	assert_eq(real.forced_traits_by_day.get(5), PackedStringArray(["valuables", "tattoo"]))
	assert_false(real.forced_traits_by_day.has(6), "day 6+ is random (v3)")
	assert_almost(real.base_decay_per_hour, 0.05)
	assert_eq(real.delivery_minute, 460)
	assert_eq([real.valuables_coins_min, real.valuables_coins_max], [5, 8])


## GP-01 (§2.5 v3): the six slice deliveries of the real tables offer the valuables choice
## three times (days 2, 4, 5) and show every narrative trait, the strange wound on day 3.
func test_real_tables_slice_corpses_days_1_to_6() -> void:
	var real := load(REAL_TABLES) as CorpseTables
	var by_day: Dictionary = {}
	var seen: Dictionary = {}
	for day: int in range(1, 7):
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), real, day)
		by_day[day] = r.traits
		for t: StringName in r.traits:
			seen[t] = int(seen.get(t, 0)) + 1
		if r.has_trait(&"valuables"):
			assert_true(r.valuables_coins >= real.valuables_coins_min and r.valuables_coins <= real.valuables_coins_max,
					"day %d coins %d" % [day, r.valuables_coins])
	assert_eq(by_day[1], [], "day 1 tutorial")
	assert_eq(by_day[2], [&"valuables"])
	assert_eq(by_day[3], [&"strange_wound"], "mystery hint")
	assert_eq(by_day[4], [&"valuables", &"letter"])
	assert_eq(by_day[5], [&"valuables", &"tattoo"])
	assert_eq(int(seen.get(&"valuables", 0)), 3, "three thefts possible -> reputation -3 reachable: %s" % str(by_day))
	for t: StringName in [&"letter", &"tattoo", &"strange_wound"]:
		assert_true(int(seen.get(t, 0)) >= 1, "%s appears in days 1-6" % t)


func test_database_serves_real_tables() -> void:
	assert_true(Database.corpse_tables() is CorpseTables)


# --- record helpers ---

func test_has_trait_and_revealed_traits() -> void:
	var r := CorpseRecord.new()
	r.traits = [&"letter", &"valuables"]
	assert_true(r.has_trait(&"letter"))
	assert_false(r.has_trait(&"tattoo"))
	assert_eq(r.revealed_traits(), [], "hidden until examined")
	r.examined = true
	assert_eq(r.revealed_traits(), [&"letter", &"valuables"])
	r.revealed_traits().clear()
	assert_eq(r.traits.size(), 2, "revealed_traits returns a copy")


func test_freshness_stage_thresholds() -> void:
	var r := CorpseRecord.new()
	var cases := [[1.0, &"fresh"], [0.6, &"fresh"], [0.59, &"wilted"], [0.3, &"wilted"], [0.29, &"decaying"], [0.1, &"decaying"], [0.099, &"rotten"], [0.0, &"rotten"]]
	for c: Array in cases:
		r.freshness = c[0]
		assert_eq(r.freshness_stage(), c[1], "freshness %s" % str(c[0]))


## ARCH-06: one threshold rule for a given config; freshness_stage() uses the game config.
func test_stage_for_uses_the_given_config() -> void:
	var custom := EconomyConfig.new()
	custom.fresh_good_threshold = 0.9
	custom.fresh_bad_threshold = 0.5
	var cases := [[0.9, &"fresh"], [0.89, &"wilted"], [0.5, &"wilted"], [0.49, &"decaying"]]
	for c: Array in cases:
		assert_eq(CorpseRecord.stage_for(c[0], custom), c[1], "freshness %s" % str(c[0]))
	var r := CorpseRecord.new()
	r.freshness = 0.7
	assert_eq(r.freshness_stage(), CorpseRecord.stage_for(0.7, EconomyConfig.resolve()))
	assert_eq(EconomyConfig.resolve(custom), custom, "an injected config wins")
	assert_eq(EconomyConfig.resolve(), Database.config(&"economy_config"), "else the data file")


func test_needs_valuables_decision() -> void:
	var r := CorpseRecord.new()
	r.traits = [&"valuables"]
	assert_false(r.needs_valuables_decision(), "not examined")
	r.examined = true
	assert_true(r.needs_valuables_decision())
	r.valuables_decision = &"left"
	assert_false(r.needs_valuables_decision(), "decided")
	var plain := CorpseRecord.new()
	plain.examined = true
	assert_false(plain.needs_valuables_decision(), "no valuables")


# --- dict round-trip ---

func test_dict_round_trip_all_fields() -> void:
	var r := _full_record()
	var d := r.to_dict()
	assert_eq(d.keys().size(), 35, "every field is saved (buried_day: §11 register; Phase 4: + 11; Phase 6: + 5)")
	var back := CorpseRecord.from_dict(d)
	assert_eq(back.to_dict(), d)
	assert_true(back.cause_id is StringName)
	assert_true(back.position is Vector3)
	assert_eq(typeof(back.traits[0]), TYPE_STRING_NAME)


func test_to_dict_is_a_copy() -> void:
	var r := _full_record()
	var d := r.to_dict()
	(d.traits as Array).append(&"tattoo")
	assert_eq(r.traits.size(), 2)


func test_from_dict_after_json_native_round_trip() -> void:
	var r := _full_record()
	var text := JSON.stringify(JSON.from_native(r.to_dict()))
	var back := CorpseRecord.from_dict(JSON.to_native(JSON.parse_string(text)))
	assert_eq(back.to_dict(), r.to_dict())
	assert_eq(typeof(back.to_dict().seed), TYPE_INT)


func test_from_dict_accepts_plain_json_values() -> void:
	var r := _full_record()
	var plain: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_true(plain.seed is float and plain.cause_id is String and plain.position is String, "plain JSON types")
	var back := CorpseRecord.from_dict(plain)
	assert_eq(back.seed, r.seed)
	assert_eq(typeof(back.seed), TYPE_INT)
	assert_eq(back.age, 57)
	assert_eq(back.cause_id, &"drowned")
	assert_true(back.cause_id is StringName)
	assert_eq(back.traits, [&"valuables", &"letter"])
	assert_eq(back.valuables_decision, &"taken")
	assert_eq(back.location, &"table")
	assert_eq(back.position, Vector3(1.5, 0.25, -3.0))
	assert_eq(back.last_decay_total, 2000)
	assert_almost(back.freshness, 0.42)


func test_from_dict_vector_formats() -> void:
	var formats: Array = [[1, 2, 3], {"x": 1, "y": 2, "z": 3}, "(1, 2, 3)", PackedFloat32Array([1, 2, 3]), Vector3i(1, 2, 3)]
	for f: Variant in formats:
		assert_eq(CorpseRecord.from_dict({"position": f}).position, Vector3(1, 2, 3), str(f))
	assert_eq(CorpseRecord.from_dict({"position": [1, 2]}).position, Vector3.ZERO, "wrong size -> default")
	assert_eq(CorpseRecord.from_dict({"position": "(a, b, c)"}).position, Vector3.ZERO)


func test_from_dict_traits_formats() -> void:
	assert_eq(CorpseRecord.from_dict({"traits": PackedStringArray(["letter"])}).traits, [&"letter"])
	assert_eq(CorpseRecord.from_dict({"traits": ["letter", 3, null, &"tattoo"]}).traits, [&"letter", &"tattoo"])
	assert_eq(CorpseRecord.from_dict({"traits": "letter"}).traits, [])


func test_from_dict_defaults_for_missing_or_bad_values() -> void:
	var r := CorpseRecord.from_dict({"seed": "abc", "age": [], "location": &"moon", "valuables_decision": &"sold", "examined": "true", "freshness": null})
	var defaults := CorpseRecord.new()
	assert_eq(r.seed, 0)
	assert_eq(r.age, 0)
	assert_eq(r.location, &"dropoff", "unknown location -> default")
	assert_eq(r.valuables_decision, &"", "unknown decision -> undecided")
	assert_true(r.examined, "string 'true' is accepted")
	assert_almost(r.freshness, 1.0)
	assert_eq(CorpseRecord.from_dict({}).to_dict(), defaults.to_dict())


func _full_record() -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = "corpse_0007"
	r.seed = CorpseGenerator.seed_for(9, 3)
	r.display_name = "Clara Esche"
	r.age = 57
	r.cause_id = &"drowned"
	r.traits = [&"valuables", &"letter"]
	r.examined = true
	r.shrouded = true
	r.valuables_coins = 7
	r.valuables_decision = &"taken"
	r.freshness = 0.42
	r.freshness_at_burial = -1.0
	r.last_decay_total = 2000
	r.location = &"table"
	r.position = Vector3(1.5, 0.25, -3.0)
	r.rot_y = 1.25
	r.grave_id = ""
	r.arrival_total_minutes = 1900
	r.buried_day = 3
	return r


# --- Phase 4 (P1, docs/PHASE4_DESIGN.md §2.1, §2.5, §3.4, §10) ---------------------------------

## Graveyard duck type for the delivery rules: free / locked plots, plots of the elder section.
class PlotsDouble extends Node:
	var free_plots: int = 0
	var locked: int = 0
	var elder := PackedStringArray()

	func free_plot_count() -> int:
		return free_plots

	func locked_plot_count() -> int:
		return locked

	func plots_in_section(section: StringName) -> PackedStringArray:
		return elder if section == &"elder" else PackedStringArray()


func test_phase4_fields_round_trip() -> void:
	var r := Phase4Fixtures.corpse([&"tattoo", &"valuables"], &"drowned_millpond")
	r.story_id = &"s2_hemmerling"
	r.exam_done = [&"hands", &"pockets"]
	r.finds_revealed = [&"f_tattoo", &"f_s2_key"]
	r.finds_lost = [&"f_s2_wrists"]
	r.traits_revealed = [&"tattoo"]
	r.washed = true
	r.dress = CorpseRecord.DRESS_GOWN
	r.shrouded = true
	r.laid_out = true
	r.harvested = [&"hair"]
	r.balm_windows = PackedInt32Array([500, 1580, 2000, 3080])
	r.stench_noted = true
	var native := JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict())))) as Dictionary
	var plain := JSON.parse_string(JSON.stringify(r.to_dict())) as Dictionary
	for d: Dictionary in [r.to_dict(), native, plain]:
		var back := CorpseRecord.from_dict(d)
		assert_eq(back.to_dict(), r.to_dict())
		assert_eq(back.story_id, &"s2_hemmerling")
		assert_true(back.exam_done[0] is StringName, "names, not Strings")
		assert_eq(back.balm_windows, PackedInt32Array([500, 1580, 2000, 3080]))


func test_from_dict_tolerates_missing_and_bad_phase4_fields() -> void:
	var old := CorpseRecord.from_dict({"id": "corpse_0001", "traits": ["letter"], "examined": true, "shrouded": true})
	assert_eq([old.story_id, old.washed, old.laid_out, old.stench_noted], [&"", false, false, false])
	assert_eq([old.exam_done.size(), old.finds_revealed.size(), old.harvested.size(), old.balm_windows.size()], [0, 0, 0, 0])
	assert_eq(old.dress, CorpseRecord.DRESS_SHROUD, "a shrouded record without dress field wears the shroud")
	var bad := CorpseRecord.from_dict({"exam_done": ["hands", "nose", "hands", 7], "dress": "cape", "harvested": ["teeth", "ears"],
			"balm_windows": [100, 50, "x", 3, 200, 300, 400], "finds_revealed": "f_mark", "washed": "true"})
	assert_eq(bad.exam_done, [&"hands"] as Array[StringName], "unknown and duplicate steps dropped")
	assert_eq(bad.dress, CorpseRecord.DRESS_NONE)
	assert_false(bad.shrouded)
	assert_eq(bad.harvested, [&"teeth"] as Array[StringName])
	assert_eq(bad.balm_windows, PackedInt32Array([200, 300]), "only valid [start < end] pairs")
	assert_eq(bad.finds_revealed.size(), 0)
	assert_true(bad.washed)
	var dressed := CorpseRecord.from_dict({"dress": "gown"})
	assert_true(dressed.shrouded, "shrouded == (dress != \"\")")


func test_revealed_traits_follow_the_steps() -> void:
	var r := Phase4Fixtures.corpse([&"letter", &"tattoo"])
	r.examined = true
	r.exam_done = [&"hands"]
	r.traits_revealed = [&"tattoo"]
	assert_eq(r.revealed_traits(), [&"tattoo"] as Array[StringName], "only the revealed find's trait")
	r.revealed_traits().append(&"x")
	assert_eq(r.traits_revealed.size(), 1, "a copy")
	r.exam_done = [&"wounds"]
	r.traits_revealed.clear()
	assert_eq(r.revealed_traits(), [] as Array[StringName], "a step without the trait's find")
	var legacy := Phase4Fixtures.corpse([&"letter"])
	legacy.examined = true
	assert_eq(legacy.revealed_traits(), [&"letter"] as Array[StringName], "legacy: examined without step bookkeeping")


func test_valuables_decision_needs_the_pockets_step() -> void:
	var r := Phase4Fixtures.corpse([&"valuables"])
	r.examined = true
	r.exam_done = [&"clothing", &"hands", &"wounds"]
	assert_false(r.needs_valuables_decision(), "pockets not searched yet")
	r.exam_done.append(&"pockets")
	assert_true(r.needs_valuables_decision())
	r.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_false(r.needs_valuables_decision())
	var plain := Phase4Fixtures.corpse([&"letter"])
	plain.exam_done = [&"pockets"]
	assert_false(plain.needs_valuables_decision(), "no valuables")


func test_stage_for_rotten_follows_rot_threshold() -> void:
	var custom := EconomyConfig.new()
	custom.rot_threshold = 0.2
	assert_eq(CorpseRecord.stage_for(0.2, custom), &"decaying")
	assert_eq(CorpseRecord.stage_for(0.19, custom), &"rotten")
	var fixture := Phase4Fixtures.economy_config()
	assert_eq([CorpseRecord.stage_for(0.1, fixture), CorpseRecord.stage_for(0.0999, fixture)], [&"decaying", &"rotten"])


func test_balm_window_slows_decay() -> void:
	# Rate 0.05/h, arrival 460: 10 h with a 4 h window at factor 0.25 → 6 + 1 = 7 effective hours.
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, 460)
	var now := 460 + 600
	r.balm_windows = PackedInt32Array([460 + 120, 460 + 360])
	assert_almost(CorpseDecay.effective_minutes(r, now, 0.25), 420.0)
	assert_almost(CorpseDecay.freshness_at(r, now, 0.05, 0.25), 1.0 - 0.05 * 7.0)
	assert_almost(CorpseDecay.freshness_at(r, now, 0.05), 1.0 - 0.05 * 7.0, 0.0001, "default balm factor 0.25")
	assert_almost(CorpseDecay.effective_minutes(r, now, 1.0), 600.0, 0.0001, "factor 1 = no effect")
	r.balm_windows = PackedInt32Array()
	assert_almost(CorpseDecay.freshness_at(r, now, 0.05), 0.5, 0.0001, "no window: unchanged formula")


func test_balm_window_overlap_is_clipped_to_arrival_and_now() -> void:
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, 1000)
	r.balm_windows = PackedInt32Array([900, 1060, 1500, 3000])
	# Overlap: [1000, 1060] = 60 and [1500, 1600] = 100 at now 1600.
	assert_almost(CorpseDecay.effective_minutes(r, 1600, 0.25), 600.0 - 0.75 * 160.0)
	assert_almost(CorpseDecay.effective_minutes(r, 900, 0.25), 0.0, 0.0001, "before arrival")


func test_three_one_hour_windows_equal_one_three_hour_window() -> void:
	var a := Phase4Fixtures.corpse([], &"fever", 1.0, 0)
	a.balm_windows = PackedInt32Array([60, 120, 120, 180, 180, 240])
	var b := Phase4Fixtures.corpse([], &"fever", 1.0, 0)
	b.balm_windows = PackedInt32Array([60, 240])
	for now: int in [30, 90, 150, 240, 600, 3000]:
		assert_eq(CorpseDecay.freshness_at(a, now, 0.075), CorpseDecay.freshness_at(b, now, 0.075), "now %d" % now)
	var overlapping := Phase4Fixtures.corpse([], &"fever", 1.0, 0)
	overlapping.balm_windows = PackedInt32Array([60, 200, 100, 240])
	assert_eq(CorpseDecay.freshness_at(overlapping, 600, 0.075), CorpseDecay.freshness_at(b, 600, 0.075), "overlaps count once")


func test_is_balm_active() -> void:
	var r := Phase4Fixtures.corpse()
	r.balm_windows = PackedInt32Array([100, 200, 500, 600])
	assert_eq([CorpseDecay.is_balm_active(r, 99), CorpseDecay.is_balm_active(r, 100), CorpseDecay.is_balm_active(r, 199),
			CorpseDecay.is_balm_active(r, 200), CorpseDecay.is_balm_active(r, 550)], [false, true, true, false, true])


func test_minutes_until_without_balm() -> void:
	# 0.05/h: 0.6 is reached after exactly 8 h and first undercut one minute later.
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, 460)
	var m := CorpseDecay.minutes_until(r, 460, 0.05, 0.25, 0.6)
	assert_eq(m, 481)
	assert_true(CorpseDecay.freshness_at(r, 460 + m, 0.05) < 0.6)
	assert_true(CorpseDecay.freshness_at(r, 460 + m - 1, 0.05) >= 0.6)
	assert_eq(CorpseDecay.minutes_until(r, 460 + 100, 0.05, 0.25, 0.6), 381, "from a later moment")
	assert_eq(CorpseDecay.minutes_until(r, 460 + 481, 0.05, 0.25, 0.6), -1, "already below")
	assert_eq(CorpseDecay.minutes_until(r, 460, 0.0, 0.25, 0.6), -1, "no decay")
	assert_eq(CorpseDecay.minutes_until(r, 460, 0.05, 0.25, 0.0), -1, "never below 0")


func test_minutes_until_with_balm_windows() -> void:
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, 0)
	r.balm_windows = PackedInt32Array([120, 240])
	# 2 h full + 2 h at 0.25 (= 0.5 h) → 2.5 h at 240; 3.5 h more to reach 6 h (0.7 at 0.05/h).
	var m := CorpseDecay.minutes_until(r, 0, 0.05, 0.25, 0.7)
	assert_true(CorpseDecay.freshness_at(r, m, 0.05) < 0.7)
	assert_true(CorpseDecay.freshness_at(r, m - 1, 0.05) >= 0.7)
	assert_eq(m, 240 + 211)
	var inside := CorpseDecay.minutes_until(r, 150, 0.05, 0.25, 0.85)
	assert_eq(inside, 121, "from inside the window: 1.5 h effective at 240, 0.85 at 270")
	assert_true(CorpseDecay.freshness_at(r, 150 + inside, 0.05) < 0.85 and CorpseDecay.freshness_at(r, 149 + inside, 0.05) >= 0.85)
	var frozen := Phase4Fixtures.corpse([], &"fever", 1.0, 0)
	frozen.balm_windows = PackedInt32Array([0, 600])
	assert_eq(CorpseDecay.minutes_until(frozen, 0, 0.05, 0.0, 0.9), 600 + 121, "factor 0: nothing happens inside the window")


func test_cemetery_full_counts_reserved_plots() -> void:
	var g := PlotsDouble.new()
	g.free_plots = 3
	assert_false(CorpseDeliveryRules.is_cemetery_full(g, 1))
	assert_false(CorpseDeliveryRules.is_cemetery_full(g, 1, 1))
	assert_true(CorpseDeliveryRules.is_cemetery_full(g, 1, 2), "3 free ≤ 1 unburied + 2 reserved")
	assert_false(CorpseDeliveryRules.is_cemetery_full(null, 5, 5), "no graveyard")
	g.free()


func test_reserved_plots_only_what_no_locked_plot_can_take() -> void:
	var g := PlotsDouble.new()
	g.locked = 6
	g.elder = PackedStringArray(["h_01"])
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 5, &"elder"), 0, "the locked plots still take them")
	g.locked = 2
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 5, &"elder"), 3)
	g.locked = 0
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 1, &"elder"), 1, "one grave waits for S5")
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 0, &"elder"), 0)
	g.elder = PackedStringArray()
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 5, &"elder"), 0, "a world without the story section")
	assert_eq(CorpseDeliveryRules.reserved_plots(g, 5), 5, "no section given")
	assert_eq(CorpseDeliveryRules.reserved_plots(null, 5, &"elder"), 0)
	g.free()
