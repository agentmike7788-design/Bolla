class_name SaveMigration
extends RefCounted
## Upgrades a decoded save state ({autoloads, nodes}) to the CURRENT format
## (docs/PHASE3_DESIGN.md §5.2, §3.4 "Speichern"). Applied by SaveFileIO.read_doc after
## decode_state; the normal load path follows and the next save writes CURRENT.
## Pure: never touches the scene tree or an autoload, never changes its input.

const CURRENT := 2

## Save ids of the Phase-3 system nodes that get an empty state ({} = their default state,
## docs/PHASE3_DESIGN.md §3.1, §5.2 step 4). Reputation keeps its value in GameState, the
## derived nodes (CemeteryScore, BuildMode, GrassClearMask) are not saved.
const V2_EMPTY_NODES: PackedStringArray = ["expansion", "cleanliness", "decorations", "ghosts"]
## Phase-2 reputation (about −10…+10, 0 = "Geachtet") → Phase-3 scale 0…100:
## clampi(V1_REPUTATION_BASE + old × V1_REPUTATION_STEP, 0, 100) – 0 → 40, −3 → 13 (§3.4
## ReputationRules.migrate_v1; the formula is part of the format, not a balancing value).
const V1_REPUTATION_BASE := 40
const V1_REPUTATION_STEP := 9
const REPUTATION_MIN := 0
const REPUTATION_MAX := 100


## Chain from_version → CURRENT. Unknown / newer versions → {} (= corrupt).
## `meta` (optional, W0 addition) is the save's meta block – migrate_1_to_2 needs meta.day.
static func migrate(state: Dictionary, from_version: int, meta: Dictionary = {}) -> Dictionary:
	if from_version < 1 or from_version > CURRENT:
		return {}
	if not state.get("autoloads") is Dictionary or not state.get("nodes") is Dictionary:
		return {}
	var out := state
	if from_version <= 1:
		out = migrate_1_to_2(out, meta)
	return out


## §5.2 steps 1–7 on a deep copy of a v1 state (run exactly once – the reputation is rescaled).
static func migrate_1_to_2(state: Dictionary, meta: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var autoloads := _sub(out, "autoloads")
	var nodes := _sub(out, "nodes")
	var game_state := _sub(autoloads, "GameState")
	var day := _save_day(meta, _sub(autoloads, "TimeManager"))
	# 1. Reputation onto the 0…100 scale (tier meaning kept: 0 "Geachtet" → 40 "Geachtet").
	var stats := _sub(game_state, "stats")
	_set_key(stats, "reputation", reputation_v1_to_v2(_to_int(_get_key(stats, "reputation"), 0)))
	# 2. slice_complete → vs_finished: deliveries resume as soon as a plot is free.
	var flags := _sub(game_state, "flags")
	var finished: Variant = _get_key(flags, "slice_complete")
	if _has_key(flags, "slice_complete"):
		_erase_key(flags, "slice_complete")
		if finished:
			_set_key(flags, "vs_finished", true)
	# 3. No second reputation drift on the day of the load.
	if not _has_key(flags, "rep_last_day"):
		_set_key(flags, "rep_last_day", day)
	# 4. Empty states for the new system nodes (default state, no "no saved state" warning).
	for id: String in V2_EMPTY_NODES:
		if not nodes.get(id) is Dictionary:
			nodes[id] = {}
	# 5. Graves: completed_day 0 (= ghosts right away). plot_07…12 stay absent – Graveyard
	#    creates them LOCKED from its section data when it loads.
	var graveyard: Variant = nodes.get("graveyard")
	if graveyard is Dictionary and (graveyard as Dictionary).get("graves") is Array:
		for grave: Variant in (graveyard as Dictionary).graves:
			if grave is Dictionary and not (grave as Dictionary).has("completed_day"):
				(grave as Dictionary)["completed_day"] = 0
	# 6. CorpseManager: list of today's deliveries (the v1 field stays as its fallback).
	var corpses: Variant = nodes.get("corpse_manager")
	if corpses is Dictionary and not (corpses as Dictionary).has("last_delivery_ids"):
		var last := str((corpses as Dictionary).get("last_delivery_id", ""))
		(corpses as Dictionary)["last_delivery_ids"] = [last] if last != "" else []
	# 7. Player, TimeManager, resources, chest, hut: unchanged.
	return out


## ReputationRules.migrate_v1 (§3.4): 0 → 40, −1 → 31, −2 → 22, −3 → 13, clamped 0…100.
static func reputation_v1_to_v2(old: int) -> int:
	return clampi(V1_REPUTATION_BASE + old * V1_REPUTATION_STEP, REPUTATION_MIN, REPUTATION_MAX)


# --- helpers ----------------------------------------------------------------------------------

## meta.day of the save; falls back to the saved TimeManager day, then 1.
static func _save_day(meta: Dictionary, time_state: Dictionary) -> int:
	var day: Variant = meta.get("day", time_state.get("day", 1))
	return maxi(1, _to_int(day, 1))


## d[key] as a Dictionary – created (and stored) when missing or not a Dictionary.
static func _sub(d: Dictionary, key: String) -> Dictionary:
	var value: Variant = d.get(key)
	if value is Dictionary:
		return value
	var fresh := {}
	d[key] = fresh
	return fresh


## GameState writes StringName keys, JSON may give Strings – both forms count.
static func _has_key(d: Dictionary, key: String) -> bool:
	return d.has(StringName(key)) or d.has(key)


static func _get_key(d: Dictionary, key: String) -> Variant:
	if d.has(StringName(key)):
		return d[StringName(key)]
	return d.get(key)


static func _set_key(d: Dictionary, key: String, value: Variant) -> void:
	d.erase(key)
	d[StringName(key)] = value


static func _erase_key(d: Dictionary, key: String) -> void:
	d.erase(key)
	d.erase(StringName(key))


static func _to_int(v: Variant, default: int) -> int:
	if v is int or v is float:
		return int(v)
	return default
