extends TestCase
## P7 (docs/PHASE8_DESIGN.md §2.6.1, §2.6.2, §3.4, §5.1, §10): Wanderers – Veit's alms once a day (one coin,
## coins_spent alms, piety alms, stats.alms_given), c_n_veit after three alms on different days or listening +
## two, his places by the clock (odd days at the graveyard gate); Hanne's day (day % 6 == 1), her two stands,
## shop_open; nothing before p8_open; save / load.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


class PietyDouble extends Node:
	var events: Array = []

	func _init() -> void:
		add_to_group(&"piety")

	func event(kind: StringName, _reason: String) -> void:
		events.append(kind)


class JournalDouble extends Node:
	var clues: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		return true


var w: Wanderers
var piety: PietyDouble
var journal: JournalDouble
var inv: Inventory
var spent: Array = []


func before_each() -> void:
	GameState.reset()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)
	TimeManager.load_state({"day": 54, "minute_of_day": 540})
	w = Wanderers.new()
	w.wanderer_data = {&"beggar": Phase8Fixtures.wanderer(&"beggar"), &"peddler": Phase8Fixtures.wanderer(&"peddler")}
	piety = PietyDouble.new()
	journal = JournalDouble.new()
	for n: Node in [w, piety, journal]:
		tree.root.add_child(n)
	inv = FakeInventory.new()
	inv.add_item(&"coin", 10)
	spent.clear()
	EventBus.coins_spent.connect(_on_spent)


func after_each() -> void:
	EventBus.coins_spent.disconnect(_on_spent)
	for n: Node in [w, piety, journal]:
		n.queue_free()
	await wait_frames(1)
	GameState.reset()


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])


func test_alms_once_a_day_with_piety_and_ledger() -> void:
	assert_eq(w.alms_block_reason(inv), "", "08:00–11:30 at the church door")
	assert_true(w.give_alms(inv))
	assert_eq(inv.count(&"coin"), 9, "one coin")
	assert_eq(spent, [[1, &"alms"]])
	assert_eq(GameState.get_stat(&"coins_spent_alms"), 1, "the ledger")
	assert_eq(GameState.get_stat(&"alms_given"), 1)
	assert_eq(piety.events, [&"alms"])
	assert_eq(w.alms_block_reason(inv), Wanderers.TEXT_TODAY)
	assert_false(w.give_alms(inv), "once a day")
	assert_eq(w.alms_count(), 1)


func test_clue_after_three_alms_on_different_days() -> void:
	for day: int in [54, 55, 56]:
		TimeManager.load_state({"day": day, "minute_of_day": 540})
		assert_true(w.give_alms(inv), "day %d" % day)
		if day < 56:
			assert_eq(journal.clues, [], "not yet after %d" % w.alms_count())
	assert_eq(journal.clues, [&"c_n_veit"], "„Drei gehen nachts\"")
	assert_eq(w.alms_count(), 3)


func test_listening_and_two_alms() -> void:
	w.give_alms(inv)
	w.note_listen(&"beggar")
	assert_eq(journal.clues, [], "one alms + listening")
	TimeManager.load_state({"day": 55, "minute_of_day": 540})
	w.give_alms(inv)
	assert_eq(journal.clues, [&"c_n_veit"], "listening + two alms")
	w.note_listen(&"peddler")


func test_block_reasons() -> void:
	inv.remove_item(&"coin", 10)
	assert_eq(w.alms_block_reason(inv), Wanderers.TEXT_NO_COIN)
	assert_eq(w.alms_block_reason(null), Wanderers.TEXT_NO_COIN)
	TimeManager.load_state({"day": 54, "minute_of_day": 60})
	inv.add_item(&"coin", 1)
	assert_eq(w.alms_block_reason(inv), Wanderers.TEXT_ABSENT, "asleep in Osric's coach house")
	GameState.set_flag(&"p8_open", false)
	TimeManager.load_state({"day": 54, "minute_of_day": 540})
	assert_eq(w.alms_block_reason(inv), Wanderers.TEXT_ABSENT, "before p8_open nobody")
	assert_false(w.present(&"beggar"))


func test_veit_places_by_the_clock() -> void:
	assert_eq(w.place(&"beggar", 54, 500), &"v_church_step")
	assert_eq(w.place(&"beggar", 55, 830), &"veit_gate", "odd days outside the graveyard gate")
	assert_eq(w.place(&"beggar", 55, 970), &"", "between gate and evening")
	assert_eq(w.place(&"beggar", 54, 830), &"v_bridge_sit", "even days on the bridge")
	assert_eq(w.place(&"beggar", 54, 1100), &"v_bridge_sit")
	assert_eq(w.place(&"beggar", 54, 1300), &"v_well_bench", "in the dark on the well bench")
	assert_eq(w.place(&"beggar", 54, 1420), &"", "asleep")


func test_hanne_every_sixth_day() -> void:
	var days: Array = []
	for day: int in range(53, 70):
		if w.peddler_day(day):
			days.append(day)
	assert_eq(days, [55, 61, 67], "day % 6 == 1")
	assert_eq(w.next_peddler_day(56), 61)
	assert_eq(w.place(&"peddler", 55, 580), &"on_the_way", "09:30 over the bridge")
	assert_eq(w.place(&"peddler", 55, 700), &"v_well_peddler", "10:00–14:00 at the well")
	assert_eq(w.place(&"peddler", 55, 900), &"on_the_way")
	assert_eq(w.place(&"peddler", 55, 950), &"peddler_gate", "15:40–16:20 at the gate")
	assert_eq(w.place(&"peddler", 55, 1010), &"", "up the forest path")
	assert_eq(w.place(&"peddler", 56, 700), &"", "not her day")
	assert_true(w.has_shop(&"peddler"))
	assert_false(w.has_shop(&"grocer"))
	TimeManager.load_state({"day": 55, "minute_of_day": 700})
	assert_true(w.shop_open(&"peddler"))
	assert_true(w.present(&"peddler"))
	TimeManager.load_state({"day": 55, "minute_of_day": 900})
	assert_false(w.shop_open(&"peddler"), "on the way she does not sell")


func test_save_load() -> void:
	w.give_alms(inv)
	w.note_listen(&"beggar")
	w.note_talk(&"peddler")
	w.note_talk(&"peddler")
	var state := w.save_state()
	var other := Wanderers.new()
	other.wanderer_data = w.wanderer_data
	tree.root.add_child(other)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state, "identical after JSON")
	assert_eq(other.alms_block_reason(inv), Wanderers.TEXT_TODAY, "no second alms after loading")
	assert_eq(other.talks(&"peddler"), 2)
	other.load_state({"alms": -4, "talks": {"x": "y"}})
	assert_eq(other.alms_count(), 0)
	other.queue_free()
	await wait_frames(1)


func test_stub_free() -> void:
	assert_false(FileAccess.get_file_as_string("res://src/systems/village/wanderers.gd").contains("## STUB ("))
