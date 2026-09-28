class_name ChapelConfig
extends Resource
## The chapel – funeral service and devotion (docs/PHASE6_DESIGN.md §2.4):
## data/config/chapel_config.tres. Arrays by chapel level 0…3.

@export var service_minutes: int = 45
## The service starts between 08:00 and 17:00 (minute of the day).
@export var service_start_min: int = 480
@export var service_start_max: int = 1020
@export var candle_item: StringName = &"altar_candle"
@export var candle_amount: int = 1
@export var service_min_freshness: float = 0.3
@export var service_needs_dress: bool = true
@export var service_fee_by_level: PackedInt32Array = [0, 3, 5, 7]
@export var service_rep_by_level: PackedInt32Array = [0, 1, 2, 3]
@export var mourners_by_level: PackedInt32Array = [0, 0, 2, 4]
@export var devotion_minutes: int = 30
## Lasting ghost mood bonus of a devotion by chapel level (not summed – the highest counts).
@export var devotion_mood_by_level: PackedInt32Array = [0, 1, 2, 3]
## A robbed soul's mood is raised by a devotion at most to this value.
@export var devotion_robbed_cap: int = 8
@export var room_id: StringName = &"chapel"
