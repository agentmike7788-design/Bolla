extends TestCase
## P3 (docs/PHASE3_DESIGN.md §2.5, §3.3, §3.4, §10): CemeteryScore – formula graves + decor −
## dirt, clamped ≥ 0, five tiers incl. Ehrwürdig (Phase 4 §2.14: gated by decor / dirt),
## breakdown with the next tier and venerable_missing,
## cemetery_quality_changed only on change, exactly one after world_ready / loading.
## Graves, decor and dirt come from group doubles.


class FakeGraveyard extends Node:
	var quality: int = 0

	func _init() -> void:
		add_to_group(&"graveyard")

	func total_quality() -> int:
		return quality


class FakeDecorations extends Node:
	var score: int = 0

	func _init() -> void:
		add_to_group(&"decorations")

	func decor_score() -> int:
		return score


class FakeCleanliness extends Node:
	var value: int = 0

	func _init() -> void:
		add_to_group(&"cleanliness")

	func penalty() -> int:
		return value


var world: Node
var graves: FakeGraveyard
var decor: FakeDecorations
var dirt: FakeCleanliness
var score: CemeteryScore
var events: Array = []


func before_each() -> void:
	world = Node.new()
	world.name = "ScoreWorld"
	tree.root.add_child(world)
	graves = FakeGraveyard.new()
	decor = FakeDecorations.new()
	dirt = FakeCleanliness.new()
	world.add_child(graves)
	world.add_child(decor)
	world.add_child(dirt)
	score = CemeteryScore.new()
	score.economy = load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig
	world.add_child(score)
	EventBus.cemetery_quality_changed.connect(_on_quality)


func after_each() -> void:
	EventBus.cemetery_quality_changed.disconnect(_on_quality)


func _on_quality(total: int, rating: StringName) -> void:
	events.append([total, rating])


func test_compute_formula_and_clamp() -> void:
	assert_eq(CemeteryScore.compute(0, 0, 0), 0)
	assert_eq(CemeteryScore.compute(48, 12, 3), 57)
	assert_eq(CemeteryScore.compute(10, 0, 25), 0, "never below 0")
	assert_eq(CemeteryScore.compute(0, 30, 0), 30)
	assert_eq(CemeteryScore.compute(120, 30, 68), 82)


func test_total_reads_the_systems() -> void:
	graves.quality = 48
	decor.score = 12
	dirt.value = 3
	assert_eq(score.total(), 57)
	assert_eq(score.rating(), &"dignified")
	dirt.value = 70
	assert_eq(score.total(), 0)
	assert_eq(score.rating(), &"neglected")


func test_missing_systems_count_zero() -> void:
	decor.free()
	dirt.free()
	graves.quality = 20
	assert_eq(score.total(), 20)
	assert_eq(score.breakdown().decor, 0)
	assert_eq(score.breakdown().dirt, 0)


func test_five_tiers() -> void:
	var cases := [[0, &"neglected"], [15, &"orderly"], [32, &"tended"], [50, &"dignified"], [100, &"dignified"]]
	for c: Array in cases:
		graves.quality = c[0]
		assert_eq(score.rating(), c[1], "total %d (no decor: at most Würdevoll)" % c[0])
	graves.quality = 88
	decor.score = 12
	assert_eq(score.rating(), &"venerable", "graves + decor reach Ehrwürdig")
	dirt.value = 1
	assert_eq(score.rating(), &"dignified", "dirt costs the top tier")


## Phase 4 §2.14: Ehrwürdig needs decor ≥ 12 and a dirt penalty ≤ 6 on top of quality 100.
func test_venerable_gate() -> void:
	graves.quality = 120
	decor.score = 11
	assert_eq(score.rating(), &"dignified", "decor 11 < 12")
	decor.score = 12
	dirt.value = 7
	assert_eq(score.total(), 125)
	assert_eq(score.rating(), &"dignified", "dirt 7 > 6")
	dirt.value = 6
	assert_eq(score.rating(), &"venerable", "decor 12, dirt 6")
	events.clear()
	dirt.value = 7
	EventBus.cleanliness_changed.emit(7, 3)
	assert_eq(events, [[125, &"dignified"]], "the gated rating is what the signal reports")


func test_breakdown() -> void:
	graves.quality = 40
	decor.score = 8
	dirt.value = 2
	assert_eq(score.breakdown(), {"graves": 40, "decor": 8, "dirt": 2, "total": 46, "rating": &"tended",
			"next_rating": &"dignified", "next_at": 50, "venerable_missing": PackedStringArray(["Zier 8/12"])})
	graves.quality = 0
	decor.score = 0
	assert_eq(score.breakdown().next_rating, &"orderly")
	assert_eq(score.breakdown().next_at, 15)
	assert_eq(score.breakdown().total, 0, "clamped")
	assert_eq(score.breakdown().dirt, 2, "the penalty is reported positive")
	graves.quality = 110
	var held := score.breakdown()
	assert_eq(held.rating, &"dignified", "quality enough, decor missing")
	assert_eq([held.next_rating, held.next_at], [&"venerable", 100])
	assert_eq(held.venerable_missing, PackedStringArray(["Zier 0/12"]))
	decor.score = 12
	var top := score.breakdown()
	assert_eq(top.rating, &"venerable")
	assert_eq(top.next_rating, &"", "no tier above Ehrwürdig")
	assert_eq(top.next_at, 0)
	assert_eq(top.venerable_missing, PackedStringArray())


func test_signal_only_on_change() -> void:
	score.refresh()
	assert_eq(events, [[0, &"neglected"]], "first refresh")
	score.refresh()
	assert_eq(events.size(), 1, "unchanged → silent")
	graves.quality = 9
	EventBus.grave_completed.emit("plot_01", "c_0001", 9, [])
	assert_eq(events[-1], [9, &"neglected"])
	EventBus.grave_state_changed.emit("plot_01", GraveRecord.State.MARKED)
	assert_eq(events.size(), 2, "same total → silent")
	decor.score = 6
	EventBus.decor_changed.emit("d_1", &"decor_bench_wood", true)
	assert_eq(events[-1], [15, &"orderly"])
	dirt.value = 1
	EventBus.cleanliness_changed.emit(1, 0)
	assert_eq(events[-1], [14, &"neglected"])
	graves.quality = 11
	EventBus.grave_quality_changed.emit("plot_01", 11)
	assert_eq(events[-1], [16, &"orderly"])
	assert_eq(events.size(), 5)
	score.refresh(true)
	assert_eq(events.size(), 6, "force emits")


func test_exactly_one_after_world_ready() -> void:
	graves.quality = 20
	EventBus.world_ready.emit(world)
	assert_eq(events, [[20, &"orderly"]])
	score.refresh()
	assert_eq(events.size(), 1)


func test_exactly_one_after_loading() -> void:
	score.refresh()
	events.clear()
	SaveManager.is_loading = true
	EventBus.world_ready.emit(world)
	graves.quality = 30
	EventBus.grave_state_changed.emit("plot_01", GraveRecord.State.MARKED)
	decor.score = 5
	EventBus.decor_changed.emit("d_1", &"decor_lantern", true)
	assert_eq(events, [], "silent while loading")
	SaveManager.is_loading = false
	EventBus.grave_state_changed.emit("plot_01", GraveRecord.State.MARKED)
	assert_eq(events, [], "broadcast after the load waits for game_loaded")
	EventBus.game_loaded.emit(1)
	assert_eq(events, [[35, &"tended"]], "exactly one after loading")
	dirt.value = 1
	EventBus.cleanliness_changed.emit(1, 0)
	assert_eq(events.size(), 2, "normal again after the load")


func test_unchanged_value_after_load_still_emits_once() -> void:
	graves.quality = 20
	score.refresh()
	events.clear()
	EventBus.game_loaded.emit(1)
	assert_eq(events, [[20, &"orderly"]])
