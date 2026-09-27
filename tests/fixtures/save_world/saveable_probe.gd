extends Node
## Test double for the saveable contract (docs §5): typed state, call log.
## Logs "<save_id>:<call>" into the owning save_world (if any) and into `calls`.

@export var save_id: String = ""
@export var save_order: int = 0
## Start content granted on EventBus.new_game_started (never in _ready).
@export var start_count: int = 3

var pos: Vector3 = Vector3.ZERO
var count: int = 0
var tag: StringName = &"default"
var tags: Array[StringName] = []
var ratio: float = 0.0
var stock: Dictionary = {}
var calls: PackedStringArray = []
## State seen in _ready (must always be the default state).
var ready_state: Dictionary = {}
## Whether the world had announced world_ready when load_state ran.
var loaded_after_world_ready: bool = false


func _ready() -> void:
	ready_state = save_state()
	EventBus.new_game_started.connect(_on_new_game_started)
	_log("ready")


func save_state() -> Dictionary:
	return {"pos": pos, "count": count, "tag": tag, "tags": tags.duplicate(), "ratio": ratio, "stock": stock.duplicate()}


func load_state(data: Dictionary) -> void:
	var world := owner
	loaded_after_world_ready = world != null and bool(world.get("is_world_ready"))
	pos = data.get("pos", Vector3.ZERO)
	count = data.get("count", 0)
	tag = data.get("tag", &"default")
	tags.assign(data.get("tags", []))
	ratio = data.get("ratio", 0.0)
	stock = (data.get("stock", {}) as Dictionary).duplicate()
	_log("load")


func post_load() -> void:
	_log("post_load")


func _on_new_game_started() -> void:
	count = start_count
	_log("new_game")


func _log(what: String) -> void:
	var entry := "%s:%s" % [save_id, what]
	calls.append(entry)
	if owner != null and owner.has_method("log_event"):
		owner.call("log_event", entry)
