class_name AudioMusic
extends Node
## Quiet music with rests: a piece of the current context plays through once, then silence
## (config.music_pause_min … max), then the next piece (never the same twice in a row when the
## context has more). A context change fades the running piece out (music_fade_out) and waits
## music_first_delay before the new context starts. Context &"" = no music.

enum State { IDLE, WAIT, PLAY, FADE }

const SILENT_DB := -60.0
## The title screen waits only this long between pieces.
const TITLE_PAUSE := Vector2(6.0, 12.0)
const TITLE := &"title"

var audio: AudioManager
var context: StringName = &""
var state: State = State.IDLE
var current_cue: StringName = &""

var _player: AudioStreamPlayer
var _wait: float = 0.0
var _fade_speed: float = 15.0
var _last_cue: StringName = &""


func setup(owner_audio: AudioManager) -> void:
	audio = owner_audio
	_player = AudioStreamPlayer.new()
	_player.name = "Music"
	_player.bus = &"Music"
	add_child(_player)
	_player.finished.connect(_on_finished)


func set_context(ctx: StringName) -> void:
	if ctx == context:
		return
	context = ctx
	if state == State.PLAY:
		state = State.FADE
		_fade_speed = (_player.volume_db - SILENT_DB) / maxf(audio.config.music_fade_out, 0.1)
		return
	_schedule_first()


## Starts the next piece of the context at once (tests, preview).
func play_now() -> bool:
	var tracks := _tracks()
	if tracks.is_empty():
		return false
	var pick: StringName = StringName(tracks[0])
	if tracks.size() > 1:
		var choices: Array[StringName] = []
		for t: String in tracks:
			if StringName(t) != _last_cue:
				choices.append(StringName(t))
		pick = choices[randi() % choices.size()]
	var cue := audio.cue(pick)
	if cue == null:
		return false
	var stream := audio.stream_for(cue)
	if stream == null:
		return false
	_player.stream = stream
	_player.volume_db = cue.volume_db
	_player.play()
	current_cue = cue.id
	_last_cue = cue.id
	state = State.PLAY
	return true


func stop() -> void:
	_player.stop()
	state = State.IDLE
	current_cue = &""
	context = &""


func is_playing() -> bool:
	return _player.playing


func _process(delta: float) -> void:
	match state:
		State.WAIT:
			_wait -= delta
			if _wait <= 0.0 and not play_now():
				state = State.IDLE
		State.FADE:
			_player.volume_db = move_toward(_player.volume_db, SILENT_DB, _fade_speed * delta)
			if _player.volume_db <= SILENT_DB + 0.01:
				_player.stop()
				current_cue = &""
				_schedule_first()


func _schedule_first() -> void:
	if context == &"" or _tracks().is_empty():
		state = State.IDLE
		return
	state = State.WAIT
	_wait = 1.0 if context == TITLE else audio.config.music_first_delay


func _on_finished() -> void:
	if state != State.PLAY:
		return
	current_cue = &""
	state = State.WAIT
	if context == TITLE:
		_wait = randf_range(TITLE_PAUSE.x, TITLE_PAUSE.y)
	else:
		_wait = randf_range(audio.config.music_pause_min, maxf(audio.config.music_pause_min, audio.config.music_pause_max))


func _tracks() -> PackedStringArray:
	if audio == null or audio.config == null:
		return PackedStringArray()
	return audio.config.music_tracks.get(context, PackedStringArray())
