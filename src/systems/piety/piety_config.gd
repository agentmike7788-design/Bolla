class_name PietyConfig
extends Resource
## Piety – the inner moral value (docs/PHASE4_DESIGN.md §2.7): data/config/piety_config.tres.
## Per-tier arrays follow PietyRules.TIERS (hardhearted … devout).

@export var min_value: int = -100
@export var max_value: int = 100
@export var start_value: int = 0
## Tier i+1 from value ≥ tier_thresholds[i].
@export var tier_thresholds: PackedInt32Array = [-59, -19, 20, 60]
@export var events: Dictionary[StringName, int] = {&"valuables_left": 3, &"valuables_taken": -6, &"hair_taken": -4, &"teeth_taken": -6, &"full_prep": 3, &"bare_burial": -2, &"rotten_burial": -2}
## Daily +1 towards 0 (only below 0, only without harvesting the day before).
@export var daily_recovery: int = 1
## Ghost gift coins per tier.
@export var gift_by_tier: PackedInt32Array = [0, 2, 2, 2, 3]
## Extra coins per sold item at Ilse per tier.
@export var buyer_bonus_by_tier: PackedInt32Array = [1, 1, 0, 0, 0]
## Hook for Phase 13+ (PietyRules.affinity): ≥ +threshold soul, ≤ −threshold bone.
@export var affinity_threshold: int = 20
