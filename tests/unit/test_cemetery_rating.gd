extends TestCase
## M3: CemeteryRating tiers. Fixture = EconomyConfig class defaults (10 / 25 / 45); the real
## data (§2.4 v3) uses 15 / 32 / 50 and is checked against a recomputed slice playthrough.

const REAL_ECONOMY := "res://data/config/economy_config.tres"
const REAL_TABLES := "res://data/corpses/corpse_tables.tres"
const SLICE_DAYS := 6
## Hours between the 07:40 delivery and the burial in the recomputed playthrough.
const BURIAL_HOURS := 4.0

var config: EconomyConfig


func before_each() -> void:
	config = load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig


func test_tiers_at_boundaries() -> void:
	var cases := [[-5, &"neglected"], [0, &"neglected"], [9, &"neglected"], [10, &"orderly"], [24, &"orderly"],
			[25, &"tended"], [44, &"tended"], [45, &"dignified"], [60, &"dignified"]]
	for c: Array in cases:
		assert_eq(CemeteryRating.rating(c[0], config), c[1], "total %d" % c[0])


func test_labels() -> void:
	assert_eq(CemeteryRating.label(&"neglected"), "Verwahrlost")
	assert_eq(CemeteryRating.label(&"orderly"), "Ordentlich")
	assert_eq(CemeteryRating.label(&"tended"), "Gepflegt")
	assert_eq(CemeteryRating.label(&"dignified"), "Würdevoll")


func test_unknown_label_is_empty() -> void:
	assert_eq(CemeteryRating.label(&""), "")
	assert_eq(CemeteryRating.label(&"glorious"), "")


func test_custom_thresholds() -> void:
	var custom := config.duplicate() as EconomyConfig
	custom.rating_thresholds = PackedInt32Array([1, 2, 3])
	assert_eq(CemeteryRating.rating(0, custom), &"neglected")
	assert_eq(CemeteryRating.rating(1, custom), &"orderly")
	assert_eq(CemeteryRating.rating(2, custom), &"tended")
	assert_eq(CemeteryRating.rating(3, custom), &"dignified")


func test_invalid_thresholds_fall_back_to_defaults() -> void:
	var broken := config.duplicate() as EconomyConfig
	broken.rating_thresholds = PackedInt32Array([5])
	assert_eq(CemeteryRating.rating(9, broken), &"neglected")
	assert_eq(CemeteryRating.rating(45, broken), &"dignified")
	assert_eq(CemeteryRating.rating(30, null), &"tended", "null config -> defaults")


func test_every_rating_has_a_label() -> void:
	for total: int in [0, 10, 25, 45]:
		assert_true(CemeteryRating.label(CemeteryRating.rating(total, config)) != "")


# --- real data (§2.4 v3): Verwahrlost < 15 <= Ordentlich < 32 <= Gepflegt < 50 <= Würdevoll ---

func test_real_config_tiers_at_boundaries() -> void:
	var real := load(REAL_ECONOMY) as EconomyConfig
	assert_eq(real.rating_thresholds, PackedInt32Array([15, 32, 50]))
	var cases := [[14, &"neglected"], [15, &"orderly"], [31, &"orderly"], [32, &"tended"], [49, &"tended"], [50, &"dignified"]]
	for c: Array in cases:
		assert_eq(CemeteryRating.rating(c[0], real), c[1], "total %d" % c[0])


## GP-02: the six slice corpses of the real tables, examined and buried 4 h after the delivery
## (fresh for every cause), scored with the real economy config.
func test_real_playthrough_honest_shroud_and_gravestone_is_dignified() -> void:
	var total := _slice_total(true, &"gravestone_simple", 0)
	assert_eq(total, 57, "9, 10, 9, 10, 10, 9")
	assert_eq(_real_rating(total), &"dignified")


func test_real_playthrough_without_shroud_misses_dignified() -> void:
	var total := _slice_total(false, &"gravestone_simple", 0)
	assert_eq(total, 45)
	assert_eq(_real_rating(total), &"tended")


func test_real_playthrough_three_thefts_miss_dignified() -> void:
	var total := _slice_total(true, &"gravestone_simple", 3)
	assert_eq(total, 48)
	assert_eq(_real_rating(total), &"tended")
	assert_eq(_real_rating(_slice_total(true, &"gravestone_simple", 2)), &"dignified", "two thefts still reach it")


func test_real_playthrough_crosses_or_one_shroud_miss_dignified() -> void:
	assert_eq(_real_rating(_slice_total(true, &"wooden_cross", 0)), &"tended", "wooden crosses")
	assert_eq(_real_rating(_slice_total(false, &"gravestone_simple", 0, 1)), &"tended", "a single shroud")


## Sum of the six slice graves. take: how many valuables corpses are robbed (the first ones);
## shrouds: how many graves get a shroud when `shroud` is false (the first ones).
func _slice_total(shroud: bool, marker: StringName, take: int, shrouds: int = 0) -> int:
	var real := load(REAL_ECONOMY) as EconomyConfig
	var tables := load(REAL_TABLES) as CorpseTables
	var total := 0
	for day: int in range(1, SLICE_DAYS + 1):
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), tables, day)
		r.examined = true
		r.shrouded = shroud or day <= shrouds
		if r.has_trait(CorpseRecord.TRAIT_VALUABLES):
			r.valuables_decision = CorpseRecord.DECISION_TAKEN if take > 0 else CorpseRecord.DECISION_LEFT
			take -= 1
		var rate := tables.base_decay_per_hour * float(tables.get_cause(r.cause_id).get("decay_mult", 1.0))
		r.freshness_at_burial = 1.0 - rate * BURIAL_HOURS
		total += GraveQuality.compute(r, marker, real)
	return total


func _real_rating(total: int) -> StringName:
	return CemeteryRating.rating(total, load(REAL_ECONOMY) as EconomyConfig)
