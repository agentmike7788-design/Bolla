class_name AudioAmbience
extends Node
## The soundscape: two bed players crossfade (config.ambience_fade) when the profile changes;
## the profile's spots fire at random intervals around the listener; the SFX-bus reverb follows
## the profile (chapel, crypt). Driven by Audio.set_profile – no game logic here.

const SILENT_DB := -60.0
## Spots are placed this far (m) around the listener, random direction.
const SPOT_RADIUS := Vector2(6.0, 14.0)
const REVERB_BUS := &"SFX"

var audio: AudioManager
var profile_id: StringName = &""
var profile: AudioAmbienceProfile

var _beds: Array[AudioStreamPlayer] = []
## Index of the bed that fades in / plays.
var _front: int = 0
## Target volume (dB) of the front bed and the fade speed (dB per second).
var _target_db: float = SILENT_DB
var _fade_speed: float = 24.0
## spot index -> seconds until it fires.
var _spot_timers: Array[float] = []


func setup(owner_audio: AudioManager) -> void:
	audio = owner_audio
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Bed%d" % i
		p.bus = &"Ambience"
		p.volume_db = SILENT_DB
		add_child(p)
		_beds.append(p)


## Switches to `id` (&"" = silence) with a crossfade over `fade` seconds.
func set_profile(id: StringName, fade: float) -> void:
	if id == profile_id:
		return
	profile_id = id
	profile = audio.profile(id) if id != &"" else null
	var span := maxf(fade, 0.05)
	_fade_speed = (0.0 - SILENT_DB) / span
	_front = 1 - _front
	var bed := _beds[_front]
	bed.stop()
	_target_db = SILENT_DB
	_spot_timers.clear()
	_apply_reverb()
	if profile == null:
		return
	var cue: AudioCue = audio.cue(profile.bed) if profile.bed != &"" else null
	if cue != null:
		var stream := audio.stream_for(cue)
		if stream != null:
			bed.stream = stream
			bed.volume_db = SILENT_DB
			_target_db = cue.volume_db + profile.bed_volume_db
			bed.play(randf() * maxf(stream.get_length() - 0.1, 0.0))
	for spot: Dictionary in profile.spots:
		_spot_timers.append(_interval(spot) * randf_range(0.3, 1.0))


func bed_playing() -> bool:
	return _beds[_front].playing


func bed_stream() -> AudioStream:
	return _beds[_front].stream if _beds[_front].playing else null


func stop() -> void:
	for b: AudioStreamPlayer in _beds:
		b.stop()
		b.volume_db = SILENT_DB
	profile_id = &""
	profile = null
	_spot_timers.clear()
	_apply_reverb()


func _process(delta: float) -> void:
	var step := _fade_speed * delta
	for i in _beds.size():
		var b := _beds[i]
		if not b.playing:
			continue
		if i == _front:
			b.volume_db = move_toward(b.volume_db, _target_db, step)
		else:
			b.volume_db = move_toward(b.volume_db, SILENT_DB, step)
			if b.volume_db <= SILENT_DB + 0.01:
				b.stop()
	if profile == null:
		return
	var hour := TimeManager.minute_of_day / 60
	for i in _spot_timers.size():
		_spot_timers[i] -= delta
		if _spot_timers[i] > 0.0:
			continue
		var spot := profile.spots[i]
		_spot_timers[i] = _interval(spot)
		if not AudioAmbience.hour_in(hour, spot.get("hours", Vector2i(-1, -1))):
			continue
		audio.play(StringName(spot.get("cue", &"")), _spot_position(), float(spot.get("volume_db", 0.0)))


## Hours window [x, y) that wraps over midnight; (-1, -1) = always.
static func hour_in(hour: int, window: Variant) -> bool:
	if not window is Vector2i:
		return true
	var w: Vector2i = window
	if w.x < 0 or w.x == w.y:
		return true
	if w.x < w.y:
		return hour >= w.x and hour < w.y
	return hour >= w.x or hour < w.y


func _interval(spot: Dictionary) -> float:
	var lo := float(spot.get("min", 10.0))
	var hi := float(spot.get("max", lo * 2.0))
	return randf_range(lo, maxf(lo, hi))


## Around the listener in the world (3D) – inside rooms and on the title screen null (2D).
func _spot_position() -> Variant:
	var origin: Variant = audio.listener_position()
	if not origin is Vector3 or audio.is_inside():
		return null
	var ang := randf() * TAU
	var r := randf_range(SPOT_RADIUS.x, SPOT_RADIUS.y)
	return (origin as Vector3) + Vector3(cos(ang) * r, randf_range(1.0, 5.0), sin(ang) * r)


func _apply_reverb() -> void:
	var bus := AudioServer.get_bus_index(REVERB_BUS)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var reverb := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
	if reverb == null:
		return
	var wet := profile.reverb_wet if profile != null else 0.0
	reverb.wet = wet
	reverb.room_size = profile.reverb_room_size if profile != null else 0.5
	AudioServer.set_bus_effect_enabled(bus, 0, wet > 0.0)
