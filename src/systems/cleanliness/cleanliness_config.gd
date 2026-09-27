class_name CleanlinessConfig
extends Resource
## Weeds & leaves (docs/PHASE3_DESIGN.md §2.4): data/config/cleanliness_config.tres.

## Progress per game day by kind (&"weeds", &"leaves").
@export var growth_per_day: Dictionary[StringName, float] = {&"weeds": 0.30, &"leaves": 0.40}
## ± factor per spot, fixed from hash(spot_id).
@export var growth_jitter: float = 0.25
@export var max_level: int = 3
## Cemetery quality penalty per spot by level 0..3.
@export var penalty_by_level: PackedInt32Array = [0, 0, 1, 2]
## Ghost mood points of a grave's own spot by level 0..3.
@export var grave_mood_by_level: PackedInt32Array = [1, 0, -2, -4]
## Weeding minutes by level 0..3 (by hand).
@export var weed_minutes: PackedInt32Array = [0, 15, 15, 25]
@export var rake_minutes: int = 10
## Raking leaves needs this item.
@export var rake_item: StringName = &"rake"
