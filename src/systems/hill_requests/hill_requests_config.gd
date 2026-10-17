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

# Phase 9 – larger requests (docs/PHASE9_DESIGN.md §2.3.2, §3.4): OrderData with size large and 2–4 parts in
# data/hill_requests/large/. From day 2 one place at the gate, from village_open one more at the parish board.
## First day a large request is pinned (07:44 with the small ones).
@export var large_start_day: int = 2
## Places: one at the gate, one at the parish board (from village_open).
@export var large_slots_gate: int = 1
@export var large_slots_village: int = 1
## At most one accepted at once (in addition to the small ones).
@export var large_max_active: int = 1
## A freed place is filled on the next morning (before village_open) / on the second morning (from village_open).
@export var large_refill_days_early: int = 1
@export var large_refill_days_village: int = 2
## An offered large request is taken down after this many days.
@export var large_offer_days: int = 2
## Reputation of a missed large request; relationship to the giver from village_open (gains large_request_village).
@export var large_fail_rep: int = -2
@export var large_reward_rel: int = 3
## Half done at the deadline: at least this share of the parts → half the coins (rounded down), reputation 0.
@export var half_ratio: float = 0.5
