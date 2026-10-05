class_name Graveyard
extends Node
## Owns all GraveRecords (WorldRoot/Systems/Graveyard). Groups graveyard + saveable.
## _ready collects the grave_plot nodes (grave_id, is_old, section_id) as EMPTY / OLD records –
## LOCKED for plots of a section that does not start unlocked (Phase 3, unlock_section).
## States: EMPTY -dig-> DUG -bury-> FILLED -place_marker-> MARKED (-upgrade_marker-> MARKED);
## OLD -lift_old-> EMPTY (Phase 6, old plots only; load_state keeps their saved state); LOCKED -unlock_section-> EMPTY.
## Reputation events (grave finished good / poor, marker upgraded) go directly to the node in
## group "reputation"; the cemetery quality signal comes from CemeteryScore (Phase 3).

const GROUP := &"graveyard"
const SAVEABLE_GROUP := &"saveable"
const PLOT_GROUP := &"grave_plot"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const COIN_ITEM := &"coin"
const STAT_BURIALS := &"burials"
const STAT_REPUTATION := &"reputation"
const REPUTATION_GROUP := &"reputation"
const SCORE_GROUP := &"cemetery_score"
const DECOR_GROUP := &"decorations"
const CLEANLINESS_GROUP := &"cleanliness"
const GHOSTS_GROUP := &"ghosts"
const FLAG_CEMETERY_COMPLETE := &"cemetery_complete"
const SLICE_SUMMARY_PANEL := &"slice_summary"
const VARIANT_CEMETERY := &"cemetery"
const DEFAULT_SECTION := &"yard"
const PAYMENT_REASON := "Bestattung von %s"
const REASON_GRAVE := "Grab von %s"
const REASON_UPGRADE := "Grabzeichen von %s aufgewertet"
const EVENT_GRAVE_GOOD := &"grave_good"
const EVENT_GRAVE_POOR := &"grave_poor"
const EVENT_MARKER_UPGRADE := &"marker_upgrade"
# Phase 4 (docs/PHASE4_DESIGN.md §1.3, §2.7, §3.4)
const PIETY_GROUP := &"piety"
const JOURNAL_GROUP := &"journal"
const EVENT_BARE_BURIAL := &"bare_burial"
const EVENT_ROTTEN_BURIAL := &"rotten_burial"
const REASON_BARE_BURIAL := "%s ohne Leichentuch bestattet"
const REASON_ROTTEN_BURIAL := "%s verfallen bestattet"
const CHAPTER_SIX_PITS := &"six_pits"
const FLAG_NOT_LORENZ := &"insight_not_lorenz"
const STAT_PREPARED := &"prepared"
const STAT_UTILIZED := &"utilized"
const STAT_PIETY := &"piety"
# Phase 5 (docs/PHASE5_DESIGN.md §2.5, §2.7)
const WORKSHOP_GROUP := &"workshop"
const BUILDINGS_GROUP := &"buildings"
const STAT_STONES_SET := &"stones_set"
const SHAPE_MASTER := &"stone_master"
const EVENT_MASTER_STONE := &"master_stone"
const REASON_MASTER_STONE := "Ein Meisterstein auf dem Friedhof. Das spricht sich herum."
# Phase 7 (docs/PHASE7_DESIGN.md §2.5, §3.3): orders hear of graves and stones directly.
const ORDERS_GROUP := &"orders"
const REASON_NEW_OLD_STONE := "Ein neuer Stein für %s"

@export var save_id: String = "graveyard"
@export var save_order: int = 10

## Quality points, payment and rating; null = Database.config(&"economy_config").
var economy: EconomyConfig
## Base payment per cause; null = Database.corpse_tables().
var tables: CorpseTables
## Payment bonus and good / poor grave limits; null = Database.config(&"reputation_config").
var reputation_config: ReputationConfig
## Sections (which start unlocked); empty = Database.sections().
var section_data: Array[SectionData] = []
## Finale story of the chapter six_pits; null = Database.config(&"story_config").
var story_config: StoryConfig
## Stone surcharges (inscription / fitting / gilded points); null = Database.config(&"stone_config").
var stone_config: StoneConfig

## id -> record, in plot (tree) order.
var _graves: Dictionary[String, GraveRecord] = {}
## grave id -> section id of its plot (only graves with a plot in this world).
var _plot_sections: Dictionary[String, StringName] = {}
## Phase 6 (P3): ids of the is_old plots (old graves stay old plots after lift_old).
var _old_plots: Dictionary[String, bool] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


func _ready() -> void:
	_graves = _collect_plots()
	EventBus.world_ready.connect(_on_world_ready)


func graves() -> Array[GraveRecord]:
	var out: Array[GraveRecord] = []
	out.assign(_graves.values())
	return out


func get_grave(id: String) -> GraveRecord:
	return _graves.get(id) as GraveRecord


## EMPTY + DUG graves.
func free_plot_count() -> int:
	var count := 0
	for grave: GraveRecord in _graves.values():
		if grave.state == GraveRecord.State.EMPTY or grave.state == GraveRecord.State.DUG:
			count += 1
	return count


## EMPTY -> DUG.
func dig(id: String) -> bool:
	var grave := _known_grave(id, "dig")
	if grave == null or grave.state != GraveRecord.State.EMPTY:
		return false
	grave.state = GraveRecord.State.DUG
	EventBus.grave_state_changed.emit(id, grave.state)
	return true


## DUG -> FILLED: corpse_manager.mark_buried, stats.burials + 1, then grave_state_changed, corpse_buried.
func bury(grave_id: String, corpse_id: String) -> bool:
	var grave := _known_grave(grave_id, "bury")
	if grave == null or grave.state != GraveRecord.State.DUG:
		return false
	var corpses := _corpse_manager()
	var corpse: CorpseRecord = corpses.get_record(corpse_id) if corpses != null else null
	if corpse == null or corpse.location == CorpseRecord.LOCATION_BURIED:
		push_warning("[Graveyard] bury: no unburied corpse '%s'" % corpse_id)
		return false
	grave.state = GraveRecord.State.FILLED
	grave.corpse_id = corpse_id
	corpses.mark_buried(corpse_id, grave_id)
	GameState.add_stat(STAT_BURIALS, 1)
	_burial_piety(corpse)
	EventBus.grave_state_changed.emit(grave_id, grave.state)
	EventBus.corpse_buried.emit(corpse_id, grave_id)
	_check_chapter()
	return true


## FILLED -> MARKED: takes the marker item from inv, stores quality + breakdown + completed_day
## and pays coins into inv (GraveQuality.payment_parts incl. the reputation bonus). Signals:
## grave_state_changed, grave_completed, payment_received; then the reputation event
## (quality >= grave_good_min / <= grave_poor_max) and the cemetery completion.
## Returns the payment (0 when refused).
func place_marker(grave_id: String, marker_id: StringName, inv: Inventory) -> int:
	var grave := _known_grave(grave_id, "place_marker")
	if grave == null or grave.state != GraveRecord.State.FILLED:
		return 0
	var cfg := _economy()
	if not cfg.marker_quality.has(marker_id) or StoneDesignRules.is_shape(marker_id):
		push_warning("[Graveyard] place_marker: '%s' is no grave marker item" % marker_id)
		return 0
	if inv == null:
		push_warning("[Graveyard] place_marker without inventory")
		return 0
	var corpse := _corpse_of(grave)
	if corpse == null:
		push_warning("[Graveyard] place_marker: corpse '%s' of grave '%s' unknown" % [grave.corpse_id, grave_id])
		return 0
	if not inv.remove_item(marker_id, 1):
		return 0
	var lines: Array = []
	lines.append_array(GraveQuality.breakdown(corpse, marker_id, cfg))
	grave.state = GraveRecord.State.MARKED
	grave.marker_id = marker_id
	grave.quality = GraveQuality.compute(corpse, marker_id, cfg)
	grave.breakdown = lines
	grave.completed_day = TimeManager.day
	var rep := _reputation()
	var rep_cfg := _reputation_config()
	var parts := GraveQuality.payment_parts(corpse, grave.quality, _tables(), cfg, rep.tier() if rep != null else &"", rep_cfg)
	var paid := int(parts.total)
	if paid > 0:
		inv.add_item(COIN_ITEM, paid)
	EventBus.grave_state_changed.emit(grave_id, grave.state)
	EventBus.grave_completed.emit(grave_id, grave.corpse_id, grave.quality, lines.duplicate(true))
	EventBus.payment_received.emit(paid, PAYMENT_REASON % corpse.display_name)
	if rep != null:
		if grave.quality >= rep_cfg.grave_good_min:
			rep.event(EVENT_GRAVE_GOOD, REASON_GRAVE % corpse.display_name)
		elif grave.quality <= rep_cfg.grave_poor_max:
			rep.event(EVENT_GRAVE_POOR, REASON_GRAVE % corpse.display_name)
	_check_cemetery_complete()
	_check_chapter()
	_check_buildings_goal(corpse)
	_note_orders_grave(grave_id, grave.corpse_id)
	return paid


## Sum of MARKED qualities; OLD graves count economy.old_grave_quality each.
func total_quality() -> int:
	var cfg := _economy()
	var total := 0
	for grave: GraveRecord in _graves.values():
		if grave.state == GraveRecord.State.MARKED:
			total += grave.quality
		elif grave.state == GraveRecord.State.OLD:
			total += cfg.old_grave_quality
	return total


## CemeteryScore.rating() (Phase 4 §2.14: "Ehrwürdig" gated by decor and tending) when the world
## has one; otherwise the graves-only Phase-2 rating (tests, fixture worlds).
func rating() -> StringName:
	var score := _first(SCORE_GROUP)
	if score != null and score.has_method(&"rating"):
		var gated: StringName = score.call(&"rating")
		if gated != &"":
			return gated
	return CemeteryRating.rating(total_quality(), _economy())


## grave_state_changed for every grave (cemetery_quality_changed: CemeteryScore, Phase 3).
func broadcast_state() -> void:
	for grave: GraveRecord in _graves.values():
		EventBus.grave_state_changed.emit(grave.id, grave.state)


func save_state() -> Dictionary:
	var list: Array = []
	for grave: GraveRecord in _graves.values():
		list.append(grave.to_dict())
	return {"graves": list}


## Replaces everything: default records of the current plots, overwritten by the saved ones.
func load_state(data: Dictionary) -> void:
	_graves = _collect_plots()
	var list: Variant = data.get("graves", [])
	if not list is Array:
		return
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var grave := GraveRecord.from_dict(entry as Dictionary)
		if grave.id == "":
			push_warning("[Graveyard] saved grave without id skipped")
			continue
		if not _graves.has(grave.id) and is_inside_tree():
			push_warning("[Graveyard] saved grave '%s' has no plot in this world" % grave.id)
		_graves[grave.id] = grave


# --- Phase 3 (docs/PHASE3_DESIGN.md §3.4 "Gräber") --------------------------------------------

## LOCKED → EMPTY for the plots of `section_id`; grave_state_changed per plot; count.
func unlock_section(section_id: StringName) -> int:
	var count := 0
	for id: String in plots_in_section(section_id):
		var grave := get_grave(id)
		if grave == null or grave.state != GraveRecord.State.LOCKED:
			continue
		grave.state = GraveRecord.State.EMPTY
		count += 1
		EventBus.grave_state_changed.emit(id, grave.state)
	return count


## Grave ids of the plots of `section_id`, in plot (tree) order.
func plots_in_section(section_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in _graves:
		if _plot_sections.get(id, &"") == section_id:
			out.append(id)
	return out


## Phase 4 §3.4: grave ids of the plots in sections with counts_for_cemetery (the Phase-3 goal
## cemetery_complete; the Holunderwinkel does not count). Graves of unknown sections count.
func plots_counting_for_cemetery() -> PackedStringArray:
	var excluded := _sections_where(func(s: SectionData) -> bool: return not s.counts_for_cemetery)
	var out := PackedStringArray()
	for id: String in _graves:
		if not excluded.has(_plot_sections.get(id, &"")):
			out.append(id)
	return out


## LOCKED graves (plots of sections not unlocked yet) – CorpseDeliveryRules.reserved_plots.
func locked_plot_count() -> int:
	var count := 0
	for grave: GraveRecord in _graves.values():
		if grave.state == GraveRecord.State.LOCKED and _may_open(grave.id):
			count += 1
	return count


## W-Welt (Phase 7): a locked plot of a section that only a story event opens (unlock_flag – the
## Lindenacker opens with linden_consecrated) is no capacity to come before that event – the
## Phase-4 story reservation (CorpseDeliveryRules.reserved_plots) must not count on it. Sections
## the player unlocks himself (the Holunderwinkel with its key) still count.
func _may_open(grave_id: String) -> bool:
	var section_id: StringName = _plot_sections.get(grave_id, &"")
	if section_id == &"":
		return true
	var data := Database.section(section_id) as SectionData
	return data == null or data.unlock_flag == &"" or GameState.flag_on(data.unlock_flag)


## Section of the plot of `grave_id` (&"" = no plot in this world).
func section_of(grave_id: String) -> StringName:
	return _plot_sections.get(grave_id, &"")


## Markers in `inv` (EconomyConfig.marker_quality order) that would raise the quality of the
## MARKED grave `grave_id`: a better marker whose result is not clamped away.
func upgrade_options(grave_id: String, inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	var grave := get_grave(grave_id)
	if grave == null or grave.state != GraveRecord.State.MARKED or inv == null:
		return out
	var corpse := _corpse_of(grave)
	if corpse == null or not grave.design.is_empty():
		return out  # a designed stone is only ever replaced by a better designed stone
	var cfg := _economy()
	var current: int = cfg.marker_quality.get(grave.marker_id, 0)
	for id: StringName in cfg.marker_quality:
		if StoneDesignRules.is_shape(id):
			continue  # Phase 5: designed stones are no items – set only via Stonemasonry
		if cfg.marker_quality[id] > current and inv.has(id) and GraveQuality.compute(corpse, id, cfg) > grave.quality:
			out.append(id)
	return out


## MARKED → MARKED with a better marker from `inv` (the old one is lost): new quality and
## breakdown, no second payment; grave_quality_changed, reputation event marker_upgrade.
## Returns the quality difference, 0 = refused (nothing consumed).
func upgrade_marker(grave_id: String, marker_id: StringName, inv: Inventory) -> int:
	var grave := _known_grave(grave_id, "upgrade_marker")
	if grave == null or not marker_id in upgrade_options(grave_id, inv):
		return 0
	var corpse := _corpse_of(grave)
	if not inv.remove_item(marker_id, 1):
		return 0
	var cfg := _economy()
	var old_quality := grave.quality
	var lines: Array = []
	lines.append_array(GraveQuality.breakdown(corpse, marker_id, cfg))
	grave.marker_id = marker_id
	grave.quality = GraveQuality.compute(corpse, marker_id, cfg)
	grave.breakdown = lines
	EventBus.grave_quality_changed.emit(grave_id, grave.quality)
	var rep := _reputation()
	if rep != null:
		rep.event(EVENT_MARKER_UPGRADE, REASON_UPGRADE % corpse.display_name)
	return grave.quality - old_quality


func _on_world_ready(world: Node) -> void:
	if world != null and world.is_ancestor_of(self):
		broadcast_state()


## Phase goal (§1.3): every non-old grave MARKED (so none LOCKED, at least one exists) → flag
## cemetery_complete, cemetery_completed, summary panel (variant cemetery). Once.
## Phase 4 (§2.10): only graves of sections with counts_for_cemetery (not the Holunderwinkel).
func _check_cemetery_complete() -> void:
	if GameState.has_flag(FLAG_CEMETERY_COMPLETE):
		return
	var any := false
	for id: String in plots_counting_for_cemetery():
		var grave := _graves[id]
		if grave.state == GraveRecord.State.OLD:
			continue
		if grave.state != GraveRecord.State.MARKED:
			return
		any = true
	if not any:
		return
	GameState.set_flag(FLAG_CEMETERY_COMPLETE, true)
	EventBus.cemetery_completed.emit()
	EventBus.ui_panel_requested.emit(SLICE_SUMMARY_PANEL, summary_context())


## Context of the completion panel: the Phase-2 fields (total / rating from CemeteryScore when
## it has one) plus variant, decor, dirt, reputation_tier and content_ghosts (0 / &"" while a
## system is missing).
func summary_context() -> Dictionary:
	var total := total_quality()
	var rating_id := CemeteryRating.rating(total, _economy())
	var score := _first(SCORE_GROUP)
	if score != null and score.has_method(&"total") and score.has_method(&"rating") and score.call(&"rating") != &"":
		total = int(score.call(&"total"))
		rating_id = score.call(&"rating")
	var rep := _reputation()
	return {
		"days": TimeManager.day,
		"burials": GameState.get_stat(STAT_BURIALS),
		"total": total,
		"rating": rating_id,
		"reputation": GameState.get_stat(STAT_REPUTATION),
		"variant": VARIANT_CEMETERY,
		"decor": _call_int(DECOR_GROUP, &"decor_score"),
		"dirt": _call_int(CLEANLINESS_GROUP, &"penalty"),
		"reputation_tier": rep.tier() if rep != null else &"",
		"content_ghosts": _content_ghosts(),
	}


## Phase 4 (§1.3, §3.4): per section with a chapter – every plot of it MARKED (at least one)
## and, for the chapter six_pits, the finale story corpse (StoryConfig.finale_story) buried →
## flag <chapter>_complete, chapter_completed, summary panel (variant = the chapter). Once each.
func _check_chapter() -> void:
	for s: SectionData in _section_list():
		if s.chapter == &"" or GameState.has_flag(_chapter_flag(s.chapter)):
			continue
		var ids := plots_in_section(s.id)
		if ids.is_empty():
			continue
		var all_marked := true
		for id: String in ids:
			if _graves[id].state != GraveRecord.State.MARKED:
				all_marked = false
				break
		if not all_marked:
			continue
		if s.chapter == CHAPTER_SIX_PITS and not _finale_buried():
			continue
		GameState.set_flag(_chapter_flag(s.chapter), true)
		EventBus.chapter_completed.emit(s.chapter)
		EventBus.ui_panel_requested.emit(SLICE_SUMMARY_PANEL, chapter_context(s.chapter))


## Context of the chapter panel: summary_context() with variant = `chapter_id`, plus
## prepared / utilized, piety + piety_tier (Piety node), insights (JournalManager, count),
## not_lorenz (flag insight_not_lorenz) and restless_ghosts.
func chapter_context(chapter_id: StringName) -> Dictionary:
	var context := summary_context()
	context["variant"] = chapter_id
	context["chapter"] = chapter_id
	context["prepared"] = GameState.get_stat(STAT_PREPARED)
	context["utilized"] = GameState.get_stat(STAT_UTILIZED)
	context["piety"] = GameState.get_stat(STAT_PIETY)
	var piety := _first(PIETY_GROUP)
	context["piety_tier"] = piety.call(&"tier") if piety != null and piety.has_method(&"tier") else &""
	var journal := _first(JOURNAL_GROUP)
	# Main insights only (QA4-07: not the optional Kranichfrau – "n/5").
	var insights := 0
	if journal != null and journal.has_method(&"main_insight_count"):
		insights = int(journal.call(&"main_insight_count"))
	elif journal != null and journal.has_method(&"insights"):
		insights = (journal.call(&"insights") as Array).size()
	context["insights"] = insights
	context["not_lorenz"] = GameState.has_flag(FLAG_NOT_LORENZ)
	context["restless_ghosts"] = _ghosts_with_mood(&"restless")
	return context


func _chapter_flag(chapter_id: StringName) -> StringName:
	return StringName("%s_complete" % chapter_id)


## The finale story corpse (StoryConfig.finale_story) is buried.
func _finale_buried() -> bool:
	var corpses := _corpse_manager()
	if corpses == null:
		return false
	var finale := _story_config().finale_story
	for record: CorpseRecord in corpses.records():
		if record.story_id == finale and record.location == CorpseRecord.LOCATION_BURIED:
			return true
	return false


## Graveyard.bury (Phase 4 §2.7): Piety events bare_burial (not dressed) and rotten_burial
## (stage rotten at burial) – directly on the node in group piety.
func _burial_piety(corpse: CorpseRecord) -> void:
	var piety := _first(PIETY_GROUP)
	if piety == null or not piety.has_method(&"event"):
		return
	if not corpse.is_dressed() and not corpse.shrouded:
		piety.call(&"event", EVENT_BARE_BURIAL, REASON_BARE_BURIAL % corpse.display_name)
	var fresh := corpse.freshness_at_burial if corpse.freshness_at_burial >= 0.0 else corpse.freshness
	if CorpseRecord.stage_for(fresh, _economy()) == CorpseRecord.STAGE_ROTTEN:
		piety.call(&"event", EVENT_ROTTEN_BURIAL, REASON_ROTTEN_BURIAL % corpse.display_name)


func _section_list() -> Array[SectionData]:
	var out: Array[SectionData] = []
	var list: Array = section_data if not section_data.is_empty() else Database.sections()
	for section: Variant in list:
		if section is SectionData:
			out.append(section)
	return out


## Ids of the sections for which `pred` holds.
func _sections_where(pred: Callable) -> Dictionary:
	var out := {}
	for s: SectionData in _section_list():
		if pred.call(s):
			out[s.id] = true
	return out


func _story_config() -> StoryConfig:
	if story_config == null:
		story_config = Database.config(&"story_config") as StoryConfig
		if story_config == null:
			story_config = StoryConfig.new()
	return story_config


func _collect_plots() -> Dictionary[String, GraveRecord]:
	var out: Dictionary[String, GraveRecord] = {}
	_plot_sections.clear()
	_old_plots.clear()
	if not is_inside_tree():
		return out
	var locked := _locked_sections()
	for plot: Node in get_tree().get_nodes_in_group(PLOT_GROUP):
		var raw_id: Variant = plot.get("grave_id")
		var id := String(raw_id) if raw_id is String or raw_id is StringName else ""
		if id == "":
			push_warning("[Graveyard] grave plot %s has no grave_id" % plot.get_path())
			continue
		if out.has(id):
			push_warning("[Graveyard] duplicate grave_id '%s' (%s)" % [id, plot.get_path()])
			continue
		var grave := GraveRecord.new()
		grave.id = id
		var is_old: Variant = plot.get("is_old")
		var raw_section: Variant = plot.get("section_id")
		var section := StringName(raw_section) if raw_section is StringName or raw_section is String else DEFAULT_SECTION
		if section == &"":
			section = DEFAULT_SECTION
		_plot_sections[id] = section
		if is_old is bool and is_old:
			grave.state = GraveRecord.State.OLD
			_old_plots[id] = true
		else:
			grave.state = GraveRecord.State.LOCKED if locked.has(section) else GraveRecord.State.EMPTY
		out[id] = grave
	return out


## Ids of the sections that do not start unlocked (unknown sections count as open).
func _locked_sections() -> Dictionary:
	var out := {}
	var list: Array = section_data if not section_data.is_empty() else Database.sections()
	for section: Variant in list:
		if section is SectionData and not (section as SectionData).starts_unlocked:
			out[(section as SectionData).id] = true
	return out


func _corpse_of(grave: GraveRecord) -> CorpseRecord:
	var corpses := _corpse_manager()
	return corpses.get_record(grave.corpse_id) if corpses != null else null


func _content_ghosts() -> int:
	return _ghosts_with_mood(&"content")


func _ghosts_with_mood(mood: StringName) -> int:
	var ghosts := _first(GHOSTS_GROUP)
	if ghosts == null or not ghosts.has_method(&"eligible_graves") or not ghosts.has_method(&"mood_of"):
		return 0
	var count := 0
	for id: String in ghosts.call(&"eligible_graves"):
		if ghosts.call(&"mood_of", id) == mood:
			count += 1
	return count


func _call_int(group: StringName, method: StringName) -> int:
	var node := _first(group)
	return int(node.call(method)) if node != null and node.has_method(method) else 0


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _reputation() -> Reputation:
	return _first(REPUTATION_GROUP) as Reputation


func _reputation_config() -> ReputationConfig:
	if reputation_config == null:
		reputation_config = Database.config(&"reputation_config") as ReputationConfig
		if reputation_config == null:
			reputation_config = ReputationConfig.new()
	return reputation_config


func _known_grave(id: String, action: String) -> GraveRecord:
	var grave := get_grave(id)
	if grave == null:
		push_warning("[Graveyard] %s: unknown grave '%s'" % [action, id])
	return grave


func _corpse_manager() -> CorpseManager:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(CORPSE_MANAGER_GROUP) as CorpseManager


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy


func _tables() -> CorpseTables:
	if tables == null:
		tables = Database.corpse_tables() as CorpseTables
	return tables


# --- Phase 5 (docs/PHASE5_DESIGN.md §2.5, §3.4) -------------------------------------------------

## Sets a designed stone (the shape id becomes marker_id, design = design.to_dict()). It must
## bring more marker points than the current marker (StoneDesignRules.current_marker_points).
## FILLED → like place_marker (payment into `inv`, grave_completed, reputation good / poor,
## cemetery / chapter checks); MARKED → like upgrade_marker (no payment, grave_quality_changed,
## reputation marker_upgrade; a master stone also master_stone, once per grave). Both:
## grave_stone_set, stats.stones_set + 1, Workshop.check_goal. Nothing is taken from `inv`
## (the stone was paid when carved). Returns the quality difference (0 = refused).
func set_designed_stone(grave_id: String, design: StoneDesign, inv: Inventory) -> int:
	var grave := _known_grave(grave_id, "set_designed_stone")
	if grave == null or design == null or design.is_empty():
		return 0
	if grave.state != GraveRecord.State.FILLED and grave.state != GraveRecord.State.MARKED:
		return 0
	var cfg := _economy()
	if not cfg.marker_quality.has(design.shape):
		push_warning("[Graveyard] set_designed_stone: '%s' is no stone shape" % design.shape)
		return 0
	var corpse := _corpse_of(grave)
	if corpse == null:
		push_warning("[Graveyard] set_designed_stone: corpse '%s' of grave '%s' unknown" % [grave.corpse_id, grave_id])
		return 0
	var stone_cfg := _stone_config()
	if StoneDesignRules.marker_points(design, corpse, cfg, stone_cfg) <= StoneDesignRules.current_marker_points(grave, corpse, cfg, stone_cfg):
		return 0
	if grave.state == GraveRecord.State.FILLED and inv == null:
		push_warning("[Graveyard] set_designed_stone without inventory (payment)")
		return 0
	var was_filled := grave.state == GraveRecord.State.FILLED
	var old_quality := grave.quality if not was_filled else 0
	var had_master := StoneDesign.from_dict(grave.design).shape == SHAPE_MASTER
	var stored := design.to_dict()
	var lines: Array = []
	lines.append_array(GraveQuality.breakdown(corpse, design.shape, cfg, stored))
	grave.state = GraveRecord.State.MARKED
	grave.marker_id = design.shape
	grave.design = stored
	grave.quality = GraveQuality.compute(corpse, design.shape, cfg, stored)
	grave.breakdown = lines
	GameState.add_stat(STAT_STONES_SET, 1)
	var rep := _reputation()
	if was_filled:
		grave.completed_day = TimeManager.day
		var rep_cfg := _reputation_config()
		var parts := GraveQuality.payment_parts(corpse, grave.quality, _tables(), cfg, rep.tier() if rep != null else &"", rep_cfg)
		var paid := int(parts.total)
		if paid > 0:
			inv.add_item(COIN_ITEM, paid)
		EventBus.grave_state_changed.emit(grave_id, grave.state)
		EventBus.grave_completed.emit(grave_id, grave.corpse_id, grave.quality, lines.duplicate(true))
		EventBus.payment_received.emit(paid, PAYMENT_REASON % corpse.display_name)
		if rep != null:
			if grave.quality >= rep_cfg.grave_good_min:
				rep.event(EVENT_GRAVE_GOOD, REASON_GRAVE % corpse.display_name)
			elif grave.quality <= rep_cfg.grave_poor_max:
				rep.event(EVENT_GRAVE_POOR, REASON_GRAVE % corpse.display_name)
	else:
		EventBus.grave_quality_changed.emit(grave_id, grave.quality)
		if rep != null:
			rep.event(EVENT_MARKER_UPGRADE, REASON_UPGRADE % corpse.display_name)
			if design.shape == SHAPE_MASTER and not had_master:
				rep.event(EVENT_MASTER_STONE, REASON_MASTER_STONE)
	EventBus.grave_stone_set.emit(grave_id, design.shape, grave.quality)
	if was_filled:
		_check_cemetery_complete()
		_check_chapter()
		_check_buildings_goal(corpse)
	var workshop := _first(WORKSHOP_GROUP)
	if workshop != null and workshop.has_method(&"check_goal"):
		workshop.call(&"check_goal")
	if was_filled:
		_note_orders_grave(grave_id, grave.corpse_id)
	var orders := _first(ORDERS_GROUP)
	if orders != null and orders.has_method(&"note_stone_set"):
		orders.call(&"note_stone_set", grave_id)
	return grave.quality - old_quality


## Phase 6 (§1.5, §3.3; QA6-01): the marker of a serviced corpse may complete „Unter Dach und
## Erde" – Buildings.check_goal (direct call, only for a corpse with service_held).
func _check_buildings_goal(corpse: CorpseRecord) -> void:
	if corpse == null or not corpse.service_held:
		return
	var buildings := _first(BUILDINGS_GROUP)
	if buildings != null and buildings.has_method(&"check_goal"):
		buildings.call(&"check_goal")


func _stone_config() -> StoneConfig:
	if stone_config == null:
		stone_config = Database.config(&"stone_config") as StoneConfig
		if stone_config == null:
			stone_config = StoneConfig.new()
	return stone_config


# --- Phase 7 (docs/PHASE7_DESIGN.md §2.5, §3.4) -------------------------------------------------

## Phase 7 (docs/PHASE7_DESIGN.md §2.5, §3.4): a designed stone replaces the old stone of a
## rest-period grave (old_01 / old_08) with an active stone order for it: the state stays OLD (not
## liftable), no payment, no quality – grave.design / marker_id take the new stone, reputation
## marker_upgrade +1, stats.stones_set + 1, grave_stone_set, then Orders.note_stone_set. false =
## refused (no OLD old grave, no stone, no active order). Stonemasonry.set_stone calls it for a stone
## carved for an old grave.
func replace_old_marker(grave_id: String, design: StoneDesign) -> bool:
	var grave := _known_grave(grave_id, "replace_old_marker")
	if grave == null or design == null or design.is_empty() or grave.state != GraveRecord.State.OLD:
		return false
	if not _old_plots.is_empty() and not _old_plots.has(grave_id):
		return false
	if not _economy().marker_quality.has(design.shape):
		push_warning("[Graveyard] replace_old_marker: '%s' is no stone shape" % design.shape)
		return false
	if not has_stone_order(grave_id):
		return false
	grave.design = design.to_dict()
	grave.marker_id = design.shape
	GameState.add_stat(STAT_STONES_SET, 1)
	var old := Database.old_grave(grave_id) as OldGraveData
	var name := old.display_name if old != null and old.display_name != "" else grave_id
	var rep := _reputation()
	if rep != null:
		rep.event(EVENT_MARKER_UPGRADE, REASON_NEW_OLD_STONE % name)
	EventBus.grave_stone_set.emit(grave_id, design.shape, grave.quality)
	var orders := _first(ORDERS_GROUP)
	if orders != null and orders.has_method(&"note_stone_set"):
		orders.call(&"note_stone_set", grave_id)
	return true


# --- Phase 8 (docs/PHASE8_DESIGN.md §2.2.5, §2.3, §2.4, §3.4; P2) -------------------------------

## Lines a designed stone holds at most (carved text + chiselled-on lines, §2.2.5 "< 4 Zeilen").
const MAX_STONE_LINES := 4


## Lines on the stone of `grave_id` (carved text + extra_lines); 0 = no designed stone.
func stone_line_count(grave_id: String) -> int:
	var grave := get_grave(grave_id)
	if grave == null or grave.design.is_empty():
		return 0
	return StoneDesign.from_dict(grave.design).text.size() + grave.extra_lines.size()


## A line can still be chiselled onto the designed stone of this FILLED / MARKED grave (< 4 lines).
func can_append_inscription(grave_id: String) -> bool:
	var grave := get_grave(grave_id)
	if grave == null or grave.design.is_empty():
		return false
	if grave.state != GraveRecord.State.MARKED and grave.state != GraveRecord.State.FILLED:
		return false
	var count := stone_line_count(grave_id)
	return count > 0 and count < MAX_STONE_LINES


## A line chiselled onto a designed stone with < 4 lines (wish line) → GraveRecord.extra_lines; the stone
## visual is rebuilt (grave_quality_changed – the quality stays). false = no designed stone, full, empty
## line or the line is there already.
func append_inscription(grave_id: String, line: String) -> bool:
	var text := line.strip_edges()
	if text == "" or not can_append_inscription(grave_id):
		return false
	var grave := get_grave(grave_id)
	if grave.extra_lines.has(text):
		return false
	grave.extra_lines.append(text)
	EventBus.grave_quality_changed.emit(grave_id, grave.quality)
	return true


## §2.4 Liesel 1: the name line of a designed stone (S5 „Lorenz Aschau (?)" → „Kaspar Dorn") – the line of
## the template's {name}, else the first carved line. The carved text changes (it is cut anew); the
## quality stays. false = no designed stone, no text or the same name.
func replace_name_line(grave_id: String, _name: String) -> bool:
	var grave := get_grave(grave_id)
	var text := _name.strip_edges()
	if grave == null or grave.design.is_empty() or text == "":
		return false
	var design := StoneDesign.from_dict(grave.design)
	if design.text.is_empty():
		return false
	var index := 0
	var ins := Database.inscription(design.inscription) as InscriptionData if design.inscription != &"" else null
	if ins != null:
		for i: int in ins.lines.size():
			if ins.lines[i].strip_edges() == "{name}":
				index = mini(i, design.text.size() - 1)
				break
	if design.text[index] == text:
		return false
	design.text[index] = text
	grave.design = design.to_dict()
	EventBus.grave_quality_changed.emit(grave_id, grave.quality)
	return true


## An accepted stone order targets `grave_id` (Orders, group orders) – only then may an old grave
## get a new stone (Stonemasonry, GravePlot).
func has_stone_order(grave_id: String) -> bool:
	var orders := _first(ORDERS_GROUP)
	if orders == null or not orders.has_method(&"active") or not orders.has_method(&"order_data"):
		return false
	for id: StringName in orders.call(&"active"):
		var o := orders.call(&"order_data", id) as OrderData
		if o != null and o.kind == &"stone" and o.target == grave_id:
			return true
	return false


## Phase 7 (§3.3): bury / stone orders hear of a completed grave directly.
func _note_orders_grave(grave_id: String, corpse_id: String) -> void:
	var orders := _first(ORDERS_GROUP)
	if orders != null and orders.has_method(&"note_grave_completed"):
		orders.call(&"note_grave_completed", grave_id, corpse_id)


# --- Phase 6 (docs/PHASE6_DESIGN.md §2.3, §3.4) -------------------------------------------------

## OLD → EMPTY (grave_state_changed); only is_old plots (a saved OLD record of a normal plot
## stays). Ossuary.lift calls it. The lifted grave is an ordinary place from now on: the delivery
## rule "one corpse per free place" (free_plot_count) picks it up by itself.
func lift_old(grave_id: String) -> bool:
	var grave := _known_grave(grave_id, "lift_old")
	if grave == null or grave.state != GraveRecord.State.OLD:
		return false
	if not _old_plots.is_empty() and not _old_plots.has(grave_id):
		push_warning("[Graveyard] lift_old: '%s' is no old grave" % grave_id)
		return false
	grave.state = GraveRecord.State.EMPTY
	EventBus.grave_state_changed.emit(grave_id, grave.state)
	return true
