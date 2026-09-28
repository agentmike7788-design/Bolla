class_name TraderConfig
extends Resource
## The night trader Ilse Kranich (docs/PHASE4_DESIGN.md §2.6): data/config/trader_config.tres.

## From this day, at the first minute ≥ intro_minute (06:00): the note at the hut door.
@export var intro_day: int = 4
@export var intro_minute: int = 360
## 22:45: "Jemand wartet an der Westmauer." (once per night).
@export var notice_minute: int = 1365
## Her small shop: item → {"price": coins, "per_night": stock}.
## Phase 5 §2.6 adds gold_leaf (6, 2 per night) – class default; data/config/trader_config.tres is P6's.
@export var shop: Dictionary[StringName, Dictionary] = {&"linen": {"price": 2, "per_night": 3}, &"juniper": {"price": 1, "per_night": 4}, &"gold_leaf": {"price": 6, "per_night": 2}}
## "Kanntest du den alten Totengräber?" after this many talks (different nights) or sales.
@export var lorenz_after_talks: int = 3
@export var lorenz_after_sales: int = 4
## Flag trader_rumor after this many sales.
@export var rumor_after_sales: int = 3
@export_multiline var intro_note: String = ""
## Greeting per piety tier (PietyRules.TIERS).
@export var greetings: Dictionary[StringName, String] = {}


func price(item_id: StringName) -> int:
	return int((shop.get(item_id, {}) as Dictionary).get("price", 0))


func per_night(item_id: StringName) -> int:
	return int((shop.get(item_id, {}) as Dictionary).get("per_night", 0))
