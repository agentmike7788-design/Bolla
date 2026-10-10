extends TestCase
## W2: ObjectiveResolver.current() – every branch of the objective chain (docs §1, §7),
## priorities between several corpses / graves, clock-based idle lines and purity.
## Phase 8 (docs/PHASE8_DESIGN.md §7.5, W-UI): the chain after the village chapter (world.p8).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const WAIT := "Der Leichenkutscher kommt gegen 07:40"
const TO_TABLE := "Leiche zum Leichentisch bringen"
const EXAMINE := "Leiche untersuchen"
const DECIDE := "Über die Wertsachen entscheiden"
const SHROUD := "Leichentuch anlegen (+2 Qualität)"
const DIG := "Grab ausheben"
const BURY := "Leiche bestatten"
const NO_PLOT := "Keine freie Grabstelle mehr"
const MARKER := "Grabzeichen setzen"
const MARKER_CRAFT := "Grabzeichen setzen (Werkbank: Holzkreuz = 3 Holz)"
const REST := "Feierabend – Ausruhen an der Hüttentür"
const SLEEP := "Feierabend – Schlafen an der Hüttentür"
const TABLE_BUSY := "Tisch belegt – Leiche mit [Q] ablegen"
## Daytime minute (12:00) where the idle line would be REST.
const NOON := 720

var _inv: Inventory


func before_each() -> void:
	_inv = FakeInventory.new()


func after_each() -> void:
	_inv.free()


func test_data_behind_the_texts() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	var time_cfg := Database.config(&"time_config") as TimeConfig
	assert_eq(tables.delivery_minute, 460, "07:40")
	assert_eq(time_cfg.wake_minute, 360)
	assert_eq(time_cfg.sleep_from_minute, 1080)
	assert_eq((Database.recipe(&"wooden_cross") as RecipeData).inputs, {&"wood": 3})
	assert_eq((Database.config(&"economy_config") as EconomyConfig).quality_shroud, 2)


func test_idle_lines_follow_the_clock() -> void:
	var cases := {0: SLEEP, 200: SLEEP, 359: SLEEP, 360: WAIT, 390: WAIT, 459: WAIT, 460: REST,
			NOON: REST, 1079: REST, 1080: SLEEP, 1320: SLEEP, 1439: SLEEP}
	for minute: int in cases:
		assert_eq(_objective([], [], minute), cases[minute], "minute %d" % minute)


func test_idle_minute_wraps() -> void:
	assert_eq(_objective([], [], 1440 + 390), WAIT)
	assert_eq(_objective([], [], -60), SLEEP, "23:00")


func test_unexamined_corpse_goes_to_the_table() -> void:
	for location: StringName in [&"dropoff", &"ground", &"carried"]:
		assert_eq(_objective([_corpse(location)], [_grave(GraveRecord.State.EMPTY)]), TO_TABLE, String(location))


func test_unexamined_corpse_on_table_is_examined() -> void:
	assert_eq(_objective([_corpse(&"table")], [_grave(GraveRecord.State.EMPTY)]), EXAMINE)
	assert_eq(_objective([_corpse(&"table")], [_grave(GraveRecord.State.DUG)]), EXAMINE, "examining comes before burying")


func test_open_valuables_decision() -> void:
	var c := _corpse(&"table", true)
	c.traits = [&"valuables"]
	assert_eq(_objective([c], [_grave(GraveRecord.State.EMPTY)]), DECIDE)
	c.location = &"carried"
	assert_eq(_objective([c], [_grave(GraveRecord.State.DUG)]), BURY, "away from the table: bury (valuables stay)")
	c.location = &"table"
	c.valuables_decision = &"left"
	assert_eq(_objective([c], [_grave(GraveRecord.State.EMPTY)]), DIG)
	c.valuables_decision = &"taken"
	assert_eq(_objective([c], [_grave(GraveRecord.State.EMPTY)]), DIG)


func test_shroud_hint_only_on_table_with_a_shroud() -> void:
	var c := _corpse(&"table", true)
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.EMPTY)]
	assert_eq(_objective([c], graves), DIG, "no shroud in the inventory")
	_inv.add_item(&"shroud", 1)
	assert_eq(_objective([c], graves), SHROUD)
	c.shrouded = true
	assert_eq(_objective([c], graves), DIG, "already shrouded")
	c.shrouded = false
	c.location = &"carried"
	assert_eq(_objective([c], graves), DIG, "carried: no shroud hint")


func test_dig_then_bury() -> void:
	for location: StringName in [&"table", &"carried", &"ground", &"dropoff"]:
		var c := _corpse(location, true)
		assert_eq(_objective([c], [_grave(GraveRecord.State.EMPTY)]), DIG, String(location))
		assert_eq(_objective([c], [_grave(GraveRecord.State.EMPTY), _grave(GraveRecord.State.DUG)]), BURY, String(location))


func test_no_free_plot() -> void:
	var c := _corpse(&"carried", true)
	assert_eq(_objective([c], [_grave(GraveRecord.State.MARKED), _grave(GraveRecord.State.OLD)]), NO_PLOT)
	assert_eq(_objective([c], []), NO_PLOT)


func test_marker_line_with_and_without_marker_item() -> void:
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.FILLED), _grave(GraveRecord.State.EMPTY)]
	assert_eq(_objective([], graves), MARKER_CRAFT, "no marker: workbench hint from the recipe")
	_inv.add_item(&"wooden_cross", 1)
	assert_eq(_objective([], graves), MARKER)
	_inv.remove_item(&"wooden_cross", 1)
	_inv.add_item(&"gravestone_simple", 1)
	assert_eq(_objective([], graves), MARKER)


func test_marker_line_without_inventory() -> void:
	assert_eq(ObjectiveResolver.current([], [_grave(GraveRecord.State.FILLED)], null, NOON, {}), MARKER_CRAFT)


func test_carried_corpse_beats_open_marker() -> void:
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.FILLED), _grave(GraveRecord.State.DUG)]
	assert_eq(_objective([_corpse(&"carried", true)], graves), BURY)
	assert_eq(_objective([_corpse(&"carried")], graves), TO_TABLE)


func test_open_marker_beats_other_corpses() -> void:
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.FILLED), _grave(GraveRecord.State.EMPTY)]
	for location: StringName in [&"table", &"ground", &"dropoff"]:
		assert_eq(_objective([_corpse(location)], graves), MARKER_CRAFT, String(location))


func test_most_urgent_corpse_wins() -> void:
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.EMPTY)]
	var at_dropoff := _corpse(&"dropoff")
	var on_table := _corpse(&"table", true)
	assert_eq(_objective([at_dropoff, on_table], graves), DIG, "table before dropoff, list order irrelevant")
	assert_eq(_objective([on_table, at_dropoff], graves), DIG)
	var on_ground := _corpse(&"ground")
	var unexamined_table := _corpse(&"table")
	assert_eq(_objective([on_ground, unexamined_table], graves), EXAMINE, "table before ground")
	var carried := _corpse(&"carried", true)
	assert_eq(_objective([unexamined_table, carried], graves), DIG, "carried before table")


func test_buried_corpses_are_ignored() -> void:
	var buried := _corpse(&"buried", true)
	assert_eq(_objective([buried], [_grave(GraveRecord.State.MARKED)], 390), WAIT)
	assert_eq(_objective([buried], [_grave(GraveRecord.State.MARKED)], NOON), REST)


## Phase 3 (§2.7): slice_complete is no longer read – the corpse chain goes on.
func test_slice_complete_is_ignored() -> void:
	var marked := _grave(GraveRecord.State.MARKED)
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.FILLED), marked]
	var corpses: Array[CorpseRecord] = [_corpse(&"carried")]
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {&"slice_complete": true}), TO_TABLE)
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {"slice_complete": true}), TO_TABLE, "String key")
	assert_eq(ObjectiveResolver.current([], [marked], _inv, NOON, {&"slice_complete": true}), REST, "idle as before")


## C5: a carried, unexamined corpse is not sent to a table another corpse occupies.
func test_occupied_table_is_not_suggested() -> void:
	var on_table := _corpse(&"table", true)
	on_table.id = "corpse_0001"
	var carried := _corpse(&"carried")
	carried.id = "corpse_0002"
	assert_eq(_objective([on_table, carried], [_grave(GraveRecord.State.EMPTY)]), TABLE_BUSY, "hands must be free to dig")
	assert_eq(_objective([on_table, carried], [_grave(GraveRecord.State.DUG)]), BURY, "an open grave is usable")
	assert_eq(_objective([carried], [_grave(GraveRecord.State.EMPTY)]), TO_TABLE, "free table: to the table")
	var unexamined_on_table := _corpse(&"table")
	unexamined_on_table.id = "corpse_0003"
	assert_eq(_objective([carried, unexamined_on_table], [_grave(GraveRecord.State.EMPTY)]), TABLE_BUSY)
	var buried := _corpse(&"buried", true)
	assert_eq(_objective([buried, carried], [_grave(GraveRecord.State.EMPTY)]), TO_TABLE, "buried records do not block")


func test_null_entries_are_skipped() -> void:
	var corpses: Array[CorpseRecord] = [null, _corpse(&"table")]
	var graves: Array[GraveRecord] = [null, _grave(GraveRecord.State.EMPTY)]
	assert_eq(ObjectiveResolver.current(corpses, graves, null, NOON, {}), EXAMINE)


func test_is_pure() -> void:
	var c := _corpse(&"table", true)
	c.traits = [&"valuables"]
	var g := _grave(GraveRecord.State.DUG)
	_inv.add_item(&"shroud", 2)
	var before := [c.to_dict(), g.to_dict(), _inv.save_state(), GameState.save_state(), TimeManager.save_state()]
	var flags := {&"met_carter": true}
	for i: int in 3:
		assert_eq(ObjectiveResolver.current([c], [g], _inv, NOON, flags), DECIDE)
	assert_eq([c.to_dict(), g.to_dict(), _inv.save_state(), GameState.save_state(), TimeManager.save_state()], before)
	assert_eq(flags, {&"met_carter": true})


## Phase 7 (docs/PHASE7_DESIGN.md §7): the village line comes after the corpse chain and the Phase-6
## buildings goal; the Lindenacker is no Phase-3 section step.
func test_phase7_village_line_after_the_corpse_chain() -> void:
	var world := {"p7": true, "p7_intro": true, "visited": true, "linden_granted": true, "linden_done": 3, "linden_total": 10,
			"sections": [{"id": &"linden", "name": "Lindenacker", "unlocked": false, "done": 3, "total": 10, "block": "", "gate": true}]}
	assert_eq(_objective_world([], [], world), "Lindenacker: 3/10", "not „Lindenacker aufschließen“")
	var carried := _corpse(&"carried")
	assert_eq(_objective_world([carried], [_grave(GraveRecord.State.DUG)], world), TO_TABLE, "the corpse first")
	world["p6"] = true
	world["p6_intro"] = true
	world["levels"] = {&"crypt": 1, &"chapel": 0, &"shed": 0}
	world["goal_levels"] = {&"crypt": 2, &"chapel": 2, &"shed": 2}
	world["goal_done"] = false
	assert_eq(_objective_world([], [], world), "Kapelle 2 · Gruft 2 · Schuppen 2", "Phase 6 first while open")
	world["goal_done"] = true
	assert_eq(_objective_world([], [], world), "Lindenacker: 3/10")


## Phase 8 (docs/PHASE8_DESIGN.md §7.5): the chain after „Ein Name im Dorf" – each line in turn, the time-bound ones
## first; an urgent Phase-7 order still goes before the plain chapter count.
func test_phase8_chain_after_the_village_chapter() -> void:
	var p8 := {"intro": false, "minute": NOON}
	var world := {"p7": true, "p7_intro": true, "visited": true, "linden_granted": true, "linden_cleared": true, "consecrated": true,
			"goal_done": true, "goal_parts": 4, "goal_total": 4, "p8": p8}
	assert_eq(_objective_world([], [], world), "Sprich mit Osric")
	p8["intro"] = true
	p8["rosine_ready"] = true
	assert_eq(_objective_world([], [], world), "Rosine will dich sprechen")
	p8["hired"] = true
	p8["board_empty"] = true
	assert_eq(_objective_world([], [], world), "Kreidetafel: Arbeitsliste für Jakob")
	p8["board_empty"] = false
	p8["teach"] = &"rake"
	assert_eq(_objective_world([], [], world), "Zeig Jakob, wie man harkt")
	p8["waiting"] = "Martha Kehr"
	assert_eq(_objective_world([], [], world), "Martha Kehr wartet am Grab", "a waiting visitor first")
	p8.erase("waiting")
	p8.erase("teach")
	p8["wish"] = {"kind": &"flowers", "name": "Hedwig Lamprecht", "days": 2}
	assert_eq(_objective_world([], [], world), "Wunsch: Blumen für Hedwig Lamprecht (≈ 2 Tage)")
	p8["wish"] = {}
	p8["tin_empty"] = true
	assert_eq(_objective_world([], [], world), "Lohndose leer – Jakob arbeitet morgen umsonst")
	p8["tin_empty"] = false
	p8["peddler"] = {"place": &"peddler_gate", "until": 980}
	assert_eq(_objective_world([], [], world), "Hanne Vogelsang ist am Tor (bis 16:20)")
	p8.erase("peddler")
	p8["night_question"] = true
	assert_eq(_objective_world([], [], world), "Merkbuch: Wer geht nachts zu den Kranken?")
	p8["sick_light"] = &"house_ott"
	assert_eq(_objective_world([], [], world), "Bei den Otts brennt Licht")
	p8.erase("sick_light")
	p8["night_question"] = false
	p8["disturbed"] = true
	assert_eq(_objective_world([], [], world), "Ein Grab ist aufgewühlt")
	p8["disturbed"] = false
	p8["goal_parts"] = 3
	p8["goal_total"] = 4
	assert_eq(_objective_world([], [], world), "Wer heraufkommt: 3/4")
	world["urgent_order"] = {"id": &"of_lenz_1", "title": "Die Namen", "days_left": 1}
	assert_eq(_objective_world([], [], world), "Auftrag: Die Namen (bis morgen früh)", "an urgent order before the count")
	world.erase("urgent_order")
	p8["goal_done"] = true
	world["board_open"] = 2
	assert_eq(_objective_world([], [], world), "Die Gemeindetafel hat neue Bitten", "then the board")
	p8["fest_today"] = &"fest_lights"
	assert_eq(_objective_world([], [], world), "Heute Abend ist Lichtgang")
	p8["minute"] = 1000
	p8["lights"] = Vector2i(31, 34)
	assert_eq(_objective_world([], [], world), "Kein Grab ohne Licht: 31/34")
	var carried := _corpse(&"carried")
	assert_eq(_objective_world([carried], [_grave(GraveRecord.State.DUG)], world), TO_TABLE, "the corpse still first")


func test_phase8_waits_for_the_village_chapter() -> void:
	var world := {"p7": true, "p7_intro": false, "goal_done": false, "p8": {"intro": false}}
	assert_eq(_objective_world([], [], world), "Sprich mit Osric", "the Phase-7 line (Osric) – not Phase 8's")
	world["p7_intro"] = true
	assert_eq(_objective_world([], [], world), "Geh nach Hollerbrück")
	assert_eq(Phase8Texts.objective({}), "", "nothing before p8_open")


func _objective_world(corpses: Array, graves: Array, world: Dictionary) -> String:
	var typed_corpses: Array[CorpseRecord] = []
	typed_corpses.assign(corpses)
	var typed_graves: Array[GraveRecord] = []
	typed_graves.assign(graves)
	return ObjectiveResolver.current(typed_corpses, typed_graves, _inv, NOON, {}, world)


# --- helpers ------------------------------------------------------------------------------

func _objective(corpses: Array, graves: Array, minute: int = NOON) -> String:
	var typed_corpses: Array[CorpseRecord] = []
	typed_corpses.assign(corpses)
	var typed_graves: Array[GraveRecord] = []
	typed_graves.assign(graves)
	return ObjectiveResolver.current(typed_corpses, typed_graves, _inv, minute, {})


func _corpse(location: StringName, examined: bool = false) -> CorpseRecord:
	var c := CorpseRecord.new()
	c.id = "corpse_%s" % location
	c.display_name = "Hedwig Rabenstein"
	c.location = location
	c.examined = examined
	return c


func _grave(state: GraveRecord.State) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = "plot_%d" % state
	g.state = state
	return g
