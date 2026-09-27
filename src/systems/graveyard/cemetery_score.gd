class_name CemeteryScore
extends Node
## STUB (P3) – docs/PHASE3_DESIGN.md §2.5, §3.4. Systems/CemeteryScore (group
## &"cemetery_score", derived, not saved). Cemetery quality = max(0, graves + decor − dirt).
## From Phase 3 on the only sender of EventBus.cemetery_quality_changed (only on change;
## forced once after world_ready / loading).


func _init() -> void:
	add_to_group(&"cemetery_score", true)


## maxi(0, graves + decor − dirt_penalty)
static func compute(_graves: int, _decor: int, _dirt_penalty: int) -> int:
	return 0


func total() -> int:
	return 0


func rating() -> StringName:
	return &""


## {graves, decor, dirt (≥ 0, subtracted), total, rating, next_rating (&"" at the top), next_at}
func breakdown() -> Dictionary:
	return {}


func refresh() -> void:
	pass
