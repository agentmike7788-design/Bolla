class_name MemorialPlate
extends Node3D
## The name plate „Konrad Wackernagel" on the memorial board of the church (docs/PHASE8_DESIGN.md §2.4
## Rosine 2, §3.4, §4.6 D7): visible from friend_innkeeper_2 on. No interaction; refreshes on the step,
## a load and the start (listeners change no state).

const FLAG := &"friend_innkeeper_2"


func _ready() -> void:
	EventBus.friend_step_completed.connect(_on_change.unbind(2))
	EventBus.game_loaded.connect(_on_change.unbind(1))
	refresh()


## Visible ⇔ FLAG.
func refresh() -> void:
	visible = GameState.flag_on(FLAG)


func _on_change() -> void:
	refresh()
