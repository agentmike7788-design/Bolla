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
	assert_eq(real.causes.size(), 6)
	for c: Dictionary in real.causes:
		assert_true(c.id is StringName, "cause id is a StringName")
		assert_true(String(c.label) != "" and String(c.description) != "")
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
	var cases := [[1.0, &"fresh"], [0.6, &"fresh"], [0.59, &"wilted"], [0.3, &"wilted"], [0.29, &"decaying"], [0.0, &"decaying"]]
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
	assert_eq(d.keys().size(), 19, "every field is saved (buried_day: §11 register)")
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
