class_name Player
extends CharacterBody3D
## The gravekeeper (groups player, saveable; save_id "player", save_order 100).
## Moves on world axes like the prototype (camera yaw 0: move_up = −Z) and yaws the whole
## body toward the movement – the capsule is round, and Model, CarrySocket and the
## InteractionDetector turn with it. States: FREE, CARRYING (carry_speed) and LOCKED while
## UIState has a modal open. [E] uses the focused Interactable, [Q] puts a carried corpse
## down through the CorpseManager. Timed actions pause the clock (&"action") and
## fast-forward it while the progress bar fills. Values: data/config/player_config.tres,
## data/config/action_config.tres. Helpers: player_action_runner.gd (timed actions),
## player_carry.gd (carried Interactables, drop probe), player_animator.gd (rig / waddle).

enum State { FREE, CARRYING, LOCKED }

const ACTION_PAUSE := &"action"
const TEXT_CANNOT_DROP := "Hier nicht ablegen."
## Prompt for targets that need free hands while a corpse is carried (§3.4) – shared text.
const TEXT_HANDS_FULL := "Hände frei nötig – [Q] ablegen"
## Collision layer 1 (world): ground rays and the drop box check.
const WORLD_MASK := 1
## Squared input length below which the stick/keys count as released.
const INPUT_DEADZONE_SQ := 0.0001
## Horizontal speed (m/s) above which the walk animations play.
const MOVING_SPEED := 0.1
## A valid drop transform must never equal Transform3D() (= invalid): lifted by this (m).
const IDENTITY_NUDGE := 0.001
## Global shader uniform (project.godot) of the foliage occlusion cutout: leaves between the
## camera and this point fade out (painted_foliage.gdshader). Far below the world = no cutout.
const OCCLUSION_TARGET := &"occlusion_target"
const OCCLUSION_OFF := Vector3(0.0, -1000.0, 0.0)
## Absorbs float drift of the summed frame deltas when converting progress to whole minutes.
const MINUTE_EPSILON := 0.000001

@export var save_id: String = "player"
@export var save_order: int = 100
## Footprint of a lying corpse (x = along its length); a drop needs it free of world bodies.
@export var drop_box_size: Vector3 = Vector3(0.9, 0.4, 0.5)
## Gap between ground and drop box, so the floor itself never counts as an obstacle.
@export var drop_box_clearance: float = 0.05
## The ground of a drop spot must lie at most this much above / below the feet. The ray
## starts inside anything taller, looks through it, and the box check then rejects it.
@export var drop_step_up: float = 0.25
@export var drop_step_down: float = 0.5
## Cross-fade between rig animations (s).
@export var anim_blend: float = 0.15
## Procedural waddle for a model without AnimationPlayer (as in the prototype).
@export var waddle_deg: float = 4.0
@export var waddle_speed: float = 9.0
@export var waddle_settle: float = 8.0
@export var waddle_bob: float = 0.04
## Chest height (m above the feet) the foliage cutout keeps visible: tree crowns between the
## camera and this point fade out, nothing below it is cut (UI-01).
@export var occlusion_height: float = 1.1

var config: PlayerConfig
var actions: ActionConfig
var state: State = State.FREE
@onready var inventory: Inventory = $Inventory
## Corpse node currently in the CarrySocket (null when the hands are free).
var carried: Node3D
var carried_id: String = ""
## Tests: timed actions finish inside start_timed_action (game time still advances).
var instant_actions: bool = false
## True while the gravekeeper is inside the hut (docs §11) – set by the portal, saved.
var in_interior: bool = false
## Build mode (set_build_mode, Phase 3): no focus, no [E]/[Q]. Not saved.
var build_mode: bool = false

@onready var model: Node3D = $Model
@onready var carry_socket: Node3D = $CarrySocket
@onready var detector: InteractionDetector = $InteractionDetector


## One running timed action.
class TimedAction:
	var label: String
	var minutes: int
	var duration: float
	var on_done: Callable
	var cancellable: bool
	var animation: StringName
	var elapsed: float = 0.0
	var advanced: int = 0


## Timed-action runner (player_action_runner.gd); _action forwards to its running action.
var _runner := PlayerActionRunner.new()
var _action: TimedAction:
	get:
		return _runner.current
## Animation driver (player_animator.gd, created in _ready); _anim = the rig's AnimationPlayer.
var _animator: PlayerAnimator
var _anim: AnimationPlayer:
	get:
		return _animator.anim if _animator != null else null
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _modal: bool = false
var _has_carried: bool = false
## Switches the carried node's Interactables off and back on (player_carry.gd).
var _carry := PlayerCarry.new()
## Last reported interaction focus (EventBus.interaction_focus_changed).
var _shown_id: int = 0
var _shown_prompt: String = ""
var _shown_enabled: bool = false


func _ready() -> void:
	if config == null:
		config = Database.config(&"player_config") as PlayerConfig
	if config == null:
		config = PlayerConfig.new()
	if actions == null:
		actions = Database.config(&"action_config") as ActionConfig
	if actions == null:
		actions = ActionConfig.new()
	inventory.slot_count = config.inventory_slots
	_animator = PlayerAnimator.new(self)
	_animator.attach_lantern()
	_modal = UIState.is_modal()
	EventBus.ui_modal_changed.connect(_on_ui_modal_changed)
	EventBus.new_game_started.connect(apply_start_inventory)
	_refresh_state()


func _exit_tree() -> void:
	# A running action must not leave the clock paused behind.
	cancel_timed_action()
	if _shown_prompt != "":
		_report_focus(0, "", false)
	RenderingServer.global_shader_parameter_set(OCCLUSION_TARGET, OCCLUSION_OFF)


## Every rendered frame: the foliage cutout follows the chest (see occlusion_height).
func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(OCCLUSION_TARGET, occlusion_point())


## World point the foliage occlusion cutout keeps visible (the chest).
func occlusion_point() -> Vector3:
	return global_position + Vector3(0.0, occlusion_height, 0.0)


func _physics_process(delta: float) -> void:
	_check_carried()
	var input := _move_input()
	if is_busy() and _action.cancellable and input.length_squared() > INPUT_DEADZONE_SQ:
		cancel_timed_action()
	var dir := Vector3.ZERO if is_busy() else Vector3(input.x, 0.0, input.y)
	var speed := config.carry_speed if state == State.CARRYING else config.move_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	if dir.length_squared() > INPUT_DEADZONE_SQ:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(config.turn_speed * delta, 0.0, 1.0))
	if is_busy():
		_tick_action(delta)
	_update_animation(delta)
	_update_focus_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		if _try_interact():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"drop"):
		if _try_drop():
			get_viewport().set_input_as_handled()


## True while a timed action runs.
func is_busy() -> bool:
	return _action != null


## Mechanical only: moves `node` into the CarrySocket and switches its Interactables off.
## The CorpseManager keeps the record; refuses (warning) while another node is carried.
func attach_carried(node: Node3D, id: String) -> void:
	if node == null:
		push_warning("[Player] attach_carried(null, '%s') ignored" % id)
		return
	if _is_carrying() and carried != node:
		push_warning("[Player] already carrying '%s' – '%s' not attached" % [carried_id, id])
		return
	var parent := node.get_parent()
	if parent == null:
		carry_socket.add_child(node)
	elif parent != carry_socket:
		node.reparent(carry_socket, false)
	node.transform = Transform3D.IDENTITY
	carried = node
	carried_id = id
	_has_carried = true
	_carry.disable_interactables(node)
	_refresh_state()


## Takes the carried node out of the CarrySocket (the caller re-parents it) and switches its
## Interactables back on. Returns the node, or null if nothing was carried.
func detach_carried() -> Node3D:
	var node: Node3D = carried if _is_carrying() else null
	if node == null:
		push_warning("[Player] detach_carried: nothing carried")
	elif node.get_parent() == carry_socket:
		carry_socket.remove_child(node)
	_forget_carried()
	return node


## Runs a timed action: the clock pauses (&"action") and advances in whole minutes as the
## bar fills (actions.real_seconds_for(game_minutes) real seconds), the rest at the end,
## then on_done is called. Refused (false) while another action runs. Allowed while LOCKED
## (panel buttons pass cancellable = false). Movement input cancels a cancellable action.
func start_timed_action(label: String, game_minutes: int, on_done: Callable, cancellable: bool = true, animation: StringName = &"interact") -> bool:
	if is_busy():
		return false
	var action := TimedAction.new()
	action.label = label
	action.minutes = maxi(game_minutes, 0)
	action.on_done = on_done
	action.cancellable = cancellable
	action.animation = animation
	action.duration = 0.0 if instant_actions else maxf(actions.real_seconds_for(action.minutes), 0.0)
	_runner.start(action)
	if instant_actions:
		_tick_action(0.0)
	else:
		_update_animation(0.0)
	return true


## Stops the running action: minutes already advanced stay, on_done is NOT called.
func cancel_timed_action() -> void:
	_runner.cancel()


## Replaces the inventory with config.start_items (connected to EventBus.new_game_started).
func apply_start_inventory() -> void:
	inventory.clear()
	for id: StringName in config.start_items:
		var rest := inventory.add_item(id, config.start_items[id])
		if rest > 0:
			push_warning("[Player] start item '%s': %d did not fit" % [id, rest])


## Where a carried corpse would be put down: config.drop_distance in front of the player,
## else at the feet – on the ground below (ray, layer 1) with a corpse-sized box free of
## world bodies. The corpse lies across the facing direction. Transform3D() = no valid spot.
func drop_position() -> Transform3D:
	if not is_inside_tree():
		return Transform3D()
	return PlayerCarry.drop_position(self)


## Phase 3 §3.4 build-mode hook (BuildMode): while active the interaction focus is empty and
## the gravekeeper's [E]/[Q] do nothing ([E] is also build_place); movement stays.
func set_build_mode(active: bool) -> void:
	build_mode = active
	_update_focus_prompt()


## Inside / outside the hut; always announces EventBus.interior_changed so camera, sun and
## environment follow (also after a load that did not change the value).
func set_in_interior(value: bool) -> void:
	in_interior = value
	EventBus.interior_changed.emit(value)


## {position: Vector3, rot_y: float, in_interior: bool, inventory: Inventory.save_state()}.
## The carried corpse is not saved here – CorpseManager.post_load() re-attaches it.
func save_state() -> Dictionary:
	return {"position": position, "rot_y": rotation.y, "in_interior": in_interior, "inventory": inventory.save_state()}


## Replaces the state; stops any timed action and forgets the carried node (its owner, the
## CorpseManager, rebuilds corpse nodes in its own load_state and re-attaches in post_load).
func load_state(data: Dictionary) -> void:
	cancel_timed_action()
	if _has_carried:
		_forget_carried()
	var saved_position: Variant = data.get("position")
	if saved_position is Vector3:
		position = saved_position
	var saved_rot: Variant = data.get("rot_y")
	if saved_rot is float or saved_rot is int:
		rotation = Vector3(0.0, float(saved_rot), 0.0)
	velocity = Vector3.ZERO
	var saved_inside: Variant = data.get("in_interior", false)
	set_in_interior(saved_inside is bool and bool(saved_inside))
	var saved_inventory: Variant = data.get("inventory")
	inventory.load_state(saved_inventory if saved_inventory is Dictionary else {})


# --- input & interaction ------------------------------------------------------------------

func _move_input() -> Vector2:
	if state == State.LOCKED:
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## E: the focused target interacts, or its prompt (the reason) is shown as a warning.
func _try_interact() -> bool:
	var target := _usable_focus()
	if target == null:
		return false
	var prompt := target.prompt_for(self)
	if prompt == "":
		return false
	if target.can_interact_with(self):
		target.interact_with(self)
	else:
		EventBus.notification_requested.emit(prompt, &"warning")
	return true


## Q: put the carried corpse on the ground via the CorpseManager (group corpse_manager).
func _try_drop() -> bool:
	if build_mode or state == State.LOCKED or is_busy() or not _is_carrying():
		return false
	var xform := drop_position()
	if xform == Transform3D():
		EventBus.notification_requested.emit(TEXT_CANNOT_DROP, &"warning")
		return true
	var manager := get_tree().get_first_node_in_group(&"corpse_manager")
	if manager == null or not manager.has_method(&"put_down"):
		push_warning("[Player] no corpse_manager – cannot put '%s' down" % carried_id)
		return true
	if not bool(manager.call(&"put_down", carried_id, &"ground", xform)):
		push_warning("[Player] corpse_manager refused to put '%s' down" % carried_id)
	return true


## The detector's focus if the player may use it now (not LOCKED, not busy, enabled).
func _usable_focus() -> Interactable:
	if build_mode or state == State.LOCKED or is_busy() or detector == null:
		return null
	var focus := detector.focused
	if not is_instance_valid(focus) or not focus.enabled:
		return null
	return focus


## Polls the focused target's prompt/can_interact and reports changes on the EventBus.
func _update_focus_prompt() -> void:
	var target := _usable_focus()
	var prompt := target.prompt_for(self) if target != null else ""
	var usable := prompt != "" and target.can_interact_with(self)
	var target_id := target.get_instance_id() if prompt != "" else 0
	if target_id != _shown_id or prompt != _shown_prompt or usable != _shown_enabled:
		_report_focus(target_id, prompt, usable)


func _report_focus(target_id: int, prompt: String, usable: bool) -> void:
	_shown_id = target_id
	_shown_prompt = prompt
	_shown_enabled = usable
	EventBus.interaction_focus_changed.emit(prompt, usable)


# --- state & carrying ---------------------------------------------------------------------

func _on_ui_modal_changed(open: bool) -> void:
	_modal = open
	_refresh_state()


func _refresh_state() -> void:
	if _modal:
		state = State.LOCKED
	else:
		state = State.CARRYING if _is_carrying() else State.FREE


func _is_carrying() -> bool:
	return _has_carried and is_instance_valid(carried) and not carried.is_queued_for_deletion()


## A carried node that was freed or moved out of the socket elsewhere is no longer carried.
func _check_carried() -> void:
	if _has_carried and (not _is_carrying() or carried.get_parent() != carry_socket):
		_forget_carried()


func _forget_carried() -> void:
	_carry.restore_interactables()
	carried = null
	carried_id = ""
	_has_carried = false
	_refresh_state()


# --- timed actions & presentation ---------------------------------------------------------

func _tick_action(delta: float) -> void:
	_runner.tick(delta)


func _update_animation(delta: float) -> void:
	_animator.update(delta, _action, _is_carrying())


## STUB (P3) Phase 5 §3.4: highest tier of `kind` on the tool belt (ToolRules.tier; 0 until P3).
func tool_tier(kind: StringName) -> int:
	return ToolRules.tier(inventory, kind)
