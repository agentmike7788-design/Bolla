class_name RegionRoot
extends Node3D
## STUB (P1) – an outdoor region (docs/PHASE7_DESIGN.md §3.1, §3.4, §4.1): WorldRoot/Regions/Graveyard
## (manages the existing outdoor nodes through config.managed_paths, moves nothing) and
## WorldRoot/Regions/Village (the instance of src/world/village/village.tscn at (0, 0, 400)).
## EventBus.region_changed → apply_region: the inactive region's managed paths are hidden and
## PROCESS_MODE_DISABLED; the active one is shown (INHERIT), every Npc refreshes, the camera rig gets
## camera_profile() as its base profile and snaps. W1 (P1) fills the bodies; the signatures are the contract.

const GROUP := &"region_root"
const GRAVEYARD := &"graveyard"
const VILLAGE := &"village"

@export var region_id: StringName = &"graveyard"
@export var config: RegionConfig
@export var camera_rig_path: NodePath
@export var hide_when_inactive: bool = true

var active: bool = false


func _init() -> void:
	add_to_group(GROUP)


## Waypoint position (like WorldRoot.get_waypoint; Graveyard delegates to WorldRoot).
func get_waypoint(_id: StringName) -> Vector3:
	return Vector3.ZERO


func get_waypoint_facing(_id: StringName) -> float:
	return 0.0


func ground_height(_pos: Vector2) -> float:
	return 0.0


## The marker Spawns/<spawn_id>.
func spawn_transform(_spawn_id: StringName) -> Transform3D:
	return global_transform if is_inside_tree() else transform


## bounds = origin + config.bounds_*.
func camera_profile() -> CameraProfile:
	return CameraProfile.new()


## EventBus.region_changed: active / inactive (see the class comment).
func apply_region(current: StringName) -> void:
	active = current == region_id


## The region root with this id in the tree (null = none).
static func find(tree: SceneTree, id: StringName) -> RegionRoot:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		if node is RegionRoot and (node as RegionRoot).region_id == id:
			return node as RegionRoot
	return null


## Player.region_id (graveyard without a player).
static func current(tree: SceneTree) -> StringName:
	var player := tree.get_first_node_in_group(&"player") as Player if tree != null else null
	return player.region_id if player != null else GRAVEYARD
