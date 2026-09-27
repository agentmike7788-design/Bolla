class_name ActionConfig
extends Resource
## Durations of player actions (data/config/action_config.tres).
## Game minutes are what the clock advances; real seconds are how long the progress bar runs.

@export var examine_minutes: int = 20
@export var shroud_minutes: int = 10
@export var dig_minutes: int = 60
@export var bury_minutes: int = 30
@export var marker_minutes: int = 10
@export var gather_minutes: int = 10
@export var real_seconds_per_minute: float = 0.05
@export var real_seconds_min: float = 1.5
@export var real_seconds_max: float = 4.0


func real_seconds_for(game_minutes: int) -> float:
	return clampf(game_minutes * real_seconds_per_minute, real_seconds_min, real_seconds_max)
