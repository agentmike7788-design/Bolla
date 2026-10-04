class_name AudioAmbienceProfile
extends Resource
## One soundscape (data/audio/ambience/<id>.tres): a looping bed plus "spots" – one-shots the
## AudioManager scatters at random intervals (birds, owl, a far hammer, drips). Optional room
## reverb on the SFX bus (chapel, crypt).

@export var id: StringName
## Looping bed cue (&"" = silence).
@export var bed: StringName = &""
## Added to the bed cue's own volume_db.
@export var bed_volume_db: float = 0.0
## [{cue: StringName, min: float, max: float, volume_db: float (optional), hours: Vector2i (optional,
## only between these hours, wraps over midnight)}] – seconds between two plays of that spot.
@export var spots: Array[Dictionary] = []
## Wet level of the SFX-bus reverb while this profile plays (0 = off).
@export var reverb_wet: float = 0.0
@export var reverb_room_size: float = 0.5
