class_name ScheduleEntry
extends Resource
## One phase of an NPC's day. The NPC walks `path` (waypoint ids) from start_minute
## during travel_minutes, then stays at the last waypoint until the next entry.

@export var start_minute: int = 0
@export var travel_minutes: int = 0
## &"home", &"walk", &"idle", &"smoke" …
@export var activity: StringName = &"idle"
## Animation name on the NPC model (e.g. &"push_cart", &"idle", &"talk").
@export var animation: StringName = &"idle"
@export var path: PackedStringArray = []
## Dialogue available in this phase (&"" = none).
@export var dialogue_id: StringName = &""
## false = "at home" (hidden, not interactable, no collision).
@export var visible: bool = true
## true = pushes the handcart in this phase.
@export var with_cart: bool = false
