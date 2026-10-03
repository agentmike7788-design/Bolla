class_name CameraRig
extends Node3D
## Fixed-angle 2.5D follow camera. Switchable between a narrow-FOV perspective
## ("diorama") and an orthographic projection with matching framing.
## set_profile() swaps in a place framing (hut interior: distance, bounds, own environment).

signal projection_changed(orthographic: bool)

@export var target: Node3D
@export var pitch_deg: float = 45.0
@export var yaw_deg: float = 0.0
@export var fov_deg: float = 30.0
@export var distance: float = 22.0
@export var zoom_min: float = 10.0
@export var zoom_max: float = 34.0
@export var zoom_step: float = 2.0
@export var follow_speed: float = 5.0
@export var look_offset: Vector3 = Vector3(0, 0.8, 0)
@export var orthographic: bool = false
@export_group("Bounds")
## Clamp the followed focus point to [bounds_min, bounds_max] on XZ (off for the prototype).
@export var bounds_enabled: bool = false
@export var bounds_min: Vector2 = Vector2(-10.0, -10.0)
@export var bounds_max: Vector2 = Vector2(10.0, 10.0)

@onready var camera: Camera3D = $Camera3D

## Active place profile (set_profile), null = the rig's own framing (outdoors).
var profile: CameraProfile
var _focus: Vector3
## The rig's own framing, captured when the first profile replaces it.
var _own: CameraProfile
## Phase 7: the outdoor region's base profile (set_base_profile); null = none (bit-identical).
var base_profile: CameraProfile
## The base profile that was active when _own was captured (its zoom comes back with it).
var _own_base: CameraProfile
## Phase 3: the mouse wheel rotates the build preview while build mode is on – no zoom then.
var _zoom_locked: bool = false


func _ready() -> void:
	_focus = _clamped(target.global_position if target else global_position)
	_apply_projection()
	_update_transform()
	# A load (and a new game) places the player after this _ready: jump there instead of
	# sweeping across the map from the scene's start position (SL-2).
	EventBus.game_loaded.connect(_on_world_placed.unbind(1))
	EventBus.new_game_started.connect(_on_world_placed)
	EventBus.build_mode_changed.connect(_on_build_mode_changed)


func _process(delta: float) -> void:
	if target:
		_focus = _focus.lerp(_clamped(target.global_position), clampf(follow_speed * delta, 0.0, 1.0))
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if _zoom_locked:
		return
	if event.is_action_pressed("camera_zoom_in"):
		set_distance(distance - zoom_step)
	elif event.is_action_pressed("camera_zoom_out"):
		set_distance(distance + zoom_step)


func set_distance(value: float) -> void:
	distance = clampf(value, zoom_min, zoom_max)
	_apply_projection()


func toggle_projection() -> void:
	orthographic = not orthographic
	_apply_projection()
	projection_changed.emit(orthographic)


## Switches to a place profile (distance, zoom range, bounds, environment); the rig's own
## framing is kept and comes back with clear_profile(). Snap afterwards after a teleport.
func set_profile(value: CameraProfile) -> void:
	if value == null:
		clear_profile()
		return
	if profile == null:
		_own = _capture()
		_own_base = base_profile
	profile = value
	_apply(value)


## Back to the rig's own framing (and the zoom it had) – no-op without a profile. Phase 7: with a
## base profile that changed while the place profile was on (another region), back to that base.
func clear_profile() -> void:
	if profile == null:
		return
	profile = null
	if base_profile != null and base_profile != _own_base:
		_apply(base_profile)
	else:
		_apply(_own)


## Phase 7 (docs/PHASE7_DESIGN.md §3.4): the outdoor region's framing (RegionRoot.camera_profile).
## Applied at once while no place profile is on; otherwise kept, and clear_profile() returns to it
## (instead of the framing captured before the room). Without a call everything stays bit-identical.
## The same profile again (a load in the same region) keeps the current zoom.
func set_base_profile(p: CameraProfile) -> void:
	var changed := p != base_profile
	base_profile = p
	if p != null and profile == null and changed:
		_apply(p)


## Jump to the target immediately (used after teleports and for screenshots).
func snap() -> void:
	if target:
		_focus = _clamped(target.global_position)
	_update_transform()


func _on_build_mode_changed(active: bool) -> void:
	_zoom_locked = active


func _on_world_placed() -> void:
	if is_inside_tree() and is_instance_valid(target) and target.is_inside_tree():
		snap()


## The focus point for `p` (bounds applied when enabled).
func _clamped(p: Vector3) -> Vector3:
	if not bounds_enabled:
		return p
	return Vector3(clampf(p.x, bounds_min.x, bounds_max.x), p.y, clampf(p.z, bounds_min.y, bounds_max.y))


func _capture() -> CameraProfile:
	var own := CameraProfile.new()
	own.distance = distance
	own.zoom_min = zoom_min
	own.zoom_max = zoom_max
	own.bounds_enabled = bounds_enabled
	own.bounds_min = bounds_min
	own.bounds_max = bounds_max
	if camera:
		own.environment = camera.environment
		own.attributes = camera.attributes
	return own


func _apply(p: CameraProfile) -> void:
	zoom_min = p.zoom_min
	zoom_max = p.zoom_max
	bounds_enabled = p.bounds_enabled
	bounds_min = p.bounds_min
	bounds_max = p.bounds_max
	if camera:
		camera.environment = p.environment
		camera.attributes = p.attributes
	set_distance(p.distance)


func _apply_projection() -> void:
	if not camera:
		return
	if orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.0 * distance * tan(deg_to_rad(fov_deg) * 0.5)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov_deg
	camera.near = 0.5
	camera.far = distance + 60.0


func _update_transform() -> void:
	var dir := Vector3.BACK.rotated(Vector3.RIGHT, -deg_to_rad(pitch_deg)).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	var focus := _focus + look_offset
	camera.global_position = focus + dir * distance
	camera.look_at(focus, Vector3.UP)
