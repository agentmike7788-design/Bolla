class_name HouseDoor
extends Node3D
## The door of a house one can enter in the village (docs/PHASE7_DESIGN.md §2.2, §3.4, §4.3):
## Village/Entities/door_<id> at the marker door_outside of the house, facing away from it (+Z).
## Open in open_windows ([from, to, from, to] minutes of day, `to` exclusive; empty = always); the
## surgery also while Lectures.door_open(door_id) (lecture night, only for the invited gravekeeper).
## Never with a corpse; closed → „Geschlossen. Öffnet um 14:00." interact: HutPortal.travel(…, room_id)
## to the room's spawn (fade of its InteriorConfig) – Player.region_id stays village. Whoever is inside
## when it closes may leave in peace (RoomExit with door_id checks no opening time).

const GROUP := &"house_door"
const FORMAT_CLOSED := "Geschlossen. Öffnet um %s."
const FORMAT_ENTER := "[E] %s betreten"
const TEXT_CLOSED := "Geschlossen."
const LECTURES_GROUP := &"lectures"
const MINUTES_PER_DAY := 1440

@export var door_id: StringName
@export var room_id: StringName
@export var display_name: String = ""
@export var open_windows: PackedInt32Array = []
## Where the gravekeeper stands after leaving the room (door-local, in front of the door).
@export var exit_offset: Vector3 = Vector3(0.0, 0.0, 0.3)

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


func is_open_now() -> bool:
	return is_open_at(TimeManager.minute_of_day) or _lecture_open()


## Whether minute `m` of the day lies in one of the open windows (a window may run over midnight).
func is_open_at(m: int) -> bool:
	if open_windows.is_empty():
		return true
	var t := posmod(m, MINUTES_PER_DAY)
	for i: int in range(0, open_windows.size() - 1, 2):
		var from := open_windows[i]
		var to := open_windows[i + 1]
		if (from <= to and t >= from and t < to) or (from > to and (t >= from or t < to)):
			return true
	return false


## Minute of day of the next opening (the next window start after now, wrapping into tomorrow), or -1
## (no windows = always open).
func next_opening() -> int:
	if open_windows.size() < 2:
		return -1
	var now := TimeManager.minute_of_day
	var best := -1
	var best_wait := MINUTES_PER_DAY + 1
	for i: int in range(0, open_windows.size() - 1, 2):
		var start := posmod(open_windows[i], MINUTES_PER_DAY)
		var wait := posmod(start - now, MINUTES_PER_DAY)
		if wait == 0:
			wait = MINUTES_PER_DAY
		if wait < best_wait:
			best_wait = wait
			best = start
	return best


## In front of the door, facing away from the house.
func exit_transform() -> Transform3D:
	var xform := global_transform if is_inside_tree() else transform
	return Transform3D(xform.basis.orthonormalized(), xform * exit_offset)


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or HutPortal.is_travelling(player) or is_instance_valid(player.carried):
		return false
	return room() != null and is_open_now()


func get_interaction_prompt(player: Player) -> String:
	if room() == null:
		return ""
	if player != null and is_instance_valid(player.carried):
		return HutDoor.TEXT_CORPSE_OUTSIDE
	if not is_open_now():
		var next := next_opening()
		return FORMAT_CLOSED % _clock(next) if next >= 0 else TEXT_CLOSED
	return FORMAT_ENTER % (display_name if display_name != "" else String(room_id))


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var target := room()
	HutPortal.travel(player, target.spawn_transform(), true, target.room_config().fade_seconds, target.room_id)


## The interior room behind the door (null while the world has none).
func room() -> InteriorRoom:
	return InteriorRoom.find(get_tree(), room_id) if is_inside_tree() and room_id != &"" else null


static func find(tree: SceneTree, id: StringName) -> HouseDoor:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is HouseDoor and (node as HouseDoor).door_id == id:
			return node as HouseDoor
	return null


## "14:00" for minute 840.
static func _clock(minute: int) -> String:
	return "%02d:%02d" % [int(minute / 60.0), minute % 60]


## Lectures.door_open(door_id) (lecture night) – false without a Lectures node.
func _lecture_open() -> bool:
	if not is_inside_tree():
		return false
	var lectures := get_tree().get_first_node_in_group(LECTURES_GROUP)
	return lectures != null and lectures.has_method(&"door_open") and bool(lectures.call(&"door_open", door_id))
