class_name InteriorRoom
extends Node3D
## STUB (P6) – root of an interior scene (docs/PHASE6_DESIGN.md §3.4, §4.7, §4.8), the core of
## HutInterior (docs/VERTICAL_SLICE_DESIGN.md §11): its own scene far from the world, spawn,
## camera profile, own sun / environment, InteriorLighting. On EventBus.interior_room_changed it is
## active when current == room_id; hide_when_inactive rooms are only visible while active.
## apply_level shows / hides children with meta "min_level" / "max_level" (collision with them).
## W1 (P6) fills the bodies; the signatures are the contract. HutInterior extends it in W1 (P6).

const GROUP := &"interior_room"

@export var room_id: StringName = &"hut"
@export var config: InteriorConfig
@export var environment: Environment
@export var camera_attributes: CameraAttributes
## Focus bounds of the interior camera, room-local XZ.
@export var bounds_min: Vector2 = Vector2(-0.5, -0.3)
@export var bounds_max: Vector2 = Vector2(0.5, 0.3)
@export var camera_rig_path: NodePath
@export var outdoor_sun_path: NodePath
## New rooms true, the hut false (bit-identical).
@export var hide_when_inactive: bool = false
## "" = the hut (no levels).
@export var building_id: StringName = &""

var active: bool = false


func _init() -> void:
	add_to_group(GROUP)


## Where the gravekeeper appears when entering (spawn_inside).
func spawn_transform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


## The CameraRig profile of the room.
func camera_profile() -> CameraProfile:
	return CameraProfile.new()


## EventBus.interior_room_changed: active when current == room_id; sun, profile, visibility.
func apply_room(_current: StringName) -> void:
	pass


## Children with meta "min_level" / "max_level" shown / hidden (collision with them).
func apply_level(_level: int) -> void:
	pass


## The room with `room_id` in the tree (null if none).
static func find(tree: SceneTree, id: StringName) -> InteriorRoom:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var room := node as InteriorRoom
		if room != null and room.room_id == id:
			return room
	return null
