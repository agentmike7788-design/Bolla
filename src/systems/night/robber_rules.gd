class_name RobberRules
extends RefCounted
## Pure night-robber rules (docs/PHASE8_DESIGN.md §2.6.3, §3.2.1): which night may come (from the night after
## p8_open_day + 4, not on the night of the lights, not in a night-watch night, his story still open), the target
## grave (buried ≤ 5 days ago, FILLED / MARKED, no mortsafe, no burning candle, not disturbed – the freshest),
## the first night for sure, then 35 % with a pause of 2 nights (deterministic from the night and the seed).
## A night N is the night that begins on the evening of day N; he comes at 01:30 of day N + 1.
## No tree: the caller passes the candidates.

## §2.6.3 consequences of the second encounter (relationship deltas; reputation / piety are config events).
const REPORT_MAYOR := 4
const LET_GO_WASHER := 2
const LET_GO_MAYOR := -2
const MAYOR := &"mayor"
const WASHER := &"washer"


## The night N may bring him at all (before the grave check).
static func night_open(night: int, open_day: int, lights_day: int, watch: bool, fate: StringName, cfg: RobberConfig) -> bool:
	if open_day <= 0 or fate != &"":
		return false
	if night < open_day + cfg.start_offset_days:
		return false
	if lights_day > 0 and night == lights_day:
		return false
	return not watch


## The night N brings him (given a target): the first one for sure (first_guaranteed, he never came), later
## with `chance` and at least min_gap_nights nights of pause after `last_night`.
static func comes(night: int, last_night: int, seed: int, cfg: RobberConfig) -> bool:
	if last_night < 0:
		return cfg.first_guaranteed or _roll(night, seed) < cfg.chance
	if night - last_night <= cfg.min_gap_nights:
		return false
	return _roll(night, seed) < cfg.chance


## A grave is a target in night N: buried ≤ fresh_days before day N + 1, occupied, unprotected.
static func is_target(buried_day: int, night: int, occupied: bool, mortsafe: bool, candle: bool, disturbed: bool,
		cfg: RobberConfig) -> bool:
	if not occupied or mortsafe or candle or disturbed or buried_day <= 0:
		return false
	return night + 1 - buried_day <= cfg.fresh_days and buried_day <= night + 1


## The freshest of the candidates [{grave_id, buried_day}] ("" = none) – ties by grave id.
static func freshest(candidates: Array) -> String:
	var best := ""
	var best_day := -1
	for c: Variant in candidates:
		var d := int((c as Dictionary).get("buried_day", -1))
		var g := str((c as Dictionary).get("grave_id", ""))
		if d > best_day or (d == best_day and g < best):
			best = g
			best_day = d
	return best


## Deterministic 0…1 of a night.
static func _roll(night: int, seed: int) -> float:
	return float(posmod(hash([night, seed, "robber"]), 10000)) / 10000.0
