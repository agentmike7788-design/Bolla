class_name TreasuryRules
extends RefCounted
## STUB (P2) – pure rules of the parish treasury (docs/PHASE10_DESIGN.md §2.5, §3.4): the share of tended occupied graves
## (no weeds / leaves at the grave's care spots, no withered flowers, not disturbed), the cemetery money of a week
## {quality, need, hardship, total}, prorating (rounded up), the rent of a month (from the lease letter, the first month
## prorated from the book's start), the tithe (10 % of the receipted income, ≤ 25), the estimate (10 % of „ohne Beleg"
## over 20, ≤ 15), why the dues cannot be paid now.
## W1 (P2) fills the bodies; the signatures are the contract.


static func care_share(_graves: Array, _tree: SceneTree) -> float:
	return 0.0


## {quality, need, hardship, total}
static func parish_pay(_tier: StringName, _care: float, _disturbed: int, _holdings: int, _cfg: TreasuryConfig) -> Dictionary:
	return {"quality": 0, "need": 0, "hardship": 0, "total": 0}


## amount × days / of_days, rounded up.
static func prorate(_amount: int, _days: int, _of_days: int) -> int:
	return 0


static func rent_due(_month_key: String, _book_start: int, _flags: Dictionary, _cfg: TreasuryConfig) -> int:
	return 0


static func tithe(_booked_income: int, _cfg: TreasuryConfig) -> int:
	return 0


static func estimate(_untracked: int, _cfg: TreasuryConfig) -> int:
	return 0


## "" = can pay; else the reason shown dimmed.
static func dues_block_reason(_amount: int, _holdings: int) -> String:
	return ""
