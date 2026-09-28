extends TestCase
## M3: CorpseManager – spawning, delivery rules (§2.5; Phase 3 §2.7: deliveries per tier, a
## free bier per corpse, missed deliveries, no end at slice_complete), decay, carrying,
## examination, shroud, valuables, burial, save/load. Uses test doubles for Dropoff, Graveyard and Player.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const REAL_TABLES := "res://data/corpses/corpse_tables.tres"
const REAL_ECONOMY := "res://data/config/economy_config.tres"
const CARTER_DIALOGUE := "res://data/dialogue/carter.tres"
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


## Dropoff that is occupied while a dropoff corpse lies on its slot (like the real Dropoff,
## but per bier).
class BierDouble extends DropoffDouble:
	func is_free() -> bool:
		var m := get_tree().get_first_node_in_group(&"corpse_manager") as CorpseManager
		for r: CorpseRecord in m.records():
			if r.location == &"dropoff" and r.position.is_equal_approx(slot.origin):
				return false
		return is_open


## CorpseManager with a fixed number of deliveries per day (instead of the reputation tier).
class DueManager extends CorpseManager:
	var due: int = 1

	func deliveries_due(_day: int) -> int:
		return due


## Reputation (group "reputation"): fixed tier, records change / event calls.
class ReputationDouble extends Reputation:
	var fixed_tier: StringName = &""
	var calls: Array = []

	func tier() -> StringName:
		return fixed_tier

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


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


## Lead decision (GP-04 follow-up): when every free plot is already reserved by a waiting corpse,
## the cemetery is full for good – no delivery, and it is NOT a missed delivery (quiet stop).
func test_delivery_needs_more_free_plots_than_unburied_corpses() -> void:
	graveyard.free_plots = 1
	manager.spawn_corpse(null, Transform3D.IDENTITY, &"ground")
	events.clear()
	assert_null(manager.try_daily_delivery(1), "1 free plot, 1 unburied corpse")
	assert_eq(events, [], "quiet stop, no skip signal")
	graveyard.free_plots = 2
	assert_not_null(manager.try_daily_delivery(2), "2 free plots, 1 unburied corpse")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)
	assert_false(GameState.has_flag(&"delivery_skipped"))


## GP-04: every plot filled or marked – no plot can ever be freed, so the carter brings nothing
## any more, quietly: no missed delivery, no skip flag/signal, no warning (bier state irrelevant).
func test_no_delivery_and_no_miss_when_every_plot_is_used() -> void:
	graveyard.free_plots = 0
	manager.spawn_corpse(null, Transform3D.IDENTITY, &"ground")
	events.clear()
	assert_null(manager.try_daily_delivery(7))
	assert_eq(manager.records().size(), 1)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)
	assert_false(GameState.has_flag(&"delivery_skipped"))
	assert_eq(events, [])
	dropoff.is_open = false
	EventBus.time_tick.emit(8, 460)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0, "also with an occupied bier")
	assert_eq(events, [])
	assert_null(manager.try_daily_delivery(8), "idempotent per day")


## GP-01: with the real tables the slice brings the valuables choice three times; taking all
## three makes the gravekeeper "Verrufen" (-3) and the carter's reputation remark reachable.
func test_real_slice_three_thefts_reach_verrufen_and_the_carter_remark() -> void:
	manager.tables = load(REAL_TABLES) as CorpseTables
	manager.economy = load(REAL_ECONOMY) as EconomyConfig
	var inv := _inventory()
	var choices := 0
	for day: int in range(1, 7):
		var r := manager.try_daily_delivery(day)
		assert_not_null(r, "delivery day %d" % day)
		manager.examine(r.id)
		if r.needs_valuables_decision():
			choices += 1
			manager.decide_valuables(r.id, true, inv)
	assert_eq(choices, 3, "valuables on days 2, 4 and 5")
	assert_eq(GameState.get_stat(&"valuables_taken"), 3)
	assert_eq(GameState.get_stat(&"reputation"), 3 * manager.economy.valuables_reputation)
	assert_eq(GameState.reputation_label(), "Verrufen")
	GameState.set_flag(&"met_carter")
	TimeManager.minute_of_day = 465
	var runner := DialogueRunner.new()
	runner.start(load(CARTER_DIALOGUE) as DialogueData, {"inventory": inv, "speaker": null})
	assert_eq(runner.current_node().id, &"greet_morning")
	runner.choose(0)
	assert_eq(runner.current_node().id, &"remark_rep", "the carter reacts to the thefts")


func test_delivery_skipped_without_graveyard() -> void:
	graveyard.remove_from_group(&"graveyard")
	assert_null(manager.try_daily_delivery(1))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)


func test_delivery_skipped_without_dropoff() -> void:
	dropoff.remove_from_group(&"dropoff")
	assert_null(manager.try_daily_delivery(1))
	assert_eq(events[0], ["skipped", 1, CorpseManager.REASON_NO_DROPOFF])


## Phase 3 §2.7: slice_complete no longer ends the deliveries (only a full cemetery does).
func test_slice_complete_no_longer_stops_deliveries() -> void:
	GameState.set_flag(&"slice_complete", true)
	assert_not_null(manager.try_daily_delivery(3))
	assert_eq(manager.records().size(), 1)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)


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


## C1: resting over 07:40 delivers once – the corpse arrived at 07:40 and decayed since then.
func test_rest_over_delivery_time_delivers_once() -> void:
	TimeManager.advance(1080 - 390)
	assert_eq(manager.records().size(), 1)
	var r := manager.records()[0]
	assert_eq(r.arrival_total_minutes, 460, "arrived at the delivery minute inside the rest")
	assert_eq(r.last_decay_total, 1080)
	assert_almost(r.freshness, 1.0 - _rate(r) * (1080 - 460) / 60.0, 0.00001, "decayed from 07:40 to 18:00")
	assert_ne(r.freshness_stage(), &"fresh", "10 h 20 min on the bier")


## C1: a timed action over 07:40 (07:10 -> 08:10) backdates the arrival to 07:40.
func test_delivery_inside_a_short_skip_is_backdated() -> void:
	TimeManager.advance(40)
	assert_eq(manager.records(), [])
	TimeManager.advance(60)
	var r := manager.records()[0]
	assert_eq(r.arrival_total_minutes, 460)
	assert_eq(r.last_decay_total, 490)
	assert_almost(r.freshness, 1.0 - _rate(r) * 30 / 60.0, 0.00001)
	assert_eq(events.slice(0, 1), [["arrived", r.id]])


## C1: a direct call before the delivery minute (tests, debug) never arrives in the future.
func test_early_direct_delivery_arrives_now() -> void:
	var r := manager.try_daily_delivery(1)
	assert_eq(r.arrival_total_minutes, 390)
	assert_eq(r.last_decay_total, 390)
	assert_eq(r.freshness, 1.0)


## C1: the fake time_skipped signal alone (TimeManager not moved) uses the signal's times.
func test_delivery_via_skip_signal_uses_the_signal_times() -> void:
	EventBus.time_skipped.emit(390, 1080)
	var r := manager.records()[0]
	assert_eq(r.arrival_total_minutes, 460)
	assert_eq(r.last_decay_total, 1080)


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
	assert_eq(r.freshness_stage(), &"rotten", "Phase 4 §2.5: below 0.1")


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
	assert_eq(r.buried_day, TimeManager.day, "burial day for the grave register (§11)")


## C6: freshness comes from the minutes since arrival in one expression (no accumulated float
## error): after exactly 8 h a x1.0 corpse is still 0.6 "Frisch", after exactly 14 h 0.3 "Welk".
func test_decay_hits_the_stage_thresholds_exactly() -> void:
	TimeManager.advance(460 - 390)
	var fever := _spawn(&"fever")
	var drowned := _spawn(&"drowned")  # x1.5: 0.6 after 320 min, 0.3 after 560 min
	TimeManager.advance(20)
	for i: int in 5:
		TimeManager.advance(60)
	assert_true(drowned.freshness == 0.6, "x1.5 after 320 min: exactly 0.6, got %.17f" % drowned.freshness)
	assert_eq(drowned.freshness_stage(), &"fresh")
	TimeManager.advance(60)
	TimeManager.advance(60)
	TimeManager.advance(40)
	assert_true(fever.freshness == 0.6, "x1.0 after 480 min: exactly 0.6, got %.17f" % fever.freshness)
	assert_eq(fever.freshness_stage(), &"fresh")
	TimeManager.advance(80)
	assert_true(drowned.freshness == 0.3, "x1.5 after 560 min: exactly 0.3, got %.17f" % drowned.freshness)
	assert_eq(drowned.freshness_stage(), &"wilted")


## C6: a x1.0 corpse buried exactly 8 h after its 07:40 arrival keeps the "Frisch" bonus.
func test_burial_on_the_fresh_threshold_gets_the_bonus() -> void:
	TimeManager.advance(460 - 390)
	var r := _spawn(&"fever")
	for i: int in 8:
		TimeManager.advance(60)
	manager.mark_buried(r.id, "plot_01")
	assert_true(r.freshness_at_burial >= economy.fresh_good_threshold, "got %.17f" % r.freshness_at_burial)
	var labels: Array = []
	for line: Dictionary in GraveQuality.breakdown(r, &"wooden_cross", economy):
		labels.append(line.label)
	assert_has(labels, "Frisch")
	assert_eq(GraveQuality.compute(r, &"wooden_cross", economy), 2 + 1 + 1)


## C2: the gameplay floats survive the save format (JSON.from_native writes 14 digits) bit-exactly,
## so a load can never move freshness across a threshold (07:40 delivery + 20 min examination).
func test_freshness_survives_the_json_save_format_exactly() -> void:
	TimeManager.advance(460 - 390)
	var r := manager.records()[0]
	TimeManager.advance(20)
	var threshold := _spawn(&"fever")
	for i: int in 8:
		TimeManager.advance(60)
	manager.mark_buried(threshold.id, "plot_01")
	var values := {r.id: r.freshness, threshold.id: threshold.freshness_at_burial}
	manager.load_state(_json_round_trip(manager.save_state()))
	assert_true(manager.get_record(r.id).freshness == values[r.id],
			"%.17f -> %.17f" % [values[r.id], manager.get_record(r.id).freshness])
	assert_true(manager.get_record(threshold.id).freshness_at_burial == values[threshold.id],
			"%.17f -> %.17f" % [values[threshold.id], manager.get_record(threshold.id).freshness_at_burial])


## ARCH-06: stage-change signals follow the injected EconomyConfig (the one GraveQuality uses).
func test_stage_signals_follow_the_injected_economy() -> void:
	var custom := economy.duplicate() as EconomyConfig
	custom.fresh_good_threshold = 0.95
	manager.economy = custom
	var r := _spawn(&"fever")
	events.clear()
	EventBus.hour_changed.emit(1, 7)  # 30 min: 0.975
	assert_eq(events, [])
	EventBus.hour_changed.emit(1, 8)  # 90 min: 0.925 < 0.95
	assert_eq(events, [["updated", r.id]], "wilted under the injected thresholds")
	assert_eq(CorpseRecord.stage_for(r.freshness, custom), &"wilted")


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
	assert_eq(GameState.get_stat(&"reputation"), economy.valuables_reputation)
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
	assert_eq(manager.save_state(), {"corpses": [], "next_serial": 1, "last_delivery_day": 0, "last_delivery_ids": [], "spawn_counts": {},
			"story_delivered": [], "story_last_day": 0, "stench_day": 0})
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


# --- Phase 3 deliveries (P1, §2.7) ---

func test_deliveries_follow_the_reputation_tier_and_never_exceed_one() -> void:
	var cfg := Phase3Fixtures.reputation_config()
	manager.reputation_config = cfg
	var rep := _reputation(&"renowned")
	for t: StringName in ReputationRules.TIERS:
		rep.fixed_tier = t
		for day: int in [2, 3]:
			var due := manager.deliveries_due(day)
			assert_eq(due, maxi(0, ReputationRules.deliveries_on(day, t, cfg)), "%s day %d" % [t, day])
			assert_true(due <= 1, "one corpse per day in every tier (§14.2)")
	var real := load("res://data/config/reputation_config.tres") as ReputationConfig
	assert_eq(Array(real.deliveries_per_day), [1, 1, 1, 1, 1], "data: one corpse per day")
	rep.fixed_tier = &"esteemed"
	assert_not_null(manager.try_daily_delivery(1))
	assert_eq(manager.deliveries_of(1).size(), 1, "esteemed: still one")


func test_deliveries_due_without_reputation_node_is_one() -> void:
	assert_eq(manager.deliveries_due(2), 1)
	assert_eq(manager.deliveries_due(3), 1)


func test_no_delivery_due_is_quiet() -> void:
	var m := _due_manager(0)
	assert_null(m.try_daily_delivery(2), "e.g. disreputable on an even day")
	assert_eq(m.records(), [])
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0, "not a missed delivery")
	assert_false(GameState.has_flag(&"delivery_skipped"))
	assert_eq(events, [])
	m.due = 1
	assert_not_null(m.try_daily_delivery(3), "the next due day delivers again")


func test_each_corpse_needs_a_free_bier() -> void:
	dropoff.remove_from_group(&"dropoff")
	var first := _bier(Transform3D(Basis.IDENTITY, Vector3(1, 0, 1)))
	var second := _bier(Transform3D(Basis.IDENTITY, Vector3(5, 0, 1)))
	var m := _due_manager(2)
	var r := m.try_daily_delivery(1)
	var list := m.deliveries_of(1)
	assert_eq(list.size(), 2)
	assert_eq(r, list[0], "try_daily_delivery = the first corpse of the day")
	assert_eq([list[0].position, list[1].position], [first.slot.origin, second.slot.origin], "one per bier")
	assert_eq(list[1].seed, CorpseGenerator.seed_for(1, 1), "second spawn index")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)


func test_missed_delivery_counts_the_corpses_and_costs_reputation_once() -> void:
	var rep := _reputation(&"unremarkable")
	dropoff.is_open = false
	var m := _due_manager(2)
	assert_null(m.try_daily_delivery(4))
	assert_null(m.try_daily_delivery(4))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 2, "both corpses missed, once per day")
	assert_eq(GameState.get_flag(&"delivery_skipped"), 4)
	assert_eq(rep.calls, [["event", &"missed_delivery", CorpseManager.REASON_MISSED]])
	assert_eq(events, [["skipped", 4, CorpseManager.REASON_OCCUPIED], ["note", CorpseManager.NOTE_SKIPPED % CorpseManager.REASON_OCCUPIED, &"warning"]])


func test_second_corpse_missed_when_only_one_bier_is_free() -> void:
	dropoff.remove_from_group(&"dropoff")
	_bier(SLOT)
	var rep := _reputation(&"unremarkable")
	var m := _due_manager(2)
	assert_not_null(m.try_daily_delivery(1))
	assert_eq(m.deliveries_of(1).size(), 1)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1, "the rest counts")
	assert_eq(rep.calls.size(), 1)


func test_no_reputation_cost_without_plot_or_dropoff() -> void:
	var rep := _reputation(&"unremarkable")
	graveyard.free_plots = 0
	assert_null(manager.try_daily_delivery(1), "cemetery full: quiet")
	dropoff.remove_from_group(&"dropoff")
	graveyard.free_plots = 6
	assert_null(manager.try_daily_delivery(2))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1, "no bier at all is still reported")
	assert_eq(rep.calls, [], "only an occupied bier costs reputation")


func test_deliveries_of_earlier_days() -> void:
	var one := manager.try_daily_delivery(1)
	var two := manager.try_daily_delivery(2)
	assert_eq(manager.deliveries_of(2), [two])
	assert_eq(manager.deliveries_of(1), [one], "earlier day: generated for that day")
	assert_eq(manager.deliveries_of(3), [])
	assert_eq(manager.deliveries_of(0), [])
	assert_null(manager.try_daily_delivery(1), "no delivery for an earlier day")


func test_save_writes_last_delivery_ids_and_reads_the_v1_field() -> void:
	var r := manager.try_daily_delivery(1)
	var saved := manager.save_state()
	assert_eq(saved.last_delivery_ids, [r.id])
	assert_false(saved.has("last_delivery_id"), "v2 format")
	var v1 := _json_round_trip(saved)
	v1.erase("last_delivery_ids")
	v1["last_delivery_id"] = r.id
	manager.load_state(v1)
	assert_eq(manager.try_daily_delivery(1).id, r.id, "v1 last_delivery_id read as fallback")
	assert_eq(manager.save_state().last_delivery_ids, [r.id])
	v1["last_delivery_id"] = ""
	manager.load_state(v1)
	assert_eq(manager.save_state().last_delivery_ids, [])
	assert_eq(CorpseSaveCodec.read_delivery_ids({"last_delivery_ids": ["a", "", "a", 3, "b"]}), ["a", "b"] as Array[String])


func test_valuables_go_through_the_reputation_api() -> void:
	var rep := _reputation(&"unremarkable")
	var r := _spawn(&"fever", [&"valuables"])
	manager.examine(r.id)
	manager.decide_valuables(r.id, true, _inventory())
	assert_eq(rep.calls, [["change", economy.valuables_reputation, CorpseManager.REASON_VALUABLES]])
	assert_eq(GameState.get_stat(&"reputation"), 0, "the Reputation node owns the value")
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)


func test_free_dropoffs_and_report_skip_count() -> void:
	var busy := DropoffDouble.new()
	busy.is_open = false
	var plain := Node.new()
	var list: Array[Node] = [busy, dropoff, plain]
	assert_eq(CorpseDeliveryRules.free_dropoffs(list), [dropoff] as Array[Node])
	assert_eq(CorpseDeliveryRules.free_dropoffs([] as Array[Node]), [] as Array[Node])
	busy.free()
	plain.free()
	CorpseDeliveryRules.report_skip(3, "x", 3)
	assert_eq(GameState.get_stat(&"missed_deliveries"), 3)
	CorpseDeliveryRules.report_skip(4, "x")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 4, "default 1")


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


## Freshness lost per hour by `r` with the fixture tables.
func _rate(r: CorpseRecord) -> float:
	return tables.base_decay_per_hour * float(tables.get_cause(r.cause_id).get("decay_mult", 1.0))


## Replaces the fixture manager by one with a fixed number of deliveries per day.
func _due_manager(due: int) -> DueManager:
	world.remove_child(manager)
	_orphans.append(manager)
	var m := DueManager.new()
	m.due = due
	m.name = "CorpseManager"
	m.tables = tables
	m.economy = economy
	m.container_path = ^"../Corpses"
	world.add_child(m)
	manager = m
	return m


func _reputation(tier: StringName) -> ReputationDouble:
	var rep := ReputationDouble.new()
	rep.fixed_tier = tier
	world.add_child(rep)
	return rep


## Extra bier in group "dropoff" that is occupied while a corpse lies on its slot.
func _bier(at: Transform3D) -> BierDouble:
	var bier := BierDouble.new()
	bier.slot = at
	bier.add_to_group(&"dropoff")
	world.add_child(bier)
	return bier


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


# --- Phase 4 (P1, docs/PHASE4_DESIGN.md §2.5, §2.11, §3.4, §10) ---------------------------------

## Graveyard with the Phase-4 duck type: free / locked plots and the Holunderwinkel plots.
class StoryGraveyardDouble extends GraveyardDouble:
	var locked: int = 0
	var elder := PackedStringArray(["h_01", "h_02", "h_03", "h_04", "h_05", "h_06"])

	func locked_plot_count() -> int:
		return locked

	func plots_in_section(section: StringName) -> PackedStringArray:
		return elder if section == &"elder" else PackedStringArray()


## CorpseManager delivering only on odd days (disreputable, §2.11 rule 1).
class OddDayManager extends CorpseManager:
	func deliveries_due(day: int) -> int:
		return day % 2


## Piety / journal / corpse care doubles (groups piety, journal, corpse_care).
class CallsDouble extends Node:
	var calls: Array = []

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])

	func add_clue(id: StringName, corpse_id: String = "", silent: bool = false) -> bool:
		calls.append(["add_clue", id, corpse_id, silent])
		return true

	func exam_all_instant(id: String) -> Dictionary:
		calls.append(["exam_all_instant", id])
		return {}

	func dress(id: String, kind: StringName, inv: Inventory) -> bool:
		calls.append(["dress", id, kind, inv != null])
		return true


func test_story_corpse_comes_instead_of_the_random_one() -> void:
	_story_setup(manager)
	var arrived: Array = []
	var on_story := func(story_id: StringName, corpse_id: String) -> void: arrived.append([story_id, corpse_id])
	EventBus.story_corpse_arrived.connect(on_story)
	events.clear()
	var r := manager.try_daily_delivery(6)
	EventBus.story_corpse_arrived.disconnect(on_story)
	assert_not_null(r)
	assert_eq([r.story_id, r.display_name, r.age, r.cause_id], [&"s1_quendel", "Marthe Quendel", 63, &"old_age"])
	assert_eq(r.traits, [&"strange_wound"] as Array[StringName], "forced traits")
	assert_eq(r.seed, CorpseGenerator.seed_for(6, 0), "takes the day's spawn index")
	assert_eq(r.location, &"dropoff")
	assert_eq(arrived, [[&"s1_quendel", r.id]])
	assert_has(events, ["note", Phase4Fixtures.story(&"s1_quendel").arrival_note, &"info"])
	assert_eq(manager.story_delivered(), PackedStringArray(["s1_quendel"]))
	assert_eq(manager.story_last_day(), 6)
	assert_eq(manager.deliveries_of(6), [r])
	assert_eq(manager.records().size(), 1, "no random corpse besides it")


func test_story_days_of_a_new_game() -> void:
	_story_setup(manager)
	var days := {}
	for day: int in range(1, 22):
		var r := manager.try_daily_delivery(day)
		assert_not_null(r, "a corpse every day (day %d)" % day)
		if r != null and r.story_id != &"":
			days[r.story_id] = day
	assert_eq(days, {&"s1_quendel": 6, &"s2_hemmerling": 9, &"s3_wernstein": 13, &"s4_uhlig": 16, &"s5_moor": 19})


func test_story_waits_for_odd_days_while_disreputable() -> void:
	var m := OddDayManager.new()
	_replace_manager(m)
	_story_setup(m)
	var days := {}
	for day: int in range(1, 24):
		var r := m.try_daily_delivery(day)
		if r != null and r.story_id != &"":
			days[r.story_id] = day
	assert_eq(days, {&"s1_quendel": 7, &"s2_hemmerling": 9, &"s3_wernstein": 13, &"s4_uhlig": 17, &"s5_moor": 19})


func test_story_catches_up_every_second_day_after_loading() -> void:
	_story_setup(manager)
	for day: int in range(1, 15):
		manager.try_daily_delivery(day)
	var data := manager.save_state()
	data["story_delivered"] = []
	data["story_last_day"] = 0
	manager.load_state(_json_round_trip(data))
	var days: Array = []
	for day: int in range(15, 25):
		var r := manager.try_daily_delivery(day)
		if r != null and r.story_id != &"":
			days.append([r.story_id, day])
	assert_eq(days, [[&"s1_quendel", 15], [&"s2_hemmerling", 17], [&"s3_wernstein", 19], [&"s4_uhlig", 21], [&"s5_moor", 23]])


func test_story_waits_for_a_free_bier() -> void:
	_story_setup(manager)
	dropoff.is_open = false
	assert_null(manager.try_daily_delivery(6))
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1, "an occupied bier is a missed delivery")
	assert_eq(manager.story_delivered().size(), 0)
	dropoff.is_open = true
	assert_eq(manager.try_daily_delivery(7).story_id, &"s1_quendel", "comes the next day")


func test_reservation_keeps_plots_for_pending_stories() -> void:
	var g := _story_graveyard()
	_story_setup(manager)
	g.free_plots = 5
	events.clear()
	assert_null(manager.try_daily_delivery(2), "5 free ≤ 0 unburied + 5 pending: no random corpse")
	assert_eq(events, [["note", Phase4Fixtures.story_config().reserve_note, &"info"]], "quiet, Osric's line only")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 0)
	assert_false(GameState.has_flag(&"delivery_skipped"))
	g.free_plots = 6
	assert_not_null(manager.try_daily_delivery(3), "6 free > 0 + 5")
	g.free_plots = 2
	var s1 := manager.try_daily_delivery(6)
	assert_eq(s1.story_id, &"s1_quendel", "a story corpse only needs free > unburied (2 > 1)")
	g.free_plots = 2
	assert_null(manager.try_daily_delivery(7), "2 free = 2 unburied: full")


func test_locked_plots_lift_the_reservation() -> void:
	var g := _story_graveyard()
	_story_setup(manager)
	g.free_plots = 2
	g.locked = 6
	assert_not_null(manager.try_daily_delivery(2), "the Holunderwinkel can still take the stories")
	g.locked = 3
	assert_null(manager.try_daily_delivery(3), "2 free ≤ 1 unburied + (5 − 3) reserved")


func test_no_reservation_in_a_world_without_the_story_section() -> void:
	_story_setup(manager)
	graveyard.free_plots = 2
	assert_not_null(manager.try_daily_delivery(2), "Phase-3 world: nothing reserved")


func test_stench_at_the_gate_once_per_day() -> void:
	_story_setup(manager)
	var rep := _reputation(&"")
	manager.reputation_config = Phase4Fixtures.reputation_config()
	var old := _spawn(&"fever")
	old.arrival_total_minutes = 460
	old.last_decay_total = 460
	# Day 2 07:40 = 24 h after arrival: 1 − 1.2 → 0 (rotten) – stinks.
	events.clear()
	EventBus.time_tick.emit(2, 460)
	assert_eq(rep.calls.filter(func(c: Array) -> bool: return c[1] == &"stench").size(), 1)
	assert_has(events, ["note", CorpseManager.NOTE_STENCH, &"warning"])
	var data := manager.save_state()
	assert_eq(data.stench_day, 2)
	manager.load_state(_json_round_trip(data))
	manager._last_delivery_day = 1
	rep.calls.clear()
	EventBus.time_tick.emit(2, 461)
	assert_eq(rep.calls.filter(func(c: Array) -> bool: return c[1] == &"stench").size(), 0, "once per day, also after a reload")


func test_no_stench_while_fresh_balmed_or_buried() -> void:
	_story_setup(manager)
	var rep := _reputation(&"")
	manager.reputation_config = Phase4Fixtures.reputation_config()
	var r := _spawn(&"fever")
	var t0 := r.arrival_total_minutes
	manager._check_stench(2, t0 + 13 * 60)
	assert_eq(rep.calls, [], "13 h: 0.35 (wilted) – no stench")
	r.balm_windows = PackedInt32Array([t0, t0 + 100000])
	manager._check_stench(3, t0 + 30 * 60)
	assert_eq(rep.calls, [], "a running juniper window: no stench")
	r.balm_windows = PackedInt32Array()
	manager._check_stench(4, t0 + 30 * 60)
	assert_eq(rep.calls.size(), 1, "without the window it stinks")
	manager.mark_buried(r.id, "plot_01")
	manager._check_stench(5, t0 + 40 * 60)
	assert_eq(rep.calls.size(), 1, "buried corpses do not stink")


func test_stench_falls_back_to_the_class_default_points() -> void:
	_story_setup(manager)
	var rep := _reputation(&"")
	manager.reputation_config = Phase3Fixtures.reputation_config()
	_spawn(&"fever")
	manager._check_stench(5, 5 * 1440)
	assert_eq(rep.calls, [["change", -2, CorpseManager.REASON_STENCH]], "reputation_config.tres without stench (until P3)")


func test_key_fallback_on_day_started() -> void:
	_story_setup(manager)
	var journal := CallsDouble.new()
	journal.add_to_group(&"journal")
	world.add_child(journal)
	events.clear()
	EventBus.day_started.emit(11)
	assert_false(GameState.has_flag(&"has_elder_key"))
	EventBus.day_started.emit(12)
	assert_eq(GameState.get_flag(&"has_elder_key"), true)
	assert_eq(journal.calls, [["add_clue", &"c_elder_key", "", true]], "clue without a line")
	assert_has(events, ["note", Phase4Fixtures.story_config().key_fallback_text, &"info"])
	assert_eq(manager.apply_daily_checks(13), [] as Array[StringName], "idempotent")
	assert_eq(journal.calls.size(), 1)


func test_no_key_fallback_when_the_key_was_found() -> void:
	_story_setup(manager)
	GameState.set_flag(&"has_elder_key", true)
	events.clear()
	assert_eq(manager.apply_daily_checks(15), [] as Array[StringName])
	assert_eq(events, [])


func test_examine_without_corpse_care_reveals_every_step() -> void:
	var r := _spawn(&"fever", [&"valuables", &"letter"])
	manager.examine(r.id)
	assert_true(r.examined)
	assert_true(r.is_fully_examined())
	assert_eq(r.traits_revealed, [&"valuables", &"letter"] as Array[StringName])
	assert_true(r.needs_valuables_decision())


func test_examine_and_apply_shroud_delegate_to_corpse_care() -> void:
	var care := CallsDouble.new()
	care.add_to_group(&"corpse_care")
	world.add_child(care)
	var r := _spawn(&"fever")
	manager.examine(r.id)
	var inv := _inventory()
	assert_true(manager.apply_shroud(r.id, inv))
	assert_eq(care.calls, [["exam_all_instant", r.id], ["dress", r.id, &"shroud", true]])
	assert_false(r.examined, "CorpseCare owns the change")


func test_apply_shroud_without_care_sets_the_dress() -> void:
	var r := _spawn(&"fever")
	var inv := _inventory()
	inv.add_item(&"shroud", 1)
	assert_true(manager.apply_shroud(r.id, inv))
	assert_eq([r.shrouded, r.dress], [true, &"shroud"])


func test_decide_valuables_raises_piety_events() -> void:
	var piety := CallsDouble.new()
	piety.add_to_group(&"piety")
	world.add_child(piety)
	var inv := _inventory()
	var a := _spawn(&"fever", [&"valuables"])
	var b := _spawn(&"fever", [&"valuables"])
	manager.examine(a.id)
	manager.examine(b.id)
	manager.decide_valuables(a.id, true, inv)
	manager.decide_valuables(b.id, false, inv)
	assert_eq([piety.calls[0][1], piety.calls[1][1]], [&"valuables_taken", &"valuables_left"])


func test_story_bookkeeping_round_trip() -> void:
	_story_setup(manager)
	for day: int in range(1, 10):
		manager.try_daily_delivery(day)
	var data := _json_round_trip(manager.save_state())
	assert_eq(data.story_delivered, ["s1_quendel", "s2_hemmerling"])
	var other := _new_manager()
	other.name = "Other"
	_story_setup(other)
	world.add_child(other)
	other.load_state(data)
	assert_eq(other.story_delivered(), PackedStringArray(["s1_quendel", "s2_hemmerling"]))
	assert_eq(other.story_last_day(), 9)
	assert_eq(other.get_record(manager.deliveries_of(9)[0].id).story_id, &"s2_hemmerling")
	other.load_state({"story_delivered": ["s1_quendel", "", "s1_quendel", 3], "story_last_day": "x"})
	assert_eq([other.story_delivered(), other.story_last_day()], [PackedStringArray(["s1_quendel"]), 0], "tolerant")


func test_deliver_story_now() -> void:
	_story_setup(manager)
	var r := manager.deliver_story_now(&"s5_moor")
	assert_not_null(r)
	assert_eq([r.story_id, r.display_name, r.cause_id], [&"s5_moor", Phase4Fixtures.story(&"s5_moor").display_name, &"moor_cold"])
	assert_eq(manager.story_last_day(), TimeManager.day)
	assert_null(manager.deliver_story_now(&"s5_moor"), "only once")
	assert_null(manager.deliver_story_now(&"nope"))
	dropoff.is_open = false
	assert_null(manager.deliver_story_now(&"s1_quendel"), "needs a free bier")
	dropoff.is_open = true
	graveyard.free_plots = 1
	assert_null(manager.deliver_story_now(&"s1_quendel"), "needs free > unburied")
	assert_eq(manager.story_delivered(), PackedStringArray(["s5_moor"]))


func test_decay_uses_the_balm_windows_and_the_prep_factor() -> void:
	var r := _spawn(&"fever")
	manager.prep_config = Phase4Fixtures.prep_config()
	var start := r.arrival_total_minutes
	r.balm_windows = PackedInt32Array([start, start + 240])
	EventBus.time_skipped.emit(start, start + 240)
	assert_almost(r.freshness, 1.0 - 0.05 * 1.0, 0.0001, "4 h at 0.25 = 1 h")
	var custom := PrepConfig.new()
	custom.balm_factor = 0.5
	manager.prep_config = custom
	EventBus.time_skipped.emit(start + 240, start + 241)
	assert_almost(r.freshness, CorpseDecay.freshness_at(r, start + 241, 0.05, 0.5))


func test_carrying_a_decaying_corpse_smells_once() -> void:
	var fresh := _spawn(&"fever")
	var player := _player()
	events.clear()
	assert_true(manager.pick_up(fresh.id, player))
	assert_eq(events, [["updated", fresh.id]], "fresh: nothing")
	manager.put_down(fresh.id, &"ground", Transform3D.IDENTITY)
	var old := _spawn(&"fever")
	old.freshness = 0.2
	events.clear()
	assert_true(manager.pick_up(old.id, player))
	assert_eq(events, [["note", CorpseManager.NOTE_SMELL, &"info"], ["updated", old.id]])
	assert_true(old.stench_noted)
	manager.put_down(old.id, &"ground", Transform3D.IDENTITY)
	events.clear()
	manager.pick_up(old.id, player)
	assert_eq(events, [["updated", old.id]], "once per corpse")


func _story_setup(m: CorpseManager) -> void:
	m.stories = Phase4Fixtures.stories()
	m.story_config = Phase4Fixtures.story_config()
	graveyard.free_plots = 40


func _story_graveyard() -> StoryGraveyardDouble:
	graveyard.remove_from_group(&"graveyard")
	var g := StoryGraveyardDouble.new()
	g.add_to_group(&"graveyard")
	world.add_child(g)
	graveyard = g
	return g


func _replace_manager(m: CorpseManager) -> void:
	world.remove_child(manager)
	_orphans.append(manager)
	m.name = "CorpseManager"
	m.tables = tables
	m.economy = economy
	m.container_path = ^"../Corpses"
	world.add_child(m)
	manager = m
