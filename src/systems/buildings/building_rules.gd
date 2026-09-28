class_name BuildingRules
extends RefCounted
## Pure rules of the building levels (docs/PHASE6_DESIGN.md §2.1, §1.5, §3.4). Uses only the public
## Inventory API (count), so it works with any Inventory (also test doubles). Coins are the currency
## item &"coin". A level builds only on the previous one: no skipping, no demolition.

const TEXT_MAXED := "Voll ausgebaut."
const TEXT_MISSING := "Es fehlt: %s"
## Site while buildings_open is not set (the site is hidden then – guard only).
const TEXT_CLOSED := "Der Bauplatz ist noch nicht frei."
const COIN := &"coin"
## goal_progress().missing entries besides the building ids.
const GOAL_SERVICES := "services"
const GOAL_REINTERRED := "reinterred"


## The level after `level`; null = fully built (or no data).
static func next_level(data: BuildingData, level: int) -> BuildingLevelData:
	if data == null:
		return null
	return data.level_data(maxi(level, 0) + 1)


## "" | „Voll ausgebaut." | „Es fehlt: 2 Stein, 5 Münzen" | TEXT_CLOSED (not open / no data).
static func upgrade_block_reason(data: BuildingData, level: int, inv: Inventory, open: bool) -> String:
	if data == null:
		return TEXT_CLOSED
	var next := next_level(data, level)
	if next == null:
		return TEXT_MAXED
	if not open:
		return TEXT_CLOSED
	var gaps := missing(next, inv)
	if not gaps.is_empty():
		return TEXT_MISSING % WorkshopRules.describe(gaps)
	return ""


## {item_id_or_coin: missing amount} in inputs order, coins last; {} = everything there.
static func missing(level_data: BuildingLevelData, inv: Inventory) -> Dictionary:
	var out: Dictionary = {}
	if level_data == null:
		return out
	var valid := is_instance_valid(inv)
	for id: StringName in level_data.inputs:
		var need := int(level_data.inputs[id])
		var have := inv.count(id) if valid else 0
		if need > have:
			out[id] = need - have
	if level_data.coins > 0:
		var coins := inv.count(COIN) if valid else 0
		if level_data.coins > coins:
			out[COIN] = level_data.coins - coins
	return out


## All inputs of a level incl. the coins ({id: amount}, coins under COIN).
static func cost(level_data: BuildingLevelData) -> Dictionary:
	var out: Dictionary = {}
	if level_data == null:
		return out
	for id: StringName in level_data.inputs:
		out[id] = int(level_data.inputs[id])
	if level_data.coins > 0:
		out[COIN] = level_data.coins
	return out


## §1.5: {done, total, missing} over the goal levels (one entry per building), the held services
## (buried + marked) and the reinterred boxes. missing lists building ids, "services" and
## "reinterred". Extra keys for the HUD tooltip („Gruft 2/2 · Kapelle 1/2 · … · Umbettung 3/1"):
## levels {id: [level, goal]}, services [n, goal], reinterred [n, goal].
static func goal_progress(levels: Dictionary, services: int, reinterred: int, cfg: BuildingsConfig) -> Dictionary:
	var out := {"done": 0, "total": 0, "missing": PackedStringArray(), "levels": {}, "services": [0, 0], "reinterred": [0, 0]}
	if cfg == null:
		return out
	var missing_ids := PackedStringArray()
	var done := 0
	var per_building := {}
	for id: StringName in cfg.goal_levels:
		var goal := int(cfg.goal_levels[id])
		var have := int(levels.get(id, levels.get(String(id), 0)))
		per_building[id] = [have, goal]
		if have >= goal:
			done += 1
		else:
			missing_ids.append(String(id))
	var services_ok := services >= cfg.goal_services
	if services_ok:
		done += 1
	else:
		missing_ids.append(GOAL_SERVICES)
	var reinterred_ok := reinterred >= cfg.goal_reinterred
	if reinterred_ok:
		done += 1
	else:
		missing_ids.append(GOAL_REINTERRED)
	out.done = done
	out.total = cfg.goal_levels.size() + 2
	out.missing = missing_ids
	out.levels = per_building
	out.services = [services, cfg.goal_services]
	out.reinterred = [reinterred, cfg.goal_reinterred]
	return out
