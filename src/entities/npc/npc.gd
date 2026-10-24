class_name Npc
extends Node3D
## Schedule-driven NPC (groups npc, saveable). Every frame it places itself from
## ScheduleResolver.entry_at() + progress() along the entry's waypoint polyline (constant speed
## by arc length) at TimeManager.get_minute_f() – nothing but the clock is needed, so the save
## is empty. Walking: walk / push_cart with AnimationPlayer.speed_scale = ground speed / the
## speed the cycle was made for; afterwards entry.animation. Hidden entries hide the NPC and
## switch its Interactable and collision off. The handcart (Cart) shows while with_cart;
## Cargo (the dead on the cart, CorpseManager.cart_load) until he has laid them onto the bier – or all day when
## the delivery was skipped. G8 Runde 3 (CartUnload, CartDeliveryConfig): in the minutes before the delivery he
## steps to the cart, lifts each corpse off, carries it to its bier and lays it down; afterwards he walks back to
## the handles – the figure (Model) and the cargo move, the root and the cart stay. All from the clock as well.
## Standing heading: the waypoint's facing, else the direction of the walk that ended there –
## both follow from the clock, so a load shows him exactly as walking in did (SL-1).
## debug_teleport() (debug console) holds him at a spot until the next schedule phase.
## Path sampling and heading evaluation: npc_pose.gd.
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, §9): shown only for entries of its own region (entry.region,
## "" = graveyard) and while hide_flag is not set. Outside the gravekeeper's region it evaluates once
## per game minute (like hidden) and its animation rests. LOD (set_lod, from NpcLod): 0 full ·
## 1 reduced (evaluation every NpcConfig.reduced_interval s, the animation runs) · 2 resting (the
## evaluation as 1, the animation paused).

const GROUP := &"npc"
const PROMPT_TALK := "[E] Mit %s reden"
const ANIM_WALK := &"walk"
## Gaits a walk entry may ask for besides the *_walk cycles (_moving_anim).
const MOVE_ANIMS: Array[StringName] = [&"run", &"climb"]
const ANIM_PUSH := &"push_cart"
const ANIM_IDLE := &"idle"
## Phase 8 (§2.1.1, §2.1.2): a „bedrückt" figure stands with its head down; chatter partners talk.
const ANIM_IDLE_LOW := &"idle_low"
const ANIM_TALK := &"talk"
const ANIM_LOW_MOOD := &"low"
const FLAG_DELIVERY_SKIPPED := &"delivery_skipped"
const CART_SLOT := "slot_corpse"
## G8 Runde 3 (gate bell): the bell rings only while the clock runs past its moment – a step longer than this
## (game minutes; a skip, sleep or load) rings nothing.
const BELL_MAX_GAP := 2.0
const BELL_GROUP := &"gate_bell"
## G8 Runde 3: a third corpse on the cart lies this much (m) higher, on the two side by side.
const CARGO_STACK := 0.2
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
## G8 Runde 2: child meshes named lantern* (lantern_prop, Jakob's lantern) are carried lanterns (CarriedLanterns.GROUP).
const LANTERN_PROP_PREFIX := "lantern"
const LANTERN_BLIND := "lantern_blind"
const CARRIED_LANTERN_GROUP := &"carried_lantern"

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
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P1): the region of this Npc – shown only for schedule entries
## of its region (entry.region, "" = graveyard); hidden while the GameState flag hide_flag is set
## (Wiebke Hagedorn: hagedorn_dead).
@export var region_id: StringName = &"graveyard"
@export var hide_flag: StringName = &""
@export_group("Animation")
## Ground speed (m/s) at which the walk / push_cart cycles do not slide (rig notes, M6a).
@export var walk_anim_speed: float = 1.65
@export var push_anim_speed: float = 1.14
## G8 Runde 3: ground speed (m/s) of the carry_walk cycle (the dead in his arms).
@export var carry_anim_speed: float = 1.2
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
## G8 Runde 3: the cargo nodes on the cart's slot ([0] = cargo, more for several corpses), the cart load of the
## current game minute (CorpseManager.cart_load; key = total minute, -1 = stale), the unload pose (CartUnload.pose,
## {} = none) and its values.
var _cargo_nodes: Array[Node3D] = []
var _load_key: int = -1
var _load: Dictionary = {}
var _unload: Dictionary = {}
var cart_config: CartDeliveryConfig
## Total game minute (with fraction) of the last update that may ring the gate bell (-1 = none yet / placed anew).
var _bell_clock: float = -1.0
var _bell: Node3D
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
## Phase 7: LOD values (null = data/config/npc_config.tres), the level and the time since the last
## reduced evaluation; whether the gravekeeper is in this Npc's region.
var npc_config: NpcConfig
var _lod: int = 0
var _lod_elapsed: float = 0.0
var _region_active: bool = true
## Phase 8: the runtime schedule (set_runtime_schedule; null = data), the current animation, the child
## meshes with a show_with / hide_with meta ([mesh, show list, hide list, hide_after]), the level-1 interval
## override (night of the lights) and the visible cap (NpcLod).
var _runtime: NpcSchedule
var _current_anim: StringName = &""
var _props: Array = []
## QA8-07: hash(entry, schedule, carry list) → the next clip outside the carry list (_next_animation_outside).
var _carry_cache: Dictionary[int, StringName] = {}
var lod_interval_override: float = 0.0
var _culled: bool = false
## ChatterRunner: the figure turns to its partner and talks (null = none).
var _chatter_target: Node3D
## Mood cache (NpcLife.mood is derived; asked once per game hour): [hour key, low].
var _mood_key: int = -1
var _mood_low: bool = false
## G8 Runde 4 (NpcWorkConfig, null = data/config/npc_work_config.tres): the figure works (its entry's clip is a work
## clip) and is attending the gravekeeper (he stands close or talks to it: the work pauses); the dialogue it was
## asked for is open; the pipe-smoke puffs and the cycle position they were last checked at.
var work_config: NpcWorkConfig
var _working: bool = false
var _attending: bool = false
var _in_dialogue: bool = false
var _puffs: CPUParticles3D
var _puff_pos: float = -1.0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)
	_pose = NpcPose.new(self)


func _ready() -> void:
	# W-Welt (Phase 7): the village figures and the priest on his consecration walk have no save_id –
	# their state is the clock (save_state is empty), so they are no saveables at all.
	if save_id == "":
		remove_from_group(&"saveable")
	if model != null and get_node_or_null(^"Model") == null:
		var inst := model.instantiate()
		inst.name = "Model"
		add_child(inst)
	_model = get_node_or_null(^"Model") as Node3D
	var found: Array[Node] = []
	if _model != null:
		found = _model.find_children("*", "AnimationPlayer", true, false)
	_anim = found[0] as AnimationPlayer if not found.is_empty() else null
	_collect_props()
	# The cargo lies on the cart's slot_corpse marker (+X = the corpse's long axis).
	var slot := cart.find_child(CART_SLOT, true, false) as Node3D
	if slot != null and cargo.get_parent() != slot:
		cargo.reparent(slot, false)
		cargo.transform = Transform3D.IDENTITY
	_cargo_nodes = [cargo]
	_tables = Database.corpse_tables() as CorpseTables
	_heading = rotation.y
	_uses_cart = _schedule_uses_cart()
	if not _uses_cart:
		cart.visible = false
		cart_shape.disabled = true
		cargo.visible = false
		_with_cart = false
	_make_lantern()
	_region_active = RegionRoot.current(get_tree()) == region_id
	EventBus.region_changed.connect(_on_region_changed)
	EventBus.corpse_arrived.connect(_on_cart_load_changed.unbind(1))
	EventBus.delivery_skipped.connect(_on_cart_load_changed.unbind(2))
	# G8 Runde 3 (QA Lieferung): a time skip (debug „time", sleeping, waiting) places the carter for the new clock at once.
	EventBus.time_skipped.connect(_on_time_skipped)
	EventBus.dialogue_ended.connect(_on_dialogue_ended.unbind(1))
	refresh()


func _process(delta: float) -> void:
	# QA W3 (Phase 4 perf): hidden (at home, or its requires_flag missing – Ilse all day) the
	# schedule can only change with the game minute – re-evaluated once per minute, not per frame.
	# Phase 7: the same outside the gravekeeper's region.
	if (not _present or not _region_active) and _held_entry == null:
		var minute := TimeManager.total_minutes()
		if minute == _hidden_minute:
			return
		_hidden_minute = minute
	elif _lod > 0:
		_lod_elapsed += delta
		if _lod_elapsed < _lod_interval():
			return
		delta = _lod_elapsed
		_lod_elapsed = 0.0
	_update(delta)


## Places the NPC for the current clock immediately (no smoothing).
func refresh() -> void:
	_load_key = -1
	_bell_clock = -1.0
	_update(-1.0)


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and _talkable


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT_TALK % first_name() if _talkable else ""


## Talking is allowed while carrying a corpse (§3.4).
func interact(player: Player) -> void:
	if can_interact(player):
		# G8 Runde 4: a working figure puts the work down and talks (until EventBus.dialogue_ended).
		_in_dialogue = true
		EventBus.dialogue_requested.emit(entry.dialogue_id, self)
		if is_inside_tree():
			refresh()


## G8 Runde 4: the figure stands at a work place and plays a work clip (NpcWorkConfig.work_clips).
func is_working() -> bool:
	return _working


## G8 Runde 4: the work pauses for the gravekeeper (he is close or talks to the figure).
func is_attending() -> bool:
	return _attending


func first_name() -> String:
	var full := _schedule().display_name if _schedule() != null else ""
	if full == "" and _runtime != null:
		if schedule == null and npc_id != &"":
			schedule = Database.schedule(npc_id) as NpcSchedule
		full = schedule.display_name if schedule != null else ""
	if full == "":
		full = String(npc_id)
	return full.get_slice(" ", 0)


func is_present() -> bool:
	return _present


## G9 Gehtempo: present by the clock now (what the next _update sets) – for callers between two frames (a dialogue
## condition right after a time skip: the bots advance the clock without frames, a hidden figure re-evaluates only
## once per frame), so they never read the state of an older minute.
func present_by_clock() -> bool:
	var sched := _schedule()
	if sched == null or sched.entries.is_empty():
		return false
	var e := ScheduleResolver.entry_at(sched, int(TimeManager.get_minute_f()), TimeManager.day)
	if e == null:
		return _present
	return e.visible and flag_allows() and shows_region(e) and not hidden_by_flag()


## Standing at a dialogue spot (prompt active).
func is_talkable() -> bool:
	return _talkable


## requires_flag is set (or none is required).
func flag_allows() -> bool:
	if requires_flag == &"" or not GameState.has_flag(requires_flag):
		return requires_flag == &""
	var v: Variant = GameState.get_flag(requires_flag)
	return not (typeof(v) == TYPE_BOOL and not v)


## The model's AnimationPlayer (CarriedLanterns: the gait phase for the lantern's swing).
func animation_player() -> AnimationPlayer:
	return _anim


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


## Phase 7 (docs/PHASE7_DESIGN.md §3.4, §9): 0 full · 1 reduced (evaluation every
## NpcConfig.reduced_interval, the animation runs) · 2 resting (animation paused). NpcLod sets it.
func set_lod(level: int) -> void:
	level = clampi(level, 0, 2)
	if level == _lod:
		return
	_lod = level
	_lod_elapsed = 0.0
	if level >= 2:
		_pause_animation()
	elif is_node_ready() and _present:
		_update_animation()


func lod() -> int:
	return _lod


## Phase 8 (docs/PHASE8_DESIGN.md §3.4, P1): a runtime schedule (ScheduleBuilder – visits, the apprentice,
## festivals, the robber) replaces the data schedule until clear_runtime_schedule(); not saved (the owner
## rebuilds it from its plan + the clock after a load). null = clear_runtime_schedule(). Entries without a
## region take this Npc's region (ScheduleBuilder.stay has none).
func set_runtime_schedule(s: NpcSchedule) -> void:
	if s == null:
		clear_runtime_schedule()
		return
	# ScheduleBuilder.stay knows no region: entries without one belong to this Npc's region.
	if region_id != RegionRoot.GRAVEYARD:
		for e: ScheduleEntry in s.entries:
			if e != null and e.region == &"":
				e.region = region_id
	_runtime = s
	_after_schedule_change()


## Back to the data schedule (data/npc/<npc_id>; none → hidden).
func clear_runtime_schedule() -> void:
	if _runtime == null:
		return
	_runtime = null
	_after_schedule_change()


## The runtime schedule (null = the data schedule is active).
func runtime_schedule() -> NpcSchedule:
	return _runtime


## The animation the figure plays (or would play) right now (&"" = hidden / none) – the show_with meshes
## follow it.
func current_animation() -> StringName:
	return _current_anim


## Phase 8 (§3.4, §9): NpcLod sets the level-1 evaluation interval on the night of the lights (3 Hz);
## <= 0 = NpcConfig.reduced_interval.
func set_lod_interval(seconds: float) -> void:
	lod_interval_override = seconds


## Phase 8 (§9): beyond the visible cap of the region (NpcLod) the figure is not drawn (it keeps its
## place, prompt and collision from the clock).
func set_culled(on: bool) -> void:
	if on == _culled:
		return
	_culled = on
	if _model != null:
		_model.visible = not on


func is_culled() -> bool:
	return _culled


## Phase 8 (§2.1.2, ChatterRunner): while set (and standing) the figure turns to `target` and plays talk.
func set_chatter_target(target: Node3D) -> void:
	_chatter_target = target
	if is_node_ready():
		refresh()


func chatter_target() -> Node3D:
	return _chatter_target if is_instance_valid(_chatter_target) else null


## Whether the gravekeeper is in this Npc's region (Player.region_id; graveyard without a player).
func region_active() -> bool:
	return _region_active


## The entry belongs to this Npc's region (entry.region, "" = the graveyard).
func shows_region(e: ScheduleEntry) -> bool:
	return e != null and (e.region if e.region != &"" else RegionRoot.GRAVEYARD) == region_id


## hide_flag is set (Wiebke Hagedorn after hagedorn_dead).
func hidden_by_flag() -> bool:
	return hide_flag != &"" and GameState.flag_on(hide_flag)


## Debug console ("npc <id> here"): stands at `world_pos` (on the ground) for the rest of the
## current schedule phase, then the clock takes over again. He faces the nearest player – with
## the cart turned to his side, so it never lands on them.
func debug_teleport(world_pos: Vector3) -> void:
	var sched := _schedule()
	if sched == null or sched.entries.is_empty():
		push_warning("[Npc] %s: no schedule – debug_teleport ignored" % name)
		return
	_held_entry = ScheduleResolver.entry_at(sched, int(TimeManager.get_minute_f()), TimeManager.day)
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
		# Phase 8 (§3.1): an Npc without a plan (the new graveyard figures before their runtime schedule)
		# is hidden like one at home.
		entry = null
		if is_node_ready():
			_set_state(false, false, false)
			_current_anim = &""
			_apply_props()
		return
	var minute_f := TimeManager.get_minute_f()
	entry = ScheduleResolver.entry_at(sched, int(minute_f), TimeManager.day)
	if entry == null:
		return
	progress = ScheduleResolver.progress(entry, minute_f)
	if _held_entry != null and _held_entry != entry:
		_held_entry = null
	if not shows_region(entry):
		# W-Welt (Phase 7): an entry of the other region (Osric's village day, the priest's
		# consecration walk) names waypoints this Npc's world does not have – hidden, no path.
		_set_state(false, false, false)
		_current_anim = &""
		_apply_props()
		return
	var path := _pose.path(entry)
	var sample := _pose.sample(path, progress)
	global_position = sample[0] if _held_entry == null else _held_position
	var dir: Vector3 = sample[1]
	var shown := entry.visible and flag_allows() and shows_region(entry) and not hidden_by_flag()
	var cart_on := shown and entry.with_cart and _uses_cart
	# G8 Runde 3: no prompt while he unloads and walks back to the handles.
	_set_state(shown, shown and entry.dialogue_id != &"" and not (cart_on and _cart_busy(minute_f)), cart_on)
	# The root (and with it the cart) turns with the path; only the figure turns to a player.
	var heading := _heading
	if _held_entry != null:
		heading = _held_heading
	elif is_walking() and dir.length_squared() > EPSILON:
		heading = atan2(dir.x, dir.z)
	elif not is_walking():
		heading = _pose.waypoint_yaw(entry, heading)
	# G8 Runde 4: at a work place the figure keeps to its work (facing the counter, altar, desk) until the gravekeeper
	# comes close (NpcWorkConfig.pause_range) or talks to it; then it stops and turns to him.
	var work_cfg := _work_config()
	_working = not is_walking() and _held_entry == null and work_cfg.is_work(entry.animation)
	if _working and not entry.path.is_empty():
		var work_yaw := work_cfg.facing_at(StringName(entry.path[entry.path.size() - 1]))
		if not is_nan(work_yaw):
			heading = work_yaw
	var look := _pose.look_yaw(heading, not is_walking() and _talkable, work_cfg.pause_range if _working else -1.0)
	_attending = _working and _talkable and (_in_dialogue or not is_zero_approx(look) or _pose.player_within(work_cfg.pause_range))
	var partner := chatter_target()
	if partner != null and not is_walking():
		var to := _flat(partner.global_position - global_position)
		if to.length_squared() > EPSILON:
			look = wrapf(atan2(to.x, to.z) - heading, -PI, PI)
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
	if _uses_cart:
		_update_cargo(minute_f)
		_check_bell(minute_f, delta)
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
	if not _present or entry == null:
		if _current_anim != &"":
			_current_anim = &""
			_apply_props()
		return
	if bool(_unload.get("active", false)):
		_play_unload()
		return
	# Held by debug_teleport in the middle of a walk: he waits (idle) instead of walking on the spot.
	var wanted := entry.animation if _held_entry == null or entry.travel_minutes == 0 else ANIM_IDLE
	var designed := 0.0
	if is_walking():
		wanted = ANIM_PUSH if entry.with_cart else _moving_anim()
		designed = push_anim_speed if entry.with_cart else (walk_anim_speed if String(wanted).ends_with("walk") else 0.0)
	elif chatter_target() != null:
		wanted = ANIM_TALK
	elif _attending:
		wanted = _work_config().talk_clip if _in_dialogue else _work_config().pause_clip
	elif wanted == ANIM_IDLE and _is_low():
		wanted = ANIM_IDLE_LOW
	if wanted != _current_anim or not _props.is_empty():
		_current_anim = wanted
		_apply_props()
	if _anim == null:
		return
	if _lod >= 2 or not _region_active:
		_pause_animation()
		return
	if not _anim.has_animation(wanted):
		wanted = ANIM_IDLE
	if not _anim.has_animation(wanted):
		return
	if _anim.current_animation != wanted or not _anim.is_playing():
		_anim.play(wanted, anim_blend)
		_puff_pos = -1.0
	_anim.speed_scale = ground_speed() / designed if designed > 0.0 else 1.0
	_check_puffs(wanted)


## W-Welt (W2): a walk entry may name its gait – a *_walk cycle (lantern_walk, carry_can_walk), run (Lambert's
## flight) or climb (over the Lindenacker fence); the model must have it, else the plain walk.
func _moving_anim() -> StringName:
	var gait := entry.animation if entry != null else &""
	if gait != &"" and (String(gait).ends_with("_walk") or gait in MOVE_ANIMS) and _anim != null and _anim.has_animation(gait):
		return gait
	return ANIM_WALK


## NpcLife says „bedrückt" (only while the mood effects apply; asked once per game hour).
func _is_low() -> bool:
	if npc_id == &"" or not is_inside_tree():
		return false
	var key := floori(TimeManager.total_minutes() / 60.0)
	if key != _mood_key:
		_mood_key = key
		var life := get_tree().get_first_node_in_group(&"npc_life")
		_mood_low = life != null and life.has_method(&"moods_active") and bool(life.call(&"moods_active")) \
				and StringName(str(life.call(&"mood", npc_id))) == ANIM_LOW_MOOD
	return _mood_low


func _pause_animation() -> void:
	if _anim != null and _anim.is_playing():
		_anim.pause()


## EventBus.region_changed: back in the region → placed from the clock at once; away → resting.
func _on_region_changed(id: StringName) -> void:
	var now := id == region_id
	if now == _region_active:
		return
	_region_active = now
	_hidden_minute = -1
	if not now:
		_pause_animation()
	elif is_node_ready():
		refresh()


func _lod_interval() -> float:
	if npc_config == null:
		npc_config = Database.config(&"npc_config") as NpcConfig
		if npc_config == null:
			npc_config = NpcConfig.new()
	return lod_interval_override if lod_interval_override > 0.0 else npc_config.reduced_interval


## Phase 8 (§3.4, „Muster ToolProps"): child meshes of the model with the meta show_with (animation names –
## Array, PackedStringArray or "a,b") are shown only while the figure plays one of them; hide_with hides
## them in those; hide_after (an animation name) hides them for good once the schedule has passed the entry
## with that animation (the bouquet after lay_flowers). No nodes are created at runtime.
func _collect_props() -> void:
	_props.clear()
	if _model == null:
		return
	var stack: Array[Node] = [_model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var node3d := n as Node3D
		if node3d == null or node3d == _model:
			continue
		# W-Welt (W2): the exported figures carry the clip lists as glTF extras (node meta "extras").
		var extras: Dictionary = node3d.get_meta(&"extras", {}) if node3d.get_meta(&"extras", {}) is Dictionary else {}
		if node3d.has_meta(&"show_with") or node3d.has_meta(&"hide_with") or extras.has("show_with") or extras.has("hide_with"):
			_props.append([node3d, _names(node3d.get_meta(&"show_with", extras.get("show_with", ""))),
					_names(node3d.get_meta(&"hide_with", extras.get("hide_with", ""))),
					StringName(str(node3d.get_meta(&"hide_after", extras.get("hide_after", "")))),
					_names(node3d.get_meta(&"carry_with", extras.get("carry_with", "")))])
			# G8 Runde 2 (Lichtgang): a carried lantern (not Lambert's hooded one) gets its light, spot, flicker and
			# swing from CarriedLanterns.
			if String(node3d.name).begins_with(LANTERN_PROP_PREFIX) and not String(node3d.name).begins_with(LANTERN_BLIND):
				node3d.add_to_group(CARRIED_LANTERN_GROUP)
	_carry_cache.clear()


## Visibility of the show_with meshes for the current animation (and the schedule position).
func _apply_props() -> void:
	for p: Array in _props:
		var node: Node3D = p[0]
		if not is_instance_valid(node):
			continue
		var show_list: Array[StringName] = p[1]
		var hide_list: Array[StringName] = p[2]
		var shown := _current_anim != &"" and (show_list.is_empty() or _current_anim in show_list)
		if _current_anim in hide_list:
			shown = false
		var after: StringName = p[3]
		if shown and after != &"" and _passed_animation(after):
			shown = false
		# W3 (QA8-07, P5 carry_with, §1 „Werkzeug in der Hand"): between the places of a job the tool of that job
		# stays in the hand – in its carry_with clips while the next entry of the schedule that does something else
		# (a clip outside carry_with) plays one of its show_with clips: the rake on the way from leaf heap to leaf
		# heap, not on the way to the weeds or to the bench.
		var carry_list: Array[StringName] = p[4] if p.size() > 4 else ([] as Array[StringName])
		if not shown and not carry_list.is_empty() and _current_anim in carry_list and not show_list.is_empty() \
				and _next_animation_outside(carry_list) in show_list:
			shown = true
		node.visible = shown


## QA8-07: the animation of the first schedule entry after the current one (by start) whose clip is not in
## `carry` (&"" = none today). Cached per current entry and list.
func _next_animation_outside(carry: Array[StringName]) -> StringName:
	var sched := _schedule()
	if sched == null or entry == null:
		return &""
	var key := hash([entry.get_instance_id(), sched.get_instance_id(), carry])
	if _carry_cache.has(key):
		return _carry_cache[key]
	if _carry_cache.size() > 16:
		_carry_cache.clear()
	var best: ScheduleEntry = null
	for e: ScheduleEntry in sched.entries:
		if e == null or e == entry or e.animation in carry or e.start_minute <= entry.start_minute:
			continue
		if best == null or e.start_minute < best.start_minute:
			best = e
	var anim := best.animation if best != null else &""
	_carry_cache[key] = anim
	return anim


## The schedule has an entry with `anim` that started before the current entry (sorted by start).
func _passed_animation(anim: StringName) -> bool:
	var sched := _schedule()
	if sched == null or entry == null:
		return false
	for e: ScheduleEntry in sched.entries:
		if e != null and e != entry and e.animation == anim and e.start_minute < entry.start_minute:
			return true
	return false


## True if the show_with mesh `mesh_name` is visible (tests, screenshots).
func prop_shown(mesh_name: String) -> bool:
	for p: Array in _props:
		if is_instance_valid(p[0]) and (p[0] as Node3D).name == mesh_name:
			return (p[0] as Node3D).visible
	return false


static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is String or raw is StringName:
		for part: String in str(raw).split(",", false):
			if part.strip_edges() != "":
				out.append(StringName(part.strip_edges()))
	elif raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out


## Test helper (round 1): the first cargo node wears the look of the corpse generated for `day` (spawn index 0).
func _show_cargo_for(day: int) -> void:
	if _tables != null:
		_set_cargo_look(0, CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), _tables, day))


# --- G8 Runde 3: the dead on the cart and the unloading -----------------------------------

## The cargo for the clock: every corpse of the cart load on the cart's slot (side by side, head to the handles),
## in the look it will have on the bier (story looks too); during the unloading (CartUnload.pose) the one in his
## hands follows the pose, those laid down lie on their biers and the figure walks / lifts / lowers.
func _update_cargo(minute_f: float) -> void:
	var was_active := bool(_unload.get("active", false))
	_unload = {}
	var cfg := _cart_config()
	var now_load := _cart_load()
	var unload: Array[CorpseRecord] = now_load.get("unload", [] as Array[CorpseRecord])
	var keep: Array[CorpseRecord] = now_load.get("keep", [] as Array[CorpseRecord])
	var biers: Array[Transform3D] = now_load.get("biers", [] as Array[Transform3D])
	var total := mini(unload.size() + keep.size(), maxi(cfg.max_cargo, 1))
	var shown := _with_cart and _present
	if shown:
		_ensure_cargo(total)
	for i: int in _cargo_nodes.size():
		var node := _cargo_nodes[i]
		node.visible = shown and i < total
		if node.visible:
			_set_cargo_look(i, unload[i] if i < unload.size() else keep[i - unload.size()])
			_cargo_nodes[i].transform = _cargo_rest(i, total)
	var slot := _cart_slot()
	if shown and slot != null and _tables != null and _held_entry == null and _in_unload_window(minute_f):
		var on_cart: Array[Transform3D] = []
		for i: int in mini(unload.size(), total):
			on_cart.append(slot.global_transform * _cargo_rest(i, total))
		_unload = CartUnload.pose(cfg, minute_f, _tables.delivery_minute, on_cart, biers, global_position, rotation.y,
				slot.global_position, slot.global_basis.x, int(now_load.get("delivered", 0)), _return_bier(),
				slot.global_transform * _cargo_rest(0, maxi(total, 1)), _bell_point())
	if bool(_unload.get("active", false)):
		var laid: int = _unload.laid
		var moving: int = _unload.index
		for i: int in mini(mini(unload.size(), total), biers.size()):
			if i < laid:
				_cargo_nodes[i].global_transform = biers[i]
			elif i == moving:
				_cargo_nodes[i].global_transform = _unload.corpse
		if _model != null:
			_model.position = to_local(_unload.figure)
			_look = wrapf(float(_unload.yaw) - rotation.y, -PI, PI)
			_model.rotation = Vector3(0.0, _look, 0.0)
	elif _model != null and (was_active or _model.position != Vector3.ZERO):
		_model.position = Vector3.ZERO


## The unload clips: one-shots (load_lift / load_lower) follow the pose's progress, the walks run at the ground
## speed (stopped with the clock).
func _play_unload() -> void:
	var wanted: StringName = _unload.anim
	if wanted != _current_anim or not _props.is_empty():
		_current_anim = wanted
		_apply_props()
	if _anim == null:
		return
	if _lod >= 2 or not _region_active:
		_pause_animation()
		return
	var designed := carry_anim_speed if wanted == CartUnload.ANIM_CARRY else walk_anim_speed
	if not _anim.has_animation(wanted):
		wanted = ANIM_WALK if wanted == CartUnload.ANIM_CARRY else ANIM_IDLE
		designed = walk_anim_speed
	if not _anim.has_animation(wanted):
		return
	var t: float = _unload.anim_t
	if t >= 0.0:
		if _anim.current_animation != wanted:
			_anim.play(wanted, anim_blend)
		_anim.speed_scale = 1.0
		_anim.seek(clampf(t, 0.0, 1.0) * _anim.current_animation_length, true)
		return
	if _anim.current_animation != wanted or not _anim.is_playing():
		_anim.play(wanted, anim_blend)
	var real := 0.0
	if TimeManager.running and not TimeManager.paused:
		real = float(_unload.speed) / maxf(TimeManager.config.seconds_per_game_minute, EPSILON)
	_anim.speed_scale = real / designed if designed > 0.0 else 1.0


## The clock is between the start of the unloading and the end of the walk back.
func _in_unload_window(minute_f: float) -> bool:
	if _tables == null:
		return false
	var cfg := _cart_config()
	return minute_f >= float(cfg.unload_start(_tables.delivery_minute)) \
			and minute_f < float(_tables.delivery_minute) + cfg.after_minutes(_bell_point() != null)


## He is unloading or walking back to the handles right now (no prompt meanwhile).
func _cart_busy(minute_f: float) -> bool:
	if _held_entry != null or not _in_unload_window(minute_f):
		return false
	var now_load := _cart_load()
	if minute_f < float(_tables.delivery_minute):
		return not (now_load.get("unload", []) as Array).is_empty() and not (now_load.get("biers", []) as Array).is_empty()
	return int(now_load.get("delivered", 0)) > 0


## CorpseManager.cart_load for the current game minute (cached per minute). Without a manager (tests, previews):
## the corpse generated for the day on the cart until the delivery minute, after it only after a skipped delivery.
func _cart_load() -> Dictionary:
	var key := TimeManager.total_minutes()
	if key == _load_key:
		return _load
	_load_key = key
	var manager := get_tree().get_first_node_in_group(&"corpse_manager") if is_inside_tree() else null
	if manager != null and manager.has_method(&"cart_load"):
		_load = manager.call(&"cart_load", TimeManager.day, TimeManager.minute_of_day)
		return _load
	var keep: Array[CorpseRecord] = []
	var day := TimeManager.day
	if _tables != null and (TimeManager.minute_of_day < _tables.delivery_minute
			or int(GameState.get_flag(FLAG_DELIVERY_SKIPPED, 0)) == day):
		keep.append(CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), _tables, day))
	_load = {"unload": [] as Array[CorpseRecord], "biers": [] as Array[Transform3D], "keep": keep, "delivered": 0}
	return _load


func _on_cart_load_changed() -> void:
	_load_key = -1


## EventBus.time_skipped – only the carter (a figure with a cart): placed from the clock without smoothing (else the
## root – and the cart with it – swung from the old heading for a second after a skip, 3 m off at 07:35). Other
## figures keep their per-frame update (the playthrough bots read their entry right after a skip). A skip past the
## gate bell rings nothing – the HUD only notes the delivery (after the CorpseManager has made it, deferred).
func _on_time_skipped(from_total: int, to_total: int) -> void:
	if not _uses_cart or not is_node_ready() or not is_inside_tree():
		return
	_hidden_minute = -1
	refresh()
	_note_skipped_delivery.call_deferred(from_total, to_total)


# --- G8 Runde 3: the gate bell after the delivery (user: „und er soll an der glock klingeln das ich höre wen eine
# neue leiche da ist") -----------------------------------------------------------------------------------------------

## The gate bell's hanging point (world; null = no bell in this world) – CartUnload walks him there after the delivery.
func _bell_point() -> Variant:
	if _bell == null or not is_instance_valid(_bell):
		_bell = null
		if not is_inside_tree():
			return null
		for node: Node in get_tree().get_nodes_in_group(BELL_GROUP):
			if node is Node3D and (node as Node3D).is_inside_tree():
				_bell = node as Node3D
				break
		if _bell == null:
			return null
	var hang: Variant = _bell.call(&"bell_node") if _bell.has_method(&"bell_node") else null
	return (hang as Node3D).global_position if hang is Node3D else _bell.global_position


## Rings the bell when the running clock passes its moment (CartDeliveryConfig.ring_offset after the delivery) on a
## day something was delivered; placing him anew (delta < 0: refresh, load, skip) only notes the clock.
func _check_bell(minute_f: float, delta: float) -> void:
	var now := float(TimeManager.total_minutes() - TimeManager.minute_of_day) + minute_f
	var prev := _bell_clock
	_bell_clock = now
	if delta < 0.0 or prev < 0.0 or now <= prev or now - prev > BELL_MAX_GAP or _tables == null:
		return
	var at := _ring_total(TimeManager.day)
	if at < 0.0 or not (prev < at and now >= at) or not bool(_unload.get("ringing", false)):
		return
	if int(_cart_load().get("delivered", 0)) <= 0 or _bell == null:
		return
	if _bell.has_method(&"ring_delivery"):
		_bell.call(&"ring_delivery", first_name())


## Total game minute the bell sounds on `day` (-1 = no ringing).
func _ring_total(day: int) -> float:
	var off := _cart_config().ring_offset()
	if off < 0.0 or _tables == null or _bell_point() == null:
		return -1.0
	return float((day - 1) * TimeManager.MINUTES_PER_DAY + _tables.delivery_minute) + off


## A skip (sleep, waiting, debug „time") went past the ringing on a day he delivered: no sound, only the HUD note.
func _note_skipped_delivery(from_total: int, to_total: int) -> void:
	if not is_inside_tree() or _bell == null or not is_instance_valid(_bell):
		return
	var day := TimeManager.day
	var at := _ring_total(day)
	if at < 0.0 or not (float(from_total) < at and float(to_total) >= at):
		return
	_load_key = -1
	if int(_cart_load().get("delivered", 0)) > 0 and _bell.has_method(&"note_delivery"):
		_bell.call(&"note_delivery", first_name())


## Where corpse `i` of `total` lies on the cart (slot-local): side by side, a third one on top; head to the handles.
func _cargo_rest(i: int, total: int) -> Transform3D:
	var cfg := _cart_config()
	var basis := Basis(Vector3.UP, PI) if cfg.head_to_handles else Basis.IDENTITY
	var offset := Vector3.ZERO
	if total >= 2:
		if i < 2:
			offset.z = (-0.5 if i == 0 else 0.5) * cfg.cargo_spacing
		else:
			offset.y = CARGO_STACK * (i - 1)
	return Transform3D(basis, offset)


## At least `n` cargo nodes on the cart's slot (more for several corpses).
func _ensure_cargo(n: int) -> void:
	var parent := cargo.get_parent() if is_instance_valid(cargo) else null
	while _cargo_nodes.size() < n and parent != null:
		var scene := load(CARGO_LOOKS[0]) as PackedScene
		if scene == null:
			return
		var node := scene.instantiate() as Node3D
		node.name = "Cargo%d" % _cargo_nodes.size()
		node.visible = false
		parent.add_child(node)
		_cargo_nodes.append(node)


## Cargo node `i` wears the look of `record` (Corpse.look_of – the same model the corpse will have on the bier).
func _set_cargo_look(i: int, record: CorpseRecord) -> void:
	if i < 0 or i >= _cargo_nodes.size() or record == null:
		return
	var path := Corpse.look_path(Corpse.look_of(record, _tables, CARGO_LOOKS.size()), CARGO_LOOKS)
	var node := _cargo_nodes[i]
	if path == "" or node.scene_file_path == path:
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var fresh := scene.instantiate() as Node3D
	var parent := node.get_parent()
	fresh.name = node.name
	fresh.transform = node.transform
	fresh.visible = node.visible
	parent.add_child(fresh)
	parent.move_child(fresh, node.get_index())
	node.free()
	_cargo_nodes[i] = fresh
	if i == 0:
		cargo = fresh


## The cart's slot_corpse marker (null without one).
func _cart_slot() -> Node3D:
	return cargo.get_parent() as Node3D if is_instance_valid(cargo) and cargo.get_parent() != cart else cart.find_child(CART_SLOT, true, false) as Node3D


## The bier he walks back from after the delivery (the first one of the world).
func _return_bier() -> Transform3D:
	var bier := get_tree().get_first_node_in_group(&"dropoff") if is_inside_tree() else null
	return bier.call(&"slot_transform") as Transform3D if bier != null and bier.has_method(&"slot_transform") else global_transform


func _cart_config() -> CartDeliveryConfig:
	if cart_config == null:
		cart_config = Database.config(&"cart_delivery_config") as CartDeliveryConfig
		if cart_config == null:
			cart_config = CartDeliveryConfig.new()
	return cart_config


## How many corpses the cart shows right now (on the cart, in his arms or laid down until the delivery) – tests, screenshots.
func cargo_count() -> int:
	var n := 0
	for node: Node3D in _cargo_nodes:
		if is_instance_valid(node) and node.visible:
			n += 1
	return n


## The current unload pose (CartUnload.pose; {} when he is not unloading) – tests, screenshots.
func unload_pose() -> Dictionary:
	return _unload


## The cargo nodes (tests, screenshots).
func cargo_nodes() -> Array[Node3D]:
	return _cargo_nodes


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


# --- G8 Runde 4: work at the work place ------------------------------------------------------

func _work_config() -> NpcWorkConfig:
	if work_config == null:
		work_config = Database.config(&"npc_work_config") as NpcWorkConfig
		if work_config == null:
			work_config = NpcWorkConfig.new()
	return work_config


## EventBus.dialogue_ended: back to the work (the gravekeeper may still stand close – then the figure waits).
func _on_dialogue_ended() -> void:
	if not _in_dialogue:
		return
	_in_dialogue = false
	if is_node_ready() and is_inside_tree():
		refresh()


## Pipe smoke (NpcWorkConfig.puff_clips): when the clip's cycle passes one of its puff moments a few soft puffs leave
## the marker at the pipe bowl and drift up (one-shot burst in world space; no nodes while nobody smokes).
func _check_puffs(clip: StringName) -> void:
	var marks := _work_config().puffs(clip)
	if marks.is_empty() or _anim == null or not _anim.is_playing() or _anim.current_animation != clip or _culled:
		_puff_pos = -1.0
		return
	var length := _anim.current_animation_length
	if length <= 0.0:
		return
	var pos := _anim.current_animation_position / length
	var before := _puff_pos
	_puff_pos = pos
	if before < 0.0:
		return
	for m: float in marks:
		if (pos >= before and before < m and m <= pos) or (pos < before and (m > before or m <= pos)):
			_puff()
			return


func _puff() -> void:
	if not is_inside_tree():
		return
	var cfg := _work_config()
	if _puffs == null:
		_puffs = _make_puffs(cfg)
		add_child(_puffs)
	var marker := _model.find_child(cfg.puff_marker, true, false) as Node3D if _model != null else null
	_puffs.global_position = marker.global_position if marker != null else global_transform * cfg.puff_fallback
	_puffs.restart()


static func _make_puffs(cfg: NpcWorkConfig) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "PipeSmoke"
	p.top_level = true
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(1, cfg.puff_amount)
	p.lifetime = cfg.puff_lifetime
	p.explosiveness = 0.55
	p.direction = Vector3.UP
	p.spread = cfg.puff_spread_deg
	p.initial_velocity_min = cfg.puff_speed * 0.5
	p.initial_velocity_max = cfg.puff_speed
	p.gravity = Vector3(0.0, cfg.puff_rise, 0.0)
	p.damping_min = 0.1
	p.damping_max = 0.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, cfg.puff_color)
	fade.set_color(1, Color(cfg.puff_color, 0.0))
	p.color_ramp = fade
	var mesh := SphereMesh.new()
	mesh.radius = cfg.puff_size
	mesh.height = cfg.puff_size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# --- lookups -------------------------------------------------------------------------------

func _world() -> Node:
	if world == null:
		var node := get_parent()
		while node != null and not node.has_method(&"get_waypoint"):
			node = node.get_parent()
		world = node
	return world


func _schedule() -> NpcSchedule:
	if _runtime != null:
		return _runtime
	if schedule == null and npc_id != &"":
		schedule = Database.schedule(npc_id) as NpcSchedule
	return schedule


## A runtime schedule came or went: fresh paths, no debug hold, the cart only for a data schedule with
## one, placed from the clock at once.
func _after_schedule_change() -> void:
	_pose.clear_cache()
	_held_entry = null
	_hidden_minute = -1
	_uses_cart = _runtime == null and _schedule_uses_cart()
	if not _uses_cart and is_node_ready():
		cart.visible = false
		cart_shape.set_deferred(&"disabled", true)
		for node: Node3D in _cargo_nodes:
			if is_instance_valid(node):
				node.visible = false
		_unload = {}
		if _model != null:
			_model.position = Vector3.ZERO
		_with_cart = false
	if is_node_ready():
		refresh()


static func _flat(v: Vector3) -> Vector3:
	return NpcPose.flat(v)
