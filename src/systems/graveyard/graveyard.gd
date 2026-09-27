class_name Graveyard
extends Node
## Owns all GraveRecords (WorldRoot/Systems/Graveyard). Groups graveyard + saveable.
## _ready collects the grave_plot nodes (grave_id, is_old, section_id) as EMPTY / OLD records –
## LOCKED for plots of a section that does not start unlocked (Phase 3, unlock_section).
## States: EMPTY -dig-> DUG -bury-> FILLED -place_marker-> MARKED (-upgrade_marker-> MARKED);
## OLD never changes; LOCKED -unlock_section-> EMPTY.
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

## id -> record, in plot (tree) order.
var _graves: Dictionary[String, GraveRecord] = {}
## grave id -> section id of its plot (only graves with a plot in this world).
var _plot_sections: Dictionary[String, StringName] = {}


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
	EventBus.grave_state_changed.emit(grave_id, grave.state)
	EventBus.corpse_buried.emit(corpse_id, grave_id)
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
	if not cfg.marker_quality.has(marker_id):
		push_warning("[Graveyard] place_marker: '%s' is no grave marker" % marker_id)
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


func rating() -> StringName:
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


## STUB (P1) – Phase 4 §3.4: grave ids of the plots in sections with counts_for_cemetery
## (W0: every plot).
func plots_counting_for_cemetery() -> PackedStringArray:
	return PackedStringArray(_graves.keys())


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
	if corpse == null:
		return out
	var cfg := _economy()
	var current: int = cfg.marker_quality.get(grave.marker_id, 0)
	for id: StringName in cfg.marker_quality:
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
func _check_cemetery_complete() -> void:
	if GameState.has_flag(FLAG_CEMETERY_COMPLETE):
		return
	var any := false
	for grave: GraveRecord in _graves.values():
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


func _collect_plots() -> Dictionary[String, GraveRecord]:
	var out: Dictionary[String, GraveRecord] = {}
	_plot_sections.clear()
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
	var ghosts := _first(GHOSTS_GROUP)
	if ghosts == null or not ghosts.has_method(&"eligible_graves") or not ghosts.has_method(&"mood_of"):
		return 0
	var count := 0
	for id: String in ghosts.call(&"eligible_graves"):
		if ghosts.call(&"mood_of", id) == &"content":
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
