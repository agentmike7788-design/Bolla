extends Node3D
## The charcoal kiln next to the forge (docs/PHASE5_DESIGN.md §2.1 Meiler, §4.1): child "Cold"
## (stacked, unlit) or "Burning" with its thin smoke thread while the forge's background job runs
## and is not ready yet. Presentation only – reads Workshop.job_of(&"forge"), changes nothing.
## Hidden with the forge station until it is built (parent Workbench).

const STATION := &"forge"
const WORKSHOP_GROUP := &"workshop"

var burning: bool = false


func _ready() -> void:
	EventBus.workshop_job_changed.connect(_on_job_changed)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.new_game_started.connect(refresh)
	refresh()


## Burning = a job at the forge that is not ready yet.
func refresh() -> void:
	var shop := get_tree().get_first_node_in_group(WORKSHOP_GROUP) if is_inside_tree() else null
	var job: Dictionary = shop.call(&"job_of", STATION) if shop != null else {}
	burning = not job.is_empty() and not bool(job.get("ready", false))
	var cold := get_node_or_null(^"Cold") as Node3D
	var hot := get_node_or_null(^"Burning") as Node3D
	var smoke := get_node_or_null(^"Smoke") as CPUParticles3D
	if cold != null:
		cold.visible = not burning
	if hot != null:
		hot.visible = burning
	if smoke != null:
		smoke.visible = burning
		smoke.emitting = burning


func _on_job_changed(station_id: StringName, _recipe_id: StringName, _state: StringName) -> void:
	if station_id == STATION:
		refresh()


func _on_game_loaded(_slot: int) -> void:
	refresh()
