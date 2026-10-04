class_name StairPortal
extends Area3D
## G7 round 1 (user: „da sollen Treppen in die Gruft hinuntergehen"): the walk-through end of a
## stair. When the gravekeeper walks into this area along `direction` (node-local XZ, at least
## `min_speed` m/s), its target – a BuildingDoor (at the foot of the crypt stair outside: down into
## the room) or a RoomExit (high up the stair in the crypt room: up and out) – makes the same trip as
## [E] there: the short fade of the room's config, a carried corpse goes along, nothing while a trip
## runs or the target refuses (level 0, a building that forbids corpses). The trip starts on the
## stair itself, so the descent / the climb is seen before the fade.

const PLAYER_LAYER := 2

## Walking direction (node-local XZ) that uses the stair; the other way does nothing.
@export var direction: Vector2 = Vector2(0.0, -1.0)
## The BuildingDoor / RoomExit (relative to this node).
@export var target_path: NodePath = ^".."
@export var min_speed: float = 0.3


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for body: Node3D in get_overlapping_bodies():
		var player := body as Player
		if player != null and wants_through(player):
			use(player)


## Whether `player` walks this stair's way (along direction) and the target lets them through.
func wants_through(player: Player) -> bool:
	var target := target()
	if target == null or not target.has_method(&"can_interact") or not bool(target.call(&"can_interact", player)):
		return false
	var dir3 := global_transform.basis * Vector3(direction.x, 0.0, direction.y)
	var along := Vector2(dir3.x, dir3.z).normalized()
	return Vector2(player.velocity.x, player.velocity.z).dot(along) >= min_speed


## The target's trip (BuildingDoor.interact / RoomExit.interact).
func use(player: Player) -> void:
	var target := target()
	if target != null:
		target.call(&"interact", player)


func target() -> Node:
	return get_node_or_null(target_path) if is_inside_tree() else null
