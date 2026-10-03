class_name Corpse
extends Node3D
## Visual + interactable of one corpse; state lives in CorpseRecord (CorpseManager).
## Shows one of the plain looks (plain_variants, picked by the record's seed – so a corpse
## keeps its look through saves; story corpses use StoryCorpseData.look) or, once dressed,
## ph_prop_corpse_shrouded / ph_prop_corpse_gown (swapped on corpse_updated). Phase 4 (P4,
## docs/PHASE4_DESIGN.md §3.4): laid out → sprig + candle stub (no light) on the chest; the
## child DecayVisual paints the decay (tint, flies, wisps, juniper smoke) – refreshed on
## corpse_updated, hour_changed and time_skipped. Pure presentation, the record is only read.
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

## Phase 4 looks and models (P5, §8). Missing files fall back (see _plain_scene / _dress_scene).
const STORY_LOOK_PATHS: Dictionary[int, String] = {
	4: "res://assets/models/props/ph_prop_corpse_05.glb",
	5: "res://assets/models/props/ph_prop_corpse_06.glb",
}
## Plain look used while a Phase-4 look's model does not exist yet.
const STORY_LOOK_FALLBACK: Dictionary[int, int] = {4: 3, 5: 1}
const GOWN_MODEL_PATH := "res://assets/models/props/ph_prop_corpse_gown.glb"
const SPRIG_MODEL_PATH := "res://assets/models/props/ph_prop_layout_sprig.glb"
## Chest of the corpse models (they lie along local X, head towards +X, top of the chest ~0.24 m).
const SPRIG_OFFSET := Vector3(0.4, 0.24, 0.0)
const SPRIG_MARKER := "sprig"
const LAYOUT_NODE := "LayOut"

var corpse_id: String = ""

@onready var interactable: Interactable = $Interactable
@onready var decay_visual: CorpseDecayVisual = get_node_or_null(^"DecayVisual") as CorpseDecayVisual

var _model: Node3D
var _model_shrouded: bool = false
var _model_dress: StringName = &""
var _model_variant: int = -1
var _layout: Node3D
var _covered: bool = false


func _ready() -> void:
	EventBus.corpse_updated.connect(_on_corpse_updated)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.time_skipped.connect(_on_time_skipped)
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


## Re-reads the record: model (plain look, shroud or gown), the laid-out sprig, the decay
## visual and whether the own Interactable is active.
func refresh() -> void:
	var record := _record()
	var dress := dress_of(record)
	if _covered and dress == CorpseRecord.DRESS_NONE:
		dress = CorpseRecord.DRESS_SHROUD
	var variant := _look_for(record)
	if _model == null or dress != _model_dress or (dress == CorpseRecord.DRESS_NONE and variant != _model_variant):
		_set_model(dress, variant)
	_set_laid_out(record != null and record.laid_out)
	refresh_decay(record)
	var active := record != null and record.location in PICKABLE_LOCATIONS
	if interactable != null and interactable.enabled != active:
		interactable.enabled = active
		interactable.set_deferred(&"monitorable", active)


## Decay presentation from the record (stage incl. rotten, balm window, washed).
func refresh_decay(record: CorpseRecord = null) -> void:
	if record == null:
		record = _record()
	if decay_visual == null or record == null:
		return
	var economy := _economy()
	var stage := stage_of(record.freshness, economy)
	var balm := CorpsePrep.is_balm_active(record, TimeManager.total_minutes())
	decay_visual.apply(record.freshness, stage, balm, record.washed)


## Phase 7 (docs/PHASE7_DESIGN.md §2.6, §3.4): while a specimen is taken the cloth lies over the whole
## body, face and hands included (the shroud model ph_prop_corpse_shrouded); off → the record's own
## look again. Presentation only – the record is not touched, nothing about the body changes.
func set_covered(on: bool) -> void:
	if _covered == on:
		return
	_covered = on
	refresh()


func is_covered() -> bool:
	return _covered


func is_shrouded_visual() -> bool:
	return _model_shrouded


## &"" / &"shroud" / &"gown" of the model currently shown.
func dress_visual() -> StringName:
	return _model_dress


func is_laid_out_visual() -> bool:
	return _layout != null


## Dress of a record: CorpseRecord.dress, or &"shroud" for a Phase-2/3 record that is only
## `shrouded`.
static func dress_of(record: CorpseRecord) -> StringName:
	if record == null:
		return CorpseRecord.DRESS_NONE
	if record.dress != CorpseRecord.DRESS_NONE:
		return record.dress
	return CorpseRecord.DRESS_SHROUD if record.shrouded else CorpseRecord.DRESS_NONE


## CorpseRecord.stage_for plus &"rotten" below EconomyConfig.rot_threshold (§2.5).
static func stage_of(freshness: float, economy: EconomyConfig) -> StringName:
	var cfg := EconomyConfig.resolve(economy)
	var stage := CorpseRecord.stage_for(freshness, cfg)
	if stage == CorpseRecord.STAGE_DECAYING and freshness < cfg.rot_threshold:
		return CorpseRecord.STAGE_ROTTEN
	return stage


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


func _on_hour_changed(_day: int, _hour: int) -> void:
	if is_inside_tree():
		refresh_decay()


func _on_time_skipped(_from_total: int, _to_total: int) -> void:
	if is_inside_tree():
		refresh_decay()


## Look index: StoryCorpseData.look (≥ 0) of a story corpse, else variant_for_record.
func _look_for(record: CorpseRecord) -> int:
	if record == null:
		return 0
	if record.story_id != &"":
		var story := Database.story_corpse(record.story_id) as StoryCorpseData
		if story != null and story.look >= 0:
			return story.look
	return variant_for_record(record, _corpse_tables(), plain_variants.size())


func _set_model(dress: StringName, variant: int) -> void:
	if _model != null:
		remove_child(_model)
		_model.queue_free()
	var scene := _dress_scene(dress) if dress != CorpseRecord.DRESS_NONE else _plain_scene(variant)
	_model = scene.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	move_child(_model, 0)
	_model_dress = dress
	_model_shrouded = dress != CorpseRecord.DRESS_NONE
	_model_variant = variant
	if decay_visual != null:
		decay_visual.set_target(_model)
	if _layout != null:
		_place_layout()


func _plain_scene(variant: int) -> PackedScene:
	if variant >= 0 and variant < plain_variants.size() and plain_variants[variant] != null:
		return plain_variants[variant]
	if STORY_LOOK_PATHS.has(variant):
		if ResourceLoader.exists(STORY_LOOK_PATHS[variant]):
			return load(STORY_LOOK_PATHS[variant]) as PackedScene
		return _plain_scene(STORY_LOOK_FALLBACK[variant])
	return plain_model


## Gown model once P5 delivered it; until then the shroud model.
func _dress_scene(dress: StringName) -> PackedScene:
	if dress == CorpseRecord.DRESS_GOWN and ResourceLoader.exists(GOWN_MODEL_PATH):
		return load(GOWN_MODEL_PATH) as PackedScene
	return shrouded_model


## Sprig + candle stub (ph_prop_layout_sprig, or LayoutPlaceholderMesh until it exists).
func _set_laid_out(on: bool) -> void:
	if on == (_layout != null):
		return
	if not on:
		remove_child(_layout)
		_layout.queue_free()
		_layout = null
		return
	if ResourceLoader.exists(SPRIG_MODEL_PATH):
		_layout = (load(SPRIG_MODEL_PATH) as PackedScene).instantiate() as Node3D
	else:
		var mesh := MeshInstance3D.new()
		mesh.name = LayoutPlaceholderMesh.NAME
		mesh.mesh = LayoutPlaceholderMesh.build()
		mesh.material_override = LayoutPlaceholderMesh.material()
		_layout = Node3D.new()
		_layout.add_child(mesh)
	_layout.name = LAYOUT_NODE
	add_child(_layout)
	_place_layout()


## On the model's "sprig" marker if it has one, else on the chest (SPRIG_OFFSET).
func _place_layout() -> void:
	var marker := _model.find_child(SPRIG_MARKER, true, false) as Node3D if _model != null else null
	if marker != null:
		_layout.transform = global_transform.affine_inverse() * marker.global_transform if is_inside_tree() else marker.transform
	else:
		_layout.transform = Transform3D(Basis.IDENTITY, SPRIG_OFFSET)


func _corpse_tables() -> CorpseTables:
	var manager := _manager()
	if manager != null and manager.tables != null:
		return manager.tables
	return Database.corpse_tables() as CorpseTables


func _economy() -> EconomyConfig:
	var manager := _manager()
	return manager.economy if manager != null and manager.economy != null else EconomyConfig.resolve()


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
