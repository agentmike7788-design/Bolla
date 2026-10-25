class_name PietyConfig
extends Resource
## Piety – the inner moral value (docs/PHASE4_DESIGN.md §2.7): data/config/piety_config.tres.
## Per-tier arrays follow PietyRules.TIERS (hardhearted … devout).

@export var min_value: int = -100
@export var max_value: int = 100
@export var start_value: int = 0
## Tier i+1 from value ≥ tier_thresholds[i].
@export var tier_thresholds: PackedInt32Array = [-59, -19, 20, 60]
## Phase 6 §2.7: + service (unharvested only), devotion (once per grave), reinterred.
## Phase 7 §2.11: + organ_taken (−6 = an inner organ; the amount per organ comes from
## AnatomyConfig.organs[*].piety through Piety.event(&"organ_taken", …, amount)), lecture_attended −3,
## specimen_returned +3, specimen_returned_grave +5 (class default; the .tres is P4's).
## Phase 8 §2.11: + alms +1, listen +1, robber_let_go +2, lights_all +2 (W0: class default and .tres; P2 owns them).
## Phase 9 §2.9 (+ 16): letters (read_sealed −1, read_grave +1, burned_asked +1, burned_unasked −1, buried +1, answered +1),
## the endings (sent_away +3, kept_promise +3, made_public −1), Brenneisen (soil_sold −1, register_sold −3, case_bribe −3,
## kladde_sold −8, case_to_ilse +2, stranger_refused +1), postage_paid +1 (W0: class default and .tres; P3 owns them).
## Phase 10 §2.10 (+ 2): poor_box_give +1 (once a week, P2), rose_planted +1 (a rose bush on a foreign grave without a
## wish, at most 1 a day, P4) (W0: class default and .tres).
@export var events: Dictionary[StringName, int] = {&"valuables_left": 3, &"valuables_taken": -6, &"hair_taken": -4, &"teeth_taken": -6, &"full_prep": 3, &"bare_burial": -2, &"rotten_burial": -2, &"service": 1, &"devotion": 1, &"reinterred": 1, &"organ_taken": -6, &"lecture_attended": -3, &"specimen_returned": 3, &"specimen_returned_grave": 5, &"alms": 1, &"listen": 1, &"robber_let_go": 2, &"lights_all": 2, &"letter_read_sealed": -1, &"letter_read_grave": 1, &"letter_burned_asked": 1, &"letter_burned_unasked": -1, &"letter_buried": 1, &"letter_answered": 1, &"sent_away": 3, &"kept_promise": 3, &"made_public": -1, &"soil_sold": -1, &"register_sold": -3, &"case_bribe": -3, &"kladde_sold": -8, &"case_to_ilse": 2, &"stranger_refused": 1, &"postage_paid": 1, &"poor_box_give": 1, &"rose_planted": 1}
## Daily +1 towards 0 (only below 0, only without harvesting the day before).
@export var daily_recovery: int = 1
## Ghost gift coins per tier.
@export var gift_by_tier: PackedInt32Array = [0, 2, 2, 2, 3]
## Extra coins per sold item at Ilse per tier.
@export var buyer_bonus_by_tier: PackedInt32Array = [1, 1, 0, 0, 0]
## Hook for Phase 13+ (PietyRules.affinity): ≥ +threshold soul, ≤ −threshold bone.
@export var affinity_threshold: int = 20
# Phase 5 (docs/PHASE5_DESIGN.md §2.9, G4 finding B2): full_prep only for a corpse nothing was
# harvested from (CorpseCare._after_prep, P6). stats.prepared counts every full preparation.
@export var full_prep_requires_unharvested: bool = true
