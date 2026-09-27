class_name DirtGrowth
extends RefCounted
## Pure growth rules of weeds / leaves (docs/PHASE3_DESIGN.md §2.4, §3.4). Growth is a function
## of elapsed game minutes (like decay), never of ticks: grow(p, r, a + b) == grow(grow(p, r, a), r, b)
## below the clamp.
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const MINUTES_PER_DAY := 1440.0
## Resolution of the per-spot jitter factor.
const JITTER_STEPS := 1000


## Progress per day incl. the fixed ±growth_jitter factor from hash(spot_id). Unknown kind = 0.
static func rate(spot_id: String, kind: StringName, cfg: CleanlinessConfig) -> float:
	var base := float(cfg.growth_per_day.get(kind, 0.0))
	return base * (1.0 + cfg.growth_jitter * jitter_unit(spot_id))


## Fixed value in [−1, 1] from hash(spot_id) (deterministic across runs).
static func jitter_unit(spot_id: String) -> float:
	var steps := posmod(spot_id.hash(), JITTER_STEPS + 1)
	return float(steps) / float(JITTER_STEPS) * 2.0 - 1.0


## progress after `minutes` of growth, clamped to [0, max_level + 0.999].
static func grow(progress: float, rate_per_day: float, minutes: int, cfg: CleanlinessConfig) -> float:
	if minutes <= 0 or rate_per_day <= 0.0:
		return clampf(progress, 0.0, _cap(cfg))
	return clampf(progress + rate_per_day * float(minutes) / MINUTES_PER_DAY, 0.0, _cap(cfg))


## min(max_level, floor(progress)), never below 0.
static func level(progress: float, cfg: CleanlinessConfig) -> int:
	return clampi(floori(progress), 0, cfg.max_level)


static func _cap(cfg: CleanlinessConfig) -> float:
	return float(cfg.max_level) + 0.999
