extends TestCase
## Phase 8 (P4, docs/PHASE8_DESIGN.md §2.7.2, §10): the Lichtgang evening in the real world – the v6 state
## slot_p7_day53_neighbor (Phase 8 opened on day 53) through the real SaveManager, a Festivals node in
## Systems (W-Welt adds it to the builder in W2), the real Graveyard / Relationships / Reputation / Piety /
## GhostManager / Player, the clock driven through TimeManager.advance: Osric's 12 candles at 07:40, the
## procession plan (Lenz in front, staggered, down 18:00–18:30), the villagers' own lights at their graves,
## the player's candles on the graves without kin, the early ghosts, a round trip at 17:20 (state of the
## festival identical, runtime schedules rebuilt), the 18:00 evaluation lights_all with its consequences
## and the end at 18:30 (lights_held).
## Until P2 (GraveCare) / P1 (ScheduleBuilder) / W-Welt (Npc on the graveyard) are merged, a candle double
## stands in for GraveCare when the world has none; the procession is checked as plan.

const TIMEOUT := 240.0
var TEST_SAVES := TestCase.user_dir("test_lights_evening")
const SLOT := 7


## GraveCare stand-in: a candle burns once lit (GraveCare.light takes one grave_candle from `inv`).
class CandleCare extends Node:
	var lit: Dictionary = {}

	func _init() -> void:
		add_to_group(&"grave_care")

	func candle_lit(grave_id: String) -> bool:
		return lit.has(grave_id)

	func light(grave_id: String, inv: Inventory) -> bool:
		if lit.has(grave_id) or inv == null or not inv.remove_item(&"grave_candle", 1):
			return false
		lit[grave_id] = true
		return true


var _injected: Array[StringName] = []


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	for id: StringName in Phase8Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase8Fixtures.item(id)
			_injected.append(id)


func after_each() -> void:
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	UIState.clear()
	TestCase.remove_user_dir(TEST_SAVES)


func test_lights_evening_in_the_real_world() -> void:
	assert_eq(Phase8Fixtures.install_save_v6("slot_p7_day53_neighbor", TEST_SAVES, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	TimeManager.running = false
	var world := tree.current_scene as WorldRoot
	assert_not_null(world)
	var systems := world.get_node("Systems")
	var player := world.get_player()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)
	var fest := systems.get_node_or_null("Festivals") as Festivals
	if fest == null:
		fest = Festivals.new()
		fest.name = "Festivals"
		systems.add_child(fest)
	var care: Node = tree.get_first_node_in_group(&"grave_care")
	if care == null:
		care = CandleCare.new()
		systems.add_child(care)
	var graveyard := tree.get_first_node_in_group(&"graveyard") as Graveyard
	var occupied := PackedStringArray()
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED:
			occupied.append(g.id)
	assert_true(occupied.size() >= 30, "Bogen A: ≈ 34 occupied graves (%d)" % occupied.size())

	# The morning of the Lichtgang (day 58 = 29. Nebelung).
	TimeManager.load_state({"day": 58, "minute_of_day": 359})
	TimeManager.advance(1)
	assert_eq([fest.fest_day(&"fest_lights"), fest.today(), fest.state(&"fest_lights")], [58, &"fest_lights", &"announced"])
	assert_eq(int(GameState.get_flag(&"fest_lights_day")), 58)
	var before := player.inventory.count(&"grave_candle")
	TimeManager.advance(100)
	assert_eq(player.inventory.count(&"grave_candle"), before + 12, "07:40 Osric brings Lenz' 12 candles")

	# The plan: Lenz in front, Esch and Theres at their old graves, Jakob with the lantern; staggered.
	var plan := fest.procession_plan()
	assert_eq(plan[0].npc, &"npc_priest", "Lenz vorn")
	assert_eq(plan.back().npc, &"npc_apprentice")
	for i: int in range(1, plan.size()):
		assert_true(plan[i].arrive >= plan[i - 1].arrive and plan[i].leave >= plan[i - 1].leave, "staggered")
	assert_true(plan.all(func(e: Dictionary) -> bool: return e.arrive >= 1005 and e.leave <= 1110))

	# The afternoon: the player sets Lenz' candles (and own ones) on the graves the families will not light.
	TimeManager.advance(15 * 60 - TimeManager.minute_of_day)
	var family := {}
	for e: Dictionary in plan:
		for gid: String in e.graves:
			family[gid] = true
	var to_light := Array(occupied).filter(func(gid: String) -> bool: return not family.has(gid))
	player.inventory.add_item(&"grave_candle", maxi(0, to_light.size() - player.inventory.count(&"grave_candle")))
	for gid: String in to_light:
		assert_true(bool(care.call(&"light", gid, player.inventory)), "candle on " + gid)
	assert_eq(fest.lights_count().x, to_light.size())

	# 17:00 the procession is on the hill, the families light theirs; 17:20 a round trip.
	TimeManager.advance(17 * 60 + 20 - TimeManager.minute_of_day)
	assert_eq(fest.running(), &"fest_lights")
	assert_eq(fest.lights_count(), Vector2i(occupied.size(), occupied.size()), "„Kein Grab ohne Licht“")
	var saved := fest.save_state()
	systems.remove_child(fest)
	fest.free()
	fest = Festivals.new()
	fest.name = "Festivals"
	systems.add_child(fest)
	fest.load_state(JSON.parse_string(JSON.stringify(saved)))
	fest.post_load()
	assert_eq(fest.save_state(), saved, "17:20 round trip")

	# 18:00 the evaluation.
	var rel := tree.get_first_node_in_group(&"relationships") as Relationships
	var vals := {}
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		vals[npc] = rel.value(npc)
	TimeManager.advance(18 * 60 - TimeManager.minute_of_day)
	assert_eq(fest.lights_result(), &"all")
	assert_true(GameState.flag_on(&"lights_all"))
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		var gain := 5 if npc == &"priest" else 2
		assert_eq(rel.value(npc), mini(100, int(vals[npc]) + gain), "%s +%d" % [npc, gain])
	TimeManager.advance(30)
	assert_eq(fest.state(&"fest_lights"), &"ended", "18:30 the procession goes down")
	assert_true(GameState.flag_on(&"lights_held"))
	TimeManager.advance(60)
	assert_eq(fest.lights_result(), &"all", "evaluated once")
