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
## Phase 4 (docs/PHASE4_DESIGN.md §7), `world` keys from CemeteryStatus.phase4_state():
##   - a corpse on the table whose next find is lost within LOSS_HINT_MINUTES (table_loss):
##     „Spuren verblassen – untersuchen oder räuchern“ in place of its corpse step
##   - after the corpse chain, before the Phase-3 goals: „Merkbuch: Hinweise passen zusammen“
##     (journal_ready) and „Eine Grube wartet noch“ (story_pending > 0 and the free plots are
##     all held for the story dead)
##   - a gated section (the Holunderwinkel) not started yet but open to work: „… aufschließen“
## Phase 5 (docs/PHASE5_DESIGN.md §7), `world` keys from CemeteryStatus.phase5_state() – after the
## corpse chain, the Phase-4 goals, the sections and the tending (care keeps the cemetery's
## rating, so it stays first): „Holzkohle ist fertig“ · „Ein Stein liegt bereit – setz ihn bei …“
## · „Sprich mit Osric über den Bruch“ · „Ostpforte aufschließen“ · „Bauplatz: <Station> bauen“
## (the next affordable first) · „Findlinge brechen – Spitzhacke nötig“ · „Werkzeug: …“ ·
## „Setz den Meisterstein“; in the idle slot „Gräber ohne Namen: n“.
## Phase 6 (docs/PHASE6_DESIGN.md §7), `world` keys from CemeteryStatus.phase6_state(): in the corpse
## chain „Bring die Leiche in die Gruft“ (instead of „zum Leichentisch“ once the crypt stands), „Die
## Kapelle steht – leg <Name> auf den Katafalk“ (a dressed, examined dead, not serviced, 08:00–17:00)
## and „Aussegnung am Altar halten“ (on the catafalque); corpses in a niche or on the catafalque
## count as unburied. After the Phase-5 line: Phase6Texts.objective (Osric · Bauplatz: Gruft ·
## Gebeine beisetzen · Altes Grab heben / Gebeinkiste zimmern · Hinter dem Beinhaus zieht es kalt ·
## „Kapelle 2 · Gruft 2 · Schuppen 2“ · „Eine Andacht für <Name>?“).

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
const TEXT_LOSS := "Spuren verblassen – untersuchen oder räuchern"
const TEXT_JOURNAL_READY := "Merkbuch: Hinweise passen zusammen"
const TEXT_RESERVED := "Eine Grube wartet noch"
const TEXT_UNLOCK_GATE := "%s aufschließen"
## „Spuren verblassen …“ while the next loss is at most this far away (§7).
const LOSS_HINT_MINUTES := 120
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
const LOCATION_ORDER: Array[StringName] = [&"carried", &"catafalque", &"table", &"niche", &"ground", &"dropoff"]
const LOCATION_CATAFALQUE := &"catafalque"


static func current(corpses: Array[CorpseRecord], graves: Array[GraveRecord], inv: Inventory, minute_of_day: int, flags: Dictionary, world: Dictionary = {}) -> String:
	var active := _active_corpse(corpses)
	var table_taken := _table_taken_by_other(corpses, active)
	if active != null and active.location == LOCATION_CARRIED:
		return _no_plot_fallback(_corpse_step(active, graves, inv, table_taken, world, minute_of_day), world)
	if _has_state(graves, GraveRecord.State.FILLED):
		return _marker_step(inv)
	if active != null:
		if active.location == LOCATION_TABLE and _loss_soon(world):
			return TEXT_LOSS
		return _no_plot_fallback(_corpse_step(active, graves, inv, table_taken, world, minute_of_day), world)
	if _count_ready(world) > 0:
		return TEXT_JOURNAL_READY
	if _reserved(graves, world):
		return TEXT_RESERVED
	if _free_plots(graves) <= SECTION_FREE_MAX:
		var section := _section_step(world)
		if section != "":
			return section
	var care := _care_step(world, inv)
	if care != "":
		return care
	var workshop := _phase5_step(world)
	if workshop != "":
		return workshop
	var buildings := Phase6Texts.objective(world)
	if buildings != "":
		return buildings
	if _ghost_night(graves, minute_of_day, flags):
		return TEXT_GHOST_NIGHT
	return _idle_step(minute_of_day, flags, world)


## Phase-5 line of the workyard (§7) or "" (no Phase-5 state / nothing to do but naming graves).
static func _phase5_step(world: Dictionary) -> String:
	if not bool(world.get("p5", false)):
		return ""
	if bool(world.get("kiln_ready", false)):
		return Phase5Texts.OBJ_KILN
	var ready := str(world.get("stone_ready", ""))
	if ready != "":
		return Phase5Texts.OBJ_STONE_READY % ready
	if not bool(world.get("license", false)):
		return Phase5Texts.OBJ_OSRIC
	if not bool(world.get("bruch_open", true)):
		return Phase5Texts.OBJ_GATE
	var sites: Array = world.get("sites", [])
	if not sites.is_empty():
		var pick: Dictionary = sites[0]
		for site: Dictionary in sites:
			if bool(site.get("affordable", false)):
				pick = site
				break
		return Phase5Texts.OBJ_BUILD % str(pick.get("name", ""))
	var tiers: Dictionary = world.get("tiers", {})
	if not bool(world.get("quarry_open", true)):
		return Phase5Texts.OBJ_BOULDERS if int(tiers.get(&"pickaxe", 0)) >= 1 else Phase5Texts.OBJ_BOULDERS_TOOL
	if bool(world.get("goal_done", false)):
		return ""
	var missing: PackedStringArray = world.get("goal_missing", PackedStringArray())
	var goal_tiers: Dictionary = world.get("goal_tiers", {})
	for kind: Variant in goal_tiers:
		if String(kind) in missing:
			return Phase5Texts.OBJ_TOOLS % Phase5Texts.tool_goal_text(tiers, goal_tiers, Database.config(&"tool_config") as ToolConfig)
	if WorkshopRules.GOAL_MASTER in missing:
		return Phase5Texts.OBJ_MASTER
	return ""


## Next section to clear: the first locked one that can be worked on, else the first locked
## one with its prerequisite; "" when every section is open (or no sections are known).
static func _section_step(world: Dictionary) -> String:
	var blocked := ""
	for raw: Variant in world.get("sections", []):
		var s := raw as Dictionary
		if s == null or bool(s.get("unlocked", true)):
			continue
		var block := str(s.get("block", ""))
		if block == "" and bool(s.get("gate", false)) and int(s.get("done", 0)) == 0:
			return TEXT_UNLOCK_GATE % str(s.get("name", ""))
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


## The next find of the table corpse is lost within LOSS_HINT_MINUTES (world.table_loss ≥ 0).
static func _loss_soon(world: Dictionary) -> bool:
	var loss := int(world.get("table_loss", -1))
	return loss >= 0 and loss <= LOSS_HINT_MINUTES


static func _count_ready(world: Dictionary) -> int:
	var ready: Variant = world.get("journal_ready", [])
	if ready is PackedStringArray:
		return (ready as PackedStringArray).size()
	return (ready as Array).size() if ready is Array else 0


## Story dead still to come and every free plot is held for them (no random corpse today).
static func _reserved(graves: Array[GraveRecord], world: Dictionary) -> bool:
	var pending := int(world.get("story_pending", 0))
	var free := _free_plots(graves)
	return pending > 0 and free > 0 and free <= pending


## "Keine freie Grabstelle mehr" → the section that brings new plots, if any.
static func _no_plot_fallback(step: String, world: Dictionary) -> String:
	if step != TEXT_NO_PLOT:
		return step
	var section := _section_step(world)
	return section if section != "" else step


## Next step for one unburied corpse. `table_taken`: another corpse lies on the table.
static func _corpse_step(corpse: CorpseRecord, graves: Array[GraveRecord], inv: Inventory, table_taken: bool = false,
		world: Dictionary = {}, minute_of_day: int = -1) -> String:
	if not corpse.examined and corpse.location == LOCATION_TABLE:
		return TEXT_EXAMINE
	if not corpse.examined and not table_taken:
		return Phase6Texts.OBJ_TO_CRYPT if int(world.get("crypt_level", 0)) >= 1 else TEXT_TO_TABLE
	if not corpse.examined and corpse.location == LOCATION_CARRIED and not _has_state(graves, GraveRecord.State.DUG):
		# The table is occupied and digging needs free hands.
		return TEXT_TABLE_BUSY
	# The decision is made at the table; burying elsewhere leaves the valuables (M3).
	if corpse.location == &"table" and corpse.needs_valuables_decision():
		return TEXT_DECIDE
	if corpse.location == &"table" and not corpse.shrouded and _count(inv, SHROUD_ITEM) > 0:
		return TEXT_SHROUD % _economy().quality_shroud
	var chapel := _chapel_step(corpse, world, minute_of_day)
	if chapel != "":
		return chapel
	if _has_state(graves, GraveRecord.State.DUG):
		return TEXT_BURY
	if _has_state(graves, GraveRecord.State.EMPTY):
		return TEXT_DIG
	return TEXT_NO_PLOT


## Phase 6: the chapel for a dressed, examined dead without a service, while services may begin.
static func _chapel_step(corpse: CorpseRecord, world: Dictionary, minute_of_day: int) -> String:
	if int(world.get("chapel_level", 0)) < 1 or corpse.service_held or not corpse.examined or minute_of_day < 0:
		return ""
	var cfg := Database.config(&"chapel_config") as ChapelConfig
	if cfg == null:
		cfg = ChapelConfig.new()
	var m := posmod(minute_of_day, TimeManager.MINUTES_PER_DAY)
	if m < cfg.service_start_min or m > cfg.service_start_max or not ChapelRules.is_dressed(corpse) or corpse.freshness < cfg.service_min_freshness:
		return ""
	if corpse.location == LOCATION_CATAFALQUE:
		return Phase6Texts.OBJ_SERVICE
	return Phase6Texts.OBJ_CATAFALQUE % corpse.display_name


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
	var nameless := int(world.get("nameless", 0))
	if bool(world.get("p5", false)) and nameless > 0:
		return Phase5Texts.OBJ_NAMELESS % nameless
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
