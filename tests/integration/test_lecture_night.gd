extends TestCase
## P8 (docs/PHASE7_DESIGN.md §2.6.4, §10): a lecture night at systems level – the invited gravedigger
## at 22:30 (the surgery door still shut), the door opens at 23:00 only on the lecture night, a save /
## load round trip in the middle of the night before the lecture, the lecture with a real specimen taken
## from a corpse, the clock runs on to the morning and the rumour of the deterministic roll lands once.
## The walk to the village and the HouseDoor itself are P1's (RegionTravel / HouseDoor, W2 world); here
## the clock jumps the 30 travel minutes like RegionTravel does.

class ManagerDouble extends CorpseManager:
	func _ready() -> void:
		pass

	func put(r: CorpseRecord) -> void:
		_records[r.id] = r


class RelDouble extends Relationships:
	var adds: Array = []

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		adds.append([npc_id, delta])
		return 0


var world: Node
var specimens: Specimens
var lectures: Lectures
var rel: RelDouble
var rep: Reputation
var inv: Inventory
var _injected: Array[StringName] = []


func before_each() -> void:
	GameState.reset()
	GameState.stats[&"reputation"] = 50
	GameState.stats[&"piety"] = 0
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase7Fixtures.item(id)
			_injected.append(id)
	var cfg := Phase7Fixtures.anatomy_config()
	world = Node.new()
	world.name = "NightWorld"
	var manager := ManagerDouble.new()
	var r := Phase4Fixtures.corpse([], &"fever", 0.8)
	r.id = "c_7"
	r.display_name = "Jakob Kehr"
	manager.put(r)
	world.add_child(manager)
	specimens = Specimens.new()
	specimens.config = cfg
	specimens.findings = Phase7Fixtures.findings()
	world.add_child(specimens)
	lectures = Lectures.new()
	lectures.config = cfg
	world.add_child(lectures)
	rel = RelDouble.new()
	world.add_child(rel)
	var piety := Piety.new()
	piety.config = Phase7Fixtures.piety_config()
	world.add_child(piety)
	rep = Reputation.new()
	rep.config = Phase7Fixtures.reputation_config()
	world.add_child(rep)
	tree.root.add_child(world)
	inv = Inventory.new()
	inv.slot_count = 10


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	inv.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	GameState.reset()


## The first lecture night (from day 3) whose roll is `wanted`.
func _night(wanted: bool) -> int:
	for day: int in range(3, 600, 3):
		if LectureRules.rumor(day, lectures.seed, rep.tier(), lectures.config) == wanted:
			return day
	return -1


func _evening(night: int) -> String:
	TimeManager.load_state({"day": night, "minute_of_day": 20 * 60})
	inv.add_item(&"prep_jar", 1)
	inv.add_item(&"spirits", 1)
	var uid := specimens.harvest("c_7", &"heart", &"jar", inv)
	lectures.invite()
	lectures.learn(&"l_lung")
	lectures.learn(&"l_liver")
	TimeManager.load_state({"day": night, "minute_of_day": 22 * 60 + 30})
	return uid


func test_a_discovered_lecture_night() -> void:
	var night := _night(true)
	assert_true(night > 0)
	var uid := _evening(night)
	assert_ne(uid, "")
	assert_false(lectures.door_open(&"door_surgery"), "22:30: still shut")
	TimeManager.advance(30)
	assert_true(lectures.door_open(&"door_surgery"), "23:00 after the walk: open")
	# Save / load in the middle of the night, before the lecture.
	var saved := {"specimens": specimens.save_state(), "lectures": lectures.save_state(), "inv": inv.save_state()}
	var json := JSON.parse_string(JSON.stringify(saved)) as Dictionary
	specimens.load_state(json.specimens)
	lectures.load_state(json.lectures)
	inv.load_state(json.inv)
	assert_true(lectures.door_open(&"door_surgery"), "still open after the load")
	assert_true(inv.has_uid(uid))
	var result := lectures.hold(uid, inv)
	TimeManager.advance(60)
	assert_true(result.ok)
	assert_eq([result.fee, result.teaching, result.rumor], [6, &"l_heart", true])
	assert_eq(specimens.get_record(uid).state, &"lectured")
	TimeManager.advance(30)
	assert_false(lectures.door_open(&"door_surgery"), "after 00:30: over")
	var before := GameState.get_stat(&"reputation")
	# Walk home, sleep: the clock runs to the morning (it is 00:30 now).
	TimeManager.advance(5 * 60)
	assert_eq(GameState.get_stat(&"reputation"), before, "before 06:00 nothing")
	TimeManager.advance(60)
	assert_eq(GameState.get_stat(&"reputation"), before - 4, "the rumour at 06:00")
	assert_true(rel.adds.has([&"priest", -3]) and rel.adds.has([&"washer", -2]))
	TimeManager.advance(24 * 60)
	assert_eq(rel.adds.count([&"priest", -3]), 1, "once")
	assert_eq(lectures.rumor_pending_day(), 0)


func test_a_quiet_lecture_night_and_no_door_on_other_nights() -> void:
	var night := _night(false)
	var uid := _evening(night)
	TimeManager.advance(45)
	assert_eq(lectures.night_line(), Lectures.TEXT_QUIET)
	assert_true(lectures.hold(uid, inv).ok)
	TimeManager.advance(9 * 60)
	assert_false(rel.adds.has([&"priest", -3]), "nobody saw the light")
	assert_eq(lectures.rumor_pending_day(), 0)
	TimeManager.load_state({"day": night + 1, "minute_of_day": 23 * 60 + 30})
	assert_false(lectures.door_open(&"door_surgery"), "the next night: shut")
