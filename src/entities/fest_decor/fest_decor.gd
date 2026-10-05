class_name FestDecor
extends Node3D
## The Kathrein decoration of the inn (docs/PHASE8_DESIGN.md §2.7.1, §3.4, §4.6 D6): fir green and
## ribbons on two beams, the tables against the wall – shown only on the festival day (fest_flag holds
## today's day, set by Festivals). Pure display, no interaction; refreshes on the day, the festival
## signals and a load (listeners change no state).

## Shown while this GameState flag equals TimeManager.day (fest_kathrein_day).
@export var fest_flag: StringName = &"fest_kathrein_day"


func _ready() -> void:
	EventBus.day_started.connect(_on_change.unbind(1))
	EventBus.festival_changed.connect(_on_change.unbind(2))
	EventBus.game_loaded.connect(_on_change.unbind(1))
	refresh()


## Visible ⇔ the flag holds today's day.
func refresh() -> void:
	visible = is_fest_day(fest_flag)


## The festival day flag `flag` holds today's day.
static func is_fest_day(flag: StringName) -> bool:
	var v: Variant = GameState.get_flag(flag)
	return (v is int or v is float) and int(v) == TimeManager.day


func _on_change() -> void:
	refresh()
