extends TestCase
## P2 (docs/PHASE4_DESIGN.md §2.3, §2.5, §2.6, §10): CorpsePrep rules (order, tool / item,
## shroud vs. gown), CorpseCare preparation (full_prep exactly once, +3 piety, stats.prepared,
## juniper windows slow the decay), harvesting via CorpseCare (item, reputation, piety, locks,
## full inventory) and the MorgueTable panel calls (timed minutes, warnings, panel_state).

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"


class ManagerDouble extends CorpseManager:
	var recs: Dictionary = {}
	var notified: Array[String] = []

	func _ready() -> void:
		pass

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord

	func records() -> Array[CorpseRecord]:
		var out: Array[CorpseRecord] = []
		out.assign(recs.values())
		return out

	func notify_changed(id: String) -> void:
		notified.append(id)


## Piety that records its events (the real one is P3's).
class PietyDouble extends Piety:
	var events: Array = []

	func event(kind: StringName, reason: String) -> void:
		events.append([kind, reason])


class ReputationDouble extends Reputation:
	var events: Array = []

	func _ready() -> void:
		pass

	func event(kind: StringName, reason: String) -> void:
		events.append([kind, reason])


class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false

	func add_item(_id: StringName, amount: int) -> int:
		return amount


var prep: PrepConfig
var manager: ManagerDouble
var piety: PietyDouble
var rep: ReputationDouble
var care: CorpseCare
var inv: Inventory
var prepared: Array = []
var harvested: Array = []
var notes: Array = []


func before_each() -> void:
	prep = Phase4Fixtures.prep_config()
	prepared.clear()
	harvested.clear()
	notes.clear()
	manager = ManagerDouble.new()
	piety = PietyDouble.new()
	rep = ReputationDouble.new()
	care = CorpseCare.new()
	care.exam_config = Phase4Fixtures.exam_config()
	care.prep_config = prep
	care.utilization_config = Phase4Fixtures.utilization_config()
	care.tables = load(FIXTURE_TABLES) as CorpseTables
	care.finds = Phase4Fixtures.finds()
	care.harvest_rule = _harvest_rule
	for n: Node in [manager, piety, rep, care]:
		tree.root.add_child(n)
	inv = FakeInventory.new()
	EventBus.corpse_prepared.connect(_on_prepared)
	EventBus.corpse_harvested.connect(_on_harvested)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.corpse_prepared.disconnect(_on_prepared)
	EventBus.corpse_harvested.disconnect(_on_harvested)
	EventBus.notification_requested.disconnect(_on_note)
	if is_instance_valid(inv) and inv.get_parent() == null:
		inv.free()


## Stand-in for UtilizationRules.block_reason (P3, a stub in W1): hidden until the trader is
## known, then tool, then minimum freshness – the §2.6 contract.
func _harvest_rule(record: CorpseRecord, kind: StringName, i: Inventory, cfg: UtilizationConfig, known: bool) -> String:
	if not known:
		return UtilizationRules.HIDDEN
	var entry := cfg.kind(kind)
	if i == null or not i.has(StringName(entry.tool)):
		return "Werkzeug fehlt – Ilse Kranich hat es."
	if record.freshness < float(entry.min_freshness):
		return String(entry.get("low_freshness_text", "zu spät"))
	return ""


func _on_prepared(id: String, action: StringName) -> void:
	prepared.append([id, action])


func _on_harvested(id: String, kind: StringName, item: StringName) -> void:
	harvested.append([id, kind, item])


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _record(traits: Array[StringName] = [], freshness: float = 1.0, id: String = "corpse_test") -> CorpseRecord:
	var r := Phase4Fixtures.corpse(traits, &"fever", freshness)
	r.id = id
	r.location = CorpseRecord.LOCATION_TABLE
	manager.recs[id] = r
	return r


func _tools() -> void:
	inv.add_item(&"scrub_brush", 1)
	inv.add_item(&"comb", 1)


# --- CorpsePrep rules ------------------------------------------------------------------------

func test_minutes_per_action() -> void:
	assert_eq(CorpsePrep.minutes(&"wash", prep), 15)
	assert_eq(CorpsePrep.minutes(&"dress", prep, &"shroud"), 10)
	assert_eq(CorpsePrep.minutes(&"dress", prep, &"gown"), 15)
	assert_eq(CorpsePrep.minutes(&"lay_out", prep), 10)
	assert_eq(CorpsePrep.minutes(&"balm", prep), 10)
	assert_eq(CorpsePrep.minutes(&"nope", prep), 0)


func test_wash_needs_the_brush_and_comes_before_dressing() -> void:
	var r := _record()
	assert_eq(CorpsePrep.block_reason(r, &"wash", inv, prep), "Wurzelbürste nötig – Werkbank.")
	inv.add_item(&"scrub_brush", 1)
	assert_eq(CorpsePrep.block_reason(r, &"wash", inv, prep), "")
	r.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(CorpsePrep.block_reason(r, &"wash", inv, prep), "Nach dem Einkleiden nicht mehr möglich.")
	r.dress = CorpseRecord.DRESS_NONE
	r.washed = true
	assert_eq(CorpsePrep.block_reason(r, &"wash", inv, prep), "Die Leiche ist schon gewaschen.")


func test_dress_needs_its_item_and_the_valuables_decision() -> void:
	var r := _record([&"valuables"])
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"shroud"), "Kein Leichentuch – an der Werkbank herstellen.")
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"gown"), "Kein Totenhemd – an der Werkbank herstellen.")
	assert_ne(CorpsePrep.block_reason(r, &"dress", inv, prep, &"cape"), "", "unknown kind")
	inv.add_item(&"shroud", 1)
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"shroud"), "")
	r.examined = true
	r.exam_done.append(&"pockets")
	r.traits_revealed.append(&"valuables")
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"shroud"), "Erst über die Wertsachen entscheiden.")
	r.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"shroud"), "")
	r.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(CorpsePrep.block_reason(r, &"dress", inv, prep, &"gown"), "Die Leiche ist bereits eingehüllt.")


func test_lay_out_needs_the_comb_before_or_after_dressing() -> void:
	var r := _record()
	assert_eq(CorpsePrep.block_reason(r, &"lay_out", inv, prep), "Holzkamm nötig – Werkbank.")
	inv.add_item(&"comb", 1)
	r.dress = CorpseRecord.DRESS_GOWN
	assert_eq(CorpsePrep.block_reason(r, &"lay_out", inv, prep), "", "also after dressing")
	r.laid_out = true
	assert_eq(CorpsePrep.block_reason(r, &"lay_out", inv, prep), "Die Leiche ist schon aufgebahrt.")


func test_balm_rules_and_windows() -> void:
	TimeManager.set_time(1, 600)
	var now := TimeManager.total_minutes()
	var r := _record()
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, prep), "Keine Wacholderzweige mehr – Osric verkauft sie.")
	inv.add_item(&"juniper", 5)
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, prep), "")
	r.balm_windows = PackedInt32Array([now - 10, now + 10])
	assert_true(CorpsePrep.is_balm_active(r, now))
	assert_false(CorpsePrep.is_balm_active(r, now + 10), "end is exclusive")
	assert_eq(CorpsePrep.balm_end(r, now), now + 10)
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, prep), "Der Wacholderrauch hängt noch über ihr.")
	r.balm_windows = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, prep), "Mehr Rauch hilft ihr nicht mehr.", "max 4 windows")
	assert_eq(CorpsePrep.balm_end(r, now), -1)


# --- CorpseCare preparation ------------------------------------------------------------------

func test_full_preparation_counts_exactly_once() -> void:
	var r := _record()
	_tools()
	inv.add_item(&"burial_gown", 1)
	assert_true(care.wash(r.id, inv))
	assert_false(care.wash(r.id, inv), "once")
	assert_true(care.lay_out(r.id, inv))
	assert_eq(piety.events, [], "two of three parts")
	assert_true(care.dress(r.id, &"gown", inv))
	assert_eq([r.washed, r.dress, r.shrouded, r.laid_out], [true, &"gown", true, true])
	assert_eq(inv.count(&"burial_gown"), 0, "gown consumed")
	assert_eq(inv.count(&"scrub_brush") + inv.count(&"comb"), 2, "tools stay")
	assert_eq(piety.events, [[&"full_prep", CorpseCare.REASON_FULL_PREP]])
	assert_eq(GameState.get_stat(&"prepared"), 1)
	assert_eq(prepared, [[r.id, &"wash"], [r.id, &"lay_out"], [r.id, &"dress"]])
	assert_eq(manager.notified, [r.id, r.id, r.id])
	inv.add_item(&"juniper", 1)
	assert_true(care.apply_balm(r.id, inv))
	assert_eq(piety.events.size(), 1, "smoking afterwards does not count again")
	assert_eq(GameState.get_stat(&"prepared"), 1)


func test_shroud_vs_gown_and_quality() -> void:
	var economy := Phase4Fixtures.economy_config()
	var a := _record([], 0.45, "a")
	var b := _record([], 0.45, "b")
	inv.add_item(&"shroud", 1)
	inv.add_item(&"burial_gown", 1)
	assert_true(care.dress("a", &"shroud", inv))
	assert_true(care.dress("b", &"gown", inv))
	assert_eq([inv.count(&"shroud"), inv.count(&"burial_gown")], [0, 0])
	assert_eq(GraveQuality.compute(a, &"", economy), 4, "buried 2 + shroud 2")
	assert_eq(GraveQuality.compute(b, &"", economy), 5, "buried 2 + gown 3")
	assert_false(care.dress("a", &"gown", inv), "dressed once")


func test_dress_refused_without_item_or_decision() -> void:
	var r := _record([&"valuables"])
	assert_false(care.dress(r.id, &"shroud", inv))
	care.exam_step(r.id, &"pockets")
	inv.add_item(&"shroud", 1)
	assert_false(care.dress(r.id, &"shroud", inv), "valuables decision open")
	assert_eq(inv.count(&"shroud"), 1, "nothing consumed")
	r.valuables_decision = CorpseRecord.DECISION_TAKEN
	assert_true(care.dress(r.id, &"shroud", inv))
	assert_eq(care.step_block_reason(r.id, &"clothing"), "Nach dem Einkleiden nicht mehr zugänglich.")


func test_balm_slows_the_decay() -> void:
	TimeManager.set_time(1, 460)
	var r := _record()
	r.arrival_total_minutes = TimeManager.total_minutes()
	inv.add_item(&"juniper", 2)
	assert_true(care.apply_balm(r.id, inv))
	var now := TimeManager.total_minutes()
	assert_eq(r.balm_windows, PackedInt32Array([now, now + 1080]))
	assert_eq(inv.count(&"juniper"), 1)
	assert_false(care.apply_balm(r.id, inv), "window still running")
	assert_eq(prepared, [[r.id, &"balm"]])
	# Freshness with the window (P1's CorpseDecay; W1 stub may ignore it) is never below the
	# plain one.
	var plain := CorpseRecord.new()
	plain.arrival_total_minutes = r.arrival_total_minutes
	var later := now + 600
	assert_true(CorpseDecay.freshness_at(r, later, 0.05, prep.balm_factor) >= CorpseDecay.freshness_at(plain, later, 0.05, prep.balm_factor))


# --- harvesting ------------------------------------------------------------------------------

func test_harvest_hidden_until_the_trader_is_known() -> void:
	var r := _record()
	assert_eq(care.harvest_block_reason(r.id, &"hair", inv), UtilizationRules.HIDDEN)
	GameState.set_flag(&"trader_known", true)
	assert_eq(care.harvest_block_reason(r.id, &"hair", inv), "Werkzeug fehlt – Ilse Kranich hat es.")
	assert_false(care.harvest(r.id, &"hair", inv))


func test_harvest_hair_gives_the_braid_and_costs() -> void:
	TimeManager.set_time(4, 600)
	GameState.set_flag(&"trader_known", true)
	var r := _record()
	# A fresh corpse of today (QA4-01: the harvest checks the freshness of now).
	r.arrival_total_minutes = TimeManager.total_minutes()
	r.last_decay_total = r.arrival_total_minutes
	inv.add_item(&"shears", 1)
	assert_eq(care.harvest_block_reason(r.id, &"hair", inv), "")
	assert_true(care.harvest(r.id, &"hair", inv))
	assert_eq(inv.count(&"hair_braid"), 1)
	assert_eq(r.harvested, [&"hair"] as Array[StringName])
	assert_eq(piety.events, [[&"hair_taken", String(care.utilization_config.kind(&"hair").label)]])
	assert_eq(rep.events.size(), 1)
	assert_eq(rep.events[0][0], &"hair_taken")
	assert_eq(GameState.get_stat(&"utilized"), 1)
	assert_eq(GameState.get_flag(&"piety_used_day"), 4)
	assert_eq(harvested, [[r.id, &"hair", &"hair_braid"]])
	assert_eq(notes.back(), [String(care.utilization_config.kind(&"hair").done_text), &"info"])
	assert_eq(care.harvest_block_reason(r.id, &"hair", inv), CorpseCare.REASON_HARVESTED)
	assert_false(care.harvest(r.id, &"hair", inv), "once per corpse")
	assert_eq(GraveQuality.compute(r, &"", Phase4Fixtures.economy_config()), 2 + 1 - 1, "buried + fresh − hair")


func test_harvest_locks_dressing_and_freshness_and_full_inventory() -> void:
	GameState.set_flag(&"trader_known", true)
	inv.add_item(&"shears", 1)
	inv.add_item(&"pliers", 1)
	var brittle := _record([], 0.2, "brittle")
	assert_ne(care.harvest_block_reason("brittle", &"hair", inv), "", "hair too brittle")
	assert_eq(care.harvest_block_reason("brittle", &"teeth", inv), "", "teeth have no limit")
	var dressed := _record([], 1.0, "dressed")
	dressed.dress = CorpseRecord.DRESS_SHROUD
	assert_eq(care.harvest_block_reason("dressed", &"teeth", inv), CorpseCare.REASON_DRESSED)
	assert_false(care.harvest("dressed", &"teeth", inv))
	var full := FullInventory.new()
	full.add_item(&"pliers", 1)
	full.items[&"pliers"] = 1
	_record([], 1.0, "full")
	assert_eq(care.harvest_block_reason("full", &"teeth", full), CorpseCare.REASON_INVENTORY_FULL)
	assert_false(care.harvest("full", &"teeth", full))
	full.free()
	assert_eq(piety.events, [], "nothing happened")
	assert_eq(GameState.get_stat(&"utilized"), 0)


# --- MorgueTable panel calls -----------------------------------------------------------------

func _table_world() -> Array:
	var world := Node3D.new()
	tree.root.add_child(world)
	var table := (load(TABLE_SCENE) as PackedScene).instantiate() as MorgueTable
	world.add_child(table)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	world.add_child(player)
	player.instant_actions = true
	await tree.process_frame
	return [table, player]


func test_table_requests_run_their_minutes() -> void:
	var parts: Array = await _table_world()
	var table: MorgueTable = parts[0]
	var player: Player = parts[1]
	TimeManager.set_time(1, 600)
	var r := _record([&"tattoo"])
	var start := TimeManager.total_minutes()
	table.request_exam_step(&"hands")
	assert_eq(r.exam_done, [&"hands"] as Array[StringName])
	assert_eq(TimeManager.total_minutes(), start + 10)
	table.request_exam_step(&"hands")
	assert_eq(notes.back(), ["Schon untersucht.", &"warning"])
	table.request_exam_all()
	assert_true(r.is_fully_examined())
	assert_eq(TimeManager.total_minutes(), start + 10 + 35, "clothing + wounds + pockets as one action")
	table.request_wash()
	assert_eq(notes.back(), ["Wurzelbürste nötig – Werkbank.", &"warning"])
	player.inventory.add_item(&"scrub_brush", 1)
	player.inventory.add_item(&"comb", 1)
	player.inventory.add_item(&"shroud", 1)
	player.inventory.add_item(&"juniper", 1)
	table.request_wash()
	table.request_shroud()
	table.request_lay_out()
	table.request_balm()
	assert_eq([r.washed, r.dress, r.laid_out, r.balm_windows.size()], [true, &"shroud", true, 2])
	assert_eq(TimeManager.total_minutes(), start + 45 + 15 + 10 + 10 + 10)
	table.request_dress(&"gown")
	assert_eq(notes.back(), ["Die Leiche ist bereits eingehüllt.", &"warning"])
	var before := notes.size()
	table.request_harvest(&"hair")
	assert_eq(notes.size(), before, "hidden harvest: no note")


func test_table_examine_compat_resolves_every_step() -> void:
	var parts: Array = await _table_world()
	var table: MorgueTable = parts[0]
	var r := _record([&"valuables", &"tattoo"])
	var start := TimeManager.total_minutes()
	table.request_examine()
	assert_true(r.is_fully_examined(), "Phase-2 button = everything at once")
	assert_eq(TimeManager.total_minutes(), start + 20, "ActionConfig.examine_minutes")
	assert_eq(r.traits_revealed, [&"tattoo", &"valuables"] as Array[StringName])
	table.request_examine()
	assert_eq(notes.back(), [MorgueTable.TEXT_EXAMINED, &"warning"])


func test_table_harvest_and_panel_state() -> void:
	var parts: Array = await _table_world()
	var table: MorgueTable = parts[0]
	var player: Player = parts[1]
	GameState.set_flag(&"trader_known", true)
	var r := _record([&"tattoo"], 0.5)
	var state := table.panel_state()
	assert_eq(state.corpse_id, r.id)
	assert_eq(state.open_steps, CorpseRecord.STEPS)
	assert_eq(state.exam_all_minutes, 45)
	assert_true(state.harvest_visible)
	assert_eq(state.harvest[&"hair"].reason, "Werkzeug fehlt – Ilse Kranich hat es.")
	assert_eq(state.prep.dress_warning, MorgueTablePanelState.DRESS_WARNING)
	player.inventory.add_item(&"shears", 1)
	var start := TimeManager.total_minutes()
	table.request_harvest(&"hair")
	assert_eq(player.inventory.count(&"hair_braid"), 1)
	assert_eq(TimeManager.total_minutes(), start + 10)
	table.request_exam_step(&"hands")
	table.request_exam_step(&"clothing")
	state = table.panel_state()
	assert_eq(state.finds, [{"id": &"f_tattoo", "step": &"hands", "label": "Tätowierung",
			"text": String((load(FIXTURE_TABLES) as CorpseTables).get_trait(&"tattoo").get("reveal_text", "")), "state": &"revealed", "clue_id": &"c_anchor_snake"}])
	assert_eq(state.nothing_steps, [&"clothing"] as Array[StringName])
	assert_eq(state.harvest[&"hair"].done, true)
	assert_eq(state.next_loss.get("find_id"), &"f_cause_fever", "wounds still open: the cause detail is next at risk")


# --- Phase 5 (P6): piety fix §2.9 (G4 finding B2) and herb bundles §2.6 -------------------------

## Hair taken, then washed, dressed, laid out: no full_prep, stats.prepared +1, quality unchanged.
func _harvest_then_prepare(cfg: PietyConfig) -> CorpseRecord:
	piety.config = cfg
	GameState.set_flag(&"trader_known", true)
	TimeManager.set_time(4, 600)
	var r := _record()
	r.arrival_total_minutes = TimeManager.total_minutes()
	r.last_decay_total = r.arrival_total_minutes
	_tools()
	inv.add_item(&"shears", 1)
	inv.add_item(&"shroud", 1)
	assert_true(care.harvest(r.id, &"hair", inv))
	assert_true(care.wash(r.id, inv))
	assert_true(care.dress(r.id, &"shroud", inv))
	assert_true(care.lay_out(r.id, inv))
	assert_true(r.is_fully_prepared())
	return r


func test_piety_fix_no_full_prep_bonus_after_a_harvest() -> void:
	var r := _harvest_then_prepare(Phase5Fixtures.piety_config())
	assert_eq(piety.events, [[&"hair_taken", String(care.utilization_config.kind(&"hair").label)]], "no full_prep")
	assert_eq(GameState.get_stat(&"prepared"), 1, "the journal stays honest")
	assert_eq(prepared, [[r.id, &"wash"], [r.id, &"dress"], [r.id, &"lay_out"]])
	var economy := Phase4Fixtures.economy_config()
	var labels: Array = []
	for line: Dictionary in GraveQuality.breakdown(r, &"", economy):
		labels.append(line.label)
	for label: String in ["Gewaschen", "Leichentuch", "Aufgebahrt"]:
		assert_has(labels, label, "quality line %s unchanged" % label)


func test_piety_fix_unharvested_still_gets_the_bonus() -> void:
	piety.config = Phase5Fixtures.piety_config()
	var r := _record()
	_tools()
	inv.add_item(&"shroud", 1)
	care.wash(r.id, inv)
	care.dress(r.id, &"shroud", inv)
	care.lay_out(r.id, inv)
	assert_eq(piety.events, [[&"full_prep", CorpseCare.REASON_FULL_PREP]])
	assert_eq(GameState.get_stat(&"prepared"), 1)


func test_piety_fix_flag_off_restores_the_phase4_rule() -> void:
	var cfg := Phase5Fixtures.piety_config().duplicate() as PietyConfig
	cfg.full_prep_requires_unharvested = false
	_harvest_then_prepare(cfg)
	assert_eq(piety.events.back(), [&"full_prep", CorpseCare.REASON_FULL_PREP], "old behaviour")
	assert_eq(GameState.get_stat(&"prepared"), 1)


func test_full_prep_counts_rule() -> void:
	var cfg := PietyConfig.new()
	var r := CorpseRecord.new()
	assert_true(CorpseCare.full_prep_counts(r, cfg))
	r.harvested = [&"teeth"] as Array[StringName]
	assert_false(CorpseCare.full_prep_counts(r, cfg))
	assert_false(CorpseCare.full_prep_counts(r, null), "default: the flag is on")
	cfg.full_prep_requires_unharvested = false
	assert_true(CorpseCare.full_prep_counts(r, cfg))
	assert_false(CorpseCare.full_prep_counts(null, cfg))
	assert_true(Database.config(&"piety_config").get(&"full_prep_requires_unharvested"), "data: on")


func test_herb_bundle_smokes_like_juniper() -> void:
	TimeManager.set_time(1, 600)
	care.prep_config = Phase5Fixtures.prep_config()
	var p5 := care.prep_config
	var r := _record()
	assert_eq(CorpsePrep.balm_item_in(inv, p5), &"")
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, p5), "Keine Wacholderzweige mehr – Osric verkauft sie.")
	inv.add_item(&"herb_bundle", 2)
	assert_eq(CorpsePrep.balm_item_in(inv, p5), &"herb_bundle")
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, p5), "")
	assert_true(care.apply_balm(r.id, inv))
	var now := TimeManager.total_minutes()
	assert_eq(r.balm_windows, PackedInt32Array([now, now + p5.balm_window_minutes]), "same window as juniper")
	assert_eq(inv.count(&"herb_bundle"), 1)
	# Juniper first (list order) when both are held.
	var other := _record([], 1.0, "other")
	inv.add_item(&"juniper", 1)
	assert_eq(CorpsePrep.balm_item_in(inv, p5), &"juniper")
	assert_true(care.apply_balm(other.id, inv))
	assert_eq([inv.count(&"juniper"), inv.count(&"herb_bundle")], [0, 1])
	# Phase-4 config (no herb bundles listed explicitly → class default) and an empty list → balm_item.
	var old := Phase4Fixtures.prep_config().duplicate() as PrepConfig
	old.balm_items = [] as Array[StringName]
	assert_eq(CorpsePrep.balm_item_in(inv, old), &"", "empty list: only balm_item (juniper)")
	assert_eq(Database.config(&"prep_config").get(&"balm_items"), [&"juniper", &"herb_bundle"] as Array[StringName])
