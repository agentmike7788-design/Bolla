class_name PlayerConfig
extends Resource
## Player tuning (data/config/player_config.tres).

@export var move_speed: float = 3.2
@export var carry_speed: float = 2.0
@export var turn_speed: float = 10.0
## Phase 5 §2.3: 20 (class default; data/config/player_config.tres is P3's and still says 16).
@export var inventory_slots: int = 20
## Applied on "new game" only.
@export var start_items: Dictionary[StringName, int] = {&"coin": 5, &"wood": 2, &"linen": 1}
## Distance in front of the player where a carried corpse is put down.
@export var drop_distance: float = 0.8
