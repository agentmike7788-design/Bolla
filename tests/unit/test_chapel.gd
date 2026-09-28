extends TestCase
## P4 (docs/PHASE6_DESIGN.md §2.4, §3.4, §10): ChapelRules (service: time window, dress, freshness,
## candle, once per corpse; fee / reputation / mourners by level; devotion: bonus by level, cap 8 for
## robbed souls, the contract's numbers), ChapelRites (hold_service with fee, reputation, piety only
## unharvested, mark_service, stats, funeral_held; hold_devotion per level – again after an upgrade,
## the higher value counts, piety once; eligible_devotions; services_buried; save / load), the
## entities Catafalque, ChapelAltar and MournerSet.
## Other modules: Buildings through Phase6Fixtures.buildings_at (W0 load_state), CorpseManager as a
## double (records, put_down / pick_up / mark_service recorded – P2 owns the real ones).

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const CANDLE := &"altar_candle"
const MARKED := GraveRecord.State.MARKED


## CorpseManager double: records by id; put_down / pick_up / mark_service recorded (mark_service sets
## the record fields like P2's implementation).
class CorpsesDouble extends CorpseManager:
	var recs: Dictionary = {}
	var calls: Array = []

	func _ready() -> void:
		pass

	func records() -> Array[CorpseRecord]:
		var out: Array[CorpseRecord] = []
		for r: CorpseRecord in recs.values():
			out.append(r)
		return out

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord

	func refresh_decay(_id: String) -> void:
		pass

	func mark_service(id: String, day: int) -> void:
		calls.append(["mark_service", id, day])
		var r := get_record(id)
		if r != null:
			r.service_held = true
			r.service_day = day

	func put_down(id: String, location: StringName, xform: Transform3D, parent: Node3D = null, room: StringName = &"",
			slot_id: String = "") -> bool:
		calls.append(["put_down", id, location, parent, room, slot_id, xform.origin])
		var r := get_record(id)
		if r != null:
			r.location = location
			r.room = room
		return true

	func pick_up(id: String, _player: Player) -> bool:
		calls.append(["pick_up", id])
		var r := get_record(id)
		if r != null:
			r.location = CorpseRecord.LOCATION_CARRIED
		return true


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


var cfg: ChapelConfig
var world: Node3D
var corpses: CorpsesDouble
var graveyard: Graveyard
var buildings: Buildings
var rites: ChapelRites
var rep: Reputation
var piety: Piety
var inv: Inventory
var funerals: Array = []
var devotions_signalled: Array = []
var payments: Array = []
var notes: Array = []
var panels: Array = []


func before_each() -> void:
	cfg = Phase6Fixtures.chapel_config()
	GameState.reset()
	GameState.stats[&"reputation"] = 50
	TimeManager.load_state({"day": 31, "minute_of_day": 600})
	funerals.clear()
	devotions_signalled.clear()
	payments.clear()
	notes.clear()
	panels.clear()
	EventBus.funeral_held.connect(_on_funeral)
	EventBus.devotion_held.connect(_on_devotion)
	EventBus.payment_received.connect(_on_payment)
	EventBus.notification_requested.connect(_on_note)
	EventBus.ui_panel_requested.connect(_on_panel)
	inv = Phase6Fixtures.inv_with({CANDLE: 3})


func after_each() -> void:
	EventBus.funeral_held.disconnect(_on_funeral)
	EventBus.devotion_held.disconnect(_on_devotion)
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.ui_panel_requested.disconnect(_on_panel)
	if is_instance_valid(world):
		world.free()
	if inv != null:
		inv.free()
		inv = null
	GameState.reset()


# --- ChapelRules: service -------------------------------------------------------------------

func test_service_block_reasons_in_order() -> void:
	var r := Phase6Fixtures.service_corpse()
	assert_eq(ChapelRules.service_block_reason(r, inv, 600, 1, cfg), "")
	assert_eq(ChapelRules.service_block_reason(r, inv, 600, 0, cfg), ChapelRules.TEXT_NO_CHAPEL, "no roof yet")
	assert_eq(ChapelRules.service_block_reason(null, inv, 600, 1, cfg), ChapelRules.TEXT_NO_CORPSE)
	var on_table := Phase6Fixtures.service_corpse()
	on_table.location = CorpseRecord.LOCATION_TABLE
	assert_eq(ChapelRules.service_block_reason(on_table, inv, 600, 1, cfg), ChapelRules.TEXT_NO_CORPSE, "only on the catafalque")
	var held := Phase6Fixtures.service_corpse()
	held.service_held = true
	assert_eq(ChapelRules.service_block_reason(held, inv, 600, 1, cfg), ChapelRules.TEXT_HELD, "once per corpse")
	var bare := Phase6Fixtures.service_corpse(1.0, CorpseRecord.DRESS_NONE)
	assert_eq(ChapelRules.service_block_reason(bare, inv, 600, 1, cfg), ChapelRules.TEXT_DRESS)
	assert_eq(ChapelRules.service_block_reason(Phase6Fixtures.service_corpse(1.0, CorpseRecord.DRESS_SHROUD), inv, 600, 1, cfg), "",
			"a shroud is enough")
	assert_eq(ChapelRules.service_block_reason(Phase6Fixtures.service_corpse(0.29), inv, 600, 1, cfg), ChapelRules.TEXT_LATE)
	assert_eq(ChapelRules.service_block_reason(Phase6Fixtures.service_corpse(0.3), inv, 600, 1, cfg), "", "0.3 still allowed")
	var empty := FakeInventory.new()
	assert_eq(ChapelRules.service_block_reason(r, empty, 600, 1, cfg), ChapelRules.TEXT_NO_CANDLE)
	assert_eq(ChapelRules.service_block_reason(r, null, 600, 1, cfg), ChapelRules.TEXT_NO_CANDLE)
	empty.free()
	assert_eq(ChapelRules.TEXT_DAYTIME, "Die Trauergäste kommen nur bei Tag.")
	assert_eq(ChapelRules.TEXT_NO_CANDLE, "Keine Altarkerze – Osric hat welche.")


func test_service_time_window_08_to_17() -> void:
	var r := Phase6Fixtures.service_corpse()
	var cases := {0: false, 479: false, 480: true, 720: true, 1020: true, 1021: false, 1380: false}
	for minute: int in cases:
		var reason := ChapelRules.service_block_reason(r, inv, minute, 2, cfg)
		assert_eq(reason == "", cases[minute], "minute %d: %s" % [minute, reason])
	assert_eq(ChapelRules.service_block_reason(r, inv, 1300, 2, cfg), ChapelRules.TEXT_DAYTIME)
	assert_eq(ChapelRules.service_block_reason(r, inv, ChapelRules.ANY_MINUTE, 2, cfg), "", "end of a service: no window")


func test_fee_reputation_mourners_by_level() -> void:
	var got := []
	for level: int in 4:
		got.append([ChapelRules.fee(level, cfg), ChapelRules.reputation(level, cfg), ChapelRules.mourners(level, cfg)])
	assert_eq(got, [[0, 0, 0], [3, 1, 0], [5, 2, 2], [7, 3, 4]], "§2.4 table")
	assert_eq([ChapelRules.fee(9, cfg), ChapelRules.fee(-1, cfg)], [0, 0], "outside the table")


# --- ChapelRules: devotion ------------------------------------------------------------------

func test_devotion_bonus_by_level_and_robbed_cap() -> void:
	for level: int in 4:
		assert_eq(ChapelRules.devotion_bonus(level, 0, 5, cfg), [0, 1, 2, 3][level], "level %d" % level)
	assert_eq(ChapelRules.devotion_bonus(3, 2, 2, cfg), 3, "robbed 2 → 5: room below the cap")
	assert_eq(ChapelRules.devotion_bonus(3, 1, 7, cfg), 1, "robbed 7 → at most 8")
	assert_eq(ChapelRules.devotion_bonus(1, 1, 8, cfg), 0, "robbed 8 stays 8")
	assert_eq(ChapelRules.devotion_bonus(3, 1, 12, cfg), 0, "never negative")
	assert_eq(ChapelRules.devotion_bonus(1, 0, 8, cfg), 1, "an unrobbed soul is not capped")
	for base: int in range(-10, 9):
		for level: int in range(1, 4):
			var score := base + ChapelRules.devotion_bonus(level, 1, base, cfg)
			assert_true(score <= cfg.devotion_robbed_cap, "robbed %d + L%d = %d ≤ 8" % [base, level, score])


func test_devotion_contract_numbers() -> void:
	# §2.4: fully robbed with a master stone 2 (restless) → devotion 3: 5 calm · mixed grave 4 → devotion 2:
	# 6 calm · calm wooden-cross grave 8 → devotion 1: 9 content.
	var ghost := Phase6Fixtures.ghost_config()
	var clean := Phase3Fixtures.cleanliness_config()
	var robbed_base := GhostMood.score(11, 0, 0, clean, ghost, 2)
	assert_eq([robbed_base, GhostMood.mood(robbed_base, ghost)], [2, &"restless"])
	var robbed := GhostMood.score(11, 0, 0, clean, ghost, 2, ChapelRules.devotion_bonus(3, 2, robbed_base, cfg))
	assert_eq([robbed, GhostMood.mood(robbed, ghost)], [5, &"calm"])
	var mixed_base := GhostMood.score(8, 0, 0, clean, ghost, 1)
	assert_eq(mixed_base, 4)
	var mixed := GhostMood.score(8, 0, 0, clean, ghost, 1, ChapelRules.devotion_bonus(2, 1, mixed_base, cfg))
	assert_eq([mixed, GhostMood.mood(mixed, ghost)], [6, &"calm"])
	var cross_base := GhostMood.score(7, 0, 0, clean, ghost)
	assert_eq([cross_base, GhostMood.mood(cross_base, ghost)], [8, &"calm"])
	var cross := GhostMood.score(7, 0, 0, clean, ghost, 0, ChapelRules.devotion_bonus(1, 0, cross_base, cfg))
	assert_eq([cross, GhostMood.mood(cross, ghost)], [9, &"content"])
	# A robbed soul never becomes content through candles.
	for q: int in range(0, 21):
		var base := GhostMood.score(q, 0, 2, clean, ghost, 1)
		if base < 9:
			var s := GhostMood.score(q, 0, 2, clean, ghost, 1, ChapelRules.devotion_bonus(3, 1, base, cfg))
			assert_true(GhostMood.mood(s, ghost) != &"content", "quality %d" % q)


func test_devotion_block_reasons() -> void:
	var grave := Phase6Fixtures.serviced_grave()
	assert_eq(ChapelRules.devotion_block_reason(grave, 0, inv, 1, cfg), "")
	assert_eq(ChapelRules.devotion_block_reason(grave, 0, inv, 0, cfg), ChapelRules.TEXT_NO_CHAPEL)
	assert_eq(ChapelRules.devotion_block_reason(null, 0, inv, 1, cfg), ChapelRules.TEXT_NO_GHOST)
	var filled := GraveRecord.new()
	filled.state = GraveRecord.State.FILLED
	assert_eq(ChapelRules.devotion_block_reason(filled, 0, inv, 1, cfg), ChapelRules.TEXT_NO_GHOST, "only graves with a ghost")
	assert_eq(ChapelRules.devotion_block_reason(grave, 1, inv, 1, cfg), "Für dieses Grab brennt schon ein Licht.")
	assert_eq(ChapelRules.devotion_block_reason(grave, 1, inv, 2, cfg), "", "again after the upgrade")
	assert_eq(ChapelRules.devotion_block_reason(grave, 2, inv, 2, cfg), ChapelRules.TEXT_LIT)
	var empty := FakeInventory.new()
	assert_eq(ChapelRules.devotion_block_reason(grave, 0, empty, 3, cfg), ChapelRules.TEXT_NO_CANDLE)
	empty.free()


# --- ChapelRites: service -------------------------------------------------------------------

func test_level_follows_buildings() -> void:
	await _make_world(0)
	assert_eq(rites.level(), 0)
	_set_chapel(2)
	assert_eq(rites.level(), 2)
	assert_eq(rites.service_block_reason("nobody", inv), ChapelRules.TEXT_NO_CORPSE)


func test_hold_service_by_level() -> void:
	var expected := {1: [3, 1, 0], 2: [5, 2, 2], 3: [7, 3, 4]}
	for level: int in expected:
		await _make_world(level)
		var r := _catafalque_corpse("c_%d" % level)
		GameState.stats[&"reputation"] = 50
		var rep_before := rep.value()
		var piety_before := piety.value()
		var coins := inv.count(&"coin")
		var candles := inv.count(CANDLE)
		assert_eq(rites.service_block_reason(r.id, inv), "", "L%d" % level)
		var fee := rites.hold_service(r.id, inv)
		assert_eq(fee, expected[level][0], "fee L%d" % level)
		assert_eq(inv.count(&"coin") - coins, fee, "coins L%d" % level)
		assert_eq(candles - inv.count(CANDLE), 1, "one candle")
		assert_eq(rep.value() - rep_before, expected[level][1], "reputation L%d" % level)
		assert_eq(piety.value() - piety_before, 1, "piety service +1")
		assert_true(r.service_held, "mark_service")
		assert_eq(r.service_day, 31)
		assert_eq(corpses.calls, [["mark_service", r.id, 31]])
		assert_eq(funerals.back(), [r.id, level, fee])
		assert_eq(payments.back(), [fee, "Die Familie legt %d Münzen auf den Altar." % fee])
		assert_has(notes, "Die Familie legt %d Münzen auf den Altar." % fee)
		assert_eq(GameState.get_stat(&"services_held"), 1)
		assert_eq(rites.services_held(), 1)
		# Once per corpse.
		assert_eq(rites.service_block_reason(r.id, inv), ChapelRules.TEXT_HELD)
		assert_eq(rites.hold_service(r.id, inv), -1)
		assert_eq(inv.count(CANDLE), candles - 1, "nothing taken the second time")
		world.free()
		inv.free()
		inv = Phase6Fixtures.inv_with({CANDLE: 3})
		GameState.reset()
	assert_eq(ChapelRules.mourners(2, cfg), 2)


func test_harvested_corpse_gets_no_piety_but_fee_and_reputation() -> void:
	await _make_world(1)
	var r := _catafalque_corpse("c_h")
	r.harvested = [CorpseRecord.HARVEST_HAIR]
	var piety_before := piety.value()
	var rep_before := rep.value()
	assert_eq(rites.hold_service(r.id, inv), 3)
	assert_eq(piety.value(), piety_before, "§2.4: only unharvested")
	assert_eq(rep.value() - rep_before, 1, "the family knows nothing")
	assert_true(r.service_held)


func test_hold_service_after_17_when_begun_in_time() -> void:
	await _make_world(1)
	var r := _catafalque_corpse("c_late")
	TimeManager.load_state({"day": 31, "minute_of_day": 1050})
	assert_eq(rites.service_block_reason(r.id, inv), ChapelRules.TEXT_DAYTIME, "cannot begin at 17:30")
	assert_eq(rites.hold_service(r.id, inv), 3, "the end of a service begun at 17:00 counts")


func test_hold_service_refuses_without_candle_or_corpse() -> void:
	await _make_world(1)
	var r := _catafalque_corpse("c_x")
	var empty := FakeInventory.new()
	assert_eq(rites.hold_service(r.id, empty), -1)
	assert_false(r.service_held)
	assert_eq(rites.hold_service("missing", inv), -1)
	assert_eq([funerals.size(), GameState.get_stat(&"services_held")], [0, 0])
	empty.free()


func test_service_quality_line_at_the_marker() -> void:
	var eco := Phase6Fixtures.economy_config()
	var r := Phase6Fixtures.service_corpse()
	var without := GraveQuality.compute(r, &"wooden_cross", eco)
	r.service_held = true
	var lines := GraveQuality.breakdown(r, &"wooden_cross", eco)
	assert_eq(lines.back(), {"label": "Ausgesegnet", "points": 1})
	assert_eq(GraveQuality.compute(r, &"wooden_cross", eco), without + 1)
	var grave := Phase6Fixtures.serviced_grave()
	assert_eq(grave.breakdown.back().label, "Ausgesegnet", "serviced_grave fixture")


func test_services_buried_counts_marked_graves() -> void:
	await _make_world(1, 3)
	var a := _catafalque_corpse("c_a")
	var b := _catafalque_corpse("c_b")
	var c := _catafalque_corpse("c_c")
	a.service_held = true
	b.service_held = true
	for pair: Array in [[a, "plot_01", MARKED], [b, "plot_02", GraveRecord.State.FILLED], [c, "plot_03", MARKED]]:
		var rec: CorpseRecord = pair[0]
		rec.location = CorpseRecord.LOCATION_BURIED
		rec.grave_id = pair[1]
		var g := graveyard.get_grave(pair[1])
		g.state = pair[2]
		g.corpse_id = rec.id
	assert_eq(rites.services_buried(), 1, "service_held ∧ MARKED")
	graveyard.get_grave("plot_02").state = MARKED
	assert_eq(rites.services_buried(), 2)


# --- ChapelRites: devotion ------------------------------------------------------------------

func test_devotion_per_level_higher_value_counts_piety_once() -> void:
	await _make_world(1, 2)
	_mark("plot_01", "Agnes")
	var piety_before := piety.value()
	assert_eq(rites.devotion_level("plot_01"), 0)
	assert_true(rites.hold_devotion("plot_01", inv))
	assert_eq([rites.devotion_level("plot_01"), inv.count(CANDLE)], [1, 2])
	assert_eq(piety.value() - piety_before, 1, "piety devotion +1")
	assert_eq(devotions_signalled, [["plot_01", 1]])
	assert_eq(rites.devotion_block_reason("plot_01", inv), ChapelRules.TEXT_LIT)
	assert_false(rites.hold_devotion("plot_01", inv), "once per level")
	assert_eq(inv.count(CANDLE), 2, "no candle burnt")
	_set_chapel(3)
	assert_eq(rites.devotion_block_reason("plot_01", inv), "", "after the upgrade again")
	assert_true(rites.hold_devotion("plot_01", inv))
	assert_eq(rites.devotion_level("plot_01"), 3, "the higher value, not summed")
	assert_eq(devotions_signalled.back(), ["plot_01", 3])
	assert_eq(piety.value() - piety_before, 1, "piety once per grave")
	assert_eq(GameState.get_stat(&"devotions_held"), 2)
	assert_eq(rep.value(), 50, "no reputation – the devotion is private")
	assert_eq(rites.devotion_block_reason("plot_02", inv), ChapelRules.TEXT_NO_GHOST, "empty plot")


func test_devotion_any_time_of_day() -> void:
	await _make_world(1, 1)
	_mark("plot_01", "Agnes")
	TimeManager.load_state({"day": 31, "minute_of_day": 1400})
	assert_eq(rites.devotion_block_reason("plot_01", inv), "", "also at night")


func test_eligible_devotions() -> void:
	await _make_world(2, 3)
	_mark("plot_01", "Agnes Hollweg")
	_mark("plot_03", "Hanne Sörgel")
	rites.load_state({"devotions": {"plot_03": 2}})
	assert_eq(rites.eligible_devotions()[0].block_reason, ChapelRules.TEXT_NO_CANDLE, "no player: no candle")
	var player := await _player()
	player.inventory.add_item(CANDLE, 1)
	var list := rites.eligible_devotions()
	assert_eq(list.size(), 2, "only MARKED graves")
	assert_eq([list[0].grave_id, list[0].name, list[0].held_level, list[0].block_reason], ["plot_01", "Agnes Hollweg", 0, ""])
	assert_eq([list[1].grave_id, list[1].held_level, list[1].block_reason], ["plot_03", 2, ChapelRules.TEXT_LIT])
	for key: String in ["grave_id", "name", "section", "mood", "held_level", "block_reason"]:
		assert_true(list[0].has(key), key)


func test_save_load_roundtrip_and_tolerance() -> void:
	await _make_world(2, 2)
	_mark("plot_01", "Agnes")
	var r := _catafalque_corpse("c_s")
	rites.hold_devotion("plot_01", inv)
	rites.hold_service(r.id, inv)
	var saved := rites.save_state()
	assert_eq(saved, {"devotions": {"plot_01": 2}, "services": 1}, "§5.1 format")
	var copy := ChapelRites.new()
	copy.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(copy.save_state(), saved, "roundtrip through JSON")
	assert_eq(copy.devotion_level("plot_01"), 2)
	copy.load_state({})
	assert_eq(copy.save_state(), {"devotions": {}, "services": 0}, "missing keys = nothing held")
	expect_errors(0)
	copy.load_state({"devotions": {"a": 9, "b": "x", "c": 0}, "services": "many"})
	assert_eq(copy.devotion_level("a"), 3, "clamped")
	assert_eq([copy.devotion_level("b"), copy.devotion_level("c"), copy.services_held()], [0, 0, 0])
	copy.free()


# --- entities -------------------------------------------------------------------------------

func test_catafalque_prompts_and_occupant() -> void:
	await _make_world(1)
	var cat := (load("res://src/entities/catafalque/catafalque.tscn") as PackedScene).instantiate() as Catafalque
	var slot := Node3D.new()
	slot.name = "slot_corpse"
	slot.position = Vector3(0, 0.8, 0)
	cat.add_child(slot)
	world.add_child(cat)
	var player := await _player()
	assert_eq(cat.occupant(), "")
	assert_false(cat.can_interact(player), "nothing to take")
	assert_eq(cat.get_interaction_prompt(player), "")
	var carried := _carried_corpse("c_carry")
	_carry(player, carried)
	assert_true(cat.can_interact(player))
	assert_eq(cat.get_interaction_prompt(player), "[E] Auf den Katafalk legen")
	cat.interact(player)
	assert_eq(corpses.calls.back(), ["put_down", "c_carry", CorpseRecord.LOCATION_CATAFALQUE, null, &"chapel", "", Vector3(0, 0.8, 0)],
			"put_down at the slot, room chapel, under the Corpses container")
	assert_eq(cat.occupant(), "c_carry")
	assert_eq(cat.get_interaction_prompt(player), "Der Katafalk ist belegt", "still carrying")
	assert_false(cat.can_interact(player))
	_uncarry(player)
	assert_eq(cat.get_interaction_prompt(player), "[E] Leiche aufnehmen")
	cat.interact(player)
	assert_eq(corpses.calls.back(), ["pick_up", "c_carry"])
	assert_eq(cat.occupant(), "")


func test_altar_prompts_and_panels() -> void:
	await _make_world(0)
	var parts := _chapel_room()
	var altar: ChapelAltar = parts[0]
	var player := await _player()
	assert_false(altar.can_interact(player), "no chapel yet")
	assert_eq(altar.get_interaction_prompt(player), "")
	_set_chapel(1)
	assert_true(altar.can_interact(player))
	assert_eq(altar.get_interaction_prompt(player), "[E] Andacht halten", "catafalque empty")
	altar.interact(player)
	assert_eq(panels.back()[0], &"devotion")
	assert_true(panels.back()[1].altar == altar and panels.back()[1].player == player)
	var r := _catafalque_corpse("c_alt")
	assert_eq(altar.get_interaction_prompt(player), "[E] Aussegnung halten (45 Min)")
	altar.interact(player)
	assert_eq(panels.back()[0], &"chapel")
	assert_eq(panels.back()[1].corpse_id, r.id)
	assert_true(panels.back()[1].inventory == player.inventory)
	_carry(player, _carried_corpse("c_other"))
	assert_false(altar.can_interact(player), "hands must be free")


func test_altar_service_timed_action_with_mourners() -> void:
	await _make_world(2)
	var parts := _chapel_room()
	var altar: ChapelAltar = parts[0]
	var mourners: MournerSet = parts[1]
	var player := await _player()
	player.inventory.add_item(CANDLE, 1)
	var r := _catafalque_corpse("c_srv")
	altar.interact(player)
	var shown_during := []
	var probe := func(_id: String, _lvl: int, _fee: int) -> void: shown_during.append(mourners.shown_count())
	EventBus.funeral_held.connect(probe)
	var start := TimeManager.total_minutes()
	altar.request_service()
	EventBus.funeral_held.disconnect(probe)
	assert_eq(shown_during, [2], "2 mourners during the service at level 2")
	assert_eq(mourners.shown_count(), 0, "gone at the end")
	assert_false(altar.rite_active)
	assert_true(r.service_held)
	assert_eq(TimeManager.total_minutes() - start, 45, "45 minutes")
	assert_eq(player.inventory.count(&"coin"), 5)
	# Blocked: a warning, no action.
	var r2 := r
	r2.service_held = false
	r2.dress = CorpseRecord.DRESS_NONE
	r2.shrouded = false
	altar.request_service()
	assert_has(notes, ChapelRules.TEXT_DRESS)


func test_altar_devotion_timed_action() -> void:
	await _make_world(1, 1)
	_mark("plot_01", "Agnes")
	var parts := _chapel_room()
	var altar: ChapelAltar = parts[0]
	var player := await _player()
	player.inventory.add_item(CANDLE, 1)
	altar.interact(player)
	var start := TimeManager.total_minutes()
	altar.request_devotion("plot_01")
	assert_eq(TimeManager.total_minutes() - start, 30)
	assert_eq(rites.devotion_level("plot_01"), 1)
	assert_eq(player.inventory.count(CANDLE), 0)
	altar.request_devotion("plot_01")
	assert_has(notes, ChapelRules.TEXT_LIT)


func test_mourner_set_shows_and_hides() -> void:
	var set := MournerSet.new()
	for i: int in 4:
		var fig := MeshInstance3D.new()
		fig.name = "Figure%d" % i
		set.add_child(fig)
	assert_eq(set.figures().size(), 4)
	assert_eq(_visible(set), 0, "hidden at the start")
	set.show_mourners(2)
	assert_eq([set.shown_count(), _visible(set)], [2, 2])
	set.show_mourners(9)
	assert_eq([set.shown_count(), _visible(set)], [4, 4], "at most 4")
	set.hide_mourners()
	assert_eq([set.shown_count(), _visible(set)], [0, 0])
	set.show_mourners(0)
	assert_eq(_visible(set), 0)
	set.free()


func test_mourner_set_places_figures_on_the_seats() -> void:
	var room := Node3D.new()
	for i: int in 4:
		var seat := Marker3D.new()
		seat.name = "pew_seat_%d" % (i + 1)
		seat.position = Vector3(i, 0.5, 2)
		room.add_child(seat)
	var set := MournerSet.new()
	var packed := PackedScene.new()
	var proto := MeshInstance3D.new()
	packed.pack(proto)
	proto.free()
	set.figure_scenes = [packed]
	room.add_child(set)
	tree.root.add_child(room)
	await wait_frames(1)
	var figs := set.figures()
	assert_eq(figs.size(), 4)
	assert_eq(figs[2].global_position, Vector3(2, 0.5, 2), "on pew_seat_3")
	assert_eq(_visible(set), 0)
	set.show_mourners(4)
	assert_eq(_visible(set), 4)
	assert_almost((figs[0] as MeshInstance3D).transparency, 1.0, 0.01, "fades in from transparent")
	room.free()


# --- helpers -------------------------------------------------------------------------------

func _make_world(chapel_level: int, plots: int = 0) -> void:
	world = Node3D.new()
	world.name = "ChapelWorld"
	corpses = CorpsesDouble.new()
	world.add_child(corpses)
	for i: int in plots:
		var plot := PlotDouble.new()
		plot.grave_id = "plot_%02d" % (i + 1)
		plot.name = plot.grave_id
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	graveyard = Graveyard.new()
	graveyard.economy = Phase6Fixtures.economy_config()
	world.add_child(graveyard)
	buildings = Phase6Fixtures.buildings_at({&"chapel": chapel_level})
	world.add_child(buildings)
	rep = Reputation.new()
	rep.config = Phase6Fixtures.reputation_config()
	world.add_child(rep)
	piety = Piety.new()
	piety.config = Phase6Fixtures.piety_config()
	world.add_child(piety)
	rites = ChapelRites.new()
	rites.config = cfg
	world.add_child(rites)
	tree.root.add_child(world)
	await wait_frames(1)


func _set_chapel(level: int) -> void:
	buildings.load_state({"levels": {"chapel": level}})


## [ChapelAltar, MournerSet, Catafalque] of a small chapel room in the world.
func _chapel_room() -> Array:
	var altar := (load("res://src/entities/chapel_altar/chapel_altar.tscn") as PackedScene).instantiate() as ChapelAltar
	world.add_child(altar)
	var set := MournerSet.new()
	for i: int in 4:
		set.add_child(MeshInstance3D.new())
	world.add_child(set)
	var cat := (load("res://src/entities/catafalque/catafalque.tscn") as PackedScene).instantiate() as Catafalque
	world.add_child(cat)
	return [altar, set, cat]


func _catafalque_corpse(id: String) -> CorpseRecord:
	var r := Phase6Fixtures.service_corpse()
	r.id = id
	r.display_name = "Tote " + id
	corpses.recs[id] = r
	return r


func _carried_corpse(id: String) -> CorpseRecord:
	var r := _catafalque_corpse(id)
	r.location = CorpseRecord.LOCATION_CARRIED
	r.room = &""
	return r


func _carry(player: Player, record: CorpseRecord) -> void:
	var node := Node3D.new()
	world.add_child(node)
	player.carried = node
	player.carried_id = record.id


func _uncarry(player: Player) -> void:
	if is_instance_valid(player.carried):
		player.carried.free()
	player.carried = null
	player.carried_id = ""


func _mark(grave_id: String, name: String) -> void:
	var g := graveyard.get_grave(grave_id)
	var r := Phase5Fixtures.corpse()
	r.id = "c_" + grave_id
	r.display_name = name
	r.location = CorpseRecord.LOCATION_BURIED
	r.grave_id = grave_id
	corpses.recs[r.id] = r
	g.state = MARKED
	g.corpse_id = r.id
	g.quality = 8
	g.completed_day = 20


func _player() -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	world.add_child(player)
	await wait_frames(1)
	player.instant_actions = true
	return player


static func _visible(set: MournerSet) -> int:
	var n := 0
	for fig: Node3D in set.figures():
		if fig.visible:
			n += 1
	return n


func _on_funeral(corpse_id: String, level: int, fee: int) -> void:
	funerals.append([corpse_id, level, fee])


func _on_devotion(grave_id: String, bonus: int) -> void:
	devotions_signalled.append([grave_id, bonus])


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _on_panel(panel: StringName, context: Dictionary) -> void:
	panels.append([panel, context])
