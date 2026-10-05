class_name VillageShops
extends Node
## Systems/VillageShops (docs/PHASE7_DESIGN.md §2.3, §3.1, §3.4, §5.1), groups &"village_shops",
## &"saveable": the six village shops after the pattern of Ilse's NightTrade (coins at once, stock per
## day, atomic). Buying never changes a relationship.
## - Open: the shop's villager stands at the shop spot – the village Npc (npc_id, region village):
##   present, talkable, not walking, schedule activity &"shop"; without such an Npc the same rule
##   straight from the schedule and the clock (`schedules`, else Database.schedule(npc_id)).
## - Prices: ShopRules.price (reputation tier, relationship tier to the shopkeeper) / buy_price.
## - Stock per day: resets every morning at 06:00 – derived from the clock when read (stock day =
##   TimeManager.day, before 06:00 the day before), so loading never refills it. A friend gets the
##   row's friend_extra on top (Esch: +2 steel rods).
## - Coins: buying → GameState.note_coins_spent(cost, ShopData.coin_reason); selling →
##   payment_received(coins, PAYMENT_REASON). Both emit shop_trade (coins positive = income).

const GROUP := &"village_shops"
const PAYMENT_REASON := "Verkauf im Dorf"
const COIN := &"coin"
const ACTIVITY_SHOP := &"shop"
const REGION_VILLAGE := &"village"
## Stock and the daily buying limit reset at this minute of day (06:00).
const RESET_MINUTE := 360
const TEXT_CLOSED := "Gerade steht niemand am Laden."
# Phase 8 (docs/PHASE8_DESIGN.md §2.6.2, §2.11, W0 note 10; P7): Hanne's shop opens by Wanderers.shop_open
# (her two stands), selling to her pays „Verkauf an Hanne"; rows with requires_flag (Esch's mortsafe from
# robber_known) are only offered with the flag, price_after_flag {flag, price} lowers the base price.
const WANDERERS_GROUP := &"wanderers"
const PAYMENT_REASON_PEDDLER := "Verkauf an Hanne"

@export var save_id: String = "village_shops"
@export var save_order: int = 52

## Rules; null = data/config/relationship_config.tres (resolved lazily).
var config: RelationshipConfig
## Tests / fallback presence: npc_id → NpcSchedule; empty = Database.schedule(npc_id).
var schedules: Dictionary[StringName, NpcSchedule] = {}
## Tests: shop_id → ShopData; empty = Database.shop(shop_id).
var shop_data: Dictionary[StringName, ShopData] = {}

## Stock day the stored counters belong to (-1 = none yet → full).
var _stock_day: int = -1
## shop_id → {item: left of the base per_day (may go below 0 by a friend's extra)}.
var _stock_left: Dictionary[StringName, Dictionary] = {}
## shop_id → {item: how many the shop still buys today}.
var _bought_left: Dictionary[StringName, Dictionary] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func shop(shop_id: StringName) -> ShopData:
	if not shop_data.is_empty():
		return shop_data.get(shop_id)
	return Database.shop(shop_id) as ShopData


## The Npc stands at the shop spot (ready to talk, not walking).
func is_open(shop_id: StringName) -> bool:
	var s := shop(shop_id)
	if s == null:
		return false
	var wanderers := _system(WANDERERS_GROUP)
	if wanderers != null and wanderers.has_method(&"has_shop") and bool(wanderers.call(&"has_shop", shop_id)):
		return bool(wanderers.call(&"shop_open", shop_id))
	var npc := npc_node(shop_id)
	if npc != null:
		return npc.is_present() and npc.is_talkable() and not npc.is_walking() and npc.entry != null \
				and npc.entry.activity == ACTIVITY_SHOP
	var sched := _schedule(s.npc_id)
	if sched == null or sched.entries.is_empty():
		return false
	var entry := ScheduleResolver.entry_at(sched, TimeManager.minute_of_day, TimeManager.day)
	return entry != null and entry.visible and entry.activity == ACTIVITY_SHOP and entry.dialogue_id != &"" \
			and ScheduleResolver.progress(entry, float(TimeManager.minute_of_day)) >= 1.0


## The village Npc of the shopkeeper (null = none in the tree).
func npc_node(shop_id: StringName) -> Npc:
	var s := shop(shop_id)
	if s == null or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == s.npc_id and npc.region_id == REGION_VILLAGE:
			return npc
	return null


## [{item, price, stock_left, block_reason}] (block reason for one piece).
func offers(shop_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := shop(shop_id)
	if s == null:
		return out
	var inv := _player_inventory()
	var rel := _rel_tier(s)
	var open := is_open(shop_id)
	for item: StringName in s.sells:
		if not ShopRules.row_available(s.sells[item]):
			continue
		var p := sell_price(shop_id, item)
		var left := stock_left(shop_id, item)
		var reason := TEXT_CLOSED if not open else ShopRules.buy_block_reason(s, item, 1, left, inv, p, rel)
		out.append({"item": item, "price": p, "stock_left": left, "block_reason": reason})
	return out


## [{item, price, bought_left, held, block_reason}] (block reason for one piece).
func wants(shop_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := shop(shop_id)
	if s == null:
		return out
	var inv := _player_inventory()
	var open := is_open(shop_id)
	for item: StringName in s.buys:
		var left := bought_left(shop_id, item)
		var reason := TEXT_CLOSED if not open else ShopRules.sell_block_reason(s, item, 1, left, inv)
		out.append({"item": item, "price": buy_price(shop_id, item), "bought_left": left,
				"held": inv.count(item) if inv != null else 0, "block_reason": reason})
	return out


## Unit price the player pays for `item` now (0 = not sold here).
func sell_price(shop_id: StringName, item: StringName) -> int:
	var s := shop(shop_id)
	if s == null or not s.sells.has(item):
		return 0
	return ShopRules.price(ShopRules.row_price_now(s.sells[item]), _rep_tier(), _rel_tier(s), _cfg())


## Unit price the shop pays the player for `item` now (0 = not bought here).
func buy_price(shop_id: StringName, item: StringName) -> int:
	var s := shop(shop_id)
	if s == null or not s.buys.has(item):
		return 0
	return ShopRules.buy_price(ShopRules.row_price(s.buys[item]), _rel_tier(s), _cfg())


## Pieces left today (per_day, + friend_extra for a friend).
func stock_left(shop_id: StringName, item: StringName) -> int:
	var s := shop(shop_id)
	if s == null or not s.sells.has(item):
		return 0
	var row: Dictionary = s.sells[item]
	var base := ShopRules.row_per_day(row, RelationshipRules.TIERS[0])
	var extra := ShopRules.row_per_day(row, _rel_tier(s)) - base
	return maxi(_stored(_stock_left, shop_id, item, base) + extra, 0)


## Pieces the shop still buys today.
func bought_left(shop_id: StringName, item: StringName) -> int:
	var s := shop(shop_id)
	if s == null or not s.buys.has(item):
		return 0
	return maxi(_stored(_bought_left, shop_id, item, ShopRules.row_per_day(s.buys[item], RelationshipRules.TIERS[0])), 0)


## "" or why `n` × `item` cannot be bought now (closed included).
func buy_block_reason(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> String:
	var s := shop(shop_id)
	if s != null and not is_open(shop_id):
		return TEXT_CLOSED
	return ShopRules.buy_block_reason(s, item, n, stock_left(shop_id, item), inv, sell_price(shop_id, item), _rel_tier(s))


## "" or why `n` × `item` cannot be sold now (closed included).
func sell_block_reason(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> String:
	var s := shop(shop_id)
	if s != null and not is_open(shop_id):
		return TEXT_CLOSED
	return ShopRules.sell_block_reason(s, item, n, bought_left(shop_id, item), inv)


## Atomic; note_coins_spent(cost, coin_reason); shop_trade.
func buy(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> bool:
	var s := shop(shop_id)
	if s == null or inv == null or buy_block_reason(shop_id, item, n, inv) != "":
		return false
	var cost := sell_price(shop_id, item) * n
	if cost > 0 and not inv.remove_item(COIN, cost):
		return false
	var rest := inv.add_item(item, n)
	if rest > 0:
		# can_add promised room – undo the whole trade rather than lose coins.
		inv.remove_item(item, n - rest)
		if cost > 0:
			inv.add_item(COIN, cost)
		return false
	_roll_day()
	_change(_stock_left, shop_id, item, ShopRules.row_per_day(s.sells[item], RelationshipRules.TIERS[0]), -n)
	GameState.note_coins_spent(cost, s.coin_reason)
	EventBus.shop_trade.emit(shop_id, -cost, {}, {item: n})
	return true


## Atomic; payment_received(…, PAYMENT_REASON); shop_trade; coins | 0.
func sell(shop_id: StringName, item: StringName, n: int, inv: Inventory) -> int:
	var s := shop(shop_id)
	if s == null or inv == null or sell_block_reason(shop_id, item, n, inv) != "":
		return 0
	var coins := buy_price(shop_id, item) * n
	if not inv.remove_item(item, n):
		return 0
	if coins > 0:
		inv.add_item(COIN, coins)
	_roll_day()
	_change(_bought_left, shop_id, item, ShopRules.row_per_day(s.buys[item], RelationshipRules.TIERS[0]), -n)
	if coins > 0:
		EventBus.payment_received.emit(coins, PAYMENT_REASON_PEDDLER if s.coin_reason == &"peddler" else PAYMENT_REASON)
	EventBus.shop_trade.emit(shop_id, coins, {item: n}, {})
	return coins


## Stock day of the clock: TimeManager.day, before 06:00 the day before.
func stock_day() -> int:
	return TimeManager.day if TimeManager.minute_of_day >= RESET_MINUTE else TimeManager.day - 1


## {stock_day, stock_left, bought_left}; a new day → full (derived).
func save_state() -> Dictionary:
	return {"stock_day": _stock_day, "stock_left": _out(_stock_left), "bought_left": _out(_bought_left)}


## Tolerant: damaged entries are dropped ({} = full stock).
func load_state(data: Dictionary) -> void:
	var day: Variant = data.get("stock_day")
	_stock_day = int(day) if day is int or day is float else -1
	_stock_left = _in(data.get("stock_left"))
	_bought_left = _in(data.get("bought_left"))


# --- internals ------------------------------------------------------------------------------

func _stored(table: Dictionary[StringName, Dictionary], shop_id: StringName, item: StringName, full: int) -> int:
	if _stock_day != stock_day():
		return full
	var row: Dictionary = table.get(shop_id, {})
	return int(row.get(item, full))


func _change(table: Dictionary[StringName, Dictionary], shop_id: StringName, item: StringName, full: int, delta: int) -> void:
	var row: Dictionary = table.get(shop_id, {})
	row[item] = int(row.get(item, full)) + delta
	table[shop_id] = row


## A new stock day: the counters start full again.
func _roll_day() -> void:
	var today := stock_day()
	if _stock_day == today:
		return
	_stock_day = today
	_stock_left.clear()
	_bought_left.clear()


func _schedule(npc_id: StringName) -> NpcSchedule:
	if schedules.has(npc_id):
		return schedules[npc_id]
	return Database.schedule(npc_id) as NpcSchedule


func _rel_tier(s: ShopData) -> StringName:
	var rel := _system(Relationships.GROUP) as Relationships
	if rel == null or s == null:
		return RelationshipRules.TIERS[0]
	return rel.tier(s.npc_id)


func _rep_tier() -> StringName:
	var rep := _system(&"reputation")
	if rep != null and rep.has_method(&"tier"):
		return rep.call(&"tier")
	return ReputationRules.tier(GameState.get_stat(&"reputation"), ReputationRules._cfg(null))


func _player_inventory() -> Inventory:
	var player := _system(&"player")
	if player == null:
		return null
	return player.get(&"inventory") as Inventory


func _system(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _cfg() -> RelationshipConfig:
	if config == null:
		config = RelationshipRules._cfg(null)
	return config


static func _out(table: Dictionary[StringName, Dictionary]) -> Dictionary:
	var out := {}
	for shop_id: StringName in table:
		var row := {}
		for item: Variant in table[shop_id]:
			row[str(item)] = int(table[shop_id][item])
		out[String(shop_id)] = row
	return out


static func _in(raw: Variant) -> Dictionary[StringName, Dictionary]:
	var out: Dictionary[StringName, Dictionary] = {}
	if not raw is Dictionary:
		return out
	for shop_id: Variant in raw:
		var src: Variant = (raw as Dictionary)[shop_id]
		if not src is Dictionary:
			continue
		var row := {}
		for item: Variant in src:
			var v: Variant = (src as Dictionary)[item]
			if v is int or v is float:
				row[StringName(str(item))] = clampi(int(v), -1000, 1000)
		out[StringName(str(shop_id))] = row
	return out
