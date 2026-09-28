class_name RoomExit
extends Node3D
## The way out of a building's room at the marker door_inside (docs/PHASE6_DESIGN.md §3.4,
## §4.7): BuildingData.prompt_exit („[E] Hinaufgehen" in the crypt, else „[E] Hinausgehen");
## travels to BuildingDoor.exit_transform() with inside false (fade of the room's config). A
## carried corpse goes along when the building allows_corpse (else HutDoor.TEXT_CORPSE_OUTSIDE –
## the shed cannot be entered with one anyway). Scene: room_exit.tscn (Interactable).

const PROMPT_OUT := "[E] Hinausgehen"

@export var building_id: StringName
## The building's data; null = the outside door's (or Database.building(building_id)).
var data: BuildingData

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or HutPortal.is_travelling(player) or _door() == null:
		return false
	var info := building_data()
	return info == null or info.allows_corpse or not is_instance_valid(player.carried)


func get_interaction_prompt(player: Player) -> String:
	if _door() == null:
		return ""
	var info := building_data()
	if info != null and player != null and is_instance_valid(player.carried) and not info.allows_corpse:
		return HutDoor.TEXT_CORPSE_OUTSIDE
	return info.prompt_exit if info != null and info.prompt_exit != "" else PROMPT_OUT


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	HutPortal.travel(player, _door().exit_transform(), false, _fade_seconds())


## The BuildingData (own, the door's, or Database), null when unknown.
func building_data() -> BuildingData:
	if data == null:
		var door := _door()
		if door != null:
			data = door.building_data()
		elif building_id != &"" and is_inside_tree():
			var db := get_node_or_null(^"/root/Database")
			if db != null:
				data = db.call(&"building", building_id) as BuildingData
	return data


func _door() -> BuildingDoor:
	return BuildingDoor.find(get_tree(), building_id) if is_inside_tree() else null


func _fade_seconds() -> float:
	var node := get_parent()
	while node != null and not node is InteriorRoom:
		node = node.get_parent()
	var room := node as InteriorRoom
	return room.room_config().fade_seconds if room != null else InteriorConfig.resolve(null).fade_seconds
