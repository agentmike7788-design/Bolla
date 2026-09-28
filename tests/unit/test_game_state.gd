extends TestCase
## M2: GameState – flags, stats, reputation label, reset, save/load (§3.4, §2.4).
## Phase 3 (P3): the label follows ReputationRules on the 0…100 scale (docs/PHASE3_DESIGN.md §2.6).

## Phase 4 (§3.4): + piety, utilized, prepared, trader_sales.
const STAT_KEYS: Array[StringName] = [&"burials", &"valuables_taken", &"reputation", &"missed_deliveries", &"days_played",
		&"piety", &"utilized", &"prepared", &"trader_sales"]


func test_defaults_after_reset() -> void:
	assert_eq(GameState.flags, {})
	assert_eq(GameState.stats.size(), STAT_KEYS.size())
	for key: StringName in STAT_KEYS:
		assert_true(GameState.stats.has(key), "stat %s" % key)
		assert_eq(GameState.get_stat(key), 0)
		assert_true(GameState.stats[key] is int, "stat %s is int" % key)


func test_set_flag_defaults_to_true() -> void:
	GameState.set_flag(&"met_carter")
	assert_true(GameState.has_flag(&"met_carter"))
	assert_eq(GameState.get_flag(&"met_carter"), true)
	assert_true(GameState.get_flag(&"met_carter") is bool)


func test_flag_value_types() -> void:
	GameState.set_flag(&"delivery_skipped", 3)
	GameState.set_flag(&"mood", "grimmig")
	GameState.set_flag(&"weight", 1.5)
	GameState.set_flag(&"off", false)
	GameState.set_flag(&"sn", &"kutscher")
	assert_true(GameState.get_flag(&"delivery_skipped") is int)
	assert_eq(GameState.get_flag(&"delivery_skipped"), 3)
	assert_true(GameState.get_flag(&"mood") is String)
	assert_true(GameState.get_flag(&"weight") is float)
	assert_eq(GameState.get_flag(&"off"), false)
	assert_true(GameState.has_flag(&"off"), "a false flag still exists")
	assert_true(GameState.get_flag(&"sn") is String, "StringName stored as String")
	assert_eq(GameState.get_flag(&"sn"), "kutscher")


func test_unsupported_flag_values_are_ignored() -> void:
	GameState.set_flag(&"vec", Vector3.ONE)
	GameState.set_flag(&"nothing", null)
	GameState.set_flag(&"list", [1, 2])
	assert_false(GameState.has_flag(&"vec"))
	assert_false(GameState.has_flag(&"nothing"))
	assert_false(GameState.has_flag(&"list"))


func test_get_flag_default_and_string_keys() -> void:
	assert_null(GameState.get_flag(&"missing"))
	assert_eq(GameState.get_flag(&"missing", 7), 7)
	GameState.set_flag(&"slice_complete")
	assert_true(GameState.flags.has("slice_complete"), "String lookup finds StringName key")
	assert_eq(GameState.get_flag("slice_complete"), true)


func test_clear_flag_and_clear_flags() -> void:
	GameState.set_flag(&"a")
	GameState.set_flag(&"b", 2)
	GameState.clear_flag(&"a")
	GameState.clear_flag(&"unknown")
	assert_false(GameState.has_flag(&"a"))
	assert_true(GameState.has_flag(&"b"))
	GameState.clear_flags()
	assert_eq(GameState.flags, {})
	assert_eq(GameState.get_stat(&"burials"), 0, "stats untouched")


func test_add_and_get_stat() -> void:
	GameState.add_stat(&"burials", 1)
	GameState.add_stat(&"burials", 2)
	GameState.add_stat(&"reputation", -1)
	GameState.add_stat(&"reputation", -2)
	assert_eq(GameState.get_stat(&"burials"), 3)
	assert_eq(GameState.get_stat(&"reputation"), -3)
	assert_eq(GameState.stats.reputation, -3, "dot access on stats")
	assert_eq(GameState.get_stat(&"never_set"), 0)
	GameState.add_stat(&"custom", 4)
	assert_eq(GameState.get_stat(&"custom"), 4, "free-form stats are allowed")


func test_reputation_label_default_thresholds() -> void:
	var cases := {-9: "Verrufen", 0: "Verrufen", 14: "Verrufen", 15: "Unauffällig", 25: "Unauffällig", 34: "Unauffällig",
			35: "Geachtet", 54: "Geachtet", 55: "Geschätzt", 79: "Geschätzt", 80: "Gerühmt", 100: "Gerühmt"}
	for rep: int in cases:
		GameState.stats[&"reputation"] = rep
		assert_eq(GameState.reputation_label(), cases[rep], "reputation %d" % rep)


func test_reputation_label_uses_reputation_config() -> void:
	var cfg := Phase3Fixtures.reputation_config().duplicate() as ReputationConfig
	cfg.tier_thresholds = PackedInt32Array([10, 20, 30, 40])
	GameState.reputation_config = cfg
	var cases := {9: "Verrufen", 10: "Unauffällig", 20: "Geachtet", 30: "Geschätzt", 40: "Gerühmt"}
	for rep: int in cases:
		GameState.stats[&"reputation"] = rep
		assert_eq(GameState.reputation_label(), cases[rep], "reputation %d" % rep)


func test_reputation_label_survives_broken_thresholds() -> void:
	var cfg := ReputationConfig.new()
	cfg.tier_thresholds = PackedInt32Array([0])
	GameState.reputation_config = cfg
	GameState.stats[&"reputation"] = 40
	assert_eq(GameState.reputation_label(), "Geachtet", "falls back to default thresholds")


func test_reputation_default_stat_stays_zero() -> void:
	# DEFAULT_STATS unchanged (reset = 0); a new game sets start_value via Reputation (§3.4).
	GameState.reset()
	assert_eq(GameState.get_stat(&"reputation"), 0)


func test_reset_clears_everything() -> void:
	var flags_ref := GameState.flags
	GameState.set_flag(&"x", 1)
	GameState.add_stat(&"burials", 2)
	GameState.add_stat(&"custom", 1)
	GameState.reputation_config = ReputationConfig.new()
	GameState.reset()
	assert_eq(GameState.flags, {})
	assert_eq(GameState.get_stat(&"burials"), 0)
	assert_false(GameState.stats.has(&"custom"))
	assert_null(GameState.reputation_config, "config re-resolved lazily")
	assert_true(is_same(flags_ref, GameState.flags), "cleared in place")


func test_save_load_round_trip_typed() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"delivery_skipped", 2)
	GameState.set_flag(&"note", "Brief")
	GameState.set_flag(&"share", 0.25)
	GameState.add_stat(&"burials", 4)
	GameState.add_stat(&"reputation", -2)
	var saved := GameState.save_state()
	var restored: Dictionary = JSON.to_native(JSON.from_native(saved))
	GameState.reset()
	GameState.set_flag(&"stale")
	GameState.load_state(restored)
	assert_eq(GameState.save_state(), saved)
	assert_false(GameState.has_flag(&"stale"), "load replaces completely")
	assert_true(GameState.get_flag(&"delivery_skipped") is int)
	assert_true(GameState.get_flag(&"share") is float)
	assert_true(GameState.get_flag(&"met_carter") is bool)
	for key: Variant in GameState.flags:
		assert_true(key is StringName, "flag keys are StringName")
	for key: StringName in STAT_KEYS:
		assert_true(GameState.stats[key] is int)


func test_save_state_is_a_copy() -> void:
	GameState.set_flag(&"a")
	var saved := GameState.save_state()
	GameState.set_flag(&"b")
	GameState.add_stat(&"burials", 1)
	assert_false((saved.flags as Dictionary).has(&"b"))
	assert_eq((saved.stats as Dictionary)[&"burials"], 0)


func test_load_state_fills_missing_and_skips_bad_values() -> void:
	GameState.load_state({"flags": {"legacy": true, "bad": Vector2.ONE}, "stats": {"burials": 2.0, "reputation": "x"}})
	assert_true(GameState.has_flag(&"legacy"))
	assert_false(GameState.has_flag(&"bad"))
	assert_eq(GameState.get_stat(&"burials"), 2)
	assert_true(GameState.stats[&"burials"] is int, "float from JSON converted to int")
	assert_eq(GameState.get_stat(&"reputation"), 0, "non-numeric stat ignored")
	for key: StringName in STAT_KEYS:
		assert_true(GameState.stats.has(key), "default stat %s present" % key)
	GameState.load_state({})
	assert_eq(GameState.flags, {})
	assert_eq(GameState.get_stat(&"burials"), 0)
