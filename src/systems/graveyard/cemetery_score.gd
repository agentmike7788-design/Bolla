class_name CemeteryScore
extends Node
## Systems/CemeteryScore (docs/PHASE3_DESIGN.md §2.5, §3.3, §3.4), group &"cemetery_score",
## derived, not saved. Cemetery quality = max(0, graves + decor − dirt):
##   graves = Graveyard.total_quality(), decor = DecorationManager.decor_score(),
##   dirt = CleanlinessManager.penalty() (each read through its group; missing system = 0).
## From Phase 3 on the only sender of EventBus.cemetery_quality_changed: synchronously after
## every change of graves, decor or dirt, only when total or rating changes; exactly once
## after world_ready (new game) and once after loading (game_loaded).
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const GROUP := &"cemetery_score"

## Rating thresholds; null = EconomyConfig.resolve().
var economy: EconomyConfig

var _last_total: int = -1
var _last_rating: StringName = &""
## True while a load is running: changes wait for game_loaded (one forced emission).
var _loading: bool = false


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	EventBus.grave_state_changed.connect(_on_grave_state_changed)
	EventBus.grave_completed.connect(_on_grave_completed)
	EventBus.grave_quality_changed.connect(_on_grave_quality_changed)
	EventBus.decor_changed.connect(_on_decor_changed)
	EventBus.cleanliness_changed.connect(_on_cleanliness_changed)
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.game_loaded.connect(_on_game_loaded)


## maxi(0, graves + decor − dirt_penalty)
static func compute(graves: int, decor: int, dirt_penalty: int) -> int:
	return maxi(0, graves + decor - dirt_penalty)


func total() -> int:
	return compute(_graves(), _decor(), _dirt())


func rating() -> StringName:
	return CemeteryRating.rating(total(), _economy())


## {graves, decor, dirt (≥ 0, subtracted), total, rating, next_rating (&"" at the top), next_at}
## next_at = quality at which next_rating starts (0 at the top).
func breakdown() -> Dictionary:
	var graves := _graves()
	var decor := _decor()
	var dirt := _dirt()
	var sum := compute(graves, decor, dirt)
	var cfg := _economy()
	var current := CemeteryRating.rating(sum, cfg)
	var index := CemeteryRating.TIERS.find(current)
	var next_rating := &""
	var next_at := 0
	var thresholds := cfg.rating_thresholds
	if thresholds.size() != CemeteryRating.TIERS.size() - 1:
		thresholds = EconomyConfig.new().rating_thresholds
	if index >= 0 and index + 1 < CemeteryRating.TIERS.size():
		next_rating = CemeteryRating.TIERS[index + 1]
		next_at = thresholds[index]
	return {"graves": graves, "decor": decor, "dirt": dirt, "total": sum, "rating": current,
			"next_rating": next_rating, "next_at": next_at}


## Recomputes; cemetery_quality_changed only when total or rating changed (or `force`).
## Deviation from §3.4 (`refresh() -> void`): optional `force` for world_ready / game_loaded.
func refresh(force: bool = false) -> void:
	var sum := total()
	var current := CemeteryRating.rating(sum, _economy())
	if not force and sum == _last_total and current == _last_rating:
		return
	_last_total = sum
	_last_rating = current
	EventBus.cemetery_quality_changed.emit(sum, current)


func _on_change() -> void:
	if _loading or SaveManager.is_loading:
		_loading = true
		return
	refresh()


func _on_grave_state_changed(_grave_id: String, _state: int) -> void:
	_on_change()


func _on_grave_completed(_grave_id: String, _corpse_id: String, _quality: int, _breakdown: Array) -> void:
	_on_change()


func _on_grave_quality_changed(_grave_id: String, _quality: int) -> void:
	_on_change()


func _on_decor_changed(_uid: String, _decor_id: StringName, _placed: bool) -> void:
	_on_change()


func _on_cleanliness_changed(_penalty: int, _dirty_spots: int) -> void:
	_on_change()


## New game: the one emission after world_ready. A load waits for game_loaded.
func _on_world_ready(_world: Node) -> void:
	if SaveManager.is_loading:
		_loading = true
		return
	refresh(true)


func _on_game_loaded(_slot: int) -> void:
	_loading = false
	refresh(true)


func _graves() -> int:
	var graveyard := _system(&"graveyard")
	return int(graveyard.call(&"total_quality")) if graveyard != null and graveyard.has_method(&"total_quality") else 0


func _decor() -> int:
	var decorations := _system(&"decorations")
	return int(decorations.call(&"decor_score")) if decorations != null and decorations.has_method(&"decor_score") else 0


func _dirt() -> int:
	var cleanliness := _system(&"cleanliness")
	return maxi(int(cleanliness.call(&"penalty")), 0) if cleanliness != null and cleanliness.has_method(&"penalty") else 0


func _system(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy
