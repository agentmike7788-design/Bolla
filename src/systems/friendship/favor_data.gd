class_name FavorData
extends Resource
## A favour and its return favour (docs/PHASE8_DESIGN.md §2.4 „Gefallen & Gegengefallen", §3.4):
## data/friendship/favors/<id>.tres. No favour costs or brings coins.

const EFFECTS: Array[StringName] = [&"rumor_shield", &"free_iron", &"order_ware", &"prayer", &"night_watch",
		&"free_medicine", &"corpse_wash"]

@export var id: StringName
@export var npc_id: StringName
@export var label: String
## rumor_shield | free_iron | order_ware | prayer | night_watch | free_medicine | corpse_wash.
@export var effect: StringName
## Effect parameters (items, days, choices …).
@export var params: Dictionary = {}
## Once per 5 days per person.
@export var cooldown_days: int = 5
## Return favour: a pool of friend orders (one chosen), offered the day after, 3 days to do it.
@export var return_orders: Array[StringName] = []
@export var return_after_days: int = 1
@export var return_days: int = 3
## Returned +4, not returned −6 and the favour rests 7 days.
@export var returned_rel: int = 4
@export var unreturned_rel: int = -6
@export var lock_days: int = 7
