class_name ApprenticeConfig
extends Resource
## The apprentice Jakob Wackernagel (docs/PHASE8_DESIGN.md §2.5, §3.4): data/config/apprentice_config.tres.
## The class defaults carry the contract values.

@export var npc_id: StringName = &"apprentice"
@export var hire_flag: StringName = &"apprentice_hired"
## 08:15 at the road end, 08:30 work, lunch 12:00–12:30, 15:30 tools back and wage.
@export var arrive_minute: int = 495
@export var start_minute: int = 510
@export var lunch: Vector2i = Vector2i(720, 750)
@export var end_minute: int = 930
## 3 coins per working day; after 3 unpaid days in a row he stays at home.
@export var wage: int = 3
@export var unpaid_limit: int = 3
## Day off: day % 7 == 2.
@export var day_off_mod: int = 7
@export var day_off_rest: int = 2
## Angelernt → Geübt after 12 own places; showing works up to 4 m.
@export var practice_jobs: int = 12
@export var teach_distance: float = 4.0
## Mistake rate by level (0 never – he cannot, 1 Angelernt 8 %, 2 Geübt 2 %).
@export var mistake_rate: PackedFloat32Array = [1.0, 0.08, 0.02]
## Morale 0…5, start 3; ≥ 4 −10 % minutes, ≤ 1 +20 %; scolded: mistakes × 0.5 the next day.
@export var morale_start: int = 3
@export var morale_fast: int = 4
@export var morale_slow: int = 1
@export var fast_factor: float = 0.9
@export var slow_factor: float = 1.2
@export var scold_mistake_factor: float = 0.5
## The chalk board holds 3 lines; his box 6 slots + the coin tin.
@export var board_lines: int = 3
@export var box_slots: int = 6
