class_name MarketOfferData
extends Resource
## One offer of a market stand's pool (docs/PHASE10_DESIGN.md §2.7.4, §3.4; sub-resource of MarketStallData.offers):
## the item, its base price (× market state, integer, never < 1), the stock per market, the draw weight, an optional
## flag and conditions (e.g. "!rel_tier:friend" for the gold leaf, "flag:robber_known" for the used mortsafe).

@export var item: StringName
@export var price: int = 1
@export var stock: int = 1
@export var weight: float = 1.0
@export var requires_flag: StringName = &""
@export var conditions: PackedStringArray = []
