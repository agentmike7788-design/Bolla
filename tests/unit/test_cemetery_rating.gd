extends TestCase
## M3: CemeteryRating tiers (Verwahrlost < 10 <= Ordentlich < 25 <= Gepflegt < 45 <= Würdevoll).

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
