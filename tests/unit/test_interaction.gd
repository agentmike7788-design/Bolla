extends TestCase
## M5: Interactable + InteractionDetector – layers, target resolution, focus ranking by
## priority / distance / facing, disabled and empty-prompt handling, focus_changed (§3.4).

const PHYSICS_FRAMES := 3


## Target double: implements the interaction contract and records calls.
class Target extends Node3D:
	var prompt: String = "Benutzen"
	var usable: bool = true
	var interactions: int = 0
	var last_player: Player
	var prompt_players: Array = []

	func can_interact(_player: Player) -> bool:
		return usable

	func get_interaction_prompt(player: Player) -> String:
		prompt_players.append(player)
		return prompt

	func interact(player: Player) -> void:
		interactions += 1
		last_player = player


## Target double with ill-typed answers (e.g. a stub that forgot a return value).
class SloppyTarget extends Node3D:
	func can_interact(_player: Player) -> Variant:
		return null

	func get_interaction_prompt(_player: Player) -> Variant:
		return null


var focus_events: Array = []


# --- Interactable -------------------------------------------------------------------------

func test_interactable_defaults_match_contract() -> void:
	var ia := Interactable.new()
	assert_eq(ia.collision_layer, 8, "layer 4 = bit value 8")
	assert_eq(ia.collision_mask, 0)
	assert_false(ia.monitoring, "never detects anything itself")
	assert_true(ia.monitorable)
	assert_eq(ia.prompt, "Benutzen")
	assert_eq(ia.priority, 0)
	assert_true(ia.enabled)
	assert_eq(ia.target_path, ^"..")
	ia.free()


func test_get_target_defaults_to_parent() -> void:
	var target := _target(Vector3.ZERO)
	var ia := target.get_node("Interactable") as Interactable
	assert_eq(ia.get_target(), target)


func test_get_target_follows_custom_path() -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var other := Target.new()
	other.name = "Other"
	root.add_child(other)
	var ia := Interactable.new()
	root.add_child(ia)
	ia.target_path = ^"../Other"
	assert_eq(ia.get_target(), other)
	ia.target_path = ^"../Missing"
	assert_null(ia.get_target(), "unresolvable path → null, no error")
	ia.target_path = NodePath()
	assert_null(ia.get_target(), "empty path → null")


func test_get_target_without_parent_is_null() -> void:
	var ia := Interactable.new()
	assert_null(ia.get_target())
	assert_eq(ia.prompt_for(null), "", "no target → no prompt (not focusable)")
	assert_false(ia.can_interact_with(null))
	ia.interact_with(null)  # warning only
	ia.target_path = ^"/root/Somewhere"
	assert_null(ia.get_target(), "absolute path outside the tree → null, no engine error")
	ia.free()


func test_ill_typed_answers_count_as_not_focusable() -> void:
	var sloppy := SloppyTarget.new()
	tree.root.add_child(sloppy)
	var ia := _add_area(sloppy, Vector3.ZERO)
	assert_eq(ia.prompt_for(null), "")
	assert_false(ia.can_interact_with(null))


func test_helpers_delegate_to_target() -> void:
	var target := _target(Vector3.ZERO, "Grab ausheben (60 Min)")
	var ia := target.get_node("Interactable") as Interactable
	assert_eq(ia.prompt_for(null), "Grab ausheben (60 Min)")
	assert_true(ia.can_interact_with(null))
	target.usable = false
	assert_false(ia.can_interact_with(null))
	ia.interact_with(null)
	assert_eq(target.interactions, 1)


func test_helpers_fallback_for_plain_target() -> void:
	var plain := Node3D.new()
	tree.root.add_child(plain)
	var ia := Interactable.new()
	ia.prompt = "Tür öffnen"
	plain.add_child(ia)
	assert_eq(ia.prompt_for(null), "Tür öffnen", "no get_interaction_prompt → export prompt")
	assert_true(ia.can_interact_with(null), "no can_interact → usable")
	ia.interact_with(null)  # no interact(): warning only, no error


# --- InteractionDetector: setup -----------------------------------------------------------

func test_detector_defaults_match_contract() -> void:
	var det := InteractionDetector.new()
	assert_eq(det.collision_layer, 0)
	assert_eq(det.collision_mask, 8, "sees layer 4 (Interactables)")
	assert_true(det.monitoring)
	assert_false(det.monitorable)
	assert_null(det.focused)
	assert_null(det.best_candidate(), "outside the tree: nothing")
	det.free()


func test_score_prefers_close_and_in_front() -> void:
	var det := _detector()
	var probe := Node3D.new()
	tree.root.add_child(probe)
	probe.global_position = Vector3(0, 0, 2)
	assert_almost(det.score_of(probe), 2.0 - det.facing_weight, 0.0001, "ahead (+Z)")
	probe.global_position = Vector3(2, 5, 0)
	assert_almost(det.score_of(probe), 2.0, 0.0001, "side; height ignored")
	probe.global_position = Vector3(0, 0, -2)
	assert_almost(det.score_of(probe), 2.0 + det.facing_weight, 0.0001, "behind")
	probe.global_position = Vector3(0, 1, 0)
	assert_almost(det.score_of(probe), -det.facing_weight, 0.0001, "on top counts as in front")
	det.rotation.y = PI
	probe.global_position = Vector3(0, 0, -2)
	assert_almost(det.score_of(probe), 2.0 - det.facing_weight, 0.0001, "facing follows rotation")


# --- InteractionDetector: focus -----------------------------------------------------------

func test_focuses_single_target_and_signals_once() -> void:
	var det := _detector()
	var target := _target(Vector3(0, 0, 0.8))
	await _physics()
	assert_eq(det.focused, _area(target))
	assert_eq(focus_events, [_area(target)], "focus_changed exactly once")
	await _physics()
	assert_eq(focus_events.size(), 1, "no signal while nothing changes")


func test_target_leaving_range_clears_focus() -> void:
	var det := _detector()
	var target := _target(Vector3(0, 0, 0.8))
	await _physics()
	target.global_position = Vector3(0, 0, 20)
	await _physics()
	assert_null(det.focused)
	assert_eq(focus_events, [_area(target), null])


## Within the front cone priority comes first (GP-05 moved targets behind the player out of it).
func test_higher_priority_beats_distance_and_facing() -> void:
	var det := _detector()
	var near := _target(Vector3(0, 0, 0.3), "Nah", 5)
	var far := _target(Vector3(1.0, 0, 0.3), "Fern", 20)
	await _physics()
	assert_eq(det.focused, _area(far), "priority first (farther and to the side, still ahead)")
	_area(far).priority = 0
	await _physics()
	assert_eq(det.focused, _area(near))


## GP-05: the carter (NPC 30) behind the player must not take the focus from the corpse
## (20) the player faces; turning around to him gives it back.
func test_target_behind_never_beats_one_ahead() -> void:
	var det := _detector()
	var corpse := _target(Vector3(0, 0, 1.0), "Leiche aufheben", 20)
	var npc := _target(Vector3(0, 0, -1.0), "Mit Osric reden", 30)
	await _physics()
	assert_eq(det.focused, _area(corpse), "what the player faces wins")
	det.rotation.y = PI
	await _physics()
	assert_eq(det.focused, _area(npc), "turned to the NPC")


func test_targets_behind_rank_by_priority_when_nothing_is_ahead() -> void:
	var det := _detector()
	var low := _target(Vector3(0, 0, -0.4), "Niedrig", 5)
	var high := _target(Vector3(0.6, 0, -1.0), "Hoch", 30)
	await _physics()
	assert_eq(det.focused, _area(high), "only targets behind: priority, then distance")
	_area(high).priority = 5
	await _physics()
	assert_eq(det.focused, _area(low))


func test_front_cone_is_sticky_for_the_focus() -> void:
	var det := _detector()
	var side := _target(Vector3(1.0, 0, 0.05), "Seite", 5)
	await _physics()
	assert_eq(det.focused, _area(side))
	var behind := _target(Vector3(-0.2, 0, -1.2), "Hinten", 30)
	det.rotation.y = -0.1  # the focused target drifts just behind the side line (facing ≈ −0.05)
	await _physics()
	assert_eq(det.focused, _area(side), "still counts as ahead: no flip to the target behind")
	det.rotation.y = -0.5
	await _physics()
	assert_eq(det.focused, _area(behind), "clearly behind now")


func test_equal_priority_prefers_nearer() -> void:
	var det := _detector()
	_target(Vector3(0, 0, 1.2))
	var near := _target(Vector3(0, 0, 0.5))
	await _physics()
	assert_eq(det.focused, _area(near))


func test_equal_distance_prefers_facing() -> void:
	var det := _detector()
	var left := _target(Vector3(1, 0, 0))
	var right := _target(Vector3(-1, 0, 0))
	det.rotation.y = PI / 2.0  # +Z turned to +X
	await _physics()
	assert_eq(det.focused, _area(left), "the one in front (+X)")
	det.rotation.y = -PI / 2.0
	await _physics()
	assert_eq(det.focused, _area(right), "turning around switches the focus")


func test_current_focus_is_sticky_for_near_ties() -> void:
	var det := _detector()
	var first := _target(Vector3(0, 0, 1.0))
	await _physics()
	assert_eq(det.focused, _area(first))
	var second := _target(Vector3(0, 0, 0.95))
	await _physics()
	assert_eq(det.focused, _area(first), "5 cm closer is within focus_bias")
	second.global_position = Vector3(0, 0, 0.6)
	await _physics()
	assert_eq(det.focused, _area(second), "clearly closer wins")


func test_disabled_interactables_are_ignored() -> void:
	var det := _detector()
	var near := _target(Vector3(0, 0, 0.5))
	var far := _target(Vector3(0, 0, 1.2))
	await _physics()
	assert_eq(det.focused, _area(near))
	_area(near).enabled = false
	await _physics()
	assert_eq(det.focused, _area(far))
	_area(far).enabled = false
	await _physics()
	assert_null(det.focused)
	_area(near).enabled = true
	await _physics()
	assert_eq(det.focused, _area(near))
	assert_eq(focus_events, [_area(near), _area(far), null, _area(near)])


func test_empty_prompt_is_not_focusable() -> void:
	var det := _detector()
	var important := _target(Vector3(0, 0, 0.5), "", 30)
	var normal := _target(Vector3(0, 0, 1.0), "Benutzen", 0)
	await _physics()
	assert_eq(det.focused, _area(normal), "empty prompt skipped despite priority")
	normal.prompt = ""
	await _physics()
	assert_null(det.focused)
	important.prompt = "Reden"
	await _physics()
	assert_eq(det.focused, _area(important), "prompt is re-polled every frame")


func test_unusable_target_with_prompt_stays_focusable() -> void:
	var det := _detector()
	var target := _target(Vector3(0, 0, 0.6), "Hände frei nötig – [Q] ablegen")
	target.usable = false
	await _physics()
	assert_eq(det.focused, _area(target), "shown dimmed, still focused")


func test_missing_target_is_ignored() -> void:
	var det := _detector()
	var holder := Node3D.new()
	tree.root.add_child(holder)
	var ia := _add_area(holder, Vector3(0, 0, 0.6))
	ia.target_path = ^"../Nowhere"
	await _physics()
	assert_null(det.focused)


func test_plain_areas_on_layer_are_ignored() -> void:
	var det := _detector()
	var area := Area3D.new()
	area.collision_layer = 8
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	tree.root.add_child(area)
	area.global_position = Vector3(0, 0, 0.5)
	await _physics()
	assert_eq(det.get_overlapping_areas().size(), 1, "overlap is seen")
	assert_null(det.focused, "but it is no Interactable")


func test_freed_focus_signals_null() -> void:
	var det := _detector()
	var target := _target(Vector3(0, 0, 0.6))
	await _physics()
	assert_eq(det.focused, _area(target))
	target.queue_free()
	await _physics()
	assert_null(det.focused)
	assert_eq(focus_events.size(), 2)
	assert_null(focus_events[1])


func test_refresh_can_be_called_directly() -> void:
	var det := _detector()
	det.set_physics_process(false)
	var target := _target(Vector3(0, 0, 0.6))
	await _physics()
	assert_null(det.focused, "no automatic rescoring while disabled")
	det.refresh()
	assert_eq(det.focused, _area(target))
	det.refresh()
	assert_eq(focus_events.size(), 1, "second refresh without change: no signal")


func test_prompt_receives_player_ancestor() -> void:
	var player := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	tree.root.add_child(player)
	player.set_physics_process(false)
	var det := player.get_node("InteractionDetector") as InteractionDetector
	assert_eq(det.player, player, "nearest Player ancestor")
	var target := _target(Vector3(0, 0, 0.8))
	await _physics()
	assert_eq(det.focused, _area(target))
	assert_has(target.prompt_players, player)


# --- helpers ------------------------------------------------------------------------------

func _detector() -> InteractionDetector:
	var det := InteractionDetector.new()
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	shape.shape = sphere
	det.add_child(shape)
	tree.root.add_child(det)
	det.focus_changed.connect(func(ia: Interactable) -> void: focus_events.append(ia))
	return det


func _target(pos: Vector3, prompt: String = "Benutzen", priority: int = 0) -> Target:
	var target := Target.new()
	target.prompt = prompt
	tree.root.add_child(target)
	target.global_position = pos
	var ia := _add_area(target, Vector3.ZERO)
	ia.priority = priority
	return target


func _add_area(parent: Node3D, offset: Vector3) -> Interactable:
	var ia := Interactable.new()
	ia.name = "Interactable"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	shape.shape = sphere
	ia.add_child(shape)
	parent.add_child(ia)
	ia.position = offset
	return ia


func _area(target: Node) -> Interactable:
	return target.get_node("Interactable") as Interactable


func _physics(frames: int = PHYSICS_FRAMES) -> void:
	for i: int in frames:
		await tree.physics_frame
