class_name ShopRules
extends RefCounted
## STUB (P2) – pure shop rules (docs/PHASE7_DESIGN.md §2.3, §3.4): whole coins, never below 1;
## base · „Verrufen" +1 per item · relationship „Vertraut" or higher −1 on goods from 4 coins.
## Buying from the player: base, +1 from 3 coins for a friend. W1 (P2) fills the bodies; the
## signatures are the contract.


static func price(base: int, _rep_tier: StringName, _rel_tier: StringName, _cfg: RelationshipConfig) -> int:
	return base


static func buy_price(base: int, _rel_tier: StringName, _cfg: RelationshipConfig) -> int:
	return base


static func buy_block_reason(_shop: ShopData, _item: StringName, _n: int, _stock_left: int, _inv: Inventory, _price: int,
		_rel_tier: StringName) -> String:
	return ""


static func sell_block_reason(_shop: ShopData, _item: StringName, _n: int, _bought_left: int, _inv: Inventory) -> String:
	return ""
