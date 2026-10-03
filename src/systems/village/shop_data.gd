class_name ShopData
extends Resource
## One village shop (docs/PHASE7_DESIGN.md §2.3, §3.4): data/shops/<id>.tres.

@export var id: StringName
## The villager who keeps the shop (VillagerData.npc_id).
@export var npc_id: StringName
@export var title: String = ""
## {item: {"price": int, "per_day": int, "requires_tier": StringName (optional)}}
@export var sells: Dictionary[StringName, Dictionary] = {}
## {item: {"price": int, "per_day": int}}
@export var buys: Dictionary[StringName, Dictionary] = {}
## EventBus.coins_spent reason of a purchase.
@export var coin_reason: StringName = &"village"
