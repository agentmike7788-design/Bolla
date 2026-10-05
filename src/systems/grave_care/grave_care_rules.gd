class_name GraveCareRules
extends RefCounted
## STUB (P2) – pure grave-care rules (docs/PHASE8_DESIGN.md §2.3, §3.2.1): flowers fresh / wilted / gone
## by the minutes since the last watering, the candle window 15:00–07:00, the mortsafe minimum of 10 days,
## the care bonus (flowers or bouquet +1, candle +1 – +2 on the night of the lights – capped by care_cap).
## §3.4 gives no signatures for this class: P2 adds pure static functions (deterministic, no tree).
## W1 (P2) fills the bodies.
