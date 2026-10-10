extends TestCase
## P7 (docs/PHASE8_DESIGN.md §2.6.2, §2.11, W0 note 10, §10): the Phase-8 items and shops – the 10 items, Hanne's
## Kiepe (prices, stock per visit day over both stands, purchases into the ledger peddler, selling to her pays
## „Verkauf an Hanne", no relationship discounts, a load refills nothing), Theres' and Esch's additions (the
## mortsafe only from robber_known, 12 then 8 after Esch's second step).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const ITEMS := {
	&"flower_seedlings": ItemData.Category.MATERIAL, &"grave_candle": ItemData.Category.MATERIAL,
	&"watering_can": ItemData.Category.TOOL, &"apprentice_rake": ItemData.Category.TOOL, &"mortsafe": ItemData.Category.GOODS,
	&"wax_wreath": ItemData.Category.GOODS, &"register_extract": ItemData.Category.GOODS,
	&"memorial_plate": ItemData.Category.CRAFTED, &"quast_crate": ItemData.Category.GOODS, &"lorenz_ledger_2": ItemData.Category.GOODS,
}

var shops: VillageShops
var wanderers: Wanderers
var inv: Inventory
var payments: Array = []
var spent: Array = []


func before_each() -> void:
	GameState.reset()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)
	GameState.add_stat(&"reputation", 70)
	TimeManager.load_state({"day": 55, "minute_of_day": 700})
	wanderers = Wanderers.new()
	tree.root.add_child(wanderers)
	shops = VillageShops.new()
	tree.root.add_child(shops)
	inv = FakeInventory.new()
	inv.add_item(&"coin", 100)
	payments.clear()
	spent.clear()
	EventBus.payment_received.connect(_on_payment)
	EventBus.coins_spent.connect(_on_spent)


func after_each() -> void:
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.coins_spent.disconnect(_on_spent)
	shops.queue_free()
	wanderers.queue_free()
	await wait_frames(1)
	GameState.reset()


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])


func test_phase8_items() -> void:
	for id: StringName in ITEMS:
		var item := Database.item(id) as ItemData
		assert_not_null(item, String(id))
		if item == null:
			continue
		assert_eq(item.category, ITEMS[id], String(id))
		assert_eq(item.display_name, Phase8Fixtures.item(id).display_name, String(id))
		assert_true(item.description.length() >= 20, String(id))
	assert_eq((Database.item(&"mortsafe") as ItemData).max_stack, 4)
	assert_eq((Database.item(&"flower_seedlings") as ItemData).max_stack, 10)


func test_shop_data_match_the_contract() -> void:
	for id: StringName in Phase8Fixtures.SHOP_IDS:
		var real := Database.shop(id) as ShopData
		var fixture := Phase8Fixtures.shop(id)
		assert_eq(real.sells, fixture.sells, "%s sells" % id)
		assert_eq(real.buys, fixture.buys, "%s buys" % id)
		assert_eq(real.coin_reason, fixture.coin_reason, String(id))
	var hanne := Database.shop(&"peddler") as ShopData
	var prices := {}
	for item: StringName in hanne.sells:
		prices[item] = [int(hanne.sells[item].price), int(hanne.sells[item].per_day)]
	assert_eq(prices, {&"flower_seedlings": [2, 6], &"grave_candle": [1, 8], &"watering_can": [4, 1], &"wax_wreath": [5, 1],
			&"gold_leaf": [6, 1], &"ink": [2, 3]}, "§2.6.2")
	assert_eq(hanne.coin_reason, &"peddler")


func test_hanne_sells_only_at_her_stands_with_one_stock() -> void:
	assert_true(shops.is_open(&"peddler"), "10:00–14:00 at the well")
	assert_eq(shops.sell_price(&"peddler", &"grave_candle"), 1)
	assert_true(shops.buy(&"peddler", &"grave_candle", 5, inv))
	assert_eq(spent, [[5, &"peddler"]], "the ledger peddler")
	assert_eq(GameState.get_stat(&"coins_spent_peddler"), 5)
	TimeManager.load_state({"day": 55, "minute_of_day": 900})
	assert_false(shops.is_open(&"peddler"), "on the way")
	assert_eq(shops.buy_block_reason(&"peddler", &"grave_candle", 1, inv), VillageShops.TEXT_CLOSED)
	TimeManager.load_state({"day": 55, "minute_of_day": 950})
	assert_true(shops.is_open(&"peddler"), "15:40–16:20 at the gate")
	assert_eq(shops.stock_left(&"peddler", &"grave_candle"), 3, "the stock of the whole day over both stands")
	var saved := shops.save_state()
	shops.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(shops.stock_left(&"peddler", &"grave_candle"), 3, "a load refills nothing")
	assert_false(shops.buy(&"peddler", &"grave_candle", 4, inv))
	TimeManager.load_state({"day": 56, "minute_of_day": 700})
	assert_false(shops.is_open(&"peddler"), "not her day")


func test_selling_to_hanne() -> void:
	inv.add_item(&"yarn", 8)
	assert_eq(shops.sell(&"peddler", &"yarn", 6, inv), 6)
	assert_eq(payments, [[6, "Verkauf an Hanne"]])
	assert_eq(shops.sell_block_reason(&"peddler", &"yarn", 1, inv), ShopRules.TEXT_ENOUGH, "at most 6 a visit")
	assert_eq(shops.buy_price(&"peddler", &"wound_salve"), 4)


func test_esch_mortsafe_from_robber_known() -> void:
	var smith := Database.shop(&"smith") as ShopData
	shops.shop_data = {&"smith": smith}
	var ids: Array = []
	for o: Dictionary in shops.offers(&"smith"):
		ids.append(o.item)
	assert_false(ids.has(&"mortsafe"), "not before robber_known")
	assert_true(ids.has(&"watering_can") and ids.has(&"apprentice_rake"))
	assert_eq(ShopRules.buy_block_reason(smith, &"mortsafe", 1, 2, inv, 12, &""), ShopRules.TEXT_NOT_SOLD)
	GameState.set_flag(&"robber_known", true)
	ids.clear()
	for o: Dictionary in shops.offers(&"smith"):
		ids.append(o.item)
	assert_true(ids.has(&"mortsafe"))
	assert_eq(ShopRules.row_price_now(smith.sells[&"mortsafe"]), 12)
	GameState.set_flag(&"friend_smith_2", true)
	assert_eq(ShopRules.row_price_now(smith.sells[&"mortsafe"]), 8, "after Esch's second step")


func test_theres_sells_seedlings_and_candles() -> void:
	var grocer := Database.shop(&"grocer") as ShopData
	assert_eq([int(grocer.sells[&"flower_seedlings"].price), int(grocer.sells[&"flower_seedlings"].per_day)], [2, 4])
	assert_eq([int(grocer.sells[&"grave_candle"].price), int(grocer.sells[&"grave_candle"].per_day)], [1, 6])
