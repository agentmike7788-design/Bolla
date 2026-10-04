class_name AudioCue
extends Resource
## One playable sound (data/audio/cues_*.tres, written by tools/audio/build_audio.py): a set of
## variant files (one is picked at random, never the same twice in a row), the bus and the mix
## values. Streams load lazily (Audio caches them), so a missing file only warns.

@export var id: StringName
## res:// paths of the variants (.ogg).
@export var files: PackedStringArray = []
## &"Music" | &"Ambience" | &"SFX" | &"UI".
@export var bus: StringName = &"SFX"
@export var volume_db: float = 0.0
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
