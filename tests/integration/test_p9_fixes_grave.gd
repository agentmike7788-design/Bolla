extends TestCase
## Phase 9 W3 „Restbedarf“ 1 (docs/reviews/phase9_round1/fixes/fixes.md): the grave's prompts in the generated
## graveyard world – Gesa's straw flowers (GraveCare.straw_block_reason / lay_straw) as „[E] Strohblumen aufs Grab
## legen“, and „Datum vergleichen“ (H2) before the flowers.

const WORLD := "res://src/world/graveyard/graveyard.tscn"


## What the grave asks of WhoKnows (the real one needs the whole chain; test_letters_flow uses the same double).
class WhoKnowsDouble extends Node:
	var config := WhoKnowsConfig.new()
	var compared: Array[String] = []
	var comparable: Array[String] = []

	func _init() -> void:
		add_to_group(&"who_knows")

	func can_compare(grave_id: String) -> bool:
		return comparable.has(grave_id) and not compared.has(grave_id)

	func compare_grave(grave_id: String) -> bool:
		compared.append(grave_id)
		return true

	func reserved_plot_count() -> int:
		return 0


var world: WorldRoot
var player: Player
var corpses: CorpseManager
var graveyard: Graveyard
var care: GraveCare


func before_each() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	player = world.get_player()
	player.set_physics_process(false)
	player.instant_actions = true
	corpses = tree.get_first_node_in_group(&"corpse_manager") as CorpseManager
	graveyard = tree.get_first_node_in_group(&"graveyard") as Graveyard
	care = tree.get_first_node_in_group(&"grave_care") as GraveCare
	var who := world.get_node_or_null("Systems/WhoKnows")
	if who != null:
		who.get_parent().remove_child(who)
		who.free()


func after_each() -> void:
	if is_instance_valid(player):
		player.cancel_timed_action()
	Audio.reset()
	if is_instance_valid(world):
		tree.root.remove_child(world)
		world.free()
	world = null
	player = null


func _buried_plot() -> GravePlot:
	var r := corpses.spawn_corpse()
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.EMPTY:
			graveyard.dig(g.id)
			assert_true(graveyard.bury(g.id, r.id))
			for n: Node in tree.get_nodes_in_group(&"grave_plot"):
				if (n as GravePlot).grave_id == g.id:
					return n as GravePlot
	return null


func test_straw_flowers_have_their_prompt_and_are_laid() -> void:
	var plot := _buried_plot()
	assert_not_null(plot)
	assert_not_null(care)
	player.inventory.add_item(&"straw_bouquet", 1)
	var minutes := care.get_config().plant_minutes
	assert_true(plot.can_interact(player))
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_STRAW % minutes)
	plot.interact(player)
	assert_true(care.is_straw(plot.grave_id), "laid through GraveCare.lay_straw")
	assert_eq(player.inventory.count(&"straw_bouquet"), 0)
	assert_ne(plot.get_interaction_prompt(player), GravePlot.PROMPT_STRAW % minutes, "flowers on the grave now")


func test_seedlings_first_straw_afterwards_on_another_grave() -> void:
	var plot := _buried_plot()
	player.inventory.add_item(&"straw_bouquet", 1)
	player.inventory.add_item(&"flower_seedlings", 1)
	var minutes := care.get_config().plant_minutes
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_PLANT % minutes, "Phase-8 order kept")
	plot.interact(player)
	var other := _buried_plot()
	assert_eq(other.get_interaction_prompt(player), GravePlot.PROMPT_STRAW % minutes)


func test_compare_the_date_before_the_flowers() -> void:
	var who := WhoKnowsDouble.new()
	world.add_child(who)
	var plot := _buried_plot()
	who.comparable.append(plot.grave_id)
	for item: StringName in [&"flower_seedlings", &"wax_wreath", &"straw_bouquet"]:
		player.inventory.add_item(item, 1)
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_DATE % 5, "date first")
	plot.interact(player)
	assert_eq(who.compared, [plot.grave_id] as Array[String], "the date was compared, nothing planted")
	assert_eq(care.flowers_state(plot.grave_id), &"")
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_PLANT % care.get_config().plant_minutes,
			"then the flowers")


func test_closing_a_disturbed_grave_still_before_the_date() -> void:
	assert_eq(GravePlot.P9_DATE_AFTER, [GravePlot.CARE_COINS, GravePlot.CARE_CLOSE] as Array[StringName])
	var plot := _buried_plot()
	assert_true(plot._date_first(GravePlot.CARE_PLANT))
	assert_true(plot._date_first(GravePlot.CARE_STRAW))
	assert_true(plot._date_first(&""))
	assert_false(plot._date_first(GravePlot.CARE_CLOSE))
