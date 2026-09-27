extends Node3D
## Test world for SaveManager: like WorldRoot it announces EventBus.world_ready deferred
## after _ready. Children log into `events` to verify the load/new-game order.

var events: PackedStringArray = []
var is_world_ready: bool = false


func _ready() -> void:
	log_event("world:ready")
	_announce.call_deferred()


func log_event(text: String) -> void:
	events.append(text)


func _announce() -> void:
	is_world_ready = true
	log_event("world:world_ready")
	EventBus.world_ready.emit(self)
