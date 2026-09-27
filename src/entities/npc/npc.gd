class_name Npc
extends Node3D
## Schedule-driven NPC (groups npc, saveable). Every frame it places itself from
## ScheduleResolver.entry_at() + progress() along the entry's waypoint polyline (constant speed
## by arc length) at TimeManager.get_minute_f() – nothing but the clock is needed, so the save
## is empty. Walking: walk / push_cart with AnimationPlayer.speed_scale = ground speed / the
## speed the cycle was made for; afterwards entry.animation. Hidden entries hide the NPC and
## switch its Interactable and collision off. The handcart (Cart) shows while with_cart;
## Cargo (a corpse on the cart) until the day's delivery – or all day when it was skipped.

const GROUP := &"npc"
const PROMPT_TALK := "[E] Mit %s reden"
const ANIM_WALK := &"walk"
const ANIM_PUSH := &"push_cart"
const ANIM_IDLE := &"idle"
const FLAG_SLICE_COMPLETE := &"slice_complete"
const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const CART_SLOT := "slot_corpse"
## Below this (m) a path segment has no direction.
const EPSILON := 0.0001

@export var save_id: String = ""
@export var save_order: int = 20
@export var npc_id: StringName
@export var model: PackedScene
@export_group("Animation")
## Ground speed (m/s) at which the walk / push_cart cycles do not slide (rig notes, M6a).
@export var walk_anim_speed: float = 1.65
@export var push_anim_speed: float = 1.14
@export var anim_blend: float = 0.2
## Turning speed (1/s) towards the walking direction or a nearby player.
@export var turn_speed: float = 8.0
## While standing at a dialogue spot, the NPC turns to a player closer than this (m).
@export var face_player_range: float = 3.5

## Resolved on demand: data/npc/<npc_id> schedule, the nearest ancestor with get_waypoint().
var schedule: NpcSchedule
var world: Node
## Current schedule phase and its travel progress (0..1).
var entry: ScheduleEntry
var progress: float = 1.0

@onready var body: AnimatableBody3D = $Body
@onready var body_shape: CollisionShape3D = $Body/Shape
@onready var cart_shape: CollisionShape3D = $Body/CartShape
@onready var interactable: Interactable = $Interactable
@onready var cart: Node3D = $Cart
@onready var cargo: Node3D = $Cart/Cargo

var _anim: AnimationPlayer
var _tables: CorpseTables
var _present: bool = true
var _talkable: bool = true
var _with_cart: bool = true
## entry instance id -> {points: PackedVector3Array, lengths: PackedFloat32Array, total: float}
var _paths: Dictionary = {}
var _heading: float = 0.0
## Extra yaw of the figure (Model) towards a nearby player; the cart keeps its place.
var _look: float = 0.0
var _model: Node3D


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	if model != null and get_node_or_null(^"Model") == null:
		var inst := model.instantiate()
		inst.name = "Model"
		add_child(inst)
	_model = get_node_or_null(^"Model") as Node3D
	var found: Array[Node] = []
	if _model != null:
		found = _model.find_children("*", "AnimationPlayer", true, false)
	_anim = found[0] as AnimationPlayer if not found.is_empty() else null
	# The cargo lies on the cart's slot_corpse marker (+X = the corpse's long axis).
	var slot := cart.find_child(CART_SLOT, true, false) as Node3D
	if slot != null and cargo.get_parent() != slot:
		cargo.reparent(slot, false)
		cargo.transform = Transform3D.IDENTITY
	_tables = Database.corpse_tables() as CorpseTables
	_heading = rotation.y
	refresh()


func _process(delta: float) -> void:
	_update(delta)


## Places the NPC for the current clock immediately (no smoothing).
func refresh() -> void:
	_update(-1.0)


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and _talkable


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT_TALK % first_name() if _talkable else ""


## Talking is allowed while carrying a corpse (§3.4).
func interact(player: Player) -> void:
	if can_interact(player):
		EventBus.dialogue_requested.emit(entry.dialogue_id, self)


func first_name() -> String:
	var full := _schedule().display_name if _schedule() != null else String(npc_id)
	return full.get_slice(" ", 0)


func is_present() -> bool:
	return _present


func is_walking() -> bool:
	return entry != null and entry.travel_minutes > 0 and progress < 1.0


## Metres per real second along the current path (0 while standing or the clock is stopped).
func ground_speed() -> float:
	if not is_walking() or not TimeManager.running or TimeManager.paused:
		return 0.0
	var path := _path(entry)
	return float(path.total) / (entry.travel_minutes * maxf(TimeManager.config.seconds_per_game_minute, EPSILON))


## Everything follows from the clock.
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	refresh()


func _update(delta: float) -> void:
	var sched := _schedule()
	if sched == null or sched.entries.is_empty():
		return
	var minute_f := TimeManager.get_minute_f()
	entry = ScheduleResolver.entry_at(sched, int(minute_f))
	if entry == null:
		return
	progress = ScheduleResolver.progress(entry, minute_f)
	var path := _path(entry)
	var sample := _sample(path, progress)
	global_position = sample[0]
	var dir: Vector3 = sample[1]
	_set_state(entry.visible, entry.visible and entry.dialogue_id != &"", entry.visible and entry.with_cart)
	cargo.visible = _with_cart and _has_cargo()
	# The root (and with it the cart) turns with the path; only the figure turns to a player.
	var heading := _heading
	if is_walking() and dir.length_squared() > EPSILON:
		heading = atan2(dir.x, dir.z)
	elif not is_walking():
		heading = _waypoint_yaw(heading)
	var look := _look_yaw(heading)
	if delta < 0.0:
		_heading = heading
		_look = look
	else:
		var k := clampf(turn_speed * delta, 0.0, 1.0)
		_heading = lerp_angle(rotation.y, heading, k)
		_look = lerp_angle(_look, look, k)
	rotation = Vector3(0.0, _heading, 0.0)
	if _model != null:
		_model.rotation = Vector3(0.0, _look, 0.0)
	_update_animation()


## Figure yaw relative to the root: towards a player closer than face_player_range while
## standing at a dialogue spot, else 0.
func _look_yaw(heading: float) -> float:
	if is_walking() or not _talkable:
		return 0.0
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return 0.0
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length_squared() <= EPSILON or to.length() >= face_player_range:
		return 0.0
	return wrapf(atan2(to.x, to.z) - heading, -PI, PI)


## Standing: the waypoint's facing (layout waypoint_facing), else keep the arrival heading.
func _waypoint_yaw(current: float) -> float:
	var w := _world()
	if w != null and w.has_method(&"get_waypoint_facing") and not entry.path.is_empty():
		var yaw := float(w.call(&"get_waypoint_facing", StringName(entry.path[entry.path.size() - 1])))
		if not is_nan(yaw):
			return yaw
	return current


func _set_state(present: bool, talkable: bool, with_cart: bool) -> void:
	if present != _present:
		_present = present
		visible = present
		body_shape.set_deferred(&"disabled", not present)
	if talkable != _talkable:
		_talkable = talkable
		interactable.enabled = talkable
		interactable.set_deferred(&"monitorable", talkable)
	if with_cart != _with_cart:
		_with_cart = with_cart
		cart.visible = with_cart
		cart_shape.set_deferred(&"disabled", not with_cart)


func _update_animation() -> void:
	if _anim == null:
		return
	var wanted := entry.animation
	var designed := 0.0
	if is_walking():
		wanted = ANIM_PUSH if entry.with_cart else ANIM_WALK
		designed = push_anim_speed if entry.with_cart else walk_anim_speed
	if not _anim.has_animation(wanted):
		wanted = ANIM_IDLE
	if not _anim.has_animation(wanted):
		return
	if _anim.current_animation != wanted or not _anim.is_playing():
		_anim.play(wanted, anim_blend)
	_anim.speed_scale = ground_speed() / designed if designed > 0.0 else 1.0


## Corpse on the cart: on the way in before the delivery minute, or all day after a skipped one.
func _has_cargo() -> bool:
	if GameState.has_flag(FLAG_SLICE_COMPLETE) or _tables == null:
		return false
	if TimeManager.minute_of_day < _tables.delivery_minute:
		return true
	return GameState.get_flag(FLAG_DELIVERY_SKIPPED, 0) == TimeManager.day


# --- path -----------------------------------------------------------------------------------

func _path(e: ScheduleEntry) -> Dictionary:
	var key := e.get_instance_id()
	if _paths.has(key):
		return _paths[key]
	var points := PackedVector3Array()
	for id: String in e.path:
		points.append(_waypoint(StringName(id)))
	if points.is_empty():
		points.append(global_position)
	var lengths := PackedFloat32Array([0.0])
	for k: int in range(1, points.size()):
		lengths.append(lengths[k - 1] + _flat(points[k] - points[k - 1]).length())
	var path := {"points": points, "lengths": lengths, "total": lengths[lengths.size() - 1]}
	_paths[key] = path
	return path


## [position, direction] at `t` (0..1) of the path's arc length.
func _sample(path: Dictionary, t: float) -> Array:
	var points: PackedVector3Array = path.points
	var lengths: PackedFloat32Array = path.lengths
	var total: float = path.total
	if points.size() == 1 or total <= EPSILON:
		return [points[points.size() - 1], Vector3.ZERO]
	var s := clampf(t, 0.0, 1.0) * total
	for k: int in range(1, points.size()):
		if s <= lengths[k] or k == points.size() - 1:
			var seg := lengths[k] - lengths[k - 1]
			var u := clampf((s - lengths[k - 1]) / seg, 0.0, 1.0) if seg > EPSILON else 1.0
			var pos := points[k - 1].lerp(points[k], u)
			return [_on_ground(pos), _flat(points[k] - points[k - 1]).normalized()]
	return [points[points.size() - 1], Vector3.ZERO]


func _on_ground(pos: Vector3) -> Vector3:
	var w := _world()
	if w != null and w.has_method(&"ground_height"):
		pos.y = float(w.call(&"ground_height", Vector2(pos.x, pos.z)))
	return pos


func _waypoint(id: StringName) -> Vector3:
	var w := _world()
	if w == null:
		push_warning("[Npc] %s: no world with waypoints" % name)
		return global_position
	return w.call(&"get_waypoint", id)


func _world() -> Node:
	if world == null:
		var node := get_parent()
		while node != null and not node.has_method(&"get_waypoint"):
			node = node.get_parent()
		world = node
	return world


func _schedule() -> NpcSchedule:
	if schedule == null and npc_id != &"":
		schedule = Database.schedule(npc_id) as NpcSchedule
	return schedule


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
