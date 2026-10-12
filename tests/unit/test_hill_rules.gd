extends TestCase
## G8 Runde 6 „Bitten vom Hügel" (docs/PHASE8_DESIGN.md G8 Runde 6 §1–§2, §6): the pure rules (places and limits
## before / after the village, offer conditions, the deterministic pick, deadlines, completion checks, reward words),
## the config data and the pool (≥ 14 requests, all solvable with the means of days 2–13, a giver from the village,
## German texts, small rewards).

const LAYOUT := "res://data/world/graveyard_layout.json"
## Means of days 2–13 (no village shops, no workyard parts): what a delivery may ask for.
const EARLY_ITEMS: Array[StringName] = [&"wood", &"stone", &"wooden_cross", &"gravestone_simple", &"shroud"]
const EARLY_DECOR: Array[StringName] = [&"decor_grave_vase", &"decor_bench_wood", &"decor_bench_stone", &"decor_lantern"]
const EARLY_SECTIONS: Array[StringName] = [&"east", &"north", &"elder"]
const GIVERS: Array[StringName] = [&"carter", &"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer",
		&"kin_kehr", &"kin_brandt", &"kin_ott", &"kin_sieber"]


func _cfg() -> HillRequestsConfig:
	return Database.config(&"hill_requests_config") as HillRequestsConfig


func _req(kind: StringName, conditions: Dictionary = {}, id: StringName = &"hr_test", giver: StringName = &"smith") -> OrderData:
	var r := OrderData.new()
	r.id = id
	r.giver = giver
	r.kind = kind
	r.category = OrderData.CATEGORY_HILL
	r.title = "Test"
	r.conditions = conditions
	r.days_limit = 2
	r.cooldown_days = 6
	r.reward_coins = 3
	r.reward_rep = 1
	return r


func _ctx(more: Dictionary = {}) -> Dictionary:
	var ctx := {"day": 2, "village": false, "on_board": [], "givers": [], "ended": {}, "levels": {}, "dirty_graves": [],
			"free_plots": 3, "marked": 1, "items": [], "open_obstacles": {&"east": 4}}
	ctx.merge(more, true)
	return ctx


# --- config -------------------------------------------------------------------------------------

func test_config_data() -> void:
	var cfg := _cfg()
	assert_not_null(cfg, "data/config/hill_requests_config.tres")
	assert_eq(cfg.start_day, 2, "from day 2")
	assert_eq(cfg.post_minute, 464, "Osric pins at 07:44")
	assert_eq([cfg.slots_early, cfg.max_active_early, cfg.refill_days_early], [2, 2, 1], "before the village: 2 places, 2 at once, next morning")
	assert_eq([cfg.slots_village, cfg.max_active_village], [1, 1], "after village_open: one place")
	assert_true(cfg.refill_days_village > cfg.refill_days_early, "longer refill after village_open")
	assert_true(cfg.fail_rep <= 0 and cfg.fail_rep >= -2, "a missed request costs (nearly) nothing (%d)" % cfg.fail_rep)
	assert_eq(cfg.village_flag, &"village_open")
	var fresh := HillRequestsConfig.new()
	for p: String in ["start_day", "post_minute", "refresh_minute", "slots_early", "max_active_early", "refill_days_early",
			"slots_village", "max_active_village", "refill_days_village", "offer_days", "fail_rep", "village_flag", "log_size"]:
		assert_eq(cfg.get(p), fresh.get(p), "data == class default: " + p)


func test_places_and_limits() -> void:
	var cfg := _cfg()
	assert_eq(HillRules.slots(cfg, false), 2)
	assert_eq(HillRules.slots(cfg, true), 1)
	assert_eq(HillRules.max_active(cfg, false), 2)
	assert_eq(HillRules.max_active(cfg, true), 1)
	assert_eq(HillRules.refill_days(cfg, false), 1)
	assert_eq(HillRules.refill_days(cfg, true), 3)
	assert_eq(HillRules.accept_block(&"offered", 0, cfg, false), "")
	assert_eq(HillRules.accept_block(&"offered", 1, cfg, false), "", "two at once before the village")
	assert_eq(HillRules.accept_block(&"offered", 2, cfg, false), HillRules.TEXT_MAX_ACTIVE % 2)
	assert_eq(HillRules.accept_block(&"offered", 1, cfg, true), HillRules.TEXT_MAX_ACTIVE_ONE, "one after village_open")
	assert_eq(HillRules.accept_block(&"accepted", 0, cfg, false), HillRules.TEXT_ACCEPTED)
	assert_eq(HillRules.accept_block(&"", 0, cfg, false), HillRules.TEXT_NOT_ON_BOARD)


# --- offer conditions ---------------------------------------------------------------------------

func test_offer_block_common_rules() -> void:
	var r := _req(&"ghost")
	assert_eq(HillRules.offer_block(r, _ctx()), "")
	assert_eq(HillRules.offer_block(r, _ctx({"on_board": [&"hr_test"]})), "on board")
	assert_eq(HillRules.offer_block(r, _ctx({"givers": [&"smith"]})), "giver on board", "never two of one giver at once")
	assert_eq(HillRules.offer_block(r, _ctx({"ended": {&"hr_test": 1}, "day": 6})), "cooldown", "cooldown from its end")
	assert_eq(HillRules.offer_block(r, _ctx({"ended": {&"hr_test": 1}, "day": 7})), "", "after cooldown_days")
	var early := _req(&"ghost", {"phase": "early"})
	assert_eq(HillRules.offer_block(early, _ctx({"village": true})), "early only")
	var late := _req(&"ghost", {"phase": "village"})
	assert_eq(HillRules.offer_block(late, _ctx()), "village only")
	var later := _req(&"ghost", {"min_day": 3})
	assert_eq(HillRules.offer_block(later, _ctx()), "too early")
	assert_eq(HillRules.offer_block(later, _ctx({"day": 3})), "")
	var order := _req(&"ghost")
	order.category = &""
	assert_eq(HillRules.offer_block(order, _ctx()), "no request", "an order of Orders is no request")
	assert_eq(HillRules.offer_block(_req(&"dance"), _ctx()), "unknown kind")


func test_offer_block_by_kind() -> void:
	var tend := _req(&"tend", {"spots": ["dirt_y01", "dirt_y02"]})
	assert_eq(HillRules.offer_block(tend, _ctx({"levels": {"dirt_y01": 0, "dirt_y02": 0}})), "clean")
	assert_eq(HillRules.offer_block(tend, _ctx({"levels": {"dirt_y01": 1, "dirt_y02": 0}})), "")
	var grave := _req(&"tend", {"grave": "marked_dirty"})
	assert_eq(HillRules.offer_block(grave, _ctx()), "no dirty grave")
	assert_eq(HillRules.offer_block(grave, _ctx({"dirty_graves": ["plot_02"]})), "")
	var leaves := _req(&"tend", {"spots": ["dirt_y09"], "requires_item": "rake"})
	assert_eq(HillRules.offer_block(leaves, _ctx({"levels": {"dirt_y09": 2}})), "item", "leaves only with a rake")
	assert_eq(HillRules.offer_block(leaves, _ctx({"levels": {"dirt_y09": 2}, "items": [&"rake"]})), "")
	for kind: StringName in HillRules.CORPSE_KINDS:
		assert_eq(HillRules.offer_block(_req(kind), _ctx({"free_plots": 0})), "no plot", "%s needs a corpse still to come" % kind)
		assert_eq(HillRules.offer_block(_req(kind), _ctx()), "", kind)
	assert_eq(HillRules.offer_block(_req(&"ghost"), _ctx({"marked": 0})), "no ghost")
	var clear := _req(&"clear", {"sections": ["east", "north"]})
	assert_eq(HillRules.offer_block(clear, _ctx({"open_obstacles": {&"east": 0}})), "nothing to clear")
	assert_eq(HillRules.offer_block(clear, _ctx({"open_obstacles": {&"north": 2}})), "")
	assert_eq(HillRules.offer_block(_req(&"deliver"), _ctx()), "")
	assert_eq(HillRules.offer_block(_req(&"decor"), _ctx()), "")


func test_pick_is_deterministic_and_respects_the_rules() -> void:
	var pool: Array = []
	for i: int in 6:
		pool.append(_req(&"ghost", {}, StringName("hr_p%d" % i), StringName("giver_%d" % i)))
	var a := HillRules.pick(pool, _ctx({"day": 5}), 0)
	assert_ne(a, &"")
	assert_eq(HillRules.pick(pool, _ctx({"day": 5}), 0), a, "same day, same place → same request")
	var other := HillRules.pick(pool, _ctx({"day": 5, "on_board": [a]}), 1)
	assert_ne(other, a, "never the one already on the board")
	var days := {}
	for d: int in range(2, 14):
		days[HillRules.pick(pool, _ctx({"day": d}), 0)] = true
	assert_true(days.size() >= 3, "the pick varies over the days (%d)" % days.size())
	var ended := {}
	for r: OrderData in pool:
		ended[r.id] = 4
	assert_eq(HillRules.pick(pool, _ctx({"day": 5, "ended": ended}), 0), &"", "all cooling down → none")
	assert_eq(HillRules.pick_grave(["plot_01", "plot_02"], 3), HillRules.pick_grave(["plot_02", "plot_01"], 3), "grave pick order-free")


# --- deadlines and completion --------------------------------------------------------------------

func test_deadline() -> void:
	var r := _req(&"ghost")
	r.days_limit = 2
	assert_eq(HillRules.deadline_day(r, 3), 5, "accepted on day 3 with two days → due at 06:00 of day 5")
	r.days_limit = 0
	assert_eq(HillRules.deadline_day(r, 3), 4, "at least one day")
	assert_eq(HillRules.days_left(5, 3), 2)
	assert_eq(HillRules.days_left(5, 4), 1)
	assert_eq(HillRules.days_left(5, 9), 0)


func test_completion_checks() -> void:
	var spots := PackedStringArray(["dirt_y01", "dirt_y02"])
	assert_false(HillRules.tend_done(spots, {"dirt_y01": 0, "dirt_y02": 0}, false), "nothing tended since the acceptance")
	assert_false(HillRules.tend_done(spots, {"dirt_y01": 0, "dirt_y02": 1}, true), "one spot still dirty")
	assert_true(HillRules.tend_done(spots, {"dirt_y01": 0, "dirt_y02": 0}, true))
	assert_eq(HillRules.spots_of(_req(&"tend", {"grave": "marked_dirty"}), "plot_04"), PackedStringArray(["dirt_plot_04"]))
	var prep := _req(&"prep", {"washed": true, "dressed": true})
	var rec := CorpseRecord.new()
	assert_false(HillRules.prep_ok(prep, rec))
	rec.washed = true
	assert_false(HillRules.prep_ok(prep, rec), "washed, not dressed")
	rec.dress = CorpseRecord.DRESS_SHROUD
	assert_true(HillRules.prep_ok(prep, rec))
	var laid := _req(&"prep", {"washed": true, "dressed": true, "laid_out": true})
	assert_false(HillRules.prep_ok(laid, rec), "not laid out")
	rec.laid_out = true
	assert_true(HillRules.prep_ok(laid, rec))
	var marker := _req(&"marker", {"marker": "gravestone_simple"})
	var g := GraveRecord.new()
	g.state = GraveRecord.State.MARKED
	g.marker_id = &"wooden_cross"
	assert_false(HillRules.marker_ok(marker, g), "a cross is no stone")
	g.marker_id = &"gravestone_simple"
	assert_true(HillRules.marker_ok(marker, g))
	assert_true(HillRules.decor_ok(_req(&"decor", {"decor": ["decor_grave_vase"]}), &"decor_grave_vase"))
	assert_false(HillRules.decor_ok(_req(&"decor", {"decor": ["decor_grave_vase"]}), &"decor_lantern"))
	assert_true(HillRules.clear_ok(_req(&"clear", {"sections": ["east"]}), &"east"))
	assert_false(HillRules.clear_ok(_req(&"clear", {"sections": ["east"]}), &"linden"))
	var deliver := _req(&"deliver")
	deliver.items = {&"wood": 3} as Dictionary[StringName, int]
	var inv := Inventory.new()
	inv.slot_count = 8
	inv.add_item(&"wood", 2)
	assert_false(HillRules.deliver_ready(deliver, inv))
	inv.add_item(&"wood", 1)
	assert_true(HillRules.deliver_ready(deliver, inv))
	assert_eq(HillRules.recipient(deliver), &"carter", "deliveries go to Osric")
	inv.free()


func test_reward_words() -> void:
	var r := _req(&"ghost", {"reward_items": {"linen": 1}})
	assert_eq(HillRules.reward_parts(r), PackedStringArray(["3 Münzen", "Ruf +1", "1× Leinen"]))
	assert_eq(HillTexts.reward_note("Test", HillRules.reward_parts(r)), "Bitte erfüllt: Test – 3 Münzen · Ruf +1 · 1× Leinen")
	assert_eq(HillTexts.posted(1), "Osric hat eine Bitte ans Tor geheftet.")
	assert_eq(HillTexts.posted(2), "Osric hat zwei Bitten ans Tor geheftet.")
	assert_eq(HillTexts.deadline(2, -1), "Frist: 2 Tage")
	assert_eq(HillTexts.deadline(2, 2), "noch 2 Tage")
	assert_eq(HillTexts.deadline(2, 1), "heute der letzte Tag")
	assert_eq(HillRules.giver_name(&"carter"), "Osric Faulhaber")
	assert_eq(HillRules.giver_name(&"surgeon"), "Severin Quast")
	assert_eq(HillRules.giver_name(&"kin_kehr"), "Martha Kehr")
	assert_eq(HillRules.fill("Das Grab von %s", "Anna"), "Das Grab von Anna")
	assert_eq(HillRules.fill("Ohne Platzhalter", "Anna"), "Ohne Platzhalter")


# --- the pool -----------------------------------------------------------------------------------

func test_pool_size_kinds_and_givers() -> void:
	var pool := Database.hill_requests()
	assert_true(pool.size() >= 14 and pool.size() <= 24, "14–18 requests (%d)" % pool.size())
	var kinds := {}
	var givers := {}
	for raw: Variant in pool:
		var r := raw as OrderData
		assert_not_null(r)
		assert_eq(r.category, OrderData.CATEGORY_HILL, "%s category hill" % r.id)
		assert_true(r.kind in HillRules.KINDS, "%s kind %s" % [r.id, r.kind])
		assert_true(r.giver in GIVERS, "%s: a giver from the village (%s)" % [r.id, r.giver])
		assert_ne(HillRules.giver_name(r.giver), String(r.giver), "%s: the giver has a name" % r.id)
		kinds[r.kind] = true
		givers[r.giver] = true
		assert_true(Database.order_data(r.id) == null, "%s is no order of data/orders" % r.id)
	assert_eq(kinds.size(), HillRules.KINDS.size(), "every kind in the pool (%s)" % str(kinds.keys()))
	for v: StringName in [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer"]:
		assert_true(givers.has(v), "the seven villagers ask: %s" % v)
	assert_true(givers.has(&"carter"), "Osric asks too")
	assert_true(givers.keys().any(func(g: StringName) -> bool: return String(g).begins_with("kin_")), "mourners ask too")


func test_pool_values_are_small_and_bounded() -> void:
	for raw: Variant in Database.hill_requests():
		var r := raw as OrderData
		assert_true(r.days_limit >= 1 and r.days_limit <= 3, "%s: deadline 1–3 days (%d)" % [r.id, r.days_limit])
		assert_true(r.reward_coins >= 1 and r.reward_coins <= 3, "%s: a few coins (%d)" % [r.id, r.reward_coins])
		assert_true(r.reward_rep >= 1 and r.reward_rep <= 2, "%s: a little reputation (%d)" % [r.id, r.reward_rep])
		assert_eq(r.reward_rel, 0, "%s: no relationship points (Phase-7 tiers untouched)" % r.id)
		assert_true(r.cooldown_days >= 5, "%s: cooldown ≥ 5 days (%d)" % [r.id, r.cooldown_days])
		var items := HillRules.reward_items(r)
		assert_true(items.size() <= 1, "%s: at most one small thing" % r.id)
		for item: StringName in items:
			assert_true(Database.has_item(item), "%s: reward item %s exists" % [r.id, item])
			assert_true(items[item] == 1, "%s: one %s" % [r.id, item])


func test_pool_is_solvable_with_the_early_means() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var spot_ids := {}
	for s: Dictionary in layout.dirt_spots:
		spot_ids[str(s.id)] = true
	for raw: Variant in Database.hill_requests():
		var r := raw as OrderData
		match r.kind:
			HillRules.KIND_DELIVER:
				assert_false(r.items.is_empty(), "%s: items" % r.id)
				for item: StringName in r.items:
					assert_true(item in EARLY_ITEMS, "%s: %s comes from the hill (wood, stone, the workbench)" % [r.id, item])
					assert_true(int(r.items[item]) >= 1 and int(r.items[item]) <= 4, "%s: a small amount" % r.id)
				assert_eq(HillRules.recipient(r), &"carter", "%s: handed over at Osric's cart" % r.id)
			HillRules.KIND_TEND:
				if str(r.conditions.get("grave", "")) != HillRules.GRAVE_MARKED_DIRTY:
					var spots := HillRules.spots_of(r)
					assert_false(spots.is_empty(), "%s: spots" % r.id)
					for s: String in spots:
						assert_true(spot_ids.has(s), "%s: care spot %s in the layout" % [r.id, s])
			HillRules.KIND_CLEAR:
				for s: String in HillRules.sections_of(r):
					assert_true(StringName(s) in EARLY_SECTIONS, "%s: an early section (%s)" % [r.id, s])
			HillRules.KIND_DECOR:
				var decor: Variant = r.conditions.get("decor", [])
				for d: Variant in decor:
					assert_true(StringName(str(d)) in EARLY_DECOR, "%s: decor of the workbench (%s)" % [r.id, d])
					assert_not_null(Database.recipe(StringName(str(d))), "%s: %s has a recipe" % [r.id, d])
			HillRules.KIND_MARKER:
				var m := StringName(str(r.conditions.get("marker", "")))
				assert_true(m == &"" or Database.recipe(m) != null, "%s: marker %s from the workbench" % [r.id, m])
		assert_eq(r.requires_flag, &"", "%s: no flag of a later phase" % r.id)


func test_pool_texts() -> void:
	for raw: Variant in Database.hill_requests():
		var r := raw as OrderData
		assert_true(r.title.length() >= 8 and r.title.length() <= 40, "%s: a short title (%s)" % [r.id, r.title])
		assert_true(r.request_text.length() >= 60, "%s: a request text" % r.id)
		assert_true(r.thanks_text.length() >= 30, "%s: a thanks text" % r.id)
		assert_true(r.request_text.count("%s") <= 1 and r.thanks_text.count("%s") <= 1, "%s: at most one placeholder" % r.id)
		for word: String in ["Quest", "XP", "Level"]:
			assert_false(r.request_text.contains(word) or r.title.contains(word), "%s: no game words (%s)" % [r.id, word])
