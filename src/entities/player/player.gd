class_name Player
extends CharacterBody3D
## The gravekeeper (groups player, saveable).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

enum State { FREE, CARRYING, LOCKED }

@export var save_id: String = "player"
@export var save_order: int = 100

var config: PlayerConfig
var actions: ActionConfig
var state: State = State.FREE
var inventory: Inventory
var carried: Node3D
var carried_id: String = ""
var instant_actions: bool = false

func is_busy() -> bool:
	push_warning("STUB Player.is_busy")
	return false


func attach_carried(node: Node3D, id: String) -> void:
	push_warning("STUB Player.attach_carried")


func detach_carried() -> Node3D:
	push_warning("STUB Player.detach_carried")
	return null


func start_timed_action(label: String, game_minutes: int, on_done: Callable, cancellable: bool = true) -> bool:
	push_warning("STUB Player.start_timed_action")
	return false


func cancel_timed_action() -> void:
	push_warning("STUB Player.cancel_timed_action")


func apply_start_inventory() -> void:
	push_warning("STUB Player.apply_start_inventory")


func drop_position() -> Transform3D:
	push_warning("STUB Player.drop_position")
	return Transform3D()


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
