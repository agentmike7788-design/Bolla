class_name WhoKnowsConfig
extends Resource
## The main chain „Wer weiß, wann?" (docs/PHASE9_DESIGN.md §2.2, §2.2.2, §3.4): data/config/who_knows_config.tres.
## All dates of the chain are relative to q_light_day = p9_open_day + open_light_offset.

## The open light (Siebers) = p9_open_day − 12; Johann's death = light + 21 (02:10); decision deadline H6 =
## light + 17 (23:59).
@export var open_light_offset: int = -12
@export var death_offset: int = 21
@export var decide_offset: int = 17
## GameState flags: the day of the open light, Johann marked (H4).
@export var light_flag: StringName = &"q_light_day"
@export var marked_flag: StringName = &"q_sieber_marked"
## Johann Sieber's kin / household.
@export var kin_id: StringName = &"kin_sieber"
@export var house: StringName = &"house_sieber"
## From this step Johann visits Grete's grave daily (Visitors.set_kin_interval 1) and sits on the bench
## 14:00–16:00 (bench_window, minutes).
@export var daily_visit_from_step: StringName = &"h4"
@export var bench_window: Vector2i = Vector2i(840, 960)
## §1.3 minutes: read the ledger (H1), compare the register (H2), compare a grave's date (H2), the nameless letter.
@export var kladde_minutes: int = 20
@export var register_minutes: int = 30
@export var grave_minutes: int = 5
@export var letter_minutes: int = 20
@export var letter_item: StringName = &"ink"
## Ending A: leaves with Hanne at 16:20 (980) or with Osric at 10:00 (600).
@export var depart_with_peddler_minute: int = 980
@export var depart_with_carter_minute: int = 600
## H3: 3 of 5 witnesses → i_light_before.
@export var witness_count: int = 3
## §2.6: the held-back plot of the fourth row.
@export var reserve_section: StringName = &"linden_row4"
