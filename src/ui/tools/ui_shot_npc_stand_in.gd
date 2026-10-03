extends Node3D
## QA stand-in for a villager (ui_screenshot_director_phase7.gd): group npc, npc_id, region village – only
## so RemarkBubbles finds a head to put the bubble on while the village scene is not built yet.

var npc_id: StringName = &""
var region_id: StringName = &"village"


func _init() -> void:
	add_to_group(&"npc")
