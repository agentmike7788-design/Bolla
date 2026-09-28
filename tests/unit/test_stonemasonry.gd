extends TestCase
## P4 (docs/PHASE5_DESIGN.md §2.5, §3.4, §5.1, §10): Stonemasonry – eligible graves, the
## "schon besser" block, rack of 3, one stone per grave, atomic carving, setting on FILLED
## (payment) vs. MARKED (none), master-stone reputation once, discard, "passt nicht mehr",
## text fixed after the S5 rename, save / load; Graveyard.set_designed_stone; GravePlot prompt.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const FILLED := GraveRecord.State.FILLED
const MARKED := GraveRecord.State.MARKED

const MASTER_ITEMS := {&"workstone": 3, &"stone": 2, &"iron_fittings": 2, &"clay": 1, &"ink": 1, &"gold_leaf": 1}


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


class ReputationDouble extends Reputation:
	var calls: Array = []

	func tier() -> StringName:
		return &""

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


class WorkshopDouble extends Node:
	var checks: int = 0

	func check_goal() -> void:
		checks += 1


var world: Node3D
var graveyard: Graveyard
var corpses: CorpseManager
var masonry: Stonemasonry
var rep: ReputationDouble
var workshop: WorkshopDouble
var inv: Inventory
var events: Array = []


func before_each() -> void:
	var tables := load(FIXTURE_TABLES) as CorpseTables
	var eco := Phase5Fixtures.economy_config()
	world = Node3D.new()
	var container := Node3D.new()
	container.name = "Corpses"
	world.add_child(container)
	corpses = CorpseManager.new()
	corpses.tables = tables
	corpses.economy = eco
	corpses.container_path = ^"../Corpses"
	world.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = eco
	graveyard.tables = tables
	graveyard.section_data = Phase3Fixtures.sections()
	graveyard.reputation_config = Phase5Fixtures.reputation_config()
	graveyard.stone_config = Phase5Fixtures.stone_config()
	world.add_child(graveyard)
	for id: String in ["plot_01", "plot_02", "plot_03", "plot_04", "plot_05"]:
		var plot := PlotDouble.new()
		plot.grave_id = id
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	masonry = Stonemasonry.new()
	masonry.config = Phase5Fixtures.stone_config()
	masonry.workshop_config = Phase5Fixtures.workshop_config()
	world.add_child(masonry)
	rep = ReputationDouble.new()
	world.add_child(rep)
	workshop = WorkshopDouble.new()
	workshop.add_to_group(&"workshop")
	world.add_child(workshop)
	tree.root.add_child(world)
	inv = FakeInventory.new()
	events.clear()
	EventBus.stone_order_changed.connect(_on_order)
	EventBus.grave_stone_set.connect(_on_set)
	EventBus.payment_received.connect(_on_payment)
	EventBus.grave_completed.connect(_on_completed)
	EventBus.grave_quality_changed.connect(_on_quality)


func after_each() -> void:
	EventBus.stone_order_changed.disconnect(_on_order)
	EventBus.grave_stone_set.disconnect(_on_set)
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.grave_completed.disconnect(_on_completed)
	EventBus.grave_quality_changed.disconnect(_on_quality)
	inv.free()
	world.queue_free()


# --- contract -------------------------------------------------------------------------------

func test_groups_and_save_contract() -> void:
	assert_true(masonry.is_in_group(&"stonemasonry"))
	assert_true(masonry.is_in_group(&"saveable"))
	assert_eq([masonry.save_id, masonry.save_order], ["stonemasonry", 35])
	assert_eq(masonry.save_state(), {"next_id": 1, "ready": [], "heard_design": []})


# --- eligible graves / blocks -----------------------------------------------------------------

func test_eligible_graves_are_filled_or_marked_with_a_corpse() -> void:
	_filled("plot_01", "Marthe Quendel")
	_marked("plot_02", "Egbert Kornblum", &"wooden_cross")
	graveyard.dig("plot_03")
	var list := masonry.eligible_graves()
	assert_eq(list.size(), 2, "EMPTY / DUG are not listed")
	assert_eq([list[0].grave_id, list[0].name, list[0].marker, list[0].ready], ["plot_01", "Marthe Quendel", &"", false])
	assert_eq([list[1].grave_id, list[1].marker], ["plot_02", &"wooden_cross"])
	assert_eq(list[1].quality, graveyard.get_grave("plot_02").quality)
	assert_eq(list[0].section, &"yard")


func test_block_reasons() -> void:
	_filled("plot_01", "Marthe Quendel")
	_marked("plot_02", "Egbert Kornblum", &"gravestone_simple")
	var stele := Phase5Fixtures.design(&"stone_stele")
	assert_eq(masonry.order_block_reason("plot_03", stele, inv), Stonemasonry.TEXT_NO_GRAVE, "empty plot")
	assert_eq(masonry.order_block_reason("plot_01", StoneDesign.new(), inv), Stonemasonry.TEXT_NO_SHAPE)
	assert_eq(masonry.order_block_reason("plot_01", Phase5Fixtures.design(&"stone_stele", &"", &"", true), inv),
			Stonemasonry.TEXT_GOLD_NEEDS_INSCRIPTION)
	assert_eq(masonry.order_block_reason("plot_02", stele, inv), "Der jetzige Stein ist schon besser.", "3 = 3 is not better")
	assert_true(masonry.order_block_reason("plot_01", stele, inv).begins_with("Es fehlt: 4 "), "4 stone missing")
	_give({&"stone": 4})
	assert_eq(masonry.order_block_reason("plot_01", stele, inv), "")
	assert_true(masonry.order_block_reason("plot_02", Phase5Fixtures.design(&"stone_stele", &"i_rest"), inv).begins_with("Es fehlt: 1 "),
			"stele + inscription 4 > 3: only the ink is missing")


func test_preview_numbers() -> void:
	var c := _marked("plot_01", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	var before := graveyard.get_grave("plot_01").quality
	masonry.inventory = inv
	var p := masonry.preview("plot_01", Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true))
	assert_eq(p.quality_before, before)
	assert_eq(p.quality_after, before - 3 + 9, "gravestone 3 → master 9")
	assert_eq(Array(p.text), ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."])
	assert_true(p.fits)
	assert_eq(p.minutes, 205)
	assert_eq(p.inputs, MASTER_ITEMS)
	assert_eq(p.missing, MASTER_ITEMS, "nothing in the inventory")
	assert_true(String(p.block_reason).begins_with("Es fehlt:"))
	var labels: Array = []
	for line: Dictionary in p.lines:
		labels.append(line.label)
	assert_true(labels.has("Meisterstein") and labels.has("Zierde: Holunderdolde") and not labels.has("Grabstein"), str(labels))
	assert_eq(masonry.preview("plot_05", Phase5Fixtures.design(&"stone_stele")), {}, "no corpse")
	assert_eq(c.display_name, "Marthe Quendel")


# --- carving ----------------------------------------------------------------------------------

func test_carve_takes_material_atomically_and_fixes_the_text() -> void:
	_filled("plot_01", "Marthe Quendel", 63, &"s1_quendel", 37)
	var master := Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true)
	var partial := MASTER_ITEMS.duplicate()
	partial.erase(&"gold_leaf")
	_give(partial)
	assert_eq(masonry.carve("plot_01", master, inv), "", "gold leaf missing")
	assert_eq(inv.count(&"workstone"), 3, "nothing taken")
	_give({&"gold_leaf": 1})
	var crafted := GameState.get_stat(&"crafted")
	var id := masonry.carve("plot_01", master, inv)
	assert_eq(id, "stone_0001")
	for item: StringName in MASTER_ITEMS:
		assert_eq(inv.count(item), 0, String(item) + " taken")
	assert_eq(GameState.get_stat(&"crafted"), crafted + 1, "stats.crafted")
	assert_eq(events, [["order", "stone_0001", "plot_01", &"ready"]])
	var ready := masonry.ready_for("plot_01")
	assert_eq([ready.id, ready.shape, ready.name, ready.fits_still], ["stone_0001", &"stone_master", "Marthe Quendel", true])
	assert_eq(ready.design.text, ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."])
	assert_true(masonry.eligible_graves()[0].ready)


func test_one_stone_per_grave_and_rack_of_three() -> void:
	for i: int in 5:
		_filled("plot_0%d" % (i + 1), "Tote %d" % i)
	_give({&"stone": 40})
	var stele := Phase5Fixtures.design(&"stone_stele")
	assert_ne(masonry.carve("plot_01", stele, inv), "")
	assert_eq(masonry.order_block_reason("plot_01", stele, inv), "Für dieses Grab liegt schon ein Stein bereit.")
	assert_eq(masonry.carve("plot_01", stele, inv), "")
	assert_ne(masonry.carve("plot_02", stele, inv), "")
	assert_ne(masonry.carve("plot_03", stele, inv), "")
	assert_eq(masonry.order_block_reason("plot_04", stele, inv), "Die Ablage ist voll – setz erst einen Stein.")
	assert_eq(masonry.carve("plot_04", stele, inv), "")
	assert_eq(masonry.ready_stones().size(), 3)
	assert_eq(inv.count(&"stone"), 40 - 12)


# --- setting ----------------------------------------------------------------------------------

func test_set_on_filled_pays_like_place_marker() -> void:
	_filled("plot_01", "Marthe Quendel", 63, &"s1_quendel", 37)
	_give({&"stone": 5, &"clay": 1, &"ink": 1})
	var arch := Phase5Fixtures.design(&"stone_arch", &"i_garden", &"orn_ivy")
	var id := masonry.carve("plot_01", arch, inv)
	events.clear()
	var diff := masonry.set_stone("plot_01", inv)
	var g := graveyard.get_grave("plot_01")
	assert_eq(g.state, MARKED)
	assert_eq(g.marker_id, &"stone_arch")
	assert_eq(g.design.text, ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."])
	assert_eq(diff, g.quality, "FILLED: difference from 0")
	var paid := inv.count(&"coin")
	assert_true(paid > 0, "payment")
	var c := corpses.get_record(g.corpse_id)
	var expected := GraveQuality.payment_parts(c, g.quality, graveyard.tables, graveyard.economy, &"", graveyard.reputation_config)
	assert_eq(paid, int(expected.total))
	assert_true(_has_event(["completed", "plot_01", g.quality]), str(events))
	assert_true(_has_event(["payment", paid]), str(events))
	assert_true(_has_event(["stone_set", "plot_01", &"stone_arch", g.quality]))
	assert_true(_has_event(["order", id, "plot_01", &"set"]))
	assert_eq(GameState.get_stat(&"stones_set"), 1)
	assert_eq(workshop.checks, 1, "Workshop.check_goal")
	assert_eq(masonry.ready_stones(), [] as Array[Dictionary], "left the rack")
	assert_eq(rep.calls, [["event", &"grave_good", "Grab von Marthe Quendel"]])


func test_set_on_marked_no_payment_and_master_reputation_once() -> void:
	_marked("plot_01", "Marthe Quendel", &"gravestone_simple", 63, &"s1_quendel", 37)
	var before := graveyard.get_grave("plot_01").quality
	rep.calls.clear()
	_give({&"workstone": 6, &"stone": 4, &"iron_fittings": 4, &"clay": 2, &"ink": 2, &"gold_leaf": 1})
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_master"), inv)
	events.clear()
	var diff := masonry.set_stone("plot_01", inv)
	assert_eq(diff, 2, "gravestone 3 → master 5")
	assert_eq(graveyard.get_grave("plot_01").quality, before + 2)
	assert_eq(inv.count(&"coin"), 0, "no second payment")
	assert_false(_has_event_kind("payment") or _has_event_kind("completed"))
	assert_true(_has_event(["quality", "plot_01", before + 2]))
	assert_eq(rep.calls, [["event", &"marker_upgrade", "Grabzeichen von Marthe Quendel aufgewertet"],
			["event", &"master_stone", "Ein Meisterstein auf dem Friedhof. Das spricht sich herum."]])
	rep.calls.clear()
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true), inv)
	assert_eq(masonry.set_stone("plot_01", inv), 4, "master 5 → master complete 9")
	assert_eq(rep.calls, [["event", &"marker_upgrade", "Grabzeichen von Marthe Quendel aufgewertet"]], "master_stone once per grave")
	assert_eq(graveyard.get_grave("plot_01").quality, before + 6, "§2.5: up to +6 over the plain gravestone")


func test_set_designed_stone_refusals() -> void:
	_marked("plot_01", "A", &"gravestone_simple")
	var g := graveyard.get_grave("plot_01")
	var q := g.quality
	assert_eq(graveyard.set_designed_stone("plot_01", Phase5Fixtures.design(&"stone_stele"), inv), 0, "not better")
	assert_eq(graveyard.set_designed_stone("plot_03", Phase5Fixtures.design(&"stone_master"), inv), 0, "EMPTY")
	assert_eq(graveyard.set_designed_stone("plot_01", StoneDesign.new(), inv), 0, "empty design")
	assert_eq([g.marker_id, g.quality, g.design], [&"gravestone_simple", q, {}])
	_filled("plot_02", "B")
	assert_eq(graveyard.set_designed_stone("plot_02", Phase5Fixtures.design(&"stone_stele"), null), 0, "FILLED needs the purse")
	assert_eq(masonry.set_stone("plot_02", inv), 0, "no stone in the rack")


func test_upgrade_options_never_offer_designed_shapes() -> void:
	_marked("plot_01", "A", &"wooden_cross")
	_give({&"stone_stele": 1, &"stone_master": 1, &"gravestone_simple": 1})
	assert_eq(graveyard.upgrade_options("plot_01", inv), [&"gravestone_simple"] as Array[StringName])
	_filled("plot_02", "B")
	assert_eq(graveyard.place_marker("plot_02", &"stone_master", inv), 0, "shapes are no marker items")
	assert_eq(graveyard.get_grave("plot_02").state, FILLED)
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_arch"), _stocked({&"stone": 5, &"clay": 1}))
	masonry.set_stone("plot_01", inv)
	assert_eq(graveyard.upgrade_options("plot_01", inv), [] as Array[StringName], "designed stone: no item upgrade")


func test_no_longer_fitting_stone_and_discard() -> void:
	_marked("plot_01", "A", &"wooden_cross")
	_give({&"stone": 20, &"clay": 2, &"ink": 2})
	var id := masonry.carve("plot_01", Phase5Fixtures.design(&"stone_stele"), inv)
	assert_true(masonry.ready_for("plot_01").fits_still)
	# Meanwhile a better stone was set another way (debug / an arch carved before the rack rule).
	graveyard.set_designed_stone("plot_01", Phase5Fixtures.design(&"stone_arch", &"i_rest"), inv)
	var ready := masonry.ready_for("plot_01")
	assert_false(ready.fits_still, "passt nicht mehr")
	assert_eq(masonry.set_stone("plot_01", inv), 0, "refused")
	assert_eq(masonry.ready_stones().size(), 1, "never discarded automatically")
	events.clear()
	assert_true(masonry.discard(id))
	assert_eq(events, [["order", id, "plot_01", &"discarded"]])
	assert_false(masonry.discard(id), "gone")
	assert_eq(inv.count(&"stone"), 20 - 4, "material lost")


func test_text_stays_after_the_s5_rename() -> void:
	var c := _marked("plot_01", "Lorenz Aschau (?)", &"wooden_cross", 58, &"s5_moor", 20)
	_give({&"stone": 4, &"ink": 1})
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_stele", &"i_rest"), inv)
	c.display_name = "Kaspar Dorn"
	masonry.set_stone("plot_01", inv)
	assert_eq(graveyard.get_grave("plot_01").design.text[1], "Lorenz Aschau", "§2.5: carved text keeps the old name")
	_give({&"stone": 5, &"clay": 1, &"ink": 1})
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_arch", &"i_rest"), inv)
	assert_eq(masonry.ready_for("plot_01").design.text[1], "Kaspar Dorn", "a new stone carries the new name")


func test_save_load_roundtrip() -> void:
	_filled("plot_01", "A")
	_filled("plot_02", "B")
	_give({&"stone": 8, &"ink": 1})
	masonry.carve("plot_01", Phase5Fixtures.design(&"stone_stele", &"i_rest"), inv)
	masonry.carve("plot_02", Phase5Fixtures.design(&"stone_stele"), inv)
	masonry.mark_design_heard("plot_04")
	var state := masonry.save_state()
	assert_eq(state.next_id, 3)
	assert_eq(state.heard_design, ["plot_04"])
	var plain: Dictionary = JSON.parse_string(JSON.stringify(state))
	var other := Stonemasonry.new()
	world.add_child(other)
	other.load_state(plain)
	assert_eq(other.save_state(), state, "JSON roundtrip identical")
	other.load_state({"ready": [{"id": "stone_0009", "grave_id": "plot_01", "design": {"shape": "stone_stele"}}, "junk",
			{"id": "x", "grave_id": "", "design": {}}]})
	assert_eq(other.ready_stones().size(), 1, "tolerant")
	assert_eq(other.save_state().next_id, 10, "next id after the highest saved one")
	other.load_state({})
	assert_eq(other.save_state(), {"next_id": 1, "ready": [], "heard_design": []})
	other.queue_free()


func test_grave_plot_prompt_prefers_the_ready_stone() -> void:
	var plot := (load("res://src/entities/grave/grave_plot.tscn") as PackedScene).instantiate() as GravePlot \
			if ResourceLoader.exists("res://src/entities/grave/grave_plot.tscn") else GravePlot.new()
	plot.grave_id = "plot_05"
	plot.remove_from_group(&"grave_plot")
	world.add_child(plot)
	_marked("plot_05", "Marthe Quendel", &"wooden_cross")
	assert_false(plot.has_stone_to_set())
	_give({&"stone": 4, &"ink": 1})
	masonry.carve("plot_05", Phase5Fixtures.design(&"stone_stele", &"i_rest"), inv)
	assert_true(plot.has_stone_to_set())
	assert_eq(plot.get_interaction_prompt(null), "[E] Gestalteten Stein setzen (20 Min)")
	plot._finish_set_stone(inv)
	assert_eq(graveyard.get_grave("plot_05").marker_id, &"stone_stele")
	assert_false(plot.has_stone_to_set())
	assert_eq(plot.design, graveyard.get_grave("plot_05").design, "visual follows the design")
	var visual := plot.get_child(0)
	assert_not_null(visual.find_child("Inscription", true, false), "inscription on the grave")


# --- helpers ----------------------------------------------------------------------------------

func _corpse(name: String, age: int, story: StringName, day: int) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = name
	r.cause_id = &"fever"
	r.age = age
	r.story_id = story
	r.shrouded = true
	r.examined = true
	var spawned := corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	spawned.arrival_total_minutes = (day - 1) * 1440 + 460  # spawn stamps "now"
	return spawned


func _filled(grave_id: String, name: String, age: int = 50, story: StringName = &"", day: int = 1) -> CorpseRecord:
	var r := _corpse(name, age, story, day)
	graveyard.dig(grave_id)
	graveyard.bury(grave_id, r.id)
	return r


func _marked(grave_id: String, name: String, marker: StringName, age: int = 50, story: StringName = &"", day: int = 1) -> CorpseRecord:
	var r := _filled(grave_id, name, age, story, day)
	var purse := FakeInventory.new()
	purse.add_item(marker, 1)
	graveyard.place_marker(grave_id, marker, purse)
	purse.free()
	events.clear()
	return r


func _give(items: Dictionary) -> void:
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))


func _stocked(items: Dictionary) -> Inventory:
	_give(items)
	return inv


func _has_event(e: Array) -> bool:
	for got: Variant in events:
		if _equal(got, e):
			return true
	return false


func _has_event_kind(kind: String) -> bool:
	for got: Array in events:
		if got[0] == kind:
			return true
	return false


func _on_order(order_id: String, grave_id: String, state: StringName) -> void:
	events.append(["order", order_id, grave_id, state])


func _on_set(grave_id: String, shape_id: StringName, quality: int) -> void:
	events.append(["stone_set", grave_id, shape_id, quality])


func _on_payment(amount: int, _reason: String) -> void:
	events.append(["payment", amount])


func _on_completed(grave_id: String, _corpse_id: String, quality: int, _lines: Array) -> void:
	events.append(["completed", grave_id, quality])


func _on_quality(grave_id: String, quality: int) -> void:
	events.append(["quality", grave_id, quality])
