class_name AudioWorld
extends Node
## Sounds that live in the world: the listener at the gravekeeper (the camera hangs 20 m away,
## so 3D sources are heard from where he stands), footsteps by surface (his 2D, the villagers'
## positional and quieter), Osric's cart, positional loops (brook, forge) and spot sources (the
## smith's anvil), the church bell on the hour. Reads positions only – changes nothing.
## Phase 8 (docs/PHASE8_DESIGN.md §8.3): the Npc's animations sound in step with their clips (Jakob's rake and can,
## the visitors kneeling, the robber's spade, a knock at a door), Hanne's bells follow her while she walks, the
## robber's flight runs over the gravel and the wall, events sound at their source (a candle at its grave, coins on
## the stone, alms in Veit's cup), Jakob whistles when he is in good spirits, the festivals set their music and
## soundscape (fest_context) and the hand bell rings at the lights.

## Metres beyond a loop emitter's max_distance at which it still runs (no audible start at the edge).
const EMITTER_MARGIN := 4.0

var audio: AudioManager
var listener: AudioListener3D

var _player_last: Vector3 = Vector3.INF
var _player_walked: float = 0.0
## npc instance id -> metres walked since its last step.
var _npc_walked: Dictionary[int, float] = {}
var _cart: AudioStreamPlayer3D
## emitter index -> AudioStreamPlayer3D (loops), spot emitter index -> seconds left.
var _loops: Dictionary[int, AudioStreamPlayer3D] = {}
var _spot_timers: Dictionary[int, float] = {}
var _bell_left: int = 0
var _bell_wait: float = 0.0
## Phase 8: npc instance id -> {anim, frac, last_ms, ap: WeakRef (AnimationPlayer)}.
var _npc_state: Dictionary[int, Dictionary] = {}
## Loop players that follow walking Npc (made in setup) and the Npc instance id each one follows (0 = free).
var _npc_loops: Array[AudioStreamPlayer3D] = []
var _npc_loop_owner: PackedInt64Array = []
## The running flight: {npc, until_ms, climbed, points: PackedVector3Array} (empty = none).
var _flight: Dictionary = {}
var _whistle_left: float = 0.0
## Festival bell: the rule striking, strikes left, seconds to the next; the minute seen last.
var _fest_bell: Dictionary = {}
var _fest_bell_left: int = 0
var _fest_bell_wait: float = 0.0
var _fest_minute: int = -1
var _festivals_ref: WeakRef = null


func setup(owner_audio: AudioManager) -> void:
	audio = owner_audio
	listener = AudioListener3D.new()
	listener.name = "Listener"
	add_child(listener)
	_cart = AudioStreamPlayer3D.new()
	_cart.name = "Cart"
	_cart.bus = &"SFX"
	_cart.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_cart)
	for i in maxi(audio.config.npc_loop_voices, 0):
		var p := AudioStreamPlayer3D.new()
		p.name = "NpcLoop%d" % i
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_npc_loops.append(p)
		_npc_loop_owner.append(0)


func reset() -> void:
	_player_last = Vector3.INF
	_player_walked = 0.0
	_npc_walked.clear()
	_cart.stop()
	for i: int in _loops:
		_loops[i].stop()
	_spot_timers.clear()
	_bell_left = 0
	_npc_state.clear()
	_stop_npc_loops()
	_flight = {}
	_whistle_left = 0.0
	_fest_bell = {}
	_fest_bell_left = 0
	_fest_minute = -1
	_festivals_ref = null


## Starts the hourly bell (EventBus.hour_changed).
func ring_bell(hour: int) -> void:
	if not hour in audio.config.bell_hours:
		return
	_bell_left = maxi(audio.config.bell_strikes, 1)
	_bell_wait = 0.0


func _process(delta: float) -> void:
	var player := audio.player()
	if player == null or not player.is_inside_tree():
		if listener.is_current():
			listener.clear_current()
		_cart.stop()
		_stop_loops()
		_stop_npc_loops()
		return
	listener.global_position = player.global_position + Vector3.UP * audio.config.listener_height
	if not listener.is_current():
		listener.make_current()
	if not get_tree().paused:
		_player_steps(player)
		_npc_steps(delta)
		_npc_sounds(player, delta)
	elif not _npc_loop_owner.is_empty():
		_stop_npc_loops()
	_update_cart()
	_update_emitters(player, delta)
	_update_bell(player, delta)
	_update_fest_bells(player, delta)


# --- footsteps ---------------------------------------------------------------------------

func _player_steps(player: Player) -> void:
	var pos := player.global_position
	if _player_last == Vector3.INF:
		_player_last = pos
		return
	var moved := Vector2(pos.x - _player_last.x, pos.z - _player_last.z).length()
	_player_last = pos
	if moved > audio.config.teleport_distance or player.is_busy() or not player.is_on_floor():
		return
	_player_walked += moved
	if _player_walked < audio.config.player_step_length:
		return
	_player_walked = 0.0
	audio.play(step_cue(audio.player_surface()))


func _npc_steps(delta: float) -> void:
	var lpos := listener.global_position
	var range_sq := audio.config.npc_step_range * audio.config.npc_step_range
	var voices := 0
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null or not npc.is_visible_in_tree() or not npc.is_present():
			continue
		var speed := npc.ground_speed()
		if speed <= 0.0:
			continue
		var pos := npc.global_position
		if pos.distance_squared_to(lpos) > range_sq:
			continue
		var key := npc.get_instance_id()
		var walked: float = _npc_walked.get(key, randf() * audio.config.npc_step_length) + speed * delta
		if walked >= audio.config.npc_step_length and voices < audio.config.npc_step_voices:
			walked = 0.0
			voices += 1
			var cue := flight_step_cue(npc)
			if cue == &"":
				cue = step_cue(audio.surface_at_world(pos))
			audio.play(cue, pos + Vector3.UP * 0.1, audio.config.npc_step_volume_db)
		_npc_walked[key] = walked


func step_cue(surface: StringName) -> StringName:
	return audio.config.step_cues.get(surface, audio.config.step_cues.get(AudioSurfaces.DEFAULT_SURFACE, &""))


# --- cart ----------------------------------------------------------------------------------

func _update_cart() -> void:
	var cart_npc: Npc = null
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == audio.config.cart_npc:
			cart_npc = npc
			break
	var rolling := cart_npc != null and cart_npc.is_visible_in_tree() and cart_npc.cart.visible \
			and cart_npc.ground_speed() > 0.0
	if not rolling:
		if _cart.playing:
			_cart.stop()
		return
	_cart.global_position = cart_npc.global_position + Vector3.UP * 0.4
	if _cart.playing:
		return
	var cue := audio.cue(audio.config.cart_cue)
	if cue == null:
		return
	_cart.stream = audio.stream_for(cue)
	_cart.volume_db = cue.volume_db
	_cart.max_distance = cue.max_distance
	_cart.unit_size = cue.unit_size
	_cart.play()


func cart_playing() -> bool:
	return _cart.playing


# --- emitters ----------------------------------------------------------------------------

func _update_emitters(player: Player, delta: float) -> void:
	var outside := not player.in_interior
	var hour := TimeManager.minute_of_day / 60
	var list := audio.config.emitters
	for i in list.size():
		var e := list[i]
		var on := outside and StringName(e.get("region", &"")) == player.region_id \
				and AudioAmbience.hour_in(hour, e.get("hours", Vector2i(-1, -1)))
		var p: AudioStreamPlayer3D = _loops.get(i, null)
		# G7 Runde 2: a loop beyond its range is stopped, not mixed silently (Vorbis decoding on the
		# browser's main thread) – it starts again at a random point when the listener comes close.
		if on and not in_range(i, e):
			on = false
		if not on:
			if p != null and p.playing:
				p.stop()
			continue
		if p == null:
			p = _make_loop(i, e)
			if p == null:
				continue
		if not p.playing:
			p.play(randf() * maxf(p.stream.get_length() - 0.1, 0.0))
	var spots := audio.config.spot_emitters
	for i in spots.size():
		var e := spots[i]
		if not outside or StringName(e.get("region", &"")) != player.region_id:
			continue
		var left: float = _spot_timers.get(i, randf_range(1.0, float(e.get("max", 10.0))))
		left -= delta
		if left <= 0.0:
			left = randf_range(float(e.get("min", 5.0)), float(e.get("max", 10.0)))
			if AudioAmbience.hour_in(hour, e.get("hours", Vector2i(-1, -1))):
				audio.play(StringName(e.get("cue", &"")), _world_pos(e), float(e.get("volume_db", 0.0)))
		_spot_timers[i] = left


## The listener is within the range of emitter `i` (its cue's max_distance + EMITTER_MARGIN).
func in_range(i: int, e: Dictionary) -> bool:
	var reach := 0.0
	var p: AudioStreamPlayer3D = _loops.get(i, null)
	if p != null:
		reach = p.max_distance
	else:
		var cue := audio.cue(StringName(e.get("cue", &"")))
		reach = cue.max_distance if cue != null else 0.0
	if reach <= 0.0:
		return true
	reach += EMITTER_MARGIN
	return listener.global_position.distance_squared_to(_world_pos(e)) <= reach * reach


func loops_playing() -> int:
	var n := 0
	for i: int in _loops:
		if _loops[i].playing:
			n += 1
	return n


func _make_loop(i: int, e: Dictionary) -> AudioStreamPlayer3D:
	var cue := audio.cue(StringName(e.get("cue", &"")))
	if cue == null:
		return null
	var stream := audio.stream_for(cue)
	if stream == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "Emitter%d" % i
	p.stream = stream
	p.bus = cue.bus
	p.volume_db = cue.volume_db + float(e.get("volume_db", 0.0))
	p.max_distance = cue.max_distance
	p.unit_size = cue.unit_size
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	p.global_position = _world_pos(e)
	_loops[i] = p
	return p


func _stop_loops() -> void:
	for i: int in _loops:
		if _loops[i].playing:
			_loops[i].stop()


func _world_pos(e: Dictionary) -> Vector3:
	var local: Vector3 = e.get("pos", Vector3.ZERO)
	return audio.region_origin(StringName(e.get("region", &""))) + local


# --- bell --------------------------------------------------------------------------------

func _update_bell(player: Player, delta: float) -> void:
	if _bell_left <= 0:
		return
	_bell_wait -= delta
	if _bell_wait > 0.0:
		return
	_bell_left -= 1
	_bell_wait = audio.config.bell_interval
	var cfg := audio.config
	if player.region_id == cfg.bell_region and not player.in_interior:
		audio.play(cfg.bell_cue, audio.region_origin(cfg.bell_region) + cfg.bell_position)
	else:
		audio.play(cfg.bell_cue, null, cfg.bell_far_db - (6.0 if player.in_interior else 0.0))


# --- Phase 8: the living who come up (§8.3) ------------------------------------------------

## Every visible Npc: its animation's sounds (enter / beats / leave), the walk loops, the flight, the whistling.
## Transitions far away are only noted (they sound when they happen near the listener, never on first sight).
func _npc_sounds(player: Player, delta: float) -> void:
	var cfg := audio.config
	var lpos := listener.global_position
	var range_sq := cfg.npc_sound_range * cfg.npc_sound_range
	var walkers: Array[Npc] = []
	var seen: Dictionary[int, bool] = {}
	_whistle_left -= delta
	var try_whistle := _whistle_left <= 0.0 and not cfg.whistle.is_empty()
	if try_whistle:
		_whistle_left = float(cfg.whistle.get("check", 6.0))
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc == null or not npc.is_visible_in_tree() or not npc.is_present() or not npc.region_active():
			continue
		var key := npc.get_instance_id()
		seen[key] = true
		var near := npc.global_position.distance_squared_to(lpos) <= range_sq and not player.in_interior
		_npc_anim(npc, key, near)
		if near and cfg.npc_walk_loops.has(npc.npc_id) and npc.ground_speed() > 0.0:
			walkers.append(npc)
		if not _flight.is_empty() and _is_npc(npc, StringName(_flight["npc"])):
			_update_flight(npc)
		if try_whistle and near:
			_maybe_whistle(npc)
	for key: int in _npc_state.keys():
		if not seen.has(key):
			_npc_state.erase(key)
	_update_npc_loops(walkers)


## The animation rule of `anim` for this Npc ({} = none / not for this Npc).
func anim_rule(npc_id: StringName, anim: StringName) -> Dictionary:
	var rule: Dictionary = audio.config.npc_anim_cues.get(anim, {})
	if rule.is_empty():
		return rule
	var only := PackedStringArray(rule.get("npcs", PackedStringArray()))
	if not only.is_empty() and not String(npc_id) in only:
		return {}
	return rule


## True when `beat` (fraction of the clip) lies in (prev, now] – across the wrap of a looping clip as well.
static func beat_crossed(prev: float, now: float, beat: float) -> bool:
	if now >= prev:
		return beat > prev and beat <= now
	return beat > prev or beat <= now


func _npc_anim(npc: Npc, key: int, near: bool) -> void:
	var anim := npc.current_animation()
	var st: Dictionary = _npc_state.get(key, {})
	var first := st.is_empty()
	if first:
		st = {"anim": anim, "frac": -1.0, "last_ms": -1000000, "ap": _anim_player_ref(npc)}
	var prev: float = st["frac"]
	if anim != StringName(st["anim"]):
		if near and not audio.settling():
			var old := anim_rule(npc.npc_id, StringName(st["anim"]))
			if old.has("leave"):
				_play_at_npc(npc, StringName(old["leave"]), old)
			var rule := anim_rule(npc.npc_id, anim)
			if rule.has("enter"):
				_play_at_npc(npc, StringName(rule["enter"]), rule)
		st["anim"] = anim
		prev = -1.0
	var frac := _anim_fraction(st, anim, prev)
	if not first and near and frac != prev and not audio.settling():
		var rule := anim_rule(npc.npc_id, anim)
		if rule.has("cue"):
			for b: float in PackedFloat32Array(rule.get("beats", PackedFloat32Array())):
				if beat_crossed(prev, frac, b) and _rule_ready(st, rule):
					_play_at_npc(npc, StringName(rule["cue"]), rule)
					st["last_ms"] = Time.get_ticks_msec()
	st["frac"] = frac
	_npc_state[key] = st


## Position in the running clip (0…1) when the Npc's AnimationPlayer plays `anim`; else `prev` (no beat).
func _anim_fraction(st: Dictionary, anim: StringName, prev: float) -> float:
	var ref: WeakRef = st.get("ap", null)
	var ap: AnimationPlayer = ref.get_ref() as AnimationPlayer if ref != null else null
	if ap == null or not ap.is_playing() or ap.current_animation != anim:
		return prev
	var length := ap.current_animation_length
	if length <= 0.0:
		return prev
	return clampf(ap.current_animation_position / length, 0.0, 1.0)


func _anim_player_ref(npc: Npc) -> WeakRef:
	var model := npc.get_node_or_null(^"Model")
	if model == null:
		return null
	var found := model.find_children("*", "AnimationPlayer", true, false)
	return weakref(found[0]) if not found.is_empty() else null


func _rule_ready(st: Dictionary, rule: Dictionary) -> bool:
	var every := float(rule.get("every", 0.0))
	if every > 0.0 and Time.get_ticks_msec() - int(st.get("last_ms", 0)) < int(every * 1000.0):
		return false
	var chance := float(rule.get("chance", 1.0))
	return chance >= 1.0 or randf() < chance


func _play_at_npc(npc: Npc, cue: StringName, rule: Dictionary) -> void:
	if cue == &"":
		return
	var pos := npc.global_position + Vector3.UP * float(rule.get("height", 0.6))
	audio.play(cue, pos, float(rule.get("volume_db", 0.0)))


static func _is_npc(npc: Npc, id: StringName) -> bool:
	return npc.npc_id == id or String(npc.name) == "npc_" + String(id)


## The visible Npc `id` in the gravekeeper's region (null = none).
func npc_node(id: StringName) -> Npc:
	if id == &"" or not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Npc.GROUP):
		var npc := node as Npc
		if npc != null and _is_npc(npc, id) and npc.is_visible_in_tree() and npc.region_active():
			return npc
	return null


# --- walk loops (Hanne's bells) ------------------------------------------------------------

func _update_npc_loops(walkers: Array[Npc]) -> void:
	var lpos := listener.global_position
	walkers.sort_custom(func(a: Npc, b: Npc) -> bool:
		return a.global_position.distance_squared_to(lpos) < b.global_position.distance_squared_to(lpos))
	var keep: Dictionary[int, Npc] = {}
	for npc: Npc in walkers.slice(0, _npc_loops.size()):
		keep[npc.get_instance_id()] = npc
	for i in _npc_loops.size():
		if _npc_loop_owner[i] != 0 and not keep.has(_npc_loop_owner[i]):
			_npc_loops[i].stop()
			_npc_loop_owner[i] = 0
	for key: int in keep:
		var npc := keep[key]
		var idx := _npc_loop_owner.find(key)
		if idx < 0:
			idx = _npc_loop_owner.find(0)
			if idx < 0 or not _start_npc_loop(idx, npc):
				continue
		_npc_loops[idx].global_position = npc.global_position + Vector3.UP * 1.0


func _start_npc_loop(idx: int, npc: Npc) -> bool:
	var cue := audio.cue(audio.config.npc_walk_loops.get(npc.npc_id, &""))
	var stream := audio.stream_for(cue) if cue != null and audio.enabled else null
	if stream == null:
		return false
	var p := _npc_loops[idx]
	p.stream = stream
	p.bus = cue.bus
	p.volume_db = cue.volume_db
	p.max_distance = cue.max_distance
	p.unit_size = cue.unit_size
	p.global_position = npc.global_position + Vector3.UP * 1.0
	p.play(randf() * maxf(stream.get_length() - 0.1, 0.0))
	_npc_loop_owner[idx] = npc.get_instance_id()
	return true


func _stop_npc_loops() -> void:
	for i in _npc_loops.size():
		if _npc_loops[i].playing:
			_npc_loops[i].stop()
		_npc_loop_owner[i] = 0


func npc_loops_playing() -> int:
	var n := 0
	for p: AudioStreamPlayer3D in _npc_loops:
		if p.playing:
			n += 1
	return n


# --- the flight -----------------------------------------------------------------------------

## The Npc `id` flees (robber_event fled): his steps run over the gravel, the wall once.
func start_flight(id: StringName) -> void:
	var f := audio.config.flight
	if f.is_empty() or id == &"":
		return
	var points := PackedVector3Array()
	var npc := npc_node(id)
	var world := _waypoint_world(npc)
	if world != null:
		for wp: String in PackedStringArray(f.get("climb_points", PackedStringArray())):
			if ScheduleBuilder.has_point(world, wp):
				points.append(world.call(&"get_waypoint", StringName(wp)))
	var now := Time.get_ticks_msec()
	_flight = {"npc": id, "until_ms": now + int(float(f.get("seconds", 60.0)) * 1000.0), "started_ms": now,
			"climbed": false, "points": points}


## The nearest ancestor of the Npc with get_waypoint() (its region or the world root).
static func _waypoint_world(npc: Npc) -> Node:
	var n: Node = npc.get_parent() if npc != null else null
	while n != null:
		if n.has_method(&"get_waypoint"):
			return n
		n = n.get_parent()
	return null


func flight_active() -> bool:
	return not _flight.is_empty()


## The step cue of a fleeing Npc (&"" = his ground's).
func flight_step_cue(npc: Npc) -> StringName:
	if _flight.is_empty() or not _is_npc(npc, StringName(_flight["npc"])):
		return &""
	return StringName(audio.config.flight.get("step_cue", &""))


func _update_flight(npc: Npc) -> void:
	var now := Time.get_ticks_msec()
	if now > int(_flight["until_ms"]) or (now - int(_flight["started_ms"]) > 1500 and npc.ground_speed() <= 0.0):
		_flight = {}
		return
	if bool(_flight["climbed"]):
		return
	var f := audio.config.flight
	var radius := float(f.get("climb_radius", 1.5))
	var p := npc.global_position
	for q: Vector3 in PackedVector3Array(_flight["points"]):
		if Vector2(p.x - q.x, p.z - q.z).length() <= radius:
			_flight["climbed"] = true
			_play_at_npc(npc, StringName(f.get("climb_cue", &"")), {"height": 0.8})
			return


# --- whistling ------------------------------------------------------------------------------

func _maybe_whistle(npc: Npc) -> void:
	var w := audio.config.whistle
	if npc.npc_id != StringName(w.get("npc", &"")):
		return
	if not String(npc.current_animation()) in PackedStringArray(w.get("anims", PackedStringArray())):
		return
	var system := get_tree().get_first_node_in_group(StringName(w.get("group", &"")))
	var method := StringName(w.get("method", &""))
	if system != null and method != &"" and system.has_method(method) and float(system.call(method)) < float(w.get("min", 0.0)):
		return
	if randf() < float(w.get("chance", 1.0)):
		_play_at_npc(npc, StringName(w.get("cue", &"")), {"height": 1.3})


# --- events at their source -----------------------------------------------------------------

## Plays a positional event rule (AudioConfig.positional_cues) for the signal arguments `args`.
func play_event(rule: Dictionary, args: Array) -> bool:
	var at := StringName(rule.get("at", &""))
	var arg := int(rule.get("arg", 0))
	var value := str(args[arg]) if arg >= 0 and arg < args.size() else ""
	var id := StringName(str(rule.get("id", value)))
	if bool(rule.get("flee", false)):
		start_flight(id)
	var cue := StringName(rule.get("cue", &""))
	if cue == &"":
		return false
	var pos: Variant = event_position(at, value, id)
	if pos is Vector3:
		return audio.play(cue, (pos as Vector3) + Vector3.UP * float(rule.get("height", 0.4)), float(rule.get("volume_db", 0.0)))
	if rule.has("fallback_db"):
		return audio.play(cue, null, float(rule["fallback_db"]))
	return false


## World position of an event's source (null = not in the tree / not in the gravekeeper's region).
func event_position(at: StringName, value: String, id: StringName) -> Variant:
	match at:
		&"grave":
			var plot := GraveView.plot_of(value, get_tree())
			return plot.global_position if plot != null and plot.is_visible_in_tree() else null
		&"npc":
			var npc := npc_node(id)
			return npc.global_position if npc != null else null
		&"group":
			var node := get_tree().get_first_node_in_group(id) as Node3D
			return node.global_position if node != null and node.is_visible_in_tree() else null
	return null


# --- festivals ------------------------------------------------------------------------------

## The running festival's presentation for the gravekeeper here ({} = none; AudioConfig.fest_contexts).
func fest_context(player: Player) -> Dictionary:
	var cfg := audio.config
	if cfg.fest_contexts.is_empty() or player == null:
		return {}
	var id := running_festival()
	if id == &"":
		return {}
	var rule: Dictionary = cfg.fest_contexts.get(id, {})
	if rule.is_empty():
		return {}
	if rule.has("rooms"):
		return rule if player.in_interior and String(player.interior_id) in PackedStringArray(rule["rooms"]) else {}
	if rule.has("regions"):
		return rule if not player.in_interior and String(player.region_id) in PackedStringArray(rule["regions"]) else {}
	return rule


## Festivals.running() (&"" = none or no Festivals node).
func running_festival() -> StringName:
	var f: Node = _festivals_ref.get_ref() as Node if _festivals_ref != null else null
	if f == null or not f.is_inside_tree():
		f = get_tree().get_first_node_in_group(&"festivals") if is_inside_tree() else null
		_festivals_ref = weakref(f) if f != null else null
	if f == null or not f.has_method(&"running"):
		return &""
	return StringName(str(f.call(&"running")))


func _update_fest_bells(player: Player, delta: float) -> void:
	var minute := TimeManager.minute_of_day
	if minute != _fest_minute:
		var before := _fest_minute
		_fest_minute = minute
		if before >= 0 and minute > before and not audio.settling() and not audio.config.fest_bells.is_empty():
			var fest := running_festival()
			for rule: Dictionary in audio.config.fest_bells:
				var at := int(rule.get("minute", -1))
				if fest != &"" and StringName(rule.get("fest", &"")) == fest and at > before and at <= minute:
					_fest_bell = rule
					_fest_bell_left = maxi(int(rule.get("strikes", 1)), 1)
					_fest_bell_wait = 0.0
	if _fest_bell_left <= 0 or get_tree().paused:
		return
	_fest_bell_wait -= delta
	if _fest_bell_wait > 0.0:
		return
	_fest_bell_left -= 1
	_fest_bell_wait = float(_fest_bell.get("interval", 2.0))
	var cue := StringName(_fest_bell.get("cue", &""))
	var npc := npc_node(StringName(_fest_bell.get("npc", &"")))
	if npc != null and not player.in_interior:
		audio.play(cue, npc.global_position + Vector3.UP * 1.2)
	else:
		audio.play(cue, null, float(_fest_bell.get("far_db", -12.0)))
