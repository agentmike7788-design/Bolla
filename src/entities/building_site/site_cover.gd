class_name SiteCover
extends Node3D
## G7 round 1: the sod patch over the crypt stair pit (Entities/<site>_cover, built from the layout's
## buildings.sites[].stair.cover_rect): shown with its walkable collision while the building is below
## `min_open_level` (before the building opens, on the site, during level 0) – the approved ground
## look of the Alter Hof stays until the crypt has its stair; from that level on it is hidden and its
## collision disabled (the gravekeeper walks down the stair).

const BUILDINGS_GROUP := &"buildings"

@export var building_id: StringName = &"crypt"
@export var min_open_level: int = 1

var _applied := false
var _poll := 0.0


func _ready() -> void:
	EventBus.building_upgraded.connect(func(_id: StringName, _l: int) -> void: refresh())
	EventBus.game_loaded.connect(func(_s: int) -> void: refresh())
	EventBus.new_game_started.connect(refresh)
	EventBus.time_tick.connect(func(_d: int, _m: int) -> void: refresh())
	refresh()


## Whether the pit is covered now (the building's level < min_open_level).
func is_covering() -> bool:
	var b := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	var lvl := int(b.call(&"level", building_id)) if b != null and b.has_method(&"level") else 0
	return lvl < min_open_level


## Levels can also change by Buildings.load_state alone (debug, shots): a cheap check twice a second.
func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		refresh()


func refresh() -> void:
	var on := is_covering()
	if on == visible and is_node_ready() and _applied:
		return
	_applied = true
	visible = on
	for node: Node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = not on
