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
## G7 Runde 2 (Werkzeuge): the same for the belt tools – axe (chop), pickaxe (pick), hammer
## (hammer, chisel with the chisel in the left fist) and saw (saw): drawn from the tool bag at the
## right hip, visible only while out (ToolProps), chips at the bite, the cue in step (beat_cue).
## G7 Runde 2 (Bestatten): the burial action clip (tool_anim_config burial_action_clip) is played by
## PlayerBurial's sequence – step to the pit, lay the dead into it, silence – and then fills the grave
## with the shovel (the fill clip's tool phases; every throw raises the earth, dirt_pour in step).

enum ToolPhase { BACK, DRAW, HOLD, STOW }

## The rig's AnimationPlayer anywhere under the Model (null = procedural waddle).
var anim: AnimationPlayer
var tools: ToolAnimConfig
var props: ToolProps
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
## G7 Runde 2 (Bestatten): the laying-into-the-grave sequence of a burial (player_burial.gd).
var burial: PlayerBurial
## Chip bursts per action clip (wood chips, stone splinters) and the last shown tool state.
var _chips: Dictionary[StringName, CPUParticles3D] = {}
var _shown: Array = []
## Phase 8 (docs/PHASE8_DESIGN.md §2.3, W1-Anschluss 5): the watering can has no mesh in the model (tri budget) –
## ph_tool_watering_can hangs at the marker can_grip while the clip `water` plays (created on first use).
const WATER_CLIP := &"water"
const CAN_MARKER := "can_grip"
const CAN_NAME := "WateringCan"
const CAN_PATH := "res://assets/models/props/ph_tool_watering_can.glb"
var _can: Node3D


func _init(player: Player) -> void:
	_player = player
	var found := player.model.find_children("*", "AnimationPlayer", true, false)
	anim = found[0] as AnimationPlayer if not found.is_empty() else null
	tools = Database.config(&"tool_anim_config") as ToolAnimConfig
	if tools == null:
		tools = ToolAnimConfig.new()
	_blade = player.model.find_child(String(tools.blade_marker), true, false) as Node3D
	burial = PlayerBurial.new(player, tools)
	props = ToolProps.new(player.model, tools)


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
	burial.update(delta, action)
	if anim == null:
		_waddle(delta, moving and action == null)
		return
	var clip := clip_of(action)
	var blend := _player.anim_blend
	var wanted := _tool_animation(moving, clip)
	if wanted != &"":
		if phase == ToolPhase.HOLD:
			blend = tools.hold_blends.get(_hold_clip, tools.hold_blend)
		elif phase == ToolPhase.STOW:
			blend = tools.stow_blend
	else:
		wanted = _wanted_animation(moving, clip, carrying)
	if wanted != &"" and (anim.current_animation != wanted or not anim.is_playing()) and not _held_end(wanted):
		anim.play(wanted, blend)
	if phase == ToolPhase.HOLD:
		_hold_events(action)
	_update_props()
	_update_can(anim.current_animation == WATER_CLIP)


## The watering can at can_grip only while watering (W1-Anschluss 5).
func _update_can(on: bool) -> void:
	if _can == null:
		if not on:
			return
		var marker := _player.model.find_child(CAN_MARKER, true, false) as Node3D
		if marker == null or not ResourceLoader.exists(CAN_PATH):
			return
		_can = (load(CAN_PATH) as PackedScene).instantiate() as Node3D
		_can.name = CAN_NAME
		marker.add_child(_can)
	_can.visible = on


## True while the watering can shows (tests, screenshots).
func can_shown() -> bool:
	return _can != null and _can.visible


## The burial's one-shot clips (lowering, silence) hold their last frame instead of starting over.
func _held_end(clip: StringName) -> bool:
	return (clip == tools.burial_lower_clip or clip == tools.burial_mourn_clip) and anim.assigned_animation == clip


## The clip the running `action` shows now (&"" = none): its own, or for the burial clip the step of
## the burial sequence (PlayerBurial.clip).
func clip_of(action: Player.TimedAction) -> StringName:
	if action == null:
		return &""
	if action.animation == tools.burial_action_clip:
		return burial.clip(action)
	return action.animation


## Real seconds of the burial sequence (-1 = no rig: the usual bar, no presentation).
func burial_seconds() -> float:
	return tools.burial_seconds(anim)


## Starts the burial presentation at `plot` (Player.start_burial, before the action starts).
func begin_burial(plot: GravePlot) -> void:
	if anim != null and plot != null:
		burial.begin(plot)


## The tool the gravekeeper has out of its place on the back (drawing, holding or stowing); &"" =
## everything on the back.
func held_tool() -> StringName:
	return &"" if phase == ToolPhase.BACK else _tool


## True if the running action clip `clip` sounds its work cue in step with the tool (work_beat).
func syncs_work_cue(clip: StringName) -> bool:
	if anim != null and clip == tools.burial_action_clip:
		return _needs_tool(tools.burial_fill_clip) != &""
	return anim != null and tools.bite_at.has(clip) and _needs_tool(clip) != &""


## The work cue the tool clip `clip` sounds at its bite (&"" = the label's keyword cue).
func beat_cue(clip: StringName) -> StringName:
	return tools.beat_cues.get(clip, &"") if syncs_work_cue(clip) else &""


## Puts the tool back on the back at once and shows the rest clip (loading, changing rooms).
func reset_tool() -> void:
	phase = ToolPhase.BACK
	_tool = &""
	_hold_clip = &""
	_last_pos = -1.0
	_update_props()
	burial.reset()
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
	if kind == &"" or not anim.has_animation(clip) or not props.has(kind):
		return &""
	for clips: Dictionary in [tools.draw_clips, tools.stow_clips]:
		if not anim.has_animation(clips.get(kind, &"")):
			return &""
	return kind


## The clip of the current tool phase (advancing the phase), &"" when the tool is on the back.
func _tool_animation(moving: bool, clip: StringName) -> StringName:
	var need := _needs_tool(clip) if clip != &"" else &""
	match phase:
		ToolPhase.BACK:
			if need != &"":
				return _start_draw(need, clip)
		ToolPhase.DRAW:
			if need != _tool:
				return _start_stow(moving) if need == &"" else _start_draw(need, clip)
			_hold_clip = clip
			if _finished(tools.draw_clips[_tool]):
				phase = ToolPhase.HOLD
				_last_pos = -1.0
				return _hold_clip
			return tools.draw_clips[_tool]
		ToolPhase.HOLD:
			if need != _tool:
				return _start_stow(moving)
			if clip != _hold_clip:
				_hold_clip = clip
				_last_pos = -1.0
			return _hold_clip
		ToolPhase.STOW:
			if need != &"":
				return _start_draw(need, clip)
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


## HOLD: the blade's bite → AudioEvents.work_beat(); the throw → a few earth clods. Filling a grave
## (the burial action): the throw sounds the cue (dirt_pour), the clods go into the pit and the
## earth rises (PlayerBurial.on_throw).
func _hold_events(action: Player.TimedAction = null) -> void:
	if anim.current_animation != _hold_clip or anim.current_animation_length <= 0.0:
		return
	var pos := anim.current_animation_position / anim.current_animation_length
	var last := _last_pos
	_last_pos = pos
	if last < 0.0:
		return
	var filling := action != null and action.animation == tools.burial_action_clip
	var bite := float(tools.bite_at.get(_hold_clip, -1.0))
	var toss := float(tools.toss_at.get(_hold_clip, -1.0))
	if _passed(last, pos, toss if filling else bite):
		_work_beat()
	if _passed(last, pos, toss):
		throw_clods(tools.burial_clod_direction if filling else tools.clod_direction)
		if filling:
			burial.on_throw()
	if tools.chip_markers.has(_hold_clip) and _passed(last, pos, float(tools.bite_at.get(_hold_clip, -1.0))):
		throw_chips(_hold_clip)


## Which tool shows: the one being drawn once the fist is at the bag, the held one, the one being
## stowed until it is back in the bag; at rest only the shovel on the back (ToolProps).
func _update_props() -> void:
	var state: Array = [&"", false]
	if phase != ToolPhase.BACK and anim != null:
		var shown := true
		if phase == ToolPhase.DRAW:
			var draw: StringName = tools.draw_clips.get(_tool, &"")
			shown = _clip_pos(draw) >= float(tools.draw_show_at.get(draw, 0.0))
		elif phase == ToolPhase.STOW:
			var stow := _stow_clip()
			shown = _clip_pos(stow) < float(tools.stow_hide_at.get(stow, 2.0))
		state = [_tool, shown]
	if state == _shown:
		return
	_shown = state
	if state[0] == &"":
		props.rest()
	else:
		props.show(state[0], state[1])


## Fraction of the one-shot `clip` played (0 while it is not the assigned clip yet).
func _clip_pos(clip: StringName) -> float:
	if anim.assigned_animation != clip or anim.current_animation_length <= 0.0:
		return 0.0
	return anim.current_animation_position / anim.current_animation_length


## True if the cycle position went from `a` to `b` (wrapping at 1) across `mark`.
static func _passed(a: float, b: float, mark: float) -> bool:
	if mark < 0.0:
		return false
	if b >= a:
		return a < mark and mark <= b
	return mark > a or mark <= b


## A few chips leave the striking point of the tool clip `clip` (wood / stone; one-shot, world space).
func throw_chips(clip: StringName) -> void:
	if not _player.is_inside_tree() or tools.chip_amount <= 0:
		return
	var p: CPUParticles3D = _chips.get(clip)
	if p == null:
		p = _burst("Chips_" + String(clip), tools.chip_amount, tools.chip_lifetime, tools.chip_size, tools.chip_speed,
				tools.chip_spread_deg, tools.chip_colors.get(clip, Color.GRAY))
		_chips[clip] = p
		_player.add_child(p)
	var at := _player.model.find_child(String(tools.chip_markers[clip]), true, false) as Node3D
	p.global_position = at.global_position if at != null else _player.global_position + Vector3.UP * 0.6
	p.direction = (_player.global_basis * Vector3(0.0, 1.0, 0.6)).normalized()
	p.restart()


func _work_beat() -> void:
	var audio := _player.get_node_or_null(^"/root/Audio")
	if audio != null and audio.get(&"events") != null:
		audio.events.call(&"work_beat")


## A few painted earth crumbs leave the blade (one-shot burst, world space; `direction` player-local).
func throw_clods(direction: Vector3 = Vector3.ZERO) -> void:
	if not _player.is_inside_tree() or tools.clod_amount <= 0:
		return
	if _clods == null:
		_clods = _make_clods()
		_player.add_child(_clods)
	var from := _blade.global_position if _blade != null else _player.global_position + Vector3.UP
	_clods.global_position = from
	var dir := direction if direction != Vector3.ZERO else tools.clod_direction
	_clods.direction = (_player.global_basis * dir).normalized()
	_clods.restart()


func _make_clods() -> CPUParticles3D:
	return _burst("EarthClods", tools.clod_amount, tools.clod_lifetime, tools.clod_size, tools.clod_speed,
			tools.clod_spread_deg, tools.clod_color)


func _burst(node_name: String, amount: int, lifetime: float, size: float, speed: float, spread: float,
		color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.85
	p.spread = spread
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh
	return p


# --- plain clips ------------------------------------------------------------------------

func _wanted_animation(moving: bool, clip: StringName, carrying: bool) -> StringName:
	if clip != &"" and anim.has_animation(clip):
		return clip
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
