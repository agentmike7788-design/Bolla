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
# Phase 7 (docs/PHASE7_DESIGN.md §2.2, §3.4)
## Region of the entry: &"" = the graveyard; &"village" = Hollerbrück. An Npc only shows the
## entries of its own region (Npc.region_id).
@export var region: StringName = &""
## The entry counts only while this GameState flag equals TimeManager.day (the priest's
## consecration day: linden_consecration_day). ScheduleResolver.entry_at(…, day -1) skips it.
@export var today_flag: StringName = &""
