class_name RobberRules
extends RefCounted
## STUB (P7) – pure night-digger rules (docs/PHASE8_DESIGN.md §2.6.3, §3.2.1): the target grave (fresh ≤
## fresh_days, FILLED / MARKED, no mortsafe, no candle, no night watch, the freshest), the night roll
## (first guaranteed, then chance with min_gap_nights, deterministic from day and seed), noticing.
## §3.4 gives no signatures for this class: P7 adds pure static functions (deterministic, no tree).
## W1 (P7) fills the bodies.
