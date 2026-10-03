extends TestCase
## P8 (docs/PHASE7_DESIGN.md §2.6.4, §3.4, §10): LectureRules and Systems/Lectures – the lecture night
## (day % 3, 23:00–00:30, the surgery door only then and only for the invited), the invitation, one lecture
## per evening, no bundle, the fee (organ, standing), the teaching once, piety −3, Quast +3, the
## deterministic rumour (25 % / 10 % from „Geschätzt") with reputation, priest and washer on the next
## morning once; save / load; LectureSet shows students and the closed jar, nothing else.

class RelDouble extends Relationships:
	var adds: Array = []
	var surgeon := &"stranger"

	func tier(npc_id: StringName) -> StringName:
		return surgeon if npc_id == &"surgeon" else &"stranger"

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		adds.append([npc_id, delta])
		return 0


class ManagerDouble extends CorpseManager:
	func _ready() -> void:
		pass

	func put(r: CorpseRecord) -> void:
		_records[r.id] = r


var cfg: AnatomyConfig
var world: Node
var lectures: Lectures
var specimens: Specimens
var rel: RelDouble
var piety: Piety
var rep: Reputation
var inv: Inventory
var held: Array = []
var notes: Array = []
var _injected: Array[StringName] = []


func before_each() -> void:
	GameState.reset()
	GameState.stats[&"piety"] = 0
	GameState.stats[&"reputation"] = 50
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase7Fixtures.item(id)
			_injected.append(id)
	cfg = Phase7Fixtures.anatomy_config()
	world = Node.new()
	world.name = "LectureWorld"
	var manager := ManagerDouble.new()
	var r := Phase4Fixtures.corpse([], &"fever", 0.9)
	r.id = "c_1"
	manager.put(r)
	world.add_child(manager)
	specimens = Specimens.new()
	specimens.config = cfg
	world.add_child(specimens)
	lectures = Phase7Fixtures.lecture_night(3)
	world.add_child(lectures)
	rel = RelDouble.new()
	world.add_child(rel)
	piety = Piety.new()
	piety.config = Phase7Fixtures.piety_config()
	world.add_child(piety)
	rep = Reputation.new()
	rep.config = Phase7Fixtures.reputation_config()
	world.add_child(rep)
	tree.root.add_child(world)
	inv = Inventory.new()
	inv.slot_count = 8
	held.clear()
	notes.clear()
	EventBus.lecture_held.connect(_on_held)
	EventBus.notification_requested.connect(_on_note)
	_at(3, 23 * 60 + 30)


func after_each() -> void:
	EventBus.lecture_held.disconnect(_on_held)
	EventBus.notification_requested.disconnect(_on_note)
	if is_instance_valid(world):
		world.free()
	inv.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	GameState.reset()


func _on_held(day: int, organ: StringName, fee: int, rumor: bool) -> void:
	held.append([day, organ, fee, rumor])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _at(day: int, minute: int) -> void:
	TimeManager.load_state({"day": day, "minute_of_day": minute})


## A specimen record held in `inv` (through load_state, like the fixtures).
func _piece(organ: StringName, container: StringName = &"jar", clarity: float = 0.9) -> String:
	var s := Phase7Fixtures.specimen(organ, container, clarity, null, TimeManager.total_minutes())
	s.corpse_id = "c_1"
	var records: Array = []
	for uid: String in specimens.of_corpse("c_1"):
		records.append(specimens.get_record(uid).to_dict())
	records.append(s.to_dict())
	specimens.load_state({"next": 1, "records": records})
	inv.add_unique(SpecimenRules.item_for(container), s.uid)
	return s.uid


func test_lecture_night_every_third_day_23_to_0030() -> void:
	var nights := []
	for day: int in range(1, 10):
		if LectureRules.is_lecture_night(day, 23 * 60 + 10, cfg):
			nights.append(day)
	assert_eq(nights, [3, 6, 9])
	assert_false(LectureRules.is_lecture_night(3, 22 * 60 + 59, cfg), "22:59")
	assert_true(LectureRules.is_lecture_night(3, 23 * 60, cfg), "23:00")
	assert_true(LectureRules.is_lecture_night(4, 29, cfg), "00:29 belongs to the night of day 3")
	assert_false(LectureRules.is_lecture_night(4, 30, cfg), "00:30 over")
	assert_false(LectureRules.is_lecture_night(3, 29, cfg), "00:29 of day 3 = the night of day 2")
	assert_eq(LectureRules.night_of(4, 10, cfg), 3)
	assert_false(LectureRules.is_lecture_night(0, 1390, cfg), "day 0 never")


func test_door_only_on_lecture_nights_for_the_invited() -> void:
	assert_true(lectures.tonight())
	assert_true(lectures.door_open(&"door_surgery"))
	assert_false(lectures.door_open(&"door_inn"), "only the surgery")
	_at(3, 22 * 60)
	assert_false(lectures.door_open(&"door_surgery"), "before 23:00")
	_at(4, 15)
	assert_true(lectures.door_open(&"door_surgery"), "00:15")
	_at(5, 23 * 60 + 30)
	assert_false(lectures.door_open(&"door_surgery"), "not every night")
	var uninvited := Lectures.new()
	uninvited.config = cfg
	_at(3, 23 * 60 + 30)
	assert_false(uninvited.door_open(&"door_surgery"), "not invited")
	uninvited.free()


func test_invitation() -> void:
	var l := Lectures.new()
	l.config = cfg
	world.add_child(l)
	assert_false(l.invite_ready(), "anatomy unknown")
	GameState.set_flag(&"anatomy_known", true)
	assert_false(l.invite_ready(), "Quast still a stranger")
	rel.surgeon = &"acquainted"
	assert_false(l.invite_ready(), "no specimen sold or researched yet")
	GameState.stats[&"specimens_researched"] = 1
	assert_true(l.invite_ready())
	assert_true(l.invite())
	assert_false(l.invite(), "once")
	assert_true(l.invited())
	assert_false(l.invite_ready())


func test_fee_by_organ_and_standing() -> void:
	assert_eq(LectureRules.fee(&"heart", 0, cfg), 6)
	assert_eq(LectureRules.fee(&"eyes", 0, cfg), 7)
	assert_eq(LectureRules.fee(&"hand", 0, cfg), 8)
	assert_eq(LectureRules.fee(&"liver", 0, cfg), 5)
	assert_eq(LectureRules.fee(&"liver", 2, cfg), 7, "+1 per standing")


func test_block_reasons() -> void:
	var jar := Phase7Fixtures.specimen(&"heart", &"jar", 0.9, null, 0)
	assert_eq(LectureRules.block_reason(jar, 0, false, false, cfg), LectureRules.TEXT_NOT_INVITED)
	assert_eq(LectureRules.block_reason(jar, 0, true, true, cfg), LectureRules.TEXT_HELD, "one lecture per evening")
	assert_eq(LectureRules.block_reason(jar, 0, true, false, cfg), "")
	var bundle := Phase7Fixtures.specimen(&"heart", &"bundle", 0.9, null, 0)
	assert_eq(LectureRules.block_reason(bundle, 0, true, false, cfg), "Kein Bündel. Quast will ein Glas.")
	var cloudy := Phase7Fixtures.specimen(&"heart", &"jar", 0.45, null, 0)
	assert_eq(LectureRules.block_reason(cloudy, 0, true, false, cfg), LectureRules.TEXT_CLOUDY)
	assert_eq(LectureRules.block_reason(Phase7Fixtures.specimen(&"hand", &"bone", 0.5, null, 0), 0, true, false, cfg), "",
			"bone specimen, exactly 0.5")
	assert_eq(LectureRules.block_reason(Phase7Fixtures.specimen(&"heart", &"display", 0.7, null, 0), 0, true, false, cfg), "")
	jar.state = &"sold"
	assert_eq(LectureRules.block_reason(jar, 0, true, false, cfg), LectureRules.TEXT_GONE)
	assert_eq(LectureRules.block_reason(null, 0, true, false, cfg), LectureRules.TEXT_GONE)


func test_hold_pays_teaches_costs_and_once_per_evening() -> void:
	var heart := _piece(&"heart")
	var lung := _piece(&"lung")
	var result := lectures.hold(heart, inv)
	assert_true(result.ok)
	assert_eq([result.fee, result.organ, result.teaching, result.learned], [6, &"heart", &"l_heart", true])
	assert_eq(inv.count(&"coin"), 6)
	assert_false(inv.has_uid(heart), "the jar stays in the cabinet")
	assert_eq(specimens.get_record(heart).state, &"lectured")
	assert_true(lectures.known_teachings().has("l_heart"))
	assert_eq(GameState.get_stat(&"piety"), -3, "piety −3")
	assert_eq(int(GameState.get_flag(&"piety_used_day", 0)), 3)
	assert_eq(rel.adds, [[&"surgeon", 3]], "Quast +3")
	assert_eq(GameState.get_stat(&"lectures_attended"), 1)
	assert_eq(held.size(), 1)
	assert_eq(held[0].slice(0, 3), [3, &"heart", 6])
	var again := lectures.hold(lung, inv)
	assert_eq([again.ok, again.reason], [false, LectureRules.TEXT_HELD], "one per evening")
	assert_true(inv.has_uid(lung))
	_at(6, 23 * 60 + 5)
	var second := lectures.hold(lung, inv)
	assert_true(second.ok, "the next lecture night")
	assert_false(second.learned, "l_lung came with the case")
	assert_has(notes, Lectures.TEXT_KNOWN)
	assert_eq(lectures.attended(), 2)


func test_hold_refusals() -> void:
	var bundle := _piece(&"heart", &"bundle")
	assert_eq(lectures.hold(bundle, inv).reason, LectureRules.TEXT_BUNDLE)
	var jar := _piece(&"liver")
	_at(4, 60)
	assert_eq(lectures.hold(jar, inv).reason, LectureRules.TEXT_NOT_TONIGHT)
	_at(3, 23 * 60 + 30)
	var other := Inventory.new()
	assert_eq(lectures.hold(jar, other).reason, LectureRules.TEXT_GONE, "not in this inventory")
	other.free()
	assert_eq(GameState.get_stat(&"lectures_attended"), 0)


func test_rumor_is_deterministic_and_rarer_when_esteemed() -> void:
	var common := 0
	var esteemed := 0
	for day: int in range(3, 3003, 3):
		if LectureRules.rumor(day, 7, &"respected", cfg):
			common += 1
		if LectureRules.rumor(day, 7, &"esteemed", cfg):
			esteemed += 1
		assert_eq(LectureRules.rumor(day, 7, &"respected", cfg), LectureRules.rumor(day, 7, &"respected", cfg))
	assert_true(common > 190 and common < 310, "≈ 25 %% (%d / 1000)" % common)
	assert_true(esteemed > 50 and esteemed < 150, "≈ 10 %% from „Geschätzt\" (%d / 1000)" % esteemed)
	assert_eq(LectureRules.rumor(9, 7, &"renowned", cfg), LectureRules.rumor(9, 7, &"esteemed", cfg), "Gerühmt counts as Geschätzt")


func _rumor_night() -> int:
	for day: int in range(3, 300, 3):
		if LectureRules.rumor(day, lectures.seed, rep.tier(), cfg):
			return day
	return -1


func test_rumor_on_the_next_morning_once() -> void:
	var night := _rumor_night()
	assert_true(night > 0)
	_at(night, 23 * 60 + 10)
	lectures.load_state({"invited": true, "teachings": ["l_lung", "l_liver"]})
	var uid := _piece(&"stomach")
	var result := lectures.hold(uid, inv)
	assert_true(result.rumor)
	assert_eq(held.back()[3], true)
	assert_eq(lectures.rumor_pending_day(), night + 1)
	var rep_before := GameState.get_stat(&"reputation")
	lectures.apply_morning(night)
	assert_eq(GameState.get_stat(&"reputation"), rep_before, "not the same night")
	EventBus.hour_changed.emit(night + 1, 3)
	assert_eq(GameState.get_stat(&"reputation"), rep_before, "only from 06:00")
	EventBus.hour_changed.emit(night + 1, 6)
	assert_eq(GameState.get_stat(&"reputation"), rep_before - 4, "reputation −4")
	assert_eq(rel.adds.slice(1), [[&"priest", -3], [&"washer", -2]], "priest −3, Liesel −2")
	assert_has(notes, Lectures.TEXT_RUMOR)
	lectures.apply_morning(night + 1)
	EventBus.hour_changed.emit(night + 1, 7)
	assert_eq(GameState.get_stat(&"reputation"), rep_before - 4, "once")


func test_night_line_without_numbers() -> void:
	assert_true(lectures.night_line() in [Lectures.TEXT_QUIET, Lectures.TEXT_RISKY])
	assert_false(lectures.night_line().contains("%"))
	_at(5, 600)
	assert_eq(lectures.night_line(), "")


func test_learn_once_and_save_load() -> void:
	assert_true(lectures.learn(&"l_eyes"))
	assert_false(lectures.learn(&"l_eyes"))
	assert_false(lectures.learn(&""))
	var uid := _piece(&"kidneys")
	lectures.hold(uid, inv)
	var state := lectures.save_state()
	assert_eq(state.keys(), ["invited", "last_day", "attended", "teachings", "rumor_day"])
	var back := Lectures.new()
	back.load_state(JSON.parse_string(JSON.stringify(state)) as Dictionary)
	assert_eq(back.save_state(), state, "round trip")
	assert_eq(Array(back.known_teachings()), ["l_lung", "l_liver", "l_eyes", "l_kidneys"])
	back.load_state({"invited": "yes", "teachings": [3, "l_x", "l_x"], "last_day": "z"})
	assert_eq([back.invited(), Array(back.known_teachings())], [false, ["l_x"]], "tolerant")
	back.free()
	var fresh := Lectures.new()
	assert_eq(fresh.save_state(), {})
	fresh.free()


func test_teaching_of_an_organ() -> void:
	for organ: StringName in AnatomyConfig.ORGANS:
		assert_eq(Lectures.teaching_of(organ), StringName("l_" + String(organ)))
	assert_eq(Lectures.teaching_of(&""), &"")
	for t: TeachingData in Phase7Fixtures.teachings():
		var real := Database.teaching(t.id) as TeachingData
		assert_not_null(real, String(t.id))
		if real != null:
			assert_eq([real.organ, real.text], [t.organ, t.text], "§2.6.5 " + String(t.id))


func test_lecture_set_shows_students_and_the_closed_jar() -> void:
	var set := (load("res://src/entities/lecture_set/lecture_set.tscn") as PackedScene).instantiate() as LectureSet
	for i: int in 3:
		var s := Node3D.new()
		s.name = "Student%d" % (i + 1)
		s.add_child(MeshInstance3D.new())
		set.add_child(s)
	var jar := Node3D.new()
	jar.name = "Jar"
	set.add_child(jar)
	world.add_child(set)
	assert_eq(set.students().size(), 3)
	assert_false(set.students()[0].visible, "hidden until a lecture")
	assert_false(set.jar().visible)
	set.show_lecture(&"heart")
	assert_true(set.is_shown())
	assert_eq(set.organ(), &"heart")
	assert_true(set.students().all(func(s: Node3D) -> bool: return s.visible))
	assert_true(set.jar().visible)
	set.hide_lecture()
	assert_false(set.is_shown())
	await tree.create_timer(0.9).timeout
	assert_false(set.students()[0].visible, "faded out")
	assert_null(set.get_node_or_null(^"Interactable"), "presentation only")
	set.free()
