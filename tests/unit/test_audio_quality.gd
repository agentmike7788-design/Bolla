extends TestCase
## G7 Runde 2 – sound quality and browser robustness: every file decoded through Godot's own playback
## (AudioStreamPlayback.mix_audio) is free of clipping, one-shots start and end silently (no click),
## loops have no jump at the wrap point, every cue plays at its target loudness (K-weighted, ±4.5 dB
## against tools/audio/analyze_audio.py), one-shots are WAV/QOA and loops Vorbis, the web output buffer
## is raised, the audio modules load nothing while playing, music and soundscape keep running while the
## tree is paused, and a loop emitter out of range is stopped.

const CLIP := 0.999
## |first| / |last| sample of a one-shot – above this is an audible click.
const EDGE := 0.02
## Jump at a loop's wrap point against the 99.9th percentile of its sample steps.
const SEAM_RATIO := 6.0
const LOUDNESS_TOLERANCE := 4.5
## Seconds decoded per file for peak and loudness (beds are stationary; long music is skipped for loudness).
const WINDOW := 6.0
const AUDIO_DIR := "res://src/systems/audio"
## Modules that run while sounds play – they must never load a resource.
const RUNTIME_MODULES: PackedStringArray = ["audio_voices.gd", "audio_ambience.gd", "audio_music.gd",
		"audio_world.gd", "audio_events.gd", "audio_surfaces.gd"]
const PLAYER_SCENE := "res://src/entities/player/player.tscn"


func before_each() -> void:
	Audio.reset()
	Audio.enabled = true


func after_each() -> void:
	tree.paused = false
	Audio.reset()


static func _decode(stream: AudioStream, seconds: float, from: float = 0.0) -> PackedVector2Array:
	var pb := stream.instantiate_playback()
	pb.start(from)
	var rate := AudioServer.get_mix_rate()
	return pb.mix_audio(1.0, int(seconds * rate))


static func _mono(buf: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for i: int in buf.size():
		out[i] = (buf[i].x + buf[i].y) * 0.5
	return out


## BS.1770 K-weighting (high shelf + high pass) for `rate`, as pyloudnorm builds it.
static func _k_weight(x: PackedFloat32Array, rate: float) -> PackedFloat32Array:
	var y := x
	for stage: int in 2:
		var b := [0.0, 0.0, 0.0]
		var a := [1.0, 0.0, 0.0]
		if stage == 0:
			var amp := pow(10.0, 4.0 / 40.0)
			var w0 := TAU * 1500.0 / rate
			var alpha := sin(w0) / (2.0 * (1.0 / sqrt(2.0)))
			var c := cos(w0)
			var a0 := (amp + 1.0) - (amp - 1.0) * c + 2.0 * sqrt(amp) * alpha
			b = [amp * ((amp + 1.0) + (amp - 1.0) * c + 2.0 * sqrt(amp) * alpha) / a0,
					-2.0 * amp * ((amp - 1.0) + (amp + 1.0) * c) / a0,
					amp * ((amp + 1.0) + (amp - 1.0) * c - 2.0 * sqrt(amp) * alpha) / a0]
			a = [1.0, 2.0 * ((amp - 1.0) - (amp + 1.0) * c) / a0, ((amp + 1.0) - (amp - 1.0) * c - 2.0 * sqrt(amp) * alpha) / a0]
		else:
			var w0 := TAU * 38.0 / rate
			var alpha := sin(w0) / (2.0 * 0.5)
			var c := cos(w0)
			var a0 := 1.0 + alpha
			b = [(1.0 + c) * 0.5 / a0, -(1.0 + c) / a0, (1.0 + c) * 0.5 / a0]
			a = [1.0, -2.0 * c / a0, (1.0 - alpha) / a0]
		var out := PackedFloat32Array()
		out.resize(y.size())
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var b0: float = b[0]
		var b1: float = b[1]
		var b2: float = b[2]
		var a1: float = a[1]
		var a2: float = a[2]
		for i: int in y.size():
			var v := y[i]
			var r := b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = v
			y2 = y1
			y1 = r
			out[i] = r
		y = out
	return y


## Loudness (LUFS): mean square over the whole buffer (long form) or the loudest 400 ms window.
static func _loudness(x: PackedFloat32Array, rate: float, long_form: bool) -> float:
	var k := _k_weight(x, rate)
	var n := int(0.4 * rate)
	if long_form:
		var sum := 0.0
		for v: float in k:
			sum += v * v
		return -0.691 + 10.0 * log(maxf(sum / maxf(k.size(), 1.0), 1e-12)) / log(10.0)
	if k.size() < n:
		k.resize(n)
	var acc := 0.0
	for i: int in n:
		acc += k[i] * k[i]
	var best := acc
	var hop := int(0.01 * rate)
	var i0 := 0
	while i0 + n + hop <= k.size():
		for j: int in hop:
			acc += k[i0 + n + j] * k[i0 + n + j] - k[i0 + j] * k[i0 + j]
		i0 += hop
		best = maxf(best, acc)
	return -0.691 + 10.0 * log(maxf(best / n, 1e-12)) / log(10.0)


static func _long_form(c: AudioCue) -> bool:
	return c.loop or c.bus == &"Music"


func test_formats_wav_for_one_shots_vorbis_for_loops() -> void:
	for id: StringName in Audio.cue_ids():
		var c := Audio.cue(id)
		for s: AudioStream in c.streams:
			if _long_form(c):
				assert_true(s is AudioStreamOggVorbis, "%s: loop / music stays Vorbis" % id)
			else:
				assert_true(s is AudioStreamWAV, "%s: one-shot is WAV" % id)
				if s is AudioStreamWAV:
					assert_eq((s as AudioStreamWAV).format, AudioStreamWAV.FORMAT_QOA, "%s: imported as QOA" % id)


func test_no_clipping_and_no_edge_clicks() -> void:
	var checked := 0
	for id: StringName in Audio.cue_ids():
		var c := Audio.cue(id)
		for s: AudioStream in c.streams:
			var x := _mono(_decode(s, minf(s.get_length(), WINDOW)))
			var peak := 0.0
			for v: float in x:
				peak = maxf(peak, absf(v))
			assert_true(peak < CLIP, "%s: no clipping (peak %.3f)" % [s.resource_path.get_file(), peak])
			if not _long_form(c):
				assert_true(absf(x[0]) < EDGE, "%s starts silently (%.3f)" % [s.resource_path.get_file(), x[0]])
				var tail := _mono(_decode(s, 0.05, maxf(s.get_length() - 0.05, 0.0)))
				var last := 0.0
				for v: float in tail.slice(maxi(tail.size() - 40, 0)):
					last = maxf(last, absf(v))
				assert_true(last < EDGE, "%s ends silently (%.3f)" % [s.resource_path.get_file(), last])
			checked += 1
	assert_true(checked >= 150, "every file decoded (%d)" % checked)


func test_loops_have_no_jump_at_the_seam() -> void:
	for id: StringName in Audio.cue_ids():
		var c := Audio.cue(id)
		if not c.loop:
			continue
		for s: AudioStream in c.streams:
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			var len := s.get_length()
			var x := _mono(_decode(s, 1.0, len - 0.5))     # 0.5 s before the end, across the wrap
			var steps := PackedFloat32Array()
			for i: int in x.size() - 1:
				steps.append(absf(x[i + 1] - x[i]))
			var sorted := steps.duplicate()
			sorted.sort()
			var usual := maxf(sorted[int(sorted.size() * 0.999)], 1e-6)
			var wrap := int(0.5 * AudioServer.get_mix_rate())
			var jump := 0.0
			for i: int in range(maxi(wrap - 3, 0), mini(wrap + 3, steps.size())):
				jump = maxf(jump, steps[i])
			assert_true(jump <= usual * SEAM_RATIO, "%s: no click at the loop point (%.4f vs %.4f)" % [s.resource_path.get_file(), jump, usual])


func test_every_cue_plays_at_its_target_loudness() -> void:
	var rate := AudioServer.get_mix_rate()
	for id: StringName in Audio.cue_ids():
		var c := Audio.cue(id)
		assert_true(c.target_lufs < -10.0, "%s: levelled (target %.1f)" % [id, c.target_lufs])
		if c.bus == &"Music":
			continue          # rests and gating: checked by tools/audio/analyze_audio.py
		var energy := 0.0
		for s: AudioStream in c.streams:
			var x := _mono(_decode(s, minf(s.get_length(), WINDOW)))
			energy += pow(10.0, _loudness(x, rate, _long_form(c)) / 10.0)
		var file := 10.0 * log(energy / c.streams.size()) / log(10.0)
		var game := file + c.volume_db
		assert_true(absf(game - c.target_lufs) <= LOUDNESS_TOLERANCE,
				"%s plays at %.1f LUFS (target %.1f)" % [id, game, c.target_lufs])


func test_steps_vary() -> void:
	for surface: StringName in Audio.config.step_cues:
		var c := Audio.cue(Audio.config.step_cues[surface])
		assert_true(c.streams.size() >= 6, "%s: at least 6 variants" % c.id)
		assert_true(c.pitch_jitter >= 0.08 and c.volume_jitter_db >= 2.0, "%s: pitch and level vary" % c.id)


func test_web_output_buffer_raised() -> void:
	# ScriptProcessor mixes on the browser's main thread: 150 ms → 8192 frames (≈ 186 ms at 44.1 kHz)
	# bridge a frame hitch instead of dropping out (G7 Runde 2).
	assert_true(int(ProjectSettings.get_setting("audio/driver/output_latency.web", 0)) >= 100, "output_latency.web")
	assert_eq(str(ProjectSettings.get_setting("audio/driver/driver.web", "")), "ScriptProcessor")


func test_runtime_modules_load_nothing() -> void:
	# Every stream is a real dependency of the cue libraries (loaded with the autoload); playing must
	# never hit the disk (a first play stuttered in the browser).
	for f: String in RUNTIME_MODULES:
		var text := FileAccess.get_file_as_string(AUDIO_DIR.path_join(f))
		assert_true(text != "", f)
		for word: String in ["load(", "ResourceLoader.", "preload("]:
			assert_false(text.contains(word), "%s contains %s" % [f, word])
	for id: StringName in Audio.cue_ids():
		for s: AudioStream in Audio.cue(id).streams:
			assert_not_null(s, "%s: stream loaded with the catalogue" % id)


func test_music_and_soundscape_run_on_while_paused() -> void:
	Audio.ambience.set_profile(&"graveyard_day", 0.05)
	Audio.music.context = &"day"
	assert_true(Audio.music.play_now(), "a day piece starts")
	await wait_frames(3)
	tree.paused = true
	await wait_frames(5)
	assert_true(Audio.ambience.bed_playing(), "bed plays on under the pause menu")
	assert_true(Audio.music.is_playing(), "music plays on under the pause menu")
	assert_eq(Audio.process_mode, Node.PROCESS_MODE_ALWAYS)
	tree.paused = false


func test_loop_emitter_out_of_range_is_stopped() -> void:
	var player := await add_scene(PLAYER_SCENE) as Player
	TimeManager.set_time(TimeManager.day, 600)
	player.global_position = Vector3(-24, 0, 397)
	player.set_region(&"village")
	await wait_frames(2)
	var near := Audio.world.loops_playing()
	assert_true(near >= 1, "brook runs near the gravekeeper (%d)" % near)
	player.global_position = Vector3(60, 0, 460)
	await wait_frames(2)
	assert_true(Audio.world.loops_playing() < near, "far away the loops stop (%d → %d)" % [near, Audio.world.loops_playing()])
	player.queue_free()
