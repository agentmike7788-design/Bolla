class_name VillageConfig
extends Resource
## The village chapter (docs/PHASE7_DESIGN.md §1.2, §1.5, §2.9, §3.4): data/config/village_config.tres.

@export var unlock_flag: StringName = &"roof_and_earth_complete"
@export var open_flag: StringName = &"village_open"
## The first minute of the morning after unlock_flag at which the village opens (06:00).
@export var intro_minute: int = 360
## „Eine Runde für alle" in the Holderkrug: price, minutes.
@export var round_price: int = 5
@export var round_minutes: int = 15
## Poor box: coins per step, steps per day.
@export var donation_step: int = 5
@export var donation_steps_per_day: int = 2
## Consecration of the Lindenacker by the priest's relationship tier.
@export var consecration_price_by_tier: Dictionary[StringName, int] = {&"stranger": 10, &"acquainted": 10, &"trusted": 5, &"friend": 0}
@export var consecration_section: StringName = &"linden"
## Minute of the consecration day at which Village.consecrate runs (10:30).
@export var consecration_end_minute: int = 630
## Houses that can carry the mourning ribbon (deterministic from day and corpse seed).
@export var mourning_houses: PackedStringArray = ["house_kehr", "house_brandt", "house_ott", "house_sieber", "cottage_hagedorn", "cottage_dorn"]
## Chapter „Ein Name im Dorf" (§1.5).
@export var goal_orders: int = 6
@export var goal_givers: int = 4
@export var goal_trusted: int = 3
@export var goal_insight: StringName = &"i_deathbook"
@export var chapter_id: StringName = &"name_in_village"
@export var goal_flag: StringName = &"name_in_village_complete"
