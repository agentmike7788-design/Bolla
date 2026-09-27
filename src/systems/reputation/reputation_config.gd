class_name ReputationConfig
extends Resource
## Reputation 0…100 (docs/PHASE3_DESIGN.md §2.6, §2.7): data/config/reputation_config.tres.
## Per-tier arrays follow ReputationRules.TIERS (disreputable … renowned).

@export var start_value: int = 25
@export var min_value: int = 0
@export var max_value: int = 100
## Values at which tiers 2…5 start (unremarkable 15, respected 35, esteemed 55, renowned 80).
@export var tier_thresholds: PackedInt32Array = [15, 35, 55, 80]
## Daily drift: target = clamp(target_base + round(target_per_quality × cemetery total));
## value += clamp(round((target − value) × drift_factor), −drift_max, +drift_max).
@export var target_base: int = 20
@export var target_per_quality: float = 0.6
@export var drift_factor: float = 0.34
@export var drift_max: int = 6
## Coins added to every burial payment, per tier.
@export var pay_bonus: PackedInt32Array = [-2, 0, 1, 2, 3]
## Daily stipend (coins at day_started), per tier.
@export var stipend: PackedInt32Array = [0, 1, 2, 3, 4]
## Corpses per day, per tier: one in every tier (user decision 27.09.2026, §14.2 – overrides
## the [1, 1, 1, 2, 2] of §3.4).
@export var deliveries_per_day: PackedInt32Array = [1, 1, 1, 1, 1]
## 1 = deliveries only on odd days in that tier.
@export var delivery_every_other_day: PackedInt32Array = [1, 0, 0, 0, 0]
## Phase 4 §2.8 adds hair_taken −3, teeth_taken −5, stench −2 (class default; the .tres is P3's).
@export var event_points: Dictionary[StringName, int] = {&"grave_good": 2, &"grave_poor": -3, &"missed_delivery": -4, &"marker_upgrade": 1, &"section_unlocked": 4, &"hair_taken": -3, &"teeth_taken": -5, &"stench": -2}
## A finished grave with quality ≥ grave_good_min → grave_good, ≤ grave_poor_max → grave_poor.
@export var grave_good_min: int = 8
@export var grave_poor_max: int = 3
