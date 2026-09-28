class_name BuildingDoor
extends Node3D
## Entities/door_<id> at the marker door_outside of the outdoor model (from level 1)
## (docs/PHASE6_DESIGN.md §3.4, §4.7), group building_door, facing away from the building (+Z).
## Prompt BuildingData.prompt_enter („[E] Gruft betreten"); carrying a corpse only when the
## building allows_corpse (crypt, chapel), else HutDoor.TEXT_CORPSE_OUTSIDE and no entry; level 0
## (a site): no prompt. Travels (fade InteriorConfig.fade_seconds) to the room's spawn with
## Player.set_in_interior(true, room_id) – HutPortal, like the hut door. A carried corpse goes
## along in the gravekeeper's arms.

const GROUP := &"building_door"
const BUILDINGS_GROUP := &"buildings"

@export var building_id: StringName
## Where the gravekeeper stands after leaving the room (door-local, in front of the door).
@export var exit_offset: Vector3 = Vector3(0.0, 0.0, 0.3)
## The building's data; null = Database.building(building_id) (tests set a fixture).
var data: BuildingData

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


## Level ≥ 1 (Buildings.level; no Buildings node → closed).
func is_open() -> bool:
	return building_level(get_tree() if is_inside_tree() else null, building_id) >= 1


## Where the gravekeeper stands after leaving the room (in front of the door, facing away).
func exit_transform() -> Transform3D:
	var xform := global_transform if is_inside_tree() else transform
	return Transform3D(xform.basis.orthonormalized(), xform * exit_offset)


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or HutPortal.is_travelling(player) or not is_open():
		return false
	var info := building_data()
	if info == null or room() == null:
		return false
	return info.allows_corpse or not is_instance_valid(player.carried)


func get_interaction_prompt(player: Player) -> String:
	var info := building_data()
	if info == null or not is_open() or room() == null:
		return ""
	if player != null and is_instance_valid(player.carried) and not info.allows_corpse:
		return HutDoor.TEXT_CORPSE_OUTSIDE
	return info.prompt_enter


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var target := room()
	HutPortal.travel(player, target.spawn_transform(), true, target.room_config().fade_seconds, target.room_id)


## The BuildingData (fixture or Database), null when unknown.
func building_data() -> BuildingData:
	if data == null and building_id != &"" and is_inside_tree():
		var db := get_node_or_null(^"/root/Database")
		if db != null:
			data = db.call(&"building", building_id) as BuildingData
	return data


## The interior room of the building (null while the world has none).
func room() -> InteriorRoom:
	var info := building_data()
	if info == null or not is_inside_tree():
		return null
	return InteriorRoom.find(get_tree(), info.room_id if info.room_id != &"" else building_id)


## Buildings.level(building_id) in `tree` (0 without a Buildings node).
static func building_level(tree: SceneTree, id: StringName) -> int:
	if tree == null or id == &"":
		return 0
	var buildings := tree.get_first_node_in_group(BUILDINGS_GROUP)
	if buildings == null or not buildings.has_method(&"level"):
		return 0
	return int(buildings.call(&"level", id))


## The door of `id` in `tree` (null if none).
static func find(tree: SceneTree, id: StringName) -> BuildingDoor:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var door := node as BuildingDoor
		if door != null and door.building_id == id:
			return door
	return null
