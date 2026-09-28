class_name ExpansionManager
extends Node
## Cemetery expansion (docs/PHASE3_DESIGN.md §1.2, §2.1, §3.4 "Ausbau"). Systems/Expansion
## (groups expansion, saveable; save_id "expansion", save_order 5). Collects all nodes of group
## &"clearable" in _ready. Obstacle state lives here only (ClearableObstacle is not saved).
## A section can be worked on once its prerequisites hold (requires_section unlocked,
## cemetery rating ≥ requires_rating); clearing its last obstacle unlocks it automatically:
## Graveyard.unlock_section, reputation event section_unlocked, section_unlocked, notification.

const GROUP := &"expansion"
const SAVEABLE_GROUP := &"saveable"
const CLEARABLE_GROUP := &"clearable"
const GRAVEYARD_GROUP := &"graveyard"
const SCORE_GROUP := &"cemetery_score"
const REPUTATION_GROUP := &"reputation"
const EVENT_SECTION_UNLOCKED := &"section_unlocked"
const TEXT_NEEDS_SECTION := "Erst die %s freilegen"
const TEXT_NEEDS_RATING := "Erst Friedhof „%s“ (%d)"
const TEXT_UNLOCKED_FALLBACK := "%s ist freigelegt."
const REASON_UNLOCKED := "%s freigelegt"
# Phase 4 (docs/PHASE4_DESIGN.md §2.10, §3.4): SectionData.requires_flag, the six_pits clue.
const TEXT_NEEDS_FLAG := "Noch verschlossen."
const JOURNAL_GROUP := &"journal"
const CHAPTER_SIX_PITS := &"six_pits"
const CLUE_SIX_PITS := &"c_six_pits"

@export var save_id: String = "expansion"
@export var save_order: int = 5

## Sections; empty = Database.sections() (sorted by order either way).
var section_data: Array[SectionData] = []
## kind -> ClearableData; missing kinds come from Database.clearable(kind).
var clearable_data: Dictionary[StringName, ClearableData] = {}
## Rating thresholds for the prerequisite text; null = the Graveyard's / EconomyConfig.resolve().
var economy: EconomyConfig

## obstacle id -> node, in tree order.
var _obstacles: Dictionary[String, ClearableObstacle] = {}
var _cleared: Dictionary[String, bool] = {}
## Sections unlocked during play (starts_unlocked sections are always open).
var _unlocked: Dictionary[StringName, bool] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(SAVEABLE_GROUP, true)


func _ready() -> void:
	collect_obstacles()


## (Re)collects the nodes of group &"clearable" and shows their current state.
func collect_obstacles() -> void:
	_obstacles.clear()
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(CLEARABLE_GROUP):
		var obstacle := node as ClearableObstacle
		if obstacle == null or obstacle.is_queued_for_deletion():
			continue
		if obstacle.obstacle_id == "":
			push_warning("[ExpansionManager] obstacle %s has no obstacle_id" % obstacle.get_path())
			continue
		if _obstacles.has(obstacle.obstacle_id):
			push_warning("[ExpansionManager] duplicate obstacle_id '%s'" % obstacle.obstacle_id)
			continue
		_obstacles[obstacle.obstacle_id] = obstacle
	_apply_all()


## All sections, sorted by SectionData.order.
func sections() -> Array[SectionData]:
	var out: Array[SectionData] = []
	var list: Array = section_data if not section_data.is_empty() else Database.sections()
	for section: Variant in list:
		if section is SectionData:
			out.append(section)
	out.sort_custom(func(a: SectionData, b: SectionData) -> bool: return a.order < b.order)
	return out


func section(section_id: StringName) -> SectionData:
	for s: SectionData in sections():
		if s.id == section_id:
			return s
	return null


func is_unlocked(section_id: StringName) -> bool:
	var s := section(section_id)
	return s != null and (s.starts_unlocked or _unlocked.has(section_id))


## SectionData.order of the unlocked sections (for BuildGrid).
func unlocked_indices() -> PackedInt32Array:
	var out := PackedInt32Array()
	for s: SectionData in sections():
		if is_unlocked(s.id):
			out.append(s.order)
	return out


## "" = workable; otherwise the display text of the missing prerequisite.
func block_reason(section_id: StringName) -> String:
	var s := section(section_id)
	if s == null or is_unlocked(section_id):
		return ""
	if s.requires_flag != &"" and not GameState.has_flag(s.requires_flag):
		return s.requires_flag_text if s.requires_flag_text != "" else TEXT_NEEDS_FLAG
	if s.requires_section != &"" and not is_unlocked(s.requires_section):
		var needed := section(s.requires_section)
		return TEXT_NEEDS_SECTION % (needed.display_name if needed != null else String(s.requires_section))
	if s.requires_rating != &"" and not _rating_reached(s.requires_rating):
		return TEXT_NEEDS_RATING % [CemeteryRating.label(s.requires_rating), _rating_threshold(s.requires_rating)]
	return ""


func is_cleared(obstacle_id: String) -> bool:
	return _cleared.has(obstacle_id)


## Obstacle ids of `section_id`, in tree order.
func obstacle_ids(section_id: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in _obstacles:
		if _obstacles[id].section_id == section_id:
			out.append(id)
	return out


## (done, total)
func progress(section_id: StringName) -> Vector2i:
	var ids := obstacle_ids(section_id)
	var done := 0
	for id: String in ids:
		if is_cleared(id):
			done += 1
	return Vector2i(done, ids.size())


func obstacle(obstacle_id: String) -> ClearableObstacle:
	var node: ClearableObstacle = _obstacles.get(obstacle_id)
	return node if is_instance_valid(node) else null


## ClearableData of the obstacle's kind (null = unknown obstacle or kind).
func data_of(obstacle_id: String) -> ClearableData:
	var node := obstacle(obstacle_id)
	if node == null:
		return null
	if clearable_data.has(node.kind):
		return clearable_data[node.kind]
	return Database.clearable(node.kind) as ClearableData


## {item_id: amount} still missing to clear `obstacle_id`.
func missing_cost(obstacle_id: String, inv: Inventory) -> Dictionary:
	var out := {}
	var data := data_of(obstacle_id)
	if data == null:
		return out
	for id: StringName in data.cost:
		var have := inv.count(id) if inv != null else 0
		if have < data.cost[id]:
			out[id] = data.cost[id] - have
	return out


## The yield of `obstacle_id` fits into `inv`.
func yield_fits(obstacle_id: String, inv: Inventory) -> bool:
	var data := data_of(obstacle_id)
	if data == null or inv == null:
		return false
	for id: StringName in data.yield_items:
		if not inv.can_add(id, data.yield_items[id]):
			return false
	return true


## Prerequisite met, cost available, yield fits.
func can_clear(obstacle_id: String, inv: Inventory) -> bool:
	var node := obstacle(obstacle_id)
	if node == null or inv == null or is_cleared(obstacle_id) or data_of(obstacle_id) == null:
		return false
	if is_unlocked(node.section_id) or block_reason(node.section_id) != "":
		return false
	return missing_cost(obstacle_id, inv).is_empty() and yield_fits(obstacle_id, inv)


## Atomic: cost off, yield in, obstacle_cleared, section_progress_changed; the last one unlocks.
func clear(obstacle_id: String, inv: Inventory) -> bool:
	if not can_clear(obstacle_id, inv):
		return false
	var data := data_of(obstacle_id)
	for id: StringName in data.cost:
		if not inv.remove_item(id, data.cost[id]):
			push_warning("[ExpansionManager] clear('%s'): could not take %s" % [obstacle_id, id])
	for id: StringName in data.yield_items:
		inv.add_item(id, data.yield_items[id])
	var node := obstacle(obstacle_id)
	_cleared[obstacle_id] = true
	node.apply_cleared(true)
	EventBus.obstacle_cleared.emit(obstacle_id, node.section_id)
	var p := progress(node.section_id)
	EventBus.section_progress_changed.emit(node.section_id, p.x, p.y)
	if p.x >= p.y:
		unlock(node.section_id)
	return true


## Graveyard.unlock_section, reputation +4 (event section_unlocked), section_unlocked,
## notification – also via debug: remaining obstacles of the section count as cleared.
func unlock(section_id: StringName) -> bool:
	var s := section(section_id)
	if s == null or is_unlocked(section_id):
		return false
	_unlocked[section_id] = true
	var remaining := false
	for id: String in obstacle_ids(section_id):
		if not is_cleared(id):
			_cleared[id] = true
			obstacle(id).apply_cleared(true)
			remaining = true
	if remaining:
		var p := progress(section_id)
		EventBus.section_progress_changed.emit(section_id, p.x, p.y)
	var graveyard := _graveyard()
	if graveyard != null:
		graveyard.unlock_section(section_id)
	var rep := _first(REPUTATION_GROUP) as Reputation
	if rep != null:
		rep.event(EVENT_SECTION_UNLOCKED, REASON_UNLOCKED % s.display_name)
	EventBus.section_unlocked.emit(section_id)
	var text := s.unlock_text if s.unlock_text != "" else TEXT_UNLOCKED_FALLBACK % s.display_name
	EventBus.notification_requested.emit(text, &"reward")
	if s.chapter == CHAPTER_SIX_PITS:
		var journal := _first(JOURNAL_GROUP)
		if journal != null and journal.has_method(&"add_clue"):
			journal.call(&"add_clue", CLUE_SIX_PITS, "", false)
	return true


func save_state() -> Dictionary:
	var cleared: Array = []
	for id: String in _cleared:
		cleared.append(id)
	var unlocked: Array = []
	for id: StringName in _unlocked:
		unlocked.append(id)
	return {"cleared": cleared, "unlocked": unlocked}


## Replaces everything; {} = nothing cleared, only the starts_unlocked sections open.
func load_state(data: Dictionary) -> void:
	_cleared.clear()
	_unlocked.clear()
	var cleared: Variant = data.get("cleared", [])
	if cleared is Array:
		for id: Variant in cleared:
			if (id is String or id is StringName) and String(id) != "":
				_cleared[String(id)] = true
	var unlocked: Variant = data.get("unlocked", [])
	if unlocked is Array:
		for id: Variant in unlocked:
			if not (id is String or id is StringName):
				continue
			if section(StringName(id)) == null:
				push_warning("[ExpansionManager] saved section '%s' unknown – ignored" % id)
				continue
			_unlocked[StringName(id)] = true
	for id: StringName in _unlocked:
		for obstacle_id: String in obstacle_ids(id):
			_cleared[obstacle_id] = true
	_apply_all()


## Unlocked sections whose plots are still LOCKED in the Graveyard → repaired (warning).
func post_load() -> void:
	var graveyard := _graveyard()
	if graveyard == null:
		return
	for s: SectionData in sections():
		if s.starts_unlocked:
			continue
		# QA-05: every obstacle cleared but still locked (inconsistent / older save) would be a
		# softlock – clear() only unlocks on the last obstacle. Unlock it now.
		var p := progress(s.id)
		if not _unlocked.has(s.id) and p.y > 0 and p.x >= p.y:
			push_warning("[ExpansionManager] section '%s' has no obstacle left but is locked – unlocked" % s.id)
			unlock(s.id)
			continue
		if not _unlocked.has(s.id):
			continue
		var locked := false
		for grave_id: String in graveyard.plots_in_section(s.id):
			var grave := graveyard.get_grave(grave_id)
			if grave != null and grave.state == GraveRecord.State.LOCKED:
				locked = true
		if locked:
			push_warning("[ExpansionManager] section '%s' is unlocked but its plots are locked – repaired" % s.id)
			graveyard.unlock_section(s.id)


func _apply_all() -> void:
	for id: String in _obstacles:
		var node := obstacle(id)
		if node != null:
			node.apply_cleared(is_cleared(id))


func _rating_reached(required: StringName) -> bool:
	var need := CemeteryRating.TIERS.find(required)
	if need < 0:
		push_warning("[ExpansionManager] unknown rating '%s'" % required)
		return true
	return CemeteryRating.TIERS.find(_current_rating()) >= need


## CemeteryScore.rating() (Phase 3 cemetery quality); without it the graves-only rating.
func _current_rating() -> StringName:
	var score := _first(SCORE_GROUP)
	if score != null and score.has_method(&"rating"):
		var r: Variant = score.call(&"rating")
		if r is StringName and r != &"":
			return r
	var graveyard := _graveyard()
	return graveyard.rating() if graveyard != null else CemeteryRating.NEGLECTED


func _rating_threshold(rating_id: StringName) -> int:
	var cfg := economy
	if cfg == null:
		var graveyard := _graveyard()
		cfg = graveyard.economy if graveyard != null and graveyard.economy != null else EconomyConfig.resolve()
	var index := CemeteryRating.TIERS.find(rating_id) - 1
	return cfg.rating_thresholds[index] if index >= 0 and index < cfg.rating_thresholds.size() else 0


func _graveyard() -> Graveyard:
	return _first(GRAVEYARD_GROUP) as Graveyard


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null
