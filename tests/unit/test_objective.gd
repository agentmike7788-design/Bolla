extends TestCase
## W2: ObjectiveResolver.current() – every branch of the objective chain (docs §1, §7),
## priorities between several corpses / graves, clock-based idle lines and purity.

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
const COMPLETE := "Alle Gräber vollendet – der Friedhof ruht in Würde"
const COMPLETE_MISSED := "Alle Gräber vollendet – Stufe „%s“ (Ziel „Würdevoll“ verfehlt)"
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


func test_slice_complete_wins() -> void:
	# UI-04: COMPLETE only when the goal rating is reached (MARKED quality ≥ dignified threshold).
	var marked := _grave(GraveRecord.State.MARKED)
	marked.quality = _dignified_threshold()
	var graves: Array[GraveRecord] = [_grave(GraveRecord.State.FILLED), marked]
	var corpses: Array[CorpseRecord] = [_corpse(&"carried")]
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {&"slice_complete": true}), COMPLETE)
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {"slice_complete": true}), COMPLETE, "String key")
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {&"slice_complete": false}), TO_TABLE)
	assert_eq(ObjectiveResolver.current(corpses, graves, _inv, NOON, {&"delivery_skipped": 2}), TO_TABLE, "other flags irrelevant")


## UI-04: after the slice the line reflects whether „Würdevoll“ was reached.
func test_slice_complete_reflects_the_goal_rating() -> void:
	var flags := {&"slice_complete": true}
	var goal := _dignified_threshold()
	var economy := Database.config(&"economy_config") as EconomyConfig
	var a := _grave(GraveRecord.State.MARKED)
	var b := _grave(GraveRecord.State.MARKED)
	a.quality = goal - 1
	var graves: Array[GraveRecord] = [a, b]
	var tier := CemeteryRating.label(CemeteryRating.rating(goal - 1, economy))
	assert_eq(ObjectiveResolver.current([], graves, _inv, NOON, flags), COMPLETE_MISSED % tier, "missed by one")
	b.quality = 1
	assert_eq(ObjectiveResolver.current([], graves, _inv, NOON, flags), COMPLETE, "exactly the threshold")
	a.quality = 0
	b.quality = 0
	assert_eq(ObjectiveResolver.current([], graves, _inv, NOON, flags), COMPLETE_MISSED % CemeteryRating.label(&"neglected"))
	var filled := _grave(GraveRecord.State.FILLED)
	filled.quality = goal
	assert_eq(ObjectiveResolver.current([], [filled], _inv, NOON, flags), COMPLETE_MISSED % CemeteryRating.label(&"neglected"),
			"only completed (MARKED) graves count")
	a.quality = goal - economy.old_grave_quality
	var old := _grave(GraveRecord.State.OLD)
	old.quality = 99
	assert_eq(ObjectiveResolver.current([], [a, old], _inv, NOON, flags), COMPLETE,
			"old graves count old_grave_quality like Graveyard.total_quality()")


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


# --- helpers ------------------------------------------------------------------------------

func _dignified_threshold() -> int:
	var thresholds := (Database.config(&"economy_config") as EconomyConfig).rating_thresholds
	return thresholds[CemeteryRating.TIERS.find(&"dignified") - 1]


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
