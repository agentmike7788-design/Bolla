extends TestCase
## M3: GraveQuality – breakdown labels/points (§2.4 table), clamp, payment.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"

var tables: CorpseTables
var config: EconomyConfig


func before_each() -> void:
	tables = load(FIXTURE_TABLES) as CorpseTables
	config = load(FIXTURE_ECONOMY) as EconomyConfig


## Buried, not examined, not shrouded, freshness between the thresholds (no freshness line).
func _corpse(freshness: float = 0.45) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = "corpse_0001"
	r.cause_id = &"fever"
	r.location = &"buried"
	r.freshness = freshness
	r.freshness_at_burial = freshness
	return r


func _labels(lines: Array[Dictionary]) -> Array:
	var out: Array = []
	for line: Dictionary in lines:
		out.append(line.label)
	return out


func _sum(lines: Array[Dictionary]) -> int:
	var total := 0
	for line: Dictionary in lines:
		total += int(line.points)
	return total


func test_minimal_grave_is_buried_only() -> void:
	var lines := GraveQuality.breakdown(_corpse(), &"", config)
	assert_eq(lines, [{"label": "Bestattet", "points": 2}])
	assert_eq(GraveQuality.compute(_corpse(), &"", config), 2)


func test_each_factor_of_the_table() -> void:
	var r := _corpse()
	r.shrouded = true
	assert_eq(GraveQuality.breakdown(r, &"", config)[1], {"label": "Leichentuch", "points": 2})
	assert_eq(GraveQuality.breakdown(_corpse(), &"wooden_cross", config)[1], {"label": "Holzkreuz", "points": 1})
	assert_eq(GraveQuality.breakdown(_corpse(), &"gravestone_simple", config)[1], {"label": "Grabstein", "points": 3})
	assert_eq(GraveQuality.breakdown(_corpse(0.8), &"", config)[1], {"label": "Frisch", "points": 1})
	assert_eq(GraveQuality.breakdown(_corpse(0.1), &"", config)[1], {"label": "Verwesend", "points": -1})
	var examined := _corpse()
	examined.examined = true
	assert_eq(GraveQuality.breakdown(examined, &"", config)[1], {"label": "Untersucht", "points": 1})
	var left := _corpse()
	left.valuables_decision = &"left"
	assert_eq(GraveQuality.breakdown(left, &"", config)[1], {"label": "Wertsachen belassen", "points": 1})
	var taken := _corpse()
	taken.valuables_decision = &"taken"
	assert_eq(GraveQuality.breakdown(taken, &"", config)[1], {"label": "Wertsachen genommen", "points": -2})


func test_freshness_thresholds() -> void:
	var cases := [[1.0, 1], [0.6, 1], [0.59, 0], [0.3, 0], [0.29, -1], [0.0, -1]]
	for c: Array in cases:
		assert_eq(GraveQuality.compute(_corpse(c[0]), &"", config), 2 + int(c[1]), "freshness %s" % str(c[0]))


func test_freshness_at_burial_wins_over_current_freshness() -> void:
	var r := _corpse()
	r.freshness = 0.1
	r.freshness_at_burial = 0.9
	assert_has(_labels(GraveQuality.breakdown(r, &"", config)), "Frisch")
	r.freshness_at_burial = -1.0
	assert_has(_labels(GraveQuality.breakdown(r, &"", config)), "Verwesend", "unset -> current freshness")


func test_full_example_quality_9() -> void:
	# docs §1.9: Bestattet +2, Leichentuch +2, Grabstein +3, frisch +1, untersucht +1 = 9
	var r := _corpse(0.9)
	r.shrouded = true
	r.examined = true
	var lines := GraveQuality.breakdown(r, &"gravestone_simple", config)
	assert_eq(_labels(lines), ["Bestattet", "Leichentuch", "Grabstein", "Frisch", "Untersucht"])
	assert_eq(GraveQuality.compute(r, &"gravestone_simple", config), 9)
	assert_eq(GraveQuality.payment(r, 9, tables, config), 3 + 4, "fever base 3 + floor(4.5)")


func test_integration_formula_wooden_cross() -> void:
	var r := _corpse(1.0)
	r.shrouded = true
	r.examined = true
	assert_eq(GraveQuality.compute(r, &"wooden_cross", config), 2 + 2 + 1 + 1 + 1)


func test_valuables_left_and_taken() -> void:
	var r := _corpse(0.9)
	r.shrouded = true
	r.examined = true
	r.traits = [&"valuables"]
	r.valuables_decision = &"left"
	assert_eq(GraveQuality.compute(r, &"gravestone_simple", config), 10)
	r.valuables_decision = &"taken"
	assert_eq(GraveQuality.compute(r, &"gravestone_simple", config), 7)


func test_clamp_to_max() -> void:
	var generous := config.duplicate() as EconomyConfig
	generous.quality_buried = 8
	var r := _corpse(0.9)
	r.shrouded = true
	r.examined = true
	var lines := GraveQuality.breakdown(r, &"gravestone_simple", generous)
	assert_eq(_sum(lines), 8 + 2 + 3 + 1 + 1, "breakdown is not clamped")
	assert_eq(GraveQuality.compute(r, &"gravestone_simple", generous), 10)


func test_clamp_to_min() -> void:
	var harsh := config.duplicate() as EconomyConfig
	harsh.quality_buried = 0
	var r := _corpse(0.1)
	r.valuables_decision = &"taken"
	assert_eq(_sum(GraveQuality.breakdown(r, &"", harsh)), -3)
	assert_eq(GraveQuality.compute(r, &"", harsh), 0)


func test_custom_quality_range() -> void:
	var custom := config.duplicate() as EconomyConfig
	custom.quality_min = 3
	custom.quality_max = 5
	assert_eq(GraveQuality.compute(_corpse(), &"", custom), 3)
	var r := _corpse(0.9)
	r.shrouded = true
	assert_eq(GraveQuality.compute(r, &"gravestone_simple", custom), 5)


func test_unknown_marker_adds_nothing() -> void:
	assert_eq(_labels(GraveQuality.breakdown(_corpse(), &"flower", config)), ["Bestattet"])


func test_compute_equals_breakdown_sum_within_range() -> void:
	for i: int in 20:
		var r := CorpseGenerator.generate(i, tables, 5)
		r.examined = i % 2 == 0
		r.shrouded = i % 3 == 0
		r.freshness_at_burial = float(i) / 19.0
		if r.has_trait(&"valuables"):
			r.valuables_decision = &"taken" if i % 4 == 0 else &"left"
		var marker: StringName = [&"wooden_cross", &"gravestone_simple", &""][i % 3]
		var total := _sum(GraveQuality.breakdown(r, marker, config))
		assert_eq(GraveQuality.compute(r, marker, config), clampi(total, 0, 10))


func test_payment() -> void:
	var fever := _corpse()
	var drowned := _corpse()
	drowned.cause_id = &"drowned"
	assert_eq(GraveQuality.payment(fever, 0, tables, config), 3)
	assert_eq(GraveQuality.payment(fever, 1, tables, config), 3)
	assert_eq(GraveQuality.payment(fever, 7, tables, config), 6)
	assert_eq(GraveQuality.payment(drowned, 10, tables, config), 9)
	var unknown := _corpse()
	unknown.cause_id = &"mystery"
	assert_eq(GraveQuality.payment(unknown, 4, tables, config), 2, "unknown cause has no base payment")


func test_payment_uses_payment_per_quality() -> void:
	var custom := config.duplicate() as EconomyConfig
	custom.payment_per_quality = 1.0
	assert_eq(GraveQuality.payment(_corpse(), 5, tables, custom), 8)
	custom.payment_per_quality = 0.3
	assert_eq(GraveQuality.payment(_corpse(), 5, tables, custom), 4, "3 + floor(1.5)")


func test_payment_never_negative() -> void:
	var custom := config.duplicate() as EconomyConfig
	custom.payment_per_quality = -5.0
	assert_eq(GraveQuality.payment(_corpse(), 10, tables, custom), 0)


func test_missing_inputs_do_not_crash() -> void:
	assert_eq(GraveQuality.breakdown(null, &"wooden_cross", config), [])
	assert_eq(GraveQuality.compute(null, &"wooden_cross", config), 0)
	assert_eq(GraveQuality.compute(_corpse(), &"wooden_cross", null), 3, "defaults without config")
	assert_eq(GraveQuality.payment(_corpse(), 4, null, config), 2, "no tables -> no base payment")


## The data file equals the class defaults except the v3 rating thresholds (§2.4: 15 / 32 / 50).
## The class default stays 10 / 25 / 45 – the fixture relies on it (test_cemetery_rating.gd).
func test_real_economy_config_matches_defaults() -> void:
	var real := load("res://data/config/economy_config.tres") as EconomyConfig
	var defaults := EconomyConfig.new()
	assert_not_null(real)
	for prop: Dictionary in defaults.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "rating_thresholds":
			assert_eq(real.get(prop.name), defaults.get(prop.name), String(prop.name))
	assert_eq(real.rating_thresholds, PackedInt32Array([15, 32, 50]), "v3 thresholds")
	assert_eq(defaults.rating_thresholds, PackedInt32Array([10, 25, 45]), "class default unchanged")
	assert_true(Database.config(&"economy_config") is EconomyConfig)


## ARCH-06: the quality's freshness line and the corpse's stage use the same comparison.
func test_freshness_points_match_the_stage() -> void:
	var custom := config.duplicate() as EconomyConfig
	custom.fresh_good_threshold = 0.8
	custom.fresh_bad_threshold = 0.5
	var points := {&"fresh": custom.fresh_good_bonus, &"wilted": 0, &"decaying": custom.fresh_bad_malus}
	for f: float in [1.0, 0.8, 0.79, 0.6, 0.5, 0.49, 0.0]:
		var stage := CorpseRecord.stage_for(f, custom)
		assert_eq(GraveQuality.compute(_corpse(f), &"", custom), custom.quality_buried + int(points[stage]), "freshness %s (%s)" % [str(f), stage])
