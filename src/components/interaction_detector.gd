class_name InteractionDetector
extends Area3D
## Picks the best Interactable around the player every physics frame.
## Child of the player: layer 0, mask 8 (Interactables), monitoring only (set in _init).
## Its CollisionShape3D (scene) is a ~1.4 m sphere slightly in front of the player.
## Ranking of get_overlapping_areas(): disabled Interactables and those whose target gives
## an empty prompt are skipped; highest priority wins, equal priorities by the lowest
## distance − facing_weight × facing, where facing is the cosine between this node's +Z
## (the player's front) and the direction to the Interactable, both flattened to XZ.
## Runs before its parent's physics step, so the player reads a fresh focus.

signal focus_changed(interactable: Interactable)

const MASK := 8
## Below this (m / squared length) directions count as undefined: the target is "in front".
const EPSILON := 0.0001

## Metres of distance a target straight ahead gains over one at the side (and one behind loses).
@export var facing_weight: float = 0.75
## Metres the current focus is favoured by, so two nearly equal targets do not flicker.
@export var focus_bias: float = 0.1

var focused: Interactable
## Passed to the targets' get_interaction_prompt(); nearest Player ancestor, may stay null.
var player: Player

## Instance id of `focused` (0 = none); survives the focused node being freed.
var _focused_id: int = 0


func _init() -> void:
	collision_layer = 0
	collision_mask = MASK
	monitoring = true
	monitorable = false
	process_physics_priority = -1


func _ready() -> void:
	if player == null:
		player = _find_player()


func _physics_process(_delta: float) -> void:
	refresh()


## Rescores now; updates `focused` and emits focus_changed if the best candidate changed.
func refresh() -> void:
	var best := best_candidate()
	var best_id := best.get_instance_id() if best != null else 0
	if best_id == _focused_id:
		return
	_focused_id = best_id
	focused = best
	focus_changed.emit(best)


## The Interactable that should have the focus right now (null if none qualifies).
func best_candidate() -> Interactable:
	if not is_inside_tree() or not monitoring:
		return null
	var best: Interactable = null
	var best_score := INF
	for area: Area3D in get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or not candidate.enabled or candidate.is_queued_for_deletion():
			continue
		if candidate.prompt_for(player) == "":
			continue
		var score := score_of(candidate)
		if candidate.get_instance_id() == _focused_id:
			score -= focus_bias
		if best == null or candidate.priority > best.priority \
				or (candidate.priority == best.priority and score < best_score):
			best = candidate
			best_score = score
	return best


## Distance/facing score of one candidate (lower is better; priority is not included).
func score_of(candidate: Node3D) -> float:
	var to := candidate.global_position - global_position
	to.y = 0.0
	var distance := to.length()
	var forward := global_basis.z
	forward.y = 0.0
	var facing := 1.0
	if distance > EPSILON and forward.length_squared() > EPSILON:
		facing = forward.normalized().dot(to / distance)
	return distance - facing_weight * facing


func _find_player() -> Player:
	var node := get_parent()
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
