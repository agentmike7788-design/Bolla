class_name HouseDoor
extends Node3D
## STUB (P1) – the door of a house one can enter in the village (docs/PHASE7_DESIGN.md §2.2, §3.4, §4.3):
## Village/Entities/door_<id>. Open in open_windows ([from, to, from, to] minutes of day; empty = always);
## the surgery also while Lectures.door_open(door_id) (lecture night, only for the invited gravekeeper).
## Never with a corpse; closed → „Geschlossen. Öffnet um 14:00." interact: HutPortal.travel(…, room_id) –
## Player.region_id stays village. Whoever is inside when it closes may leave in peace.
## W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"house_door"
const FORMAT_CLOSED := "Geschlossen. Öffnet um %s."
const FORMAT_ENTER := "[E] %s betreten"

@export var door_id: StringName
@export var room_id: StringName
@export var display_name: String = ""
@export var open_windows: PackedInt32Array = []

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


func is_open_now() -> bool:
	return false


## Minute of day of the next opening, or -1.
func next_opening() -> int:
	return -1


## The marker door_outside of the house model.
func exit_transform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


static func find(tree: SceneTree, id: StringName) -> HouseDoor:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is HouseDoor and (node as HouseDoor).door_id == id:
			return node as HouseDoor
	return null
