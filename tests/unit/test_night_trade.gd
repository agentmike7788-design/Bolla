extends TestCase
## P3 (docs/PHASE4_DESIGN.md §2.6, §2.11 (5), §3.4, §5.1, §10): NightTrade and Ilse's Npc
## schedule – the note at the door from day 4, 06:00 exactly once (also after loading), her
## schedule (hidden without trader_known, present 23:00–03:00, walking from 22:40 and at 03:00),
## selling only while present with coins at once and the piety bonus, the shop atomic with a
## stock per night (reset after 12:00, not by loading), the tools once (full inventory), the
## talk counter per night, trader_rumor, the 22:45 notice, save / load. Osric's own behaviour is
## covered by the unchanged Npc tests (test_entities.gd); here only that he ignores the new
## exports. Clock: TimeManager.day / minute_of_day set directly (no signals).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const NPC_SCENE := "res://src/entities/npc/npc.tscn"


class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false

	func add_item(_id: StringName, amount: int) -> int:
		return amount


## Holds only one tool: the second is refused.
class OneSlotInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return items.size() < 1

	func add_item(id: StringName, amount: int) -> int:
		if items.size() >= 1:
			return amount
		return super.add_item(id, amount)


class FakeJournal extends Node:
	var added: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, corpse_id: String = "", silent: bool = false) -> bool:
		added.append([id, corpse_id, silent])
		return true


class FakePlayer extends Node:
	var in_interior: bool = false

	func _init() -> void:
		add_to_group(&"player")


class WaypointWorld extends Node3D:
	var points: Dictionary = {}

	func get_waypoint(id: StringName) -> Vector3:
		return points.get(id, Vector3.ZERO)


var world: Node3D
var trade: NightTrade
var journal: FakeJournal
var player: FakePlayer
var inv: Inventory
var notes: Array = []
var trades: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	world = Node3D.new()
	world.name = "TradeWorld"
	tree.root.add_child(world)
	journal = FakeJournal.new()
	world.add_child(journal)
	player = FakePlayer.new()
	world.add_child(player)
	trade = NightTrade.new()
	trade.trader_config = Phase4Fixtures.trader_config()
	trade.utilization_config = Phase4Fixtures.utilization_config()
	trade.schedule = Phase4Fixtures.trader_schedule()
	world.add_child(trade)
	inv = FakeInventory.new()
	world.add_child(inv)
	notes.clear()
	trades.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.trader_trade.connect(_on_trade)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.trader_trade.disconnect(_on_trade)
	world.free()
	GameState.reset()
	TimeManager.reset()


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_trade(coins: int, sold: Dictionary, bought: Dictionary) -> void:
	trades.append([coins, sold, bought])


func _at(day: int, minute: int) -> void:
	TimeManager.day = day
	TimeManager.minute_of_day = minute


## Known and standing at the wall (day `day`, 23:30).
func _ilse_here(day: int = 5) -> void:
	GameState.set_flag(&"trader_known", true)
	_at(day, 1410)


# --- note at the door ---------------------------------------------------------------------

func test_note_at_the_door_from_day_4_at_six_once() -> void:
	_at(3, 600)
	trade._on_time_tick(3, 600)
	assert_false(trade.is_known(), "day 3: nothing yet")
	_at(4, 359)
	trade._on_time_tick(4, 359)
	assert_false(trade.is_known(), "05:59")
	_at(4, 360)
	trade._on_time_tick(4, 360)
	assert_true(trade.is_known(), "06:00")
	assert_eq(GameState.get_flag(&"trader_known"), true)
	assert_eq(journal.added, [[&"c_trader_note", "", false]])
	assert_eq(notes, [[NightTrade.TEXT_NOTE, &"info"]])
	_at(4, 361)
	trade._on_time_tick(4, 361)
	trade.apply_morning(5)
	assert_eq(journal.added.size(), 1, "exactly once")
	assert_eq(notes.size(), 1)
	assert_eq(trade.save_state().intro_done, true)


func test_note_after_loading_a_later_day() -> void:
	# A migrated day-9 save loaded at 08:00 gets the note at once; loaded at 02:00, at 06:00.
	_at(9, 120)
	trade.load_state({})
	trade._on_game_loaded(0)
	assert_false(trade.is_known(), "02:00 – wait for the morning")
	_at(9, 480)
	trade._on_game_loaded(0)
	assert_true(trade.is_known())
	assert_eq(journal.added.size(), 1)
	var saved := trade.save_state()
	trade.load_state(saved)
	trade._on_game_loaded(0)
	assert_eq(journal.added.size(), 1, "a load with intro_done never repeats the note")


func test_known_flag_set_elsewhere_marks_the_note_done() -> void:
	GameState.set_flag(&"trader_known", true)
	_at(4, 400)
	trade.apply_morning(4)
	assert_eq(journal.added, [], "debug trader known: no second note")
	assert_true(trade.save_state().intro_done)


# --- schedule / presence -------------------------------------------------------------------

func test_real_schedule_matches_the_fixture() -> void:
	var real := Database.schedule(&"trader") as NpcSchedule
	var fixture := Phase4Fixtures.trader_schedule()
	assert_not_null(real, "data/npc/trader_schedule.tres registered by npc_id")
	assert_eq(real.display_name, "Ilse Kranich")
	assert_eq(real.entries.size(), fixture.entries.size())
	for i: int in real.entries.size():
		var a: ScheduleEntry = real.entries[i]
		var b: ScheduleEntry = fixture.entries[i]
		assert_eq([a.start_minute, a.travel_minutes, a.activity, a.animation, a.path, a.dialogue_id, a.visible, a.with_cart],
				[b.start_minute, b.travel_minutes, b.activity, b.animation, b.path, b.dialogue_id, b.visible, b.with_cart], "entry %d" % i)


func test_schedule_times() -> void:
	var sched := Database.schedule(&"trader") as NpcSchedule
	var arrive := ScheduleResolver.entry_at(sched, 1360)
	assert_eq([arrive.activity, arrive.travel_minutes, Array(arrive.path)], [&"walk", 20, ["trader_far", "trader_mid", "trader_spot"]], "22:40 from the forest edge")
	assert_eq(ScheduleResolver.arrival_minute(arrive), 1380, "at the wall 23:00")
	for minute: int in [1380, 1439, 0, 179]:
		var e := ScheduleResolver.entry_at(sched, minute)
		assert_eq([e.path, e.dialogue_id, e.visible], [PackedStringArray(["trader_spot"]), &"trader", true], "at the wall %d" % minute)
	var leave := ScheduleResolver.entry_at(sched, 180)
	assert_eq([leave.activity, Array(leave.path)], [&"walk", ["trader_spot", "trader_mid", "trader_far"]], "03:00 back")
	for minute: int in [200, 720, 1359]:
		assert_false(ScheduleResolver.entry_at(sched, minute).visible, "away at %d" % minute)
	for e: ScheduleEntry in sched.entries:
		assert_false(e.with_cart, "Ilse never has a cart")


func test_presence_follows_flag_and_clock() -> void:
	_at(5, 1410)
	assert_false(trade.is_present(), "not known → never there")
	GameState.set_flag(&"trader_known", true)
	var cases := [[1350, false], [1370, false], [1380, true], [1410, true], [0, true], [179, true], [180, false], [190, false], [600, false]]
	for c: Array in cases:
		_at(5, c[0])
		assert_eq(trade.is_present(), c[1], "minute %d" % c[0])
	GameState.set_flag(&"trader_known", false)
	_at(5, 1410)
	assert_false(trade.is_present(), "flag false")


func test_night_id_splits_at_noon() -> void:
	_at(5, 1410)
	assert_eq(trade.night_id(), 5)
	_at(6, 100)
	assert_eq(trade.night_id(), 5, "after midnight still the same night")
	_at(6, 720)
	assert_eq(trade.night_id(), 6)


func test_npc_hidden_without_flag_then_at_the_wall() -> void:
	var npc := await _trader_npc()
	_at(5, 1410)
	npc.refresh()
	assert_false(npc.visible, "no trader_known → invisible")
	assert_false(npc.interactable.enabled)
	assert_true(npc.body_shape.disabled)
	assert_eq(npc.get_interaction_prompt(null), "")
	GameState.set_flag(&"trader_known", true)
	npc.refresh()
	assert_true(npc.visible)
	assert_true(npc.global_position.is_equal_approx(Vector3(-12, 0, -2)), str(npc.global_position))
	assert_eq(npc.get_interaction_prompt(null), "[E] Mit Ilse reden")
	assert_true(trade.is_present(), "presence through the Npc node")
	_at(5, 1370)
	npc.refresh()
	assert_true(npc.visible and npc.is_walking(), "on the way at 22:50")
	assert_false(npc.interactable.enabled, "no prompt while walking")
	assert_false(trade.is_present())
	_at(6, 300)
	npc.refresh()
	assert_false(npc.visible, "gone after 03:20")
	assert_false(npc.cart.visible, "no cart")
	assert_true(npc.cart_shape.disabled)
	assert_false(npc.cargo.visible)


func test_npc_lantern_without_shadow() -> void:
	var npc := await _trader_npc()
	var light := npc.lantern()
	assert_not_null(light)
	if light == null:
		return
	assert_false(light.shadow_enabled)
	assert_true(light.is_in_group(&"warm_lights"))
	assert_almost(light.light_energy, Npc.LANTERN_ENERGY)
	assert_almost(light.omni_range, Npc.LANTERN_RANGE)
	assert_true(light.light_energy >= 1.0, "QA W3 (G4): reads at the west wall at night")
	assert_true(light.light_color.is_equal_approx(Color("E8A55A")))


func test_osric_ignores_the_new_exports() -> void:
	var carter := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	assert_eq([carter.requires_flag, carter.lantern_marker], [&"", &""])
	assert_true(carter.flag_allows(), "no flag required")
	carter.npc_id = &"carter"
	var ways := WaypointWorld.new()
	world.add_child(ways)
	ways.add_child(carter)
	await tree.process_frame
	assert_null(carter.lantern(), "no lantern")
	_at(5, 480)
	carter.refresh()
	assert_true(carter.visible and carter.cart.visible, "Osric at the drop-off with his cart")


# --- selling ------------------------------------------------------------------------------

func test_sell_only_while_present_coins_at_once() -> void:
	inv.add_item(&"hair_braid", 2)
	inv.add_item(&"teeth_pouch", 1)
	_at(5, 1410)
	assert_eq(trade.sell(&"hair_braid", 1, inv), 0, "not known")
	GameState.set_flag(&"trader_known", true)
	_at(5, 900)
	assert_eq(trade.sell(&"hair_braid", 1, inv), 0, "15:00 – not there")
	assert_eq(inv.count(&"hair_braid"), 2)
	_ilse_here()
	assert_eq(trade.quote(&"hair_braid", 2), 8)
	assert_eq(trade.sell(&"hair_braid", 2, inv), 8)
	assert_eq([inv.count(&"hair_braid"), inv.count(&"coin")], [0, 8], "coins at once")
	assert_eq(trade.sell(&"teeth_pouch", 1, inv), 5)
	assert_eq(inv.count(&"coin"), 13)
	assert_eq(GameState.get_stat(&"trader_sales"), 3)
	assert_eq(trades, [[8, {&"hair_braid": 2}, {}], [5, {&"teeth_pouch": 1}, {}]])


func test_sell_refusals() -> void:
	_ilse_here()
	inv.add_item(&"hair_braid", 1)
	inv.add_item(&"linen", 3)
	assert_eq(trade.sell(&"hair_braid", 2, inv), 0, "only 1 held – all or nothing")
	assert_eq(trade.sell(&"linen", 1, inv), 0, "she does not buy linen")
	assert_eq(trade.sell(&"hair_braid", 0, inv), 0)
	assert_eq(trade.sell(&"hair_braid", 1, null), 0)
	assert_eq([inv.count(&"hair_braid"), inv.count(&"linen"), inv.count(&"coin")], [1, 3, 0])
	assert_eq(trades, [])
	assert_eq(trade.quote(&"linen", 2), 0)


func test_piety_bonus_from_callous_down() -> void:
	_ilse_here()
	var cases := [[-80, 5, 6], [-20, 5, 6], [-19, 4, 5], [0, 4, 5], [70, 4, 5]]
	for c: Array in cases:
		GameState.stats[&"piety"] = c[0]
		assert_eq([trade.quote(&"hair_braid", 1), trade.quote(&"teeth_pouch", 1)], [c[1], c[2]], "piety %d" % c[0])
	# With a Piety node its buyer_bonus is used.
	var piety := Piety.new()
	piety.config = Phase4Fixtures.piety_config()
	world.add_child(piety)
	GameState.stats[&"piety"] = -40
	inv.add_item(&"teeth_pouch", 2)
	assert_eq(trade.sell(&"teeth_pouch", 2, inv), 12, "(5 + 1) × 2")


func test_rumor_after_three_sales() -> void:
	_ilse_here()
	inv.add_item(&"hair_braid", 3)
	trade.sell(&"hair_braid", 2, inv)
	assert_false(GameState.has_flag(&"trader_rumor"))
	trade.sell(&"hair_braid", 1, inv)
	assert_eq(GameState.get_flag(&"trader_rumor"), true, "3rd sale")
	assert_eq(trade.sales(), 3)


# --- shop ---------------------------------------------------------------------------------

func test_buy_linen_and_juniper_with_nightly_stock() -> void:
	_ilse_here()
	inv.add_item(&"coin", 20)
	assert_eq([trade.stock_left(&"linen"), trade.stock_left(&"juniper"), trade.stock_left(&"wood")], [3, 4, 0])
	assert_true(trade.buy(&"linen", 2, inv))
	assert_eq([inv.count(&"linen"), inv.count(&"coin"), trade.stock_left(&"linen")], [2, 16, 1])
	assert_false(trade.buy(&"linen", 2, inv), "only 1 left tonight")
	assert_eq([inv.count(&"linen"), inv.count(&"coin"), trade.stock_left(&"linen")], [2, 16, 1], "atomic")
	assert_true(trade.buy(&"juniper", 4, inv))
	assert_eq([inv.count(&"juniper"), inv.count(&"coin"), trade.stock_left(&"juniper")], [4, 12, 0])
	assert_false(trade.buy(&"juniper", 1, inv), "sold out")
	assert_eq(trades, [[-4, {}, {&"linen": 2}], [-4, {}, {&"juniper": 4}]])
	_at(6, 100)
	assert_eq(trade.stock_left(&"linen"), 1, "same night after midnight")
	_at(6, 1400)
	assert_eq([trade.stock_left(&"linen"), trade.stock_left(&"juniper")], [3, 4], "a new night (after 12:00)")
	assert_true(trade.buy(&"linen", 3, inv))


func test_buy_refusals_change_nothing() -> void:
	inv.add_item(&"coin", 3)
	_at(5, 1410)
	assert_false(trade.buy(&"linen", 1, inv), "not known")
	_ilse_here()
	assert_false(trade.buy(&"linen", 2, inv), "4 coins needed, 3 held")
	assert_false(trade.buy(&"wood", 1, inv), "not in her shop")
	assert_false(trade.buy(&"linen", 0, inv))
	var full := FullInventory.new()
	full.items = {&"coin": 10}
	world.add_child(full)
	assert_false(trade.buy(&"linen", 1, full), "no room")
	assert_eq(full.count(&"coin"), 10)
	_at(5, 900)
	assert_false(trade.buy(&"juniper", 1, inv), "not there by day")
	assert_eq([inv.count(&"coin"), inv.count(&"linen"), trade.stock_left(&"linen")], [3, 0, 3])
	assert_eq(trades, [])


func test_stock_survives_loading_and_is_not_refilled() -> void:
	_ilse_here()
	inv.add_item(&"coin", 10)
	trade.buy(&"linen", 2, inv)
	var saved := trade.save_state()
	assert_eq(saved.stock_night, 5)
	assert_eq(saved.stock_left, {"linen": 1, "juniper": 4})
	var other := NightTrade.new()
	other.trader_config = trade.trader_config
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.stock_left(&"linen"), 1, "loading does not refill")
	assert_eq(other.save_state(), saved, "roundtrip")
	other.free()


# --- tools, talks, notice -------------------------------------------------------------------

func test_tools_once() -> void:
	assert_true(trade.give_tools(inv))
	assert_eq([inv.count(&"shears"), inv.count(&"pliers")], [1, 1])
	assert_true(trade.tools_given())
	assert_false(trade.give_tools(inv), "only once")
	assert_eq([inv.count(&"shears"), inv.count(&"pliers")], [1, 1])


func test_tools_with_a_full_inventory_come_later() -> void:
	var small := OneSlotInventory.new()
	world.add_child(small)
	assert_false(trade.give_tools(small), "room for one tool only")
	assert_eq(small.items, {}, "atomic – the first tool is taken back")
	assert_eq(notes.back(), [NightTrade.TEXT_TOOLS_FULL, &"warning"])
	assert_false(trade.tools_given())
	var full := FullInventory.new()
	world.add_child(full)
	assert_false(trade.give_tools(full))
	assert_true(trade.give_tools(inv), "later with room")
	var held := FakeInventory.new()
	held.items = {&"shears": 1}
	world.add_child(held)
	trade.load_state({})
	assert_true(trade.give_tools(held))
	assert_eq([held.count(&"shears"), held.count(&"pliers")], [1, 1], "a held tool is not given twice")


func test_talks_count_once_per_night() -> void:
	_ilse_here(5)
	trade.note_talk()
	trade.note_talk()
	assert_eq(trade.talks(), 1)
	_at(6, 60)
	trade.note_talk()
	assert_eq(trade.talks(), 1, "same night after midnight")
	_at(6, 1400)
	trade.note_talk()
	_at(8, 1400)
	trade.note_talk()
	assert_eq(trade.talks(), 3)
	assert_eq(trade.save_state().last_talk_night, 8)


func test_waiting_notice_once_per_night_outside() -> void:
	trade.load_state({"intro_done": true})
	_at(5, 1365)
	trade._on_time_tick(5, 1365)
	assert_eq(notes, [], "not known")
	GameState.set_flag(&"trader_known", true)
	_at(5, 1364)
	trade._on_time_tick(5, 1364)
	assert_eq(notes, [], "22:44")
	player.in_interior = true
	_at(5, 1365)
	trade._on_time_tick(5, 1365)
	assert_eq(notes, [], "inside the hut")
	player.in_interior = false
	_at(5, 1370)
	trade._on_time_tick(5, 1370)
	assert_eq(notes, [[NightTrade.TEXT_WAITING, &"info"]])
	_at(5, 1400)
	trade._on_time_tick(5, 1400)
	assert_eq(notes.size(), 1, "once per night")
	_at(6, 1366)
	trade._on_time_tick(6, 1366)
	assert_eq(notes.size(), 2, "the next night again")


func test_greeting_per_piety_tier() -> void:
	GameState.stats[&"piety"] = -30
	assert_eq(trade.greeting(), "Du bist schneller geworden. Das geht vielen so.")
	GameState.stats[&"piety"] = 70
	assert_eq(trade.greeting(), "Du kommst mit leeren Händen. Das steht dir.")


# --- save / load ----------------------------------------------------------------------------

func test_save_state_format_and_roundtrip() -> void:
	assert_eq(trade.save_state(), {"intro_done": false, "tools_given": false, "talks": 0, "last_talk_night": -1,
			"stock_night": -1, "stock_left": {}})
	_ilse_here(7)
	inv.add_item(&"coin", 5)
	trade.apply_morning(7)
	trade.give_tools(inv)
	trade.note_talk()
	trade.buy(&"juniper", 1, inv)
	var saved := trade.save_state()
	assert_eq(saved, {"intro_done": true, "tools_given": true, "talks": 1, "last_talk_night": 7, "stock_night": 7,
			"stock_left": {"linen": 3, "juniper": 3}})
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	trade.load_state({})
	assert_eq(trade.talks(), 0, "{} = a fresh trader")
	trade.load_state(json)
	assert_eq(trade.save_state(), saved, "JSON roundtrip identical")


func test_load_is_tolerant() -> void:
	trade.load_state({"intro_done": "yes", "talks": "many", "stock_night": 3.0, "stock_left": {"linen": -2, "juniper": "x"}})
	assert_eq(trade.save_state(), {"intro_done": false, "tools_given": false, "talks": 0, "last_talk_night": -1,
			"stock_night": 3, "stock_left": {"linen": 0, "juniper": 0}})
	trade.load_state({"stock_left": [1, 2]})
	assert_eq(trade.save_state().stock_left, {})


func test_saveable_identity() -> void:
	assert_eq([trade.save_id, trade.save_order], ["night_trade", 45])
	assert_true(trade.is_in_group(&"saveable") and trade.is_in_group(&"night_trade"))


# --- helpers ------------------------------------------------------------------------------

func _trader_npc() -> Npc:
	var ways := WaypointWorld.new()
	ways.points = {&"trader_far": Vector3(-22, 0, -14), &"trader_mid": Vector3(-16, 0, -6), &"trader_spot": Vector3(-12, 0, -2)}
	world.add_child(ways)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.save_id = "npc_trader"
	npc.npc_id = &"trader"
	npc.schedule = Phase4Fixtures.trader_schedule()
	npc.requires_flag = &"trader_known"
	npc.lantern_marker = &"light_lantern"
	ways.add_child(npc)
	await tree.process_frame
	return npc
