class_name Corpse
extends Node3D
## Visual + interactable of one corpse; state lives in CorpseRecord (CorpseManager).
## Shows one of the plain looks (plain_variants, picked by the record's seed – so a corpse
## keeps its look through saves) or, once shrouded, ph_prop_corpse_shrouded (swapped on
## corpse_updated).
## Its Interactable is only active at the dropoff or on the ground – on the table the
## MorgueTable handles the corpse, while carried the player has switched it off.

const MANAGER_GROUP := &"corpse_manager"
const PROMPT_PICK_UP := "[E] Leiche aufheben"
## Locations where this node itself can be picked up.
const PICKABLE_LOCATIONS: Array[StringName] = [CorpseRecord.LOCATION_DROPOFF, CorpseRecord.LOCATION_GROUND]

## Variant 0 of the plain looks; the fallback when plain_variants is empty or has a gap.
@export var plain_model: PackedScene = preload("res://assets/models/props/ph_prop_corpse.glb")
@export var shrouded_model: PackedScene = preload("res://assets/models/props/ph_prop_corpse_shrouded.glb")
## Plain looks, all with the same footprint; variant = posmod(record.seed, size).
@export var plain_variants: Array[PackedScene] = [
	preload("res://assets/models/props/ph_prop_corpse.glb"),
	preload("res://assets/models/props/ph_prop_corpse_02.glb"),
	preload("res://assets/models/props/ph_prop_corpse_03.glb"),
	preload("res://assets/models/props/ph_prop_corpse_04.glb"),
]

var corpse_id: String = ""

@onready var interactable: Interactable = $Interactable

var _model: Node3D
var _model_shrouded: bool = false
var _model_variant: int = -1


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


## Re-reads the record: model (plain look or shrouded) and whether the own Interactable is active.
func refresh() -> void:
	var record := _record()
	var shrouded := record != null and record.shrouded
	var variant := variant_for_record(record, _corpse_tables(), plain_variants.size()) if record != null else 0
	if _model == null or shrouded != _model_shrouded or (not shrouded and variant != _model_variant):
		_set_model(shrouded, variant)
	var active := record != null and record.location in PICKABLE_LOCATIONS
	if interactable != null and interactable.enabled != active:
		interactable.enabled = active
		interactable.set_deferred(&"monitorable", active)


func is_shrouded_visual() -> bool:
	return _model_shrouded


## Index of the plain look this corpse wears (also while shrouded: the look underneath).
func visual_variant() -> int:
	return _model_variant


## Look indices of plain_variants: the look matches the person (name and age).
const LOOK_FARMHAND := 0
const LOOK_OLD_WOMAN := 1
const LOOK_OLD_MAN := 2
const LOOK_MILLER := 3


## Plain look that fits the record: women (first name in tables.female_first_names) get the
## woman look, men from tables.old_age the old-man look, other men farmhand or miller by seed.
## Falls back to variant_for_seed without tables or with fewer than four looks.
static func variant_for_record(record: CorpseRecord, tables: CorpseTables, count: int) -> int:
	if record == null:
		return 0
	if tables == null or count < 4:
		return variant_for_seed(record.seed, count)
	var first_name := record.display_name.get_slice(" ", 0)
	if first_name in tables.female_first_names:
		return LOOK_OLD_WOMAN
	if record.age >= tables.old_age:
		return LOOK_OLD_MAN
	return LOOK_FARMHAND if posmod(record.seed, 2) == 0 else LOOK_MILLER


## Deterministic plain look for a record seed: posmod(seed, count), 0 without variants.
static func variant_for_seed(record_seed: int, count: int) -> int:
	return posmod(record_seed, count) if count > 0 else 0


func _on_corpse_updated(id: String) -> void:
	if id == corpse_id and is_inside_tree():
		refresh()


func _set_model(shrouded: bool, variant: int) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	var scene := shrouded_model if shrouded else _plain_scene(variant)
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	move_child(_model, 0)
	_model_shrouded = shrouded
	_model_variant = variant


func _plain_scene(variant: int) -> PackedScene:
	if variant >= 0 and variant < plain_variants.size() and plain_variants[variant] != null:
		return plain_variants[variant]
	return plain_model


func _corpse_tables() -> CorpseTables:
	var manager := _manager()
	if manager != null and manager.tables != null:
		return manager.tables
	return Database.corpse_tables() as CorpseTables


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
