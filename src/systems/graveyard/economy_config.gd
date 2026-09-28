class_name EconomyConfig
extends Resource
## Grave quality points, payment and ratings (data/config/economy_config.tres).

@export_group("Grave quality")
@export var quality_buried: int = 2
@export var quality_shroud: int = 2
@export var quality_examined: int = 1
## Phase 5 §2.5: + the designed stone shapes stone_stele 3, stone_arch 4, stone_master 5
## (StoneShapeData.id = marker_id; no items – set only at the grave via Stonemasonry).
@export var marker_quality: Dictionary[StringName, int] = {&"wooden_cross": 1, &"gravestone_simple": 3,
		&"stone_stele": 3, &"stone_arch": 4, &"stone_master": 5}
@export var fresh_good_threshold: float = 0.6
@export var fresh_good_bonus: int = 1
@export var fresh_bad_threshold: float = 0.3
@export var fresh_bad_malus: int = -1
@export var valuables_left_bonus: int = 1
@export var valuables_taken_malus: int = -2
@export var quality_min: int = 0
## Phase 4 §2.4: 13 (2+1+3+1+3+1+1+1). Phase 5 §2.5: 19 (2+1+3+1+9+1+1+1: a gilded master stone
## with a fitting inscription and an ornament). Graves finished before keep their saved quality.
@export var quality_max: int = 19
# Phase 4 (docs/PHASE4_DESIGN.md §2.4, §2.5)
@export var quality_washed: int = 1
@export var quality_laid_out: int = 1
## Dress kind → points (the shroud keeps quality_shroud = 2).
@export var dress_quality: Dictionary[StringName, int] = {&"shroud": 2, &"gown": 3}
## Below this freshness the stage is rotten.
@export var rot_threshold: float = 0.1
@export var rot_malus: int = -2
## Harvest kind → points.
@export var harvest_malus: Dictionary[StringName, int] = {&"hair": -1, &"teeth": -2}
@export_group("Payment & reputation")
## payment = base_payment(cause) + floor(quality * payment_per_quality)
@export var payment_per_quality: float = 0.5
## Reputation change for taking valuables (Phase 3 §2.6: 0…100 scale).
@export var valuables_reputation: int = -8
@export_group("Cemetery rating")
@export var old_grave_quality: int = 0
## Cemetery quality at which the rating becomes orderly / tended / dignified / venerable (§2.5).
@export var rating_thresholds: PackedInt32Array = [15, 32, 50, 100]
## Phase 4 §2.14: "Ehrwürdig" also needs decor ≥ venerable_min_decor and a dirt penalty
## ≤ venerable_max_dirt.
@export var venerable_min_decor: int = 12
@export var venerable_max_dirt: int = 6
## Phase 2 only: declared, no longer read (reputation tiers: ReputationConfig, Phase 3 §2.6).
@export var reputation_thresholds: PackedInt32Array = [-1, -3]


## The one lookup: `config` if given (injected), else data/config/economy_config.tres via
## Database, else the class defaults.
static func resolve(config: EconomyConfig = null) -> EconomyConfig:
	if config != null:
		return config
	var data := Database.config(&"economy_config") as EconomyConfig
	return data if data != null else EconomyConfig.new()
