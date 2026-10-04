class_name RelationshipConfig
extends Resource
## Relationships 0…100 (docs/PHASE7_DESIGN.md §2.4, §3.4): data/config/relationship_config.tres.
## Tiers follow RelationshipRules.TIERS (stranger, acquainted, trusted, friend).

## Values at which acquainted / trusted / friend start.
@export var tier_thresholds: PackedInt32Array = [15, 40, 70]
## Relationship change per event (§2.4).
@export var gains: Dictionary[StringName, int] = {&"talk": 1, &"gift": 4, &"round": 2, &"donation": 1, &"order_failed": -4}
## Start bonus by reputation tier (disreputable … renowned) and – for piety_sensitive villagers –
## by piety tier (hardhearted … devout).
@export var rep_start_bonus: PackedInt32Array = [0, 2, 4, 6, 8]
@export var piety_start_bonus: PackedInt32Array = [-5, 0, 0, 3, 5]
## Shop prices (§2.3): −discount on goods from discount_min_price at discount_tier or higher;
## +surcharge per item at surcharge_rep_tier; buying from the player +friend_buy_bonus from
## friend_buy_min_price for a friend.
@export var discount_tier: StringName = &"trusted"
@export var discount: int = 1
@export var discount_min_price: int = 4
@export var surcharge_rep_tier: StringName = &"disreputable"
@export var surcharge: int = 1
@export var friend_buy_bonus: int = 1
@export var friend_buy_min_price: int = 3
