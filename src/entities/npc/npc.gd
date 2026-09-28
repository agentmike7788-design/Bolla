class_name Npc
extends Node3D
## Schedule-driven NPC (groups npc, saveable). Every frame it places itself from
## ScheduleResolver.entry_at() + progress() along the entry's waypoint polyline (constant speed
## by arc length) at TimeManager.get_minute_f() – nothing but the clock is needed, so the save
## is empty. Walking: walk / push_cart with AnimationPlayer.speed_scale = ground speed / the
## speed the cycle was made for; afterwards entry.animation. Hidden entries hide the NPC and
## switch its Interactable and collision off. The handcart (Cart) shows while with_cart;
## Cargo (a corpse on the cart) until the day's delivery – or all day when it was skipped.
## Standing heading: the waypoint's facing, else the direction of the walk that ended there –
## both follow from the clock, so a load shows him exactly as walking in did (SL-1).
## debug_teleport() (debug console) holds him at a spot until the next schedule phase.
## Path sampling and heading evaluation: npc_pose.gd.

const GROUP := &"npc"
const PROMPT_TALK := "[E] Mit %s reden"
const ANIM_WALK := &"walk"
const ANIM_PUSH := &"push_cart"
const ANIM_IDLE := &"idle"
const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const CART_SLOT := "slot_corpse"
## Below this (m) a path segment has no direction.
const EPSILON := 0.0001
## Lantern light (§8): warm, no shadow. QA art (W3, G4): 0.4 / 3 m read as a weak spark at the
## west wall at night – the lantern now lays a warm pool on the ground and lights her face like
## the gravekeeper's own lantern (energy 1.0, softer falloff); still one light, no shadow.
const LANTERN_NAME := "Lantern"
const LANTERN_COLOR := Color("E8A55A")
const LANTERN_ENERGY := 2.2
const LANTERN_RANGE := 4.5
const LANTERN_ATTENUATION := 1.8
const LANTERN_FALLBACK := Vector3(-0.25, 0.9, 0.2)

@export var save_id: String = ""
@export var save_order: int = 20
@export var npc_id: StringName
@export var model: PackedScene
## Phase 4 (docs/PHASE4_DESIGN.md §3.4): while this GameState flag is missing (or false) the
## NPC behaves like activity home – invisible, no prompt, no collision (Ilse: trader_known).
## &"" = always (Osric).
@export var requires_flag: StringName = &""
## Phase 4: a lantern (OmniLight3D without shadow, group warm_lights) at the model node with
## this name (Ilse: light_lantern); without such a node at LANTERN_FALLBACK. &"" = none.
@export var lantern_marker: StringName = &""
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
## Day whose corpse the cart cargo currently shows (-1 = the scene's default model).
var _cargo_day: int = -1
## Plain corpse looks, same order as Corpse.plain_variants (cargo = the corpse he will deliver).
const CARGO_LOOKS: PackedStringArray = [
	"res://assets/models/props/ph_prop_corpse.glb", "res://assets/models/props/ph_prop_corpse_02.glb",
	"res://assets/models/props/ph_prop_corpse_03.glb", "res://assets/models/props/ph_prop_corpse_04.glb",
]
var _present: bool = true
var _talkable: bool = true
var _with_cart: bool = true
## Path & pose evaluation (npc_pose.gd): polylines, sampling, standing / look headings.
var _pose: NpcPose
var _heading: float = 0.0
## Extra yaw of the figure (Model) towards a nearby player; the cart keeps its place.
var _look: float = 0.0
var _model: Node3D
## debug_teleport(): the phase it holds for (null = none), the spot and the heading.
var _held_entry: ScheduleEntry
var _held_position: Vector3
var _held_heading: float = 0.0
## The schedule has with_cart entries (Osric); otherwise no cart / cargo logic at all (Ilse).
var _uses_cart: bool = true
var _lantern: OmniLight3D
## Game minute of the last update while hidden (see _process).
var _hidden_minute: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)
	_pose = NpcPose.new(self)


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
	_uses_cart = _schedule_uses_cart()
	if not _uses_cart:
		cart.visible = false
		cart_shape.disabled = true
		cargo.visible = false
		_with_cart = false
	_make_lantern()
	refresh()


func _process(delta: float) -> void:
	# QA W3 (Phase 4 perf): hidden (at home, or its requires_flag missing – Ilse all day) the
	# schedule can only change with the game minute – re-evaluated once per minute, not per frame.
	if not _present and _held_entry == null:
		var minute := TimeManager.total_minutes()
		if minute == _hidden_minute:
			return
		_hidden_minute = minute
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


## Standing at a dialogue spot (prompt active).
func is_talkable() -> bool:
	return _talkable


## requires_flag is set (or none is required).
func flag_allows() -> bool:
	if requires_flag == &"" or not GameState.has_flag(requires_flag):
		return requires_flag == &""
	var v: Variant = GameState.get_flag(requires_flag)
	return not (typeof(v) == TYPE_BOOL and not v)


func lantern() -> OmniLight3D:
	return _lantern


func is_walking() -> bool:
	return entry != null and entry.travel_minutes > 0 and progress < 1.0 and _held_entry == null


## Metres per real second along the current path (0 while standing or the clock is stopped).
func ground_speed() -> float:
	if not is_walking() or not TimeManager.running or TimeManager.paused:
		return 0.0
	var path := _pose.path(entry)
	return float(path.total) / (entry.travel_minutes * maxf(TimeManager.config.seconds_per_game_minute, EPSILON))


## Everything follows from the clock.
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	_held_entry = null
	refresh()


## Debug console ("npc <id> here"): stands at `world_pos` (on the ground) for the rest of the
## current schedule phase, then the clock takes over again. He faces the nearest player – with
## the cart turned to his side, so it never lands on them.
func debug_teleport(world_pos: Vector3) -> void:
	var sched := _schedule()
	if sched == null or sched.entries.is_empty():
		push_warning("[Npc] %s: no schedule – debug_teleport ignored" % name)
		return
	_held_entry = ScheduleResolver.entry_at(sched, int(TimeManager.get_minute_f()))
	_held_position = _pose.on_ground(world_pos)
	_held_heading = rotation.y
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	if player != null:
		var to := _flat(player.global_position - _held_position)
		if to.length_squared() > EPSILON:
			_held_heading = atan2(to.x, to.z) + (PI * 0.5 if _held_entry != null and _held_entry.with_cart else 0.0)
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
	if _held_entry != null and _held_entry != entry:
		_held_entry = null
	var path := _pose.path(entry)
	var sample := _pose.sample(path, progress)
	global_position = sample[0] if _held_entry == null else _held_position
	var dir: Vector3 = sample[1]
	var shown := entry.visible and flag_allows()
	_set_state(shown, shown and entry.dialogue_id != &"", shown and entry.with_cart and _uses_cart)
	if _uses_cart:
		cargo.visible = _with_cart and _has_cargo()
		if cargo.visible and _cargo_day != TimeManager.day:
			_show_cargo_for(TimeManager.day)
	# The root (and with it the cart) turns with the path; only the figure turns to a player.
	var heading := _heading
	if _held_entry != null:
		heading = _held_heading
	elif is_walking() and dir.length_squared() > EPSILON:
		heading = atan2(dir.x, dir.z)
	elif not is_walking():
		heading = _pose.waypoint_yaw(entry, heading)
	var look := _pose.look_yaw(heading, not is_walking() and _talkable)
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


func _set_state(present: bool, talkable: bool, with_cart: bool) -> void:
	if present != _present:
		_present = present
		visible = present
		body_shape.set_deferred(&"disabled", not present)
		# Hidden: the skeleton rests (QA W3 perf); _update_animation plays again once shown.
		if _anim != null and not present and _anim.is_playing():
			_anim.pause()
	if talkable != _talkable:
		_talkable = talkable
		interactable.enabled = talkable
		interactable.set_deferred(&"monitorable", talkable)
	if with_cart != _with_cart:
		_with_cart = with_cart
		cart.visible = with_cart
		cart_shape.set_deferred(&"disabled", not with_cart)


func _update_animation() -> void:
	if _anim == null or not _present:
		return
	# Held by debug_teleport in the middle of a walk: he waits (idle) instead of walking on the spot.
	var wanted := entry.animation if _held_entry == null or entry.travel_minutes == 0 else ANIM_IDLE
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


## Corpse on the cart: on the way in before the delivery minute, or all day after a skipped one
## – not on a day without delivery (cemetery full, disreputable on an even day).
## Swaps the cargo model to the look of the corpse that is delivered on `day` (deterministic seed).
func _show_cargo_for(day: int) -> void:
	_cargo_day = day
	if _tables == null:
		return
	var record := CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), _tables, day)
	var look := Corpse.variant_for_record(record, _tables, CARGO_LOOKS.size())
	var scene := load(CARGO_LOOKS[look]) as PackedScene
	if scene == null or cargo.scene_file_path == scene.resource_path:
		return
	var fresh := scene.instantiate() as Node3D
	var parent := cargo.get_parent()
	fresh.name = cargo.name
	fresh.transform = cargo.transform
	fresh.visible = cargo.visible
	parent.add_child(fresh)
	parent.move_child(fresh, cargo.get_index())
	cargo.free()
	cargo = fresh


func _has_cargo() -> bool:
	if _tables == null or _cemetery_full() or _deliveries_due(TimeManager.day) <= 0:
		return false
	if TimeManager.minute_of_day < _tables.delivery_minute:
		return true
	return GameState.get_flag(FLAG_DELIVERY_SKIPPED, 0) == TimeManager.day


## CorpseManager.deliveries_due (1 without a manager that knows it).
func _deliveries_due(day: int) -> int:
	var manager := get_tree().get_first_node_in_group(&"corpse_manager")
	if manager == null or not manager.has_method(&"deliveries_due"):
		return 1
	return int(manager.call(&"deliveries_due", day))


## Same rule as CorpseManager: no plot left for a new corpse means no more deliveries.
func _cemetery_full() -> bool:
	var graveyard := get_tree().get_first_node_in_group(&"graveyard")
	var manager := get_tree().get_first_node_in_group(&"corpse_manager")
	if graveyard == null or manager == null or not graveyard.has_method(&"free_plot_count") \
			or not manager.has_method(&"unburied_count"):
		return false
	return int(graveyard.call(&"free_plot_count")) <= int(manager.call(&"unburied_count"))


func _schedule_uses_cart() -> bool:
	var sched := _schedule()
	if sched == null:
		return true
	for e: ScheduleEntry in sched.entries:
		if e != null and e.with_cart:
			return true
	return false


## The lantern light at the lantern_marker node of the model (fallback: in front of the hip).
func _make_lantern() -> void:
	if lantern_marker == &"" or _lantern != null:
		return
	var parent: Node3D = self
	var offset := LANTERN_FALLBACK
	if _model != null:
		var marker := _model.find_child(String(lantern_marker), true, false) as Node3D
		if marker != null:
			parent = marker
			offset = Vector3.ZERO
	_lantern = OmniLight3D.new()
	_lantern.name = LANTERN_NAME
	_lantern.light_color = LANTERN_COLOR
	_lantern.light_energy = LANTERN_ENERGY
	_lantern.omni_range = LANTERN_RANGE
	_lantern.omni_attenuation = LANTERN_ATTENUATION
	_lantern.shadow_enabled = false
	_lantern.position = offset
	# AtmosphereController scales every warm light from its base energy (default 1.0).
	_lantern.set_meta(&"base_energy", LANTERN_ENERGY)
	_lantern.add_to_group(&"warm_lights", true)
	parent.add_child(_lantern)


# --- lookups -------------------------------------------------------------------------------

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
	return NpcPose.flat(v)
