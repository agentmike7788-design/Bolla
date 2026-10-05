class_name MoodRules
extends RefCounted
## Pure mood rules (docs/PHASE8_DESIGN.md §2.1.1, §3.4): the daily roll from day and npc_id
## (NpcLifeConfig.mood_weights over NpcLifeConfig.moods) and the precedence rules (NpcLifeConfig.mood_rules,
## the first that matches wins).
## `events` (NpcLife.mood_events): event key → the day it happened (int) or several days (Array). Keys:
## &"festival" (a festival day) · &"mourning:<house>" (a mourning ribbon at the house) · &"step:<npc_id>" (a
## story step of the person) · &"sick_light" (a sick light in the village) · plain event names
## (lecture_rumor, specimen_sold_villager, grave_disturbed …) for the rumor rules.
## Rule fields: trigger, mood, npcs (empty = everyone / the circle / the person), days (0 today, 1 yesterday,
## 2 today or yesterday), events (rumor only).

const FALLBACK := &"plain"
const KEY_FESTIVAL := &"festival"
const KEY_SICK_LIGHT := &"sick_light"
const PREFIX_MOURNING := "mourning:"
const PREFIX_STEP := "step:"


## Deterministic from day and npc_id: a stable hash picks a mood by the weights (unknown / zero weights:
## plain).
static func roll(npc_id: StringName, day: int, cfg: NpcLifeConfig) -> StringName:
	if cfg == null:
		cfg = NpcLifeConfig.new()
	var total := 0
	for mood: StringName in cfg.moods:
		total += maxi(int(cfg.mood_weights.get(mood, 0)), 0)
	if total <= 0:
		return FALLBACK
	var pick := posmod(hash([String(npc_id), day, "mood"]), total)
	for mood: StringName in cfg.moods:
		pick -= maxi(int(cfg.mood_weights.get(mood, 0)), 0)
		if pick < 0:
			return mood
	return FALLBACK


## The first matching rule of cfg.mood_rules wins, else `base`.
static func apply_rules(base: StringName, npc_id: StringName, day: int, events: Dictionary, cfg: NpcLifeConfig,
		villager: VillagerData) -> StringName:
	if cfg == null:
		cfg = NpcLifeConfig.new()
	for rule: Dictionary in cfg.mood_rules:
		if matches(rule, npc_id, day, events, villager):
			return StringName(str(rule.get("mood", base)))
	return base


## One precedence rule holds for `npc_id` on `day`.
static func matches(rule: Dictionary, npc_id: StringName, day: int, events: Dictionary, villager: VillagerData) -> bool:
	var npcs: Array = rule.get("npcs", [])
	if not npcs.is_empty() and not npcs.has(npc_id) and not npcs.has(String(npc_id)):
		return false
	var days := int(rule.get("days", 0))
	match StringName(str(rule.get("trigger", ""))):
		&"festival":
			return happened(events, KEY_FESTIVAL, day, days)
		&"mourning_circle":
			if villager == null:
				return false
			for house: StringName in villager.circle:
				if happened(events, StringName(PREFIX_MOURNING + String(house)), day, days):
					return true
			return false
		&"own_step":
			return happened(events, StringName(PREFIX_STEP + String(npc_id)), day, days)
		&"rumor":
			for ev: Variant in rule.get("events", []):
				if happened(events, StringName(str(ev)), day, days):
					return true
			return false
		&"sick_light":
			return happened(events, KEY_SICK_LIGHT, day, days)
	return false


## `key` happened inside the window of `days` before `day` (0 today, 1 yesterday, 2 today or yesterday).
static func happened(events: Dictionary, key: StringName, day: int, days: int) -> bool:
	var raw: Variant = events.get(key, events.get(String(key), null))
	var list: Array = []
	if raw is int or raw is float:
		list = [int(raw)]
	elif raw is Array or raw is PackedInt32Array:
		list = Array(raw)
	for d: Variant in list:
		if not (d is int or d is float):
			continue
		var n := int(d)
		match days:
			0:
				if n == day:
					return true
			1:
				if n == day - 1:
					return true
			_:
				if n == day or n == day - 1:
					return true
	return false
