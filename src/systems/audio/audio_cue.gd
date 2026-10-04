class_name AudioCue
extends Resource
## One playable sound (data/audio/cues_*.tres, written by tools/audio/build_audio.py): a set of
## variant streams (one is picked at random, never the same twice in a row), the bus and the mix
## values. Streams are real resource dependencies, so an export carries them.

@export var id: StringName
## The variants (one-shots .wav – imported as QOA –, loops and music .ogg).
@export var streams: Array[AudioStream] = []
## &"Music" | &"Ambience" | &"SFX" | &"UI".
@export var bus: StringName = &"SFX"
## Set by build_audio.py so that the cue plays at target_lufs (measured loudness of its files).
@export var volume_db: float = 0.0
## Intended loudness in the game (LUFS, file + volume_db, before the user's sliders; G7 Runde 2):
## integrated for loops / music, max. momentary (400 ms) for one-shots. 0 = not levelled.
@export var target_lufs: float = 0.0
## ± random spread per play.
@export var volume_jitter_db: float = 0.0
## ± random pitch-scale spread per play (0.05 = ±5 %).
@export var pitch_jitter: float = 0.0
## Loops (beds, emitters, music is played through without loop).
@export var loop: bool = false
## Placed in the world (AudioStreamPlayer3D) when played with a position.
@export var positional: bool = false
## 3D: inaudible beyond this (m); unit_size = distance of full volume.
@export var max_distance: float = 24.0
@export var unit_size: float = 4.0
## Minimum seconds between two starts of this cue (UI spam, notification bursts).
@export var cooldown: float = 0.0
## Simultaneous voices of this cue; the oldest is cut when exceeded.
@export var max_voices: int = 3
