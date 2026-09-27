class_name DirtSpot
extends Node3D
## One weeds / leaves spot (docs/PHASE3_DESIGN.md §2.4, §3.4): group &"dirt_spot", Interactable
## priority 6. Grave spots are named dirt_<plot_id> and carry grave_id. State (progress) lives in
## CleanlinessManager (group &"cleanliness"); this node shows the level and starts the tending
## action (free hands, timed, cancellable) – weeding by hand, raking needs the rake.
## STUB (P3) → implemented in W1; this marker line stays for test_phase3_scaffold.

const GROUP := &"dirt_spot"
const MANAGER_GROUP := &"cleanliness"
const MODEL_DIR := "res://assets/models/environment"
const MODEL_NAME := {&"weeds": "ph_env_weeds_%d", &"leaves": "ph_env_leaves_%d"}
const ANIM := &"interact"
const LABEL_WEEDS := "Unkraut jäten"
const LABEL_LEAVES := "Laub harken"
const PROMPT := "[E] %s (%d Min)"
const PROMPT_NEEDS_RAKE := "Rechen nötig – Werkbank"
const TEXT_DONE := "Gepflegt."
## Render layer of swaying meshes (= WorldRoot.FOLIAGE_LAYER).
const FOLIAGE_LAYER := 1 << 1

@export var spot_id: String = ""
@export var section_id: StringName = &""
## &"weeds" or &"leaves".
@export var kind: StringName = &"weeds"
@export var grave_id: String = ""
@export var start_progress: float = 0.0

## Level currently shown (0 = nothing).
var shown_level: int = 0

var _model: Node3D


func _init() -> void:
	add_to_group(GROUP)


## Models ph_env_weeds_1..3 / ph_env_leaves_1..3; level 0 = nothing. A missing model file
## (assets not built yet) shows nothing.
func show_level(level: int) -> void:
	if level == shown_level and (level == 0 or _model != null):
		return
	shown_level = level
	if _model != null:
		_model.queue_free()
		remove_child(_model)
		_model = null
	if level <= 0:
		return
	var path := model_path(kind, level)
	if path == "" or not ResourceLoader.exists(path, "PackedScene"):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	_model = packed.instantiate() as Node3D
	if _model != null:
		_model.name = "Model"
		add_child(_model)
		# The weeds sway (mat_grass uses TIME): keep them out of the warm lights' cached cube
		# shadows like the tree crowns (render layer 2, see WorldRoot.FOLIAGE_LAYER / PERF-01).
		for mesh: Node in _model.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).layers = FOLIAGE_LAYER


## res:// path of the model for `level` of `spot_kind` ("" for an unknown kind).
static func model_path(spot_kind: StringName, level: int) -> String:
	if not MODEL_NAME.has(spot_kind):
		return ""
	return MODEL_DIR.path_join((MODEL_NAME[spot_kind] as String) % clampi(level, 1, 3) + ".glb")


func can_interact(player: Player) -> bool:
	var manager := _manager()
	return player != null and manager != null and not player.is_busy() and not is_instance_valid(player.carried) \
			and manager.tend_minutes(spot_id, player.inventory) > 0


## "" at level 0 (not focusable); hands full / rake missing are shown dimmed.
func get_interaction_prompt(player: Player) -> String:
	var manager := _manager()
	if manager == null or manager.level(spot_id) <= 0:
		return ""
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	var minutes := manager.tend_minutes(spot_id, player.inventory if player != null else null)
	if minutes <= 0:
		return PROMPT_NEEDS_RAKE if kind == &"leaves" else ""
	return PROMPT % [action_label(), minutes]


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var minutes := _manager().tend_minutes(spot_id, player.inventory)
	player.start_timed_action(action_label(), minutes, _finish.bind(player.inventory), true, ANIM)


## "Unkraut jäten" / "Laub harken"
func action_label() -> String:
	return LABEL_LEAVES if kind == &"leaves" else LABEL_WEEDS


func _finish(inv: Inventory) -> void:
	var manager := _manager()
	if manager != null and manager.tend(spot_id, inv):
		EventBus.notification_requested.emit(TEXT_DONE, &"info")


func _manager() -> CleanlinessManager:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as CleanlinessManager
