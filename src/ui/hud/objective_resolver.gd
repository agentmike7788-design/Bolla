class_name ObjectiveResolver
extends RefCounted
## Pure: the current objective line for the HUD (docs §1, §7; Phase 3: PHASE3_DESIGN §7).
## Reads only its arguments plus static game data (time config, corpse tables, recipes,
## economy config) – never live game state. `slice_complete` is no longer read (§2.7).
## `world` = CemeteryStatus.objective_state() ({} in Phase-2 worlds / tests). Priority:
##   1. the carried corpse (table → examine → dig → bury; an occupied table is skipped)
##   2. a buried grave without marker (FILLED)
##   3. another unburied corpse (table before ground before dropoff) – with no free plot left
##      the next section to clear is named instead of "Keine freie Grabstelle mehr"
##   4. clear a section (only while ≤ 1 plot is free): "Ostwiese freilegen: 3/10", or its
##      prerequisite ("Birkenhang: Erst Friedhof „Würdevoll“ (50)")
##   5. tending spots of level ≥ 2: "Unkraut jäten (3 Stellen)" → "Laub harken (2 Stellen)" →
##      rake missing for leaves
##   6. the first ghost night (21:00 … 04:30, until a ghost was heard – flag ghosts_seen)
##   7. idle: wait for the carter / sleep by clock time; otherwise (rest) the next cemetery
##      goal once „Würdevoll“ is reached / after cemetery_complete: „Friedhof: Ehrwürdig ab 100“

const TEXT_WAIT_CARTER := "Der Leichenkutscher kommt gegen %s"
const TEXT_TO_TABLE := "Leiche zum Leichentisch bringen"
const TEXT_TABLE_BUSY := "Tisch belegt – Leiche mit [Q] ablegen"
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
const TEXT_SECTION := "%s freilegen: %d/%d"
const TEXT_SECTION_BLOCKED := "%s: %s"
const TEXT_WEEDS := "Unkraut jäten (%d %s)"
const TEXT_LEAVES := "Laub harken (%d %s)"
const TEXT_RAKE := "Laub liegt – Rechen an der Werkbank bauen"
const TEXT_GHOST_NIGHT := "Etwas regt sich zwischen den Gräbern …"
const TEXT_VENERABLE := "Friedhof: %s ab %d (jetzt %d)"
const TEXT_COMPLETE := "Der Friedhof ist vollendet und %s"
const SPOT_ONE := "Stelle"
const SPOT_MANY := "Stellen"
## Phase-3 goal (§1.3) and the rating from which the idle line names it.
const GOAL_RATING := &"venerable"
const GOAL_HINT_FROM := &"dignified"
const FLAG_CEMETERY_COMPLETE := &"cemetery_complete"
const FLAG_GHOSTS_SEEN := &"ghosts_seen"
## Ghost-night hint window (21:00 … 04:30, GhostConfig appear 21:30 / vanish 04:30).
const GHOST_HINT_FROM := 1260
const GHOST_HINT_UNTIL := 270
## A section step is shown while at most this many plots are free (§7).
const SECTION_FREE_MAX := 1
const LOCATION_TABLE := &"table"
const LOCATION_CARRIED := &"carried"

const SHROUD_ITEM := &"shroud"
## Cheapest marker, suggested when the player owns none (recipe of the same id).
const HINT_MARKER := &"wooden_cross"
## Fallbacks when data is missing (mirror data/*.tres defaults).
const DEFAULT_DELIVERY_MINUTE := 460
## Unburied corpses by urgency: lower index first.
const LOCATION_ORDER: Array[StringName] = [&"carried", &"table", &"ground", &"dropoff"]


static func current(corpses: Array[CorpseRecord], graves: Array[GraveRecord], inv: Inventory, minute_of_day: int, flags: Dictionary, world: Dictionary = {}) -> String:
	var active := _active_corpse(corpses)
	var table_taken := _table_taken_by_other(corpses, active)
	if active != null and active.location == LOCATION_CARRIED:
		return _no_plot_fallback(_corpse_step(active, graves, inv, table_taken), world)
	if _has_state(graves, GraveRecord.State.FILLED):
		return _marker_step(inv)
	if active != null:
		return _no_plot_fallback(_corpse_step(active, graves, inv, table_taken), world)
	if _free_plots(graves) <= SECTION_FREE_MAX:
		var section := _section_step(world)
		if section != "":
			return section
	var care := _care_step(world, inv)
	if care != "":
		return care
	if _ghost_night(graves, minute_of_day, flags):
		return TEXT_GHOST_NIGHT
	return _idle_step(minute_of_day, flags, world)


## Next section to clear: the first locked one that can be worked on, else the first locked
## one with its prerequisite; "" when every section is open (or no sections are known).
static func _section_step(world: Dictionary) -> String:
	var blocked := ""
	for raw: Variant in world.get("sections", []):
		var s := raw as Dictionary
		if s == null or bool(s.get("unlocked", true)):
			continue
		var block := str(s.get("block", ""))
		if block == "":
			return TEXT_SECTION % [str(s.get("name", "")), int(s.get("done", 0)), int(s.get("total", 0))]
		if blocked == "":
			blocked = TEXT_SECTION_BLOCKED % [str(s.get("name", "")), block]
	return blocked


static func _care_step(world: Dictionary, inv: Inventory) -> String:
	var weeds := int(world.get("weeds", 0))
	var leaves := int(world.get("leaves", 0))
	if weeds > 0:
		return TEXT_WEEDS % [weeds, SPOT_ONE if weeds == 1 else SPOT_MANY]
	if leaves > 0:
		var rake := bool(world.get("has_rake", false)) or _count(inv, &"rake") > 0
		return TEXT_LEAVES % [leaves, SPOT_ONE if leaves == 1 else SPOT_MANY] if rake else TEXT_RAKE
	return ""


## Night window, a ghost can walk (a MARKED grave) and none was heard yet.
static func _ghost_night(graves: Array[GraveRecord], minute_of_day: int, flags: Dictionary) -> bool:
	if _flag(flags, FLAG_GHOSTS_SEEN) or not _has_state(graves, GraveRecord.State.MARKED):
		return false
	var m := posmod(minute_of_day, TimeManager.MINUTES_PER_DAY)
	return m >= GHOST_HINT_FROM or m < GHOST_HINT_UNTIL


## "Keine freie Grabstelle mehr" → the section that brings new plots, if any.
static func _no_plot_fallback(step: String, world: Dictionary) -> String:
	if step != TEXT_NO_PLOT:
		return step
	var section := _section_step(world)
	return section if section != "" else step


## Next step for one unburied corpse. `table_taken`: another corpse lies on the table.
static func _corpse_step(corpse: CorpseRecord, graves: Array[GraveRecord], inv: Inventory, table_taken: bool = false) -> String:
	if not corpse.examined and corpse.location == LOCATION_TABLE:
		return TEXT_EXAMINE
	if not corpse.examined and not table_taken:
		return TEXT_TO_TABLE
	if not corpse.examined and corpse.location == LOCATION_CARRIED and not _has_state(graves, GraveRecord.State.DUG):
		# The table is occupied and digging needs free hands.
		return TEXT_TABLE_BUSY
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


## Idle "rest" slot: the next cemetery goal once „Würdevoll“ is reached (or after the phase
## goal); "" otherwise.
static func _goal_step(flags: Dictionary, world: Dictionary) -> String:
	if not world.has("total"):
		return ""
	var total := int(world.get("total", 0))
	var rating := StringName(str(world.get("rating", "")))
	var index := CemeteryRating.TIERS.find(rating)
	var goal_index := CemeteryRating.TIERS.find(GOAL_RATING)
	if index >= goal_index and _flag(flags, FLAG_CEMETERY_COMPLETE):
		return TEXT_COMPLETE % CemeteryRating.label(GOAL_RATING).to_lower()
	if index >= goal_index:
		return ""
	if not _flag(flags, FLAG_CEMETERY_COMPLETE) and index < CemeteryRating.TIERS.find(GOAL_HINT_FROM):
		return ""
	return TEXT_VENERABLE % [CemeteryRating.label(GOAL_RATING), _goal_threshold(), total]


static func _goal_threshold() -> int:
	var thresholds := _economy().rating_thresholds
	var index := CemeteryRating.TIERS.find(GOAL_RATING) - 1
	return thresholds[index] if index >= 0 and index < thresholds.size() else 100


static func _free_plots(graves: Array[GraveRecord]) -> int:
	var n := 0
	for grave: GraveRecord in graves:
		if grave != null and (grave.state == GraveRecord.State.EMPTY or grave.state == GraveRecord.State.DUG):
			n += 1
	return n


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


## Before wake-up or from sleep time on: sleep; before the delivery (not after the phase goal –
## no plot is free any more): wait; else the cemetery goal or rest.
static func _idle_step(minute_of_day: int, flags: Dictionary = {}, world: Dictionary = {}) -> String:
	var time_cfg := _time_config()
	var minute := posmod(minute_of_day, TimeManager.MINUTES_PER_DAY)
	if minute < time_cfg.wake_minute or minute >= time_cfg.sleep_from_minute:
		return TEXT_SLEEP
	var delivery := _delivery_minute()
	if minute < delivery and not _flag(flags, FLAG_CEMETERY_COMPLETE):
		return TEXT_WAIT_CARTER % UIKit.clock(delivery)
	var goal := _goal_step(flags, world)
	return goal if goal != "" else TEXT_REST


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


## True when a corpse other than `corpse` lies on the table.
static func _table_taken_by_other(corpses: Array[CorpseRecord], corpse: CorpseRecord) -> bool:
	for other: CorpseRecord in corpses:
		if other != null and other != corpse and other.location == LOCATION_TABLE:
			return true
	return false


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
	return EconomyConfig.resolve()


static func _delivery_minute() -> int:
	var tables := Database.corpse_tables() as CorpseTables
	return tables.delivery_minute if tables != null else DEFAULT_DELIVERY_MINUTE
