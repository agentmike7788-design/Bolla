class_name RelationshipConfig
extends Resource
## Relationships 0…100 (docs/PHASE7_DESIGN.md §2.4, §3.4): data/config/relationship_config.tres.
## Tiers follow RelationshipRules.TIERS (stranger, acquainted, trusted, friend).

## Values at which acquainted / trusted / friend start.
@export var tier_thresholds: PackedInt32Array = [15, 40, 70]
## Relationship change per event (§2.4).
## Phase 8 §2.11 (+ 13): talk_cheerful, listen, danced, kathrein, wish_done_villager, friend_step_1/2/3,
## favor_returned, favor_unreturned, lights_all, jakob_scolded (Rosine), jakob_unpaid (Rosine).
## Phase 9 §2.9 (+ 11): witness, confided, letter_delivered, errand_done, named_publicly, large_request_village,
## case_reported_fenner, case_reported_quast, register_sold_lenz, register_sold_fenner, seal_broken.
@export var gains: Dictionary[StringName, int] = {&"talk": 1, &"gift": 4, &"round": 2, &"donation": 1, &"order_failed": -4,
		&"talk_cheerful": 2, &"listen": 3, &"danced": 3, &"kathrein": 2, &"wish_done_villager": 4, &"friend_step_1": 6,
		&"friend_step_2": 8, &"friend_step_3": 10, &"favor_returned": 4, &"favor_unreturned": -6, &"lights_all": 2,
		&"jakob_scolded": -1, &"jakob_unpaid": -2,
		&"witness": 2, &"confided": 4, &"letter_delivered": 3, &"errand_done": 2, &"named_publicly": -4, &"large_request_village": 3,
		&"case_reported_fenner": 4, &"case_reported_quast": -6, &"register_sold_lenz": -4, &"register_sold_fenner": -2, &"seal_broken": -3}
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
