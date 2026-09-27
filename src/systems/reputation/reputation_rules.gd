class_name ReputationRules
extends RefCounted
## Pure reputation rules (docs/PHASE3_DESIGN.md §2.6, §2.7, §3.4). Values 0…100, five tiers;
## every per-tier number comes from ReputationConfig (data/config/reputation_config.tres).
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const TIERS: Array[StringName] = [&"disreputable", &"unremarkable", &"respected", &"esteemed", &"renowned"]
const LABELS := {"disreputable": "Verrufen", "unremarkable": "Unauffällig", "respected": "Geachtet", "esteemed": "Geschätzt", "renowned": "Gerühmt"}


## Tier of `value`: tier i + 1 starts at tier_thresholds[i]. Broken thresholds → class defaults.
static func tier(value: int, cfg: ReputationConfig) -> StringName:
	var thresholds := _cfg(cfg).tier_thresholds
	if thresholds.size() != TIERS.size() - 1:
		push_warning("[ReputationRules] tier_thresholds need %d values – using defaults" % (TIERS.size() - 1))
		thresholds = ReputationConfig.new().tier_thresholds
	var index := 0
	for i: int in thresholds.size():
		if value >= thresholds[i]:
			index = i + 1
	return TIERS[index]


## Index in TIERS; -1 for an unknown tier.
static func tier_index(t: StringName) -> int:
	return TIERS.find(t)


## German label ("Verrufen" … "Gerühmt"); "" for unknown tiers.
static func label(t: StringName) -> String:
	return String(LABELS.get(String(t), ""))


## clamp(target_base + round(target_per_quality × cemetery_total), min_value, max_value)
static func target(cemetery_total: int, cfg: ReputationConfig) -> int:
	var c := _cfg(cfg)
	return clampi(c.target_base + roundi(c.target_per_quality * float(cemetery_total)), c.min_value, c.max_value)


## clamp(round((target − value) × drift_factor), −drift_max, drift_max)
static func drift(value: int, target_value: int, cfg: ReputationConfig) -> int:
	var c := _cfg(cfg)
	return clampi(roundi(float(target_value - value) * c.drift_factor), -c.drift_max, c.drift_max)


## Coins added to every burial payment in tier `t`.
static func pay_bonus(t: StringName, cfg: ReputationConfig) -> int:
	return _per_tier(_cfg(cfg).pay_bonus, t, 0)


## Daily stipend (coins) in tier `t`.
static func stipend(t: StringName, cfg: ReputationConfig) -> int:
	return _per_tier(_cfg(cfg).stipend, t, 0)


## Corpses delivered on `day` in tier `t`; 0 on even days while delivery_every_other_day is set
## for the tier (disreputable).
static func deliveries_on(day: int, t: StringName, cfg: ReputationConfig) -> int:
	var c := _cfg(cfg)
	if _per_tier(c.delivery_every_other_day, t, 0) != 0 and posmod(day, 2) == 0:
		return 0
	return maxi(_per_tier(c.deliveries_per_day, t, 1), 0)


## clampi(40 + old × 9, 0, 100): 0→40, −1→31, −2→22, −3→13
static func migrate_v1(old: int) -> int:
	return clampi(40 + old * 9, 0, 100)


static func _per_tier(values: PackedInt32Array, t: StringName, fallback: int) -> int:
	var index := tier_index(t)
	if index < 0:
		push_warning("[ReputationRules] unknown tier '%s'" % t)
		return fallback
	if index >= values.size():
		push_warning("[ReputationRules] no value for tier '%s' (%d values)" % [t, values.size()])
		return fallback
	return values[index]


static func _cfg(cfg: ReputationConfig) -> ReputationConfig:
	if cfg != null:
		return cfg
	var data := Database.config(&"reputation_config") as ReputationConfig
	return data if data != null else ReputationConfig.new()
