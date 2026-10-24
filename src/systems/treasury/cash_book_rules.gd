class_name CashBookRules
extends RefCounted
## STUB (P3) – pure rules of the cash book (docs/PHASE10_DESIGN.md §2.6, §3.4): the source of an income from its reason
## text (prefix table CashBookConfig.sources; unknown → &"other"), whether a source counts as receipted (tithe) or as
## „ohne Beleg" (estimate), „ohne Beleg" from the holdings' change minus the booked income plus the booked spending.
## W1 (P3) fills the bodies; the signatures are the contract.

const OTHER := &"other"
const UNTRACKED := &"untracked"


## Prefix table; unknown → &"other".
static func source_of(_reason: String, _cfg: CashBookConfig) -> StringName:
	return OTHER


static func is_receipt(_source: StringName, _cfg: CashBookConfig) -> bool:
	return false


## holdings_delta − booked_in + booked_out (positive or negative).
static func untracked(_holdings_delta: int, _booked_in: int, _booked_out: int) -> int:
	return 0
