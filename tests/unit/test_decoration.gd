extends TestCase
## P2 (docs/PHASE3_DESIGN.md §2.3, §3.4, §10): DecorationManager – place / remove with full
## refund, limits, section caps, gravel floor(n/4), dirt suppression, ghost bonus, save/load
## re-creates the nodes; PlacedDecor (placeholder model, collider, lights); GrassClearMask.
## World-free: fixtures (mask 12 × 8, decor, sections) and a FakeInventory.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


## Inventory that never has room (remove → refused).
class FullInventory extends FakeInventory:
	func can_add(_id: StringName, _amount: int) -> bool:
		return false


## CorpseManager double: records only, no time signals.
class FakeCorpses extends CorpseManager:
	var list: Array[CorpseRecord] = []

	func _ready() -> void:
		pass

	func records() -> Array[CorpseRecord]:
		return list


var manager: DecorationManager
var container: Node3D
var inv: FakeInventory
var events: Array = []


func before_each() -> void:
	events.clear()
	EventBus.decor_changed.connect(_on_decor_changed)
	manager = _manager()
	inv = FakeInventory.new()


func after_each() -> void:
	EventBus.decor_changed.disconnect(_on_decor_changed)
	inv.free()


func _on_decor_changed(uid: String, decor_id: StringName, placed: bool) -> void:
	events.append([uid, decor_id, placed])


func _manager(parent: Node = null) -> DecorationManager:
	var root := Node3D.new()
	root.name = "World%d" % randi()
	(parent if parent != null else tree.root).add_child(root)
	container = Node3D.new()
	container.name = "Placed"
	root.add_child(container)
	var m := DecorationManager.new()
	m.name = "Decorations"
	m.mask = Phase3Fixtures.build_mask()
	m.config = Phase3Fixtures.decor_config().duplicate()
	for id: StringName in Phase3Fixtures.DECOR_IDS:
		m.decor_table[id] = Phase3Fixtures.decor(id)
	m.section_list = Phase3Fixtures.sections()
	m.fallback_unlocked = PackedInt32Array([1, 2])
	m.container_path = NodePath("../Placed")
	root.add_child(m)
	return m


# --- place / remove -------------------------------------------------------------------------

func test_place_takes_one_item_and_creates_the_node() -> void:
	inv.add_item(&"decor_bench_wood", 2)
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), &"ok")
	var uid := manager.place(&"decor_bench_wood", Vector2i(1, 1), 0, inv)
	assert_eq(uid, "d_1")
	assert_eq(inv.count(&"decor_bench_wood"), 1)
	assert_eq(events, [["d_1", &"decor_bench_wood", true]])
	assert_eq(manager.placements().size(), 1)
	for c: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		assert_eq(manager.placement_at(c).uid, uid, str(c))
	assert_null(manager.placement_at(Vector2i(4, 1)))
	assert_eq(container.get_child_count(), 1)
	var node := container.get_child(0) as PlacedDecor
	assert_eq([node.uid, node.decor_id], [uid, &"decor_bench_wood"])
	assert_almost(node.position.x, 1.25, 0.0001, "footprint centre x")
	assert_almost(node.position.z, 0.75, 0.0001, "footprint centre z")
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), &"occupied")
	assert_eq(manager.place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), "", "refused")
	assert_eq(inv.count(&"decor_bench_wood"), 1, "nothing taken when refused")


func test_no_item() -> void:
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), &"no_item")
	assert_eq(manager.place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), "")
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0), &"ok", "without inventory: position only")
	assert_eq(manager.can_place(&"nope", Vector2i(1, 1), 0, inv), &"blocked", "unknown decor")
	manager.free_build = true
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), &"ok", "debug build free")
	assert_ne(manager.place(&"decor_bench_wood", Vector2i(1, 1), 0, inv), "")
	assert_eq(inv.count(&"decor_bench_wood"), 0)


func test_remove_refunds_the_piece() -> void:
	inv.add_item(&"decor_flowerbed", 1)
	var uid := manager.place(&"decor_flowerbed", Vector2i(6, 1), 0, inv)
	assert_ne(uid, "")
	assert_eq(inv.count(&"decor_flowerbed"), 0)
	var node := manager.node_of(uid)
	assert_true(manager.remove(uid, inv))
	assert_eq(inv.count(&"decor_flowerbed"), 1, "full refund")
	assert_eq(manager.placements().size(), 0)
	assert_null(manager.placement_at(Vector2i(7, 2)))
	assert_eq(events.back(), [uid, &"decor_flowerbed", false])
	assert_true(not is_instance_valid(node) or node.is_queued_for_deletion(), "node freed")
	assert_false(manager.remove(uid, inv), "already gone")
	assert_eq(manager.can_place(&"decor_flowerbed", Vector2i(6, 1), 0, inv), &"ok", "cells free again")


func test_remove_with_full_inventory_is_refused() -> void:
	inv.add_item(&"decor_lantern", 1)
	var uid := manager.place(&"decor_lantern", Vector2i(5, 2), 0, inv)
	var full := FullInventory.new()
	var notes: Array = []
	var cb := func(text: String, _kind: StringName) -> void: notes.append(text)
	EventBus.notification_requested.connect(cb)
	assert_false(manager.remove(uid, full))
	EventBus.notification_requested.disconnect(cb)
	assert_eq(notes, ["Kein Platz im Inventar"])
	assert_not_null(manager.get_placement(uid), "still standing")
	full.free()


func test_limits() -> void:
	inv.add_item(&"decor_lantern", 7)
	var cells := [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(0, 6), Vector2i(5, 1)]
	for i: int in 6:
		assert_ne(manager.place(&"decor_lantern", cells[i], 0, inv), "", "lantern %d" % i)
	assert_eq(manager.can_place(&"decor_lantern", cells[6], 0, inv), &"limit", "place_max 6")
	assert_eq(manager.can_place(&"decor_grave_vase", cells[6], 0), &"ok", "other kinds unaffected")
	manager.config.max_placed = 7
	assert_ne(manager.place(&"decor_grave_vase", cells[6], 0, null), "")
	assert_eq(manager.can_place(&"decor_path_gravel", Vector2i(5, 3), 0), &"limit", "max_placed over all decor")


func test_limit_before_position_and_after_item() -> void:
	manager.config.max_placed = 0
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(0, 0), 0, inv), &"no_item")
	inv.add_item(&"decor_bench_wood", 1)
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(0, 0), 0, inv), &"limit")


func test_locked_sections_follow_the_unlocked_indices() -> void:
	manager.fallback_unlocked = PackedInt32Array([1])
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(7, 1), 0), &"locked_section")
	manager.fallback_unlocked = PackedInt32Array([1, 2])
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(7, 1), 0), &"ok")


# --- score ----------------------------------------------------------------------------------

func test_contribution_formula() -> void:
	var gravel := Phase3Fixtures.decor(&"decor_path_gravel")
	assert_eq([DecorationManager.contribution(gravel, 3), DecorationManager.contribution(gravel, 4),
			DecorationManager.contribution(gravel, 7), DecorationManager.contribution(gravel, 8)], [0, 1, 1, 2], "floor(n/4)")
	assert_eq(DecorationManager.contribution(gravel, 40), 6, "counted_max 24 plates")
	var bench := Phase3Fixtures.decor(&"decor_bench_wood")
	assert_eq(DecorationManager.contribution(bench, 5), 12, "counted_max 4 × 3")
	assert_eq(DecorationManager.contribution(Phase3Fixtures.decor(&"decor_bench_stone"), 2), 10)
	assert_eq(DecorationManager.contribution(bench, 0), 0)
	assert_eq(DecorationManager.contribution(null, 3), 0)


func test_gravel_counts_floor_n_over_4() -> void:
	var cells: Array[Vector2i] = []
	for z: int in range(1, 7):
		cells.append(Vector2i(0, z))
	for z: int in range(1, 3):
		cells.append(Vector2i(5, z))
	for i: int in 7:
		assert_ne(manager.place(&"decor_path_gravel", cells[i], 0, null), "")
	assert_eq(manager.decor_score(), 1, "7 plates → 1")
	manager.place(&"decor_path_gravel", cells[7], 0, null)
	assert_eq(manager.decor_score(), 2, "8 plates → 2")


func test_section_caps() -> void:
	# east (order 2, cap 9): 4 wooden benches = 12 raw → 9
	for spot: Vector2i in [Vector2i(6, 1), Vector2i(9, 1), Vector2i(6, 2), Vector2i(9, 2)]:
		assert_ne(manager.place(&"decor_bench_wood", spot, 0, null), "", str(spot))
	# yard (order 1, cap 12): 2 lanterns = 6
	manager.place(&"decor_lantern", Vector2i(0, 1), 0, null)
	manager.place(&"decor_lantern", Vector2i(0, 2), 0, null)
	var by := manager.score_by_section()
	assert_eq(by[2], {"raw": 12, "capped": 9, "cap": 9})
	assert_eq(by[1], {"raw": 6, "capped": 6, "cap": 12})
	assert_eq(by[3], {"raw": 0, "capped": 0, "cap": 9}, "every section listed")
	assert_eq(manager.decor_score(), 15)


# --- hooks for other systems ------------------------------------------------------------------

func test_suppresses_dirt_at() -> void:
	assert_ne(manager.place(&"decor_path_gravel", Vector2i(0, 1), 0, null), "")
	assert_ne(manager.place(&"decor_flowerbed", Vector2i(6, 1), 0, null), "")
	assert_ne(manager.place(&"decor_bench_wood", Vector2i(1, 1), 0, null), "")
	assert_true(manager.suppresses_dirt_at(Vector2(0.25, 0.75)), "gravel")
	assert_true(manager.suppresses_dirt_at(Vector2(3.9, 1.4)), "flower bed (2 × 2)")
	assert_false(manager.suppresses_dirt_at(Vector2(1.25, 0.75)), "bench")
	assert_false(manager.suppresses_dirt_at(Vector2(4.0, 2.0)), "nothing")


func test_ghost_bonus_at() -> void:
	var grave := Vector2(1.5, 2.0)  # centre of the fixture grave
	assert_eq(manager.ghost_bonus_at(grave), 0)
	assert_ne(manager.place(&"decor_grave_vase", Vector2i(1, 2), 0, null), "")  # centre (0.75, 1.25), ~1.06 m
	assert_eq(manager.ghost_bonus_at(grave), 1)
	assert_ne(manager.place(&"decor_grave_vase", Vector2i(4, 2), 0, null), "")  # centre (2.25, 1.25)
	assert_eq(manager.ghost_bonus_at(grave), 1, "+1 per kind")
	assert_ne(manager.place(&"decor_lantern", Vector2i(4, 5), 0, null), "")  # centre (2.25, 2.75)
	assert_eq(manager.ghost_bonus_at(grave), 2)
	assert_ne(manager.place(&"decor_flowerbed", Vector2i(6, 2), 0, null), "")  # centre (3.5, 1.5)
	assert_eq(manager.ghost_bonus_at(Vector2(2.6, 1.5)), 2, "three kinds in reach – at most 2")
	assert_eq(manager.ghost_bonus_at(Vector2(30.0, 30.0)), 0, "out of every radius")
	assert_ne(manager.place(&"decor_bench_wood", Vector2i(9, 6), 0, null), "")  # centre (5.25, 3.25)
	assert_eq(manager.ghost_bonus_at(Vector2(5.25, 3.9)), 0, "benches give no bonus")
	# lantern 3.0 m, vase 1.8 m
	var far := Vector2(2.25, 2.75) + Vector2(2.9, 0.0)
	assert_eq(manager.ghost_bonus_at(far), 1, "only the lantern reaches")


func test_player_and_corpse_block_the_footprint() -> void:
	var p := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	p.position = Vector3(1.25, 0.0, 0.75)
	tree.root.add_child(p)
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 1), 0, null, p), &"player")
	assert_eq(manager.can_place(&"decor_path_gravel", Vector2i(2, 1), 0, null, p), &"ok", "gravel is walkable")
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 6), 0, null, p), &"ok", "far away")
	var corpses := FakeCorpses.new()
	tree.root.add_child(corpses)
	var rec := CorpseRecord.new()
	rec.id = "corpse_0001"
	rec.location = CorpseRecord.LOCATION_GROUND
	rec.position = Vector3(1.25, 0.0, 3.25)
	corpses.list.append(rec)
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 6), 0, null, p), &"corpse")
	rec.location = CorpseRecord.LOCATION_TABLE
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(1, 6), 0, null, p), &"ok", "only corpses on the ground")


func test_standing_obstacles_block() -> void:
	var obstacle := ClearableObstacle.new()
	obstacle.obstacle_id = "obs_test"
	obstacle.footprint = Rect2(0.0, 0.5, 1.0, 1.0)
	tree.root.add_child(obstacle)
	assert_eq(manager.blockers().size(), 1)
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(0, 1), 0), &"obstacle")
	assert_eq(manager.can_place(&"decor_bench_wood", Vector2i(2, 1), 0), &"ok")


# --- save / load ------------------------------------------------------------------------------

func test_save_load_recreates_the_nodes() -> void:
	inv.add_item(&"decor_bench_stone", 1)
	var a := manager.place(&"decor_bench_stone", Vector2i(0, 1), 1, inv)
	var b := manager.place(&"decor_path_gravel", Vector2i(3, 7), 0, null)
	var c := manager.place(&"decor_lantern", Vector2i(5, 1), 0, null)
	manager.remove(b, null)
	var state := manager.save_state()
	assert_eq(state.next_uid, 4)
	assert_eq(state.placements, [
		{"uid": a, "decor_id": &"decor_bench_stone", "cell": Vector2i(0, 1), "rot": 1},
		{"uid": c, "decor_id": &"decor_lantern", "cell": Vector2i(5, 1), "rot": 0},
	])
	var json: Dictionary = JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(state))))
	var other := _manager()
	var other_container := container
	assert_eq(other_container.get_child_count(), 0, "the world's _ready creates none")
	other.load_state(json)
	assert_eq(other.save_state(), state, "roundtrip identical")
	assert_eq(other_container.get_child_count(), 2, "nodes re-created")
	assert_eq(other.placement_at(Vector2i(0, 3)).uid, a, "rotated footprint restored")
	assert_eq(other.place(&"decor_grave_vase", Vector2i(5, 5), 0, null), "d_4", "uid counter continues")
	other.load_state({})
	assert_eq(other.placements().size(), 0)
	assert_eq(other.save_state(), {"next_uid": 1, "placements": []})
	await tree.process_frame
	assert_eq(other_container.get_child_count(), 0, "old nodes freed")


func test_load_drops_bad_entries() -> void:
	manager.load_state({"next_uid": 2, "placements": [
		{"uid": "d_1", "decor_id": &"decor_grave_vase", "cell": [1, 1], "rot": 0.0},
		{"uid": "d_5", "decor_id": &"decor_unknown", "cell": Vector2i(2, 2), "rot": 0},
		{"uid": "d_6", "decor_id": &"decor_grave_vase", "cell": Vector2i(1, 1), "rot": 0},
		"garbage",
	]})
	assert_eq(manager.placements().size(), 1)
	assert_eq(manager.placement_at(Vector2i(1, 1)).uid, "d_1", "JSON array cell accepted")
	assert_eq(manager.save_state().next_uid, 2)


func test_decor_placement_dict() -> void:
	var p := DecorPlacement.new()
	p.uid = "d_12"
	p.decor_id = &"decor_bench_wood"
	p.cell = Vector2i(40, 22)
	p.rot = 1
	assert_eq(p.to_dict(), {"uid": "d_12", "decor_id": &"decor_bench_wood", "cell": Vector2i(40, 22), "rot": 1})
	var back := DecorPlacement.from_dict(p.to_dict())
	assert_eq([back.uid, back.decor_id, back.cell, back.rot], [p.uid, p.decor_id, p.cell, p.rot])
	assert_eq(typeof(back.decor_id), TYPE_STRING_NAME)
	assert_eq(DecorPlacement.from_dict({"cell": {"x": 3, "y": 4}, "rot": 5}).cell, Vector2i(3, 4))
	assert_eq(DecorPlacement.from_dict({"rot": 5}).rot, 1, "rot wraps")


# --- PlacedDecor & grass mask -----------------------------------------------------------------

func test_placed_decor_placeholder_collider_and_rotation() -> void:
	var d := Phase3Fixtures.decor(&"decor_bench_wood")
	var p := DecorPlacement.from_dict({"uid": "d_9", "decor_id": d.id, "cell": Vector2i(0, 1), "rot": 1})
	var node := (load("res://src/entities/decor/placed_decor.tscn") as PackedScene).instantiate() as PlacedDecor
	node.setup(d, p, Phase3Fixtures.build_mask())
	container.add_child(node)
	assert_eq(node.name, "d_9")
	assert_almost(node.position.x, 0.25)
	assert_almost(node.position.z, 1.25, 0.0001, "rot 1: 1 × 3 cells")
	assert_almost(node.rotation.y, PI * 0.5)
	assert_not_null(node.model)
	assert_not_null(node.body, "benches collide")
	assert_eq(node.body.collision_layer, 1)
	var gravel := Phase3Fixtures.decor(&"decor_path_gravel")
	var g := (load("res://src/entities/decor/placed_decor.tscn") as PackedScene).instantiate() as PlacedDecor
	g.setup(gravel, DecorPlacement.from_dict({"uid": "d_10", "decor_id": gravel.id, "cell": Vector2i(0, 7)}), Phase3Fixtures.build_mask())
	container.add_child(g)
	assert_null(g.body, "gravel is walkable, no collider")


func test_placed_decor_lights_at_markers() -> void:
	var d := Phase3Fixtures.decor(&"decor_lantern").duplicate() as DecorData
	var model := Node3D.new()
	var marker := Marker3D.new()
	marker.name = "light_lantern"
	marker.position.y = 0.8
	model.add_child(marker)
	var scene := PackedScene.new()
	marker.owner = model
	scene.pack(model)
	model.free()
	d.model = scene
	var node := (load("res://src/entities/decor/placed_decor.tscn") as PackedScene).instantiate() as PlacedDecor
	node.setup(d, DecorPlacement.from_dict({"uid": "d_1", "decor_id": d.id, "cell": Vector2i(5, 1)}), Phase3Fixtures.build_mask())
	container.add_child(node)
	assert_eq(node.lights.size(), 1)
	var light := node.lights[0]
	assert_true(light.is_in_group(&"warm_lights"))
	assert_false(light.shadow_enabled, "grave lanterns never cast shadows")
	assert_true(light.has_meta("base_energy"))


func test_grass_mask_paint() -> void:
	var mask := Phase3Fixtures.build_mask()
	var cells: Array[Vector2i] = [Vector2i(1, 1)]
	var rects: Array[Rect2] = [Rect2(3.0, 0.0, 0.5, 0.25)]
	var img := GrassClearMask.paint(mask, cells, rects)
	assert_eq(img.get_size(), Vector2i(24, 16), "0.25 m texels")
	assert_eq(img.get_format(), Image.FORMAT_R8)
	for t: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
		assert_almost(img.get_pixelv(t).r, 1.0, 0.01, "decor texel %s" % t)
	assert_almost(img.get_pixelv(Vector2i(4, 2)).r, 0.0, 0.01)
	assert_almost(img.get_pixelv(Vector2i(12, 0)).r, 1.0, 0.01, "obstacle")
	assert_almost(img.get_pixelv(Vector2i(13, 0)).r, 1.0, 0.01, "obstacle")
	assert_almost(img.get_pixelv(Vector2i(14, 0)).r, 0.0, 0.01, "outside the rect")
	assert_almost(img.get_pixelv(Vector2i(12, 1)).r, 0.0, 0.01, "outside the rect")


func test_grass_mask_repaints_on_decor_changes() -> void:
	var grass := GrassClearMask.new()
	manager.get_parent().add_child(grass)
	grass.repaint()
	assert_eq(grass.rect, Vector4(0.0, 0.0, 6.0, 4.0))
	assert_almost(grass.image.get_pixelv(Vector2i(2, 2)).r, 0.0, 0.01)
	manager.place(&"decor_grave_vase", Vector2i(1, 1), 0, null)
	assert_almost(grass.image.get_pixelv(Vector2i(2, 2)).r, 1.0, 0.01, "decor_changed repaints")
	var tex := grass.texture
	manager.remove(manager.placements()[0].uid, null)
	assert_almost(grass.image.get_pixelv(Vector2i(2, 2)).r, 0.0, 0.01)
	assert_true(is_same(tex, grass.texture), "same texture, only updated")
	grass.get_parent().remove_child(grass)
	grass.free()
