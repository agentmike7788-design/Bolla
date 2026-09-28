class_name WorkshopRules
extends RefCounted
## Pure rules of building a station and of the chapter "Namen in Stein"
## (docs/PHASE5_DESIGN.md §2.1, §1.5, §3.4). Uses only the public Inventory API (count), so it
## works with any Inventory (also test doubles). Coins are the currency item &"coin".

const TEXT_BUILT := "Schon gebaut."
const TEXT_MISSING := "Es fehlt: %s"
## Build site while the workyard is not open yet (the site is hidden then – guard only).
const TEXT_CLOSED := "Der Werkhof ist noch nicht offen."
## Key of the coins in missing().
const COIN := &"coin"
const COIN_ONE := "Münze"
const COIN_MANY := "Münzen"
## goal_progress().missing entry of the master stone.
const GOAL_MASTER := "stone_master"


## "" | "Schon gebaut." | "Es fehlt: 2 Stein, 5 Münzen" | TEXT_CLOSED (not open). A prebuilt
## station (workbench) always counts as built.
static func build_block_reason(station: StationData, inv: Inventory, built: bool, open: bool) -> String:
	if station == null:
		return TEXT_CLOSED
	if built or station.prebuilt:
		return TEXT_BUILT
	if not open:
		return TEXT_CLOSED
	var gaps := missing(station, inv)
	if not gaps.is_empty():
		return TEXT_MISSING % describe(gaps)
	return ""


## {item_id_or_coin: missing amount} in build_inputs order, coins last; {} = everything there.
static func missing(station: StationData, inv: Inventory) -> Dictionary:
	var out: Dictionary = {}
	if station == null:
		return out
	var valid := is_instance_valid(inv)
	for id: StringName in station.build_inputs:
		var need := int(station.build_inputs[id])
		var have := inv.count(id) if valid else 0
		if need > have:
			out[id] = need - have
	if station.build_coins > 0:
		var coins := inv.count(COIN) if valid else 0
		if station.build_coins > coins:
			out[COIN] = station.build_coins - coins
	return out


## "2 Stein, 5 Münzen" (item display names from the Database, the id when unknown).
static func describe(gaps: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: Variant in gaps:
		var n := int(gaps[id])
		parts.append("%d %s" % [n, amount_name(StringName(id), n)])
	return ", ".join(parts)


## Display name of an input: "Münze"/"Münzen" for coins, else the item name.
static func amount_name(id: StringName, n: int) -> String:
	if id == COIN:
		return COIN_ONE if n == 1 else COIN_MANY
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)


## §1.5: {done, total, missing} over the goal stations, the goal tool tiers and the master
## stones (one entry). missing lists station ids, tool kinds and "stone_master". Extra keys for
## the HUD tooltip ("Werkhof 2/3 · Werkzeug 2/3 · Meisterstein 0/1"): stations, tools, master
## – each [done, total].
static func goal_progress(built: Array[StringName], tiers: Dictionary, master_stones: int, cfg: WorkshopConfig) -> Dictionary:
	var out := {"done": 0, "total": 0, "missing": PackedStringArray(), "stations": [0, 0], "tools": [0, 0], "master": [0, 0]}
	if cfg == null:
		return out
	var missing_ids := PackedStringArray()
	var stations_done := 0
	for id: StringName in cfg.goal_stations:
		if built.has(id):
			stations_done += 1
		else:
			missing_ids.append(String(id))
	var tools_done := 0
	for kind: StringName in cfg.goal_tiers:
		if int(tiers.get(kind, 0)) >= int(cfg.goal_tiers[kind]):
			tools_done += 1
		else:
			missing_ids.append(String(kind))
	var master_goal := maxi(cfg.goal_master_stones, 0)
	var master_ok := master_stones >= master_goal
	if not master_ok:
		missing_ids.append(GOAL_MASTER)
	out.done = stations_done + tools_done + (1 if master_ok else 0)
	out.total = cfg.goal_stations.size() + cfg.goal_tiers.size() + 1
	out.missing = missing_ids
	out.stations = [stations_done, cfg.goal_stations.size()]
	out.tools = [tools_done, cfg.goal_tiers.size()]
	out.master = [mini(master_stones, master_goal), master_goal]
	return out
