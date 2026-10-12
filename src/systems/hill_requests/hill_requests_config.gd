class_name HillRequestsConfig
extends Resource
## G8 Runde 6 „Bitten vom Hügel" (docs/PHASE8_DESIGN.md, G8 Runde 6 §1): data/config/hill_requests_config.tres.
## Small requests of the village pinned to the cemetery gate's notice board – with a deadline and a cooldown,
## no instant-reward daily quests (user decision 12.10.2026).

## First day a request is pinned (day 1 is the first corpse alone).
@export var start_day: int = 2
## Minute Osric pins the new requests (07:44 – after the delivery 07:40 and the gate bell).
@export var post_minute: int = 464
## Minute of the morning check (deadlines, requests taken down): 06:00 like the orders.
@export var refresh_minute: int = 360
## Before village_open: places on the board, accepted at once, mornings until a freed place is filled again.
@export var slots_early: int = 2
@export var max_active_early: int = 2
@export var refill_days_early: int = 1
## From village_open: one place, one accepted, a freed place is filled on the third morning (economy of
## Phases 7/8 and the bot goals stay).
@export var slots_village: int = 1
@export var max_active_village: int = 1
@export var refill_days_village: int = 3
## An offered (not accepted) request is taken down after this many days (no consequence).
@export var offer_days: int = 2
## Reputation of a missed deadline (small: „Verfall kostet nichts oder nur sehr wenig").
@export var fail_rep: int = -1
## Flag that switches to the village rules.
@export var village_flag: StringName = &"village_open"
## Entries kept in the journal's log (done / missed).
@export var log_size: int = 12
