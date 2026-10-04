class_name AudioVoices
extends Node
## Fixed pools of one-shot players (2D, 3D, UI): no node churn, a hard voice budget. Per cue:
## cooldown between starts and max_voices (the oldest voice of that cue is cut). When a pool is
## exhausted the voice that started first is stolen.

const META_CUE := &"audio_cue"
const META_STARTED := &"audio_started"

var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
## cue id -> Time.get_ticks_msec() of its last start.
var _last_start: Dictionary[StringName, int] = {}


func setup(count_2d: int, count_3d: int, count_ui: int) -> void:
	for i in count_2d:
		_pool_2d.append(_make_2d("Voice2D_%d" % i))
	for i in count_ui:
		_pool_ui.append(_make_2d("VoiceUI_%d" % i))
	for i in count_3d:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice3D_%d" % i
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0
		p.top_level = true
		add_child(p)
		_pool_3d.append(p)


## True when the cue may start now (cooldown passed).
func can_start(cue: AudioCue) -> bool:
	if cue.cooldown <= 0.0 or not _last_start.has(cue.id):
		return true
	return Time.get_ticks_msec() - _last_start[cue.id] >= int(cue.cooldown * 1000.0)


## Starts `stream` for `cue`; `at` = world position (3D) or null (2D). Returns the player.
func start(cue: AudioCue, stream: AudioStream, at: Variant, volume_db: float, pitch: float) -> Node:
	_limit(cue)
	_last_start[cue.id] = Time.get_ticks_msec()
	var player: Node
	if at is Vector3:
		var p3 := _take(_pool_3d) as AudioStreamPlayer3D
		p3.global_position = at
		p3.max_distance = cue.max_distance
		p3.unit_size = cue.unit_size
		p3.stream = stream
		p3.bus = cue.bus
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.play()
		player = p3
	else:
		var p2 := _take(_pool_ui if cue.bus == &"UI" else _pool_2d) as AudioStreamPlayer
		p2.stream = stream
		p2.bus = cue.bus
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.play()
		player = p2
	player.set_meta(META_CUE, cue.id)
	player.set_meta(META_STARTED, Time.get_ticks_usec())
	return player


## Voices of `cue_id` currently playing.
func playing_count(cue_id: StringName) -> int:
	var n := 0
	for p: Node in _all():
		if _is_playing(p) and p.get_meta(META_CUE, &"") == cue_id:
			n += 1
	return n


func total_playing() -> int:
	var n := 0
	for p: Node in _all():
		if _is_playing(p):
			n += 1
	return n


func stop_all() -> void:
	for p: Node in _all():
		p.call(&"stop")
	_last_start.clear()


func _limit(cue: AudioCue) -> void:
	var mine: Array[Node] = []
	for p: Node in _all():
		if _is_playing(p) and p.get_meta(META_CUE, &"") == cue.id:
			mine.append(p)
	while mine.size() >= maxi(cue.max_voices, 1):
		var oldest := mine[0]
		for p: Node in mine:
			if int(p.get_meta(META_STARTED, 0)) < int(oldest.get_meta(META_STARTED, 0)):
				oldest = p
		oldest.call(&"stop")
		mine.erase(oldest)


func _take(pool: Array) -> Node:
	var oldest: Node = pool[0]
	for p: Node in pool:
		if not _is_playing(p):
			return p
		if int(p.get_meta(META_STARTED, 0)) < int(oldest.get_meta(META_STARTED, 0)):
			oldest = p
	oldest.call(&"stop")
	return oldest


func _all() -> Array[Node]:
	var out: Array[Node] = []
	out.append_array(_pool_2d)
	out.append_array(_pool_ui)
	out.append_array(_pool_3d)
	return out


static func _is_playing(p: Node) -> bool:
	return bool(p.get(&"playing"))


func _make_2d(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	add_child(p)
	return p
