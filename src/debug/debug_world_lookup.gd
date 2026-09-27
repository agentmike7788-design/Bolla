class_name DebugWorldLookup
extends RefCounted
## Scene-tree lookups for the debug commands (DebugCommands): player, inventory, world root,
## NPCs, camera rig – and the player teleport. Works without a world: every getter may return
## null. Holds the console node only to reach the tree and to skip it while searching.

const PLAYER_GROUP := &"player"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const DROPOFF_GROUP := &"dropoff"
const NPC_GROUP := &"npc"

var _console: Node


func _init(console: Node) -> void:
	_console = console


func teleport_player(p: Node3D, pos: Vector3) -> void:
	p.global_position = pos
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	var rig := camera_rig()
	if rig != null:
		rig.snap()


func player() -> Node:
	return group_node(PLAYER_GROUP)


func inventory() -> Inventory:
	var p := player()
	return p.get(&"inventory") as Inventory if p != null else null


func group_node(group: StringName) -> Node:
	return _console.get_tree().get_first_node_in_group(group)


## The world root: the current scene or a root child offering get_waypoint (WorldRoot API).
func world() -> Node:
	var tree := _console.get_tree()
	var scene := tree.current_scene
	if scene != null and scene.has_method(&"get_waypoint") and scene.has_method(&"get_node_by_layout_id"):
		return scene
	for child: Node in tree.root.get_children():
		if child.has_method(&"get_waypoint") and child.has_method(&"get_node_by_layout_id"):
			return child
	return null


func npc_node(npc_id: StringName) -> Node3D:
	for node: Node in _console.get_tree().get_nodes_in_group(NPC_GROUP):
		if StringName(str(node.get(&"npc_id"))) == npc_id and node is Node3D:
			return node as Node3D
	return null


func camera_rig() -> CameraRig:
	return _find_rig(_console.get_tree().root)


func _find_rig(node: Node) -> CameraRig:
	if node is CameraRig:
		return node as CameraRig
	for child: Node in node.get_children():
		if child == _console:
			continue
		var found := _find_rig(child)
		if found != null:
			return found
	return null
