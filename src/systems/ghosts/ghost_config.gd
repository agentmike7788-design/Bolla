class_name GhostConfig
extends Resource
## Ghosts of the buried (docs/PHASE3_DESIGN.md §2.8): data/config/ghost_config.tres.

## Visible 21:30 … 04:30 (minute of day; the window wraps over midnight).
@export var appear_minute: int = 1290
@export var vanish_minute: int = 270
@export var fade_minutes: int = 30
@export var max_active: int = 6
@export var reselect_hysteresis: float = 2.0
@export var reselect_seconds: float = 1.0
## score < [0] restless, < [1] calm, otherwise content.
@export var mood_thresholds: PackedInt32Array = [5, 9]
@export var decor_bonus_max: int = 2
@export var listen_radius: float = 2.2
@export var face_radius: float = 3.5
@export var wander_radius: float = 2.0
## m/s by mood.
@export var speeds: Dictionary[StringName, float] = {&"content": 0.0, &"calm": 0.4, &"restless": 0.8}
## Within this many game minutes the same ghost repeats its line.
@export var repeat_minutes: int = 60
@export var bubble_seconds: float = 4.0
@export var gift_coins: int = 2
