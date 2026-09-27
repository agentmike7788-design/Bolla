class_name Corpse
extends Node3D
## Visual + interactable of one corpse; state lives in CorpseRecord (CorpseManager).
## Shows ph_prop_corpse or, once shrouded, ph_prop_corpse_shrouded (swapped on corpse_updated).
## Its Interactable is only active at the dropoff or on the ground – on the table the
## MorgueTable handles the corpse, while carried the player has switched it off.

const MANAGER_GROUP := &"corpse_manager"
const PROMPT_PICK_UP := "[E] Leiche aufheben"
## Locations where this node itself can be picked up.
const PICKABLE_LOCATIONS: Array[StringName] = [CorpseRecord.LOCATION_DROPOFF, CorpseRecord.LOCATION_GROUND]

@export var plain_model: PackedScene = preload("res://assets/models/props/ph_prop_corpse.glb")
@export var shrouded_model: PackedScene = preload("res://assets/models/props/ph_prop_corpse_shrouded.glb")

var corpse_id: String = ""

@onready var interactable: Interactable = $Interactable

var _model: Node3D
var _model_shrouded: bool = false


func _ready() -> void:
	EventBus.corpse_updated.connect(_on_corpse_updated)
	refresh()


func can_interact(player: Player) -> bool:
	return get_interaction_prompt(player) == PROMPT_PICK_UP and _hands_free(player)


func get_interaction_prompt(player: Player) -> String:
	var record := _record()
	if record == null or not record.location in PICKABLE_LOCATIONS:
		return ""
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	return PROMPT_PICK_UP


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var manager := _manager()
	if manager != null:
		manager.pick_up(corpse_id, player)


## Re-reads the record: model variant and whether the own Interactable is active.
func refresh() -> void:
	var record := _record()
	var shrouded := record != null and record.shrouded
	if _model == null or shrouded != _model_shrouded:
		_set_model(shrouded)
	var active := record != null and record.location in PICKABLE_LOCATIONS
	if interactable != null and interactable.enabled != active:
		interactable.enabled = active
		interactable.set_deferred(&"monitorable", active)


func is_shrouded_visual() -> bool:
	return _model_shrouded


func _on_corpse_updated(id: String) -> void:
	if id == corpse_id and is_inside_tree():
		refresh()


func _set_model(shrouded: bool) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	var scene := shrouded_model if shrouded else plain_model
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	move_child(_model, 0)
	_model_shrouded = shrouded


func _record() -> CorpseRecord:
	var manager := _manager()
	return manager.get_record(corpse_id) if manager != null and corpse_id != "" else null


func _manager() -> CorpseManager:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CorpseManager


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)


static func _hands_free(player: Player) -> bool:
	return player != null and not _is_carrying(player) and not player.is_busy()
