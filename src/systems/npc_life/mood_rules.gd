class_name MoodRules
extends RefCounted
## STUB (P1) – pure mood rules (docs/PHASE8_DESIGN.md §2.1.1, §3.4): the daily roll from day and
## npc_id (NpcLifeConfig.mood_weights) and the precedence rules (NpcLifeConfig.mood_rules).
## W1 (P1) fills the bodies; the signatures are the contract.


## Deterministic from day and npc_id.
static func roll(_npc_id: StringName, _day: int, _cfg: NpcLifeConfig) -> StringName:
	return &"plain"


## The first matching rule of cfg.mood_rules wins, else `base`.
static func apply_rules(base: StringName, _npc_id: StringName, _day: int, _events: Dictionary, _cfg: NpcLifeConfig,
		_villager: VillagerData) -> StringName:
	return base
