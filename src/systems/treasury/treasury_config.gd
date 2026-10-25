class_name TreasuryConfig
extends Resource
## The parish treasury (docs/PHASE10_DESIGN.md §2.5, §3.4): data/config/treasury_config.tres (P2 owns the data).
## Weekly cemetery inspection (Sunday 18:00) → cemetery money (Monday 07:40 through Osric, else the hut chest), the
## need allowance below 60 coins, the hardship floor of 10; the monthly settlement on the 1st 06:00 with the rent, the
## tithe and the estimate, due until the 7th, deferred without interest, waived after a month; the poor box at the
## gate; the chapter „Soll und Haben" (debit_credit). Weekdays: 0 = Monday … 6 = Sunday (CalendarRules).

## §2.5.2 Friedhofsschau: Sunday 18:00.
@export var schau_weekday: int = 6
@export var schau_minute: int = 1080
## §2.5.2 Auszahlung: Monday 07:40 through Osric; not at the gate → the hut chest (never Jakob's wage tin).
@export var pay_weekday: int = 0
@export var pay_minute: int = 460
@export var pay_fallback_chest: StringName = &"hut_chest"
## Base pay per week by cemetery tier (CemeteryRating: neglected … venerable).
@export var tier_pay: Dictionary[StringName, int] = {&"neglected": 0, &"orderly": 4, &"tended": 7, &"dignified": 10, &"venerable": 12}
## Care bonus: share of tended occupied graves ≥ 50 % +1, ≥ 75 % +2, ≥ 95 % +3; −1 per disturbed grave; at most 15.
@export var care_steps: PackedFloat32Array = [0.5, 0.75, 0.95]
@export var disturbed_malus: int = 1
@export var quality_cap: int = 15
## Need allowance: holdings below 60 → ⌈(60 − holdings) / 4⌉, at most 15.
@export var need_threshold: int = 60
@export var need_divisor: int = 4
@export var need_cap: int = 15
## Hardship floor: still below 10 afterwards → filled up to 10, at most 8.
@export var hardship_floor: int = 10
@export var hardship_cap: int = 8
## §2.5.4 Monatsabrechnung on the 1st at 06:00; due until the 7th (1st + 6 days, 23:59); waived after one month.
@export var settle_minute: int = 360
@export var due_days: int = 6
@export var waive_after_months: int = 1
## §2.5.5 rent for the quarry and the workshop from the lease letter (bruch_license) on.
@export var rent: int = 8
@export var rent_flag: StringName = &"bruch_license"
## §2.5.6 tithe 10 % of the receipted income, at most 25; tithe and estimate from levy_flag (village_open) on.
@export var tithe_percent: int = 10
@export var tithe_cap: int = 25
@export var levy_flag: StringName = &"village_open"
## §2.5.6 estimate 10 % of „ohne Beleg" when it is more than 20 in the month, at most 15.
@export var estimate_percent: int = 10
@export var estimate_min_untracked: int = 20
@export var estimate_cap: int = 15
## §2.5.8 poor box: at most 30 coins inside; the gravekeeper gives 1.
@export var poor_box_max: int = 30
@export var poor_box_give: int = 1
## §1.2 the chapter opens after who_knows_when_complete (p10_open / p10_open_day).
@export var open_flag: StringName = &"p10_open"
@export var open_day_flag: StringName = &"p10_open_day"
@export var unlock_flag: StringName = &"who_knows_when_complete"
## §1.5 the chapter „Soll und Haben".
@export var chapter_id: StringName = &"debit_credit"
@export var goal_flag: StringName = &"debit_credit_complete"
@export var goal_market_days: int = 2
@export var goal_min_tier: StringName = &"dignified"
## §1.6 (B) Lorenz' prepaid rent: the first settlement that asks for rent and the next one are 0; 0 = off.
@export var prepaid_rent_months: int = 2
