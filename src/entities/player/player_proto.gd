extends CharacterBody3D
## Art-prototype player: only walks around so camera and scale can be judged.
## The real player controller is built in Phase 2 (Vertical Slice).

@export var move_speed: float = 3.2
@export var turn_speed: float = 10.0
@export var waddle_deg: float = 4.0
@export var waddle_speed: float = 9.0

@onready var model: Node3D = $Model

var _walk_time: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	if dir.length_squared() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		_walk_time += delta * waddle_speed
	else:
		_walk_time = lerpf(_walk_time, roundf(_walk_time / PI) * PI, clampf(8.0 * delta, 0.0, 1.0))
	model.rotation.z = sin(_walk_time) * deg_to_rad(waddle_deg)
	model.position.y = absf(sin(_walk_time)) * 0.04
