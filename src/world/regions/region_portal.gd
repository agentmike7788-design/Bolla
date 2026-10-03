class_name RegionPortal
extends Node3D
## The way to another region (docs/PHASE7_DESIGN.md §3.4, §4.1): Entities/road_exit on the graveyard
## (the milestone at the end of the coach road) and Village/Entities/road_out (the Holderbrücke).
## Before requires_flag it is scenery (no prompt). Blocked (RegionTravel.block_reason: a corpse, a
## running action, a fade) → the reason as a dimmed prompt. [E] → RegionTravel.travel to the target
## region's Spawns/<target_spawn> with the target's travel_minutes / fade_seconds (30 / 0.8 by
## default). Scene: src/entities/region_portal/region_portal.tscn.

@export var target_region: StringName
@export var target_spawn: StringName
@export var requires_flag: StringName = &"village_open"
@export var prompt: String = "[E] Nach Hollerbrück (30 Min)"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## requires_flag is set (or none is required).
func is_open() -> bool:
	return requires_flag == &"" or GameState.flag_on(requires_flag)


func can_interact(player: Player) -> bool:
	return player != null and is_open() and _target() != null and RegionTravel.block_reason(player, target_region) == ""


func get_interaction_prompt(player: Player) -> String:
	if not is_open() or _target() == null:
		return ""
	var reason := RegionTravel.block_reason(player, target_region)
	if reason == "-":
		return ""
	return reason if reason != "" else prompt


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var target := _target()
	var cfg := target.region_config()
	if cfg == null:
		cfg = RegionConfig.new()
	var minutes := cfg.travel_minutes
	var fade := cfg.fade_seconds
	RegionTravel.travel(player, target_region, target.spawn_transform(target_spawn), minutes, fade)


func _target() -> RegionRoot:
	return RegionRoot.find(get_tree(), target_region) if is_inside_tree() else null
