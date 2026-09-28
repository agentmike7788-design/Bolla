class_name DecayVisualConfig
extends Resource
## Painted decay (docs/PHASE4_DESIGN.md §2.5, §8): data/config/decay_visual_config.tres.
## No gore: tint overlay, flies, smell wisps, juniper smoke.

## Overlay amount per stage (interpolated continuously over the freshness).
@export var overlay_by_stage: Dictionary[StringName, float] = {&"fresh": 0.0, &"wilted": 0.35, &"decaying": 0.7, &"rotten": 1.0}
@export var washed_reduction: float = 0.15
@export var flies_by_stage: Dictionary[StringName, int] = {&"fresh": 0, &"wilted": 4, &"decaying": 8, &"rotten": 10}
@export var wisps_by_stage: Dictionary[StringName, int] = {&"fresh": 0, &"wilted": 0, &"decaying": 3, &"rotten": 5}
## Juniper smoke particles during a balm window (replace the wisps).
@export var smoke_particles: int = 3
@export var stain_color: Color = Color("8E9A7E")
@export var wisp_color: Color = Color(0.66, 0.65, 0.48, 0.3)
@export var smoke_color: Color = Color(0.72, 0.70, 0.66, 0.3)
@export var visibility_range: float = 22.0
## At most this many corpses emit particles at once.
@export var max_emitting: int = 3
# Phase 6 (docs/PHASE6_DESIGN.md §2.2): in a cold niche the flies rest, the wisps run at × 0.5 and
# 2 chill particles per occupied niche show the cold (marker "chill").
@export var niche_fly_scale: float = 0.0
@export var niche_wisp_scale: float = 0.5
@export var niche_chill_particles: int = 2
