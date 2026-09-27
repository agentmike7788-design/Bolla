class_name PietyRules
extends RefCounted
## STUB (P3) – docs/PHASE4_DESIGN.md §2.7, §3.4. Pure piety rules. TIERS / LABELS are final
## (user decision §14.1); the functions are stubs.

const TIERS: Array[StringName] = [&"hardhearted", &"callous", &"matter_of_fact", &"considerate", &"devout"]
const LABELS := {"hardhearted": "Hartherzig", "callous": "Abgebrüht", "matter_of_fact": "Sachlich", "considerate": "Rücksichtsvoll", "devout": "Andächtig"}


static func tier(_value: int, _cfg: PietyConfig) -> StringName:
	return &"matter_of_fact"


static func tier_index(_t: StringName) -> int:
	return 2


static func label(_t: StringName) -> String:
	return ""


## Sentence for the journal page "Ich" (§2.7).
static func self_image(_t: StringName) -> String:
	return ""


## +daily_recovery towards 0, only below 0 and without harvesting yesterday.
static func recovery(_value: int, _used_yesterday: bool, _cfg: PietyConfig) -> int:
	return 0


## Hook for Phase 13+: &"soul" (≥ threshold) · &"bone" (≤ −threshold) · &"".
static func affinity(_value: int, _cfg: PietyConfig) -> StringName:
	return &""
