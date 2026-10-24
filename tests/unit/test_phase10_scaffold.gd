extends TestCase
## Lead / W0 (docs/PHASE10_DESIGN.md §12): the Phase-10 scaffold – every stub class loads with its contract signature,
## CalendarRules is complete, every new data class / config .tres holds valid contract values, the extensions of
## existing data classes, the 6 EventBus signals, no new input actions, Database folders, save format v9 + migration
## chain 1 → … → 9, and the W1 fixtures (tests/fixtures/phase10, Phase10Fixtures, tests/fixtures/saves_v8).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = []
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/economy/wishlist_probe.gd": "WishlistProbe",
	# P2
	"res://src/systems/treasury/treasury.gd": "Treasury",
	"res://src/systems/treasury/treasury_rules.gd": "TreasuryRules",
	"res://src/entities/offering_box/offering_box.gd": "OfferingBox",
	# P3
	"res://src/systems/treasury/cash_book.gd": "CashBook",
	"res://src/systems/treasury/cash_book_rules.gd": "CashBookRules",
	# P4
	"res://src/systems/market/market.gd": "Market",
	"res://src/systems/market/market_rules.gd": "MarketRules",
	"res://src/entities/market_stall/market_stall.gd": "MarketStall",
}
## Contract methods per class (§3.4) – a rename breaks this list. CalendarRules is complete (Lead, W0).
const METHODS := {
	"CalendarRules": ["weekday", "weekday_name", "week_of", "month_key", "month_title", "is_first_of_month",
			"first_day_of_month", "days_in_month", "next_weekday"],
	"Treasury": ["is_open", "open_day", "apply_morning", "apply_minute", "post_load", "last_schau", "pending_pay", "settlement",
			"open_settlement", "due_day", "pay_dues", "defer_dues", "poor_box_coins", "drop_in_poor_box", "empty_poor_box",
			"give_to_poor_box", "check_goal", "goal_progress", "save_state", "load_state"],
	"TreasuryRules": ["care_share", "parish_pay", "prorate", "rent_due", "tithe", "estimate", "dues_block_reason"],
	"OfferingBox": ["can_interact", "get_interaction_prompt", "interact"],
	"CashBook": ["open_day", "day_page", "week_page", "month_page", "booked_income", "untracked_in", "totals_since", "save_state",
			"load_state"],
	"CashBookRules": ["source_of", "is_receipt", "untracked"],
	"Market": ["is_open", "market_day", "next_market", "lage", "lage_all", "grant_stall", "stall_granted", "stall_offers", "buy",
			"set_up_block_reason", "set_up", "sell_tick", "take_down", "stall_goods", "sold_on", "apply_minute", "save_state",
			"load_state"],
	"MarketRules": ["is_market_day", "next_market_day", "group_state", "offers", "demand", "sale_coins", "buyer_for", "notice_text"],
	"MarketStall": ["can_interact", "get_interaction_prompt", "interact"],
	"WishlistProbe": ["open_cost"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["CalendarRules", "weekday", 1], ["CalendarRules", "weekday_name", 2], ["CalendarRules", "week_of", 1],
	["CalendarRules", "month_key", 2], ["CalendarRules", "month_title", 2], ["CalendarRules", "is_first_of_month", 2],
	["CalendarRules", "first_day_of_month", 2], ["CalendarRules", "days_in_month", 2], ["CalendarRules", "next_weekday", 2],
	["Treasury", "is_open", 0], ["Treasury", "open_day", 0], ["Treasury", "apply_morning", 1], ["Treasury", "apply_minute", 2],
	["Treasury", "post_load", 0], ["Treasury", "last_schau", 0], ["Treasury", "pending_pay", 0], ["Treasury", "settlement", 1],
	["Treasury", "open_settlement", 0], ["Treasury", "due_day", 0], ["Treasury", "pay_dues", 2], ["Treasury", "defer_dues", 0],
	["Treasury", "poor_box_coins", 0], ["Treasury", "drop_in_poor_box", 2], ["Treasury", "empty_poor_box", 1],
	["Treasury", "give_to_poor_box", 1], ["Treasury", "check_goal", 0], ["Treasury", "goal_progress", 0],
	["Treasury", "save_state", 0], ["Treasury", "load_state", 1],
	["TreasuryRules", "care_share", 2], ["TreasuryRules", "parish_pay", 5], ["TreasuryRules", "prorate", 3],
	["TreasuryRules", "rent_due", 4], ["TreasuryRules", "tithe", 2], ["TreasuryRules", "estimate", 2],
	["TreasuryRules", "dues_block_reason", 2],
	["OfferingBox", "can_interact", 1], ["OfferingBox", "get_interaction_prompt", 1], ["OfferingBox", "interact", 1],
	["CashBook", "open_day", 0], ["CashBook", "day_page", 1], ["CashBook", "week_page", 1], ["CashBook", "month_page", 1],
	["CashBook", "booked_income", 2], ["CashBook", "untracked_in", 1], ["CashBook", "totals_since", 1],
	["CashBook", "save_state", 0], ["CashBook", "load_state", 1],
	["CashBookRules", "source_of", 2], ["CashBookRules", "is_receipt", 2], ["CashBookRules", "untracked", 3],
	["Market", "is_open", 0], ["Market", "market_day", 0], ["Market", "next_market", 0], ["Market", "lage", 1],
	["Market", "lage_all", 0], ["Market", "grant_stall", 0], ["Market", "stall_granted", 0], ["Market", "stall_offers", 1],
	["Market", "buy", 4], ["Market", "set_up_block_reason", 1], ["Market", "set_up", 3], ["Market", "sell_tick", 0],
	["Market", "take_down", 1], ["Market", "stall_goods", 0], ["Market", "sold_on", 1], ["Market", "apply_minute", 2],
	["Market", "save_state", 0], ["Market", "load_state", 1],
	["MarketRules", "is_market_day", 2], ["MarketRules", "next_market_day", 2], ["MarketRules", "group_state", 4],
	["MarketRules", "offers", 4], ["MarketRules", "demand", 5], ["MarketRules", "sale_coins", 5], ["MarketRules", "buyer_for", 4],
	["MarketRules", "notice_text", 3],
	["MarketStall", "can_interact", 1], ["MarketStall", "get_interaction_prompt", 1], ["MarketStall", "interact", 1],
	["WishlistProbe", "open_cost", 2],
]
## Base classes fixed by §3.4.
const BASES := {"Treasury": "Node", "CashBook": "Node", "Market": "Node", "OfferingBox": "StaticBody3D",
		"MarketStall": "StaticBody3D", "TreasuryRules": "RefCounted", "CashBookRules": "RefCounted", "MarketRules": "RefCounted",
		"WishlistProbe": "RefCounted", "CalendarRules": "RefCounted"}
const SIGNALS := {
	"parish_schau": 4, "parish_paid": 3, "settlement_changed": 3, "poor_box_changed": 1, "cash_booked": 3, "market_changed": 3,
}
const DATA_CLASSES := {
	"TreasuryConfig": "res://src/systems/treasury/treasury_config.gd",
	"CashBookConfig": "res://src/systems/treasury/cash_book_config.gd",
	"MarketConfig": "res://src/systems/market/market_config.gd",
	"MarketStallData": "res://src/systems/market/market_stall_data.gd",
	"MarketOfferData": "res://src/systems/market/market_offer_data.gd",
	"MarketWareData": "res://src/systems/market/market_ware_data.gd",
	"WishlistData": "res://src/systems/economy/wishlist_data.gd",
	"WishlistEntryData": "res://src/systems/economy/wishlist_entry_data.gd",
	"CalendarRules": "res://src/systems/time/calendar_rules.gd",
}
## Properties changed in the data (and the class default together) after the W0 hand-over; the fixtures keep the W0
## values. Empty at W0.
const DATA_CHANGED_AFTER_W0 := {}


func test_stub_scripts_load_with_their_class_names() -> void:
	var global := _global_classes()
	for path: String in STUBS:
		var script := load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		assert_true(script.can_instantiate(), path + " parses")
		var cls: String = STUBS[path]
		assert_eq(global.get(cls), path, "class_name %s → %s" % [cls, path])
		if not IMPLEMENTED.has(cls):
			assert_true(script.source_code.contains("## STUB ("), cls + " is marked as stub")
		var names := _methods(script)
		for method: String in METHODS.get(cls, []):
			assert_true(names.has(method), "%s.%s" % [cls, method])
	var cal := load(DATA_CLASSES.CalendarRules) as GDScript
	assert_false(cal.source_code.contains("## STUB ("), "CalendarRules is complete (Lead, W0)")
	for method: String in METHODS.CalendarRules:
		assert_true(_methods(cal).has(method), "CalendarRules.%s" % method)


func test_contract_arities_and_bases() -> void:
	for spec: Array in ARITY:
		_assert_arity(_path_of(spec[0]), spec[1], spec[2], spec[0])
	for cls: String in BASES:
		var script := load(_path_of(cls)) as GDScript
		assert_eq(script.get_instance_base_type(), StringName(BASES[cls]), "%s extends %s" % [cls, BASES[cls]])


func test_data_classes_are_registered() -> void:
	var global := _global_classes()
	for cls: String in DATA_CLASSES:
		assert_eq(global.get(cls), DATA_CLASSES[cls], cls)
		if cls == "CalendarRules":
			continue
		var res: Resource = (load(DATA_CLASSES[cls]) as GDScript).new()
		assert_true(res is Resource, cls)
	assert_eq(global.get("Phase10Fixtures"), "res://tests/fixtures/phase10/phase10_fixtures.gd")


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in Phase10Fixtures.SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	for spec: Array in [["res://src/entities/offering_box/offering_box.tscn", "OfferingBox"],
			["res://src/entities/market_stall/market_stall.tscn", "MarketStall"]]:
		var scene := load(spec[0]) as PackedScene
		assert_not_null(scene, spec[0])
		if scene == null:
			continue
		var node := scene.instantiate()
		assert_true(node is StaticBody3D and (node.get_script() as Script).get_global_name() == StringName(spec[1]), spec[1])
		assert_not_null(node.get_node_or_null(^"Interactable"), spec[1] + " has an Interactable")
		assert_eq((node as StaticBody3D).collision_layer, 0, "%s: no body collision in W0 (W-Welt / owner)" % spec[1])
		node.free()
	# The save orders are unique among all saveable system nodes (§3.1): hill_requests 80, Phase 9 81–84.
	var orders := {80: "hill_requests", 81: "quests", 82: "who_knows", 83: "letters", 84: "stranger"}
	for spec: Array in Phase10Fixtures.SAVEABLES:
		assert_false(orders.has(spec[2]), "save_order %d unique" % spec[2])
		orders[spec[2]] = spec[1]


func test_stubs_answer_neutral_defaults() -> void:
	var flags := GameState.flags.duplicate(true)
	GameState.clear_flag(&"p10_open")
	GameState.clear_flag(&"p10_open_day")
	GameState.clear_flag(&"market_stall_granted")
	var t := Treasury.new()
	assert_eq([t.is_open(), t.open_day(), t.last_schau(), t.pending_pay(), t.open_settlement(), t.due_day(), t.poor_box_coins()],
			[false, -1, {}, {}, {}, -1, 0])
	assert_eq(t.settlement("1834-12"), {})
	assert_false(t.pay_dues(null, &"mayor"))
	assert_false(t.check_goal())
	assert_eq(t.goal_progress(), {"settled": false, "market_days": 0, "best_tier": &""})
	assert_eq(t.empty_poor_box(null), 0)
	assert_false(t.give_to_poor_box(null))
	t.free()
	if not IMPLEMENTED.has("TreasuryRules"):
		assert_eq(TreasuryRules.parish_pay(&"venerable", 0.9, 0, 130, TreasuryConfig.new()),
				{"quality": 0, "need": 0, "hardship": 0, "total": 0})
		assert_eq([TreasuryRules.prorate(8, 16, 31), TreasuryRules.tithe(83, TreasuryConfig.new()),
				TreasuryRules.estimate(60, TreasuryConfig.new())], [0, 0, 0])
	var c := CashBook.new()
	assert_eq([c.open_day(), c.day_page(75), c.week_page(11), c.month_page("1834-12"), c.booked_income("1834-12", false),
			c.untracked_in("1834-12"), c.totals_since(75)], [-1, {}, {}, {}, 0, 0, {}])
	c.free()
	if not IMPLEMENTED.has("CashBookRules"):
		assert_eq([CashBookRules.source_of("Bestattung von Hedwig Rabenstein", CashBookConfig.new()),
				CashBookRules.untracked(5, 2, 1)], [&"other", 0])
	var m := Market.new()
	assert_eq([m.is_open(), m.market_day(), m.next_market(), m.lage(&"candles"), m.lage_all(), m.stall_granted()],
			[false, -1, -1, &"normal", {}, false])
	assert_eq([m.stall_offers(&"ms_agathe"), m.sell_tick(), m.take_down(null), m.stall_goods(), m.sold_on(79)],
			[[] as Array[Dictionary], [] as Array[Dictionary], {}, {}, {}])
	assert_false(m.buy(&"ms_agathe", &"rose_bush", 1, null))
	assert_false(m.set_up({}, {}, null))
	m.free()
	if not IMPLEMENTED.has("MarketRules"):
		assert_eq([MarketRules.is_market_day(79, MarketConfig.new()), MarketRules.group_state(79, &"candles", {}, MarketConfig.new())],
				[false, &"normal"])
	if not IMPLEMENTED.has("WishlistProbe"):
		assert_eq(WishlistProbe.open_cost(tree, Phase10Fixtures.wishlist()), 0)
	GameState.flags = flags


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 6, "§3.3: 6 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – everything over [E], dialogues and panels; the cash book over [J].
	for action: String in ["interact", "ui_cancel", "journal_page_prev", "journal_page_next"]:
		assert_true(InputMap.has_action(action), action)


func test_new_config_contract_values() -> void:
	var t := TreasuryConfig.new()
	assert_eq([t.schau_weekday, t.schau_minute, t.pay_weekday, t.pay_minute, t.pay_fallback_chest], [6, 1080, 0, 460, &"hut_chest"])
	assert_eq(t.tier_pay, {&"neglected": 0, &"orderly": 4, &"tended": 7, &"dignified": 10, &"venerable": 12})
	assert_eq(t.tier_pay.keys(), CemeteryRating.TIERS, "one pay per cemetery tier")
	assert_eq(Array(t.care_steps), [0.5, 0.75, 0.95])
	assert_eq([t.disturbed_malus, t.quality_cap, t.need_threshold, t.need_divisor, t.need_cap, t.hardship_floor, t.hardship_cap],
			[1, 15, 60, 4, 15, 10, 8])
	assert_eq([t.settle_minute, t.due_days, t.waive_after_months, t.rent, t.rent_flag], [360, 6, 1, 8, &"bruch_license"])
	assert_eq([t.tithe_percent, t.tithe_cap, t.levy_flag, t.estimate_percent, t.estimate_min_untracked, t.estimate_cap],
			[10, 25, &"village_open", 10, 20, 15])
	assert_eq([t.poor_box_max, t.poor_box_give, t.open_flag, t.open_day_flag, t.unlock_flag], [30, 1, &"p10_open", &"p10_open_day",
			&"who_knows_when_complete"])
	assert_eq([t.chapter_id, t.goal_flag, t.goal_market_days, t.goal_min_tier, t.prepaid_rent_months], [&"debit_credit",
			&"debit_credit_complete", 2, &"dignified", 2])
	assert_eq(Database.config(&"workshop_config").get(&"license_flag"), t.rent_flag, "the lease letter = the quarry letter")
	var c := CashBookConfig.new()
	assert_eq([c.keep_days, c.check_every_minutes, c.sources, c.purpose_labels, c.untracked_label], [62, 60, {}, {}, "ohne Beleg"])
	var m := MarketConfig.new()
	assert_eq([m.open_flag, m.weekday, m.window, m.setup_from, m.stalls_visible, m.notice_weekday, m.notice_minute],
			[&"village_open", 5, Vector2i(480, 750), 450, Vector2i(390, 810), 3, 464])
	assert_eq([m.stall_flag, m.stall_fee, m.stall_slots, m.tick_minutes, m.setup_minutes, m.takedown_minutes],
			[&"market_stall_granted", 1, 6, 30, 10, 5])
	assert_eq(m.states, {&"scarce": {"price": 1.3, "demand": 1.5}, &"normal": {"price": 1.0, "demand": 1.0},
			&"glut": {"price": 0.75, "demand": 0.6}})
	assert_eq(Array(m.state_weights), [0.25, 0.5, 0.25])
	assert_eq(m.tags, {&"cheap": {"price": 0.8, "demand": 1.4}, &"fair": {"price": 1.0, "demand": 1.0},
			&"dear": {"price": 1.25, "demand": 0.6}})
	assert_eq(m.tags.keys(), Market.TAGS)
	assert_eq(m.states.keys(), Market.STATES)
	assert_eq([m.groups, m.season_rules, m.rep_demand, m.piety_demand], [{}, [], {}, {}], "§3.4 class defaults")
	assert_eq([m.mourning_deaths, m.mourning_groups, m.oversold_threshold, m.peddler_group, m.leftover_chest],
			[3, [&"candles", &"grave_goods"] as Array[StringName], 6, &"pantry", &"hut_chest"])
	var o := MarketOfferData.new()
	assert_eq([o.item, o.price, o.stock, o.weight, o.requires_flag, o.conditions], [&"", 1, 1, 1.0, &"", PackedStringArray()])
	var s := MarketStallData.new()
	assert_eq([s.id, s.npc_id, s.place, s.title, s.offers, s.picks, s.buys_groups], [&"", &"", &"", "",
			[] as Array[MarketOfferData], 4, [] as Array[StringName]])
	var w := MarketWareData.new()
	assert_eq([w.item, w.group, w.value, w.demand, w.lines], [&"", &"", 1.0, 1, {}])
	var e := WishlistEntryData.new()
	assert_eq([e.id, e.kind, e.ref, e.coins, e.available_flag, e.max_count], [&"", &"", &"", 0, &"", 1])
	assert_eq(WishlistEntryData.KINDS, [&"station", &"building", &"tool", &"item", &"per_grave"] as Array[StringName])
	assert_eq(WishlistData.new().entries, [] as Array[WishlistEntryData])


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase10Fixtures.CONFIG_NAMES + Phase10Fixtures.EXTENDED_CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase10Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		var defaults: Resource = (real.get_script() as GDScript).new()
		var changed: Array = DATA_CHANGED_AFTER_W0.get(name, [])
		var tables: Array = Phase10Fixtures.DATA_TABLES.get(name, [])
		var new_config := name in Phase10Fixtures.CONFIG_NAMES
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if StringName(prop.name) in changed:
					assert_eq(real.get(prop.name), defaults.get(prop.name), "%s.%s (changed) = class default" % [name, prop.name])
					continue
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
				if new_config and not StringName(prop.name) in tables:
					assert_eq(defaults.get(prop.name), fixture.get(prop.name), "%s.%s = class default" % [name, prop.name])


func test_extended_data_classes() -> void:
	var rep := ReputationConfig.new().event_points
	assert_eq([rep.get(&"dues_paid"), rep.get(&"estimated")], [1, -1], "§2.10 reputation")
	assert_false(rep.has(&"market_stall"), "§2.10: the market gives no reputation")
	assert_eq(rep.get(&"case_reported"), 3, "the Phase-9 events stay")
	var piety := PietyConfig.new().events
	assert_eq([piety.get(&"poor_box_give"), piety.get(&"rose_planted")], [1, 1], "§2.10 piety")
	assert_eq(piety.get(&"postage_paid"), 1, "the Phase-9 events stay")
	var gains := RelationshipConfig.new().gains
	assert_eq([gains.get(&"dues_paid_fenner"), gains.get(&"market_buy"), gains.get(&"market_sale_kin")], [2, 1, 1], "§2.10 gains")
	assert_eq(gains.get(&"seal_broken"), -3, "the Phase-9 gains stay")
	var reactions := NpcLifeConfig.new().reactions
	assert_eq(reactions.get(&"market_lage"), 1, "§3.2: market_lage 1 day")
	assert_eq(reactions.get(&"register_sold"), 2, "the Phase-9 reactions stay")
	var v := VisitorConfig.new()
	assert_eq([v.poor_box_coin, v.poor_box_cap_day], [1, 2], "§3.2 / §2.5.8")
	assert_eq(v.tip_cap_day, 4, "W0: the tip cap stays (P1 sets 3 in W1, §2.4.1 E11)")
	var r := ReputationConfig.new()
	assert_eq([Array(r.stipend), r.stipend_purse_cap], [[0, 1, 2, 3, 4], 80], "W0: the stipend stays (P1/P2 set 0 in W1, E1)")


func test_game_state_stats_and_coin_reasons() -> void:
	assert_eq(SaveMigration.V9_NEW_STATS.size(), 23, "§2.10: 23 stats")
	for key: StringName in SaveMigration.V9_NEW_STATS:
		assert_true(key in GameState.DEFAULT_STATS, "§2.10 stat %s" % key)
	var p9_end := GameState.DEFAULT_STATS.find(&"coins_spent_post")
	assert_eq(GameState.DEFAULT_STATS.slice(p9_end + 1), SaveMigration.V9_NEW_STATS, "Phase-10 stats appended")
	assert_eq(GameState.COIN_REASONS.slice(GameState.COIN_REASONS.size() - 4), [&"market", &"rent", &"tax", &"stall"]
			as Array[StringName], "§2.10 coin purposes")
	for reason: StringName in [&"market", &"rent", &"tax", &"stall"]:
		assert_true(GameState.coin_ledger_stat(reason) in SaveMigration.V9_NEW_STATS, String(reason))
	var labels := Phase10Fixtures.cash_book_config().purpose_labels
	for reason: StringName in GameState.COIN_REASONS:
		assert_true(labels.has(reason), "cash book purpose label for %s" % reason)


## §2.6 W0 check: every income reason text of the G9 code (and the new Phase-10 texts) maps to exactly one source.
func test_cash_book_sources_cover_the_reason_texts() -> void:
	var cfg := Phase10Fixtures.cash_book_config()
	var lines := Database.ghost_lines() as GhostLines
	var samples := {
		Graveyard.PAYMENT_REASON % "Hedwig Rabenstein": &"burial",
		ChapelRites.fee_text(5): &"service", ChapelRites.fee_text(1): &"service",
		Ossuary.REASON_FEE % "Kaspar Dorn": &"reinter",
		Reputation.REASON_STIPEND: &"parish",
		Orders.REASON_ORDER % "Holunderbeeren": &"order",
		HillRules.REASON % "Ein Kreuz für Lenz": &"request", HillRules.REASON_HALF % "Die Fährgräber": &"request",
		Letters.REASON_ANSWER_COIN: &"errand",
		Visitors.PAYMENT_REASON: &"tip",
		lines.gift: &"gift",
		VillageShops.PAYMENT_REASON: &"shop_sale", VillageShops.PAYMENT_REASON_PEDDLER: &"shop_sale",
		Specimens.REASON_SALE % "Herz": &"specimen",
		Lectures.REASON_FEE: &"lecture",
		CollectionShelf.FORMAT_PAYMENT % "Hand": &"collection",
		Stranger.REASON_SALE: &"stranger", Stranger.REASON_ANSWER: &"stranger", Stranger.REASON: &"stranger",
		# §2.10 new reasons.
		"Friedhofsgeld": &"parish", "Bedarfszulage der Gemeinde": &"need", "Notgroschen der Gemeinde": &"need",
		"Spenden aus dem Opferstock": &"donation_in", "Verkauf am Marktstand": &"market_sale",
	}
	for coins: int in lines.gift_by_coins:
		samples[lines.gift_by_coins[coins]] = &"gift"
	samples[Wanderers.PAYMENT_REASON] = &"shop_sale"
	for text: String in samples:
		var hits: Array[StringName] = []
		for source: StringName in cfg.sources:
			for prefix: String in (cfg.sources[source].get("prefixes", PackedStringArray()) as PackedStringArray):
				if text.begins_with(prefix) and not hits.has(source):
					hits.append(source)
		assert_eq(hits, [samples[text]] as Array[StringName], "„%s“ → %s" % [text, samples[text]])
	# §2.5.6: receipted = burial, service, reinter, order, request, errand, shops, market; „ohne Beleg" for the estimate =
	# specimen, lecture, collection, night, stranger.
	var receipt: Array[StringName] = []
	var estimate: Array[StringName] = []
	for source: StringName in cfg.sources:
		var spec: Dictionary = cfg.sources[source]
		assert_true(spec.has("label") and spec.has("prefixes") and spec.has("receipt") and spec.has("estimate"), String(source))
		if bool(spec.receipt):
			receipt.append(source)
		if bool(spec.estimate):
			estimate.append(source)
		assert_false(bool(spec.receipt) and bool(spec.estimate), "%s: never both" % source)
	assert_eq(_sorted_names(receipt), PackedStringArray(["burial", "errand", "market_sale", "order", "reinter", "request",
			"service", "shop_sale"]))
	assert_eq(_sorted_names(estimate), PackedStringArray(["collection", "lecture", "night", "specimen", "stranger"]))
	assert_eq(cfg.sources.size(), 19, "§2.6: 19 sources incl. other")


func test_market_tables_and_fixtures() -> void:
	var cfg := Phase10Fixtures.market_config()
	assert_eq(_sorted_names(cfg.groups.keys()), _sorted_names(Phase10Fixtures.GROUP_IDS), "§2.7.3: six ware groups")
	var seen := {}
	for g: StringName in cfg.groups:
		for item: String in cfg.groups[g]:
			assert_false(seen.has(item), "%s in one group only" % item)
			seen[item] = g
			assert_true(Database.has_item(StringName(item)) or StringName(item) in Phase10Fixtures.ITEM_IDS, "item %s" % item)
	assert_eq(cfg.season_rules, [{"months": PackedInt32Array([12, 1, 2]), "group": &"wood_iron", "step": 1}] as Array[Dictionary])
	for tier: StringName in cfg.rep_demand:
		assert_true(tier in ReputationRules.TIERS, String(tier))
	for tier: StringName in cfg.piety_demand:
		assert_true(tier in PietyRules.TIERS, String(tier))
	var picks := {&"ms_agathe": [5, 12], &"ms_kehr": [4, 7], &"ms_brandt": [4, 6]}
	for s: MarketStallData in Phase10Fixtures.market_stalls():
		assert_not_null(s)
		if s == null:
			continue
		assert_eq([s.picks, s.offers.size()], picks[s.id], "§2.7.4 %s: picks of the pool" % s.id)
		assert_true(s.title != "" and s.npc_id != &"" and not s.buys_groups.is_empty(), String(s.id))
		for g: StringName in s.buys_groups:
			assert_true(cfg.groups.has(g), "%s buys %s" % [s.id, g])
		for o: MarketOfferData in s.offers:
			assert_true(o.price >= 1 and o.stock >= 1, "%s: %s" % [s.id, o.item])
			assert_true(Database.has_item(o.item) or o.item in Phase10Fixtures.ITEM_IDS, "%s: item %s" % [s.id, o.item])
	var agathe := Phase10Fixtures.market_stall(&"ms_agathe")
	var rose := agathe.offers.filter(func(o: MarketOfferData) -> bool: return o.item == &"rose_bush")
	assert_eq([rose.size(), (rose[0] as MarketOfferData).price], [1, 12], "A11: rose bush 12")
	var mortsafe := agathe.offers.filter(func(o: MarketOfferData) -> bool: return o.item == &"mortsafe")
	assert_eq((mortsafe[0] as MarketOfferData).requires_flag, &"robber_known", "the used mortsafe only with robber_known")
	var values := {&"wooden_cross": [4.0, 2], &"herbs": [1.0, 6], &"herb_bundle": [3.0, 3], &"grave_candle": [1.0, 8],
			&"wax_wreath": [6.0, 2]}
	for w: MarketWareData in Phase10Fixtures.market_wares():
		assert_not_null(w)
		if w == null:
			continue
		assert_eq([w.value, w.demand], values[w.item], "§2.7.5 %s" % w.item)
		assert_eq(StringName(str(seen.get(String(w.item), ""))), w.group, "%s in its group" % w.item)
		assert_true(Database.has_item(w.item), "ware %s is an item" % w.item)
	assert_eq(Phase10Fixtures.market_ware(&"wooden_cross").lines.get(&"kin_brandt"),
			"Für den Feldrain. Und für später. Man soll vorsorgen.")


func test_item_recipe_decor_wishlist_fixtures() -> void:
	var rose := Phase10Fixtures.item(&"rose_bush")
	var lantern := Phase10Fixtures.item(&"brass_lantern")
	assert_eq([rose.id, rose.category, rose.max_stack], [&"rose_bush", ItemData.Category.MATERIAL, 4], "§2.8")
	assert_eq([lantern.id, lantern.category, lantern.max_stack], [&"brass_lantern", ItemData.Category.DECOR, 4], "§2.8")
	for item: ItemData in [rose, lantern]:
		assert_true(item.display_name != "" and item.description.length() >= 20, String(item.id))
		assert_false(Database.has_item(item.id), "%s comes with P4 (W1)" % item.id)
	var candles := Phase10Fixtures.recipe(&"grave_candle_poured")
	assert_eq([candles.inputs, candles.output_id, candles.output_amount, candles.craft_minutes, candles.station, candles.requires_flag],
			[{&"beeswax": 1, &"yarn": 1}, &"grave_candle", 4, 20, &"workbench", &"village_open"])
	var wreath := Phase10Fixtures.recipe(&"wax_wreath_bound")
	assert_eq([wreath.inputs, wreath.output_id, wreath.output_amount, wreath.craft_minutes], [{&"beeswax": 2, &"juniper": 1, &"yarn": 1},
			&"wax_wreath", 1, 25])
	for r: RecipeData in [candles, wreath]:
		for id: StringName in r.inputs:
			assert_true(Database.has_item(id), "%s: input %s" % [r.id, id])
		assert_null(Database.recipe(r.id), "%s comes with P4 (W1)" % r.id)
	var decor := Phase10Fixtures.brass_lantern_decor()
	assert_eq([decor.id, decor.zier], [&"brass_lantern", (Database.decor(&"decor_lantern") as DecorData).zier + 1], "Zier +1")
	var wish := Phase10Fixtures.wishlist()
	assert_true(wish.entries.size() >= 5, "a sample wish list")
	for e: WishlistEntryData in wish.entries:
		assert_true(e.kind in WishlistEntryData.KINDS and e.coins > 0 and e.max_count >= 1, String(e.id))
		if e.kind == &"station":
			assert_not_null(Database.station(e.ref), "%s: station %s" % [e.id, e.ref])
		else:
			assert_true(Database.has_item(e.ref) or e.ref in Phase10Fixtures.ITEM_IDS, "%s: item %s" % [e.id, e.ref])


func test_fixture_helpers() -> void:
	var flags := GameState.flags.duplicate(true)
	var day := TimeManager.day
	var minute := TimeManager.minute_of_day
	var t := Phase10Fixtures.p10_open(null, 75)
	assert_true(t.is_open())
	assert_eq(t.open_day(), 75)
	assert_true(GameState.has_flag(&"who_knows_when_complete"))
	t.free()
	t = Phase10Fixtures.schau_done(11)
	assert_eq(t.last_schau().get("week"), 11)
	assert_eq([int(t.pending_pay().get("day")), int(t.pending_pay().get("quality"))], [80, 14], "§5.1 example: day 80, quality 14")
	assert_eq(CalendarRules.weekday(Phase10Fixtures.schau_day(11)), CalendarRules.SUNDAY)
	t.free()
	t = Phase10Fixtures.settlement_due()
	assert_eq([t.open_settlement().get("month"), int(t.open_settlement().get("total")), t.due_day()], ["1834-12", 13, 66])
	assert_eq(StringName(str(t.settlement("1834-12").get("state"))), Treasury.STATE_DUE)
	t.free()
	t = Phase10Fixtures.deferred("1835-01")
	assert_eq([StringName(str(t.open_settlement().get("state"))), t.due_day()], [Treasury.STATE_DEFERRED, 97])
	t.free()
	t = Phase10Fixtures.poor_box(12)
	assert_eq(t.poor_box_coins(), 12)
	t.free()
	t = Phase10Fixtures.poor_box(99)
	assert_eq(t.poor_box_coins(), 30, "clamped to poor_box_max")
	t.free()
	var m := Phase10Fixtures.market_day()
	assert_eq([CalendarRules.weekday(TimeManager.day), TimeManager.minute_of_day, m.stall_granted()], [CalendarRules.SATURDAY,
			480, true])
	m.free()
	m = Phase10Fixtures.stall_with({&"grave_candle": 6, &"wax_wreath": 2}, {&"grave_candle": &"dear"}, 2)
	assert_eq(m.stall_goods(), {"grave_candle": 6, "wax_wreath": 2})
	m.free()
	var c := Phase10Fixtures.cash_day(75, {&"request": 1, &"tip": 2}, {&"village": 8, &"apprentice": 3})
	assert_eq(c.open_day(), 75)
	assert_eq(c.day_page(75), {"in": {&"request": 1, &"tip": 2}, "out": {&"village": 8, &"apprentice": 3}, "untracked": 0})
	assert_eq([c.booked_income("1834-12", false), c.booked_income("1834-12", true), c.untracked_in("1834-12")], [3, 1, 0],
			"receipted: the request, not the tip")
	c.free()
	GameState.flags = flags
	TimeManager.set_time(day, minute)
	assert_false(Phase10Fixtures.layout_p9().is_empty(), "layout_p9.json readable")
	assert_eq(str(Phase10Fixtures.village_layout_p9().get("region_id", "")), "village")


func test_layout_fixtures_are_byte_identical_to_the_phase9_layouts() -> void:
	# Taken at f024103 (W0). W-Welt changes data/world in W2; then only the fixture stays.
	assert_true(FileAccess.get_file_as_bytes(Phase10Fixtures.LAYOUT_P9).size() > 1000)
	var layout := Phase10Fixtures.layout_p9()
	assert_true(layout.has("plots") and layout.has("sections"), "graveyard plots and sections")
	assert_true(JSON.stringify(layout.plots).contains('"l_16"'), "Phase 9: row 4 in the layout")
	assert_false(JSON.stringify(layout).contains("poor_box_gate"), "the offering box comes with W-Welt (W2)")
	assert_false(JSON.stringify(Phase10Fixtures.village_layout_p9()).contains("ms_agathe"), "the stands come with W-Welt (W2)")


func test_database_phase10_folders() -> void:
	# The real data folders are the owners' (P4 stands and wares, P1 the wish list) – empty until W1.
	for list: Array in [Database.market_stalls(), Database.market_wares()]:
		for res: Resource in list:
			assert_true(res != null, "loaded")
	assert_null(Database.market_stall(&"nope"))
	assert_null(Database.market_ware(&"nope"))
	var wish := Database.wishlist()
	assert_true(wish == null or wish is WishlistData, "data/economy/wishlist.tres (P1) or nothing yet")
	for name: StringName in Phase10Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	var ids: Array = Database.market_stalls().map(func(s: Resource) -> String: return String(s.get(&"id")))
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted, "stands sorted by id")


func test_save_format_v9_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 9)
	assert_eq(SaveFileIO.FORMAT_VERSION, 9)
	assert_eq(SaveManager.FORMAT_VERSION, 9)
	assert_eq(SaveMigration.V9_EMPTY_NODES, PackedStringArray(["treasury", "cash_book", "market"]), "§3.4 / §5.2 step 1")
	var state := {"autoloads": {"TimeManager": {"day": 75}, "GameState": {"stats": {"coins_spent": 4}, "flags": {"bruch_license": true}}},
			"nodes": {"player": {"inventory": {"slots": [{"id": "coin", "count": 132}]}}, "hut_chest": {"slots": []}}}
	assert_eq(SaveMigration.migrate(state, 9), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 10), {}, "newer → corrupt")
	var v9 := SaveMigration.migrate_8_to_9(state, {"day": 75})
	assert_false(is_same(v9, state), "deep copy")
	assert_false((state.nodes as Dictionary).has("treasury"), "input unchanged")
	for id: String in SaveMigration.V9_EMPTY_NODES:
		assert_eq(v9.nodes.get(id), {}, "§5.2 step 1: %s" % id)
	for key: StringName in SaveMigration.V9_NEW_STATS:
		assert_eq(v9.autoloads.GameState.stats.get(String(key)), 0, "§5.2 step 2: %s" % key)
	assert_eq(v9.autoloads.GameState.stats.coins_spent, 4)
	assert_eq(v9.autoloads.GameState.flags, {"bruch_license": true}, "§5.2 step 2: no flags; step 5: the lease letter stays")
	assert_eq(v9.nodes.player, state.nodes.player, "§5.2 step 3: coins and inventories unchanged")
	assert_eq(v9.nodes.hut_chest, state.nodes.hut_chest, "§5.2 step 3: chests unchanged")
	assert_eq(SaveMigration.migrate_8_to_9(v9, {}), v9, "idempotent")
	var from_v1 := SaveMigration.migrate({"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}},
			"nodes": {}}, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("quests")
			and (from_v1.nodes as Dictionary).has("treasury"), "v1 → … → v9 chain")
	# SaveManager drops the empty Phase-10 nodes while the world has none of them (like V3–V8).
	var nodes := {"treasury": {}, "cash_book": {}, "market": {}}
	assert_eq(SaveManager.without_absent_defaults(tree, nodes), {}, "absent empty Phase-10 nodes dropped")


func test_save_v8_fixtures_exist() -> void:
	assert_eq(Phase10Fixtures.SAVES_V8.size(), 7, "§5.3: six new v8 fixtures + slot_p9_mid_h4")
	for name: String in Phase10Fixtures.SAVES_V8:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase10Fixtures.save_v8_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 8, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


# --- helpers ----------------------------------------------------------------------------------

func _assert_arity(path: String, method: String, args: int, label: String) -> void:
	var script := load(path) as GDScript
	var found := false
	for m: Dictionary in script.get_script_method_list():
		if String(m.name) == method:
			found = true
			assert_eq((m.args as Array).size(), args, "%s.%s arguments" % [label, method])
	assert_true(found, "%s.%s" % [label, method])


static func _sorted_names(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in list:
		out.append(str(v))
	out.sort()
	return out


func _global_classes() -> Dictionary:
	var global := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		global[String(entry["class"])] = String(entry["path"])
	return global


func _methods(script: GDScript) -> Dictionary:
	var names := {}
	for m: Dictionary in script.get_script_method_list():
		names[String(m.name)] = true
	return names


func _path_of(cls: String) -> String:
	if DATA_CLASSES.has(cls):
		return DATA_CLASSES[cls]
	for path: String in STUBS:
		if STUBS[path] == cls:
			return path
	return ""
