class_name StrangerConfig
extends Resource
## The gentleman with the case, Cornelius Brenneisen (docs/PHASE9_DESIGN.md §2.5, §3.4):
## data/config/stranger_config.tres.

@export var npc_id: StringName = &"stranger"
## First visit p9_open_day + 2, then every 5 days for 3 days.
@export var arrive_offset: int = 2
@export var return_every: int = 5
@export var stay_days: int = 3
## Outside the cemetery gate 14:10–15:30, in the Holderkrug 18:00–21:00 (minutes).
@export var gate_window: Vector2i = Vector2i(850, 930)
@export var inn_window: Vector2i = Vector2i(1080, 1260)
## Coins: an answer, the bribe, the tip for the case, the ledger.
@export var question_coin: int = 1
@export var bribe_coins: int = 15
@export var case_tip: int = 2
@export var kladde_price: int = 40
## Specimens: Quast's price × 1.5; the talk (register sold) after 2 days.
@export var specimen_factor: float = 1.5
@export var rumor_delay_days: int = 2
## The 6 questions at the gate (text P6).
@export var questions: PackedStringArray = []
