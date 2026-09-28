extends TestCase
## P3 (docs/PHASE4_DESIGN.md §2.7, §3.4, §10): PietyRules (five tiers at the thresholds, labels,
## self image, recovery, affinity hook, per-tier values) and the Piety node (change / clamp /
## signal, quiet tier notifications without a number, events, daily recovery idempotent and
## only without harvesting the day before, ghost gift and Ilse's bonus per tier, new game).
## Config = Phase4Fixtures.piety_config().

var cfg: PietyConfig
var world: Node
var piety: Piety
var changes: Array = []
var notes: Array = []


func before_each() -> void:
	GameState.reset()
	cfg = Phase4Fixtures.piety_config()
	world = Node.new()
	world.name = "PietyWorld"
	tree.root.add_child(world)
	piety = Piety.new()
	piety.config = cfg
	world.add_child(piety)
	changes.clear()
	notes.clear()
	EventBus.piety_changed.connect(_on_piety)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.piety_changed.disconnect(_on_piety)
	EventBus.notification_requested.disconnect(_on_note)
	world.free()
	GameState.reset()


func _on_piety(value: int, t: StringName, delta: int, reason: String) -> void:
	changes.append([value, t, delta, reason])


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


# --- rules --------------------------------------------------------------------------------

func test_tiers_at_thresholds() -> void:
	var cases := [[-100, &"hardhearted"], [-60, &"hardhearted"], [-59, &"callous"], [-20, &"callous"],
			[-19, &"matter_of_fact"], [0, &"matter_of_fact"], [19, &"matter_of_fact"], [20, &"considerate"],
			[59, &"considerate"], [60, &"devout"], [100, &"devout"]]
	for c: Array in cases:
		assert_eq(PietyRules.tier(c[0], cfg), c[1], "value %d" % c[0])
	assert_eq(PietyRules.tier(0, null), &"matter_of_fact", "null = data config")


func test_broken_thresholds_fall_back() -> void:
	var broken := cfg.duplicate() as PietyConfig
	broken.tier_thresholds = PackedInt32Array([0])
	assert_eq(PietyRules.tier(-30, broken), &"callous", "default thresholds")


func test_labels_index_and_self_image() -> void:
	var labels: Array = []
	for t: StringName in PietyRules.TIERS:
		labels.append(PietyRules.label(t))
		assert_eq(PietyRules.tier_index(t), PietyRules.TIERS.find(t))
		assert_true(PietyRules.self_image(t) != "", "self image %s" % t)
	assert_eq(labels, ["Hartherzig", "Abgebrüht", "Sachlich", "Rücksichtsvoll", "Andächtig"])
	assert_eq(PietyRules.self_image(&"devout"), "Du gehst leise zwischen ihnen. Sie merken es.")
	assert_eq(PietyRules.self_image(&"hardhearted"), "Die Toten sind Ware. Du schläfst trotzdem.")
	assert_eq([PietyRules.label(&"x"), PietyRules.self_image(&"x"), PietyRules.tier_index(&"x")], ["", "", 2])


func test_recovery_rule() -> void:
	assert_eq(PietyRules.recovery(-5, false, cfg), 1)
	assert_eq(PietyRules.recovery(-5, true, cfg), 0, "harvested yesterday")
	assert_eq(PietyRules.recovery(0, false, cfg), 0)
	assert_eq(PietyRules.recovery(12, false, cfg), 0, "never towards 0 from above")
	var fast := cfg.duplicate() as PietyConfig
	fast.daily_recovery = 3
	assert_eq(PietyRules.recovery(-2, false, fast), 2, "never past 0")


func test_affinity_hook() -> void:
	var cases := [[20, &"soul"], [100, &"soul"], [19, &""], [0, &""], [-19, &""], [-20, &"bone"], [-100, &"bone"]]
	for c: Array in cases:
		assert_eq(PietyRules.affinity(c[0], cfg), c[1], "value %d" % c[0])
	GameState.stats[&"piety"] = 40
	assert_eq(piety.affinity(), &"soul")


func test_per_tier_values() -> void:
	assert_eq(PietyRules.per_tier(cfg.gift_by_tier, &"devout"), 3)
	assert_eq(PietyRules.per_tier(cfg.buyer_bonus_by_tier, &"callous"), 1)
	assert_eq(PietyRules.per_tier(PackedInt32Array(), &"devout"), 0, "missing entry")


# --- node ---------------------------------------------------------------------------------

func test_group_and_default_stat() -> void:
	assert_true(piety.is_in_group(&"piety"))
	assert_false(piety.is_in_group(&"saveable"), "the value lives in GameState")
	assert_true(GameState.stats.has(&"piety"), "DEFAULT_STATS")
	assert_eq([piety.value(), piety.tier()], [0, &"matter_of_fact"])


func test_change_clamps_and_signals() -> void:
	piety.change(-5, "Test")
	assert_eq(GameState.get_stat(&"piety"), -5)
	assert_eq(changes, [[-5, &"matter_of_fact", -5, "Test"]])
	piety.change(-500, "tief")
	assert_eq(piety.value(), -100, "clamped")
	assert_eq(changes.back(), [-100, &"hardhearted", -95, "tief"])
	changes.clear()
	piety.change(-1, "noch tiefer")
	assert_eq(changes, [], "no signal without a change")
	piety.change(300, "hoch")
	assert_eq(piety.value(), 100)


func test_tier_change_notifies_quietly_without_number() -> void:
	piety.change(-10, "a")
	assert_eq(notes, [], "same tier → no note")
	piety.change(-10, "b")
	assert_eq(notes, [[Piety.TEXT_TIER_DOWN, &"info"]], "Sachlich → Abgebrüht")
	piety.change(60, "c")
	assert_eq(notes.size(), 2, "Abgebrüht → Rücksichtsvoll: one note")
	assert_eq(notes.back(), [Piety.TEXT_TIER_UP, &"info"])
	for n: Array in notes:
		assert_false(String(n[0]).contains("0") or String(n[0]).contains("4"), "no number in the note")


func test_events_use_config_points() -> void:
	var expected := 0
	for kind: StringName in [&"valuables_left", &"full_prep", &"valuables_taken", &"hair_taken", &"teeth_taken",
			&"bare_burial", &"rotten_burial"]:
		piety.event(kind, String(kind))
		expected += cfg.events[kind]
		assert_eq(piety.value(), expected, String(kind))
	assert_eq(expected, 3 + 3 - 6 - 4 - 6 - 2 - 2)
	piety.event(&"no_such_event", "x")
	assert_eq(piety.value(), expected, "unknown event ignored")


func test_daily_recovery_idempotent() -> void:
	GameState.stats[&"piety"] = -5
	assert_eq(piety.apply_daily(3), 1)
	assert_eq(piety.value(), -4)
	assert_eq(int(GameState.get_flag(&"piety_last_day")), 3)
	assert_eq(piety.apply_daily(3), 0, "same day again")
	assert_eq(piety.apply_daily(2), 0, "an older day")
	assert_eq(piety.value(), -4)
	assert_eq(changes.back()[3], Piety.REASON_RECOVERY)


func test_daily_recovery_only_without_harvest_yesterday() -> void:
	GameState.stats[&"piety"] = -10
	GameState.set_flag(&"piety_used_day", 4)
	assert_eq(piety.apply_daily(5), 0, "harvested on day 4")
	assert_eq(piety.value(), -10)
	assert_eq(piety.apply_daily(6), 1, "day 5 without harvesting")
	assert_eq(piety.value(), -9)
	GameState.stats[&"piety"] = 7
	assert_eq(piety.apply_daily(7), 0, "positive values stay")
	GameState.stats[&"piety"] = 0
	assert_eq(piety.apply_daily(8), 0)


func test_recovery_from_one_harvest_back_to_matter_of_fact() -> void:
	# §2.7: one harvested corpse (−10), then only dignified work: back to „Sachlich“ in a few days.
	GameState.stats[&"piety"] = -20
	GameState.set_flag(&"piety_used_day", 1)
	assert_eq(piety.tier(), &"callous")
	piety.apply_daily(2)
	assert_eq(piety.value(), -20)
	piety.apply_daily(3)
	piety.event(&"full_prep", "hergerichtet")
	assert_eq(piety.value(), -16)
	assert_eq(piety.tier(), &"matter_of_fact")


func test_gift_and_buyer_bonus_per_tier() -> void:
	var cases := [[-80, 0, 1], [-30, 2, 1], [0, 2, 0], [30, 2, 0], [80, 3, 0]]
	for c: Array in cases:
		GameState.stats[&"piety"] = c[0]
		assert_eq(piety.gift_coins(), c[1], "gift at %d" % c[0])
		assert_eq(piety.buyer_bonus(), c[2], "bonus at %d" % c[0])


func test_value_clamps_a_damaged_stat() -> void:
	GameState.stats[&"piety"] = 400
	assert_eq(piety.value(), 100)
	piety._on_game_loaded(0)
	assert_eq(GameState.get_stat(&"piety"), 100, "repaired on load")


func test_new_game_starts_at_start_value() -> void:
	GameState.stats[&"piety"] = -40
	var custom := cfg.duplicate() as PietyConfig
	custom.start_value = 5
	piety.config = custom
	piety._on_new_game_started()
	assert_eq(piety.value(), 5)
	assert_eq(int(GameState.get_flag(&"piety_last_day")), TimeManager.day, "the first day never recovers")


func test_real_config_matches_the_fixture() -> void:
	var real := Database.config(&"piety_config") as PietyConfig
	assert_not_null(real)
	# Phase 6 (§2.7): the data follows the Phase-6 fixture (Phase 4 + full_prep rule + service, devotion, reinterred).
	var expected := Phase6Fixtures.piety_config()
	for prop: Dictionary in PietyConfig.new().get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(real.get(prop.name), expected.get(prop.name), String(prop.name))
