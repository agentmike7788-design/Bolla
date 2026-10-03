class_name RelationshipRules
extends RefCounted
## STUB (P2) – pure relationship rules (docs/PHASE7_DESIGN.md §2.1, §2.4, §3.4): the tier of a value,
## the start value at the first meeting (reputation bonus; piety bonus for piety_sensitive villagers)
## and the tier word. W1 (P2) fills the bodies; the signatures are the contract.

const TIERS: Array[StringName] = [&"stranger", &"acquainted", &"trusted", &"friend"]
const WORDS: Array[String] = ["Fremd", "Bekannt", "Vertraut", "Befreundet"]
const MIN_VALUE := 0
const MAX_VALUE := 100


static func tier(_value: int, _cfg: RelationshipConfig) -> StringName:
	return TIERS[0]


static func start_value(data: VillagerData, _rep_tier: StringName, _piety_tier: StringName, _cfg: RelationshipConfig) -> int:
	return data.start_value if data != null else 0


## „Fremd" | „Bekannt" | „Vertraut" | „Befreundet".
static func word(_tier: StringName) -> String:
	return ""
