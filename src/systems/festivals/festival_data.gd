class_name FestivalData
extends Resource
## A village festival (docs/PHASE8_DESIGN.md §2.7, §3.4): data/festivals/<id>.tres – fest_kathrein
## (day 54, 19:00–23:00 in the inn) and fest_lights (day 58, the evening on the graveyard).

const SHIFT_NONE := &"none"
const SHIFT_OPEN_PLUS := &"open_plus"

@export var id: StringName
## Game day (54 / 58; game day 1 = 3. Gilbhart 1834).
@export var calendar_day: int
## &"none" | &"open_plus" (Lichtgang: before p8_open_day + shift_days → on p8_open_day + shift_days, once).
@export var shift_rule: StringName = &"none"
@export var shift_days: int = 3
## fest_kathrein_day / fest_lights_day (the effective day, set by Festivals).
@export var day_flag: StringName
## Minutes of day [from, to] of the festival.
@export var window: Vector2i
@export var region: StringName
@export var music_context: StringName
## §2.7: presence_rel, dance_rel, lights_all {...} etc.
@export var effects: Dictionary = {}
