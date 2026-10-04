class_name PlayerBurial
extends RefCounted
## G7 Runde 2 (Bestatten, "Beim Bestatten soll er die Leiche sichtbar ins Grab legen"): presentation
## of one burial at an open pit, driven by the running timed action's elapsed seconds
## (ToolAnimConfig burial_*; PlayerAnimator plays the clip this returns):
##   STEP     he steps to the pit's long side (carry_walk; burial_stands, the first free spot),
##   LOWER    bows and lays the carried dead onto the pit floor (corpse_lower) – the corpse node moves
##            from the CarrySocket over the pit (in his hands), then sinks onto the floor
##            (burial_corpse_offset, head at the marker end; corpse_down sounds),
##   SILENCE  a moment of silence (mourn),
##   FILL     draws the shovel and fills (dig): with every throw (on_throw) the fresh mound rises
##            in the pit and the corpse settles into the earth; the last throw ends the action –
##            Graveyard.bury frees the corpse node and the plot shows its mound as before.
## The corpse stays the CarrySocket's child (Player.carried) the whole time: only its global
## transform is set. Cancelling (moving off) puts it back into the arms; reset() (loading, rooms)
## at once. Nothing here is saved or touches the records – the game logic is GravePlot's.

enum Stage { NONE, STEP, LOWER, SILENCE, FILL }

const FILL_NODE := "BurialFill"

var stage: Stage = Stage.NONE
## The plot being buried at (null = no burial presentation).
var plot: GravePlot
## Throws so far in the FILL stage.
var throws: int = 0
var _player: Player
var _tools: ToolAnimConfig
var _from: Transform3D
var _to: Transform3D
var _corpse_from: Transform3D
var _laid: bool = false
var _fill: Node3D
var _fill_scale: float = 0.0
var _fill_target: float = 0.0
var _sink: float = 0.0
## The corpse node returning into the arms after a cancel.
var _returning: Node3D


func _init(player: Player, tools: ToolAnimConfig) -> void:
	_player = player
	_tools = tools


## Starts the presentation for the burial at `at` (the action itself is started by the Player).
func begin(at: GravePlot) -> void:
	_clear()
	plot = at
	stage = Stage.STEP
	_from = _player.global_transform
	_to = stand_transform()
	_laid = false
	throws = 0


func is_active() -> bool:
	return stage != Stage.NONE and is_instance_valid(plot)


## The clip of the burial `action` at its elapsed time (the fill clip without a presentation).
func clip(action: Player.TimedAction) -> StringName:
	if not is_active() or action == null:
		return _tools.burial_fill_clip
	match _stage_at(action.elapsed):
		Stage.STEP:
			return _tools.burial_step_clip
		Stage.LOWER:
			return _tools.burial_lower_clip
		Stage.SILENCE:
			return _tools.burial_mourn_clip
	return _tools.burial_fill_clip


## Every animator update: `action` = the running action (null when idle).
func update(delta: float, action: Player.TimedAction) -> void:
	if not is_active():
		_return_corpse(delta)
		return
	if action == null or action.animation != _tools.burial_action_clip:
		_cancelled()
		_return_corpse(delta)
		return
	var t := action.elapsed
	stage = _stage_at(t)
	_place_player(t)
	_place_corpse(t)
	_grow_fill(delta)


## A filling throw left the shovel: the earth rises one step (the last throw ends the action).
func on_throw() -> void:
	if not is_active() or stage != Stage.FILL:
		return
	throws += 1
	var i := throws - 1
	if i < _tools.burial_fill_scales.size():
		_fill_target = _tools.burial_fill_scales[i]
	if i < _tools.burial_sink.size():
		_sink = _tools.burial_sink[i]
	_ensure_fill()


## Where he stands for the burial (global): the first burial_stands spot whose capsule is free,
## facing the pit's centre line; none free: where he is, turned towards the pit.
func stand_transform() -> Transform3D:
	var here := _player.global_position
	var spot := here
	var aim := Vector3.ZERO
	for local: Vector3 in _tools.burial_stands:
		var g := plot.to_global(local)
		if plot.spot_is_free(_player, g):
			spot = Vector3(g.x, here.y, g.z)
			aim = Vector3(0.0, 0.0, clampf(local.z, -0.5, 0.5))
			break
	var target := plot.to_global(aim)
	var dir := Vector3(target.x - spot.x, 0.0, target.z - spot.z)
	var yaw := atan2(dir.x, dir.z) if dir.length_squared() > 0.0001 else _player.rotation.y
	return Transform3D(Basis(Vector3.UP, yaw), spot)


## The corpse lying on the pit floor (global, before it settles into the earth).
func corpse_target() -> Transform3D:
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(_tools.burial_corpse_yaw_deg)), _tools.burial_corpse_offset)
	return plot.global_transform * local


## The earth rising in the pit (null before the first throw).
func fill_node() -> Node3D:
	return _fill if is_instance_valid(_fill) else null


## Back to no burial at once: the corpse in the arms, no earth (loading, changing rooms).
func reset() -> void:
	_clear()
	var node := _carried()
	if node != null:
		node.transform = Transform3D.IDENTITY
	_returning = null


# --- stages ------------------------------------------------------------------------------

func _stage_at(t: float) -> Stage:
	var lower_at := _tools.burial_step_seconds
	var silence_at := lower_at + _tools.burial_lower_seconds
	var fill_at := silence_at + _tools.burial_silence_seconds
	if t < lower_at:
		return Stage.STEP
	if t < silence_at:
		return Stage.LOWER
	if t < fill_at:
		return Stage.SILENCE
	return Stage.FILL


func _place_player(t: float) -> void:
	var w := rig_ease(t / maxf(_tools.burial_step_seconds, 0.0001))
	var xf := _from.interpolate_with(_to, w) if w < 1.0 else _to
	if not _player.global_transform.is_equal_approx(xf):
		_player.global_transform = xf


func _place_corpse(t: float) -> void:
	var node := _carried()
	if node == null:
		return
	if stage == Stage.STEP:
		node.transform = Transform3D.IDENTITY
		_corpse_from = node.global_transform
		return
	var u := clampf((t - _tools.burial_step_seconds) / maxf(_tools.burial_lower_seconds, 0.0001), 0.0, 1.0)
	if stage != Stage.LOWER:
		u = 1.0
	if _corpse_from == Transform3D():
		_corpse_from = (_player.carry_socket.global_transform)
	var target := corpse_target()
	var hover := Transform3D(target.basis, target.origin + Vector3.UP * _tools.burial_hover_height)
	var xf: Transform3D
	if u < _tools.burial_release_at:
		xf = _corpse_from.interpolate_with(hover, rig_ease(u / maxf(_tools.burial_release_at, 0.0001)))
	else:
		var span := maxf(_tools.burial_touch_at - _tools.burial_release_at, 0.0001)
		xf = hover.interpolate_with(target, rig_ease((u - _tools.burial_release_at) / span))
	if u >= _tools.burial_touch_at and not _laid:
		_laid = true
		_play(_tools.burial_down_cue)
	xf.origin.y -= _sink_now()
	node.global_transform = xf


## The corpse settles with the earth (follows the rising mound).
func _sink_now() -> float:
	if _fill_target <= 0.0:
		return 0.0
	return _sink * clampf(_fill_scale / _fill_target, 0.0, 1.0)


func _grow_fill(delta: float) -> void:
	if _fill_target <= 0.0:
		return
	_ensure_fill()
	var w := 1.0 if delta <= 0.0 else clampf(1.0 - exp(-_tools.burial_fill_rate * delta), 0.0, 1.0)
	_fill_scale = lerpf(_fill_scale, _fill_target, w)
	if absf(_fill_scale - _fill_target) < 0.002:
		_fill_scale = _fill_target
	if _fill != null:
		_fill.scale = Vector3(1.0, maxf(_fill_scale, 0.01), 1.0)


## The fresh mound (the plot's FILLED model) under the plot's Visual, so the state change to FILLED
## frees it with the pit.
func _ensure_fill() -> void:
	if is_instance_valid(_fill) or not is_instance_valid(plot) or plot.mound_model == null:
		return
	var visual := plot.get_node_or_null(^"Visual") as Node3D
	if visual == null:
		return
	_fill = plot.mound_model.instantiate() as Node3D
	_fill.name = FILL_NODE
	_fill.position = plot.mound_offset
	_fill.scale = Vector3(1.0, 0.01, 1.0)
	visual.add_child(_fill)


## The action ended without the bury (cancelled): the corpse goes back into his arms.
func _cancelled() -> void:
	_returning = _carried()
	_clear()


func _return_corpse(delta: float) -> void:
	if not is_instance_valid(_returning):
		_returning = null
		return
	if _returning != _carried():
		_returning = null
		return
	var w := 1.0 if delta <= 0.0 else clampf(1.0 - exp(-_tools.burial_return_rate * delta), 0.0, 1.0)
	_returning.transform = _returning.transform.interpolate_with(Transform3D.IDENTITY, w)
	if _returning.transform.is_equal_approx(Transform3D.IDENTITY) or \
			_returning.transform.origin.length() < 0.002:
		_returning.transform = Transform3D.IDENTITY
		_returning = null


func _clear() -> void:
	if is_instance_valid(_fill):
		_fill.get_parent().remove_child(_fill)
		_fill.queue_free()
	_fill = null
	_fill_scale = 0.0
	_fill_target = 0.0
	_sink = 0.0
	_corpse_from = Transform3D()
	stage = Stage.NONE
	plot = null
	throws = 0


func _carried() -> Node3D:
	var node := _player.carried
	if is_instance_valid(node) and node.get_parent() == _player.carry_socket:
		return node
	return null


func _play(cue: StringName) -> void:
	var audio := _player.get_node_or_null(^"/root/Audio")
	if audio != null and audio.has_method(&"play"):
		audio.call(&"play", cue)


## Smooth 0..1 (cosine, like the rig's ease).
static func rig_ease(x: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(x, 0.0, 1.0))
