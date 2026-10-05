class_name GraveCareConfig
extends Resource
## Grave flowers, candles, mortsafes, the disturbed grave (docs/PHASE8_DESIGN.md §1.3, §2.3, §3.4):
## data/config/grave_care_config.tres. The class defaults carry the contract values.

## Grave flowers: 15 minutes, fresh 2 days after the last watering, wilted until day 4, then gone.
@export var flower_item: StringName = &"flower_seedlings"
@export var plant_minutes: int = 15
@export var flower_fresh_minutes: int = 2880
@export var flower_wilt_minutes: int = 5760
## Watering 5 minutes; the can holds 6 fillings, the rain barrel refills it in 2 minutes.
@export var water_minutes: int = 5
@export var can_item: StringName = &"watering_can"
@export var can_fills: int = 6
@export var refill_minutes: int = 2
## The visitor's bouquet lasts 2 days; the wax wreath never wilts (ghost +0).
@export var bouquet_minutes: int = 2880
@export var wreath_item: StringName = &"wax_wreath"
## Grave candle: 3 minutes, from 15:00, burns until 07:00.
@export var candle_item: StringName = &"grave_candle"
@export var candle_minutes: int = 3
@export var candle_from_minute: int = 900
@export var candle_until_minute: int = 420
## Mortsafe: on 20 / off 10 minutes, removable after 10 days at the earliest.
@export var mortsafe_item: StringName = &"mortsafe"
@export var mortsafe_set_minutes: int = 20
@export var mortsafe_remove_minutes: int = 10
@export var mortsafe_min_days: int = 10
## Closing a disturbed grave 30 minutes (shovel factor); a new line on the stone 30 minutes, 1 ink.
@export var close_minutes: int = 30
@export var line_minutes: int = 30
@export var line_item: StringName = &"ink"
## Ghost mood: care ≤ +2, disturbed −3, a candle on the night of the lights +2.
@export var care_cap: int = 2
@export var disturbed_mood: int = -3
@export var lights_candle_mood: int = 2
