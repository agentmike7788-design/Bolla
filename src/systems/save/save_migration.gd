class_name SaveMigration
extends RefCounted
## Upgrades a decoded save state ({autoloads, nodes}) to the CURRENT format
## (docs/PHASE3_DESIGN.md §5.2, §3.4 "Speichern"; docs/PHASE4_DESIGN.md §5.2: chain 1→2→3;
## docs/PHASE5_DESIGN.md §5.2: chain 1→2→3→4; docs/PHASE6_DESIGN.md §5.2: chain 1→…→5). Applied by SaveFileIO.read_doc after
## decode_state; the normal load path follows and the next save writes CURRENT.
## Pure: never touches the scene tree, never changes its input or an autoload (migrate_3_to_4 only
## reads item categories from Database).

const CURRENT := 5
## Save ids of the Phase-6 system nodes / the shed store that get an empty state in migrate_4_to_5
## (docs/PHASE6_DESIGN.md §3.1, §5.2 step 4); SaveManager.without_absent_defaults drops them while
## the world has no such node (like V4_EMPTY_NODES).
const V5_EMPTY_NODES: PackedStringArray = ["buildings", "ossuary", "chapel", "shed_store"]
## Phase-6 statistics that start at 0 (§5.2 step 6; = the Phase-6 part of GameState.DEFAULT_STATS,
## incl. the ledger stat of the coin purpose &"building", §2.7).
const V5_NEW_STATS: Array[StringName] = [&"services_held", &"devotions_held", &"bones_lifted", &"bones_reinterred",
		&"niche_waits", &"coins_spent_building"]
## §5.2 step 2: the new CorpseRecord fields and their defaults (= CorpseRecord.to_dict of a new record).
const V5_RECORD_DEFAULTS := {"room": "", "slot_id": "", "cold_windows": [], "service_held": false, "service_day": 0}
## Save ids of the Phase-5 system nodes that get an empty state in migrate_3_to_4 (§3.1, §5.2
## step 3). SaveManager.without_absent_defaults drops them again while the world has no such node.
const V4_EMPTY_NODES: PackedStringArray = ["workshop", "gathering", "stonemasonry"]
## Phase-5 statistics that start at 0 (§5.2 step 6; = the Phase-5 part of GameState.DEFAULT_STATS,
## incl. the coin ledger by purpose coins_spent_<reason>).
const V4_NEW_STATS: Array[StringName] = [&"crafted", &"stones_set", &"coins_spent", &"trees_felled",
		&"coins_spent_license", &"coins_spent_build", &"coins_spent_osric", &"coins_spent_ilse"]
## save_id of the player (Player.save_state: {position, rot_y, in_interior, inventory}).
const PLAYER_SAVE_ID := "player"
## Save ids of the Phase-4 system nodes that get an empty state in migrate_2_to_3 (§3.1, §5.2
## steps 4–5). Used by P6 once the nodes exist in the world (W0: not yet inserted – an unknown
## save_id would warn).
const V3_EMPTY_NODES: PackedStringArray = ["journal", "night_trade", "npc_trader"]
## §5.2 step 1: piety from the valuables history (= PietyConfig.events valuables_taken / _left;
## part of the format, not a balancing value).
const PIETY_PER_TAKEN := -6
const PIETY_PER_LEFT := 3
const PIETY_MIN := -100
const PIETY_MAX := 100
## Generic find ids (§2.2, fixed by the contract): trait → find, cause → "f_cause_<cause>".
const TRAIT_FINDS: Dictionary[StringName, StringName] = {&"valuables": &"f_valuables", &"letter": &"f_letter",
		&"tattoo": &"f_tattoo", &"strange_wound": &"f_mark"}
const CAUSE_FIND_PREFIX := "f_cause_"

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
	if from_version <= 2:
		out = migrate_2_to_3(out, meta)
	if from_version <= 3:
		out = migrate_3_to_4(out, meta)
	if from_version <= 4:
		out = migrate_4_to_5(out, meta)
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


## docs/PHASE4_DESIGN.md §5.2 steps 1–7 on a deep copy of a v2 state (run exactly once).
## Phase-3 saves keep everything they had; the new Phase-4 state is derived from the history:
## piety from the valuables choices, dress / examination / finds from the records, the journal
## is rebuilt quietly by JournalManager.post_load (sync_from_records) from finds_revealed.
static func migrate_2_to_3(state: Dictionary, meta: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var autoloads := _sub(out, "autoloads")
	var nodes := _sub(out, "nodes")
	var game_state := _sub(autoloads, "GameState")
	var stats := _sub(game_state, "stats")
	var flags := _sub(game_state, "flags")
	var day := _save_day(meta, _sub(autoloads, "TimeManager"))
	var corpse_state: Variant = nodes.get("corpse_manager")
	var records: Array = []
	if corpse_state is Dictionary and (corpse_state as Dictionary).get("corpses") is Array:
		records = (corpse_state as Dictionary).corpses
	# 1. Piety from the history: −6 per valuables taken, +3 per valuables left.
	var left := 0
	for r: Variant in records:
		if r is Dictionary and String(str((r as Dictionary).get("valuables_decision", ""))) == String(CorpseRecord.DECISION_LEFT):
			left += 1
	var taken := _to_int(_get_key(stats, "valuables_taken"), 0)
	_set_key(stats, "piety", clampi(PIETY_PER_TAKEN * taken + PIETY_PER_LEFT * left, PIETY_MIN, PIETY_MAX))
	_set_key(stats, "utilized", 0)
	_set_key(stats, "prepared", 0)
	# 5. (stats part) no sales at Ilse's yet.
	_set_key(stats, "trader_sales", 0)
	# 2. Records: dress from shrouded; examined → all four steps, all traits, the generic finds
	#    of its traits + the cause detail (Phase 2/3 showed everything at once – nothing lost).
	for r: Variant in records:
		if r is Dictionary:
			_migrate_record(r)
	# 3. CorpseManager: no story yet, no stench malus on the day of the load.
	if corpse_state is Dictionary:
		var cm := corpse_state as Dictionary
		cm["story_delivered"] = [] as Array[String]
		cm["story_last_day"] = 0
		cm["stench_day"] = day
	# 4./5. Empty states for the new system nodes (journal: rebuilt in post_load).
	for id: String in V3_EMPTY_NODES:
		if not nodes.get(id) is Dictionary:
			nodes[id] = {}
	# 5. No second daily piety recovery on the day of the load. trader_known stays unset: from
	#    day 4 on the note comes at the next 06:00 (NightTrade.apply_morning).
	if not _has_key(flags, "piety_last_day"):
		_set_key(flags, "piety_last_day", day)
	# 6. Graves unchanged (stored quality ≤ 10 stays); h_01…06 stay absent → Graveyard creates
	#    them LOCKED from its section data. 7. Player, time, inventory, chest, decor, cleanliness,
	#    ghosts: unchanged.
	return out


## docs/PHASE5_DESIGN.md §5.2 steps 1–7 on a deep copy of a v3 state (run exactly once).
## 1. Player inventory: every slot holding a TOOL item (ItemData.Category, read from Database) →
##    inventory.tools {id: 1}; the slot becomes {} (other slots keep their index). A second piece
##    of the same tool stays in its slot (nothing is lost). The chest has no belt. Unknown ids stay.
## 2. Graves: design {} (marker_id, quality, breakdown unchanged).
## 3. Empty states for V4_EMPTY_NODES (SaveManager.without_absent_defaults drops them while the
##    world has no such node – no "unknown save_id" warning, nothing lost).
## 4. expansion: bruch / quarry stay absent → LOCKED (ExpansionManager is tolerant).
## 5. The workyard decor is cleared at runtime (Workshop.post_load), not here.
## 6. New stats (V4_NEW_STATS) = 0; no new flags (workshop_open comes from Workshop.post_load).
## 7. Piety, graves, corpses, journal, Ilse: unchanged (the piety fix only acts from now on).
static func migrate_3_to_4(state: Dictionary, _meta: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var autoloads := _sub(out, "autoloads")
	var nodes := _sub(out, "nodes")
	var stats := _sub(_sub(autoloads, "GameState"), "stats")
	# 1. Tools from the player's slots onto the belt.
	var player: Variant = nodes.get(PLAYER_SAVE_ID)
	if player is Dictionary and (player as Dictionary).get("inventory") is Dictionary:
		move_tools_to_belt((player as Dictionary).inventory)
	# 2. Graves: no designed stone yet.
	var graveyard: Variant = nodes.get("graveyard")
	if graveyard is Dictionary and (graveyard as Dictionary).get("graves") is Array:
		for grave: Variant in (graveyard as Dictionary).graves:
			if grave is Dictionary and not (grave as Dictionary).get("design") is Dictionary:
				(grave as Dictionary)["design"] = {}
	# 3. Empty states for the new system nodes (nothing built, nodes full, no ready stones).
	for id: String in V4_EMPTY_NODES:
		if not nodes.get(id) is Dictionary:
			nodes[id] = {}
	# 6. The Phase-5 statistics start at 0.
	for key: StringName in V4_NEW_STATS:
		if not _has_key(stats, String(key)):
			_set_key(stats, String(key), 0)
	return out


## docs/PHASE6_DESIGN.md §5.2 steps 1–7 on a deep copy of a v4 state (run exactly once).
## 1. Player: interior_id "hut" when in_interior is true, else "".
## 2. Corpse records + room "", slot_id "", cold_windows [], service_held false, service_day 0
##    (existing keys are kept). A corpse on the table in front of the hut stays there (location
##    table, room ""): the crypt is at level 0 after the load, the old table stays active and the
##    corpse workable; only finishing crypt 1 carries it down at runtime (§2.2). Carried corpses
##    and corpses on the ground are unchanged.
## 3. Graves unchanged (old graves stay OLD).
## 4. Empty states for V5_EMPTY_NODES (level 0 everywhere, nothing lifted, no devotion, empty
##    store); SaveManager.without_absent_defaults drops them again while the world has no such node.
## 5. The decor on the crypt site is cleared at runtime (Buildings.post_load), not here.
## 6. New stats (V5_NEW_STATS) = 0; no new flags (buildings_open comes from Buildings.post_load).
## 7. dirt_y01 saves only its grade – it keeps it at its new place. Nothing to do.
static func migrate_4_to_5(state: Dictionary, _meta: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var autoloads := _sub(out, "autoloads")
	var nodes := _sub(out, "nodes")
	var stats := _sub(_sub(autoloads, "GameState"), "stats")
	# 1. The room of the gravekeeper.
	var player: Variant = nodes.get(PLAYER_SAVE_ID)
	if player is Dictionary and not (player as Dictionary).has("interior_id"):
		(player as Dictionary)["interior_id"] = "hut" if _is_true((player as Dictionary).get("in_interior")) else ""
	# 2. The new record fields (the table corpse stays on the old table).
	var corpse_state: Variant = nodes.get("corpse_manager")
	if corpse_state is Dictionary and (corpse_state as Dictionary).get("corpses") is Array:
		for r: Variant in (corpse_state as Dictionary).corpses:
			if r is Dictionary:
				for key: String in V5_RECORD_DEFAULTS:
					if not (r as Dictionary).has(key):
						(r as Dictionary)[key] = V5_RECORD_DEFAULTS[key].duplicate() if V5_RECORD_DEFAULTS[key] is Array else V5_RECORD_DEFAULTS[key]
	# 4. Empty states for the new system nodes / the shed store.
	for id: String in V5_EMPTY_NODES:
		if not nodes.get(id) is Dictionary:
			nodes[id] = {}
	# 6. The Phase-6 statistics start at 0.
	for key: StringName in V5_NEW_STATS:
		if not _has_key(stats, String(key)):
			_set_key(stats, String(key), 0)
	return out


## §5.2 step 1 on one saved Inventory state ({slots, currency}) in place: TOOL items → "tools".
## An existing "tools" dictionary is kept and extended (tolerant, idempotent).
static func move_tools_to_belt(inv_state: Dictionary) -> void:
	var belt: Dictionary = {}
	var saved_belt: Variant = inv_state.get("tools")
	if saved_belt is Dictionary:
		belt = saved_belt
	var slots: Variant = inv_state.get("slots")
	if slots is Array:
		var list: Array = slots
		for i: int in list.size():
			var slot: Variant = list[i]
			if not slot is Dictionary or (slot as Dictionary).is_empty():
				continue
			var raw_id: Variant = (slot as Dictionary).get("id")
			if not (raw_id is String or raw_id is StringName) or not is_tool_item(StringName(raw_id)):
				continue
			var id := StringName(raw_id)
			if belt.has(id) or belt.has(String(id)):
				continue
			belt[id] = 1
			var rest := _to_int((slot as Dictionary).get("amount"), 1) - 1
			if rest > 0:
				(slot as Dictionary)["amount"] = rest
			else:
				list[i] = {}
	inv_state["tools"] = belt


## The item is registered with ItemData.Category.TOOL (unknown ids are not tools).
static func is_tool_item(id: StringName) -> bool:
	if id == &"" or not Database.has_item(id):
		return false
	var item := Database.item(id) as ItemData
	return item != null and item.category == ItemData.Category.TOOL


## §5.2 step 2 on one record dictionary (in place). Existing Phase-4 fields are kept.
static func _migrate_record(r: Dictionary) -> void:
	var shrouded := _is_true(r.get("shrouded"))
	if not r.has("dress"):
		r["dress"] = CorpseRecord.DRESS_SHROUD if shrouded else CorpseRecord.DRESS_NONE
	var traits: Array[StringName] = []
	var saved_traits: Variant = r.get("traits", [])
	if saved_traits is Array:
		for t: Variant in saved_traits:
			if t is String or t is StringName:
				traits.append(StringName(str(t)))
	var examined := _is_true(r.get("examined"))
	if not r.has("exam_done"):
		r["exam_done"] = CorpseRecord.STEPS.duplicate() if examined else [] as Array[StringName]
	if not r.has("traits_revealed"):
		r["traits_revealed"] = traits.duplicate() if examined else [] as Array[StringName]
	if not r.has("finds_revealed"):
		r["finds_revealed"] = generic_finds(traits, StringName(str(r.get("cause_id", "")))) if examined else [] as Array[StringName]
	var defaults := {
		"story_id": &"", "finds_lost": [] as Array[StringName], "washed": false, "laid_out": false,
		"harvested": [] as Array[StringName], "balm_windows": PackedInt32Array(), "stench_noted": false,
	}
	for key: String in defaults:
		if not r.has(key):
			r[key] = defaults[key]


## The generic finds a Phase-2/3 examination showed at once, in step order (§2.1, §2.2):
## hands (tattoo) → wounds (mark, cause detail) → pockets (valuables, letter).
static func generic_finds(traits: Array[StringName], cause_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for t: StringName in [&"tattoo", &"strange_wound"]:
		if t in traits:
			out.append(TRAIT_FINDS[t])
	if cause_id != &"":
		out.append(StringName(CAUSE_FIND_PREFIX + String(cause_id)))
	for t: StringName in [&"valuables", &"letter"]:
		if t in traits:
			out.append(TRAIT_FINDS[t])
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


## Only a real bool true counts (damaged files may hold anything).
static func _is_true(v: Variant) -> bool:
	return typeof(v) == TYPE_BOOL and bool(v)


static func _to_int(v: Variant, default: int) -> int:
	if v is int or v is float:
		return int(v)
	return default
