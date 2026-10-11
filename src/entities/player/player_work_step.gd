class_name PlayerWorkStep
extends RefCounted
## G8 Runde 3 (Tischarbeit): the gravekeeper's short step to his work spot when a timed action starts – at the
## morgue table to its long side or its head end, facing the work (MorgueTable.work_stand). Presentation only:
## the action's game logic never depends on where he stands. Player.step_to starts it while an action runs;
## the Player moves it on in _physics_process and stops it when the action ends or is cancelled.

var _player: Node3D
var _from: Transform3D
var _to: Transform3D
var _seconds: float = 0.3
## Seconds since the step began (< 0 = no step).
var _t: float = -1.0


func _init(player: Node3D) -> void:
	_player = player


func begin(target: Transform3D, seconds: float) -> void:
	_from = _player.global_transform
	_to = Transform3D(target.basis.orthonormalized(), target.origin)
	_seconds = maxf(seconds, 0.0001)
	_t = 0.0
	if seconds <= 0.0:
		update(0.0)


func is_active() -> bool:
	return _t >= 0.0


## Where the step ends (the last begin()).
func target() -> Transform3D:
	return _to


func update(delta: float) -> void:
	if _t < 0.0:
		return
	_t = minf(_t + delta, _seconds)
	var w := smoothstep(0.0, 1.0, _t / _seconds)
	_player.global_transform = _from.interpolate_with(_to, w) if w < 1.0 else _to
	if _t >= _seconds:
		_t = -1.0


func stop() -> void:
	_t = -1.0
