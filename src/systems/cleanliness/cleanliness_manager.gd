class_name CleanlinessManager
extends Node
## Systems/Cleanliness (docs/PHASE3_DESIGN.md §2.4, §3.4): groups cleanliness + saveable,
## save_id "cleanliness", save_order 12. _ready collects the DirtSpot nodes (group &"dirt_spot").
## Growth comes from the difference of game minutes since last_total (hour_changed /
## time_skipped), never from ticks; cleanliness_changed is bundled – at most once per action or
## time skip (flushed at the time_tick that ends every TimeManager.advance).
## A spot grows only while its section is unlocked (ExpansionManager, group &"expansion"; none
## = every section counts as open), it is not covered by gravel / a flower bed
## (DecorationManager.suppresses_dirt_at, group &"decorations") and – for grave spots – its
## grave is FILLED or MARKED (Graveyard, group &"graveyard").
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const GROUP := &"cleanliness"
const KIND_WEEDS := &"weeds"
const KIND_LEAVES := &"leaves"

@export var save_id: String = "cleanliness"
@export var save_order: int = 12

## Growth / tending values; null = data/config/cleanliness_config.tres.
var config: CleanlinessConfig
## TimeManager.total_minutes() up to which growth has been applied.
var last_total: int = 0

## spot_id -> DirtSpot, in tree order.
var _spots: Dictionary[String, DirtSpot] = {}
## spot_id -> progress (0 … max_level + 0.999).
var _progress: Dictionary[String, float] = {}
## A level changed since the last cleanliness_changed.
var _pending: bool = false


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	collect_spots()
	last_total = TimeManager.total_minutes()
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.new_game_started.connect(apply_start_state)
	# QA-06: covered spots (gravel / flower bed) show and count as level 0 – refresh the shown
	# levels when decor changes and after a load (decorations load after this node).
	EventBus.decor_changed.connect(_on_cover_changed.unbind(3))
	EventBus.game_loaded.connect(_on_cover_changed.unbind(1))


## (Re)collects the DirtSpot nodes of the tree; known progress is kept, new spots start at 0.
## Helper (not part of the contract) – _ready calls it.
func collect_spots() -> void:
	_spots.clear()
	for node: Node in get_tree().get_nodes_in_group(DirtSpot.GROUP):
		var spot := node as DirtSpot
		if spot == null or spot.spot_id == "":
			continue
		if _spots.has(spot.spot_id):
			push_warning("[CleanlinessManager] duplicate spot id '%s'" % spot.spot_id)
			continue
		_spots[spot.spot_id] = spot
	var kept: Dictionary[String, float] = {}
	for id: String in _spots:
		kept[id] = float(_progress.get(id, 0.0))
	_progress = kept
	_show_all()


func spot_ids() -> PackedStringArray:
	return PackedStringArray(_spots.keys())


## Level of the spot; 0 while gravel / a flower bed covers it (§2.3 "unterdrückt Unkraut in
## seinen Zellen" – the progress stays and shows again when the piece is removed).
func level(spot_id: String) -> int:
	var spot: DirtSpot = _spots.get(spot_id)
	if spot != null and _suppressed(spot):
		return 0
	return DirtGrowth.level(progress(spot_id), _cfg())


func progress(spot_id: String) -> float:
	return float(_progress.get(spot_id, 0.0))


func is_growing(spot_id: String) -> bool:
	var spot: DirtSpot = _spots.get(spot_id)
	if spot == null:
		return false
	if not _section_open(spot.section_id):
		return false
	if spot.grave_id != "" and not _grave_allows_growth(spot.grave_id):
		return false
	return not _suppressed(spot)


## Minutes tending takes; 0 = not possible (unknown spot, level 0, rake missing for leaves).
func tend_minutes(spot_id: String, inv: Inventory) -> int:
	var spot: DirtSpot = _spots.get(spot_id)
	if spot == null:
		return 0
	var lvl := level(spot_id)
	if lvl <= 0:
		return 0
	var cfg := _cfg()
	if spot.kind == KIND_LEAVES:
		if inv == null or not inv.has(cfg.rake_item):
			return 0
		return maxi(cfg.rake_minutes, 1)
	if lvl >= cfg.weed_minutes.size():
		return maxi(cfg.weed_minutes[cfg.weed_minutes.size() - 1], 1) if not cfg.weed_minutes.is_empty() else 1
	return maxi(cfg.weed_minutes[lvl], 1)


## Progress 0; dirt_changed, cleanliness_changed. The caller runs the timed action first.
## Phase 8 (§2.5.4, P3): the gravekeeper's tending is reported to the apprentice (teaching by showing).
func tend(spot_id: String, inv: Inventory) -> bool:
	if tend_minutes(spot_id, inv) <= 0:
		return false
	_set_progress(spot_id, 0.0)
	_flush()
	_note_player_job(spot_id)
	return true


## Phase 8 (docs/PHASE8_DESIGN.md §2.5.2, §3.4, P3): the apprentice's tending – the same effect as tend()
## without the inventory check (his tools lie in his box; actor &"apprentice"). false = unknown spot or
## nothing to tend.
func tend_by(spot_id: String, _actor: StringName) -> bool:
	if not _spots.has(spot_id) or level(spot_id) <= 0:
		return false
	_set_progress(spot_id, 0.0)
	_flush()
	return true


## Phase 8 (§2.3, §2.6.3, §3.3, P3 for P7 / the apprentice's mistake): sets the care spot to `level`
## (clamped 0…max_level; the progress sits at the start of that level); dirt_changed, cleanliness_changed.
func set_level(spot_id: String, level_value: int) -> void:
	if not _spots.has(spot_id):
		push_warning("[CleanlinessManager] set_level(): unknown spot '%s'" % spot_id)
		return
	_set_progress(spot_id, float(clampi(level_value, 0, _cfg().max_level)))
	_flush()


func penalty() -> int:
	var by_level := _cfg().penalty_by_level
	var sum := 0
	for id: String in _progress:
		var lvl := level(id)
		if lvl >= 0 and lvl < by_level.size():
			sum += by_level[lvl]
	return sum


func dirty_count(min_level: int = 2) -> int:
	var count := 0
	for id: String in _progress:
		if level(id) >= min_level:
			count += 1
	return count


## Growth since last_total (hour_changed / time_skipped); emits cleanliness_changed when a level
## changed.
func update_to(now_total: int) -> void:
	_grow_to(now_total)
	_flush()


## Only on new_game_started: start_progress from the layout (spots of locked sections stay 0).
func apply_start_state() -> void:
	last_total = TimeManager.total_minutes()
	for id: String in _spots:
		var spot := _spots[id]
		_set_progress(id, spot.start_progress if _section_open(spot.section_id) else 0.0)
	_pending = true
	_flush()


func save_state() -> Dictionary:
	var spots := {}
	for id: String in _progress:
		spots[id] = _progress[id]
	return {"last_total": last_total, "spots": spots}


## {} → everything 0, last_total = now. Unknown saved spots are ignored (warning).
func load_state(data: Dictionary) -> void:
	for id: String in _progress:
		_progress[id] = 0.0
	last_total = TimeManager.total_minutes()
	var saved_total: Variant = data.get("last_total")
	if saved_total is int or saved_total is float:
		last_total = mini(int(saved_total), TimeManager.total_minutes())
	var saved: Variant = data.get("spots", {})
	if saved is Dictionary:
		for key: Variant in saved:
			var id := str(key)
			var value: Variant = (saved as Dictionary)[key]
			if not _progress.has(id):
				push_warning("[CleanlinessManager] saved spot '%s' is not in the world – ignored" % id)
			elif value is int or value is float:
				_progress[id] = clampf(float(value), 0.0, float(_cfg().max_level) + 0.999)
	_show_all()
	_pending = true
	_flush()


func _grow_to(now_total: int) -> void:
	var minutes := now_total - last_total
	if minutes <= 0:
		return
	last_total = now_total
	var cfg := _cfg()
	for id: String in _spots:
		if not is_growing(id):
			continue
		var spot := _spots[id]
		_set_progress(id, DirtGrowth.grow(progress(id), DirtGrowth.rate(id, spot.kind, cfg), minutes, cfg))


## Stores progress; on a level change: show_level + dirt_changed, cleanliness_changed pending.
func _set_progress(spot_id: String, value: float) -> void:
	var before := level(spot_id)
	_progress[spot_id] = value
	var after := level(spot_id)
	if after != before:
		var spot: DirtSpot = _spots.get(spot_id)
		if spot != null:
			spot.show_level(after)
		_pending = true
		EventBus.dirt_changed.emit(spot_id, after)


func _flush() -> void:
	if not _pending:
		return
	_pending = false
	EventBus.cleanliness_changed.emit(penalty(), dirty_count())


func _show_all() -> void:
	for id: String in _spots:
		_spots[id].show_level(level(id))


func _section_open(section_id: StringName) -> bool:
	var expansion := _system(&"expansion")
	if expansion == null or not expansion.has_method(&"is_unlocked"):
		return true
	return bool(expansion.call(&"is_unlocked", section_id))


func _grave_allows_growth(grave_id: String) -> bool:
	var graveyard := _system(&"graveyard")
	if graveyard == null or not graveyard.has_method(&"get_grave"):
		return false
	var grave := graveyard.call(&"get_grave", grave_id) as GraveRecord
	return grave != null and (grave.state == GraveRecord.State.FILLED or grave.state == GraveRecord.State.MARKED)


func _suppressed(spot: DirtSpot) -> bool:
	var decorations := _system(&"decorations")
	if decorations == null or not decorations.has_method(&"suppresses_dirt_at") or not spot.is_inside_tree():
		return false
	var p := spot.global_position
	return bool(decorations.call(&"suppresses_dirt_at", Vector2(p.x, p.z)))


func _system(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _note_player_job(spot_id: String) -> void:
	var apprentice := _system(&"apprentice")
	var spot: DirtSpot = _spots.get(spot_id)
	if apprentice != null and spot != null and apprentice.has_method(&"note_player_job"):
		apprentice.call(&"note_player_job", spot.kind, spot.global_position if spot.is_inside_tree() else spot.position)


func _on_hour_changed(_day: int, _hour: int) -> void:
	_grow_to(TimeManager.total_minutes())


func _on_time_skipped(_from_total: int, to_total: int) -> void:
	_grow_to(to_total)


func _on_time_tick(_day: int, _minute_of_day: int) -> void:
	_flush()


## Shown level follows a covering piece placed / removed (derived, no progress changes).
func _on_cover_changed() -> void:
	for id: String in _spots:
		var lvl := level(id)
		if _spots[id].shown_level != lvl:
			_spots[id].show_level(lvl)
			_pending = true
			EventBus.dirt_changed.emit(id, lvl)
	_flush()


func _cfg() -> CleanlinessConfig:
	if config == null:
		config = Database.config(&"cleanliness_config") as CleanlinessConfig
		if config == null:
			config = CleanlinessConfig.new()
	return config
