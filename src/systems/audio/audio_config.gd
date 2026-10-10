class_name AudioConfig
extends Resource
## Every tunable value of the sound (data/audio/audio_config.tres): which soundscape plays where
## and when, footstep surfaces, music rotation, world emitters, bells, voice budget, default
## volumes. Positions are region-local (RegionConfig.origin is added), x/z on the ground.

const BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"UI"]

## Cue libraries (AudioCueLibrary) and the directory of AudioAmbienceProfiles.
@export var libraries: Array[AudioCueLibrary] = []
@export var profile_dir: String = "res://data/audio/ambience"
@export var event_map_path: String = "res://data/audio/audio_events.tres"

@export_group("Time of day")
## Minute of day where each phase begins: dawn → day → dusk → night (→ dawn next morning).
@export var dawn_start: int = 300
@export var day_start: int = 450
@export var dusk_start: int = 1110
@export var night_start: int = 1260

@export_group("Ambience")
## "<region>/<phase>" → profile id (phase: dawn | day | dusk | night).
@export var outdoor_profiles: Dictionary[String, StringName] = {}
## Interior room id → profile id (rooms ignore the hour; the hut is "hut").
@export var room_profiles: Dictionary[StringName, StringName] = {}
## Areas with their own soundscape outdoors: [{region, rect: Rect2 (x, z, w, h), profile,
## phases: PackedStringArray (empty = always)}]; the first containing zone wins.
@export var zone_profiles: Array[Dictionary] = []
## Title screen profile and how long the bed crossfade takes (s).
@export var title_profile: StringName = &"title"
@export var ambience_fade: float = 2.5

@export_group("Footsteps")
## Surface → step cue.
@export var step_cues: Dictionary[StringName, StringName] = {}
## Region → surface outside every zone; room → surface.
@export var region_surfaces: Dictionary[StringName, StringName] = {}
@export var room_surfaces: Dictionary[StringName, StringName] = {}
## [{region, surface, rect: Rect2} | {region, surface, circle: Vector3 (x, z, r)} |
## {region, surface, line: PackedVector2Array, width}] – the first match wins.
@export var surface_zones: Array[Dictionary] = []
## Metres walked per footstep (gravekeeper / villagers), jumps above teleport_distance are ignored.
@export var player_step_length: float = 1.1
@export var npc_step_length: float = 0.85
@export var teleport_distance: float = 2.5
## Villagers' steps: quieter, positional, only within npc_step_range of the listener, at most
## npc_step_voices at once.
@export var npc_step_volume_db: float = -5.0
@export var npc_step_range: float = 14.0
@export var npc_step_voices: int = 3

@export_group("Music")
## Context → cue ids played in turn (contexts: title, day, night, village).
@export var music_tracks: Dictionary[StringName, PackedStringArray] = {}
## Silence between two pieces (s, random in range) and the first wait after a context change.
@export var music_pause_min: float = 45.0
@export var music_pause_max: float = 120.0
@export var music_first_delay: float = 8.0
@export var music_fade_out: float = 4.0

@export_group("World")
## Positional sources: [{region, pos: Vector3, cue (loop), hours: Vector2i (optional), volume_db
## (optional)}] and positional spot sources: [{region, pos, cue, min, max, hours (optional)}].
@export var emitters: Array[Dictionary] = []
@export var spot_emitters: Array[Dictionary] = []
## Osric's hand cart: the npc whose push_cart walk rolls this loop.
@export var cart_npc: StringName = &"carter"
@export var cart_cue: StringName = &"cart_roll"
## Church bell: struck `bell_strikes` times at these hours; positional in the village at
## bell_position, from the graveyard heard far away (non-positional, bell_far_db).
@export var bell_cue: StringName = &"church_bell"
@export var bell_hours: PackedInt32Array = [6, 12, 18]
@export var bell_strikes: int = 3
@export var bell_interval: float = 2.6
@export var bell_region: StringName = &"village"
@export var bell_position: Vector3 = Vector3(0, 12, -18)
@export var bell_far_db: float = -12.0
## Listener height above the gravekeeper's feet.
@export var listener_height: float = 1.6

@export_group("Phase 8")
## docs/PHASE8_DESIGN.md §8.3 (W-Ton) – the sounds of the living who come up. All of it is presentation.
## Npc animation → sound (Animations-Takt): {"cue": played on the beats, "beats": PackedFloat32Array (fractions of
## the clip; empty = no beat), "enter" / "leave": cue when the animation starts / ends, "npcs": PackedStringArray
## (npc_id; empty = everyone), "every": seconds at least between two plays at one Npc, "chance": 0…1 per beat,
## "volume_db", "height": metres above the Npc's feet}. Only within npc_sound_range of the listener.
@export var npc_anim_cues: Dictionary[StringName, Dictionary] = {}
@export var npc_sound_range: float = 25.0
## npc_id → loop that follows the Npc while it walks (Hanne's basket bells); at most npc_loop_voices players, all
## made once in setup (no node is created while playing).
@export var npc_walk_loops: Dictionary[StringName, StringName] = {}
@export var npc_loop_voices: int = 2
## Event → sound at its source. Key as AudioEventMap.signal_cues ("signal@<arg index>=<value>", most conditions win);
## value {"cue", "at": &"grave" (argument "arg" is a grave id) | &"npc" (the fixed "id" or argument "arg" is an
## npc_id) | &"group" (first node of group "id"), "volume_db", "height", "fallback_db" (not found → 2D at this
## level; missing = silent), "flee": true (that Npc starts the flight below)}.
@export var positional_cues: Dictionary[String, Dictionary] = {}
## The flight (after a "flee" event): {"npc", "step_cue" (instead of the ground's step), "climb_cue" (once, near one of
## the waypoints "climb_points" ≤ "climb_radius" m), "seconds" (longest)}.
@export var flight: Dictionary = {}
## Whistling: {"npc", "cue", "anims": PackedStringArray, "check": seconds between two tries, "chance", "group"
## (the system asked for "method", e.g. apprentice.morale), "min" (lowest value that whistles)}.
@export var whistle: Dictionary = {}
## Festival (Festivals.running()) → {"music": context, "profile": soundscape (missing = unchanged), "rooms":
## PackedStringArray (interior ids) or "regions": PackedStringArray (outdoors)}.
@export var fest_contexts: Dictionary[StringName, Dictionary] = {}
## Music context → Vector2(first wait and shortest rest, longest rest) in seconds; missing = music_first_delay and
## music_pause_min … music_pause_max.
@export var music_pauses: Dictionary[StringName, Vector2] = {}
## Bells at a festival: [{"fest", "minute", "cue", "strikes", "interval", "npc" (struck at that Npc when it is in the
## gravekeeper's region, else 2D at "far_db")}].
@export var fest_bells: Array[Dictionary] = []

@export_group("Voices")
@export var pool_2d: int = 12
@export var pool_3d: int = 10
@export var pool_ui: int = 4
## After a load / new game: no event sounds for this long (the state replays its signals).
@export var settle_seconds: float = 0.8

@export_group("Settings")
## Linear 0..1 per bus; saved in the user settings file (not in the save game).
@export var default_volumes: Dictionary[StringName, float] = {
	&"Master": 0.8, &"Music": 0.55, &"Ambience": 0.8, &"SFX": 0.9, &"UI": 0.7,
}
@export var settings_path: String = "user://settings.cfg"
