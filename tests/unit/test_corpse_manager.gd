extends TestCase
## M3: CorpseManager – spawning, delivery rules (§2.5), decay, carrying, examination,
## shroud, valuables, burial, save/load. Uses test doubles for Dropoff, Graveyard and Player.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const SLOT := Transform3D(Basis(Vector3.UP, 0.5), Vector3(2, 0, 3))
const CONTAINER_OFFSET := Vector3(10, 0, -4)


## Dropoff (group "dropoff"): is_free() / slot_transform().
class DropoffDouble extends Node3D:
	var is_open: bool = true
	var slot: Transform3D = SLOT

	func is_free() -> bool:
		return is_open

	func slot_transform() -> Transform3D:
		return slot


## Graveyard (group "graveyard"): only free_plot_count().
class GraveyardDouble extends Node:
	var free_plots: int = 6

	func free_plot_count() -> int:
		return free_plots


## Player stub subclass for the typed pick_up() argument (kept out of the tree).
## attach reparents to itself (like a carry socket); detach removes the node again.
class PlayerDouble extends Player:
	var attach_calls: Array = []
	var detach_calls: int = 0
	## true: detach_carried leaves the node under the socket (caller must reparent).
	var keep_parent: bool = false

	func attach_carried(node: Node3D, id: String) -> void:
		attach_calls.append([node, id])
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
		carried = node
		carried_id = id

	func detach_carried() -> Node3D:
		detach_calls += 1
		var node := carried
		if node != null and node.get_parent() == self and not keep_parent:
			remove_child(node)
		carried = null
		carried_id = ""
		return node


## Duck-typed player in group "player" (for post_load, which looks the player up by group).
class CarrierDouble extends Node3D:
	var attach_calls: Array = []
	var detach_calls: int = 0
	var carried: Node3D

	func attach_carried(node: Node3D, id: String) -> void:
		attach_calls.append([node, id])
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
		carried = node

	func detach_carried() -> Node3D:
		detach_calls += 1
		var node := carried
		if node != null and node.get_parent() == self:
			remove_child(node)
		carried = null
		return node


var tables: CorpseTables
var economy: EconomyConfig
var world: Node3D
var container: Node3D
var manager: CorpseManager
var dropoff: DropoffDouble
var graveyard: GraveyardDouble
var events: Array = []
var _orphans: Array[Node] = []


func before_each() -> void:
	tables = load(FIXTURE_TABLES) as CorpseTables
	economy = load(FIXTURE_ECONOMY) as EconomyConfig
	world = Node3D.new()
	world.name = "World"
	container = Node3D.new()
	container.name = "Corpses"
	container.position = CONTAINER_OFFSET
	world.add_child(container)
	manager = _new_manager()
	world.add_child(manager)
	dropoff = DropoffDouble.new()
	dropoff.add_to_group(&"dropoff")
	world.add_child(dropoff)
	graveyard = GraveyardDouble.new()
	graveyard.add_to_group(&"graveyard")
	world.add_child(graveyard)
	tree.root.add_child(world)
	events.clear()
	EventBus.corpse_arrived.connect(_on_arrived)
	EventBus.corpse_updated.connect(_on_updated)
	EventBus.delivery_skipped.connect(_on_skipped)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.corpse_arrived.disconnect(_on_arrived)
	EventBus.corpse_updated.disconnect(_on_updated)
	EventBus.delivery_skipped.disconnect(_on_skipped)
	EventBus.notification_requested.disconnect(_on_note)
	for node: Node in _orphans:
		if is_instance_valid(node):
			node.free()
	_orphans.clear()


# --- setup & contract ---

func test_groups_and_save_contract() -> void:
	assert_true(manager.is_in_group(&"corpse_manager"))
	assert_true(manager.is_in_group(&"saveable"))
	assert_eq(manager.save_id, "corpse_manager")
	assert_eq(manager.save_order, 0)
	assert_eq(tree.get_first_node_in_group(&"corpse_manager"), manager)


func test_ready_creates_no_content() -> void:
	assert_eq(manager.records(), [])
	assert_eq(manager.unburied_count(), 0)
	assert_eq(container.get_child_count(), 0)
	assert_eq(manager.get_child_count(), 0)
	assert_eq(events, [])
	assert_eq(manager.save_state().corpses, [])


func test_ready_resolves_data_from_database() -> void:
	var plain := CorpseManager.new()
	world.add_child(plain)
	assert_true(plain.tables is CorpseTables, "Database.corpse_tables()")
	assert_eq(plain.tables.resource_path, Database.CORPSE_TABLES)


# --- spawning ---

func test_spawn_generated_corpse() -> void:
	var at := Transform3D(Basis(Vector3.UP, 1.0), Vector3(1, 0, 2))
	var r := manager.spawn_corpse(null, at, &"ground")
	assert_not_null(r)
	assert_eq(r.id, "corpse_0001")
	assert_eq(r.seed, CorpseGenerator.seed_for(1, 0))
	var expected := CorpseGenerator.generate(CorpseGenerator.seed_for(1, 0), tables, 1)
	for key: String in ["display_name", "age", "cause_id", "traits", "valuables_coins", "freshness"]:
		assert_eq(r.to_dict()[key], expected.to_dict()[key], key)
	assert_eq(r.location, &"ground")
	assert_eq(r.position, Vector3(1, 0, 2))
	assert_almost(r.rot_y, 1.0)
	assert_eq(r.arrival_total_minutes, TimeManager.total_minutes())
	assert_eq(r.last_decay_total, TimeManager.total_minutes())
	assert_eq(manager.records(), [r])
	assert_eq(manager.get_record("corpse_0001"), r)
	assert_eq(events, [["arrived", "corpse_0001"]])
	var node := manager.get_corpse_node(r.id)
	assert_true(node is Corpse)
	assert_eq(node.corpse_id, r.id)
	assert_eq(node.get_parent(), container)
	assert_true(node.global_position.is_equal_approx(Vector3(1, 0, 2)), "world position despite container offset")
	assert_almost(node.global_rotation.y, 1.0)
	var second := manager.spawn_corpse()
	assert_eq(second.id, "corpse_0002")
	assert_eq(second.seed, CorpseGenerator.seed_for(1, 1), "next spawn index of the day")
	assert_eq(second.location, &"dropoff")


func test_spawn_given_record() -> void:
	var r := CorpseGenerator.generate(123, tables, 3)
	var spawned := manager.spawn_corpse(r, SLOT, &"table")
	assert_eq(spawned, r)
	assert_eq(r.id, "corpse_0001")
	assert_eq(r.seed, 123)
	assert_eq(r.location, &"table")
	var custom := CorpseRecord.new()
	custom.id = "corpse_0002"
	assert_eq(manager.spawn_corpse(custom), custom, "explicit id kept")
	var third := manager.spawn_corpse(CorpseRecord.new())
	assert_eq(third.id, "corpse_0003", "serial skips ids in use")
	var dup := CorpseRecord.new()
	dup.id = "corpse_0001"
	assert_null(manager.spawn_corpse(dup), "duplicate id refused")
	assert_eq(manager.records().size(), 3)


func test_spawn_refuses_invalid_locations() -> void:
	assert_null(manager.spawn_corpse(null, Transform3D.IDENTITY, &"buried"))
	assert_null(manager.spawn_corpse(null, Transform3D.IDENTITY, &"carried"))
	assert_null(manager.spawn_corpse(null, Transform3D.IDENTITY, &"moon"))
	assert_eq(manager.records(), [])


func test_default_scene_and_self_as_container() -> void:
	var plain := _new_manager()
	plain.container_path = NodePath()
	world.add_child(plain)
	var r := plain.spawn_corpse()
	var node := plain.get_corpse_node(r.id)
	assert_not_null(node)
	assert_eq(node.get_parent(), plain)
	assert_eq(node.scene_file_path, CorpseManager.DEFAULT_CORPSE_SCENE)


func test_missing_container_falls_back_to_manager() -> void:
	var plain := _new_manager()
	plain.container_path = ^"../Nowhere"
	world.add_child(plain)
	var r := plain.spawn_corpse()
	assert_eq(plain.get_corpse_node(r.id).get_parent(), plain)


func test_get_corpse_node_unknown() -> void:
	assert_null(manager.get_corpse_node("corpse_9999"))
	assert_null(manager.get_record("corpse_9999"))


# --- delivery ---

func test_delivery_with_free_dropoff() -> void:
	var r := manager.try_daily_delivery(1)
	assert_not_null(r)
	assert_eq(r.location, &"dropoff")
	assert_eq(r.seed, CorpseGenerator.seed_for(1, 0))
	assert_eq(r.traits, [], "day 1 forced: no traits")
	assert_eq(r.position, SLOT.origin)
	assert_almost(r.rot_y, 0.5)
	assert_true(manager.get_corpse_node(r.id).global_transform.is_equal_approx(SLOT), "placed at slot_transform()")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)
	assert_false(GameState.has_flag(&"delivery_skipped"))
	assert_eq(events, [["arrived", r.id]])


func test_delivery_day_2_has_valuables() -> void:
	var r := manager.try_daily_delivery(2)
	assert_eq(r.traits, [&"valuables"])
	assert_true(r.valuables_coins >= 5 and r.valuables_coins <= 8)
	assert_eq(r.seed, CorpseGenerator.seed_for(2, 0))


func test_delivery_skipped_when_dropoff_occupied() -> void:
	dropoff.is_open = false
	assert_null(manager.try_daily_delivery(1))
	assert_eq(manager.records(), [])
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)
	assert_eq(GameState.get_flag(&"delivery_skipped"), 1)
	assert_eq(events, [["skipped", 1, CorpseManager.REASON_OCCUPIED], ["note", CorpseManager.NOTE_SKIPPED % CorpseManager.REASON_OCCUPIED, &"warning"]])


func test_delivery_needs_more_free_plots_than_unburied_corpses() -> void:
	graveyard.free_plots = 1
	manager.spawn_corpse(null, Transform3D.IDENTITY, &"ground")
	events.clear()
	assert_null(manager.try_daily_delivery(1), "1 free plot, 1 unburied corpse")
	assert_eq(events[0], ["skipped", 1, CorpseManager.REASON_NO_PLOT])
	graveyard.free_plots = 2
	assert_not_null(manager.try_daily_delivery(2), "2 free plots, 1 unburied corpse")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)
	assert_eq(GameState.get_flag(&"delivery_skipped"), 1, "flag keeps the day of the last skip")


func test_delivery_skipped_without_graveyard() -> void:
	graveyard.remove_from_group(&"graveyard")
	assert_null(manager.try_daily_delivery(1))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)


func test_delivery_skipped_without_dropoff() -> void:
	dropoff.remove_from_group(&"dropoff")
	assert_null(manager.try_daily_delivery(1))
	assert_eq(events[0], ["skipped", 1, CorpseManager.REASON_NO_DROPOFF])


func test_no_delivery_after_slice_complete() -> void:
	GameState.set_flag(&"slice_complete", true)
	assert_null(manager.try_daily_delivery(3))
	assert_eq(manager.records(), [])
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0, "not a missed delivery")
	assert_eq(events, [])


func test_delivery_once_per_day() -> void:
	var r := manager.try_daily_delivery(1)
	assert_eq(manager.try_daily_delivery(1), r, "idempotent: same corpse")
	assert_eq(manager.records().size(), 1)
	dropoff.is_open = false
	assert_null(manager.try_daily_delivery(2))
	assert_null(manager.try_daily_delivery(2))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1, "skip counted once")
	dropoff.is_open = true
	assert_null(manager.try_daily_delivery(1), "no delivery for an earlier day")
	assert_eq(manager.records().size(), 1)


func test_delivery_via_time_tick() -> void:
	TimeManager.advance(69)
	assert_eq(TimeManager.format_clock(), "07:39")
	assert_eq(manager.records(), [])
	TimeManager.advance(1)
	assert_eq(manager.records().size(), 1, "delivered at 07:40")
	assert_eq(manager.records()[0].arrival_total_minutes, 460)
	TimeManager.advance(1)
	TimeManager.advance(30)
	assert_eq(manager.records().size(), 1, "once per day")


func test_delivery_via_time_skipped_signal() -> void:
	EventBus.time_skipped.emit(390, 1080)
	assert_eq(manager.records().size(), 1, "time_skipped alone triggers the delivery")
	EventBus.time_skipped.emit(1080, 1440 + 360)
	assert_eq(manager.records().size(), 1, "06:00 on day 2 is too early")
	EventBus.time_skipped.emit(1440 + 360, 1440 + 480)
	assert_eq(manager.records().size(), 2, "day 2 delivery")
	assert_eq(manager.records()[1].traits, [&"valuables"])


func test_rest_over_delivery_time_delivers_once() -> void:
	TimeManager.advance(1080 - 390)
	assert_eq(manager.records().size(), 1)
	var r := manager.records()[0]
	assert_eq(r.arrival_total_minutes, 1080)
	assert_almost(r.freshness, 1.0, 0.0001, "no decay before arrival")


func test_ticks_before_delivery_minute_do_nothing() -> void:
	EventBus.time_tick.emit(1, 459)
	EventBus.time_tick.emit(4, 0)
	assert_eq(manager.records(), [])
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)


func test_skipped_delivery_via_tick() -> void:
	dropoff.is_open = false
	EventBus.time_tick.emit(1, 460)
	EventBus.time_tick.emit(1, 461)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)
	assert_eq(GameState.get_flag(&"delivery_skipped"), 1)


func test_debug_spawn_takes_a_spawn_index() -> void:
	manager.spawn_corpse(null, Transform3D.IDENTITY, &"ground")
	var delivered := manager.try_daily_delivery(1)
	assert_eq(delivered.seed, CorpseGenerator.seed_for(1, 1))


# --- decay ---

func test_decay_from_minute_difference() -> void:
	var r := _spawn(&"drowned")
	TimeManager.advance(90)  # 06:30 -> 08:00: hour 7, hour 8, time_skipped
	assert_almost(r.freshness, 1.0 - 0.05 * 1.5 * 1.5)
	assert_eq(r.last_decay_total, 480)
	EventBus.hour_changed.emit(1, 8)
	assert_almost(r.freshness, 1.0 - 0.05 * 1.5 * 1.5, 0.0001, "same hour again: no double decay")


func test_decay_on_time_skipped_only() -> void:
	var r := _spawn(&"fever")
	EventBus.time_skipped.emit(390, 990)
	assert_almost(r.freshness, 0.5)
	EventBus.hour_changed.emit(1, 16)
	assert_almost(r.freshness, 0.5, 0.0001, "earlier boundary does not decay")
	EventBus.hour_changed.emit(1, 17)
	assert_almost(r.freshness, 0.5 - 0.05 * 0.5)


func test_decay_ignores_time_tick() -> void:
	var r := _spawn(&"fever")
	for minute: int in range(391, 419):
		EventBus.time_tick.emit(1, minute)
	assert_almost(r.freshness, 1.0)


func test_decay_clamps_at_zero() -> void:
	var r := _spawn(&"drowned")
	dropoff.is_open = false
	TimeManager.advance(40 * 60)
	assert_eq(r.freshness, 0.0)
	assert_eq(r.freshness_stage(), &"decaying")


func test_decay_uses_cause_multiplier_and_base_rate() -> void:
	var custom := tables.duplicate() as CorpseTables
	custom.base_decay_per_hour = 0.1
	manager.tables = custom
	var fever := _spawn(&"fever")
	var drowned := _spawn(&"drowned")
	var unknown := _spawn(&"mystery")
	EventBus.time_skipped.emit(390, 510)
	assert_almost(fever.freshness, 0.8)
	assert_almost(drowned.freshness, 0.7)
	assert_almost(unknown.freshness, 0.8, 0.0001, "unknown cause decays with multiplier 1")


func test_corpse_updated_only_on_stage_change() -> void:
	var r := _spawn(&"fever")
	events.clear()
	var stages: Array = []
	for hour: int in range(7, 24):
		EventBus.hour_changed.emit(1, hour)
		stages.append(r.freshness_stage())
	# fresh while (T - 390) <= 480 min, decaying once (T - 390) > 840 min
	assert_eq(events, [["updated", r.id], ["updated", r.id]])
	assert_eq(stages[7], &"fresh", "14:00")
	assert_eq(stages[8], &"wilted", "15:00")
	assert_eq(stages[13], &"wilted", "20:00")
	assert_eq(stages[14], &"decaying", "21:00")


func test_buried_corpse_stops_decaying() -> void:
	var r := _spawn(&"fever")
	EventBus.time_skipped.emit(390, 510)
	manager.mark_buried(r.id, "plot_01")
	var at_burial := r.freshness
	EventBus.time_skipped.emit(510, 2000)
	EventBus.hour_changed.emit(2, 5)
	assert_almost(r.freshness, at_burial)
	assert_almost(r.freshness_at_burial, 0.9)


func test_mark_buried_applies_decay_until_now() -> void:
	var r := _spawn(&"fever")
	TimeManager.load_state({"day": 1, "minute_of_day": 510})  # silent: no signals
	manager.mark_buried(r.id, "plot_01")
	assert_almost(r.freshness, 0.9)
	assert_almost(r.freshness_at_burial, 0.9)
	assert_eq(r.last_decay_total, 510)


# --- carrying ---

func test_pick_up_and_put_down_on_ground() -> void:
	var r := manager.try_daily_delivery(1)
	var node := manager.get_corpse_node(r.id)
	var player := _player()
	events.clear()
	assert_true(manager.pick_up(r.id, player))
	assert_eq(r.location, &"carried")
	assert_eq(player.attach_calls, [[node, r.id]])
	assert_eq(node.get_parent(), player)
	assert_eq(events, [["updated", r.id]])
	var xform := Transform3D(Basis(Vector3.UP, -0.75), Vector3(5, 0, 6))
	events.clear()
	assert_true(manager.put_down(r.id, &"ground", xform))
	assert_eq(player.detach_calls, 1)
	assert_eq(node.get_parent(), container)
	assert_true(node.global_transform.is_equal_approx(xform), "world transform")
	assert_eq(r.location, &"ground")
	assert_eq(r.position, Vector3(5, 0, 6))
	assert_almost(r.rot_y, -0.75)
	assert_eq(events, [["updated", r.id]])
	assert_eq(manager.get_corpse_node(r.id), node, "same node")


func test_put_down_on_table_slot() -> void:
	var r := manager.try_daily_delivery(1)
	var slot := Node3D.new()
	slot.position = Vector3(-3, 1, 2)
	slot.rotation.y = 0.3
	world.add_child(slot)
	var player := _player()
	manager.pick_up(r.id, player)
	var xform := slot.global_transform
	assert_true(manager.put_down(r.id, &"table", xform, slot))
	var node := manager.get_corpse_node(r.id)
	assert_eq(node.get_parent(), slot)
	assert_true(node.transform.is_equal_approx(Transform3D.IDENTITY), "exactly on the slot")
	assert_eq(r.location, &"table")
	assert_true(r.position.is_equal_approx(Vector3(-3, 1, 2)))
	assert_almost(r.rot_y, 0.3)


func test_put_down_when_detach_keeps_the_socket_parent() -> void:
	var r := manager.try_daily_delivery(1)
	var player := _player()
	player.keep_parent = true
	manager.pick_up(r.id, player)
	assert_true(manager.put_down(r.id, &"ground", Transform3D.IDENTITY))
	assert_eq(manager.get_corpse_node(r.id).get_parent(), container)


func test_put_down_without_pick_up_moves_the_corpse() -> void:
	var r := manager.try_daily_delivery(1)
	assert_true(manager.put_down(r.id, &"ground", Transform3D(Basis(), Vector3(1, 0, 1))))
	assert_eq(r.location, &"ground")
	assert_true(manager.get_corpse_node(r.id).global_position.is_equal_approx(Vector3(1, 0, 1)))


func test_pick_up_refusals() -> void:
	var a := manager.try_daily_delivery(1)
	var b := _spawn(&"fever")
	var player := _player()
	assert_false(manager.pick_up("corpse_9999", player), "unknown")
	assert_false(manager.pick_up(a.id, null), "no player")
	assert_true(manager.pick_up(a.id, player))
	assert_false(manager.pick_up(a.id, player), "already carried")
	assert_false(manager.pick_up(b.id, _player()), "only one corpse can be carried")
	manager.put_down(a.id, &"ground", Transform3D.IDENTITY)
	var busy := _player()
	busy.carried = Node3D.new()
	_orphans.append(busy.carried)
	assert_false(manager.pick_up(b.id, busy), "hands not free")
	manager.mark_buried(a.id, "plot_01")
	assert_false(manager.pick_up(a.id, player), "buried")
	assert_eq(b.location, &"ground")


func test_put_down_refusals() -> void:
	var r := manager.try_daily_delivery(1)
	var player := _player()
	manager.pick_up(r.id, player)
	assert_false(manager.put_down("corpse_9999", &"ground", Transform3D.IDENTITY))
	assert_false(manager.put_down(r.id, &"buried", Transform3D.IDENTITY))
	assert_false(manager.put_down(r.id, &"carried", Transform3D.IDENTITY))
	assert_false(manager.put_down(r.id, &"moon", Transform3D.IDENTITY))
	assert_eq(r.location, &"carried", "refusals change nothing")
	assert_eq(player.detach_calls, 0)
	manager.mark_buried(r.id, "plot_01")
	assert_false(manager.put_down(r.id, &"ground", Transform3D.IDENTITY), "buried")


# --- examine, shroud, valuables ---

func test_examine() -> void:
	var r := _spawn(&"fever", [&"letter"])
	events.clear()
	assert_eq(r.revealed_traits(), [])
	manager.examine(r.id)
	assert_true(r.examined)
	assert_eq(r.revealed_traits(), [&"letter"])
	assert_eq(events, [["updated", r.id]])
	manager.examine(r.id)
	assert_eq(events.size(), 1, "second examine changes nothing")
	manager.examine("corpse_9999")


func test_apply_shroud_needs_a_shroud() -> void:
	var r := _spawn(&"fever")
	var inv := _inventory()
	assert_false(manager.apply_shroud(r.id, inv), "no shroud")
	assert_false(manager.apply_shroud(r.id, null), "no inventory")
	assert_false(r.shrouded)
	inv.add_item(&"shroud", 2)
	events.clear()
	assert_true(manager.apply_shroud(r.id, inv))
	assert_true(r.shrouded)
	assert_eq(inv.count(&"shroud"), 1)
	assert_eq(events, [["updated", r.id]])
	assert_false(manager.apply_shroud(r.id, inv), "already shrouded")
	assert_eq(inv.count(&"shroud"), 1, "no second shroud used")


func test_apply_shroud_blocked_while_valuables_undecided() -> void:
	var r := _spawn(&"fever", [&"valuables"])
	var inv := _inventory()
	inv.add_item(&"shroud", 1)
	manager.examine(r.id)
	assert_false(manager.apply_shroud(r.id, inv))
	assert_eq(inv.count(&"shroud"), 1)
	manager.decide_valuables(r.id, false, inv)
	assert_true(manager.apply_shroud(r.id, inv))


func test_apply_shroud_before_examination_is_allowed() -> void:
	var r := _spawn(&"fever", [&"valuables"])
	var inv := _inventory()
	inv.add_item(&"shroud", 1)
	assert_true(manager.apply_shroud(r.id, inv), "valuables not revealed yet")


func test_decide_valuables_take() -> void:
	var r := _spawn(&"fever", [&"valuables"])
	var inv := _inventory()
	manager.examine(r.id)
	events.clear()
	manager.decide_valuables(r.id, true, inv)
	assert_eq(r.valuables_decision, &"taken")
	assert_eq(inv.count(&"coin"), r.valuables_coins)
	assert_eq(inv.count(&"coin"), 6)
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)
	assert_eq(GameState.get_stat(&"reputation"), -1)
	assert_eq(events, [["updated", r.id]])
	manager.decide_valuables(r.id, false, inv)
	manager.decide_valuables(r.id, true, inv)
	assert_eq(r.valuables_decision, &"taken", "final")
	assert_eq(inv.count(&"coin"), 6, "coins only once")
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)


func test_decide_valuables_leave() -> void:
	var r := _spawn(&"fever", [&"valuables"])
	var inv := _inventory()
	manager.examine(r.id)
	manager.decide_valuables(r.id, false, inv)
	assert_eq(r.valuables_decision, &"left")
	assert_eq(inv.count(&"coin"), 0)
	assert_eq(GameState.get_stat(&"valuables_taken"), 0)
	assert_eq(GameState.get_stat(&"reputation"), 0)
	manager.decide_valuables(r.id, true, inv)
	assert_eq(inv.count(&"coin"), 0, "final")


func test_decide_valuables_refusals() -> void:
	var hidden := _spawn(&"fever", [&"valuables"])
	var none := _spawn(&"fever")
	var inv := _inventory()
	manager.decide_valuables(hidden.id, true, inv)
	assert_eq(hidden.valuables_decision, &"", "not examined")
	manager.examine(none.id)
	manager.decide_valuables(none.id, true, inv)
	assert_eq(none.valuables_decision, &"", "no valuables")
	manager.examine(hidden.id)
	manager.decide_valuables(hidden.id, true, null)
	assert_eq(hidden.valuables_decision, &"", "take needs an inventory")
	assert_eq(inv.count(&"coin"), 0)
	manager.decide_valuables("corpse_9999", true, inv)


func test_valuables_reputation_from_economy() -> void:
	var custom := economy.duplicate() as EconomyConfig
	custom.valuables_reputation = -3
	manager.economy = custom
	var r := _spawn(&"fever", [&"valuables"])
	manager.examine(r.id)
	manager.decide_valuables(r.id, true, _inventory())
	assert_eq(GameState.get_stat(&"reputation"), -3)


# --- burial ---

func test_mark_buried() -> void:
	var r := _spawn(&"fever")
	var other := _spawn(&"fever")
	var node := manager.get_corpse_node(r.id)
	events.clear()
	manager.mark_buried(r.id, "plot_02")
	assert_eq(r.location, &"buried")
	assert_eq(r.grave_id, "plot_02")
	assert_almost(r.freshness_at_burial, 1.0)
	assert_null(manager.get_corpse_node(r.id))
	assert_null(node.get_parent(), "removed from the tree at once")
	assert_eq(container.get_children(), [manager.get_corpse_node(other.id)])
	assert_eq(manager.unburied_count(), 1)
	assert_eq(manager.records().size(), 2, "buried records stay")
	assert_eq(events, [["updated", r.id]])
	await tree.process_frame
	assert_false(is_instance_valid(node), "node freed")
	manager.mark_buried(r.id, "plot_03")
	assert_eq(r.grave_id, "plot_02", "second burial ignored")


func test_mark_buried_leaves_open_valuables() -> void:
	var examined := _spawn(&"fever", [&"valuables"])
	var hidden := _spawn(&"fever", [&"valuables"])
	manager.examine(examined.id)
	manager.mark_buried(examined.id, "plot_01")
	manager.mark_buried(hidden.id, "plot_02")
	assert_eq(examined.valuables_decision, &"left", "examined & undecided -> left")
	assert_eq(hidden.valuables_decision, &"", "never revealed -> no decision")


func test_mark_buried_keeps_taken_decision() -> void:
	var r := _spawn(&"fever", [&"valuables"])
	manager.examine(r.id)
	manager.decide_valuables(r.id, true, _inventory())
	manager.mark_buried(r.id, "plot_01")
	assert_eq(r.valuables_decision, &"taken")


func test_mark_buried_while_carried_detaches() -> void:
	var r := _spawn(&"fever")
	var player := _player()
	manager.pick_up(r.id, player)
	manager.mark_buried(r.id, "plot_01")
	assert_eq(player.detach_calls, 1)
	assert_null(player.carried)
	assert_eq(player.get_child_count(), 0)
	assert_eq(r.location, &"buried")


# --- save / load ---

func test_save_load_round_trip() -> void:
	var carrier := _carrier()
	_build_mixed_state()
	var before := manager.save_state()
	var old_nodes := container.get_children()
	manager.load_state(_json_round_trip(before))
	manager.post_load()
	assert_eq(manager.save_state(), before)
	for node: Node in old_nodes:
		assert_false(node.is_inside_tree(), "old nodes removed")
		assert_true(node.is_queued_for_deletion(), "old nodes freed")
	assert_eq(container.get_child_count(), 4, "delivered, table, ground, debug spawn – not buried/carried")
	var carried := manager.records().filter(func(r: CorpseRecord) -> bool: return r.location == &"carried")
	assert_eq(carried.size(), 1)
	var carried_node := manager.get_corpse_node(carried[0].id)
	assert_eq(carried_node.get_parent(), carrier, "post_load re-attached")
	assert_eq(carrier.attach_calls, [[carried_node, carried[0].id]])
	for r: CorpseRecord in manager.records():
		var node := manager.get_corpse_node(r.id)
		if r.location == &"buried":
			assert_null(node)
		else:
			assert_eq(node.corpse_id, r.id)
			if r.location != &"carried":
				assert_true(node.global_position.is_equal_approx(r.position), "recreated at its position")


func test_collect_state_round_trip_via_save_manager() -> void:
	_carrier()
	_build_mixed_state()
	GameState.add_stat(&"burials", 1)
	var a := SaveManager.collect_state()
	SaveManager.apply_state(_json_round_trip(a))
	var b := SaveManager.collect_state()
	assert_eq(b, a)
	assert_true(a.nodes.has("corpse_manager"))


func test_load_restores_bookkeeping() -> void:
	var delivered := manager.try_daily_delivery(1)
	manager.spawn_corpse()
	var saved := _json_round_trip(manager.save_state())
	manager.load_state({})
	world.remove_child(manager)
	_orphans.append(manager)
	var fresh := _new_manager()
	world.add_child(fresh)
	fresh.load_state(saved)
	assert_eq(fresh.try_daily_delivery(1).id, delivered.id, "day 1 already delivered")
	assert_eq(fresh.records().size(), 2)
	var next := fresh.spawn_corpse()
	assert_eq(next.id, "corpse_0003", "serial continues")
	assert_eq(next.seed, CorpseGenerator.seed_for(1, 2), "spawn index continues")
	EventBus.time_tick.emit(1, 500)
	assert_eq(fresh.records().size(), 3, "no second delivery after loading")


func test_load_state_replaces_everything() -> void:
	_build_mixed_state()
	manager.load_state({})
	assert_eq(manager.records(), [])
	assert_eq(manager.unburied_count(), 0)
	assert_eq(container.get_child_count(), 0)
	assert_eq(manager.save_state(), {"corpses": [], "next_serial": 1, "last_delivery_day": 0, "last_delivery_id": "", "spawn_counts": {}})
	assert_not_null(manager.try_daily_delivery(1), "delivery possible again")


func test_load_state_is_idempotent() -> void:
	_build_mixed_state()
	var saved := manager.save_state()
	manager.load_state(saved)
	manager.load_state(saved)
	assert_eq(manager.save_state(), saved)
	assert_eq(container.get_child_count(), 5, "no duplicate nodes (the carried one waits for post_load)")


func test_load_state_accepts_plain_json() -> void:
	var r := manager.try_daily_delivery(1)
	manager.examine(r.id)
	var saved := manager.save_state()
	var plain: Dictionary = JSON.parse_string(JSON.stringify(saved))
	manager.load_state(plain)
	assert_eq(manager.save_state(), saved)
	var loaded := manager.get_record(r.id)
	assert_true(loaded.cause_id is StringName)
	assert_eq(typeof(loaded.seed), TYPE_INT)
	assert_eq(loaded.position, SLOT.origin)


func test_load_state_skips_bad_entries() -> void:
	var good := CorpseRecord.new()
	good.id = "corpse_0004"
	good.location = &"ground"
	manager.load_state({"corpses": [good.to_dict(), "junk", {"display_name": "no id"}, good.to_dict()], "next_serial": "x", "spawn_counts": {"a": 1, 2: -1}})
	assert_eq(manager.records().size(), 1)
	assert_eq(manager.spawn_corpse().id, "corpse_0001", "bad serial -> 1")
	assert_eq(manager.save_state().spawn_counts, {1: 1})


func test_post_load_without_player_puts_corpse_on_ground() -> void:
	var r := _spawn(&"fever")
	manager.pick_up(r.id, _player())
	var saved := manager.save_state()
	manager.load_state(saved)
	events.clear()
	manager.post_load()
	assert_eq(manager.get_record(r.id).location, &"ground")
	assert_eq(manager.get_corpse_node(r.id).get_parent(), container)
	assert_eq(events, [["updated", r.id]])


func test_load_state_releases_the_carrier() -> void:
	var r := _spawn(&"fever")
	var player := _player()
	manager.pick_up(r.id, player)
	manager.load_state(manager.save_state())
	assert_eq(player.detach_calls, 1)
	assert_null(player.carried)


func test_put_down_after_load_detaches_the_group_player() -> void:
	var carrier := _carrier()
	var r := _spawn(&"fever")
	manager.pick_up(r.id, _player())
	manager.load_state(manager.save_state())
	manager.post_load()
	assert_true(manager.put_down(r.id, &"ground", Transform3D.IDENTITY))
	assert_eq(carrier.detach_calls, 1)
	assert_eq(manager.get_corpse_node(r.id).get_parent(), container)


# --- helpers ---

## dropoff (delivered), table, ground (examined, shrouded, valuables taken), buried, carried.
func _build_mixed_state() -> void:
	var inv := _inventory()
	inv.add_item(&"shroud", 1)
	manager.try_daily_delivery(1)
	var table := _spawn(&"drowned", [&"letter"], &"table", Transform3D(Basis(Vector3.UP, 0.25), Vector3(-2, 1, 0)))
	manager.examine(table.id)
	var ground := _spawn(&"fever", [&"valuables", &"letter"], &"ground", Transform3D(Basis(), Vector3(4, 0, 4)))
	manager.examine(ground.id)
	manager.decide_valuables(ground.id, true, inv)
	manager.apply_shroud(ground.id, inv)
	var buried := _spawn(&"fever")
	EventBus.time_skipped.emit(460, 600)
	manager.mark_buried(buried.id, "plot_01")
	var carried := _spawn(&"drowned")
	manager.spawn_corpse()
	manager.pick_up(carried.id, _player())


func _spawn(cause: StringName, traits: Array[StringName] = [], location: StringName = &"ground", at: Transform3D = Transform3D.IDENTITY) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = "Anna Moor"
	r.age = 40
	r.cause_id = cause
	r.traits = traits
	r.valuables_coins = 6 if r.has_trait(&"valuables") else 0
	return manager.spawn_corpse(r, at, location)


func _new_manager() -> CorpseManager:
	var m := CorpseManager.new()
	m.name = "CorpseManager"
	m.tables = tables
	m.economy = economy
	m.container_path = ^"../Corpses"
	return m


func _player() -> PlayerDouble:
	var player := PlayerDouble.new()
	_orphans.append(player)
	return player


func _carrier() -> CarrierDouble:
	var carrier := CarrierDouble.new()
	carrier.add_to_group(&"player")
	world.add_child(carrier)
	return carrier


func _inventory() -> Inventory:
	var inv: Inventory = FakeInventory.new()
	_orphans.append(inv)
	return inv


func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(data))))


func _on_arrived(id: String) -> void:
	events.append(["arrived", id])


func _on_updated(id: String) -> void:
	events.append(["updated", id])


func _on_skipped(day: int, reason: String) -> void:
	events.append(["skipped", day, reason])


func _on_note(text: String, kind: StringName) -> void:
	events.append(["note", text, kind])
