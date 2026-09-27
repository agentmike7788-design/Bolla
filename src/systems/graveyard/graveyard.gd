class_name Graveyard
extends Node
## Owns all GraveRecords (WorldRoot/Systems/Graveyard). Groups graveyard + saveable.
## _ready collects the grave_plot nodes (grave_id, is_old) as EMPTY / OLD records.
## States: EMPTY -dig-> DUG -bury-> FILLED -place_marker-> MARKED; OLD never changes.

const GROUP := &"graveyard"
const SAVEABLE_GROUP := &"saveable"
const PLOT_GROUP := &"grave_plot"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const COIN_ITEM := &"coin"
const STAT_BURIALS := &"burials"
const STAT_REPUTATION := &"reputation"
const FLAG_SLICE_COMPLETE := &"slice_complete"
const SLICE_SUMMARY_PANEL := &"slice_summary"
const PAYMENT_REASON := "Bestattung von %s"

@export var save_id: String = "graveyard"
@export var save_order: int = 10

## Quality points, payment and rating; null = Database.config(&"economy_config").
var economy: EconomyConfig
## Base payment per cause; null = Database.corpse_tables().
var tables: CorpseTables

## id -> record, in plot (tree) order.
var _graves: Dictionary[String, GraveRecord] = {}


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


## FILLED -> MARKED: takes the marker item from inv, stores quality + breakdown and pays coins
## into inv. Signals: grave_state_changed, grave_completed, payment_received,
## cemetery_quality_changed (then slice completion). Returns the payment (0 when refused).
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
	var corpses := _corpse_manager()
	var corpse: CorpseRecord = corpses.get_record(grave.corpse_id) if corpses != null else null
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
	var paid := GraveQuality.payment(corpse, grave.quality, _tables(), cfg)
	if paid > 0:
		inv.add_item(COIN_ITEM, paid)
	EventBus.grave_state_changed.emit(grave_id, grave.state)
	EventBus.grave_completed.emit(grave_id, grave.corpse_id, grave.quality, lines.duplicate(true))
	EventBus.payment_received.emit(paid, PAYMENT_REASON % corpse.display_name)
	var total := total_quality()
	EventBus.cemetery_quality_changed.emit(total, CemeteryRating.rating(total, cfg))
	_check_slice_complete()
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


## grave_state_changed for every grave, then cemetery_quality_changed.
func broadcast_state() -> void:
	for grave: GraveRecord in _graves.values():
		EventBus.grave_state_changed.emit(grave.id, grave.state)
	var total := total_quality()
	EventBus.cemetery_quality_changed.emit(total, CemeteryRating.rating(total, _economy()))


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


func _on_world_ready(world: Node) -> void:
	if world != null and world.is_ancestor_of(self):
		broadcast_state()


## Every non-old grave MARKED (and at least one exists) -> flag, slice_completed, summary panel.
func _check_slice_complete() -> void:
	if GameState.has_flag(FLAG_SLICE_COMPLETE):
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
	GameState.set_flag(FLAG_SLICE_COMPLETE, true)
	EventBus.slice_completed.emit()
	var total := total_quality()
	EventBus.ui_panel_requested.emit(SLICE_SUMMARY_PANEL, {
		"days": TimeManager.day,
		"burials": GameState.get_stat(STAT_BURIALS),
		"total": total,
		"rating": CemeteryRating.rating(total, _economy()),
		"reputation": GameState.get_stat(STAT_REPUTATION),
	})


func _collect_plots() -> Dictionary[String, GraveRecord]:
	var out: Dictionary[String, GraveRecord] = {}
	if not is_inside_tree():
		return out
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
		grave.state = GraveRecord.State.OLD if is_old is bool and is_old else GraveRecord.State.EMPTY
		out[id] = grave
	return out


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
		economy = Database.config(&"economy_config") as EconomyConfig
		if economy == null:
			economy = EconomyConfig.new()
	return economy


func _tables() -> CorpseTables:
	if tables == null:
		tables = Database.corpse_tables() as CorpseTables
	return tables
