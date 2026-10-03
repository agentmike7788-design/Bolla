class_name RegionRoot
extends Node3D
## An outdoor region (docs/PHASE7_DESIGN.md §3.1, §3.4, §4.1): WorldRoot/Regions/Graveyard (manages
## the existing outdoor nodes through config.managed_paths, moves nothing) and
## WorldRoot/Regions/Village (the instance of src/world/village/village.tscn at (0, 0, 400)).
## EventBus.region_changed → apply_region: the inactive region's managed paths are hidden and
## PROCESS_MODE_DISABLED; the active one is shown (INHERIT), every Npc of the region refreshes, the
## camera rig gets camera_profile() as its base profile and snaps. Both regions share the one sun,
## WorldEnvironment and atmosphere (the profile has no environment of its own).
## Lookups: Waypoints/<id>, Spawns/<id> and GroundCollision/Shape of the region itself; the
## graveyard falls back to its WorldRoot (waypoints, ground), the rooms of the region (InteriorRoom
## with this region_id) add their Waypoints/<id> (v_in_*). Config: `config`, else
## Database.region_config(region_id).

const GROUP := &"region_root"
const GRAVEYARD := &"graveyard"
const VILLAGE := &"village"
const WAYPOINTS := "Waypoints"
const SPAWNS := "Spawns"
const GROUND_SHAPE := ^"GroundCollision/Shape"
## managed_paths entry for the region node itself (the village scene).
const SELF_PATH := "."

@export var region_id: StringName = &"graveyard"
@export var config: RegionConfig
@export var camera_rig_path: NodePath
@export var hide_when_inactive: bool = true

var active: bool = false

## The base profile handed to the rig (built once, so a repeated apply keeps the zoom).
var _base: CameraProfile
var _heightmap: HeightMapShape3D
var _heightmap_xform: Transform3D


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	EventBus.region_changed.connect(apply_region)
	_apply_initial.call_deferred()


## The RegionConfig (exported, else Database.region_config(region_id); null when unknown).
func region_config() -> RegionConfig:
	if config == null and region_id != &"" and is_inside_tree():
		var db := get_node_or_null(^"/root/Database")
		if db != null and db.has_method(&"region_config"):
			config = db.call(&"region_config", region_id) as RegionConfig
	return config


## The region's origin (config.origin; without a config the node's position).
func origin() -> Vector3:
	var c := region_config()
	if c != null:
		return c.origin
	return global_position if is_inside_tree() else position


## Waypoint position (like WorldRoot.get_waypoint; Graveyard delegates to WorldRoot).
func get_waypoint(id: StringName) -> Vector3:
	var marker := _waypoint_marker(id)
	if marker != null:
		return marker.global_position if marker.is_inside_tree() else marker.position
	var world := _outer_world()
	if world != null:
		return world.call(&"get_waypoint", id)
	push_warning("[RegionRoot] %s: unknown waypoint '%s'" % [region_id, id])
	return origin()


## Yaw (rad) an NPC standing at the waypoint should face; NAN = none.
func get_waypoint_facing(id: StringName) -> float:
	var marker := _waypoint_marker(id)
	if marker != null:
		if not marker.has_meta(&"facing"):
			return NAN
		return marker.global_rotation.y if marker.is_inside_tree() else marker.rotation.y
	var world := _outer_world()
	if world != null and world.has_method(&"get_waypoint_facing"):
		return float(world.call(&"get_waypoint_facing", id))
	return NAN


## Height of the ground at world (x, z): the region's own ground collision heightmap, else the
## WorldRoot's (graveyard), else the origin's height.
func ground_height(pos: Vector2) -> float:
	if _heightmap == null:
		var shape_node := get_node_or_null(GROUND_SHAPE) as CollisionShape3D
		if shape_node != null and shape_node.shape is HeightMapShape3D:
			_heightmap = shape_node.shape as HeightMapShape3D
			_heightmap_xform = shape_node.global_transform if shape_node.is_inside_tree() else transform * shape_node.transform
	if _heightmap != null:
		return _sample(pos)
	var world := _outer_world()
	if world != null and world.has_method(&"ground_height"):
		return float(world.call(&"ground_height", pos))
	return origin().y


## The marker Spawns/<spawn_id>; else (graveyard) the WorldRoot waypoint of that id with its facing;
## else the region's origin (warning).
func spawn_transform(spawn_id: StringName) -> Transform3D:
	var marker := get_node_or_null(NodePath("%s/%s" % [SPAWNS, spawn_id])) as Node3D
	if marker != null:
		var xform := marker.global_transform if marker.is_inside_tree() else transform * marker.transform
		return Transform3D(xform.basis.orthonormalized(), xform.origin)
	var world := _outer_world()
	if world != null and spawn_id != &"":
		var yaw := get_waypoint_facing(spawn_id)
		return Transform3D(Basis(Vector3.UP, 0.0 if is_nan(yaw) else yaw), world.call(&"get_waypoint", spawn_id))
	push_warning("[RegionRoot] %s: unknown spawn '%s'" % [region_id, spawn_id])
	return Transform3D(Basis.IDENTITY, origin())


## bounds = origin + config.bounds_*; distance / zoom from the config; no own environment (the
## regions share the WorldEnvironment). Without a config: the CameraProfile defaults.
func camera_profile() -> CameraProfile:
	var p := CameraProfile.new()
	var c := region_config()
	if c == null:
		return p
	p.distance = c.camera_distance
	p.zoom_min = c.camera_zoom_min
	p.zoom_max = c.camera_zoom_max
	p.pitch_deg = c.camera_pitch
	p.bounds_enabled = true
	var o := Vector2(c.origin.x, c.origin.z)
	p.bounds_min = o + c.bounds_min
	p.bounds_max = o + c.bounds_max
	return p


## EventBus.region_changed: active when current == region_id. Inactive: the managed paths hidden
## (hide_when_inactive) and PROCESS_MODE_DISABLED. Active: shown, INHERIT, every Npc of the region
## refreshes from the clock, the rig gets the base profile and snaps.
func apply_region(current: StringName) -> void:
	active = current == region_id
	for node: Node in managed_nodes():
		if hide_when_inactive and node is Node3D:
			(node as Node3D).visible = active
		node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not active or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.region_id == region_id and npc.is_node_ready():
			npc.refresh()
	var rig := camera_rig()
	if rig == null or not rig.is_node_ready():
		return
	if _base == null:
		_base = camera_profile()
	rig.set_base_profile(_base)
	rig.snap()


## The nodes of config.managed_paths ("." = this node; other paths relative to the parent, else
## to the nearest ancestor that has them – WorldRoot for the graveyard).
func managed_nodes() -> Array[Node]:
	var out: Array[Node] = []
	var c := region_config()
	if c == null:
		return out
	for path: String in c.managed_paths:
		var node: Node = self if path == SELF_PATH or path == "" else _find_from_ancestors(NodePath(path))
		if node != null and not out.has(node):
			out.append(node)
	return out


## The CameraRig: camera_rig_path, else the parent of the viewport's camera.
func camera_rig() -> CameraRig:
	if not is_inside_tree():
		return null
	if not camera_rig_path.is_empty():
		var rig := get_node_or_null(camera_rig_path) as CameraRig
		if rig != null:
			return rig
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	return cam.get_parent() as CameraRig if cam != null else null


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


func _apply_initial() -> void:
	if is_inside_tree():
		apply_region(current(get_tree()))


## Waypoints/<id> of the region, else of one of its rooms (InteriorRoom.region_id == region_id).
func _waypoint_marker(id: StringName) -> Node3D:
	var marker := get_node_or_null(NodePath("%s/%s" % [WAYPOINTS, id])) as Node3D
	if marker != null or not is_inside_tree():
		return marker
	for node: Node in get_tree().get_nodes_in_group(InteriorRoom.GROUP):
		var room := node as InteriorRoom
		if room != null and room.region_id == region_id:
			marker = room.get_node_or_null(NodePath("%s/%s" % [WAYPOINTS, id])) as Node3D
			if marker != null:
				return marker
	return null


## The graveyard's WorldRoot (the nearest ancestor with get_waypoint); null for other regions.
func _outer_world() -> Node:
	if region_id != GRAVEYARD:
		return null
	var node := get_parent()
	while node != null and not node.has_method(&"get_waypoint"):
		node = node.get_parent()
	return node


func _find_from_ancestors(path: NodePath) -> Node:
	var node := get_parent()
	while node != null:
		var found := node.get_node_or_null(path)
		if found != null:
			return found
		node = node.get_parent()
	return null


func _sample(pos: Vector2) -> float:
	var local := _heightmap_xform.affine_inverse() * Vector3(pos.x, 0.0, pos.y)
	var w := _heightmap.map_width
	var d := _heightmap.map_depth
	var gx := clampf(local.x + (w - 1) * 0.5, 0.0, w - 1.0)
	var gz := clampf(local.z + (d - 1) * 0.5, 0.0, d - 1.0)
	var x0 := mini(floori(gx), w - 2)
	var z0 := mini(floori(gz), d - 2)
	var fx := gx - x0
	var fz := gz - z0
	var data := _heightmap.map_data
	var h := lerpf(lerpf(data[z0 * w + x0], data[z0 * w + x0 + 1], fx),
			lerpf(data[(z0 + 1) * w + x0], data[(z0 + 1) * w + x0 + 1], fx), fz)
	return (_heightmap_xform * Vector3(local.x, h, local.z)).y
