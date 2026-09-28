class_name OssuaryRules
extends RefCounted
## STUB (P3) – pure rules of lifting old graves and the ossuary places (docs/PHASE6_DESIGN.md
## §2.3, §3.4). W1 (P3) fills the bodies; the signatures are the contract.

const TEXT_REST := "Die Ruhezeit ist nicht um. Hier liegt noch keiner lange genug."
const TEXT_NO_BOX := "Keine Gebeinkiste – an der Werkbank zimmern."
const TEXT_FULL := "Das Beinhaus ist voll – erst die Gruft ausbauen."
const TEXT_BURIED := "Die Gruft ist noch verschüttet."


## year − died_year ≥ min_rest_years.
static func liftable(_data: OldGraveData, _year: int, _cfg: CryptConfig) -> bool:
	return false


## "" or the reason (§2.3 texts).
static func lift_block_reason(_grave: GraveRecord, _data: OldGraveData, _crypt_level: int, _used: int, _inv: Inventory,
		_year: int, _cfg: CryptConfig, _open: bool) -> String:
	return ""


## ossuary_by_level[crypt_level] (clamped).
static func capacity(_crypt_level: int, _cfg: CryptConfig) -> int:
	return 0


## „Agnes Hollweg (1741–1789)".
static func label(_data: OldGraveData) -> String:
	return ""
