class_name RobberConfig
extends Resource
## The night digger Lambert Grell (docs/PHASE8_DESIGN.md §2.6.3, §3.4): data/config/robber_config.tres.
## The class defaults carry the contract values.

## At the earliest the night after p8_open_day + 4; target graves buried ≤ 5 days ago.
@export var start_offset_days: int = 4
@export var fresh_days: int = 5
## The first possible night for sure, then 35 % with at least 2 nights' pause (deterministic).
@export var chance: float = 0.35
@export var min_gap_nights: int = 2
@export var first_guaranteed: bool = true
## 01:30 out of the wood, 01:50–05:00 digging.
@export var arrive_minute: int = 90
@export var dig_from: int = 110
@export var dig_until: int = 300
## He notices the gravekeeper ≤ 10 m; after the third disturbed night the night watchman catches him.
@export var notice_distance: float = 10.0
@export var watch_catch_after: int = 3
@export var report_rep: StringName = &"robber_reported"
@export var let_go_piety: StringName = &"robber_let_go"
