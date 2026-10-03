class_name InteriorRoom
extends Node3D
## Root of an interior scene (docs/PHASE6_DESIGN.md §3.4, §4.7, §4.8), the core of HutInterior
## (docs/VERTICAL_SLICE_DESIGN.md §11): its own scene far from the world with a spawn (child
## "Spawn"), a camera profile (distance / zoom from its InteriorConfig, bounds around the room, own
## Environment), a soft own sun (child "Sun") and InteriorLighting.
## On EventBus.interior_room_changed(current) the room is active when current == room_id: its sun
## on, the outdoor sun off, the CameraRig on its profile. Another room taking over leaves the rig
## and the outdoor sun to that room; "" (outside) restores both. hide_when_inactive rooms (the
## Phase-6 buildings) are only visible while active (one room of lights and draw calls at a time).
## apply_level(level) shows / hides children with meta "min_level" / "max_level" (building levels,
## collision and interaction with them: hidden children are PROCESS_MODE_DISABLED).
## Config: the exported `config`, else Database.interior_config(room_id) (missing → the hut's).

const GROUP := &"interior_room"
const META_MIN_LEVEL := &"min_level"
const META_MAX_LEVEL := &"max_level"
## The room of the hut (HutInterior); "" = outside.
const HUT := &"hut"

@export var room_id: StringName = &"hut"
@export var config: InteriorConfig
## Camera environment while inside (the graveyard's fog and moonlight stay outside).
@export var environment: Environment
@export var camera_attributes: CameraAttributes
## Focus bounds of the interior camera, room-local XZ.
@export var bounds_min: Vector2 = Vector2(-0.5, -0.3)
@export var bounds_max: Vector2 = Vector2(0.5, 0.3)
## Set by the world builder: the CameraRig and the outdoor DirectionalLight3D.
@export var camera_rig_path: NodePath
@export var outdoor_sun_path: NodePath
## New rooms true, the hut false (bit-identical).
@export var hide_when_inactive: bool = false
## "" = the hut (no levels).
@export var building_id: StringName = &""
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P1): the outdoor region of the room (docs / tests only).
@export var region_id: StringName = &"graveyard"

## True while the view shows this room.
var active: bool = false
## The level last applied by apply_level (-1 = never).
var level: int = -1

@onready var sun: DirectionalLight3D = get_node_or_null(^"Sun") as DirectionalLight3D
@onready var spawn: Marker3D = get_node_or_null(^"Spawn") as Marker3D


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	config = room_config()
	if sun != null:
		sun.visible = false
	if hide_when_inactive:
		visible = false
		_set_lighting_running(false)
	EventBus.interior_room_changed.connect(apply_room)
	if building_id != &"":
		apply_level(_building_level())


## The InteriorConfig of this room: `config`, else Database.interior_config(room_id), else the
## defaults (resolved once; children such as InteriorLighting call it before the room's _ready).
func room_config() -> InteriorConfig:
	if config == null:
		config = InteriorConfig.for_room(room_id)
	return config


## Where the gravekeeper appears when entering: spawn_inside, facing into the room (−Z).
func spawn_transform() -> Transform3D:
	if spawn == null:
		spawn = get_node_or_null(^"Spawn") as Marker3D
	if spawn == null:
		return global_transform if is_inside_tree() else transform
	return spawn.global_transform if spawn.is_inside_tree() else transform * spawn.transform


## The CameraRig profile of the room: config distance / zoom, bounds around the room, own env.
func camera_profile() -> CameraProfile:
	var c := room_config()
	var p := CameraProfile.new()
	p.distance = c.camera_distance
	p.zoom_min = c.camera_zoom_min
	p.zoom_max = c.camera_zoom_max
	var origin := global_position if is_inside_tree() else position
	p.bounds_enabled = true
	p.bounds_min = Vector2(origin.x, origin.z) + bounds_min
	p.bounds_max = Vector2(origin.x, origin.z) + bounds_max
	p.environment = environment
	p.attributes = camera_attributes
	return p


## EventBus.interior_room_changed: active when current == room_id; sun, visibility, and – when
## this room becomes active or the gravekeeper is outside (current "") – outdoor sun and profile.
func apply_room(current: StringName) -> void:
	if not is_inside_tree():
		return
	var now := current == room_id
	active = now
	if sun != null:
		sun.visible = now
	if hide_when_inactive:
		visible = now
		_set_lighting_running(now)
	if not now and current != &"":
		return  # another room took over: its apply_room sets the outdoor sun and the rig
	var outdoor := get_node_or_null(outdoor_sun_path) as Light3D if not outdoor_sun_path.is_empty() else null
	if outdoor != null:
		outdoor.visible = not now
	var rig := get_node_or_null(camera_rig_path) as CameraRig if not camera_rig_path.is_empty() else null
	if rig == null or not rig.is_node_ready():
		return
	if now:
		rig.set_profile(camera_profile())
	else:
		rig.clear_profile()
	rig.snap()


## Children (any depth) with meta "min_level" / "max_level" are shown when
## min_level <= level <= max_level (max_level <= 0 or absent = no upper limit); hidden ones are
## PROCESS_MODE_DISABLED, which takes their bodies, areas and interactables out of physics.
func apply_level(value: int) -> void:
	level = value
	for node: Node in find_children("*", "Node3D", true, false):
		if not (node.has_meta(META_MIN_LEVEL) or node.has_meta(META_MAX_LEVEL)):
			continue
		var on := is_shown_at(node, value)
		(node as Node3D).visible = on
		node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Whether `node` (meta min_level / max_level) belongs to the room at `value`.
static func is_shown_at(node: Node, value: int) -> bool:
	var lo := int(node.get_meta(META_MIN_LEVEL, 0))
	var hi := int(node.get_meta(META_MAX_LEVEL, 0))
	return value >= lo and (hi <= 0 or value <= hi)


## The room with `room_id` in the tree (null if none).
static func find(tree: SceneTree, id: StringName) -> InteriorRoom:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var room := node as InteriorRoom
		if room != null and room.room_id == id:
			return room
	return null


## Buildings.level(building_id) (0 without a Buildings node).
func _building_level() -> int:
	if building_id == &"" or not is_inside_tree():
		return 0
	var buildings := get_tree().get_first_node_in_group(&"buildings")
	if buildings == null or not buildings.has_method(&"level"):
		return 0
	return int(buildings.call(&"level", building_id))


## InteriorLighting of a hidden room does not run (§9: only the active room).
func _set_lighting_running(on: bool) -> void:
	for node: Node in get_children():
		if node is InteriorLighting:
			node.set_process(on)
			if on:
				(node as InteriorLighting).apply_minute((node as InteriorLighting).clock_minute())
