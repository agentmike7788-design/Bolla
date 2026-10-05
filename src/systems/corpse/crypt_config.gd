class_name CryptConfig
extends Resource
## The crypt – morgue, cold niches, ossuary (docs/PHASE6_DESIGN.md §2.2, §2.3):
## data/config/crypt_config.tres. Arrays by crypt level 0…3.

@export var niches_by_level: PackedInt32Array = [0, 2, 4, 6]
## Decay rate factor in a niche / on the crypt table or floor (room cold) by level.
@export var niche_factor_by_level: PackedFloat32Array = [1.0, 0.5, 0.4, 0.3]
@export var room_factor_by_level: PackedFloat32Array = [1.0, 0.8, 0.7, 0.6]
## Ossuary places (lifted + reinterred) by level.
@export var ossuary_by_level: PackedInt32Array = [0, 3, 5, 6]
## Corpses with room crypt do not count for the stench at the gate.
@export var stench_exempt: bool = true
## From this crypt level on the exemption holds (04.10.2026: the crypt stands at level 1 from the start;
## 1 = the crypt keeps the smell in from day 1, 2 = the early crypt still lets it out as in Phase 4).
@export var stench_exempt_min_level: int = 2
## Lifting an old grave (base minutes, the Phase-5 shovel tier factors apply), reinterring, the
## parish's fee per reinterment.
@export var lift_minutes: int = 60
@export var reinter_minutes: int = 20
@export var reinter_fee: int = 4
@export var box_item: StringName = &"bone_box"
@export var full_item: StringName = &"bone_box_full"
## Liftable only when game year − died_year ≥ min_rest_years.
@export var min_rest_years: int = 30
## The sealed passage appears at passage_level, the grille at grille_level; the clue.
@export var passage_level: int = 2
@export var grille_level: int = 3
@export var passage_clue: StringName = &"c_crypt_draft"
@export var room_id: StringName = &"crypt"
## A corpse that lay ≥ this long in a niche counts once for stats.niche_waits.
@export var niche_wait_minutes: int = 60
