extends TestCase
## P3 (docs/PHASE3_DESIGN.md §2.6, §2.7, §3.4, §10): ReputationRules (tiers, target, drift ±6,
## pay bonus, stipend, deliveries, migrate_v1, labels) and the Reputation node (change / clamp /
## signal, events, daily drift + stipend idempotent per day – also after loading –, forecast,
## new game start value). Config = Phase3Fixtures.reputation_config().


class FakeScore extends Node:
	var value: int = 0

	func _init() -> void:
		add_to_group(&"cemetery_score")

	func total() -> int:
		return value


var cfg: ReputationConfig
var world: Node
var rep: Reputation
var score: FakeScore
var inv: Inventory
var changes: Array = []
var payments: Array = []


func before_each() -> void:
	cfg = Phase3Fixtures.reputation_config()
	world = Node.new()
	world.name = "RepWorld"
	tree.root.add_child(world)
	score = FakeScore.new()
	world.add_child(score)
	inv = Inventory.new()
	world.add_child(inv)
	rep = Reputation.new()
	rep.config = cfg
	rep.stipend_inventory = inv
	world.add_child(rep)
	EventBus.reputation_changed.connect(_on_rep_changed)
	EventBus.payment_received.connect(_on_payment)


func after_each() -> void:
	EventBus.reputation_changed.disconnect(_on_rep_changed)
	EventBus.payment_received.disconnect(_on_payment)


func _on_rep_changed(value: int, t: StringName, delta: int, reason: String) -> void:
	changes.append([value, t, delta, reason])


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


# --- rules --------------------------------------------------------------------------------

func test_tiers_at_boundaries() -> void:
	var cases := [[0, &"disreputable"], [14, &"disreputable"], [15, &"unremarkable"], [34, &"unremarkable"],
			[35, &"respected"], [54, &"respected"], [55, &"esteemed"], [79, &"esteemed"], [80, &"renowned"], [100, &"renowned"]]
	for c: Array in cases:
		assert_eq(ReputationRules.tier(c[0], cfg), c[1], "value %d" % c[0])
	assert_eq(ReputationRules.tier(cfg.start_value, cfg), &"unremarkable", "new game starts Unauffällig (§14.4)")


func test_tier_index_and_labels() -> void:
	var labels := ["Verrufen", "Unauffällig", "Geachtet", "Geschätzt", "Gerühmt"]
	for i: int in ReputationRules.TIERS.size():
		var t := ReputationRules.TIERS[i]
		assert_eq(ReputationRules.tier_index(t), i, String(t))
		assert_eq(ReputationRules.label(t), labels[i], String(t))
	assert_eq(ReputationRules.tier_index(&"legendary"), -1)
	assert_eq(ReputationRules.label(&"legendary"), "")
	assert_eq(ReputationRules.label(&""), "")


func test_broken_thresholds_fall_back_to_defaults() -> void:
	var broken := cfg.duplicate() as ReputationConfig
	broken.tier_thresholds = PackedInt32Array([1])
	assert_eq(ReputationRules.tier(40, broken), &"respected")
	assert_eq(ReputationRules.tier(40, null), &"respected", "null → data config")


func test_target() -> void:
	assert_eq(ReputationRules.target(0, cfg), 20)
	assert_eq(ReputationRules.target(50, cfg), 50)
	assert_eq(ReputationRules.target(57, cfg), 54, "20 + round(34.2)")
	assert_eq(ReputationRules.target(100, cfg), 80)
	assert_eq(ReputationRules.target(200, cfg), 100, "clamped to max_value")
	assert_eq(ReputationRules.target(-50, cfg), 0, "clamped to min_value")


func test_drift_follows_with_lag_and_is_capped() -> void:
	assert_eq(ReputationRules.drift(25, 20, cfg), -2, "round(-1.7)")
	assert_eq(ReputationRules.drift(25, 29, cfg), 1, "round(1.36)")
	assert_eq(ReputationRules.drift(50, 50, cfg), 0)
	assert_eq(ReputationRules.drift(0, 100, cfg), 6, "+drift_max")
	assert_eq(ReputationRules.drift(100, 0, cfg), -6, "-drift_max")
	for v: int in range(0, 101, 7):
		for t: int in range(0, 101, 9):
			var d := ReputationRules.drift(v, t, cfg)
			assert_true(absi(d) <= cfg.drift_max, "drift %d → %d" % [v, t])
			assert_true(d == 0 or signi(d) == signi(t - v), "drift towards the target")


func test_pay_bonus_and_stipend_per_tier() -> void:
	var bonus := [-2, 0, 1, 2, 3]
	var stipend := [0, 1, 2, 3, 4]
	for i: int in ReputationRules.TIERS.size():
		var t := ReputationRules.TIERS[i]
		assert_eq(ReputationRules.pay_bonus(t, cfg), bonus[i], String(t))
		assert_eq(ReputationRules.stipend(t, cfg), stipend[i], String(t))
	assert_eq(ReputationRules.pay_bonus(&"unknown", cfg), 0)
	assert_eq(ReputationRules.stipend(&"unknown", cfg), 0)


func test_deliveries_one_per_day_in_every_tier() -> void:
	for t: StringName in ReputationRules.TIERS:
		for day: int in range(1, 15):
			var n := ReputationRules.deliveries_on(day, t, cfg)
			assert_true(n <= 1, "at most one corpse per day (§14.2): %s day %d" % [t, day])
			if t != &"disreputable":
				assert_eq(n, 1, "%s day %d" % [t, day])
	assert_eq(ReputationRules.deliveries_on(1, &"disreputable", cfg), 1, "odd day")
	assert_eq(ReputationRules.deliveries_on(2, &"disreputable", cfg), 0, "even day")
	assert_eq(ReputationRules.deliveries_on(7, &"disreputable", cfg), 1)
	assert_eq(ReputationRules.deliveries_on(14, &"disreputable", cfg), 0)


func test_migrate_v1_table() -> void:
	var cases := {0: 40, -1: 31, -2: 22, -3: 13, -5: 0, -9: 0, 1: 49, 7: 100}
	for old: int in cases:
		assert_eq(ReputationRules.migrate_v1(old), cases[old], "v1 %d" % old)
	assert_eq(ReputationRules.tier(ReputationRules.migrate_v1(0), cfg), &"respected", "0 stays Geachtet")
	assert_eq(ReputationRules.tier(ReputationRules.migrate_v1(-3), cfg), &"disreputable", "−3 stays Verrufen")


func test_real_config_matches_the_phase4_fixture() -> void:
	var real := Database.config(&"reputation_config") as ReputationConfig
	assert_not_null(real)
	# Phase 4 (§2.14 / §2.8): the data follows the Phase-4 fixture; the rule tests keep Phase 3's.
	var phase4 := Phase4Fixtures.reputation_config()
	for prop: Dictionary in ReputationConfig.new().get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(real.get(prop.name), phase4.get(prop.name), String(prop.name))


# --- node ---------------------------------------------------------------------------------

func test_value_and_tier_read_game_state() -> void:
	GameState.stats[&"reputation"] = 40
	assert_eq(rep.value(), 40)
	assert_eq(rep.tier(), &"respected")
	assert_eq(GameState.reputation_label(), "Geachtet")


func test_change_clamps_and_signals() -> void:
	GameState.stats[&"reputation"] = 30
	rep.change(10, "Test")
	assert_eq(GameState.get_stat(&"reputation"), 40)
	assert_eq(changes, [[40, &"respected", 10, "Test"]])
	GameState.stats[&"reputation"] = 98
	rep.change(5, "oben")
	assert_eq(rep.value(), 100)
	assert_eq(changes[-1], [100, &"renowned", 2, "oben"], "delta = actual change")
	GameState.stats[&"reputation"] = 3
	rep.change(-8, "unten")
	assert_eq(rep.value(), 0)
	assert_eq(changes[-1][2], -3)
	changes.clear()
	rep.change(-4, "schon unten")
	assert_eq(rep.value(), 0)
	assert_eq(changes, [], "no signal without a change")


func test_events_use_event_points() -> void:
	GameState.stats[&"reputation"] = 50
	var expected := 50
	for kind: StringName in [&"grave_good", &"grave_poor", &"missed_delivery", &"marker_upgrade", &"section_unlocked"]:
		rep.event(kind, String(kind))
		expected += cfg.event_points[kind]
		assert_eq(rep.value(), expected, String(kind))
	assert_eq(expected, 50 + 2 - 3 - 4 + 1 + 4)
	rep.event(&"no_such_event", "x")
	assert_eq(rep.value(), expected, "unknown event ignored")


func test_valuables_event_value_from_economy() -> void:
	var economy := load("res://data/config/economy_config.tres") as EconomyConfig
	GameState.stats[&"reputation"] = 25
	rep.change(economy.valuables_reputation, "Wertsachen genommen")
	assert_eq(rep.value(), 17, "−8 (§2.6)")


func test_apply_daily_drift_then_stipend() -> void:
	GameState.stats[&"reputation"] = 25
	score.value = 57  # target 54
	var result := rep.apply_daily(2)
	assert_eq(result, {"drift": 6, "stipend": 1})
	assert_eq(rep.value(), 31)
	assert_eq(inv.count(&"coin"), 1, "Unauffällig: 1 coin")
	assert_eq(payments, [[1, "Pflegegeld der Gemeinde"]])
	assert_eq(GameState.get_flag(&"rep_last_day"), 2)
	var last := rep.last_daily()
	assert_eq(last.day, 2)
	assert_eq(last.drift, 6)
	assert_eq(last.stipend, 1)
	assert_eq(last.value, 31)
	assert_eq(last.tier, &"unremarkable")


func test_stipend_uses_the_tier_after_the_drift() -> void:
	GameState.stats[&"reputation"] = 33
	score.value = 100  # target 80 → +6 → 39 respected
	rep.apply_daily(5)
	assert_eq(rep.value(), 39)
	assert_eq(inv.count(&"coin"), 2)


func test_disreputable_gets_no_stipend() -> void:
	GameState.stats[&"reputation"] = 5
	score.value = 0  # target 20 → +5 → 10
	assert_eq(rep.apply_daily(3), {"drift": 5, "stipend": 0})
	assert_eq(inv.count(&"coin"), 0)
	assert_eq(payments, [])


func test_apply_daily_is_idempotent_per_day() -> void:
	GameState.stats[&"reputation"] = 25
	score.value = 100
	rep.apply_daily(4)
	var value := rep.value()
	assert_eq(rep.apply_daily(4), {"drift": 0, "stipend": 0}, "second call same day")
	assert_eq(rep.apply_daily(3), {"drift": 0, "stipend": 0}, "earlier day")
	assert_eq(rep.value(), value)
	assert_eq(inv.count(&"coin"), 1)
	rep.apply_daily(5)
	assert_true(rep.value() > value, "next day drifts again")


func test_no_double_drift_after_loading() -> void:
	GameState.stats[&"reputation"] = 25
	score.value = 100
	rep.apply_daily(6)
	var saved := GameState.save_state()
	var value := rep.value()
	GameState.reset()
	GameState.load_state(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved)))))
	assert_eq(rep.apply_daily(6), {"drift": 0, "stipend": 0}, "flag rep_last_day survives the save")
	assert_eq(rep.value(), value)


func test_day_started_applies_the_daily_drift() -> void:
	GameState.stats[&"reputation"] = 25
	GameState.set_flag(&"rep_last_day", TimeManager.day)
	score.value = 100
	TimeManager.advance(TimeManager.minutes_until(0))
	assert_eq(TimeManager.day, 2)
	assert_eq(rep.value(), 31)
	assert_eq(GameState.get_flag(&"rep_last_day"), 2)
	assert_eq(inv.count(&"coin"), 1)


func test_forecast() -> void:
	GameState.stats[&"reputation"] = 25
	score.value = 0
	assert_eq(rep.forecast(), -2)
	score.value = 100
	assert_eq(rep.forecast(), 6)
	GameState.stats[&"reputation"] = 100
	score.value = 200
	assert_eq(rep.forecast(), 0, "already at the target")
	assert_eq(rep.value(), 100, "forecast changes nothing")


func test_new_game_sets_the_start_value() -> void:
	assert_eq(GameState.get_stat(&"reputation"), 0, "reset = 0")
	EventBus.new_game_started.emit()
	assert_eq(rep.value(), 25)
	assert_eq(rep.tier(), &"unremarkable")
	assert_eq(GameState.get_flag(&"rep_last_day"), TimeManager.day, "no drift on the first day")
	assert_eq(rep.apply_daily(TimeManager.day), {"drift": 0, "stipend": 0})


func test_without_score_node_target_uses_zero() -> void:
	score.free()
	GameState.stats[&"reputation"] = 30
	assert_eq(rep.forecast(), ReputationRules.drift(30, 20, cfg))


## Phase 4 §2.8: hair −3, teeth −5, stench at the gate −2 (Phase-3 events unchanged).
func test_phase4_events() -> void:
	rep.config = Phase4Fixtures.reputation_config()
	GameState.stats[&"reputation"] = 50
	rep.event(&"hair_taken", "Zopf")
	assert_eq(rep.value(), 47)
	rep.event(&"teeth_taken", "Zähne")
	assert_eq(rep.value(), 42)
	rep.event(&"stench", "Gestank am Tor")
	assert_eq(rep.value(), 40)
	rep.event(&"grave_good", "gut")
	assert_eq(rep.value(), 42, "Phase-3 points unchanged")
	var real := Database.config(&"reputation_config") as ReputationConfig
	assert_eq([real.event_points[&"hair_taken"], real.event_points[&"teeth_taken"], real.event_points[&"stench"]], [-3, -5, -2])
