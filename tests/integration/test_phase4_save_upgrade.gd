extends TestCase
## P6 (docs/PHASE5_DESIGN.md §5.2, §10): a Phase-4 save (format v3, tests/fixtures/saves_v3/
## slot_p4_day13_complete – cemetery_complete fresh, Holunderwinkel open, deliveries running) in
## the Phase-5 build: it loads through the real SaveManager without warnings, carries the v4 state
## (Phase-5 stats 0, graves without design, tools kept), the deliveries go on, the piety fix acts on
## the next corpse (harvested → no „Voll hergerichtet“, stats.prepared still counts), Osric offers
## the quarry license from workshop_open on (real DialogueRunner, coins into the ledger), and the
## v4 resave round-trips.
## W-Welt (W2, §10): with the workyard in the world the loom is built on its site and weaves the
## burial gown for the next corpse, and a designed stone goes straight onto a FILLED grave (with
## the burial payment, like placing a first marker).

## Records push_warning() messages (warnings never fail a test on their own).
class WarningLog extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		messages.append(code + " " + rationale)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := messages.duplicate()
		messages.clear()
		_mutex.unlock()
		return out


const TIMEOUT := 180.0
const SLOT := 5
const RESAVE_SLOT := 6
const FIXTURE := "slot_p4_day13_complete"
const TOOLS: Array[StringName] = [&"scrub_brush", &"comb", &"rake", &"shears", &"pliers"]
const V4_STATS: Array[StringName] = [&"crafted", &"stones_set", &"coins_spent", &"trees_felled",
		&"coins_spent_license", &"coins_spent_build", &"coins_spent_osric", &"coins_spent_ilse"]

var saves_dir := TestCase.user_dir("test_phase4_save_upgrade")
var warnings: WarningLog
var world: WorldRoot
var delivered: Array[String] = []
var piety_reasons: Array[String] = []
var spent: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	warnings = WarningLog.new()
	OS.add_logger(warnings)
	delivered.clear()
	piety_reasons.clear()
	spent.clear()
	EventBus.corpse_arrived.connect(_on_delivered)
	EventBus.piety_changed.connect(_on_piety)
	EventBus.coins_spent.connect(_on_spent)


func after_each() -> void:
	EventBus.corpse_arrived.disconnect(_on_delivered)
	EventBus.piety_changed.disconnect(_on_piety)
	EventBus.coins_spent.disconnect(_on_spent)
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_day13_complete_upgrades_to_phase5() -> void:
	await _load()
	if world == null:
		return
	var inv := world.get_player().inventory
	# §5.2: v4 state after the load.
	for key: StringName in V4_STATS:
		assert_eq(GameState.get_stat(key), 0, "stat %s" % key)
	for id: StringName in TOOLS:
		assert_eq(inv.count(id), 1, "%s kept (belt or slot)" % id)
	assert_eq(inv.count(&"coin"), 55)
	var marked := 0
	for g: GraveRecord in world.graveyard.graves():
		assert_eq(g.design, {}, "%s: no designed stone yet" % g.id)
		if g.state == GraveRecord.State.MARKED:
			marked += 1
	assert_eq(marked, 12)
	assert_eq(GameState.get_stat(&"piety"), 48, "piety unchanged (the fix only acts from now on)")
	assert_eq(GameState.get_stat(&"prepared"), 11)
	# Phase 5 opens from cemetery_complete (Workshop.post_load, P1); the W0 world has no workshop yet.
	var workshop := world.get_node_or_null("Systems/Workshop") as Workshop
	if workshop != null and not _is_stub(workshop):
		assert_true(GameState.has_flag(&"workshop_open"), "workshop_open right after loading (§1.2)")
	else:
		GameState.set_flag(&"workshop_open", true)
	# Piety fix (§2.9) on the corpse of day 13 at the bier: hair taken, washed, shrouded, laid out.
	_harvest_then_prepare("corpse_0013", inv)
	_bury("corpse_0013", "h_01", inv)
	# The deliveries go on (five Holunderwinkel plots still free).
	await _next_morning()
	assert_eq(delivered.size(), 1, "a delivery on day 14")
	assert_eq(warnings.take(), PackedStringArray(), "a quiet morning")
	# Osric: the quarry license through the real dialogue (coins → ledger).
	var coins := inv.count(&"coin")
	_buy_license(inv)
	assert_eq(inv.count(&"coin"), coins - 20, "the license costs 20")
	assert_eq(GameState.get_flag(&"bruch_license"), true)
	assert_eq(spent, [[20, &"license"]])
	assert_eq([GameState.get_stat(&"coins_spent"), GameState.get_stat(&"coins_spent_license")], [20, 20])
	await _loom_gown_and_designed_stone(inv)
	assert_eq(warnings.take(), PackedStringArray(), "no warnings in the Phase-5 steps")
	# The v4 resave round-trips (ledger and flags included).
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION)  # v4; Phase 6: v5
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v4 round trip")
	assert_eq(GameState.get_stat(&"coins_spent_license"), 20)
	assert_eq(warnings.take(), PackedStringArray(), "the v4 file loads quietly")


# --- helpers ----------------------------------------------------------------------------------

## §10: loom built on its build site (8 wood, 2 fittings, 10 coins) → yarn → linen → burial gown for
## the corpse delivered on day 14 → buried in h_02 (FILLED) → mason's bench → a stele with an
## inscription set on that FILLED grave: MARKED, the burial is paid, the design is stored.
func _loom_gown_and_designed_stone(inv: Inventory) -> void:
	var player := world.get_player()
	player.instant_actions = true
	var shop := world.get_node("Systems/Workshop") as Workshop
	var masonry := world.get_node("Systems/Stonemasonry") as Stonemasonry
	inv.add_item(&"wood", 11)
	inv.add_item(&"iron_fittings", 2)
	var site := world.get_node("Entities/site_loom") as BuildSite
	site.refresh()
	assert_true(site.visible and site.is_active(), "the loom's build site is shown")
	assert_eq(site.block_reason(inv), "", "loom buildable")
	site._player = player
	site.request_build()
	assert_true(shop.is_built(&"loom"), "loom built")
	UIState.clear()
	var loom := world.get_node("Entities/station_loom") as Workbench
	assert_true(loom.visible and loom.can_interact(player), "the loom stands")
	inv.add_item(&"flax", 10)
	loom.interact(player)
	for i: int in 5:
		loom.request_craft(&"yarn")
	loom.request_craft(&"linen_woven")
	loom.request_craft(&"burial_gown_loom")
	UIState.clear()
	assert_eq(inv.count(&"burial_gown"), 1, "a burial gown from the loom")
	# The corpse of day 14 onto the table, examined, dressed in the woven gown, buried in h_02.
	var record: CorpseRecord = null
	for r: CorpseRecord in world.corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF:
			record = r
	assert_not_null(record, "the corpse of day 14")
	if record == null:
		return
	var table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	world.corpse_manager.put_down(record.id, &"table", table.slot_transform(), table.slot_node())
	var care := tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	care.exam_all_instant(record.id)
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(care.dress(record.id, CorpseRecord.DRESS_GOWN, inv), "dressed in the loom's gown")
	assert_eq(record.dress, CorpseRecord.DRESS_GOWN)
	assert_true(world.graveyard.dig("h_02") and world.graveyard.bury("h_02", record.id), "buried in h_02")
	assert_eq(world.graveyard.get_grave("h_02").state, GraveRecord.State.FILLED)
	# The mason's bench, a stele with inscription → straight onto the FILLED grave (paid).
	inv.add_item(&"stone", 10)
	inv.add_item(&"ink", 1)
	assert_true(shop.build(&"mason", inv), "mason's bench built")
	var design := StoneDesign.new()
	design.shape = &"stone_stele"
	design.inscription = &"i_rest"
	assert_eq(masonry.order_block_reason("h_02", design, inv), "", "a stone for the FILLED grave")
	assert_ne(masonry.carve("h_02", design, inv), "", "carved")
	var coins := inv.count(&"coin")
	var plot := world.get_node_by_layout_id("h_02") as GravePlot
	assert_true(plot.has_stone_to_set(), "the grave offers the stone")
	plot.interact(player)
	var grave := world.graveyard.get_grave("h_02")
	assert_eq(grave.state, GraveRecord.State.MARKED, "h_02 marked with the designed stone")
	assert_eq(StoneDesign.from_dict(grave.design).shape, &"stone_stele")
	assert_true(inv.count(&"coin") > coins, "the burial is paid (%d → %d)" % [coins, inv.count(&"coin")])
	UIState.clear()
	await tree.process_frame


func _load() -> void:
	assert_eq(Phase5Fixtures.install_save_v3(FIXTURE, saves_dir, SLOT), OK)
	warnings.take()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	TimeManager.running = false
	assert_eq(warnings.take(), PackedStringArray(), "loads without warnings")


## A class still marked as a W0 stub (its script source says so).
func _is_stub(node: Node) -> bool:
	var script := node.get_script() as GDScript
	return script != null and script.source_code.contains("## STUB (")


func _harvest_then_prepare(corpse_id: String, inv: Inventory) -> void:
	var care := tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	assert_not_null(care, "CorpseCare")
	var record := world.corpse_manager.get_record(corpse_id)
	if care == null or record == null:
		return
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	var prepared_before := GameState.get_stat(&"prepared")
	var reason := care.harvest_block_reason(corpse_id, &"hair", inv)
	assert_eq(reason, "", "hair can be taken")
	assert_true(care.harvest(corpse_id, &"hair", inv), "hair taken")
	inv.add_item(&"shroud", 1)
	assert_true(care.wash(corpse_id, inv), "washed")
	assert_true(care.dress(corpse_id, &"shroud", inv), "shrouded")
	assert_true(care.lay_out(corpse_id, inv), "laid out")
	assert_true(record.is_fully_prepared())
	assert_false(piety_reasons.has(CorpseCare.REASON_FULL_PREP), "no „Voll hergerichtet“ for a harvested corpse")
	assert_eq(GameState.get_stat(&"prepared"), prepared_before + 1, "stats.prepared counts it")


## Real Graveyard API: dig, bury, a wooden cross (paid burial as in Phase 4).
func _bury(corpse_id: String, plot: String, inv: Inventory) -> void:
	assert_eq(world.graveyard.get_grave(plot).state, GraveRecord.State.EMPTY, plot + " free")
	assert_true(world.graveyard.dig(plot) and world.graveyard.bury(plot, corpse_id), "%s buried in %s" % [corpse_id, plot])
	inv.add_item(&"wooden_cross", 1)
	world.graveyard.place_marker(plot, &"wooden_cross", inv)
	assert_eq(world.graveyard.get_grave(plot).design, {}, "a plain cross, no design")


func _buy_license(inv: Inventory) -> void:
	var r := DialogueRunner.new()
	var speaker := world.get_node_by_layout_id("npc_carter")
	r.start(Database.dialogue(&"carter") as DialogueData, {"inventory": inv, "speaker": speaker})
	r._enter(&"p5_intro")
	assert_eq(r.current_node().id if r.current_node() != null else &"", &"p5_intro", "Osric introduces the quarry")
	assert_true(r.current_text().contains("Lorenz' alter Werkplatz"))
	_choose(r, &"p5_license")
	_choose(r, &"p5_license_bought")
	assert_true(GameState.has_flag(&"p5_intro"))


func _choose(r: DialogueRunner, next: StringName) -> void:
	var choices := r.available_choices()
	for i: int in choices.size():
		if choices[i].next == next:
			r.choose(i)
			return
	fail("no choice to %s" % next)


func _next_morning() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	TimeManager.set_time(TimeManager.day + 1, tables.delivery_minute)
	await tree.process_frame


func _on_delivered(corpse_id: String) -> void:
	delivered.append(corpse_id)


func _on_piety(_value: int, _tier: StringName, _delta: int, reason: String) -> void:
	piety_reasons.append(reason)


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])
