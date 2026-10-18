class_name LettersConfig
extends Resource
## Letters and errands (docs/PHASE9_DESIGN.md §2.4, §3.4): data/config/letters_config.tres.

## Pocket letters from p9_open on; the first three deliveries after it carry L1–L3 for sure.
@export var open_flag: StringName = &"p9_open"
@export var forced_after_open: int = 3
@export var forced_ids: Array[StringName] = [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"]
## Post for the dead: Osric brings a letter on p9_open_day + 3, + 6, + 9; Hanne the letter to L. Aschau.
@export var post_offsets: PackedInt32Array = [3, 6, 9]
@export var aschau_letter: StringName = &"lpo_aschau"
## Coins of the postage (coin purpose &"post"); §1.3 minutes.
@export var postage: int = 1
## W3 („Restbedarf“ 6): reading a letter standing – the letter card's „Lesen“ (TimedAction read_letter).
@export var read_minutes: int = 5
@export var read_grave_minutes: int = 10
@export var answer_minutes: int = 20
@export var burn_minutes: int = 2
@export var bury_minutes: int = 2
@export var answer_item: StringName = &"ink"
## Reputation of a delivered letter at most once a day; the counter-letter comes a day after the answer.
@export var rep_cap_day: int = 1
@export var reply_after_days: int = 1
