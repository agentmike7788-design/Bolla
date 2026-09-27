class_name NoticeBoard
extends Node3D
## Cemetery notice board at the gate (docs/PHASE3_DESIGN.md §4.1, W-Welt): model
## ph_prop_notice_board ("Model", in the scene) and a Label3D ("Label", added in _ready) on its
## marker label_board, showing the cemetery rating (CemeteryScore, group cemetery_score) and the
## village reputation (Reputation, group reputation). Refreshes on cemetery_quality_changed,
## reputation_changed, world_ready, game_loaded and new_game_started.
## Presentation only: not saved, no interaction.
## STUB (W-Welt) → implemented in W2; this marker line stays for test_phase3_scaffold.

const MARKER := "label_board"
const TITLE := "Friedhof Hollerbrück"
const TEXT := "%s\n„%s“\nRuf: %s"
## Label look (painted ink on wood, like the signpost).
const FONT_SIZE := 44
const PIXEL_SIZE := 0.0021
const INK := Color("#2a1f18")
## Lift off the board surface against z-fighting (m).
const SURFACE_OFFSET := 0.012

var label: Label3D


func _ready() -> void:
	label = get_node_or_null(^"Label") as Label3D
	if label == null:
		label = _make_label()
	EventBus.cemetery_quality_changed.connect(_on_changed.unbind(2))
	EventBus.reputation_changed.connect(_on_changed.unbind(4))
	EventBus.world_ready.connect(_on_changed.unbind(1))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	# Reputation sets the start value on new_game_started without reputation_changed (its
	# Systems node connected first, so the value is already set here).
	EventBus.new_game_started.connect(refresh)
	refresh()


## Rewrites the label from the current rating and reputation.
func refresh() -> void:
	if label != null:
		label.text = board_text(_rating(), _reputation_tier())


## "Friedhof Hollerbrück\n„Gepflegt“\nRuf: Geachtet"
static func board_text(rating: StringName, reputation_tier: StringName) -> String:
	return TEXT % [TITLE, CemeteryRating.label(rating), ReputationRules.label(reputation_tier)]


func _make_label() -> Label3D:
	var l := Label3D.new()
	l.name = "Label"
	l.font_size = FONT_SIZE
	l.pixel_size = PIXEL_SIZE
	l.modulate = INK
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.line_spacing = -4.0
	var marker := find_child(MARKER, true, false) as Node3D
	var at := Transform3D.IDENTITY
	if marker != null:
		at = _relative(marker)
	else:
		push_warning("[NoticeBoard] model has no %s marker" % MARKER)
		at.origin = Vector3(0, 1.25, 0.05)
	l.transform = at * Transform3D(Basis.IDENTITY, Vector3(0, 0, SURFACE_OFFSET))
	add_child(l)
	return l


func _relative(node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _rating() -> StringName:
	var score := _first(&"cemetery_score")
	if score != null and score.has_method(&"rating"):
		return score.call(&"rating")
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"rating"):
		return graveyard.call(&"rating")
	return CemeteryRating.NEGLECTED


func _reputation_tier() -> StringName:
	var rep := _first(&"reputation")
	if rep != null and rep.has_method(&"tier"):
		return rep.call(&"tier")
	return ReputationRules.tier(GameState.get_stat(&"reputation"), null)


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


func _on_changed() -> void:
	refresh()
