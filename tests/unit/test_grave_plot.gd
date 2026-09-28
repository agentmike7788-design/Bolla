extends TestCase
## P3 (docs/PHASE6_DESIGN.md §2.3, §3.4, §10): GravePlot of an old grave – no interaction before
## buildings_open, „[E] Altes Grab heben: …" with the block reasons, lifting through the Ossuary
## (OLD → EMPTY: models, collision, prompt), then an ordinary place with the spoil heap at the
## foot end (pit_variant &"foot"), and the lifted state after a load.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const ACTIONS := "res://tests/fixtures/phase5/action_config_fixture.tres"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const PLOT_SCENE := "res://src/entities/grave/grave_plot.tscn"
const EMPTY_MODEL := "res://assets/models/props/ph_prop_grave_plot_empty.glb"
const OLD := GraveRecord.State.OLD
const EMPTY := GraveRecord.State.EMPTY
const DUG := GraveRecord.State.DUG

var world: Node3D
var graveyard: Graveyard
var ossuary: Ossuary
var buildings: Buildings
var barbe: GravePlot
var wendel: GravePlot
var player: Player
var notes: Array = []


func before_each() -> void:
	notes.clear()
	EventBus.notification_requested.connect(_on_note)
	world = Node3D.new()
	world.name = "World"
	var corpses := CorpseManager.new()
	corpses.tables = load(FIXTURE_TABLES) as CorpseTables
	corpses.economy = Phase6Fixtures.economy_config()
	world.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = corpses.economy
	graveyard.tables = corpses.tables
	world.add_child(graveyard)
	ossuary = Ossuary.new()
	ossuary.config = Phase6Fixtures.crypt_config()
	ossuary.old_grave_data = Phase6Fixtures.old_graves()
	world.add_child(ossuary)
	buildings = Phase6Fixtures.crypt_at(1)
	world.add_child(buildings)
	barbe = _old_plot("old_04", "slab_old", "sunken", Vector3(-4, 0, 0))
	wendel = _old_plot("old_01", "cross", "fresh", Vector3(4, 0, 0))
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := Phase6Fixtures.inv_with({&"bone_box": 1})
	fake.name = "Inventory"
	player.add_child(fake)
	player.actions = load(ACTIONS) as ActionConfig
	player.instant_actions = true
	player.position = Vector3(0, 0, 6)
	world.add_child(player)
	tree.root.add_child(world)
	await wait_frames(2)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	world.queue_free()
	await wait_frames(1)


func test_old_plot_is_silent_before_buildings_open() -> void:
	assert_eq(barbe.state, OLD)
	assert_eq(barbe.get_interaction_prompt(player), "")
	assert_false(barbe.can_interact(player))
	assert_false(barbe.interactable.enabled)
	assert_eq(barbe.active_collision_roles(), PackedStringArray(["old"]))


func test_prompt_and_block_reasons_after_opening() -> void:
	_open()
	assert_true(barbe.interactable.enabled, "follows buildings_open on the next minute")
	assert_eq(barbe.get_interaction_prompt(player), "[E] Altes Grab heben: Barbe Lindt (1730–1758)")
	assert_true(barbe.can_interact(player))
	assert_eq(wendel.get_interaction_prompt(player), OssuaryRules.TEXT_REST, "rest period")
	assert_false(wendel.can_interact(player))
	player.inventory.remove_item(&"bone_box", 1)
	assert_eq(barbe.get_interaction_prompt(player), OssuaryRules.TEXT_NO_BOX)
	assert_false(barbe.can_interact(player))
	player.inventory.add_item(&"bone_box", 1)
	buildings.load_state({"levels": {"crypt": 0}})
	assert_eq(barbe.get_interaction_prompt(player), OssuaryRules.TEXT_BURIED)


func test_lifting_makes_an_ordinary_place() -> void:
	_open()
	var free_before := graveyard.free_plot_count()
	barbe.interact(player)
	await wait_frames(2)
	assert_eq(graveyard.get_grave("old_04").state, EMPTY)
	assert_eq(barbe.state, EMPTY, "same node, models swapped")
	assert_eq(_visual_models(barbe), [EMPTY_MODEL])
	assert_eq(barbe.active_collision_roles(), PackedStringArray(), "the old stone's collision is off")
	assert_eq([player.inventory.count(&"bone_box"), player.inventory.count(&"bone_box_full")], [0, 1])
	assert_eq(ossuary.pending(), PackedStringArray(["old_04"]))
	assert_eq(graveyard.free_plot_count(), free_before + 1, "Osric brings a corpse for it")
	assert_true(barbe.interactable.enabled)
	assert_eq(barbe.get_interaction_prompt(player), GravePlot.PROMPT_DIG % 60)
	barbe.interact(player)
	await wait_frames(2)
	assert_eq(graveyard.get_grave("old_04").state, DUG)
	assert_eq(barbe.active_collision_roles(), PackedStringArray(["pit"]))


func test_lift_minutes_follow_the_shovel() -> void:
	_open()
	var inv := Phase6Fixtures.inv_with({&"bone_box": 1}, {&"shovel": 2})
	assert_eq(ossuary.lift_minutes(inv, player.actions), 35)
	inv.free()


func test_spoil_heap_at_the_foot_end() -> void:
	assert_eq(barbe.pit_variant, &"foot")
	var path := barbe.active_pit_model().resource_path
	if ResourceLoader.exists(GravePlot.PIT_FOOT_PATH):
		assert_eq(path, GravePlot.PIT_FOOT_PATH)
	else:
		assert_eq(path, barbe.pit_model.resource_path, "fallback until P5's asset lands")
	assert_eq(barbe.active_footprint(), barbe.foot_footprint)
	assert_true(barbe.active_footprint().has_point(Vector2(0, 2.0)), "heap towards +Z")
	assert_false(barbe.active_footprint().has_point(Vector2(1.2, 0)), "not towards +X")
	var plain := (load(PLOT_SCENE) as PackedScene).instantiate() as GravePlot
	assert_eq([plain.pit_variant, plain.active_footprint()], [&"", plain.footprint])
	assert_eq(plain.active_pit_model(), plain.pit_model)
	plain.free()
	_open()
	barbe.interact(player)
	graveyard.dig("old_04")
	await wait_frames(1)
	assert_eq(_visual_models(barbe), [path], "DUG shows the foot pit")


func test_lifted_state_after_load() -> void:
	_open()
	barbe.interact(player)
	var saved := JSON.parse_string(JSON.stringify(graveyard.save_state())) as Dictionary
	graveyard.load_state({})
	graveyard.broadcast_state()
	await wait_frames(2)
	assert_eq(barbe.state, OLD)
	assert_eq(barbe.active_collision_roles(), PackedStringArray(["old"]))
	graveyard.load_state(saved)
	graveyard.broadcast_state()
	await wait_frames(2)
	assert_eq(barbe.state, EMPTY)
	assert_eq(_visual_models(barbe), [EMPTY_MODEL])


# --- helpers ------------------------------------------------------------------------------------

func _open() -> void:
	GameState.set_flag(&"buildings_open", true)
	EventBus.time_tick.emit(1, 400)


## An old plot like the world builder makes it, with a "Collision" body (roles old, pit, mound).
func _old_plot(id: String, stone: String, mound: String, at: Vector3) -> GravePlot:
	var plot := (load(PLOT_SCENE) as PackedScene).instantiate() as GravePlot
	plot.grave_id = id
	plot.is_old = true
	plot.old_stone = stone
	plot.old_mound = mound
	plot.pit_variant = &"foot"
	plot.position = at
	var body := StaticBody3D.new()
	body.name = "Collision"
	for role: String in ["old", "pit", "mound"]:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.set_meta(&"role", role)
		shape.disabled = role != "old"
		body.add_child(shape)
	plot.add_child(body)
	world.add_child(plot)
	return plot


func _visual_models(target: GravePlot) -> Array:
	var out: Array = []
	for child: Node in target.get_node("Visual").get_children():
		out.append(child.scene_file_path)
	return out


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
