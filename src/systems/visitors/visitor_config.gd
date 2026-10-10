class_name VisitorConfig
extends Resource
## Visitors, the look at the grave, wishes and tips (docs/PHASE8_DESIGN.md §2.2, §3.4):
## data/config/visitor_config.tres. The class defaults carry the contract values.

## §2.2.2 plan: first visit the day after the burial, then every 3 (+0/1 seed) days for 21 days of
## mourning, afterwards every 7.
@export var first_delay_days: int = 1
@export var mourning_days: int = 21
@export var interval_mourning: int = 3
@export var interval_late: int = 7
## At most 3 visits a day, 2 visitors at once, in the slots 09:30 · 12:30 · 15:00.
@export var max_visits_day: int = 3
@export var max_concurrent: int = 2
@export var slots: PackedInt32Array = [570, 750, 900]
## Late visits (after the mourning time) bring flowers with this chance (the first always).
@export var flowers_chance_late: float = 0.4
## §2.2.3: mourning 30 minutes, then waiting (wish / tip). G8 Runde 1 (B8-1, user decision): a household waits up
## to wait_minutes (was 10) for the gravekeeper, but not past wait_until_minute (16:30, before the November dusk,
## E8-1) and never less than wait_min_minutes; after the talk it goes after leave_after_talk_minutes. Villagers keep
## wait_minutes_villager (18 – their day goes on in the village: the data schedules of Esch, Theres, Liesel).
@export var mourn_minutes: int = 30
@export var wait_minutes: int = 100
@export var wait_min_minutes: int = 10
@export var wait_until_minute: int = 990
@export var wait_minutes_villager: int = 18
@export var leave_after_talk_minutes: int = 3
## G8 Runde 1 (B8-1): every visitor waits for a word after the look (the contract had: only with a tip or a wish).
@export var wait_always: bool = true
## G8 Runde 1 (B8-1): the gate bell (GateBell) rings when a visitor comes up; HUD note only while the gravekeeper is on
## the graveyard (region graveyard).
@export var bell_cue: StringName = &"gate_bell"
## A noisy action ≤ noise_distance m from a mourner (§2.2.3); a waiting visitor turns at talk_distance.
@export var noise_distance: float = 8.0
@export var talk_distance: float = 4.0
## Goodwill 0…10 per kin, start 5; a wish needs ≥ goodwill_wish_min.
@export var goodwill_start: int = 5
@export var goodwill_wish_min: int = 2
## §2.2.4 by view (precedence disturbed > neglected > bare > kept; bonus and specimen on top):
## {rep_event (ReputationConfig.event_points key, &"" = none), goodwill}.
@export var view_effects: Dictionary[StringName, Dictionary] = {
	&"disturbed": {"rep_event": &"visit_disturbed", "goodwill": -4},
	&"neglected": {"rep_event": &"visit_neglected", "goodwill": -1},
	&"bare": {"rep_event": &"", "goodwill": 0},
	&"kept": {"rep_event": &"visit_pleased", "goodwill": 1},
	&"bonus": {"rep_event": &"", "goodwill": 1},
	&"specimen": {"rep_event": &"visit_specimen_rumor", "goodwill": -3},
}
## visit_pleased at most twice a day.
@export var pleased_cap_day: int = 2
## §2.2.5: at most 3 open wishes; tip 1 (+1 goodwill ≥ 6, +1 grave quality ≥ 15), at most 4 a day.
@export var max_open: int = 3
@export var tip_base: int = 1
@export var tip_goodwill_min: int = 6
@export var tip_quality_min: int = 15
@export var tip_cap_day: int = 4
## Goodwill +2 for a wish done, −2 for one failed; villagers +4 relationship instead of coins.
@export var wish_goodwill: int = 2
@export var wish_fail_goodwill: int = -2
@export var villager_wish_rel: int = 4
