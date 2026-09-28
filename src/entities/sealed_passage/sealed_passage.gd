class_name SealedPassage
extends Node3D
## The walled-up door behind the ossuary shelf (docs/PHASE6_DESIGN.md §2.3, §3.4, §4.8): hidden
## until Ossuary.passage_state() is sealed (crypt passage_level) – „[E] Die vermauerte Tür ansehen"
## → Ossuary.look_at_passage (text + clue c_crypt_draft once); from grille_level one stone is an
## iron grille with a cold, faint light behind it – „[E] Durch das Gitter sehen" (text only).
## No way through: the Phase-12 hook. Models: P5's ph_int_sealed_passage / _grille (instanced as
## "Sealed" / "Grille" when present). The light "GrilleLight" (§2.3: #7FA0C8, 0.25, 2.5 m, no
## shadow, slow pulse 0.1 Hz) sits at the grille model's marker light_below.
## refresh() is visual only (building_upgraded deferred, game_loaded, room change).

const PROMPT_LOOK := "[E] Die vermauerte Tür ansehen"
const PROMPT_GRILLE := "[E] Durch das Gitter sehen"
const OSSUARY_GROUP := &"ossuary"
const SEALED_PATH := "res://assets/models/interior/ph_int_sealed_passage.glb"
const GRILLE_PATH := "res://assets/models/interior/ph_int_sealed_passage_grille.glb"
const MARKER_LIGHT := "light_below"
const LIGHT_COLOR := Color("7FA0C8")
const LIGHT_ENERGY := 0.25
const LIGHT_RANGE := 2.5
## Pulse: energy × (1 ± PULSE_DEPTH) at PULSE_HZ.
const PULSE_HZ := 0.1
const PULSE_DEPTH := 0.2
## Behind the grille (passage-local) when the model has no marker.
const LIGHT_FALLBACK := Vector3(0.0, 0.6, -0.5)

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

var light: OmniLight3D
var _sealed: Node3D
var _grille: Node3D
var _time: float = 0.0


func _ready() -> void:
	_sealed = _model("Sealed", SEALED_PATH)
	_grille = _model("Grille", GRILLE_PATH)
	light = get_node_or_null(^"GrilleLight") as OmniLight3D
	if light == null:
		light = OmniLight3D.new()
		light.name = "GrilleLight"
		add_child(light)
	light.light_color = LIGHT_COLOR
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	var marker := _grille.find_child(MARKER_LIGHT, true, false) as Node3D if _grille != null else null
	light.position = marker.position if marker != null else LIGHT_FALLBACK
	EventBus.building_upgraded.connect(_on_changed.unbind(2))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	EventBus.interior_room_changed.connect(_on_changed.unbind(1))
	refresh()


## Visibility of the walled door / the grille and its light from Ossuary.passage_state().
func refresh() -> void:
	var state := _state()
	var shown := state != Ossuary.PASSAGE_HIDDEN
	var grille := state == Ossuary.PASSAGE_GRILLE
	visible = shown
	if _sealed != null:
		_sealed.visible = shown and not grille
	if _grille != null:
		_grille.visible = grille
	if light != null:
		light.visible = grille
	set_process(grille)
	if interactable != null:
		interactable.enabled = shown
		interactable.set_deferred(&"monitorable", shown)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 1.0 / PULSE_HZ)
	if light != null:
		light.light_energy = LIGHT_ENERGY * (1.0 + PULSE_DEPTH * sin(TAU * PULSE_HZ * _time))


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and _state() != Ossuary.PASSAGE_HIDDEN


func get_interaction_prompt(_player: Player) -> String:
	match _state():
		Ossuary.PASSAGE_SEALED:
			return PROMPT_LOOK
		Ossuary.PASSAGE_GRILLE:
			return PROMPT_GRILLE
	return ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var ossuary := _ossuary()
	if ossuary != null:
		ossuary.look_at_passage()


func _state() -> StringName:
	var ossuary := _ossuary()
	return ossuary.passage_state() if ossuary != null else Ossuary.PASSAGE_HIDDEN


func _on_changed() -> void:
	if is_inside_tree():
		refresh.call_deferred()


func _model(node_name: String, path: String) -> Node3D:
	var node := get_node_or_null(NodePath(node_name)) as Node3D
	if node == null and ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate() as Node3D
		node.name = node_name
		add_child(node)
	return node


func _ossuary() -> Ossuary:
	return get_tree().get_first_node_in_group(OSSUARY_GROUP) as Ossuary if is_inside_tree() else null
