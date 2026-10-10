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
## Phase 7 (docs/PHASE7_DESIGN.md §3.4, P1): the region of this Npc – shown only for schedule entries
## of its region (entry.region, "" = graveyard); hidden while the GameState flag hide_flag is set
## (Wiebke Hagedorn: hagedorn_dead).
@export var region_id: StringName = &"graveyard"
@export var hide_flag: StringName = &""
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
var lod_interval_override: float = 0.0
var _culled: bool = false
## ChatterRunner: the figure turns to its partner and talks (null = none).
var _chatter_target: Node3D
## Mood cache (NpcLife.mood is derived; asked once per game hour): [hour key, low].
var _mood_key: int = -1
var _mood_low: bool = false


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
	# Held by debug_teleport in the middle of a walk: he waits (idle) instead of walking on the spot.
	var wanted := entry.animation if _held_entry == null or entry.travel_minutes == 0 else ANIM_IDLE
	var designed := 0.0
	if is_walking():
		wanted = ANIM_PUSH if entry.with_cart else _moving_anim()
		designed = push_anim_speed if entry.with_cart else (walk_anim_speed if String(wanted).ends_with("walk") else 0.0)
	elif chatter_target() != null:
		wanted = ANIM_TALK
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
	_anim.speed_scale = ground_speed() / designed if designed > 0.0 else 1.0


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
					StringName(str(node3d.get_meta(&"hide_after", extras.get("hide_after", ""))))])


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
		node.visible = shown


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
		cargo.visible = false
		_with_cart = false
	if is_node_ready():
		refresh()


static func _flat(v: Vector3) -> Vector3:
	return NpcPose.flat(v)
