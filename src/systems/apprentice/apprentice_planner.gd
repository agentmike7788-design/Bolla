class_name ApprenticePlanner
extends RefCounted
## STUB (P3) – pure planning of the apprentice's day (docs/PHASE8_DESIGN.md §2.5.2, §2.5.3, §3.4); reusable
## (Phase 14 may reuse it; no Phase-8 system knows Phase 14).
## W1 (P3) fills the bodies; the signatures are the contract.


## [{task, spot_id, grave_id, start, work_minutes, path}] – the next place first, skips mourned graves and
## locked sections, candles from 15:00, inserts the walks to the rain barrel.
static func plan(_day: int, _from_minute: int, _lines: Array[Dictionary], _state: Dictionary, _tree: SceneTree,
		_cfg: ApprenticeConfig) -> Array[Dictionary]:
	return []
