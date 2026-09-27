class_name CorpseDecay
extends RefCounted
## Decay rules of a CorpseRecord (docs §2.5), used by CorpseManager: freshness as a pure
## function of the minutes since arrival. No state, no autoloads.

const MINUTES_PER_HOUR := 60
## Freshness at arrival (CorpseGenerator sets it); decay is measured from arrival_total_minutes.
const START_FRESHNESS := 1.0
## Freshness is kept on a grid of 1 / FRESHNESS_RESOLUTION: exact threshold times land exactly
## on the threshold, and the 14-digit floats of JSON.from_native save it bit-exactly.
const FRESHNESS_RESOLUTION := 1000000.0


## Docs §2.5: freshness = START_FRESHNESS - base_decay_per_hour * decay_mult * hours since
## arrival (min 0), in one expression from the total-minute difference – no float error adds
## up over the hourly steps – snapped to the FRESHNESS_RESOLUTION grid.
## Phase 4 (§2.5): balm_factor for the juniper windows – STUB (P1): not yet applied.
static func freshness_at(record: CorpseRecord, now_total: int, decay_per_hour: float, _balm_factor: float = 0.25) -> float:
	var minutes := maxi(0, now_total - record.arrival_total_minutes)
	var value := maxf(0.0, START_FRESHNESS - decay_per_hour * minutes / float(MINUTES_PER_HOUR))
	return roundf(value * FRESHNESS_RESOLUTION) / FRESHNESS_RESOLUTION


## STUB (P1) – §2.5: minutes since arrival − (1 − balm_factor) × Σ overlap(balm window, [arrival, now]).
static func effective_minutes(record: CorpseRecord, now_total: int, _balm_factor: float) -> float:
	return float(maxi(0, now_total - record.arrival_total_minutes))


## STUB (P1) – minutes until the freshness drops below `threshold` (−1 = already below); UI "noch ≈ 3 h".
static func minutes_until(_record: CorpseRecord, _now_total: int, _decay_per_hour: float, _balm_factor: float, _threshold: float) -> int:
	return -1


## base_decay_per_hour * the decay_mult of the record's cause; 0 without tables.
static func decay_per_hour(record: CorpseRecord, tables: CorpseTables) -> float:
	if tables == null:
		return 0.0
	return tables.base_decay_per_hour * float(tables.get_cause(record.cause_id).get("decay_mult", 1.0))
