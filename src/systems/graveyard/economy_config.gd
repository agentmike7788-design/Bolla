class_name EconomyConfig
extends Resource
## Grave quality points, payment and ratings (data/config/economy_config.tres).

@export_group("Grave quality")
@export var quality_buried: int = 2
@export var quality_shroud: int = 2
@export var quality_examined: int = 1
@export var marker_quality: Dictionary[StringName, int] = {&"wooden_cross": 1, &"gravestone_simple": 3}
@export var fresh_good_threshold: float = 0.6
@export var fresh_good_bonus: int = 1
@export var fresh_bad_threshold: float = 0.3
@export var fresh_bad_malus: int = -1
@export var valuables_left_bonus: int = 1
@export var valuables_taken_malus: int = -2
@export var quality_min: int = 0
@export var quality_max: int = 10
@export_group("Payment & reputation")
## payment = base_payment(cause) + floor(quality * payment_per_quality)
@export var payment_per_quality: float = 0.5
@export var valuables_reputation: int = -1
@export_group("Cemetery rating")
@export var old_grave_quality: int = 0
## Totals at which the rating becomes orderly / tended / dignified.
@export var rating_thresholds: PackedInt32Array = [10, 25, 45]
## Reputation at or below which the label becomes "Unauffällig" / "Verrufen".
@export var reputation_thresholds: PackedInt32Array = [-1, -3]


## The one lookup: `config` if given (injected), else data/config/economy_config.tres via
## Database, else the class defaults.
static func resolve(config: EconomyConfig = null) -> EconomyConfig:
	if config != null:
		return config
	var data := Database.config(&"economy_config") as EconomyConfig
	return data if data != null else EconomyConfig.new()
