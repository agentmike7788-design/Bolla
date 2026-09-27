class_name GhostMood
extends RefCounted
## STUB (P4) – docs/PHASE3_DESIGN.md §2.8, §3.4. Pure mood / hint / line rules.
## score = grave quality + own dirt spot (+1/0/−2/−4) + decor bonus (max decor_bonus_max).
## Reasons by priority: &"weeds", &"valuables", &"cold", &"cross", &"waited", &"bare".


static func score(_quality: int, _dirt_level: int, _decor_bonus: int, _clean: CleanlinessConfig, _cfg: GhostConfig) -> int:
	return 0


## &"restless", &"calm", &"content"
static func mood(_score: int, _cfg: GhostConfig) -> StringName:
	return &"calm"


## §2.8; &"" = nothing missing.
static func main_reason(_grave: GraveRecord, _corpse: CorpseRecord, _dirt_level: int, _decor_bonus: int, _economy: EconomyConfig) -> StringName:
	return &""


## Deterministic from `seed` (hash(grave_id) + day).
static func pick_line(_lines: GhostLines, _mood: StringName, _reason: StringName, _traits: Array[StringName], _seed: int) -> String:
	return ""
