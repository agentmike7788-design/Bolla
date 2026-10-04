class_name AudioManager
extends Node
## Autoload "Audio" (docs/TECHNICAL_ARCHITECTURE.md §Audio): buses, user volumes, the cue
## catalogue (data/audio/cues_*.tres) and the context that picks soundscape and music (title
## screen · region · room · time of day · zone). Modules: AudioVoices (one-shot pools),
## AudioAmbience (beds + spots), AudioMusic (pieces with rests), AudioWorld (listener, steps,
## cart, emitters, bell), AudioEvents (EventBus → cues, timed actions, UI). Presentation only:
## nothing here changes game state. Runs while the tree is paused (pause menu).
## Headless / dummy driver: everything runs, nothing is heard.

const CONFIG_PATH := "res://data/audio/audio_config.tres"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PLAYER_GROUP := &"player"
## Context poll interval (s); events (region, room) refresh at once.
const POLL := 0.25
const LOG_SIZE := 64
const MIN_DB := -80.0

var config: AudioConfig
var event_map: AudioEventMap
## Master switch (false: play() does nothing – the beds and music stop as well).
var enabled: bool = true
## Linear 0..1 per bus (AudioSettings).
var volumes: Dictionary[StringName, float] = {}
## Last played cue ids, newest last (tests, debug).
var played: Array[StringName] = []

var voices: AudioVoices
var ambience: AudioAmbience
var music: AudioMusic
var world: AudioWorld
var events: AudioEvents

var _cues: Dictionary[StringName, AudioCue] = {}
var _profiles: Dictionary[StringName, AudioAmbienceProfile] = {}
## cue id -> index of the variant played last (no repeat).
var _last_variant: Dictionary[StringName, int] = {}
var _poll_left: float = 0.0
var _settle_until_msec: int = 0
var _player_ref: WeakRef = null
var _origins: Dictionary[StringName, Vector3] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = load(CONFIG_PATH) as AudioConfig if ResourceLoader.exists(CONFIG_PATH) else null
	if config == null:
		push_warning("[Audio] %s missing – silent defaults" % CONFIG_PATH)
		config = AudioConfig.new()
	ensure_buses()
	_load_catalogue()
	voices = _add(AudioVoices.new(), "Voices") as AudioVoices
	voices.setup(config.pool_2d, config.pool_3d, config.pool_ui)
	ambience = _add(AudioAmbience.new(), "Ambience") as AudioAmbience
	ambience.setup(self)
	music = _add(AudioMusic.new(), "Music") as AudioMusic
	music.setup(self)
	world = _add(AudioWorld.new(), "World") as AudioWorld
	world.setup(self)
	events = _add(AudioEvents.new(), "Events") as AudioEvents
	events.setup(self, event_map)
	load_settings()
	EventBus.region_changed.connect(_on_place_changed.unbind(1))
	EventBus.interior_room_changed.connect(_on_place_changed.unbind(1))
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.game_loaded.connect(_on_game_reset.unbind(1))
	EventBus.new_game_started.connect(_on_game_reset)
	EventBus.world_ready.connect(_on_game_reset.unbind(1))


# --- public API --------------------------------------------------------------------------

## Plays cue `id`: `at` = world position (3D when the cue is positional or a position is given)
## or null (2D). Returns false when unknown, disabled, cooling down or without a stream.
func play(id: StringName, at: Variant = null, volume_db: float = 0.0) -> bool:
	if not enabled or id == &"":
		return false
	var c := cue(id)
	if c == null:
		return false
	if not voices.can_start(c):
		return false
	var stream := stream_for(c)
	if stream == null:
		return false
	var vol := c.volume_db + volume_db + randf_range(-c.volume_jitter_db, c.volume_jitter_db)
	var pitch := 1.0 + randf_range(-c.pitch_jitter, c.pitch_jitter)
	var pos: Variant = at if at is Vector3 else null
	voices.start(c, stream, pos, vol, maxf(pitch, 0.1))
	played.append(id)
	if played.size() > LOG_SIZE:
		played.pop_front()
	return true


## MorgueTable.sound_hook (AnatomyConfig.sound_cue) and other code hooks.
func play_hook(id: StringName) -> void:
	play(event_map.hook_aliases.get(id, id) if event_map != null else id)


func cue(id: StringName) -> AudioCue:
	return _cues.get(id, null)


func has_cue(id: StringName) -> bool:
	return _cues.has(id)


func cue_ids() -> Array[StringName]:
	return _cues.keys()


func profile(id: StringName) -> AudioAmbienceProfile:
	return _profiles.get(id, null)


func profile_ids() -> Array[StringName]:
	return _profiles.keys()


## A variant of `c` (never the one played last when there are more), loop flag applied.
func stream_for(c: AudioCue) -> AudioStream:
	if c == null or c.streams.is_empty():
		return null
	var idx := 0
	if c.streams.size() > 1:
		idx = randi() % c.streams.size()
		if idx == _last_variant.get(c.id, -1):
			idx = (idx + 1) % c.streams.size()
	_last_variant[c.id] = idx
	var s := c.streams[idx]
	if s == null:
		push_warning("[Audio] cue '%s': variant %d missing" % [c.id, idx])
		return null
	_set_loop(s, c.loop)
	return s


func set_volume(bus: StringName, linear: float, save: bool = true) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	AudioSettings.apply({bus: volumes[bus]})
	if save:
		save_settings()


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, config.default_volumes.get(bus, 1.0))


func load_settings(path: String = "") -> void:
	if path != "":
		config.settings_path = path
	volumes = AudioSettings.load_volumes(config.settings_path, config.default_volumes)
	AudioSettings.apply(volumes)


func save_settings() -> Error:
	return AudioSettings.save_volumes(config.settings_path, volumes)


## No event sounds until settle time has passed (loads replay their state as signals).
func settle(seconds: float) -> void:
	_settle_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


func settling() -> bool:
	return Time.get_ticks_msec() < _settle_until_msec


## The gravekeeper (group "player"), cached weakly.
func player() -> Player:
	var p: Player = _player_ref.get_ref() as Player if _player_ref != null else null
	if p != null and p.is_inside_tree():
		return p
	_player_ref = null
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(PLAYER_GROUP):
		var candidate := node as Player
		if candidate != null and candidate.is_inside_tree():
			_player_ref = weakref(candidate)
			return candidate
	return null


func listener_position() -> Variant:
	var p := player()
	return world.listener.global_position if p != null else null


func is_inside() -> bool:
	var p := player()
	return p != null and p.in_interior


func region_origin(region: StringName) -> Vector3:
	if not _origins.has(region):
		var rc := Database.region_config(region) as RegionConfig
		_origins[region] = rc.origin if rc != null else Vector3.ZERO
	return _origins[region]


## Ground of the gravekeeper (room floor inside, else the region's zones).
func player_surface() -> StringName:
	var p := player()
	if p == null:
		return AudioSurfaces.DEFAULT_SURFACE
	if p.in_interior:
		return AudioSurfaces.room_surface(config, p.interior_id)
	var local := p.global_position - region_origin(p.region_id)
	return AudioSurfaces.surface_at(config, p.region_id, Vector2(local.x, local.z))


## Ground at a world position (villagers): an active room there, else the gravekeeper's region.
func surface_at_world(pos: Vector3) -> StringName:
	var room := AudioSurfaces.room_at(get_tree(), pos)
	if room != null:
		return AudioSurfaces.room_surface(config, room.room_id)
	var p := player()
	var region: StringName = p.region_id if p != null else &"graveyard"
	var local := pos - region_origin(region)
	return AudioSurfaces.surface_at(config, region, Vector2(local.x, local.z))


## &"dawn" | &"day" | &"dusk" | &"night" for a minute of day.
func phase_at(minute: int) -> StringName:
	if minute >= config.night_start or minute < config.dawn_start:
		return &"night"
	if minute < config.day_start:
		return &"dawn"
	if minute < config.dusk_start:
		return &"day"
	return &"dusk"


## The soundscape for the current situation (&"" = none: no player and no title screen).
func wanted_profile() -> StringName:
	var p := player()
	if p == null:
		return config.title_profile if _on_title() else &""
	if p.in_interior:
		return config.room_profiles.get(p.interior_id, &"")
	var phase := phase_at(TimeManager.minute_of_day)
	var local := p.global_position - region_origin(p.region_id)
	var zone := AudioSurfaces.zone_profile(config, p.region_id, Vector2(local.x, local.z), phase)
	if zone != &"":
		return zone
	return config.outdoor_profiles.get("%s/%s" % [p.region_id, phase], &"")


## Music context: title | village | night | day (&"" = none).
func wanted_music() -> StringName:
	var p := player()
	if p == null:
		return &"title" if _on_title() else &""
	var phase := phase_at(TimeManager.minute_of_day)
	if phase == &"night":
		return &"night"
	if p.region_id == &"village":
		return &"village"
	return &"day"


## Re-evaluates soundscape and music now.
func refresh_context(fade: float = -1.0) -> void:
	_poll_left = POLL
	if not enabled:
		ambience.set_profile(&"", 0.3)
		music.set_context(&"")
		return
	ambience.set_profile(wanted_profile(), config.ambience_fade if fade < 0.0 else fade)
	music.set_context(wanted_music())


## Back to a clean state (tests): everything stops, the context is re-read on the next poll.
func reset() -> void:
	voices.stop_all()
	ambience.stop()
	music.stop()
	world.reset()
	events.reset()
	played.clear()
	_last_variant.clear()
	_player_ref = null
	_settle_until_msec = 0


func ensure_buses() -> void:
	for bus: StringName in AudioConfig.BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")


# --- internals ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_poll_left -= delta
	if _poll_left <= 0.0:
		refresh_context()


func _on_place_changed() -> void:
	refresh_context()


func _on_hour_changed(_day: int, hour: int) -> void:
	if not settling():
		world.ring_bell(hour)


func _on_game_reset() -> void:
	settle(config.settle_seconds)
	world.reset()
	_player_ref = null
	refresh_context(0.8)


func _on_title() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == TITLE_SCENE


func _load_catalogue() -> void:
	for lib: AudioCueLibrary in config.libraries:
		if lib == null:
			push_warning("[Audio] a cue library of %s is missing" % CONFIG_PATH)
			continue
		for c: AudioCue in lib.cues:
			if c != null and c.id != &"":
				_cues[c.id] = c
	if config.profile_dir != "" and DirAccess.dir_exists_absolute(config.profile_dir):
		for f: String in ResourceLoader.list_directory(config.profile_dir):
			if not f.ends_with(".tres"):
				continue
			var p := load(config.profile_dir.path_join(f)) as AudioAmbienceProfile
			if p != null and p.id != &"":
				_profiles[p.id] = p
	if ResourceLoader.exists(config.event_map_path):
		event_map = load(config.event_map_path) as AudioEventMap
	if event_map == null:
		event_map = AudioEventMap.new()


func _add(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node


static func _set_loop(s: AudioStream, looped: bool) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = looped
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if looped else AudioStreamWAV.LOOP_DISABLED
