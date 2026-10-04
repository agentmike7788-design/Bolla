class_name AudioWorld
extends Node
## Sounds that live in the world: the listener at the gravekeeper (the camera hangs 20 m away,
## so 3D sources are heard from where he stands), footsteps by surface (his 2D, the villagers'
## positional and quieter), Osric's cart, positional loops (brook, forge) and spot sources (the
## smith's anvil), the church bell on the hour. Reads positions only – changes nothing.

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


func reset() -> void:
	_player_last = Vector3.INF
	_player_walked = 0.0
	_npc_walked.clear()
	_cart.stop()
	for i: int in _loops:
		_loops[i].stop()
	_spot_timers.clear()
	_bell_left = 0


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
		return
	listener.global_position = player.global_position + Vector3.UP * audio.config.listener_height
	if not listener.is_current():
		listener.make_current()
	if not get_tree().paused:
		_player_steps(player)
		_npc_steps(delta)
	_update_cart()
	_update_emitters(player, delta)
	_update_bell(player, delta)


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
			audio.play(step_cue(audio.surface_at_world(pos)), pos + Vector3.UP * 0.1, audio.config.npc_step_volume_db)
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
