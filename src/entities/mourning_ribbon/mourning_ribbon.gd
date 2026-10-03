class_name MourningRibbon
extends Node3D
## The black ribbon at the marker `ribbon` of a house (docs/PHASE7_DESIGN.md §2.9, §3.4): visible
## while Village.mourning_house(day) == house_id (derived, not saved). Presentation only; Village
## refreshes all ribbons (group mourning_ribbon) on a new day, an arrival and a burial.

const GROUP := &"mourning_ribbon"

@export var house_id: StringName


func _init() -> void:
	add_to_group(GROUP, true)


func _ready() -> void:
	refresh()


## Shows / hides the ribbon after Village.mourning_house.
func refresh() -> void:
	var village := get_tree().get_first_node_in_group(&"village") if is_inside_tree() else null
	var house: StringName = &""
	if village != null and village.has_method(&"mourning_house"):
		house = village.call(&"mourning_house", TimeManager.day)
	visible = house != &"" and house == house_id
