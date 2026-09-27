extends TestCase
## W1: world entities (§4) – Corpse, GravePlot, MorgueTable, Workbench, Dropoff, ResourceNode,
## Npc, HutDoor, Bed: prompts, can_interact and interact per state, on a small hand-built world
## with the real CorpseManager / Graveyard (fixture tables & economy), the real player scene
## (FakeInventory) and instant timed actions.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const PLOT_SCENE := "res://src/entities/grave/grave_plot.tscn"
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"
const WORKBENCH_SCENE := "res://src/entities/workbench/workbench.tscn"
const DROPOFF_SCENE := "res://src/entities/dropoff/dropoff.tscn"
const RESOURCE_SCENE := "res://src/entities/resource_node/resource_node.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const DOOR_SCENE := "res://src/entities/hut_door/hut_door.tscn"
const BED_SCENE := "res://src/entities/bed/bed.tscn"
const INTERIOR_SCENE := "res://src/world/hut_interior/hut_interior.tscn"
const CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
## Plain corpse looks in variant order (Corpse.plain_variants, picked by posmod(seed, 4)).
const CORPSE_VARIANTS: Array[String] = [
	"res://assets/models/props/ph_prop_corpse.glb",
	"res://assets/models/props/ph_prop_corpse_02.glb",
	"res://assets/models/props/ph_prop_corpse_03.glb",
	"res://assets/models/props/ph_prop_corpse_04.glb",
]
const TEST_SAVES := "user://test_saves"
const EMPTY := GraveRecord.State.EMPTY
const DUG := GraveRecord.State.DUG
const FILLED := GraveRecord.State.FILLED
const MARKED := GraveRecord.State.MARKED
## TimeManager after reset: day 1, 06:30.
const START_MINUTE := 390


## Waypoint provider for the NPC (anything with get_waypoint()).
class WaypointWorld extends Node3D:
	var points: Dictionary = {}

	func get_waypoint(id: StringName) -> Vector3:
		return points.get(id, Vector3.ZERO)


## Inventory without room for anything.
class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false

	func add_item(_id: StringName, amount: int) -> int:
		return amount


var world: Node3D
var corpses: CorpseManager
var graveyard: Graveyard
var player: Player
var inv: Inventory
var plot: GravePlot
var old_plot: GravePlot
var table: MorgueTable
var dropoff: Dropoff
var panels: Array = []
var notes: Array = []
var dialogues: Array = []


func before_each() -> void:
	panels.clear()
	notes.clear()
	dialogues.clear()
	EventBus.ui_panel_requested.connect(_on_panel)
	EventBus.notification_requested.connect(_on_note)
	EventBus.dialogue_requested.connect(_on_dialogue)
	world = Node3D.new()
	world.name = "World"
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var container := Node3D.new()
	container.name = "Corpses"
	world.add_child(container)
	corpses = CorpseManager.new()
	corpses.tables = load(FIXTURE_TABLES) as CorpseTables
	corpses.economy = load(FIXTURE_ECONOMY) as EconomyConfig
	corpses.corpse_scene = load(CORPSE_SCENE)
	corpses.container_path = ^"../Corpses"
	world.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = corpses.economy
	graveyard.tables = corpses.tables
	world.add_child(graveyard)
	plot = _instance(PLOT_SCENE, Vector3(6, 0, 0)) as GravePlot
	plot.grave_id = "plot_01"
	old_plot = _instance(PLOT_SCENE, Vector3(-6, 0, 6)) as GravePlot
	old_plot.grave_id = "old_01"
	old_plot.is_old = true
	old_plot.old_stone = "round"
	old_plot.old_mound = "grassy"
	table = _instance(TABLE_SCENE, Vector3(0, 0, -6)) as MorgueTable
	dropoff = _instance(DROPOFF_SCENE, Vector3(-6, 0, -6)) as Dropoff
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	player.position = Vector3(0, 0, 4)
	world.add_child(player)
	tree.root.add_child(world)
	inv = player.inventory
	player.instant_actions = true
	await tree.process_frame


func after_each() -> void:
	EventBus.ui_panel_requested.disconnect(_on_panel)
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.dialogue_requested.disconnect(_on_dialogue)
	if SaveManager.save_dir == TEST_SAVES:
		SaveManager.delete_save(0)


# --- Corpse -----------------------------------------------------------------------------------

func test_corpse_scene_contract() -> void:
	var c := _spawn(&"dropoff")
	var node := corpses.get_corpse_node(c.id)
	assert_true(node is Corpse)
	assert_eq(node.corpse_id, c.id)
	assert_eq(node.interactable.priority, 20, "corpse priority")
	assert_true(node.interactable.get_child(0) is CollisionShape3D, "interactable has a shape")
	assert_eq(node.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_corpse.glb")


func test_corpse_pick_up_from_dropoff() -> void:
	var c := _spawn(&"dropoff")
	var node := corpses.get_corpse_node(c.id)
	assert_eq(node.get_interaction_prompt(player), "[E] Leiche aufheben")
	assert_true(node.can_interact(player))
	node.interact(player)
	assert_eq(player.carried_id, c.id)
	assert_eq(c.location, CorpseRecord.LOCATION_CARRIED)
	assert_false(node.interactable.enabled, "carried corpse is not focusable")
	assert_eq(node.get_interaction_prompt(player), "", "no own prompt while carried")


func test_corpse_needs_free_hands() -> void:
	var a := _spawn(&"ground", Vector3(2, 0, 2))
	var b := _spawn(&"ground", Vector3(-2, 0, 2))
	corpses.pick_up(a.id, player)
	var node := corpses.get_corpse_node(b.id)
	assert_eq(node.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(node.can_interact(player))
	node.interact(player)
	assert_eq(player.carried_id, a.id, "interact refused")


func test_corpse_blocked_while_player_busy() -> void:
	var c := _spawn(&"ground")
	player.instant_actions = false
	player.start_timed_action("Test", 30, Callable())
	assert_false(corpses.get_corpse_node(c.id).can_interact(player))
	player.cancel_timed_action()


func test_corpse_on_table_is_handled_by_the_table() -> void:
	var c := _spawn(&"ground")
	corpses.pick_up(c.id, player)
	table.interact(player)
	await _settle()
	var node := corpses.get_corpse_node(c.id)
	assert_eq(c.location, CorpseRecord.LOCATION_TABLE)
	assert_false(node.interactable.enabled, "own interactable off on the table")
	assert_false(node.interactable.monitorable)
	assert_eq(node.get_interaction_prompt(player), "")
	corpses.pick_up(c.id, player)
	corpses.put_down(c.id, &"ground", Transform3D(Basis.IDENTITY, Vector3(3, 0, 3)))
	await _settle()
	assert_true(node.interactable.enabled, "on the ground it is focusable again")
	assert_true(node.interactable.monitorable)


func test_corpse_model_swaps_when_shrouded() -> void:
	var c := _spawn(&"ground")
	var node := corpses.get_corpse_node(c.id)
	assert_false(node.is_shrouded_visual())
	inv.add_item(&"shroud", 1)
	assert_true(corpses.apply_shroud(c.id, inv))
	await tree.process_frame
	assert_true(node.is_shrouded_visual())
	assert_eq(node.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_corpse_shrouded.glb")


func test_corpse_plain_variants_exported() -> void:
	var node := corpses.get_corpse_node(_spawn(&"ground").id)
	assert_eq(node.plain_variants.size(), CORPSE_VARIANTS.size(), "four plain looks")
	for i: int in CORPSE_VARIANTS.size():
		assert_not_null(node.plain_variants[i], "variant %d set" % i)
		if node.plain_variants[i] != null:
			assert_eq(node.plain_variants[i].resource_path, CORPSE_VARIANTS[i], "variant %d" % i)
	assert_eq(node.plain_model.resource_path, CORPSE_VARIANTS[0], "plain_model = variant 0")


func test_corpse_variant_for_seed_is_deterministic() -> void:
	assert_eq(Corpse.variant_for_seed(0, 4), 0)
	assert_eq(Corpse.variant_for_seed(7, 4), 3)
	assert_eq(Corpse.variant_for_seed(-1, 4), 3, "negative seeds wrap (posmod)")
	assert_eq(Corpse.variant_for_seed(12345, 0), 0, "no variants -> plain_model")
	# the generator's seeds (docs §2.5) spread over all looks within the first days
	var seen := {}
	for day: int in range(1, 5):
		seen[Corpse.variant_for_seed(CorpseGenerator.seed_for(day, 0), 4)] = true
	assert_eq(seen.size(), 4, "days 1-4 show four different looks (%s)" % [seen.keys()])


## The look follows the person: woman -> headscarf dress, man from old_age -> white beard,
## other men farmhand (even seed) or miller (odd seed).
func test_corpse_model_follows_name_and_age() -> void:
	var tables: CorpseTables = corpses.tables if corpses.tables != null else Database.corpse_tables() as CorpseTables
	for case: Array in [["Hedwig Rabenstein", 67, 4, 1], ["Frieda Kalk", 24, 5, 1], ["Gottlieb Esche", 71, 2, 2],
			["Ulrich Moor", 30, 2, 0], ["Ulrich Moor", 30, 3, 3], ["Sebald Kalk", 59, -5, 3]]:
		var c := _spawn(&"ground", Vector3(2, 0, 2), false, case[2], case[0], case[1])
		var node := corpses.get_corpse_node(c.id)
		assert_eq(node.visual_variant(), case[3], "%s (%d) -> look %d" % [case[0], case[1], case[3]])
		assert_eq(node.get_node("Model").scene_file_path, CORPSE_VARIANTS[case[3]], "%s model" % case[0])
		assert_eq(Corpse.variant_for_record(c, tables, 4), case[3])
		assert_false(node.is_shrouded_visual())


func test_every_generated_corpse_look_fits_name_and_age() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	assert_true(tables.female_first_names.size() > 0)
	for f: String in tables.female_first_names:
		assert_has(tables.first_names, f, "female name %s is a first name" % f)
	for day: int in range(1, 21):
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), tables, day)
		var look := Corpse.variant_for_record(r, tables, 4)
		var female := r.display_name.get_slice(" ", 0) in tables.female_first_names
		assert_eq(look == Corpse.LOOK_OLD_WOMAN, female, "day %d %s" % [day, r.display_name])
		if not female:
			assert_eq(look == Corpse.LOOK_OLD_MAN, r.age >= tables.old_age, "day %d age %d" % [day, r.age])


func test_corpse_variant_survives_shroud_swap() -> void:
	var c := _spawn(&"ground", Vector3(2, 0, 2), false, 6, "Gottlieb Esche", 80)
	var node := corpses.get_corpse_node(c.id)
	assert_eq(node.get_node("Model").scene_file_path, CORPSE_VARIANTS[2])
	inv.add_item(&"shroud", 1)
	assert_true(corpses.apply_shroud(c.id, inv))
	await tree.process_frame
	assert_true(node.is_shrouded_visual())
	assert_eq(node.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_corpse_shrouded.glb")
	assert_eq(node.visual_variant(), 2, "the look underneath is kept")
	assert_eq(node.get_children().filter(func(n: Node) -> bool: return n.name == &"Model").size(), 1, "one model")
	corpses.examine(c.id)  # another corpse_updated: nothing changes
	await tree.process_frame
	assert_eq(node.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_corpse_shrouded.glb")


func test_corpse_variant_survives_save_and_load() -> void:
	var plain := _spawn(&"ground", Vector3(2, 0, 2), false, 5, "Anna Moor", 40)
	var wrapped := _spawn(&"ground", Vector3(3, 0, 3), false, 7, "Bert Kalk", 30)
	inv.add_item(&"shroud", 1)
	assert_true(corpses.apply_shroud(wrapped.id, inv))
	# through JSON like a real save (seeds come back as floats)
	var state: Dictionary = JSON.parse_string(JSON.stringify(corpses.save_state()))
	corpses.load_state(state)
	await tree.process_frame
	var a := corpses.get_corpse_node(plain.id)
	assert_eq(a.get_node("Model").scene_file_path, CORPSE_VARIANTS[1], "woman look after load")
	assert_eq(a.visual_variant(), 1)
	var b := corpses.get_corpse_node(wrapped.id)
	assert_true(b.is_shrouded_visual(), "still shrouded after load")
	assert_eq(b.visual_variant(), 3, "young man, odd seed -> miller after load")


# --- GravePlot --------------------------------------------------------------------------------

func test_plot_scene_contract() -> void:
	assert_true(plot.is_in_group(&"grave_plot"))
	assert_eq(plot.interactable.priority, 10, "grave priority")
	assert_eq(graveyard.get_grave("plot_01").state, EMPTY)
	assert_eq(graveyard.get_grave("old_01").state, GraveRecord.State.OLD)
	assert_eq(_visual_models(plot), ["res://assets/models/props/ph_prop_grave_plot_empty.glb"])


func test_plot_dig() -> void:
	assert_eq(plot.get_interaction_prompt(player), "[E] Grab ausheben (60 Min)")
	assert_true(plot.can_interact(player))
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, DUG)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 60, "dig takes 60 game minutes")
	assert_eq(_visual_models(plot), ["res://assets/models/props/ph_prop_grave_pit.glb"])


func test_plot_dig_moves_the_player_out_of_the_pit() -> void:
	player.global_position = plot.global_position + Vector3(0.1, 0, 0.2)
	plot.interact(player)
	var local := plot.to_local(player.global_position)
	assert_false(plot.footprint.grow(plot.eject_margin * 0.99).has_point(Vector2(local.x, local.z)), "player outside the pit")


## C4: plots stand 2.4 m apart along X – the +X exit would put the player into the finished
## neighbour's mound, so they leave the pit to the nearest free side (+Z here).
func test_plot_dig_exit_avoids_the_neighbouring_grave() -> void:
	var mound := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.12, 0.38, 2.0)
	shape.shape = box
	mound.add_child(shape)
	world.add_child(mound)
	mound.global_position = plot.global_position + Vector3(2.4, 0.19, -0.01)
	await tree.physics_frame
	await tree.physics_frame
	player.global_position = plot.global_position + Vector3(1.0, 0, 0.2)
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, DUG)
	var local := plot.to_local(player.global_position)
	var area := plot.footprint.grow(plot.eject_margin)
	assert_almost(local.x, 1.0, 0.001, "moved straight to the +Z side")
	assert_almost(local.z, area.end.y, 0.001, str(local))
	for i: int in 10:
		await tree.physics_frame
	var settled := plot.to_local(player.global_position)
	assert_almost(settled.x, local.x, 0.02, "not pushed sideways by the neighbour")
	assert_almost(settled.z, local.z, 0.02, "not pushed sideways by the neighbour")
	assert_true(absf(player.global_position.y) < 0.05, "not standing on the mound (y %.3f)" % player.global_position.y)


func test_plot_dig_exit_keeps_the_nearest_free_side() -> void:
	player.global_position = plot.global_position + Vector3(1.4, 0, 0.1)
	plot.interact(player)
	var local := plot.to_local(player.global_position)
	assert_almost(local.x, plot.footprint.grow(plot.eject_margin).end.x, 0.001, "nothing next to it: +X is nearest")
	assert_almost(local.z, 0.1, 0.001)


func test_plot_dig_blocked_while_carrying() -> void:
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(plot.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(plot.can_interact(player))
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, EMPTY)


func test_plot_dig_blocked_by_a_corpse_on_it() -> void:
	_spawn(&"ground", plot.global_position + Vector3(0.2, 0, 0.3))
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_CORPSE_HERE)
	assert_false(plot.can_interact(player))


func test_plot_dug_needs_a_corpse_then_buries() -> void:
	graveyard.dig("plot_01")
	assert_eq(plot.get_interaction_prompt(player), "Offenes Grab – Leiche holen")
	assert_false(plot.can_interact(player))
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(plot.get_interaction_prompt(player), "[E] Bestatten (30 Min)")
	assert_true(plot.can_interact(player))
	var before := TimeManager.total_minutes()
	plot.interact(player)
	await tree.process_frame
	assert_eq(graveyard.get_grave("plot_01").state, FILLED)
	assert_eq(c.location, CorpseRecord.LOCATION_BURIED)
	assert_eq(c.grave_id, "plot_01")
	assert_null(player.carried, "the CorpseManager took the corpse")
	assert_eq(TimeManager.total_minutes() - before, 30)
	assert_eq(_visual_models(plot), ["res://assets/models/props/ph_prop_grave_mound_fresh.glb"])
	assert_almost((plot.get_node("Visual").get_child(0) as Node3D).position.z, plot.mound_offset.z, 0.0001, "mound centred")


func test_plot_marker_prompts_and_single_marker() -> void:
	_fill_plot()
	assert_eq(plot.get_interaction_prompt(player), "Kein Grabzeichen – Werkbank")
	assert_false(plot.can_interact(player))
	inv.add_item(&"wooden_cross", 1)
	assert_eq(plot.get_interaction_prompt(player), "[E] Holzkreuz setzen (10 Min)")
	assert_true(plot.can_interact(player))
	var coins := inv.count(&"coin")
	plot.interact(player)
	var grave := graveyard.get_grave("plot_01")
	assert_eq(grave.state, MARKED)
	assert_eq(grave.marker_id, &"wooden_cross")
	assert_eq(inv.count(&"wooden_cross"), 0)
	assert_true(inv.count(&"coin") > coins, "paid")
	assert_eq(_visual_models(plot), ["res://assets/models/props/ph_prop_grave_mound_fresh.glb",
			"res://assets/models/props/ph_prop_cross_wood.glb"])
	var marker := plot.get_node("Visual").get_child(1) as Node3D
	assert_true(marker.position.is_equal_approx(plot.marker_offset), "marker at the head end")
	assert_true(marker.position.z < 0.0, "head = -Z")
	assert_eq(plot.get_interaction_prompt(player), "Grab von Bert Moor – Qualität %d/10" % grave.quality)
	assert_false(plot.can_interact(player))


func test_plot_marker_blocked_while_carrying() -> void:
	_fill_plot()
	inv.add_item(&"wooden_cross", 1)
	var c := _spawn(&"ground", Vector3(-3, 0, 3))
	corpses.pick_up(c.id, player)
	assert_eq(plot.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(plot.can_interact(player))


func test_plot_marker_choice_panel() -> void:
	_fill_plot()
	inv.add_item(&"wooden_cross", 1)
	inv.add_item(&"gravestone_simple", 1)
	assert_eq(plot.get_interaction_prompt(player), "[E] Grabzeichen setzen (10 Min)")
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, FILLED, "the panel decides")
	assert_eq(panels.size(), 1)
	assert_eq(panels[0][0], &"marker_choice")
	var ctx: Dictionary = panels[0][1]
	assert_eq(ctx.grave_id, "plot_01")
	assert_eq(ctx.plot, plot)
	assert_eq(ctx.options, [&"wooden_cross", &"gravestone_simple"])
	plot.request_marker(&"gravestone_simple")
	assert_eq(graveyard.get_grave("plot_01").marker_id, &"gravestone_simple")
	assert_eq(inv.count(&"wooden_cross"), 1, "the other marker stays")
	assert_eq(_visual_models(plot)[1], "res://assets/models/props/ph_prop_gravestone_round.glb")


func test_plot_request_marker_refusals() -> void:
	plot.request_marker(&"wooden_cross")
	assert_eq(graveyard.get_grave("plot_01").state, EMPTY)
	assert_eq(_last_note(), [GravePlot.TEXT_CANNOT_MARK, &"warning"])
	_fill_plot()
	plot.request_marker(&"wooden_cross")
	assert_eq(graveyard.get_grave("plot_01").state, FILLED, "marker not in the inventory")


func test_old_plot_has_no_interaction() -> void:
	assert_eq(old_plot.get_interaction_prompt(player), "")
	assert_false(old_plot.can_interact(player))
	assert_false(old_plot.interactable.enabled)
	assert_eq(_visual_models(old_plot), ["res://assets/models/props/ph_prop_grave_mound_grassy.glb",
			"res://assets/models/props/ph_prop_gravestone_round.glb"])
	var stone := old_plot.get_node("Visual").get_child(1) as Node3D
	assert_true(stone.position.is_equal_approx(old_plot.old_stone_offset), "prototype stone position")


func test_plot_visual_follows_loaded_state() -> void:
	var c := _spawn(&"ground", Vector3(-3, 0, 3))
	graveyard.load_state({"graves": [{"id": "plot_01", "state": MARKED, "corpse_id": c.id, "marker_id": &"wooden_cross", "quality": 7}]})
	graveyard.broadcast_state()
	assert_eq(plot.state, MARKED)
	assert_eq(_visual_models(plot)[1], "res://assets/models/props/ph_prop_cross_wood.glb")


func test_plot_collision_roles_follow_state() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	for role: String in ["pit", "mound", "marker:wooden_cross"]:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.set_meta(&"role", role)
		body.add_child(shape)
	plot.add_child(body)
	graveyard.dig("plot_01")
	await tree.process_frame
	assert_eq(plot.active_collision_roles(), PackedStringArray(["pit"]))
	_bury_into_plot()
	await tree.process_frame
	assert_eq(plot.active_collision_roles(), PackedStringArray(["mound"]))
	inv.add_item(&"wooden_cross", 1)
	plot.interact(player)
	await tree.process_frame
	assert_eq(plot.active_collision_roles(), PackedStringArray(["mound", "marker:wooden_cross"]))


# --- MorgueTable ------------------------------------------------------------------------------

func test_table_put_down_on_the_slot() -> void:
	assert_true(table.is_in_group(&"morgue_table"))
	assert_eq(table.interactable.priority, 5)
	assert_eq(table.get_interaction_prompt(player), "", "free hands, free table: nothing to do")
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(table.get_interaction_prompt(player), "[E] Leiche ablegen")
	assert_true(table.can_interact(player))
	table.interact(player)
	assert_eq(c.location, CorpseRecord.LOCATION_TABLE)
	assert_eq(table.corpse_id, c.id)
	var node := corpses.get_corpse_node(c.id)
	assert_eq(node.get_parent(), table.slot_node(), "parented to slot_corpse")
	assert_true(node.transform.is_equal_approx(Transform3D.IDENTITY), "identity on the marker")
	assert_eq(String(table.slot_node().name), "slot_corpse")


func test_table_occupied_prompts_and_exam_panel() -> void:
	var c := _on_table()
	var other := _spawn(&"ground", Vector3(3, 0, 3))
	corpses.pick_up(other.id, player)
	assert_eq(table.get_interaction_prompt(player), "Der Tisch ist belegt")
	assert_false(table.can_interact(player))
	corpses.put_down(other.id, &"ground", Transform3D(Basis.IDENTITY, Vector3(3, 0, 3)))
	assert_eq(table.get_interaction_prompt(player), "[E] Leiche untersuchen")
	assert_true(table.can_interact(player))
	table.interact(player)
	assert_eq(panels.size(), 1)
	assert_eq(panels[0][0], &"corpse_exam")
	assert_eq(panels[0][1], {"corpse_id": c.id, "table": table, "player": player})


func test_table_examine() -> void:
	var c := _on_table()
	table.request_examine()
	assert_true(c.examined)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20)
	table.request_examine()
	assert_eq(_last_note(), [MorgueTable.TEXT_EXAMINED, &"warning"])
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20, "no second examination")


func test_table_examine_is_not_cancellable() -> void:
	_on_table()
	player.instant_actions = false
	table.request_examine()
	assert_true(player.is_busy())
	Input.action_press(&"move_up")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(&"move_up")
	assert_true(player.is_busy(), "movement does not cancel a panel action")
	player.cancel_timed_action()


## UI-07: once examined the prompt no longer asks for the examination.
func test_table_prompt_after_the_examination() -> void:
	var c := _on_table()
	assert_eq(table.get_interaction_prompt(player), "[E] Leiche untersuchen")
	table.request_examine()
	assert_true(c.examined)
	assert_eq(table.get_interaction_prompt(player), "[E] Leiche ansehen")
	assert_true(table.can_interact(player), "the panel still opens (shroud, valuables, pick up)")
	var other := _spawn(&"ground", Vector3(3, 0, 3))
	corpses.pick_up(other.id, player)
	assert_eq(table.get_interaction_prompt(player), "Der Tisch ist belegt")


func test_table_shroud() -> void:
	var c := _on_table()
	table.request_shroud()
	assert_eq(_last_note(), [MorgueTable.TEXT_NO_SHROUD, &"warning"])
	assert_false(c.shrouded)
	inv.add_item(&"shroud", 1)
	table.request_shroud()
	assert_true(c.shrouded)
	assert_eq(inv.count(&"shroud"), 0)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 10)
	table.request_shroud()
	assert_eq(_last_note(), [MorgueTable.TEXT_SHROUDED, &"warning"])


func test_table_valuables_decision_gates_the_shroud() -> void:
	var c := _on_table(true)
	table.request_examine()
	assert_true(c.needs_valuables_decision())
	inv.add_item(&"shroud", 1)
	table.request_shroud()
	assert_eq(_last_note(), [MorgueTable.TEXT_DECIDE_FIRST, &"warning"])
	assert_false(c.shrouded)
	table.decide_valuables(true)
	assert_eq(c.valuables_decision, CorpseRecord.DECISION_TAKEN)
	assert_eq(inv.count(&"coin"), 6)
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)
	assert_eq(GameState.get_stat(&"reputation"), corpses.economy.valuables_reputation)
	table.decide_valuables(false)
	assert_eq(_last_note(), [MorgueTable.TEXT_NO_DECISION, &"warning"])
	assert_eq(c.valuables_decision, CorpseRecord.DECISION_TAKEN, "final")
	table.request_shroud()
	assert_true(c.shrouded)


func test_table_leave_valuables() -> void:
	var c := _on_table(true)
	table.request_examine()
	table.decide_valuables(false)
	assert_eq(c.valuables_decision, CorpseRecord.DECISION_LEFT)
	assert_eq(inv.count(&"coin"), 0)


func test_table_pick_up() -> void:
	var c := _on_table()
	table.request_pick_up()
	assert_eq(player.carried_id, c.id)
	assert_eq(table.corpse_id, "")
	table.request_pick_up()
	assert_eq(_last_note(), [MorgueTable.TEXT_NO_CORPSE, &"warning"])


func test_table_occupancy_comes_from_the_records_after_load() -> void:
	var c := _on_table()
	var state := corpses.save_state()
	corpses.load_state(state)
	await tree.process_frame
	var node := corpses.get_corpse_node(c.id)
	assert_eq(node.get_parent().name, "Corpses", "recreated under the container")
	assert_eq(table.corpse_id, c.id, "still occupied")
	assert_eq(table.get_interaction_prompt(player), "[E] Leiche untersuchen")
	assert_false(node.interactable.enabled)


func test_table_panel_actions_without_corpse_warn() -> void:
	table.request_examine()
	assert_eq(_last_note(), [MorgueTable.TEXT_NO_CORPSE, &"warning"])
	table.request_shroud()
	table.decide_valuables(true)
	assert_eq(notes.size(), 3)


# --- Workbench --------------------------------------------------------------------------------

func test_workbench_panel() -> void:
	var bench := _instance(WORKBENCH_SCENE, Vector3(3, 0, -3)) as Workbench
	await tree.process_frame
	assert_eq(bench.interactable.priority, 5)
	assert_eq(bench.get_interaction_prompt(player), "[E] Werkbank benutzen")
	assert_true(bench.can_interact(player))
	bench.interact(player)
	assert_eq(panels[0][0], &"crafting")
	assert_eq(panels[0][1], {"station": &"workbench", "inventory": inv, "workbench": bench, "player": player})
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(bench.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(bench.can_interact(player))


func test_workbench_crafts_timed() -> void:
	var bench := _instance(WORKBENCH_SCENE, Vector3(3, 0, -3)) as Workbench
	await tree.process_frame
	bench.interact(player)
	inv.add_item(&"wood", 3)
	bench.request_craft(&"wooden_cross")
	assert_eq(inv.count(&"wooden_cross"), 1)
	assert_eq(inv.count(&"wood"), 0)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + (Database.recipe(&"wooden_cross") as RecipeData).craft_minutes)
	assert_eq(_last_note(), ["+1 Holzkreuz", &"reward"])


func test_workbench_refusals() -> void:
	var bench := _instance(WORKBENCH_SCENE, Vector3(3, 0, -3)) as Workbench
	await tree.process_frame
	bench.interact(player)
	inv.add_item(&"wood", 1)
	bench.request_craft(&"wooden_cross")
	assert_eq(_last_note(), ["Es fehlt: 2 Holz", &"warning"])
	assert_eq(inv.count(&"wood"), 1)
	bench.request_craft(&"no_such_recipe")
	assert_eq(_last_note(), [Workbench.TEXT_UNKNOWN, &"warning"])
	assert_eq(TimeManager.minute_of_day, START_MINUTE, "no time spent")


# --- Dropoff ----------------------------------------------------------------------------------

func test_dropoff_free_and_slot() -> void:
	assert_true(dropoff.is_in_group(&"dropoff"))
	assert_true(dropoff.is_free())
	var slot := dropoff.find_child("slot_corpse", true, false) as Node3D
	assert_true(dropoff.slot_transform().is_equal_approx(slot.global_transform))
	assert_true(dropoff.slot_transform().origin.y > 0.4, "on top of the bier")
	var c := _spawn(&"dropoff")
	assert_false(dropoff.is_free())
	corpses.pick_up(c.id, player)
	assert_true(dropoff.is_free())


func test_dropoff_drives_the_delivery() -> void:
	var c := corpses.try_daily_delivery(1)
	assert_not_null(c)
	assert_true(corpses.get_corpse_node(c.id).global_transform.is_equal_approx(dropoff.slot_transform()))
	assert_null(corpses.try_daily_delivery(2), "bier still occupied")


# --- ResourceNode -----------------------------------------------------------------------------

func test_resource_node_gathers() -> void:
	var pile := _resource()
	assert_true(pile.is_in_group(&"saveable"))
	assert_eq(pile.interactable.priority, 5)
	assert_eq(pile.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_wood_pile.glb")
	assert_eq(pile.remaining, 0, "no content before a new game")
	assert_eq(pile.get_interaction_prompt(player), "Für heute leer")
	EventBus.new_game_started.emit()
	assert_eq(pile.remaining, 6)
	assert_eq(pile.get_interaction_prompt(player), "[E] Holz sammeln (10 Min) – 6 übrig")
	assert_true(pile.can_interact(player))
	var wood := inv.count(&"wood")  # the player got the start inventory on new_game_started
	pile.interact(player)
	assert_eq(inv.count(&"wood"), wood + 1)
	assert_eq(pile.remaining, 5)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 10)
	assert_eq(_last_note(), ["+1 Holz", &"reward"])


func test_resource_node_empty_and_carrying() -> void:
	var pile := _resource()
	EventBus.new_game_started.emit()
	pile.remaining = 0
	assert_eq(pile.get_interaction_prompt(player), "Für heute leer")
	assert_false(pile.can_interact(player))
	pile.refill(TimeManager.day)
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(pile.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(pile.can_interact(player))


func test_resource_node_full_inventory() -> void:
	var pile := _resource()
	EventBus.new_game_started.emit()
	var full := FullInventory.new()
	full.name = "Inventory"
	player.remove_child(player.inventory)
	player.add_child(full)
	player.inventory = full
	assert_eq(pile.get_interaction_prompt(player), ResourceNode.PROMPT_NO_ROOM)
	assert_false(pile.can_interact(player))


func test_resource_node_refills_each_day() -> void:
	var pile := _resource()
	EventBus.new_game_started.emit()
	pile.interact(player)
	pile.interact(player)
	assert_eq(pile.remaining, 4)
	TimeManager.set_time(2, 360)
	assert_eq(pile.remaining, 6)
	assert_eq(pile.last_reset_day, 2)


func test_resource_node_save_load() -> void:
	var pile := _resource()
	EventBus.new_game_started.emit()
	pile.interact(player)
	var state := pile.save_state()
	assert_eq(state, {"remaining": 5, "last_reset_day": 1})
	pile.remaining = 0
	pile.load_state(state)
	assert_eq(pile.remaining, 5)
	TimeManager.load_state({"day": 3, "minute_of_day": 400})
	pile.load_state(state)
	assert_eq(pile.remaining, 6, "saved on an earlier day: refilled")
	assert_eq(pile.last_reset_day, 3)
	pile.load_state({"remaining": 99.0, "last_reset_day": 3.0})
	assert_eq(pile.remaining, 6, "clamped to daily_amount")


# --- Npc --------------------------------------------------------------------------------------

func test_npc_follows_the_schedule() -> void:
	var npc := await _npc()
	assert_true(npc.is_in_group(&"npc") and npc.is_in_group(&"saveable"))
	assert_eq(npc.interactable.priority, 30)
	assert_eq(npc.body.collision_layer, 4, "npc body on layer 3")
	TimeManager.load_state({"day": 1, "minute_of_day": 100})
	npc.refresh()
	await _settle()
	assert_false(npc.visible, "at home")
	assert_true(npc.global_position.is_equal_approx(Vector3(0, 0, 20)))
	assert_false(npc.interactable.enabled)
	assert_true(npc.body_shape.disabled, "no collision while away")
	assert_eq(npc.get_interaction_prompt(player), "")
	# 07:20 = half way (arc length) along a 10 m + 10 m path: the corner.
	TimeManager.load_state({"day": 1, "minute_of_day": 440})
	npc.refresh()
	await _settle()
	assert_true(npc.visible)
	assert_true(npc.global_position.is_equal_approx(Vector3(0, 0, 10)), str(npc.global_position))
	assert_true(npc.is_walking())
	assert_false(npc.interactable.enabled, "no dialogue while walking")
	assert_false(npc.body_shape.disabled)
	assert_true(npc.cart.visible, "pushes the cart")
	assert_false(npc.cart_shape.disabled)
	TimeManager.load_state({"day": 1, "minute_of_day": 450})
	npc.refresh()
	assert_true(npc.global_position.is_equal_approx(Vector3(5, 0, 10)), str(npc.global_position))
	assert_almost(npc.rotation.y, PI * 0.5, 0.001, "faces the walking direction (+X)")
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.refresh()
	await _settle()
	assert_true(npc.global_position.is_equal_approx(Vector3(10, 0, 10)))
	assert_false(npc.is_walking())
	assert_true(npc.interactable.enabled)
	assert_true(npc.interactable.monitorable)
	assert_eq(npc.get_interaction_prompt(player), "[E] Mit Osric reden")
	assert_true(npc.can_interact(player))
	TimeManager.load_state({"day": 1, "minute_of_day": 700})
	npc.refresh()
	assert_true(npc.visible)
	assert_false(npc.cart.visible, "evening without the cart")


func test_npc_talk_allowed_while_carrying() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.refresh()
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_true(npc.can_interact(player))
	npc.interact(player)
	assert_eq(dialogues, [[&"carter", npc]])


func test_npc_turns_to_the_player_but_the_cart_stays() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 450})
	npc.refresh()
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	player.global_position = Vector3(10, 0, 12)
	npc.refresh()
	assert_almost(npc.rotation.y, PI * 0.5, 0.001, "root (and cart) keep the arrival heading")
	var model := npc.get_node("Model") as Node3D
	assert_almost(wrapf(npc.rotation.y + model.rotation.y, -PI, PI), 0.0, 0.001, "the figure faces the player (+Z)")
	player.global_position = Vector3(-20, 0, -20)
	npc.refresh()
	assert_almost(model.rotation.y, 0.0, 0.001, "player gone: looks ahead again")


## SL-1: the standing heading follows from the clock alone – straight after a load (no walk
## seen) he faces the way he came in (b → c = +X), and the cart stays behind the dialogue spot.
func test_npc_standing_heading_comes_from_the_clock() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.load_state(npc.save_state())
	assert_almost(npc.rotation.y, PI * 0.5, 0.001, "arrival heading without having walked")
	TimeManager.load_state({"day": 1, "minute_of_day": 700})
	npc.load_state({})
	assert_almost(npc.rotation.y, PI * 0.5, 0.001, "a later phase at the same spot keeps it")
	assert_true(npc.cart.global_position.x > npc.global_position.x, "cart in front, on the arrival side")


## ARCH-02: the debug console's "npc carter here" calls debug_teleport – he stands there
## until his next schedule phase, then the clock takes over again.
func test_npc_debug_teleport_holds_until_the_next_phase() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.refresh()
	player.global_position = Vector3(0, 0, 4)
	npc.debug_teleport(Vector3(2, 0, 4))
	assert_true(npc.global_position.is_equal_approx(Vector3(2, 0, 4)), str(npc.global_position))
	await _settle()
	assert_true(npc.global_position.is_equal_approx(Vector3(2, 0, 4)), "held while _process runs")
	assert_false(npc.is_walking())
	assert_true(npc.interactable.enabled, "still his dialogue phase")
	var in_cart := npc.cart_shape.global_transform.affine_inverse() * player.global_position
	var half := (npc.cart_shape.shape as BoxShape3D).size * 0.5 + Vector3(0.3, 0.0, 0.3)
	assert_true(absf(in_cart.x) > half.x or absf(in_cart.z) > half.z, "the cart does not land on the player %s" % in_cart)
	var model := npc.get_node("Model") as Node3D
	var look := Vector3.BACK.rotated(Vector3.UP, npc.rotation.y + model.rotation.y)
	assert_almost(look.dot((player.global_position - npc.global_position).normalized()), 1.0, 0.01, "faces the player")
	TimeManager.load_state({"day": 1, "minute_of_day": 650})
	npc.refresh()
	assert_true(npc.global_position.is_equal_approx(Vector3(2, 0, 4)), "same phase: still there")
	TimeManager.load_state({"day": 1, "minute_of_day": 700})
	npc.refresh()
	assert_true(npc.global_position.is_equal_approx(Vector3(10, 0, 10)), "next phase: back on the schedule")
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.debug_teleport(Vector3(2, 0, 4))
	npc.load_state({})
	assert_true(npc.global_position.is_equal_approx(Vector3(10, 0, 10)), "a load drops the hold")


func test_debug_console_brings_the_npc() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.refresh()
	player.global_position = Vector3(0, 0, 4)
	player.rotation.y = 0.0
	var result := Debug.execute("npc carter here")
	assert_true(result.ok, String(result.text))
	assert_true(player.global_position.is_equal_approx(Vector3(0, 0, 4)), "the player stays")
	assert_true(npc.global_position.is_equal_approx(Vector3(0, 0, 4 + DebugConsole.NPC_OFFSET)), str(npc.global_position))


func test_npc_walk_animation_speed_scale() -> void:
	var npc := await _npc()
	var anim := npc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	TimeManager.running = true
	TimeManager.load_state({"day": 1, "minute_of_day": 430})
	npc.refresh()
	# 20 m in 40 game minutes of 0.5 s = 1 m/s real time, pushing a cart (designed 1.14 m/s).
	var speed := 20.0 / (40.0 * TimeManager.config.seconds_per_game_minute)
	assert_almost(npc.ground_speed(), speed, 0.0001)
	assert_eq(anim.current_animation, "push_cart")
	assert_almost(anim.speed_scale, speed / npc.push_anim_speed, 0.0001)
	TimeManager.push_pause(&"test")
	npc.refresh()
	assert_almost(anim.speed_scale, 0.0, 0.0001, "clock paused: no sliding feet")
	TimeManager.pop_pause(&"test")
	TimeManager.load_state({"day": 1, "minute_of_day": 700})
	npc.refresh()
	assert_eq(anim.current_animation, "talk")
	assert_almost(anim.speed_scale, 1.0, 0.0001)
	TimeManager.running = false


func test_npc_cargo_until_delivery() -> void:
	var npc := await _npc()
	TimeManager.load_state({"day": 1, "minute_of_day": 440})
	npc.refresh()
	assert_true(npc.cargo.visible, "brings a corpse")
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.refresh()
	assert_false(npc.cargo.visible, "delivered")
	GameState.set_flag(&"delivery_skipped", 1)
	npc.refresh()
	assert_true(npc.cargo.visible, "takes it back after a skipped delivery")
	assert_eq(npc.save_state(), {})


# --- Bed (former HutDoor rest / sleep, docs §11) ----------------------------------------------

func test_bed_rest() -> void:
	var bed := _instance(BED_SCENE, Vector3(-3, 0, 3)) as Bed
	await tree.process_frame
	assert_eq(bed.interactable.priority, 5)
	assert_eq(bed.get_interaction_prompt(player), "[E] Ausruhen bis 18:00")
	assert_true(bed.can_interact(player))
	bed.interact(player)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 1080])
	assert_eq(bed.get_interaction_prompt(player), "[E] Schlafen bis 06:00")


func test_bed_sleep_summary_and_autosave() -> void:
	SaveManager.save_dir = TEST_SAVES
	SaveManager.delete_save(0)
	var bed := _instance(BED_SCENE, Vector3(-3, 0, 3)) as Bed
	await tree.process_frame
	TimeManager.set_time(1, 19 * 60)
	GameState.add_stat(&"burials", 2)
	inv.add_item(&"coin", 9)
	bed.interact(player)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(GameState.get_stat(&"days_played"), 1)
	assert_eq(panels.size(), 1)
	assert_eq(panels[0][0], &"day_summary")
	assert_eq(panels[0][1], {"day": 1, "burials_today": 2, "coins_today": 9 - 5, "total": 0, "rating": &"neglected"})
	assert_true(SaveManager.has_save(0), "autosave in slot 0")
	assert_eq(_last_note(), ["Automatisch gespeichert.", &"info"])
	# The next day counts from the new baseline.
	GameState.add_stat(&"burials", 1)
	TimeManager.set_time(2, 20 * 60)
	bed.interact(player)
	assert_eq(panels[1][1].day, 2)
	assert_eq(panels[1][1].burials_today, 1)
	assert_eq(panels[1][1].coins_today, 0)
	assert_eq(GameState.get_stat(&"days_played"), 2)


func test_bed_sleep_after_midnight() -> void:
	SaveManager.save_dir = TEST_SAVES
	var bed := _instance(BED_SCENE, Vector3(-3, 0, 3)) as Bed
	await tree.process_frame
	TimeManager.set_time(2, 60)
	assert_eq(bed.get_interaction_prompt(player), "[E] Schlafen bis 06:00")
	bed.interact(player)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(panels[0][1].day, 1, "the night belongs to the previous day")


func test_bed_blocked_while_carrying() -> void:
	var bed := _instance(BED_SCENE, Vector3(-3, 0, 3)) as Bed
	await tree.process_frame
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(bed.get_interaction_prompt(player), Player.TEXT_HANDS_FULL)
	assert_false(bed.can_interact(player))
	bed.interact(player)
	assert_eq(TimeManager.minute_of_day, START_MINUTE)


# --- HutDoor (portal outside, docs §11) --------------------------------------------------------

func test_hut_door_needs_an_interior() -> void:
	var door := _instance(DOOR_SCENE, Vector3(-3, 0, 3)) as HutDoor
	await tree.process_frame
	assert_eq(door.interactable.priority, 5)
	assert_true(door.is_in_group(&"hut_door"))
	assert_eq(door.get_interaction_prompt(player), "", "no interior in this world: nothing offered")
	assert_false(door.can_interact(player))


func test_hut_door_enter_prompt_and_corpse_stays_outside() -> void:
	var door := _instance(DOOR_SCENE, Vector3(-3, 0, 3)) as HutDoor
	var interior := _instance(INTERIOR_SCENE, Vector3(0, 0, -200)) as HutInterior
	await tree.process_frame
	assert_eq(door.get_interaction_prompt(player), "[E] Hütte betreten")
	assert_true(door.can_interact(player))
	var c := _spawn(&"dropoff")
	corpses.pick_up(c.id, player)
	assert_eq(door.get_interaction_prompt(player), "Leiche draußen ablegen")
	assert_false(door.can_interact(player), "no corpse in the hut")
	var before := player.global_position
	door.interact(player)
	assert_eq(player.global_position, before, "entry refused")
	assert_false(player.in_interior)
	assert_not_null(interior)


# --- helpers ----------------------------------------------------------------------------------

func _instance(path: String, at: Vector3) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.position = at
	world.add_child(node)
	return node


## Two frames: deferred calls (monitorable, shape.disabled) have been flushed.
func _settle() -> void:
	await tree.process_frame
	await tree.process_frame


func _spawn(location: StringName, at: Vector3 = Vector3.ZERO, valuables: bool = false, seed_value: int = 0,
		person: String = "Bert Moor", age: int = 30) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.seed = seed_value
	r.display_name = person
	r.age = age
	r.cause_id = &"fever"
	if valuables:
		r.traits = [CorpseRecord.TRAIT_VALUABLES]
		r.valuables_coins = 6
	var xform := dropoff.slot_transform() if location == &"dropoff" else Transform3D(Basis.IDENTITY, at)
	return corpses.spawn_corpse(r, xform, location)


func _on_table(valuables: bool = false) -> CorpseRecord:
	var c := _spawn(&"ground", Vector3(2, 0, 2), valuables)
	corpses.pick_up(c.id, player)
	table.interact(player)
	return c


func _bury_into_plot() -> CorpseRecord:
	var c := _spawn(&"ground", Vector3(-3, 0, 3))
	corpses.pick_up(c.id, player)
	plot.interact(player)
	return c


func _fill_plot() -> void:
	graveyard.dig("plot_01")
	_bury_into_plot()


func _resource() -> ResourceNode:
	var pile := (load(RESOURCE_SCENE) as PackedScene).instantiate() as ResourceNode
	pile.save_id = "res_wood"
	pile.item_id = &"wood"
	pile.daily_amount = 6
	pile.action_label = "Holz sammeln"
	pile.model = load("res://assets/models/props/ph_prop_wood_pile.glb")
	pile.position = Vector3(3, 0, 3)
	world.add_child(pile)
	return pile


## NPC on a 3-point test path: (0,0,20) -> (0,0,10) -> (10,0,10), schedule 07:00-07:40 walk
## with cart, 07:40 dialogue at the end, 11:00 talk without cart, 12:00 away.
func _npc() -> Npc:
	var ways := WaypointWorld.new()
	ways.points = {&"a": Vector3(0, 0, 20), &"b": Vector3(0, 0, 10), &"c": Vector3(10, 0, 10)}
	world.add_child(ways)
	var sched := NpcSchedule.new()
	sched.npc_id = &"carter"
	sched.display_name = "Osric Faulhaber"
	sched.entries = [
		_entry(0, 0, ["a"], false, false, &"", &"idle"),
		_entry(420, 40, ["a", "b", "c"], true, true, &"", &"idle"),
		_entry(460, 0, ["c"], true, true, &"carter", &"idle"),
		_entry(660, 0, ["c"], true, false, &"carter", &"talk"),
		_entry(720, 0, ["a"], false, false, &"", &"idle"),
	]
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.save_id = "npc_test"
	npc.npc_id = &"carter"
	npc.schedule = sched
	npc.model = load("res://assets/models/characters/ph_chr_carter.glb")
	ways.add_child(npc)
	await tree.process_frame
	return npc


func _entry(start: int, travel: int, path: Array, shown: bool, cart: bool, dialogue: StringName, anim: StringName) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.start_minute = start
	e.travel_minutes = travel
	e.path = PackedStringArray(path)
	e.visible = shown
	e.with_cart = cart
	e.dialogue_id = dialogue
	e.animation = anim
	return e


func _visual_models(target: GravePlot) -> Array:
	var out: Array = []
	for child: Node in target.get_node("Visual").get_children():
		out.append(child.scene_file_path)
	return out


func _last_note() -> Array:
	return notes.back() if not notes.is_empty() else []


func _on_panel(panel: StringName, context: Dictionary) -> void:
	panels.append([panel, context])


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_dialogue(id: StringName, speaker: Node) -> void:
	dialogues.append([id, speaker])


## Round 1: the cart cargo shows the look of the corpse the carter delivers that day.
func test_npc_cargo_shows_the_days_corpse() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	var npc_node: Npc = load("res://src/entities/npc/npc.tscn").instantiate()
	tree.root.add_child(npc_node)
	await tree.process_frame
	for day: int in [1, 2, 3, 4]:
		npc_node.call("_show_cargo_for", day)
		var r := CorpseGenerator.generate(CorpseGenerator.seed_for(day, 0), tables, day)
		var want: String = Npc.CARGO_LOOKS[Corpse.variant_for_record(r, tables, 4)]
		assert_eq(npc_node.cargo.scene_file_path, want, "day %d cargo" % day)
	npc_node.queue_free()
