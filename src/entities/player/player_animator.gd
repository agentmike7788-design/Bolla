class_name PlayerAnimator
extends RefCounted
## Animation driver of the Player: plays the rig clips (idle / walk / carry_idle / carry_walk /
## the running action's clip) on the Model's AnimationPlayer, or waddles a model without
## AnimationPlayer procedurally (as in the prototype). Values: the Player's anim/waddle exports.

## The rig's AnimationPlayer anywhere under the Model (null = procedural waddle).
var anim: AnimationPlayer
var _player: Player
var _walk_time: float = 0.0


func _init(player: Player) -> void:
	_player = player
	var found := player.model.find_children("*", "AnimationPlayer", true, false)
	anim = found[0] as AnimationPlayer if not found.is_empty() else null


## Moves the Lantern light onto the rig's light_lantern marker, so it swings with the hips.
func attach_lantern() -> void:
	var model := _player.model
	var lantern := model.get_node_or_null(^"Lantern") as Node3D
	var marker := model.find_child("light_lantern", true, false) as Node3D
	if lantern != null and marker != null:
		lantern.reparent(marker, false)
		lantern.transform = Transform3D.IDENTITY


## `action` = the running timed action (null when idle), `carrying` = a corpse in the hands.
func update(delta: float, action: Player.TimedAction, carrying: bool) -> void:
	var velocity := _player.velocity
	var moving := Vector2(velocity.x, velocity.z).length() > Player.MOVING_SPEED
	if anim == null:
		_waddle(delta, moving and action == null)
		return
	var wanted := _wanted_animation(moving, action, carrying)
	if wanted != &"" and (anim.current_animation != wanted or not anim.is_playing()):
		anim.play(wanted, _player.anim_blend)


func _wanted_animation(moving: bool, action: Player.TimedAction, carrying: bool) -> StringName:
	if action != null and anim.has_animation(action.animation):
		return action.animation
	var wanted := &"idle"
	if carrying:
		wanted = &"carry_walk" if moving else &"carry_idle"
	elif moving:
		wanted = &"walk"
	return wanted if anim.has_animation(wanted) else &""


func _waddle(delta: float, moving: bool) -> void:
	if moving:
		_walk_time += delta * _player.waddle_speed
	else:
		_walk_time = lerpf(_walk_time, roundf(_walk_time / PI) * PI, clampf(_player.waddle_settle * delta, 0.0, 1.0))
	_player.model.rotation.z = sin(_walk_time) * deg_to_rad(_player.waddle_deg)
	_player.model.position.y = absf(sin(_walk_time)) * _player.waddle_bob
