class_name BuildSite
extends Node3D
## STUB (P1) – Entities/site_<id> in the workyard (docs/PHASE5_DESIGN.md §2.1, §3.4, §4.1):
## visible from workshop_open while its station is not built. [E] opens the build-site panel
## (&"build_site", context {station, site, inventory}); request_build runs the build as a timed
## action (build_minutes, not cancellable) → Workshop.build. W1 (P1) fills the bodies.

const PANEL := &"build_site"
const PROMPT := "[E] Bauplatz: %s"

@export var station_id: StringName


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Panel: TimedAction build_minutes (not cancellable) → Workshop.build.
func request_build() -> void:
	pass
