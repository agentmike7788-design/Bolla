extends TestCase
## Phase 8 (P4, docs/PHASE8_DESIGN.md §2.7, §3.4, §10): FestivalRules + Festivals – calendar days 54 / 58, the
## Lichtgang moved to p8_open_day + 3 exactly once, Kathrein falls out before p8_open_day, the day flags
## (the inputs of the other systems: no visits, no robber, Jakob free, Ilse away), the window, presence ≥ 30
## minutes in the inn (+2 once), dances (≥ „Bekannt", 2 partners, +3, 15 minutes), Osric's 12 candles, the
## early ghosts, the 18:00 evaluation lights_all / lights_some with all consequences, the end (lights_held),
## save / load. Doubles for the graves, candles, relationships, reputation, piety, visitors, ghosts and the
## player.


class RelDouble extends Relationships:
	var vals: Dictionary = {}
	var calls: Array = []

	func value(npc_id: StringName) -> int:
		return int(vals.get(npc_id, 0))

	func add(npc_id: StringName, delta: int, reason: String) -> int:
		calls.append([npc_id, delta, reason])
		vals[npc_id] = clampi(value(npc_id) + delta, 0, 100)
		return value(npc_id)


class RepDouble extends Reputation:
	var calls: Array = []

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, _reason: String) -> void:
		calls.append(["event", kind])


class PietyDouble extends Piety:
	var calls: Array = []

	func event(kind: StringName, _reason: String) -> void:
		calls.append(kind)


class VisitorsDouble extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"visitors")

	func add_goodwill(kin_id: StringName, delta: int) -> void:
		calls.append([kin_id, delta])


class GhostsDouble extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"ghosts")

	func set_early_window(from_minute: int, minutes: int, graves: PackedStringArray) -> void:
		calls.append([from_minute, minutes, graves])


class GravesDouble extends Node:
	var list: Array[GraveRecord] = []

	func _init() -> void:
		add_to_group(&"graveyard")

	func graves() -> Array[GraveRecord]:
		return list


class CareDouble extends Node:
	var lit: Dictionary = {}

	func _init() -> void:
		add_to_group(&"grave_care")

	func candle_lit(grave_id: String) -> bool:
		return lit.has(grave_id)


class PlayerDouble extends Node:
	var inventory: Inventory
	var region_id: StringName = &"graveyard"
	var interior_id: StringName = &""

	func _init() -> void:
		add_to_group(&"player")


var fest: Festivals
var rel: RelDouble
var rep: RepDouble
var piety: PietyDouble
var visitors: VisitorsDouble
var ghosts: GhostsDouble
var graves: GravesDouble
var care: CareDouble
var player: PlayerDouble
var changes: Array = []
var notes: Array = []
var _nodes: Array[Node] = []
var _day: int
var _minute: int
var _flags: Dictionary
var _stats: Dictionary
var _injected: Array[StringName] = []


func before_each() -> void:
	_day = TimeManager.day
	_minute = TimeManager.minute_of_day
	_flags = GameState.flags.duplicate(true)
	_stats = GameState.stats.duplicate(true)
	for id: StringName in Phase8Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase8Fixtures.item(id)
			_injected.append(id)
	for flag: StringName in [&"p8_open", &"p8_open_day", &"fest_kathrein_day", &"fest_lights_day", &"lights_held", &"lights_all"]:
		GameState.clear_flag(flag)
	TimeManager.day = 53
	TimeManager.minute_of_day = 360
	fest = _new_fest()
	rel = RelDouble.new()
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		rel.vals[npc] = 45
	rep = RepDouble.new()
	piety = PietyDouble.new()
	visitors = VisitorsDouble.new()
	ghosts = GhostsDouble.new()
	graves = GravesDouble.new()
	for i: int in 6:
		var g := GraveRecord.new()
		g.id = "l_%02d" % (i + 1)
		g.state = GraveRecord.State.MARKED if i < 4 else GraveRecord.State.EMPTY
		graves.list.append(g)
	care = CareDouble.new()
	player = PlayerDouble.new()
	player.inventory = Phase7Fixtures.inv_with()
	player.add_child(player.inventory)
	_nodes = [fest, rel, rep, piety, visitors, ghosts, graves, care, player]
	for n: Node in _nodes:
		tree.root.add_child(n)
	changes.clear()
	notes.clear()
	EventBus.festival_changed.connect(_on_changed)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.festival_changed.disconnect(_on_changed)
	EventBus.notification_requested.disconnect(_on_note)
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	TimeManager.day = _day
	TimeManager.minute_of_day = _minute
	GameState.flags.clear()
	GameState.flags.merge(_flags)
	GameState.stats.clear()
	GameState.stats.merge(_stats)


func _new_fest() -> Festivals:
	var f := Festivals.new()
	for data: FestivalData in Phase8Fixtures.festivals():
		f.fest_table[data.id] = data
	# The fixture has no guest list (W0 effects are proposals; data/ carries them).
	var kathrein := (Database.festival(&"fest_kathrein") as FestivalData)
	if kathrein != null:
		f.fest_table[&"fest_kathrein"] = kathrein
	f.villager_ids.assign(Phase8Fixtures.STORY_NPCS)
	f.household_ids.assign(Phase8Fixtures.HOUSEHOLD_KIN)
	f.relationship_config = Phase8Fixtures.relationship_config()
	return f


func _on_changed(id: StringName, state: StringName) -> void:
	changes.append([id, state])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _open(day: int) -> void:
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", day)


func _at(day: int, minute: int) -> void:
	TimeManager.day = day
	TimeManager.minute_of_day = minute
	fest.apply_morning(day)
	fest.apply_minute(day, minute)


# --- FestivalRules ------------------------------------------------------------------------------------

func test_rules_effective_days() -> void:
	var k := Phase8Fixtures.festival(&"fest_kathrein")
	var l := Phase8Fixtures.festival(&"fest_lights")
	assert_eq([FestivalRules.effective_day(k, 53), FestivalRules.effective_day(k, 54), FestivalRules.effective_day(k, 55)],
			[54, 54, -1], "§2.7.1: before p8_open_day it falls out")
	assert_eq([FestivalRules.effective_day(l, 53), FestivalRules.effective_day(l, 55), FestivalRules.effective_day(l, 56),
			FestivalRules.effective_day(l, 60)], [58, 58, 59, 63], "§2.7.2: p8_open_day + 3")
	assert_eq(FestivalRules.effective_day(l, 0), -1, "not open")
	assert_false(FestivalRules.shifted(l, 58))
	assert_true(FestivalRules.shifted(l, 59))
	assert_eq([FestivalRules.lights_result(4, 4, l), FestivalRules.lights_result(2, 4, l), FestivalRules.lights_result(1, 4, l),
			FestivalRules.lights_result(0, 0, l)], [&"all", &"some", &"none", &"none"])
	var kd := Database.festival(&"fest_kathrein") as FestivalData
	assert_eq(FestivalRules.guests_at(kd, 1150), [&"grocer", &"innkeeper", &"mayor", &"priest", &"smith"] as Array[StringName],
			"Lenz 19:00–20:00, Liesel from 20:00, Quast not")
	assert_eq(FestivalRules.guests_at(kd, 1210), [&"grocer", &"innkeeper", &"mayor", &"smith", &"washer"] as Array[StringName])
	assert_true(FestivalRules.presence_reached(kd, 1000, 1030))
	assert_false(FestivalRules.presence_reached(kd, 1000, 1029))
	assert_false(FestivalRules.presence_reached(kd, -1, 1030))


# --- the calendar ------------------------------------------------------------------------------------

func test_days_flags_and_states_arc_a() -> void:
	fest.apply_morning(53)
	assert_eq([fest.fest_day(&"fest_kathrein"), fest.fest_day(&"fest_lights")], [-1, -1], "nothing before p8_open")
	_open(53)
	fest.apply_morning(53)
	assert_eq([fest.fest_day(&"fest_kathrein"), fest.fest_day(&"fest_lights")], [54, 58])
	assert_eq([GameState.get_flag(&"fest_kathrein_day"), GameState.get_flag(&"fest_lights_day")], [54, 58], "day flags")
	assert_eq(fest.today(), &"")
	_at(54, 360)
	assert_eq([fest.today(), fest.state(&"fest_kathrein"), fest.running()], [&"fest_kathrein", &"announced", &""])
	assert_has(notes, "Heute Abend ist Kathreintanz im Holderkrug (ab 19:00).")
	_at(54, 1140)
	assert_eq(fest.running(), &"fest_kathrein", "19:00")
	_at(54, 1380)
	assert_eq([fest.state(&"fest_kathrein"), fest.running()], [&"ended", &""], "23:00")
	assert_has(notes, "Kathrein stellt den Tanz ein. Bis Weihnachten wird hier gesessen.")
	assert_eq(changes, [[&"fest_kathrein", &"announced"], [&"fest_kathrein", &"running"], [&"fest_kathrein", &"ended"]])


func test_late_opening_drops_kathrein_and_shifts_the_lights_once() -> void:
	_open(57)
	_at(57, 400)
	assert_eq([fest.fest_day(&"fest_kathrein"), fest.state(&"fest_kathrein")], [-1, &"cancelled"], "Kathrein falls out")
	assert_null(GameState.get_flag(&"fest_kathrein_day"), "no day flag")
	assert_eq(fest.fest_day(&"fest_lights"), 60, "57 + 3")
	_at(60, 400)
	assert_eq(fest.today(), &"fest_lights")
	assert_true(notes.any(func(n: String) -> bool: return n.contains("Wir haben ihn verschoben.")), "Lenz' line")
	_at(60, 1110)
	assert_true(GameState.flag_on(&"lights_held"))
	# Saved days stay; a new computation after the Lichtgang gives none (once per game).
	var saved := fest.save_state()
	var again := _new_fest()
	again.load_state(saved)
	assert_eq(again.fest_day(&"fest_lights"), 60)
	again.free()
	var fresh := _new_fest()
	TimeManager.day = 61
	fresh.apply_morning(61)
	assert_eq(fresh.fest_day(&"fest_lights"), -1, "no second Lichtgang")
	fresh.free()


# --- Kathrein ------------------------------------------------------------------------------------------

func test_presence_thirty_minutes_once() -> void:
	_open(53)
	_at(54, 1140)
	player.region_id = &"village"
	player.interior_id = &"inn"
	_at(54, 1150)
	_at(54, 1170)
	assert_false(fest.presence_done(), "20 minutes")
	player.interior_id = &""
	_at(54, 1175)
	player.interior_id = &"inn"
	_at(54, 1180)
	_at(54, 1205)
	assert_false(fest.presence_done(), "left in between – counts anew")
	_at(54, 1210)
	assert_true(fest.presence_done())
	var gained := rel.calls.filter(func(c: Array) -> bool: return c[2] == "Kathreintanz")
	assert_eq(gained.map(func(c: Array) -> StringName: return c[0]), [&"grocer", &"innkeeper", &"mayor", &"smith", &"washer"],
			"+2 with everyone present (Lenz has gone at 20:00)")
	assert_true(gained.all(func(c: Array) -> bool: return c[1] == 2))
	_at(54, 1300)
	assert_eq(rel.calls.filter(func(c: Array) -> bool: return c[2] == "Kathreintanz").size(), 5, "once")


func test_dances_two_partners_at_least_acquainted() -> void:
	_open(53)
	assert_eq(fest.dance_block_reason(&"grocer"), FestivalRules.TEXT_NO_DANCE)
	_at(54, 1150)
	assert_eq(fest.dance_block_reason(&"grocer"), FestivalRules.TEXT_NOT_IN_ROOM)
	player.region_id = &"village"
	player.interior_id = &"inn"
	assert_true(fest.dance_block_reason(&"surgeon").ends_with("ist gerade nicht da."), "Quast does not come")
	rel.vals[&"mayor"] = 10
	assert_eq(fest.dance_block_reason(&"mayor"), FestivalRules.TEXT_TIER, "≥ „Bekannt“")
	assert_eq(fest.dance_block_reason(&"grocer"), "")
	assert_true(fest.dance(&"grocer"))
	assert_eq([rel.value(&"grocer"), GameState.get_stat(&"dances"), TimeManager.minute_of_day], [48, 1, 1165], "+3, 15 minutes")
	assert_true(fest.dance_block_reason(&"grocer").begins_with("Mit "), "once per partner")
	assert_true(fest.dance(&"innkeeper"))
	assert_eq(fest.dance_block_reason(&"smith"), FestivalRules.TEXT_PARTNERS, "two partners")
	assert_eq(fest.danced(), [&"grocer", &"innkeeper"] as Array[StringName])


# --- Lichtgang -----------------------------------------------------------------------------------------

func test_lights_candles_early_ghosts_and_lights_all() -> void:
	_open(53)
	_at(58, 400)
	assert_eq(fest.today(), &"fest_lights")
	assert_eq(player.inventory.count(&"grave_candle"), 0)
	_at(58, 460)
	assert_eq(player.inventory.count(&"grave_candle"), 12, "Osric brings Lenz' 12 candles at 07:40")
	_at(58, 900)
	assert_eq(player.inventory.count(&"grave_candle"), 12, "once")
	care.lit = {"l_01": true, "l_02": true, "l_03": true, "l_04": true}
	assert_eq(fest.lights_count(), Vector2i(4, 4), "„Kein Grab ohne Licht: 4/4“")
	_at(58, 1020)
	assert_eq(fest.running(), &"fest_lights")
	assert_eq(ghosts.calls, [[1020, 30, PackedStringArray(["l_01", "l_02", "l_03", "l_04"])]], "the early ghosts (display)")
	_at(58, 1080)
	assert_eq(fest.lights_result(), &"all")
	assert_has(rep.calls, ["event", &"lights_all"], "Ruf +3")
	assert_eq(rel.value(&"priest"), 50, "Lenz +2 +3")
	assert_eq(rel.value(&"smith"), 47, "every villager +2")
	assert_eq(visitors.calls.size(), 4, "every household goodwill +2")
	assert_true(visitors.calls.all(func(c: Array) -> bool: return c[1] == 2))
	assert_eq(piety.calls, [&"lights_all"], "Pietät +2")
	assert_true(GameState.flag_on(&"lights_all"))
	_at(58, 1100)
	assert_eq(rep.calls.size(), 1, "evaluated once")
	_at(58, 1110)
	assert_eq(fest.state(&"fest_lights"), &"ended", "18:30")
	assert_true(GameState.flag_on(&"lights_held"))


func test_lights_some_and_none() -> void:
	_open(53)
	care.lit = {"l_01": true, "l_02": true}
	_at(58, 1080)
	assert_eq(fest.lights_result(), &"some", "half of the occupied graves")
	assert_eq(rep.calls, [["event", &"lights_some"]], "Ruf +1")
	assert_eq(piety.calls, [])
	assert_false(GameState.flag_on(&"lights_all"))
	var other := _new_fest()
	_nodes.append(other)
	fest.free()
	tree.root.add_child(other)
	fest = other
	rep.calls.clear()
	care.lit = {"l_01": true}
	_at(58, 1080)
	assert_eq([fest.lights_result(), rep.calls], [&"none", []])


func test_save_load_during_the_lights() -> void:
	_open(53)
	care.lit = {"l_01": true}
	_at(58, 460)
	_at(58, 1040)
	var saved := fest.save_state()
	var other := _new_fest()
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.save_state(), saved, "17:20 round trip")
	assert_eq([other.fest_day(&"fest_lights"), other.state(&"fest_lights"), other.lights_result()], [58, &"running", &""])
	other.load_state({"days": {"fest_lights": "x", "fest_kathrein": -7}, "state": {"fest_lights": "dancing"}, "danced": [3, "grocer"],
			"lights_result": "maybe", "presence": {"since": "?"}})
	assert_eq([other.fest_day(&"fest_lights"), other.fest_day(&"fest_kathrein"), other.state(&"fest_lights"), other.danced(),
			other.lights_result()], [-1, -1, &"", [&"grocer"] as Array[StringName], &""], "tolerant")
	other.free()


func test_data_matches_the_fixtures() -> void:
	for f: FestivalData in Phase8Fixtures.festivals():
		var d := Database.festival(f.id) as FestivalData
		assert_not_null(d, String(f.id))
		if d == null:
			continue
		assert_eq([d.calendar_day, d.shift_rule, d.shift_days, d.day_flag, d.window, d.region, d.music_context],
				[f.calendar_day, f.shift_rule, f.shift_days, f.day_flag, f.window, f.region, f.music_context], String(f.id))
		for key: Variant in f.effects:
			assert_eq(d.effects.get(key), f.effects[key], "%s effects.%s" % [f.id, key])
	assert_eq(Database.festivals().map(func(f: FestivalData) -> StringName: return f.id), [&"fest_kathrein", &"fest_lights"])
