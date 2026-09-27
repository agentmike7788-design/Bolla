class_name ReputationRules
extends RefCounted
## STUB (P3) – docs/PHASE3_DESIGN.md §2.6, §2.7, §3.4. Pure reputation rules. TIERS / LABELS
## are final (user decision §14.4); the functions are stubs.

const TIERS: Array[StringName] = [&"disreputable", &"unremarkable", &"respected", &"esteemed", &"renowned"]
const LABELS := {"disreputable": "Verrufen", "unremarkable": "Unauffällig", "respected": "Geachtet", "esteemed": "Geschätzt", "renowned": "Gerühmt"}


static func tier(_value: int, _cfg: ReputationConfig) -> StringName:
	return TIERS[0]


static func tier_index(_t: StringName) -> int:
	return 0


static func label(_t: StringName) -> String:
	return ""


## clamp(target_base + round(target_per_quality × cemetery_total), min_value, max_value)
static func target(_cemetery_total: int, _cfg: ReputationConfig) -> int:
	return 0


## clamp(round((target − value) × drift_factor), −drift_max, drift_max)
static func drift(_value: int, _target: int, _cfg: ReputationConfig) -> int:
	return 0


static func pay_bonus(_t: StringName, _cfg: ReputationConfig) -> int:
	return 0


static func stipend(_t: StringName, _cfg: ReputationConfig) -> int:
	return 0


## 0 on even days while disreputable.
static func deliveries_on(_day: int, _t: StringName, _cfg: ReputationConfig) -> int:
	return 1


## clampi(40 + old × 9, 0, 100): 0→40, −1→31, −2→22, −3→13
static func migrate_v1(old: int) -> int:
	return old
