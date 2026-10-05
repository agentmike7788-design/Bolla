class_name NightPathRules
extends RefCounted
## STUB (P7) – pure sick-light rules (docs/PHASE8_DESIGN.md §1.6, §3.2.1): the nights of a path relative to
## p8_open_day (a minute < 06:00 belongs to the night that began the evening before), the visit at a
## minute, the waiting time (10 minutes before, ≤ 120), the observation distance.
## §3.4 gives no signatures for this class: P7 adds pure static functions (deterministic, no tree).
## W1 (P7) fills the bodies.
