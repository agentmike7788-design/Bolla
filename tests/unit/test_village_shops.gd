extends TestCase
## P2 (docs/PHASE7_DESIGN.md §2.3, §3.4, §5.1, §10): ShopRules and VillageShops – prices (base,
## „Verrufen" +1, „Vertraut" −1 from 4, never < 1; buying from the player +1 from 3 for a friend), stock
## per day and the daily buying limit (reset at 06:00, never by loading), atomic trades (coins, room),
## is_open only while the villager stands at the shop spot, shop_trade, the coin ledger &"village",
## requires_tier and Esch's friend extra, the ShopCounter prompt. Shops and schedules from
## tests/fixtures/phase7, relationships through Phase7Fixtures.villager, the clock set directly.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false


var shops: VillageShops
var inv: Inventory
var rel: Relationships
var trades: Array = []
var payments: Array = []
var spent: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	GameState.stats[&"reputation"] = 40  # Geachtet
	_at(3, 600)
	shops = _make_shops()
	tree.root.add_child(shops)
	inv = FakeInventory.new()
	tree.root.add_child(inv)
	rel = null
	trades.clear()
	payments.clear()
	spent.clear()
	EventBus.shop_trade.connect(_on_trade)
	EventBus.payment_received.connect(_on_payment)
	EventBus.coins_spent.connect(_on_spent)


func after_each() -> void:
	EventBus.shop_trade.disconnect(_on_trade)
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.coins_spent.disconnect(_on_spent)
	shops.free()
	inv.free()
	if rel != null:
		rel.free()
	GameState.reset()
	TimeManager.reset()


func _make_shops() -> VillageShops:
	var s := VillageShops.new()
	s.config = Phase7Fixtures.relationship_config()
	for data: ShopData in Phase7Fixtures.shops():
		s.shop_data[data.id] = data
	for v: VillagerData in Phase7Fixtures.villagers():
		s.schedules[v.npc_id] = Phase7Fixtures.schedule(v.npc_id)
	return s


func _at(day: int, minute: int) -> void:
	TimeManager.day = day
	TimeManager.minute_of_day = minute


func _rel(npc: StringName, value: int) -> void:
	if rel != null:
		rel.free()
	rel = Phase7Fixtures.villager(npc, value, tree)


func _on_trade(shop_id: StringName, coins: int, sold: Dictionary, bought: Dictionary) -> void:
	trades.append([shop_id, coins, sold, bought])


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])


# --- rules ----------------------------------------------------------------------------------

func test_price_rules() -> void:
	var cfg := Phase7Fixtures.relationship_config()
	assert_eq(ShopRules.price(3, &"respected", &"stranger", cfg), 3, "base")
	assert_eq(ShopRules.price(3, &"disreputable", &"stranger", cfg), 4, "Verrufen +1")
	assert_eq(ShopRules.price(6, &"respected", &"trusted", cfg), 5, "Vertraut −1 from 4")
	assert_eq(ShopRules.price(4, &"renowned", &"friend", cfg), 3, "Befreundet counts as Vertraut or higher")
	assert_eq(ShopRules.price(3, &"respected", &"friend", cfg), 3, "no discount below 4")
	assert_eq(ShopRules.price(6, &"respected", &"acquainted", cfg), 6)
	assert_eq(ShopRules.price(4, &"disreputable", &"trusted", cfg), 4, "+1 −1")
	assert_eq(ShopRules.price(0, &"respected", &"stranger", cfg), 1, "never below 1")
	assert_eq(ShopRules.buy_price(3, &"friend", cfg), 4, "friend +1 from 3")
	assert_eq(ShopRules.buy_price(2, &"friend", cfg), 2)
	assert_eq(ShopRules.buy_price(6, &"trusted", cfg), 6)
	assert_eq(ShopRules.buy_price(0, &"stranger", cfg), 1)


func test_block_reasons() -> void:
	var grocer := Phase7Fixtures.shop(&"grocer")
	inv.add_item(&"coin", 5)
	assert_eq(ShopRules.buy_block_reason(grocer, &"iron_bar", 1, 5, inv, 3, &"stranger"), ShopRules.TEXT_NOT_SOLD)
	assert_eq(ShopRules.buy_block_reason(grocer, &"gold_leaf", 1, 1, inv, 6, &"trusted"), ShopRules.TEXT_TIER)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 0, 6, inv, 3, &"stranger"), ShopRules.TEXT_AMOUNT)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 1, 0, inv, 3, &"stranger"), ShopRules.TEXT_SOLD_OUT)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 3, 2, inv, 3, &"stranger"), ShopRules.FORMAT_STOCK % 2)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 2, 6, inv, 3, &"stranger"), ShopRules.TEXT_COINS)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 1, 6, inv, 3, &"stranger"), "")
	var full := FullInventory.new()
	full.add_item(&"coin", 9)
	assert_eq(ShopRules.buy_block_reason(grocer, &"linen", 1, 6, full, 3, &"stranger"), ShopRules.TEXT_ROOM)
	full.free()
	assert_eq(ShopRules.sell_block_reason(grocer, &"wood", 1, 5, inv), ShopRules.TEXT_NOT_BOUGHT)
	assert_eq(ShopRules.sell_block_reason(grocer, &"herbs", 1, 0, inv), ShopRules.TEXT_ENOUGH)
	assert_eq(ShopRules.sell_block_reason(grocer, &"herbs", 3, 2, inv), ShopRules.FORMAT_BOUGHT % 2)
	assert_eq(ShopRules.sell_block_reason(grocer, &"herbs", 1, 8, inv), ShopRules.TEXT_MISSING)
	inv.add_item(&"herbs", 1)
	assert_eq(ShopRules.sell_block_reason(grocer, &"herbs", 1, 8, inv), "")


# --- open, prices, offers -----------------------------------------------------------------

func test_open_only_at_the_shop_spot() -> void:
	# Theres: 07:25–14:00 and 14:35–18:00 at the window, 14:05–14:30 at the well, otherwise at home.
	var expect := {300: false, 444: false, 445: true, 600: true, 839: true, 842: false, 850: false, 875: true, 1079: true,
			1081: false}
	for minute: int in expect:
		_at(3, minute)
		assert_eq(shops.is_open(&"grocer"), expect[minute], "grocer at %d" % minute)
	_at(3, 850)
	inv.add_item(&"coin", 10)
	assert_false(shops.buy(&"grocer", &"linen", 1, inv), "closed")
	assert_eq(inv.count(&"coin"), 10)
	assert_eq(shops.offers(&"grocer")[0].block_reason, VillageShops.TEXT_CLOSED)
	assert_false(shops.is_open(&"nope"))
	# Esch: the anvil until 12:00, the inn at noon (talk only), the anvil again from 13:06.
	for minute: int in [500, 700]:
		_at(3, minute)
		assert_true(shops.is_open(&"smith"), "smith %d" % minute)
	_at(3, 750)
	assert_false(shops.is_open(&"smith"), "lunch in the inn")


func test_offers_and_wants_follow_reputation_and_relationship() -> void:
	var rows := shops.offers(&"grocer")
	assert_eq(rows.size(), 8)
	var by_item := {}
	for r: Dictionary in rows:
		by_item[r.item] = r
	assert_eq([by_item[&"linen"].price, by_item[&"linen"].stock_left, by_item[&"linen"].block_reason],
			[3, 6, ShopRules.TEXT_COINS], "no player inventory in the tree → no coins")
	assert_eq(by_item[&"gold_leaf"].block_reason, ShopRules.TEXT_TIER)
	assert_eq(shops.sell_price(&"grocer", &"gold_leaf"), 6)
	GameState.stats[&"reputation"] = 5
	assert_eq([shops.sell_price(&"grocer", &"linen"), shops.sell_price(&"grocer", &"gold_leaf")], [4, 7], "Verrufen +1")
	_rel(&"grocer", 45)
	assert_eq([shops.sell_price(&"grocer", &"linen"), shops.sell_price(&"grocer", &"gold_leaf")], [4, 6], "Vertraut −1 from 4")
	GameState.stats[&"reputation"] = 40
	assert_eq(shops.sell_price(&"grocer", &"gold_leaf"), 5)
	_rel(&"grocer", 75)
	assert_eq(shops.buy_block_reason(&"grocer", &"gold_leaf", 1, inv), ShopRules.TEXT_COINS, "a friend may buy gold leaf")
	var wants := shops.wants(&"grocer")
	assert_eq(wants.size(), 5)
	var w := {}
	for r: Dictionary in wants:
		w[r.item] = r
	assert_eq([w[&"herb_bundle"].price, w[&"herbs"].price, w[&"herbs"].bought_left, w[&"herbs"].held],
			[4, 1, 8, 0], "friend +1 from 3")
	assert_eq(shops.offers(&"nope"), [] as Array[Dictionary])


# --- buying -----------------------------------------------------------------------------------

func test_buy_atomic_with_ledger_and_signal() -> void:
	inv.add_item(&"coin", 10)
	assert_true(shops.buy(&"grocer", &"linen", 2, inv))
	assert_eq([inv.count(&"coin"), inv.count(&"linen")], [4, 2])
	assert_eq(shops.stock_left(&"grocer", &"linen"), 4)
	assert_eq(trades, [[&"grocer", -6, {}, {&"linen": 2}]])
	assert_eq(spent, [[6, &"village"]], "coins_spent(…, village)")
	assert_eq([GameState.get_stat(&"coins_spent"), GameState.get_stat(&"coins_spent_village")], [6, 6])
	assert_false(shops.buy(&"grocer", &"linen", 5, inv), "only 4 left")
	assert_false(shops.buy(&"grocer", &"linen", 2, inv), "not enough coins (6 > 4)")
	assert_eq([inv.count(&"coin"), inv.count(&"linen"), trades.size()], [4, 2, 1], "nothing changed")
	var full := FullInventory.new()
	full.add_item(&"coin", 10)
	assert_false(shops.buy(&"grocer", &"linen", 1, full), "no room")
	assert_eq(full.count(&"coin"), 10)
	full.free()
	_at(3, 500)
	assert_true(shops.buy(&"priest", &"altar_candle", 1, inv), "priest at the church door at 08:20")
	assert_eq(inv.count(&"coin"), 2)
	assert_false(shops.buy(&"grocer", &"linen", 0, inv))


func test_buying_never_changes_a_relationship() -> void:
	_rel(&"grocer", 20)
	inv.add_item(&"coin", 10)
	assert_true(shops.buy(&"grocer", &"linen", 1, inv))
	assert_eq(rel.value(&"grocer"), 20)


func test_stock_resets_at_six_not_by_loading() -> void:
	inv.add_item(&"coin", 50)
	assert_true(shops.buy(&"grocer", &"linen", 6, inv))
	assert_eq(shops.stock_left(&"grocer", &"linen"), 0)
	assert_false(shops.buy(&"grocer", &"linen", 1, inv), "sold out")
	var state := shops.save_state()
	assert_eq(state, {"stock_day": 3, "stock_left": {"grocer": {"linen": 0}}, "bought_left": {}}, "§5.1")
	var other := _make_shops()
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.stock_left(&"grocer", &"linen"), 0, "loading never refills")
	assert_eq(other.save_state(), state, "round trip")
	_at(3, 1439)
	assert_eq(other.stock_left(&"grocer", &"linen"), 0)
	_at(4, 359)
	assert_eq(other.stock_left(&"grocer", &"linen"), 0, "05:59 still the old day")
	_at(4, 360)
	assert_eq(other.stock_left(&"grocer", &"linen"), 6, "06:00 full again")
	assert_eq(other.stock_day(), 4)
	other.free()
	var fixture := Phase7Fixtures.shop_with({&"grocer": {&"linen": 1}}, 4)
	fixture.shop_data = shops.shop_data
	assert_eq(fixture.stock_left(&"grocer", &"linen"), 1, "Phase7Fixtures.shop_with")
	assert_eq(fixture.stock_left(&"grocer", &"seeds"), 6)
	fixture.free()
	shops.load_state({"stock_day": "x", "stock_left": [1], "bought_left": {"inn": {"herbs": "y"}}})
	assert_eq(shops.save_state(), {"stock_day": -1, "stock_left": {}, "bought_left": {"inn": {}}}, "tolerant")


# --- selling ----------------------------------------------------------------------------------

func test_sell_daily_limit_and_payment() -> void:
	inv.add_item(&"elderberries", 12)
	assert_eq(shops.sell(&"inn", &"elderberries", 4, inv), 8)
	assert_eq([inv.count(&"elderberries"), inv.count(&"coin")], [8, 8])
	assert_eq(payments, [[8, VillageShops.PAYMENT_REASON]])
	assert_eq(trades, [[&"inn", 8, {&"elderberries": 4}, {}]])
	assert_eq(shops.bought_left(&"inn", &"elderberries"), 6)
	assert_eq(shops.sell(&"inn", &"elderberries", 7, inv), 0, "only 6 more today")
	assert_eq(shops.sell_block_reason(&"inn", &"elderberries", 7, inv), ShopRules.FORMAT_BOUGHT % 6)
	assert_eq(shops.sell(&"inn", &"wood", 1, inv), 0, "not bought here")
	assert_eq(shops.sell(&"inn", &"herbs", 1, inv), 0, "none held")
	assert_eq(inv.count(&"coin"), 8, "nothing changed")
	assert_eq(GameState.get_stat(&"coins_spent"), 0, "income is no spending")
	_at(4, 360)
	assert_eq(shops.bought_left(&"inn", &"elderberries"), 10, "new day")
	_rel(&"innkeeper", 80)
	assert_eq(shops.buy_price(&"inn", &"elderberries"), 2, "friend: +1 only from 3")
	_rel(&"grocer", 80)
	_at(4, 600)
	inv.add_item(&"herb_bundle", 1)
	assert_eq(shops.sell(&"grocer", &"herb_bundle", 1, inv), 4, "friend +1 (3 → 4)")


# --- requires_tier, friend extra ------------------------------------------------------------

func test_requires_tier_and_friend_extra() -> void:
	inv.add_item(&"coin", 50)
	assert_false(shops.buy(&"grocer", &"gold_leaf", 1, inv), "only for a friend")
	_rel(&"grocer", 70)
	assert_true(shops.buy(&"grocer", &"gold_leaf", 1, inv))
	assert_eq(inv.count(&"coin"), 45, "6 − 1 (Vertraut or higher, from 4)")
	# Esch: steel rods 2 per day, +2 for a friend (data/shops/smith.tres friend_extra).
	shops.shop_data[&"smith"] = Database.shop(&"smith") as ShopData
	assert_eq(shops.stock_left(&"smith", &"steel_rod"), 2)
	_rel(&"smith", 70)
	assert_eq(shops.stock_left(&"smith", &"steel_rod"), 4, "friend +2")
	assert_true(shops.buy(&"smith", &"steel_rod", 3, inv))
	assert_eq(shops.stock_left(&"smith", &"steel_rod"), 1)
	_rel(&"smith", 50)
	assert_eq(shops.stock_left(&"smith", &"steel_rod"), 0, "no longer a friend: the extra is gone, never negative")
	assert_false(shops.buy(&"smith", &"steel_rod", 1, inv))


# --- counter, data ----------------------------------------------------------------------------

func test_shop_counter_prompt_only_while_open() -> void:
	var counter := (load("res://src/entities/shop_counter/shop_counter.tscn") as PackedScene).instantiate() as ShopCounter
	counter.shop_id = &"grocer"
	tree.root.add_child(counter)
	assert_true(counter.is_open())
	assert_eq(counter.get_interaction_prompt(null), ShopCounter.PROMPT)
	assert_false(counter.can_interact(null), "no player")
	_at(3, 300)
	assert_false(counter.is_open())
	assert_eq(counter.get_interaction_prompt(null), "")
	counter.shop_id = &"nope"
	_at(3, 600)
	assert_false(counter.is_open())
	counter.free()


func test_real_shop_data_matches_the_contract() -> void:
	assert_eq(Database.shops().size(), 7, "Phase 8 (P7): + Hanne's Kiepe (peddler)")
	for f: ShopData in Phase7Fixtures.shops():
		var s := Database.shop(f.id) as ShopData
		assert_not_null(s, String(f.id))
		if s == null:
			continue
		assert_eq([s.npc_id, s.coin_reason, s.buys], [f.npc_id, f.coin_reason, f.buys], String(f.id))
		# Phase 8 (P7, §2.11): Theres / Esch sell more – the keys follow the Phase-8 fixture where it has the shop.
		var p8 := Phase8Fixtures.shop(f.id) if f.id in Phase8Fixtures.SHOP_IDS else null
		assert_eq(s.sells.keys(), (p8 if p8 != null else f).sells.keys(), String(f.id))
		for item: StringName in f.sells:
			assert_eq([s.sells[item].price, s.sells[item].per_day, s.sells[item].get("requires_tier", &"")],
					[f.sells[item].price, f.sells[item].per_day, f.sells[item].get("requires_tier", &"")], "%s %s" % [f.id, item])
		for item: StringName in f.buys:
			assert_true(Database.has_item(item), "%s buys a known item %s" % [f.id, item])
		for item: StringName in f.sells:
			assert_true(Database.has_item(item), "%s sells a known item %s" % [f.id, item])
	assert_eq((Database.shop(&"smith") as ShopData).sells[&"steel_rod"].friend_extra, 2, "§2.3 +2 bei Befreundet")
	for v: VillagerData in Phase7Fixtures.villagers():
		if v.shop_id != &"":
			assert_eq((Database.shop(v.shop_id) as ShopData).npc_id, v.npc_id, String(v.shop_id))
