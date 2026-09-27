class_name DirtGrowth
extends RefCounted
## STUB (P3) – docs/PHASE3_DESIGN.md §2.4, §3.4. Pure growth rules of weeds / leaves.


## Progress per day incl. the fixed ±growth_jitter factor from hash(spot_id).
static func rate(_spot_id: String, _kind: StringName, _cfg: CleanlinessConfig) -> float:
	return 0.0


## progress after `minutes` of growth, clamped to max_level + 0.999.
static func grow(progress: float, _rate_per_day: float, _minutes: int, _cfg: CleanlinessConfig) -> float:
	return progress


## min(max_level, floor(progress)).
static func level(_progress: float, _cfg: CleanlinessConfig) -> int:
	return 0
