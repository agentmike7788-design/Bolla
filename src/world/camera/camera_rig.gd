class_name CameraRig
extends Node3D
## Fixed-angle 2.5D follow camera. Switchable between a narrow-FOV perspective
## ("diorama") and an orthographic projection with matching framing.

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

var _focus: Vector3


func _ready() -> void:
	_focus = _clamped(target.global_position if target else global_position)
	_apply_projection()
	_update_transform()


func _process(delta: float) -> void:
	if target:
		_focus = _focus.lerp(_clamped(target.global_position), clampf(follow_speed * delta, 0.0, 1.0))
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
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


## Jump to the target immediately (used after teleports and for screenshots).
func snap() -> void:
	if target:
		_focus = _clamped(target.global_position)
	_update_transform()


## The focus point for `p` (bounds applied when enabled).
func _clamped(p: Vector3) -> Vector3:
	if not bounds_enabled:
		return p
	return Vector3(clampf(p.x, bounds_min.x, bounds_max.x), p.y, clampf(p.z, bounds_min.y, bounds_max.y))


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
