class_name StrangerTable
extends Node3D
## Phase 9 W-Welt (docs/PHASE9_DESIGN.md §2.5.1 „wohnt im Holderkrug (Gaststube 18:00–21:00 an einem Tisch, schreibt)",
## §4.4, §4.6 D11): Brenneisen's book and glass on the inn's corner table (built by interior_build.gd from inn_layout.json
## phase9.stranger_table). Shown only while he sits there (Stranger.present(&"inn")) – the table is Osric's by day.
## Display only; refreshed every game minute (one lookup) and after loading.

const STRANGER_GROUP := &"stranger"
const REGION_INN := &"inn"


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.game_loaded.connect(_on_loaded)
	refresh()


## He sits at the table now.
func shown() -> bool:
	var stranger := get_tree().get_first_node_in_group(STRANGER_GROUP) if is_inside_tree() else null
	return stranger != null and stranger.has_method(&"present") and bool(stranger.call(&"present", REGION_INN))


func refresh() -> void:
	visible = shown()


func _on_time_tick(_day: int, _minute: int) -> void:
	refresh()


func _on_loaded(_slot: int) -> void:
	refresh()
