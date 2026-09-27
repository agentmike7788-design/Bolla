class_name ObjectiveResolver
extends RefCounted
## Pure: the current objective line for the HUD (docs §1, §7).
## Reads only its arguments plus static game data (time config, corpse tables, recipes,
## economy config) – never live game state. Priority:
##   1. slice complete
##   2. the carried corpse (table → examine → dig → bury)
##   3. a buried grave without marker (FILLED)
##   4. another unburied corpse (table before ground before dropoff)
##   5. idle: wait for the carter / rest / sleep, by clock time

const TEXT_WAIT_CARTER := "Der Leichenkutscher kommt gegen %s"
const TEXT_TO_TABLE := "Leiche zum Leichentisch bringen"
const TEXT_EXAMINE := "Leiche untersuchen"
const TEXT_DECIDE := "Über die Wertsachen entscheiden"
const TEXT_SHROUD := "Leichentuch anlegen (+%d Qualität)"
const TEXT_DIG := "Grab ausheben"
const TEXT_BURY := "Leiche bestatten"
const TEXT_NO_PLOT := "Keine freie Grabstelle mehr"
const TEXT_MARKER := "Grabzeichen setzen"
const TEXT_MARKER_CRAFT := "Grabzeichen setzen (Werkbank: %s = %s)"
const TEXT_REST := "Feierabend – Ausruhen an der Hüttentür"
const TEXT_SLEEP := "Feierabend – Schlafen an der Hüttentür"
const TEXT_COMPLETE := "Alle Gräber vollendet – der Friedhof ruht in Würde"

const FLAG_SLICE_COMPLETE := &"slice_complete"
const SHROUD_ITEM := &"shroud"
## Cheapest marker, suggested when the player owns none (recipe of the same id).
const HINT_MARKER := &"wooden_cross"
## Fallbacks when data is missing (mirror data/*.tres defaults).
const DEFAULT_DELIVERY_MINUTE := 460
## Unburied corpses by urgency: lower index first.
const LOCATION_ORDER: Array[StringName] = [&"carried", &"table", &"ground", &"dropoff"]


static func current(corpses: Array[CorpseRecord], graves: Array[GraveRecord], inv: Inventory, minute_of_day: int, flags: Dictionary) -> String:
	if _flag(flags, FLAG_SLICE_COMPLETE):
		return TEXT_COMPLETE
	var active := _active_corpse(corpses)
	if active != null and active.location == &"carried":
		return _corpse_step(active, graves, inv)
	if _has_state(graves, GraveRecord.State.FILLED):
		return _marker_step(inv)
	if active != null:
		return _corpse_step(active, graves, inv)
	return _idle_step(minute_of_day)


## Next step for one unburied corpse.
static func _corpse_step(corpse: CorpseRecord, graves: Array[GraveRecord], inv: Inventory) -> String:
	if not corpse.examined:
		return TEXT_EXAMINE if corpse.location == &"table" else TEXT_TO_TABLE
	# The decision is made at the table; burying elsewhere leaves the valuables (M3).
	if corpse.location == &"table" and corpse.needs_valuables_decision():
		return TEXT_DECIDE
	if corpse.location == &"table" and not corpse.shrouded and _count(inv, SHROUD_ITEM) > 0:
		return TEXT_SHROUD % _economy().quality_shroud
	if _has_state(graves, GraveRecord.State.DUG):
		return TEXT_BURY
	if _has_state(graves, GraveRecord.State.EMPTY):
		return TEXT_DIG
	return TEXT_NO_PLOT


static func _marker_step(inv: Inventory) -> String:
	for marker: StringName in _economy().marker_quality:
		if _count(inv, marker) > 0:
			return TEXT_MARKER
	var recipe := Database.recipe(HINT_MARKER) as RecipeData
	if recipe == null or recipe.inputs.is_empty():
		return TEXT_MARKER
	var parts: PackedStringArray = []
	for id: StringName in recipe.inputs:
		parts.append("%d %s" % [recipe.inputs[id], UIKit.item_name(id)])
	var marker_name := recipe.display_name if recipe.display_name != "" else UIKit.item_name(recipe.output_id)
	return TEXT_MARKER_CRAFT % [marker_name, " + ".join(parts)]


## Before wake-up or from sleep time on: sleep; before the delivery: wait; else rest.
static func _idle_step(minute_of_day: int) -> String:
	var time_cfg := _time_config()
	var minute := posmod(minute_of_day, TimeManager.MINUTES_PER_DAY)
	if minute < time_cfg.wake_minute or minute >= time_cfg.sleep_from_minute:
		return TEXT_SLEEP
	var delivery := _delivery_minute()
	if minute < delivery:
		return TEXT_WAIT_CARTER % UIKit.clock(delivery)
	return TEXT_REST


## The most urgent unburied corpse (LOCATION_ORDER, then list order); null if none.
static func _active_corpse(corpses: Array[CorpseRecord]) -> CorpseRecord:
	var best: CorpseRecord = null
	var best_rank := LOCATION_ORDER.size()
	for corpse: CorpseRecord in corpses:
		if corpse == null:
			continue
		var rank := LOCATION_ORDER.find(corpse.location)
		if rank >= 0 and rank < best_rank:
			best = corpse
			best_rank = rank
	return best


static func _has_state(graves: Array[GraveRecord], state: GraveRecord.State) -> bool:
	for grave: GraveRecord in graves:
		if grave != null and grave.state == state:
			return true
	return false


static func _count(inv: Inventory, id: StringName) -> int:
	return inv.count(id) if is_instance_valid(inv) else 0


static func _flag(flags: Dictionary, name: StringName) -> bool:
	var value: Variant = flags.get(name, false)
	return value is bool and value


static func _time_config() -> TimeConfig:
	var cfg := Database.config(&"time_config") as TimeConfig
	return cfg if cfg != null else TimeConfig.new()


static func _economy() -> EconomyConfig:
	var cfg := Database.config(&"economy_config") as EconomyConfig
	return cfg if cfg != null else EconomyConfig.new()


static func _delivery_minute() -> int:
	var tables := Database.corpse_tables() as CorpseTables
	return tables.delivery_minute if tables != null else DEFAULT_DELIVERY_MINUTE
