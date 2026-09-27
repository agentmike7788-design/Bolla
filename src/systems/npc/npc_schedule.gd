class_name NpcSchedule
extends Resource
## Daily routine of one NPC (data/npc/<npc_id>_schedule.tres).

@export var npc_id: StringName
@export var display_name: String = ""
@export var entries: Array[ScheduleEntry] = []
