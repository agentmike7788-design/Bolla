class_name ApprenticeRules
extends RefCounted
## STUB (P3) – pure apprentice rules (docs/PHASE8_DESIGN.md §2.5, §3.4): minutes by level and morale,
## the deterministic mistake (8 % / 2 %, × 0.5 after scolding), the working days.
## W1 (P3) fills the bodies; the signatures are the contract.


## task.minutes[level] × fast_factor (morale ≥ 4) / slow_factor (≤ 1); 0 = he cannot.
static func minutes_for(_task: ApprenticeTaskData, _level: int, _morale: int, _cfg: ApprenticeConfig) -> int:
	return 0


## Deterministic from day, place and task.
static func mistake(_task_id: StringName, _spot_id: String, _day: int, _level: int, _scolded: bool, _cfg: ApprenticeConfig) -> bool:
	return false


## Hired, not day % 7 == 2, no festival, fewer than unpaid_limit unpaid days.
static func works_today(_day: int, _hired: bool, _unpaid: int, _fest_today: bool, _cfg: ApprenticeConfig) -> bool:
	return false
