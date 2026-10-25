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
## Coins added to every burial payment, per tier. Tarif Phase 10 (docs/PHASE10_DESIGN.md §2.4.1 E5, P1): „Gerühmt" +3 → +2.
@export var pay_bonus: PackedInt32Array = [-2, 0, 1, 2, 2]
## Daily stipend (coins at day_started), per tier. Tarif Phase 10 (§2.4.1 E1): → 0 together with the Friedhofsgeld
## (P2 merge: reputation.gd switches it off, the data follow) – without it the founder line stalls in Phase 5.
@export var stipend: PackedInt32Array = [0, 1, 2, 3, 4]
## G8 Runde 1 (E8-2, user decision „jetzt ausgleichen"): from stipend_cap_flag on (Phase 8 open) the Gemeinde pays the
## stipend only to a gravekeeper in need – with stipend_purse_cap coins or more (purse + the chests of the hut and
## Jakob's box with its wage tin) at the start of the day it stays in the parish chest. 0 = off. The tier values
## above (Phase 3) are unchanged.
@export var stipend_purse_cap: int = 80
@export var stipend_cap_flag: StringName = &"p8_open"
## Corpses per day, per tier: one in every tier (user decision 27.09.2026, §14.2 – overrides
## the [1, 1, 1, 2, 2] of §3.4).
@export var deliveries_per_day: PackedInt32Array = [1, 1, 1, 1, 1]
## 1 = deliveries only on odd days in that tier.
@export var delivery_every_other_day: PackedInt32Array = [1, 0, 0, 0, 0]
## Phase 4 §2.8 adds hair_taken −3, teeth_taken −5, stench −2; Phase 5 §2.7 master_stone +3
## (class default; the .tres is P4's in Phase 5); Phase 6 §2.7 reinterred +1 (the .tres is P4's);
## Phase 7 §2.11 organ_taken −3, organ_taken_grave −5 (eyes, hand), lecture_rumor −4, donation +1,
## order_failed −1 (class default; the .tres is P4's); Phase 8 §2.11 visit_pleased +1, visit_neglected −1,
## visit_disturbed −3, visit_noise −1, visit_specimen_rumor −1, wish_done +1, robber_reported +3, lights_all +3,
## lights_some +1, fenner_watch +1 (W0: class default and .tres; P2 owns them).
## Phase 9 §2.9 (+ 8): letter_delivered +1 (cap 1/day), large_request_done +2, large_request_failed −2, sent_away_rumor −2,
## kept_promise +1, public_duty +3, register_sold_rumor −1, case_reported +3 (W0: class default and .tres; P3 owns them).
## Phase 10 §2.10 (+ 2): dues_paid +1 (on time, once a month), estimated −1 (the estimate, once a month); the market
## gives none (W0: class default and .tres; P2 owns them).
@export var event_points: Dictionary[StringName, int] = {&"grave_good": 2, &"grave_poor": -3, &"missed_delivery": -4, &"marker_upgrade": 1, &"section_unlocked": 4, &"hair_taken": -3, &"teeth_taken": -5, &"stench": -2, &"master_stone": 3, &"reinterred": 1, &"organ_taken": -3, &"organ_taken_grave": -5, &"lecture_rumor": -4, &"donation": 1, &"order_failed": -1, &"visit_pleased": 1, &"visit_neglected": -1, &"visit_disturbed": -3, &"visit_noise": -1, &"visit_specimen_rumor": -1, &"wish_done": 1, &"robber_reported": 3, &"lights_all": 3, &"lights_some": 1, &"fenner_watch": 1, &"letter_delivered": 1, &"large_request_done": 2, &"large_request_failed": -2, &"sent_away_rumor": -2, &"kept_promise": 1, &"public_duty": 3, &"register_sold_rumor": -1, &"case_reported": 3, &"dues_paid": 1, &"estimated": -1}
## A finished grave with quality ≥ grave_good_min → grave_good, ≤ grave_poor_max → grave_poor.
@export var grave_good_min: int = 8
@export var grave_poor_max: int = 3
