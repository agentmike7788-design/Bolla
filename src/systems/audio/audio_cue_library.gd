class_name AudioCueLibrary
extends Resource
## A list of AudioCues (data/audio/cues_<library_id>.tres) – generated with the sounds by
## tools/audio/build_audio.py; edit the catalog there, not this file.

@export var library_id: StringName
@export var cues: Array[AudioCue] = []
