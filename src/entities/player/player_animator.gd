class_name PlayerAnimator
extends RefCounted
## Animation driver of the Player: plays the rig clips (idle / walk / carry_idle / carry_walk /
## the running action's clip) on the Model's AnimationPlayer, or waddles a model without
## AnimationPlayer procedurally (as in the prototype). Values: the Player's anim/waddle exports.
## G7 Runde 2 (tool_anim_config.tres): an action clip played with a tool (the shovel for dig /
## bury / lift / clearing / clay) first draws the tool from the back (DRAW), loops with it in the
## hands (HOLD; the blade's bite sounds the work cue, the throw drops a few earth clods) and puts
## it back when the action ends or is cancelled (STOW, the walking variant when moving off).
## reset_tool() puts it back at once (loading, changing rooms).

enum ToolPhase { BACK, DRAW, HOLD, STOW }

## The rig's AnimationPlayer anywhere under the Model (null = procedural waddle).
var anim: AnimationPlayer
var tools: ToolAnimConfig
var phase: ToolPhase = ToolPhase.BACK
var _player: Player
var _walk_time: float = 0.0
## Tool being drawn / held / stowed and the action clip it is held for.
var _tool: StringName = &""
var _hold_clip: StringName = &""
var _stow_walk: bool = false
## Position of the held clip at the last update (beats and throws fire when it passes them).
var _last_pos: float = -1.0
var _clods: CPUParticles3D
var _blade: Node3D


func _init(player: Player) -> void:
	_player = player
	var found := player.model.find_children("*", "AnimationPlayer", true, false)
	anim = found[0] as AnimationPlayer if not found.is_empty() else null
	tools = Database.config(&"tool_anim_config") as ToolAnimConfig
	if tools == null:
		tools = ToolAnimConfig.new()
	_blade = player.model.find_child(String(tools.blade_marker), true, false) as Node3D


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
	var blend := _player.anim_blend
	var wanted := _tool_animation(moving, action)
	if wanted != &"":
		blend = tools.hold_blend if phase == ToolPhase.HOLD else (tools.stow_blend if phase == ToolPhase.STOW else blend)
	else:
		wanted = _wanted_animation(moving, action, carrying)
	if wanted != &"" and (anim.current_animation != wanted or not anim.is_playing()):
		anim.play(wanted, blend)
	if phase == ToolPhase.HOLD:
		_hold_events()


## The tool the gravekeeper has out of its place on the back (drawing, holding or stowing); &"" =
## everything on the back.
func held_tool() -> StringName:
	return &"" if phase == ToolPhase.BACK else _tool


## True if the running action clip `clip` sounds its work cue in step with the tool (work_beat).
func syncs_work_cue(clip: StringName) -> bool:
	return anim != null and tools.bite_at.has(clip) and _needs_tool(clip) != &""


## Puts the tool back on the back at once and shows the rest clip (loading, changing rooms).
func reset_tool() -> void:
	phase = ToolPhase.BACK
	_tool = &""
	_hold_clip = &""
	_last_pos = -1.0
	if anim == null:
		return
	var rest := &"carry_idle" if is_instance_valid(_player.carried) and anim.has_animation(&"carry_idle") else &"idle"
	if anim.has_animation(rest):
		anim.play(rest, 0.0)
		anim.seek(0.0, true)


# --- tool phases ------------------------------------------------------------------------

## Tool kind the clip is held with (all its clips exist), else &"".
func _needs_tool(clip: StringName) -> StringName:
	var kind: StringName = tools.held_tools.get(clip, &"")
	if kind == &"" or not anim.has_animation(clip):
		return &""
	for clips: Dictionary in [tools.draw_clips, tools.stow_clips]:
		if not anim.has_animation(clips.get(kind, &"")):
			return &""
	return kind


## The clip of the current tool phase (advancing the phase), &"" when the tool is on the back.
func _tool_animation(moving: bool, action: Player.TimedAction) -> StringName:
	var need := _needs_tool(action.animation) if action != null else &""
	match phase:
		ToolPhase.BACK:
			if need != &"":
				return _start_draw(need, action.animation)
		ToolPhase.DRAW:
			if need != _tool:
				return _start_stow(moving) if need == &"" else _start_draw(need, action.animation)
			_hold_clip = action.animation
			if _finished(tools.draw_clips[_tool]):
				phase = ToolPhase.HOLD
				_last_pos = -1.0
				return _hold_clip
			return tools.draw_clips[_tool]
		ToolPhase.HOLD:
			if need != _tool:
				return _start_stow(moving)
			if action.animation != _hold_clip:
				_hold_clip = action.animation
				_last_pos = -1.0
			return _hold_clip
		ToolPhase.STOW:
			if need != &"":
				return _start_draw(need, action.animation)
			if _finished(_stow_clip()):
				phase = ToolPhase.BACK
				_tool = &""
				return &""
			if moving != _stow_walk and anim.has_animation(tools.stow_walk_clips.get(_tool, &"")):
				_switch_stow(moving)
			return _stow_clip()
	return &""


func _start_draw(kind: StringName, clip: StringName) -> StringName:
	phase = ToolPhase.DRAW
	_tool = kind
	_hold_clip = clip
	return tools.draw_clips[kind]


func _start_stow(moving: bool) -> StringName:
	phase = ToolPhase.STOW
	_stow_walk = moving and anim.has_animation(tools.stow_walk_clips.get(_tool, &""))
	_last_pos = -1.0
	return _stow_clip()


func _stow_clip() -> StringName:
	return tools.stow_walk_clips[_tool] if _stow_walk else tools.stow_clips[_tool]


## Standing still ↔ walking off while stowing: the other variant at the same progress.
func _switch_stow(moving: bool) -> void:
	var ratio := 0.0
	if anim.current_animation_length > 0.0:
		ratio = anim.current_animation_position / anim.current_animation_length
	_stow_walk = moving
	var clip := _stow_clip()
	anim.play(clip, tools.hold_blend)
	anim.seek(anim.current_animation_length * ratio, false)


## True once the one-shot `clip` has played to its end (or is not the clip shown any more).
func _finished(clip: StringName) -> bool:
	if anim.assigned_animation != clip:
		return false
	return not anim.is_playing() or anim.current_animation_position >= anim.current_animation_length - 0.0001


## HOLD: the blade's bite → AudioEvents.work_beat(); the throw → a few earth clods.
func _hold_events() -> void:
	if anim.current_animation != _hold_clip or anim.current_animation_length <= 0.0:
		return
	var pos := anim.current_animation_position / anim.current_animation_length
	var last := _last_pos
	_last_pos = pos
	if last < 0.0:
		return
	if _passed(last, pos, float(tools.bite_at.get(_hold_clip, -1.0))):
		var audio := _player.get_node_or_null(^"/root/Audio")
		if audio != null and audio.get(&"events") != null:
			audio.events.call(&"work_beat")
	if _passed(last, pos, float(tools.toss_at.get(_hold_clip, -1.0))):
		throw_clods()


## True if the cycle position went from `a` to `b` (wrapping at 1) across `mark`.
static func _passed(a: float, b: float, mark: float) -> bool:
	if mark < 0.0:
		return false
	if b >= a:
		return a < mark and mark <= b
	return mark > a or mark <= b


## A few painted earth crumbs leave the blade (one-shot burst, world space).
func throw_clods() -> void:
	if not _player.is_inside_tree() or tools.clod_amount <= 0:
		return
	if _clods == null:
		_clods = _make_clods()
		_player.add_child(_clods)
	var from := _blade.global_position if _blade != null else _player.global_position + Vector3.UP
	_clods.global_position = from
	_clods.direction = (_player.global_basis * tools.clod_direction).normalized()
	_clods.restart()


func _make_clods() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "EarthClods"
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	p.amount = tools.clod_amount
	p.lifetime = tools.clod_lifetime
	p.explosiveness = 0.85
	p.spread = tools.clod_spread_deg
	p.initial_velocity_min = tools.clod_speed * 0.6
	p.initial_velocity_max = tools.clod_speed
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * tools.clod_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tools.clod_color
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh
	return p


# --- plain clips ------------------------------------------------------------------------

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
