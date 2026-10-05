class_name Fiddler
extends Node3D
## The fiddler from the „Stumpf" at the inn stove (docs/PHASE8_DESIGN.md §2.7.1, §3.4, §8.1): seated, no
## rig; shown on the festival day, the bow arm (child mesh `bow`) sways in GDScript only inside the
## festival window (Festivals.running). No interaction, display only.

const FESTIVALS_GROUP := &"festivals"
const BOW := ^"bow"
## Sway of the bow arm: amplitude (radians) and speed (cycles per second).
const SWAY_ANGLE := 0.35
const SWAY_HZ := 1.6

## Shown while this GameState flag equals TimeManager.day.
@export var fest_flag: StringName = &"fest_kathrein_day"
## The festival whose window lets the bow sway.
@export var fest_id: StringName = &"fest_kathrein"

var _phase: float = 0.0
var _bow: Node3D
var _bow_rest: Vector3 = Vector3.ZERO


func _ready() -> void:
	_bow = get_node_or_null(BOW) as Node3D
	if _bow != null:
		_bow_rest = _bow.rotation
	EventBus.day_started.connect(_on_change.unbind(1))
	EventBus.festival_changed.connect(_on_change.unbind(2))
	EventBus.game_loaded.connect(_on_change.unbind(1))
	refresh()


func refresh() -> void:
	visible = FestDecor.is_fest_day(fest_flag)
	set_process(visible and _bow != null)
	if _bow != null and not playing():
		_bow.rotation = _bow_rest


## The bow sways: the festival window runs.
func playing() -> bool:
	if not visible or not is_inside_tree():
		return false
	var fest := get_tree().get_first_node_in_group(FESTIVALS_GROUP)
	return fest != null and fest.has_method(&"running") and StringName(fest.call(&"running")) == fest_id


func _process(delta: float) -> void:
	if _bow == null:
		return
	if not playing():
		_bow.rotation = _bow_rest
		return
	_phase = fmod(_phase + delta * SWAY_HZ, 1.0)
	_bow.rotation = _bow_rest + Vector3(0.0, 0.0, sin(_phase * TAU) * SWAY_ANGLE)


func _on_change() -> void:
	refresh()
