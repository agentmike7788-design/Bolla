class_name ShopRules
extends RefCounted
## Pure shop rules (docs/PHASE7_DESIGN.md §2.3, §3.4): whole coins, never below 1;
## base · „Verrufen" +1 per item · relationship „Vertraut" or higher −1 on goods from 4 coins (base).
## Buying from the player: base, +1 from 3 coins for a friend. No further haggling.
## ShopData rows: sells {item: {price, per_day, requires_tier?, friend_extra?}}, buys {item: {price, per_day}}.

const COIN := &"coin"
const TEXT_NOT_SOLD := "Das gibt es hier nicht."
const TEXT_TIER := "Das gibt es nur für gute Freunde."
const TEXT_AMOUNT := "Wie viele denn?"
const TEXT_SOLD_OUT := "Für heute ausverkauft."
const FORMAT_STOCK := "Nur noch %d da."
const TEXT_COINS := "Dafür reichen deine Münzen nicht."
const TEXT_ROOM := "Kein Platz im Gepäck."
const TEXT_NOT_BOUGHT := "Das braucht hier keiner."
const TEXT_ENOUGH := "Davon nimmt hier heute keiner mehr."
const FORMAT_BOUGHT := "Davon nur noch %d für heute."
const TEXT_MISSING := "Das hast du nicht dabei."


static func price(base: int, rep_tier: StringName, rel_tier: StringName, cfg: RelationshipConfig) -> int:
	var c := RelationshipRules._cfg(cfg)
	var p := base
	if rep_tier == c.surcharge_rep_tier:
		p += c.surcharge
	if RelationshipRules.at_least(rel_tier, c.discount_tier) and base >= c.discount_min_price:
		p -= c.discount
	return maxi(p, 1)


static func buy_price(base: int, rel_tier: StringName, cfg: RelationshipConfig) -> int:
	var c := RelationshipRules._cfg(cfg)
	var p := base
	if rel_tier == RelationshipRules.TIERS[3] and base >= c.friend_buy_min_price:
		p += c.friend_buy_bonus
	return maxi(p, 1)


## "" or why the player cannot buy `n` × `item` at the unit price `price` (the stock left today,
## requires_tier against `rel_tier`, coins, room).
static func buy_block_reason(shop: ShopData, item: StringName, n: int, stock_left: int, inv: Inventory, price: int,
		rel_tier: StringName) -> String:
	if shop == null or not shop.sells.has(item) or not row_available(shop.sells[item]):
		return TEXT_NOT_SOLD
	var need := StringName(str((shop.sells[item] as Dictionary).get("requires_tier", "")))
	if need != &"" and not RelationshipRules.at_least(rel_tier, need):
		return TEXT_TIER
	if n <= 0:
		return TEXT_AMOUNT
	if stock_left <= 0:
		return TEXT_SOLD_OUT
	if stock_left < n:
		return FORMAT_STOCK % stock_left
	if inv == null or inv.count(COIN) < price * n:
		return TEXT_COINS
	if not inv.can_add(item, n):
		return TEXT_ROOM
	return ""


## "" or why the player cannot sell `n` × `item` here (wanted, the amount left today, held).
static func sell_block_reason(shop: ShopData, item: StringName, n: int, bought_left: int, inv: Inventory) -> String:
	if shop == null or not shop.buys.has(item):
		return TEXT_NOT_BOUGHT
	if n <= 0:
		return TEXT_AMOUNT
	if bought_left <= 0:
		return TEXT_ENOUGH
	if bought_left < n:
		return FORMAT_BOUGHT % bought_left
	if inv == null or inv.count(item) < n:
		return TEXT_MISSING
	return ""


## Base price of a row ({price}); 0 if missing.
static func row_price(row: Dictionary) -> int:
	var v: Variant = row.get("price", 0)
	return int(v) if v is int or v is float else 0


## Phase 8 (W0 note 10; P7): a row with requires_flag is sold only while that GameState flag is on.
static func row_available(row: Dictionary) -> bool:
	var flag := StringName(str(row.get("requires_flag", "")))
	return flag == &"" or GameState.flag_on(flag)


## Phase 8: the base price now – price_after_flag {flag, price} replaces it while that flag is on (Esch's
## mortsafe 8 instead of 12 after his second story step).
static func row_price_now(row: Dictionary) -> int:
	var after: Variant = row.get("price_after_flag", {})
	if after is Dictionary and GameState.flag_on(StringName(str((after as Dictionary).get("flag", "")))):
		var p: Variant = (after as Dictionary).get("price", 0)
		if p is int or p is float:
			return int(p)
	return row_price(row)


## per_day of a row (+ friend_extra for a friend).
static func row_per_day(row: Dictionary, rel_tier: StringName) -> int:
	var v: Variant = row.get("per_day", 0)
	var n := int(v) if v is int or v is float else 0
	if rel_tier == RelationshipRules.TIERS[3]:
		var extra: Variant = row.get("friend_extra", 0)
		n += int(extra) if extra is int or extra is float else 0
	return maxi(n, 0)
