extends TestCase
## P2 (docs/PHASE3_DESIGN.md §3.4, §3.6, §14.3, §10): BuildMode – enter/exit conditions,
## cursor cell (mouse ray → ground plane, clamped to cursor_reach; keyboard fallback in front
## of the gravekeeper), selection / rotation, place / remove as timed actions, the Player hook
## suppressing [E]/[Q], the CameraRig wheel lock, BuildCursor preview material and grid.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const PLAYER_SCENE := "res://src/entities/player/player.tscn"

## Interaction target double (like test_player.gd).
class Target extends Node3D:
	var interactions: int = 0

	func can_interact(_player: Player) -> bool:
		return true

	func get_interaction_prompt(_player: Player) -> String:
		return "Benutzen"

	func interact(_player: Player) -> void:
		interactions += 1


var mode: BuildMode
var manager: DecorationManager
var player: Player
var inv: FakeInventory
var changes: Array = []


func before_each() -> void:
	changes.clear()
	EventBus.build_mode_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.build_mode_changed.disconnect(_on_changed)
	UIState.clear()


func _on_changed(active: bool) -> void:
	changes.append(active)


func _world(at: Vector3 = Vector3(1.25, 0.0, 1.25)) -> void:
	var root := Node3D.new()
	tree.root.add_child(root)
	var placed := Node3D.new()
	placed.name = "Placed"
	root.add_child(placed)
	manager = DecorationManager.new()
	manager.mask = Phase3Fixtures.build_mask()
	manager.config = Phase3Fixtures.decor_config()
	for id: StringName in Phase3Fixtures.DECOR_IDS:
		manager.decor_table[id] = Phase3Fixtures.decor(id)
	manager.section_list = Phase3Fixtures.sections()
	manager.fallback_unlocked = PackedInt32Array([1, 2])
	manager.container_path = NodePath("../Placed")
	root.add_child(manager)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old := player.get_node("Inventory")
	player.remove_child(old)
	old.free()
	inv = FakeInventory.new()
	inv.name = "Inventory"
	player.add_child(inv)
	player.position = at
	player.instant_actions = true
	root.add_child(player)
	mode = BuildMode.new()
	mode.config = Phase3Fixtures.decor_config()
	mode.player = player
	mode.decorations = manager
	root.add_child(mode)
	await tree.process_frame


# --- enter / exit ---------------------------------------------------------------------------

func test_enter_and_exit() -> void:
	await _world()
	inv.add_item(&"decor_lantern", 2)
	inv.add_item(&"decor_bench_wood", 1)
	assert_true(mode.enter())
	assert_true(mode.active)
	assert_true(player.build_mode, "player hook on")
	assert_eq(changes, [true])
	assert_eq(mode.available(), [&"decor_bench_wood", &"decor_lantern"], "sorted by id")
	assert_eq(mode.selected, &"decor_bench_wood", "first available piece selected")
	assert_true(mode.enter(), "already on")
	assert_eq(changes, [true], "no second signal")
	mode.exit()
	assert_false(mode.active)
	assert_false(player.build_mode)
	assert_eq(changes, [true, false])
	mode.toggle()
	assert_true(mode.active)
	mode.toggle()
	assert_false(mode.active)


func test_enter_conditions() -> void:
	await _world()
	player.set_in_interior(true)
	assert_false(mode.enter(), "not inside the hut")
	player.set_in_interior(false)
	player.instant_actions = false
	player.start_timed_action("Graben", 60, func() -> void: pass)
	assert_false(mode.enter(), "not while busy")
	player.cancel_timed_action()
	UIState.push_modal(&"test")
	assert_false(mode.enter(), "not with a modal open")
	UIState.pop_modal(&"test")
	var corpse := Node3D.new()
	player.attach_carried(corpse, "corpse_0001")
	assert_false(mode.enter(), "hands must be free")
	player.detach_carried().free()
	assert_true(mode.enter())
	assert_eq(changes, [true])


func test_leaves_on_modal_interior_and_load() -> void:
	await _world()
	assert_true(mode.enter())
	UIState.push_modal(&"test")
	assert_false(mode.active, "a modal ends build mode")
	UIState.pop_modal(&"test")
	assert_true(mode.enter())
	player.set_in_interior(true)
	assert_false(mode.active, "entering the hut ends it")
	player.set_in_interior(false)
	assert_true(mode.enter())
	EventBus.game_loaded.emit(1)
	assert_false(mode.active, "loading ends it")
	assert_true(mode.enter())
	EventBus.new_game_started.emit()
	assert_false(mode.active, "a new game ends it")


# --- player & camera hooks ------------------------------------------------------------------

func test_player_hook_suppresses_interaction() -> void:
	await _world()
	var target := Target.new()
	player.get_parent().add_child(target)
	var ia := Interactable.new()
	ia.name = "Interactable"
	target.add_child(ia)
	player.detector.focused = ia
	assert_eq(player._usable_focus(), ia, "focus outside build mode")
	player.set_build_mode(true)
	assert_true(player.build_mode)
	assert_null(player._usable_focus(), "no focus in build mode")
	assert_false(player._try_interact(), "[E] does nothing")
	assert_eq(target.interactions, 0)
	assert_false(player._try_drop(), "[Q] does nothing")
	player.set_build_mode(false)
	assert_true(player._try_interact(), "[E] works again")
	assert_eq(target.interactions, 1)


func test_camera_ignores_the_wheel_in_build_mode() -> void:
	var rig := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	tree.root.add_child(rig)
	await tree.process_frame
	rig.set_distance(20.0)
	var wheel := InputEventAction.new()
	wheel.action = &"camera_zoom_in"
	wheel.pressed = true
	rig._unhandled_input(wheel)
	var zoomed := rig.distance
	assert_true(zoomed < 20.0, "zooms normally")
	EventBus.build_mode_changed.emit(true)
	rig._unhandled_input(wheel)
	assert_almost(rig.distance, zoomed, 0.0001, "no zoom while building")
	EventBus.build_mode_changed.emit(false)
	rig._unhandled_input(wheel)
	assert_true(rig.distance < zoomed, "zoom back after build mode")


# --- cursor ---------------------------------------------------------------------------------

func test_pick_ground_point_and_cell() -> void:
	var mask := Phase3Fixtures.build_mask()
	var centre := Vector2(1.0, 1.0)
	# straight down onto (2.3, 1.1)
	var hit: Variant = BuildMode.pick_ground_point(Vector3(2.3, 10.0, 1.1), Vector3.DOWN, centre, 8.0)
	assert_true(hit is Vector2)
	assert_almost((hit as Vector2).x, 2.3)
	assert_almost((hit as Vector2).y, 1.1)
	assert_eq(BuildMode.pick_cell(Vector3(2.3, 10.0, 1.1), Vector3.DOWN, centre, 8.0, mask), Vector2i(4, 2))
	# 45° camera ray like the game's rig (looking toward −Y and −Z)
	var dir := Vector3(0.0, -1.0, -1.0).normalized()
	assert_eq(BuildMode.pick_cell(Vector3(1.2, 5.0, 7.0), dir, centre, 8.0, mask), Vector2i(2, 4), "hits (1.2, 2.0)")
	# clamped to the reach around the gravekeeper
	var far: Variant = BuildMode.pick_ground_point(Vector3(21.0, 3.0, 1.0), Vector3.DOWN, centre, 8.0)
	assert_almost((far as Vector2).x, 9.0, 0.0001, "clamped to 8 m")
	assert_almost((far as Vector2).y, 1.0)
	assert_null(BuildMode.pick_ground_point(Vector3(0.0, 5.0, 0.0), Vector3.UP, centre, 8.0), "ray away from the ground")
	assert_null(BuildMode.pick_cell(Vector3(0.0, 5.0, 0.0), Vector3.FORWARD, centre, 8.0, mask), "ray along the ground")


func test_fallback_cell_in_front_of_the_gravekeeper() -> void:
	var mask := Phase3Fixtures.build_mask()
	var xform := Transform3D(Basis(), Vector3(1.25, 0.0, 1.25))  # faces +Z
	assert_eq(BuildMode.fallback_cell(xform, 1.2, mask), Vector2i(2, 4))
	var turned := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.25, 0.0, 1.25))  # faces +X
	assert_eq(BuildMode.fallback_cell(turned, 1.2, mask), Vector2i(4, 2))


func test_cursor_cell_uses_the_fallback_without_mouse_motion() -> void:
	await _world(Vector3(1.25, 0.0, 1.25))
	inv.add_item(&"decor_lantern", 1)
	assert_true(mode.enter())
	assert_false(mode.mouse_active, "mouse motion resets on enter")
	assert_eq(mode.cursor_cell(), BuildMode.fallback_cell(player.global_transform, 1.2, manager.mask))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	mode._unhandled_input(motion)
	assert_true(mode.mouse_active)
	assert_eq(mode.mouse_position, Vector2(10, 10))
	# no camera in the test tree → still the fallback
	assert_eq(mode.cursor_cell(), BuildMode.fallback_cell(player.global_transform, 1.2, manager.mask))
	mode.exit()
	assert_true(mode.enter())
	assert_false(mode.mouse_active)


func test_anchor_centres_the_footprint_on_the_cursor() -> void:
	assert_eq(BuildMode.anchor_for(Vector2i(5, 5), Vector2i(3, 1), 0), Vector2i(4, 5))
	assert_eq(BuildMode.anchor_for(Vector2i(5, 5), Vector2i(3, 1), 1), Vector2i(5, 4))
	assert_eq(BuildMode.anchor_for(Vector2i(5, 5), Vector2i(2, 2), 0), Vector2i(5, 5))
	assert_eq(BuildMode.anchor_for(Vector2i(5, 5), Vector2i.ONE, 3), Vector2i(5, 5))


# --- select / rotate / place / remove -------------------------------------------------------

func test_select_rotate_and_reason() -> void:
	await _world(Vector3(1.25, 0.0, 1.25))
	inv.add_item(&"decor_grave_vase", 1)
	assert_true(mode.enter())
	assert_eq(mode.selected, &"decor_grave_vase")
	assert_eq(mode.cursor_cell(), Vector2i(2, 4))
	assert_eq(mode.cursor_reason(), &"blocked", "the fixture grave lies in front")
	player.rotation.y = PI * 0.5  # faces +X → cell (4, 2), grave ring: vases allowed
	assert_eq(mode.cursor_cell(), Vector2i(4, 2))
	assert_eq(mode.cursor_reason(), &"ok")
	mode.select(&"decor_bench_wood")
	assert_eq(mode.cursor_reason(), &"no_item")
	mode.rotate()
	assert_eq(mode.rotation_step, 1)
	for i: int in 3:
		mode.rotate()
	assert_eq(mode.rotation_step, 0, "wraps after four turns")
	var hotbar := InputEventAction.new()
	hotbar.action = &"hotbar_1"
	hotbar.pressed = true
	mode._unhandled_input(hotbar)
	assert_eq(mode.selected, &"decor_grave_vase", "[1] selects the first piece in the bar")


func test_confirm_place_and_remove_are_timed_actions() -> void:
	await _world(Vector3(1.25, 0.0, 1.25))
	player.rotation.y = PI * 0.5
	inv.add_item(&"decor_grave_vase", 1)
	var labels: Array = []
	var cb := func(label: String, _d: float) -> void: labels.append(label)
	EventBus.timed_action_started.connect(cb)
	assert_false(mode.confirm_place(), "only in build mode")
	assert_true(mode.enter())
	var before := TimeManager.total_minutes()
	assert_true(mode.confirm_place())
	assert_eq(inv.count(&"decor_grave_vase"), 0)
	var placed := manager.placement_at(Vector2i(4, 2))
	assert_not_null(placed, "placed at the cursor")
	assert_eq(TimeManager.total_minutes() - before, 5, "5 game minutes")
	assert_eq(mode.selected, &"", "nothing left to place")
	assert_eq(mode.focused_placement(), placed)
	assert_true(mode.confirm_remove())
	assert_eq(inv.count(&"decor_grave_vase"), 1, "refunded")
	assert_null(manager.placement_at(Vector2i(4, 2)))
	assert_false(mode.confirm_remove(), "nothing under the cursor")
	EventBus.timed_action_started.disconnect(cb)
	assert_eq(labels, ["Grabvase aufstellen", "Grabvase abbauen"])


func test_place_input_uses_e_and_left_click() -> void:
	await _world(Vector3(1.25, 0.0, 1.25))
	player.rotation.y = PI * 0.5
	inv.add_item(&"decor_grave_vase", 2)
	assert_true(mode.enter())
	var e := InputEventAction.new()
	e.action = &"build_place"
	e.pressed = true
	mode._unhandled_input(e)
	assert_not_null(manager.placement_at(Vector2i(4, 2)), "[E] places")
	var x := InputEventAction.new()
	x.action = &"build_remove"
	x.pressed = true
	mode._unhandled_input(x)
	assert_null(manager.placement_at(Vector2i(4, 2)), "[X] removes")
	var r := InputEventAction.new()
	r.action = &"build_rotate"
	r.pressed = true
	mode._unhandled_input(r)
	assert_eq(mode.rotation_step, 1, "[R] / wheel rotates")


func test_cursor_preview_follows_validity() -> void:
	await _world(Vector3(1.25, 0.0, 1.25))
	player.rotation.y = PI * 0.5
	inv.add_item(&"decor_grave_vase", 1)
	assert_true(mode.enter())
	assert_not_null(mode.cursor)
	assert_true(mode.cursor.visible)
	assert_true(mode.cursor.valid)
	assert_eq(mode.cursor.shown_decor, &"decor_grave_vase")
	player.rotation.y = 0.0
	mode._update_cursor()
	assert_false(mode.cursor.valid, "over the grave")
	mode.exit()
	assert_false(mode.cursor.visible)


func test_preview_material_and_grid() -> void:
	var ok := BuildCursor.preview_material(true)
	var bad := BuildCursor.preview_material(false)
	assert_eq(bad.albedo_color.to_html(false), "8c2f2b")
	assert_almost(bad.albedo_color.a, 0.6, 0.01)
	assert_almost(ok.albedo_color.a, 0.6, 0.01)
	assert_true(ok.rim_enabled)
	assert_eq(ok.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	var mask := Phase3Fixtures.build_mask()
	var lines := BuildCursor.grid_lines(Vector2i(0, 1), mask, 0.5)
	# cells within 0.5 m of (0.25, 0.75): (0,1), (1,1), (0,2) → row 0 blocked
	assert_eq(lines.size(), 3 * 8)
	assert_eq(BuildCursor.grid_lines(Vector2i(2, 3), mask, 0.1).size(), 0, "grave cell is not buildable")
	var cursor := BuildCursor.new()
	cursor.config = Phase3Fixtures.decor_config()
	tree.root.add_child(cursor)
	cursor.show_at(Phase3Fixtures.decor(&"decor_bench_wood"), Vector2i(1, 1), 1, false, mask)
	assert_eq((cursor.grid.mesh as ImmediateMesh).get_surface_count(), 1, "one surface = one draw call")
	assert_almost(cursor.preview.position.x, 0.75)
	assert_almost(cursor.preview.position.z, 1.25)
	var meshes := cursor.preview.find_children("*", "GeometryInstance3D", true, false)
	assert_true(meshes.size() > 0)
	for m: Node in meshes:
		assert_eq((m as GeometryInstance3D).material_override.albedo_color.to_html(false), "8c2f2b")
	cursor.hide_cursor()
	assert_false(cursor.visible)
