class_name MarketStallData
extends Resource
## A market stand (docs/PHASE10_DESIGN.md §2.7.4, §3.4): data/market/stalls/<id>.tres (P4).
## ms_agathe (Agathe Wendel, town goods, 5 of 12), ms_kehr (Martha Kehr, 4 of 7), ms_brandt (Hinrich Brandt, 4 of 6);
## `picks` offers are drawn per market from `offers`; `buys_groups` are what its people buy at the player's stand.

@export var id: StringName
@export var npc_id: StringName
@export var place: StringName
@export var title: String
@export var offers: Array[MarketOfferData] = []
@export var picks: int = 4
## Ware groups (MarketConfig.groups) its people buy at the player's own stand (customers).
@export var buys_groups: Array[StringName] = []
