extends TestCase
## G8 Runde 3 (user: „ich dachte die neuen leichen werden mit dem holz wagen hergebracht") in the real world: every new
## corpse comes on Osric's handcart – it lies on the cart until he has unloaded it, he carries it over in the minutes
## before 07:40 and only at the delivery minute it lies on the bier (and counts as delivered); the cart load is the plan
## of the real delivery (same seed, look, story corpse; an occupied bier keeps it on the cart); skips, loads and the
## gravekeeper's absence end in the same state; the save format stays v7 (nothing new is saved).

const TIMEOUT := 120.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
var TEST_SAVES := TestCase.user_dir("test_cart_delivery")
const SLOT := 7

var world: WorldRoot
var manager: CorpseManager
var npc: Npc
var tables: CorpseTables
var cfg: CartDeliveryConfig


func before_each() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	manager = world.corpse_manager
	npc = world.get_node_by_layout_id("npc_carter") as Npc
	tables = Database.corpse_tables() as CorpseTables
	cfg = Database.config(&"cart_delivery_config") as CartDeliveryConfig


func after_each() -> void:
	TestCase.remove_user_dir(TEST_SAVES)


## The real new game (SaveManager) instead of the bare world; the clock stopped.
func _new_game() -> void:
	tree.root.remove_child(world)
	world.free()
	await SaveManager.new_game()
	TimeManager.running = false
	world = tree.current_scene as WorldRoot
	manager = world.corpse_manager
	npc = world.get_node_by_layout_id("npc_carter") as Npc


## Clock to `minute` of `day` silently, the carter placed for it.
func _at(day: int, minute: int, frac: float = 0.0) -> void:
	TimeManager.load_state({"day": day, "minute_of_day": minute})
	TimeManager.set(&"_accum", frac * TimeManager.config.seconds_per_game_minute)
	npc.refresh()
	await tree.process_frame


## The clock runs minute by minute (every time_tick as in play) up to `minute`.
func _run_to(minute: int) -> void:
	while TimeManager.minute_of_day < minute:
		TimeManager.advance(1)
		await tree.process_frame


func _on_bier() -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF:
			out.append(r)
	return out


func _bier() -> Dropoff:
	return world.get_node_by_layout_id("dropoff") as Dropoff


func test_the_corpse_comes_on_the_cart() -> void:
	await _at(1, 440)
	var cl := manager.cart_load(1, 440)
	assert_eq((cl.unload as Array).size(), 1, "today's corpse is on the cart")
	assert_true(npc.cargo.visible and npc.cargo.is_visible_in_tree(), "the cart shows it on the way")
	assert_eq(npc.cargo_count(), 1)
	assert_true(npc.cargo.global_position.distance_to(npc.cart.global_position) < 1.0, "on the cart")
	assert_true(_on_bier().is_empty(), "the bier is empty while he comes")
	# the cargo wears the look of the corpse he delivers
	var preview: CorpseRecord = (cl.unload as Array)[0]
	var want := Corpse.look_path(Corpse.look_of(preview, tables, Npc.CARGO_LOOKS.size()), Npc.CARGO_LOOKS)
	assert_eq(npc.cargo.scene_file_path, want, "cargo look")


func test_delivered_only_when_unloaded() -> void:
	await _at(1, cfg.unload_start(tables.delivery_minute) - 2)
	var preview: CorpseRecord = (manager.cart_load(1, TimeManager.minute_of_day).unload as Array)[0]
	await _run_to(cfg.unload_start(tables.delivery_minute) + 1)
	assert_true(bool(npc.unload_pose().get("active", false)), "he unloads")
	assert_false(npc.is_talkable(), "no prompt while unloading")
	assert_true(_on_bier().is_empty(), "not delivered yet")
	await _run_to(tables.delivery_minute - 1)
	assert_true(_on_bier().is_empty(), "07:39 still on its way onto the bier")
	assert_true(npc.cargo.visible, "the cargo is the corpse in his hands")
	# the last moment of the lowering: the cargo lies on the bier slot
	TimeManager.set(&"_accum", 0.999 * TimeManager.config.seconds_per_game_minute)
	npc.refresh()
	assert_true(npc.cargo.global_position.distance_to(_bier().slot_transform().origin) < 0.02, "laid onto the bier")
	var laid := npc.cargo.global_transform
	TimeManager.set(&"_accum", 0.0)
	await _run_to(tables.delivery_minute)
	var arrived := _on_bier()
	assert_eq(arrived.size(), 1, "07:40: on the bier, delivered")
	var record := arrived[0]
	assert_eq(record.seed, preview.seed, "the corpse that was on the cart")
	assert_eq(record.display_name, preview.display_name)
	assert_eq(record.arrival_total_minutes, tables.delivery_minute, "arrival = the delivery minute (freshness from 07:40)")
	var node := manager.get_corpse_node(record.id)
	assert_true(node.global_position.distance_to(laid.origin) < 0.02, "the real corpse lies where he laid it")
	assert_true(node.global_basis.get_rotation_quaternion().angle_to(laid.basis.get_rotation_quaternion()) < 0.05, "same way round")
	assert_eq(node.visual_variant(), Corpse.look_of(preview, tables, 4), "same look")
	assert_eq(npc.cargo_count(), 0, "the cart is empty")
	assert_true(bool(npc.unload_pose().get("active", false)), "he walks back to the handles")
	assert_false(npc.is_talkable())
	await _run_to(tables.delivery_minute + cfg.return_minutes)
	assert_false(bool(npc.unload_pose().get("active", false)))
	assert_true(npc.is_talkable(), "then he talks at the cart")
	assert_eq(npc.get_node("Model").position, Vector3.ZERO, "back at the handles")


func test_occupied_bier_keeps_it_on_the_cart() -> void:
	await _at(1, 430)
	manager.spawn_corpse(null, _bier().slot_transform(), CorpseRecord.LOCATION_DROPOFF)
	await _at(1, cfg.unload_start(tables.delivery_minute) + 3)
	assert_false(bool(npc.unload_pose().get("active", false)), "nowhere to put it")
	assert_eq(npc.cargo_count(), 1, "stays on the cart")
	assert_true(npc.cargo.global_position.distance_to(npc.cart.global_position) < 1.0)
	await _run_to(tables.delivery_minute + 5)
	assert_eq(_on_bier().size(), 1, "no second corpse")
	assert_eq(GameState.get_flag(&"delivery_skipped"), 1)
	assert_eq(npc.cargo_count(), 1, "he takes it back")
	assert_true(npc.is_talkable())
	await _at(1, 590)
	assert_eq(npc.cargo_count(), 1, "all morning")


## A skip over the unloading (rest, debug „time") and a load land in the delivered state: corpse on the bier, cart empty.
func test_skip_lands_delivered() -> void:
	await _at(1, 390)
	TimeManager.set_time(1, 470)
	npc.refresh()
	await tree.process_frame
	assert_eq(_on_bier().size(), 1, "delivered inside the skip")
	assert_eq(_on_bier()[0].arrival_total_minutes, tables.delivery_minute)
	assert_eq(npc.cargo_count(), 0, "cart empty")
	assert_false(bool(npc.unload_pose().get("active", false)))
	assert_eq(npc.get_node("Model").position, Vector3.ZERO)
	# into the middle of the unloading and out of it again
	await _at(2, cfg.unload_start(tables.delivery_minute) + 4)
	assert_true(_on_bier().size() == 1, "yesterday's corpse still lies there")


func test_skip_into_the_unloading() -> void:
	await _at(1, 390)
	TimeManager.set_time(1, cfg.unload_start(tables.delivery_minute) + 3)
	npc.refresh()
	await tree.process_frame
	assert_true(_on_bier().is_empty())
	assert_true(bool(npc.unload_pose().get("active", false)), "a skip into the unloading shows him unloading")
	assert_eq(npc.cargo_count(), 1)


func test_away_in_the_village() -> void:
	await _at(1, 440)
	EventBus.region_changed.emit(&"village")
	await _run_to(tables.delivery_minute + 10)
	assert_eq(_on_bier().size(), 1, "delivered while the gravekeeper is in the village")
	EventBus.region_changed.emit(&"graveyard")
	await tree.process_frame
	assert_eq(npc.cargo_count(), 0, "back: the cart is empty")
	assert_false(bool(npc.unload_pose().get("active", false)))


## Save / load in the middle of the unloading: the same pose (the clock is all it needs); nothing new is saved.
func test_load_mid_unloading() -> void:
	SaveManager.save_dir = TEST_SAVES
	await _new_game()
	await _at(1, cfg.unload_start(tables.delivery_minute) + 4)
	var before := npc.unload_pose().duplicate()
	var keys := manager.save_state().keys()
	assert_eq(npc.save_state(), {}, "the carter saves nothing")
	assert_false(keys.has("cart") or keys.has("unload"), "no new save keys (format v7)")
	assert_eq(SaveManager.save_game(SLOT), OK)
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, SLOT)))
	assert_eq(int((doc as Dictionary).format_version), 7, "format v7")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	world = tree.current_scene as WorldRoot
	manager = world.corpse_manager
	npc = world.get_node_by_layout_id("npc_carter") as Npc
	npc.refresh()
	var after := npc.unload_pose()
	assert_true(bool(after.get("active", false)), "unloading after the load")
	assert_eq(after.anim, before.anim)
	assert_true((after.figure as Vector3).distance_to(before.figure) < 0.01, "same place")
	assert_true(_on_bier().is_empty(), "not delivered yet")
	await _run_to(tables.delivery_minute)
	assert_eq(_on_bier().size(), 1, "delivered at 07:40 after the load")


## A Phase-7 save (format v6, tests/fixtures/saves_v6) loaded at 07:00: the cart carries exactly what the real delivery
## brings, and that lies on the bier at 07:40.
func test_v6_save_delivers_from_the_cart() -> void:
	SaveManager.save_dir = TEST_SAVES
	tree.root.remove_child(world)
	world.free()
	assert_eq(Phase8Fixtures.install_save_v6("slot_p7_day53_neighbor", TEST_SAVES, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	world = tree.current_scene as WorldRoot
	manager = world.corpse_manager
	npc = world.get_node_by_layout_id("npc_carter") as Npc
	var day := TimeManager.day
	var cl := manager.cart_load(day, TimeManager.minute_of_day)
	var planned := (cl.unload as Array).size()
	var kept := (cl.keep as Array).size()
	var before := _on_bier().size()
	await _run_to(cfg.unload_start(tables.delivery_minute) - 1)
	assert_eq(npc.cargo_count(), mini(planned + kept, cfg.max_cargo), "the cart shows the plan")
	await _run_to(tables.delivery_minute)
	assert_eq(_on_bier().size(), before + planned, "what was unloaded lies on the bier")
	assert_eq(npc.cargo_count(), (manager.cart_load(day, TimeManager.minute_of_day).keep as Array).size(), "the rest stays on the cart")


## A story corpse comes on the cart in its own look (S3 Wernstein, look 5 – the old cargo showed a random plain look).
func test_story_corpse_on_the_cart() -> void:
	var story := Database.story_corpse(&"s3_wernstein") as StoryCorpseData
	assert_eq(story.look, 5)
	var list: Array[StoryCorpseData] = [story]
	manager.stories = list
	await _at(story.earliest_day, 440)
	var cl := manager.cart_load(TimeManager.day, 440)
	assert_eq(((cl.unload as Array)[0] as CorpseRecord).story_id, &"s3_wernstein", "the story corpse is on the cart")
	assert_eq(npc.cargo.scene_file_path, Corpse.look_path(5, Npc.CARGO_LOOKS), "in its own look")
	await _run_to(tables.delivery_minute)
	assert_eq(_on_bier().size(), 1)
	assert_eq(_on_bier()[0].story_id, &"s3_wernstein")
	assert_eq(manager.get_corpse_node(_on_bier()[0].id).visual_variant(), 5, "the same look on the bier")


## A day without a delivery (disreputable on an even day) – an empty cart, not a corpse that vanishes at 07:40.
func test_no_delivery_empty_cart() -> void:
	GameState.stats[&"reputation"] = 0
	await _at(2, 440)
	assert_eq(manager.deliveries_due(2), 0, "disreputable: nothing on even days")
	assert_true(npc.cart.visible, "he comes with the cart")
	assert_eq(npc.cargo_count(), 0, "nothing on it")
	await _run_to(tables.delivery_minute + 1)
	assert_true(_on_bier().is_empty())
	assert_false(bool(npc.unload_pose().get("active", false)))
