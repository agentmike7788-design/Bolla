class_name TimeConfig
extends Resource
## Game clock settings (data/config/time_config.tres). Minutes are minute-of-day (0..1439).

@export var seconds_per_game_minute: float = 0.5
@export var start_day: int = 1
@export var start_minute: int = 390
@export var night_start_minute: int = 1260
@export var night_end_minute: int = 330
## Hut door: "rest" is offered before this minute and skips to it.
@export var rest_until_minute: int = 1080
## Hut door: "sleep" is offered from this minute (or after midnight before wake_minute).
@export var sleep_from_minute: int = 1080
@export var wake_minute: int = 360
