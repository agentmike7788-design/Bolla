class_name ApprenticeRules
extends RefCounted
## Pure apprentice rules (docs/PHASE8_DESIGN.md §2.5, §3.4): minutes by level and morale, the deterministic
## mistake (Angelernt 8 %, Geübt 2 %, × 0.5 the day after a scolding), the working days.


## task.minutes[level] × fast_factor (morale ≥ morale_fast) / slow_factor (≤ morale_slow), rounded, at least 1;
## 0 = he cannot (Ungelernt, unknown task).
static func minutes_for(task: ApprenticeTaskData, level: int, morale: int, cfg: ApprenticeConfig) -> int:
	if task == null or level <= 0 or level >= task.minutes.size():
		return 0
	if cfg == null:
		cfg = ApprenticeConfig.new()
	var base := task.minutes[level]
	if base <= 0:
		return 0
	var factor := 1.0
	if morale >= cfg.morale_fast:
		factor = cfg.fast_factor
	elif morale <= cfg.morale_slow:
		factor = cfg.slow_factor
	return maxi(1, roundi(base * factor))


## Deterministic from day, place and task: a stable hash in [0, 1) below mistake_rate[level] (× scold factor
## after a scolding). Level 0 never works, so never errs here.
static func mistake(task_id: StringName, spot_id: String, day: int, level: int, scolded: bool, cfg: ApprenticeConfig) -> bool:
	if cfg == null:
		cfg = ApprenticeConfig.new()
	if level <= 0 or level >= cfg.mistake_rate.size():
		return false
	var rate := cfg.mistake_rate[level]
	if scolded:
		rate *= cfg.scold_mistake_factor
	return roll(task_id, spot_id, day) < rate


## The deterministic draw 0 ≤ x < 1 of (task, place, day).
static func roll(task_id: StringName, spot_id: String, day: int) -> float:
	return float(posmod(hash([String(task_id), spot_id, day, "jakob"]), 100000)) / 100000.0


## Hired, not day % day_off_mod == day_off_rest, no festival, fewer than unpaid_limit unpaid days.
static func works_today(day: int, hired: bool, unpaid: int, fest_today: bool, cfg: ApprenticeConfig) -> bool:
	if cfg == null:
		cfg = ApprenticeConfig.new()
	if not hired or fest_today or unpaid >= cfg.unpaid_limit:
		return false
	return cfg.day_off_mod <= 0 or posmod(day, cfg.day_off_mod) != cfg.day_off_rest
