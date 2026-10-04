extends TestCase
## P3 (docs/PHASE6_DESIGN.md §2.3, §3.4, §10): OssuaryRules (rest period, places 3/5/6, block
## texts, lift minutes), Ossuary (lift OLD → EMPTY, FIFO reinterment, fee / reputation / piety
## once, passage / grille, clue once, save / load), the real ossuary data, OssuaryShelf and
## SealedPassage.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const ACTIONS := "res://tests/fixtures/phase5/action_config_fixture.tres"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const SHELF_SCENE := "res://src/entities/ossuary_shelf/ossuary_shelf.tscn"
const PASSAGE_SCENE := "res://src/entities/sealed_passage/sealed_passage.tscn"
const OLD := GraveRecord.State.OLD
const EMPTY := GraveRecord.State.EMPTY


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


## Buildings with fixed levels; counts check_goal.
class BuildingsDouble extends Buildings:
	var goal_checks: int = 0

	func check_goal() -> void:
		goal_checks += 1


class EventDouble extends Node:
	var calls: Array = []

	func event(kind: StringName, reason: String) -> void:
		calls.append([kind, reason])


class JournalDouble extends Node:
	var added: Array = []

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		added.append(id)
		return true


var world: Node3D
var graveyard: Graveyard
var ossuary: Ossuary
var buildings: BuildingsDouble
var rep: EventDouble
var piety: EventDouble
var journal: JournalDouble
var inv: Inventory
var cfg: CryptConfig
var events: Array = []
var notes: Array = []


func before_each() -> void:
	cfg = Phase6Fixtures.crypt_config()
	world = Node3D.new()
	world.name = "World"
	graveyard = Graveyard.new()
	graveyard.economy = Phase6Fixtures.economy_config()
	graveyard.tables = load(FIXTURE_TABLES) as CorpseTables
	world.add_child(graveyard)
	for id: String in Phase6Fixtures.OLD_GRAVE_IDS:
		world.add_child(_plot(id, true))
	world.add_child(_plot("plot_01", false))
	ossuary = Ossuary.new()
	ossuary.config = cfg
	ossuary.old_grave_data = Phase6Fixtures.old_graves()
	world.add_child(ossuary)
	buildings = BuildingsDouble.new()
	buildings.config = Phase6Fixtures.buildings_config()
	# Fixture buildings (no start_level): the crypt can stand at level 0 here (04.10.2026).
	for data: BuildingData in Phase6Fixtures.buildings():
		buildings.building_table[data.id] = data
	world.add_child(buildings)
	rep = EventDouble.new()
	rep.add_to_group(&"reputation")
	world.add_child(rep)
	piety = EventDouble.new()
	piety.add_to_group(&"piety")
	world.add_child(piety)
	journal = JournalDouble.new()
	journal.add_to_group(&"journal")
	world.add_child(journal)
	tree.root.add_child(world)
	inv = Phase6Fixtures.inv_with({&"bone_box": 3})
	events.clear()
	notes.clear()
	GameState.set_flag(&"buildings_open", true)
	_crypt(1)
	EventBus.grave_state_changed.connect(_on_state)
	EventBus.bones_lifted.connect(_on_lifted)
	EventBus.bones_reinterred.connect(_on_reinterred)
	EventBus.payment_received.connect(_on_payment)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.grave_state_changed.disconnect(_on_state)
	EventBus.bones_lifted.disconnect(_on_lifted)
	EventBus.bones_reinterred.disconnect(_on_reinterred)
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.notification_requested.disconnect(_on_note)
	world.queue_free()
	inv.free()
	await wait_frames(1)


# --- OssuaryRules ---------------------------------------------------------------------------

func test_rest_period_keeps_old_01_and_old_08() -> void:
	for year: int in [Phase6Fixtures.YEAR, Phase6Fixtures.YEAR + 1]:
		var liftable: Array = []
		for data: OldGraveData in Phase6Fixtures.old_graves():
			if OssuaryRules.liftable(data, year, cfg):
				liftable.append(data.grave_id)
		assert_eq(liftable, Array(Phase6Fixtures.LIFTABLE_IDS), "year %d" % year)
	assert_false(OssuaryRules.liftable(Phase6Fixtures.old_grave("old_02", 1805), 1834, cfg), "29 years")
	assert_true(OssuaryRules.liftable(Phase6Fixtures.old_grave("old_02", 1804), 1834, cfg), "30 years")
	assert_false(OssuaryRules.liftable(null, 1834, cfg))


func test_capacity_per_crypt_level() -> void:
	assert_eq([OssuaryRules.capacity(0, cfg), OssuaryRules.capacity(1, cfg), OssuaryRules.capacity(2, cfg),
			OssuaryRules.capacity(3, cfg)], [0, 3, 5, 6])
	assert_eq([OssuaryRules.capacity(-1, cfg), OssuaryRules.capacity(9, cfg), OssuaryRules.capacity(1, null)], [0, 6, 0])
	for level: int in [0, 1, 2, 3]:
		_crypt(level)
		assert_eq(ossuary.capacity(), [0, 3, 5, 6][level])


func test_label() -> void:
	assert_eq(OssuaryRules.label(Phase6Fixtures.old_grave("old_02")), "Agnes Hollweg (1741–1789)")
	assert_eq(OssuaryRules.label(Phase6Fixtures.old_grave("old_03")), "Konrad Pfister, Ratsherr (1702–1771)")
	assert_eq(OssuaryRules.label(null), "")


func test_block_reasons_in_order() -> void:
	var g := Phase6Fixtures.old_grave_record("old_04")
	var d := Phase6Fixtures.old_grave("old_04")
	var y := Phase6Fixtures.YEAR
	assert_eq(OssuaryRules.lift_block_reason(g, d, 1, 0, inv, y, cfg, false), OssuaryRules.TEXT_BURIED, "not open")
	var empty := Phase6Fixtures.old_grave_record("old_04")
	empty.state = EMPTY
	assert_eq(OssuaryRules.lift_block_reason(empty, d, 1, 0, inv, y, cfg, true), OssuaryRules.TEXT_NOT_OLD)
	assert_eq(OssuaryRules.lift_block_reason(null, d, 1, 0, inv, y, cfg, true), OssuaryRules.TEXT_NOT_OLD)
	assert_eq(OssuaryRules.lift_block_reason(Phase6Fixtures.old_grave_record("old_01"), Phase6Fixtures.old_grave("old_01"),
			1, 0, inv, y, cfg, true), OssuaryRules.TEXT_REST)
	assert_eq(OssuaryRules.lift_block_reason(g, d, 0, 0, inv, y, cfg, true), OssuaryRules.TEXT_BURIED, "crypt 0")
	assert_eq(OssuaryRules.lift_block_reason(g, d, 1, 3, inv, y, cfg, true), OssuaryRules.TEXT_FULL)
	assert_eq(OssuaryRules.lift_block_reason(g, d, 2, 3, inv, y, cfg, true), "", "crypt 2: 5 places")
	var none := Phase6Fixtures.inv_with()
	assert_eq(OssuaryRules.lift_block_reason(g, d, 1, 0, none, y, cfg, true), OssuaryRules.TEXT_NO_BOX)
	none.free()
	assert_eq(OssuaryRules.lift_block_reason(g, d, 1, 0, inv, y, cfg, true), "")


func test_lift_minutes_follow_the_shovel() -> void:
	var actions := load(ACTIONS) as ActionConfig
	var out: Array = []
	for tier: int in [0, 1, 2]:
		var i := Phase6Fixtures.inv_with({}, {&"shovel": tier})
		out.append(OssuaryRules.lift_minutes(cfg, actions, i))
		out.append(ossuary.lift_minutes(i, actions))
		i.free()
	assert_eq(out, [60, 60, 50, 50, 35, 35], "§1.3: 60 / 50 / 35")


# --- lifting ----------------------------------------------------------------------------------

func test_lift_turns_old_into_empty() -> void:
	var free_before := graveyard.free_plot_count()
	assert_true(ossuary.lift("old_04", inv))
	assert_eq(graveyard.get_grave("old_04").state, EMPTY)
	assert_eq([inv.count(&"bone_box"), inv.count(&"bone_box_full")], [2, 1])
	assert_eq(graveyard.free_plot_count(), free_before + 1, "delivery rule: one more free place")
	assert_eq(events, [["state", "old_04", EMPTY], ["lifted", "old_04"]])
	assert_eq(GameState.get_stat(&"bones_lifted"), 1)
	assert_eq([ossuary.used(), ossuary.pending(), ossuary.reinterred()], [1, PackedStringArray(["old_04"]), PackedStringArray()])
	assert_false(ossuary.lift("old_04", inv), "already lifted")
	assert_eq(ossuary.lift_block_reason("old_04", inv), OssuaryRules.TEXT_NOT_OLD)
	assert_eq(graveyard.total_quality(), 0, "old_grave_quality 0: lifting costs no quality")


func test_lift_needs_box_crypt_open_and_rest() -> void:
	var none := Phase6Fixtures.inv_with()
	assert_false(ossuary.lift("old_04", none), "no box")
	none.free()
	assert_false(ossuary.lift("old_01", inv), "rest period")
	assert_false(ossuary.lift("old_08", inv), "rest period")
	assert_false(ossuary.lift("plot_01", inv), "no old grave")
	_crypt(0)
	assert_eq(ossuary.lift_block_reason("old_04", inv), OssuaryRules.TEXT_BURIED)
	assert_false(ossuary.lift("old_04", inv))
	_crypt(1)
	GameState.clear_flag(&"buildings_open")
	assert_false(ossuary.lift("old_04", inv), "not open")
	assert_eq(graveyard.get_grave("old_04").state, OLD)
	assert_eq([inv.count(&"bone_box"), ossuary.used(), events], [3, 0, []], "nothing changed")


func test_full_ossuary_until_the_crypt_grows() -> void:
	inv.add_item(&"bone_box", 5)
	for id: String in ["old_02", "old_03", "old_04"]:
		assert_true(ossuary.lift(id, inv), id)
	assert_eq(ossuary.lift_block_reason("old_05", inv), OssuaryRules.TEXT_FULL)
	ossuary.reinter(inv)
	assert_eq(ossuary.lift_block_reason("old_05", inv), OssuaryRules.TEXT_FULL, "reinterred still occupies a place")
	_crypt(2)
	assert_true(ossuary.lift("old_05", inv))
	assert_true(ossuary.lift("old_06", inv))
	assert_eq(ossuary.lift_block_reason("old_07", inv), OssuaryRules.TEXT_FULL)
	_crypt(3)
	assert_true(ossuary.lift("old_07", inv))
	assert_eq(ossuary.used(), 6)


# --- reinterment ------------------------------------------------------------------------------

func test_reinter_is_fifo_and_pays_once() -> void:
	for id: String in ["old_06", "old_04", "old_07"]:
		ossuary.lift(id, inv)
	events.clear()
	assert_eq(ossuary.reinter(inv), "old_06", "oldest lifting first")
	assert_eq(ossuary.reinter(inv), "old_04")
	assert_eq(ossuary.pending(), PackedStringArray(["old_07"]))
	assert_eq(ossuary.reinterred(), PackedStringArray(["old_06", "old_04"]))
	assert_eq(inv.count(&"coin"), 2 * cfg.reinter_fee, "4 coins each")
	assert_eq(inv.count(&"bone_box_full"), 1)
	assert_eq(events, [["payment", 4, "Umbettung von Hanne Sörgel"], ["reinterred", "old_06", 1],
			["payment", 4, "Umbettung von Barbe Lindt"], ["reinterred", "old_04", 2]])
	assert_eq(rep.calls, [[&"reinterred", "Hanne Sörgel umgebettet"], [&"reinterred", "Barbe Lindt umgebettet"]])
	assert_eq(piety.calls.size(), 2)
	assert_has(notes, "Hanne Sörgel. Das Kreuz war morsch, die Knochen nicht.")
	assert_eq(GameState.get_stat(&"bones_reinterred"), 2)
	assert_eq(buildings.goal_checks, 2, "Buildings.check_goal per reinterment")
	assert_eq(ossuary.used(), 3)


func test_reinter_needs_a_filled_box_and_a_pending_grave() -> void:
	assert_eq(ossuary.reinter(inv), "", "nothing lifted")
	ossuary.lift("old_02", inv)
	inv.remove_item(&"bone_box_full", 1)
	assert_eq(ossuary.reinter(inv), "", "box elsewhere")
	inv.add_item(&"bone_box_full", 2)
	assert_eq(ossuary.reinter(inv), "old_02")
	assert_eq(ossuary.reinter(inv), "", "nothing pending – the spare box stays")
	assert_eq([inv.count(&"bone_box_full"), inv.count(&"coin"), rep.calls.size(), piety.calls.size()], [1, 4, 1, 1], "once")


# --- passage ----------------------------------------------------------------------------------

func test_passage_per_crypt_level() -> void:
	var states: Array = []
	for level: int in [0, 1, 2, 3, 1]:
		ossuary.on_crypt_level(level)
		states.append(ossuary.passage_state())
	assert_eq(states, [&"hidden", &"hidden", &"sealed", &"grille", &"grille"], "never back")


func test_look_at_passage_gives_the_clue_once() -> void:
	ossuary.look_at_passage()
	assert_eq([journal.added, notes], [[], []], "hidden: nothing")
	ossuary.on_crypt_level(2)
	ossuary.look_at_passage()
	ossuary.look_at_passage()
	assert_eq(journal.added, [&"c_crypt_draft"], "clue once")
	assert_eq(notes, [Ossuary.TEXT_PASSAGE_SEALED, Ossuary.TEXT_PASSAGE_SEALED])
	assert_true(GameState.has_flag(&"c_crypt_draft_seen"))
	ossuary.on_crypt_level(3)
	ossuary.look_at_passage()
	assert_eq(notes.back(), Ossuary.TEXT_PASSAGE_GRILLE)
	assert_eq(journal.added.size(), 1, "no clue at the grille")


func test_grille_gives_the_clue_when_the_door_was_skipped() -> void:
	ossuary.on_crypt_level(3)
	ossuary.look_at_passage()
	assert_eq(journal.added, [&"c_crypt_draft"])


func test_real_journal_takes_the_clue() -> void:
	journal.remove_from_group(&"journal")
	var real := JournalManager.new()
	world.add_child(real)
	ossuary.on_crypt_level(2)
	ossuary.look_at_passage()
	assert_true(real.has_clue(&"c_crypt_draft"))
	assert_true(GameState.has_flag(&"clue_c_crypt_draft"))


# --- save / load ------------------------------------------------------------------------------

func test_save_load_round_trip() -> void:
	for id: String in ["old_04", "old_06", "old_07"]:
		ossuary.lift(id, inv)
	ossuary.reinter(inv)
	ossuary.reinter(inv)
	ossuary.on_crypt_level(2)
	var saved := ossuary.save_state()
	assert_eq(saved, {"lifted": ["old_04", "old_06", "old_07"], "reinterred": ["old_04", "old_06"], "passage": "sealed"}, "§5.1")
	var other := Ossuary.new()
	other.old_grave_data = Phase6Fixtures.old_graves()
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.save_state(), saved)
	assert_eq([other.pending(), other.used(), other.passage_state()], [PackedStringArray(["old_07"]), 3, &"sealed"])
	other.load_state({})
	assert_eq(other.save_state(), {"lifted": [], "reinterred": [], "passage": "hidden"})
	other.free()


func test_load_is_tolerant() -> void:
	ossuary.load_state({"lifted": ["old_04", 7, "old_04", "old_99", "plot_01", "old_01", "old_06", null], "reinterred": ["old_06", "old_04"],
			"passage": "open"})
	assert_eq(ossuary.save_state(), {"lifted": ["old_04", "old_06"], "reinterred": ["old_04", "old_06"], "passage": "hidden"})
	ossuary.load_state({"lifted": ["old_04", "old_06"], "reinterred": ["old_06"], "passage": "grille"})
	assert_eq(ossuary.reinterred(), PackedStringArray(), "reinterred must be a prefix of lifted (FIFO)")
	assert_eq(ossuary.passage_state(), &"grille")
	ossuary.load_state({"lifted": "junk", "reinterred": 3})
	assert_eq(ossuary.used(), 0)


func test_saveable_contract() -> void:
	assert_true(ossuary.is_in_group(&"ossuary") and ossuary.is_in_group(&"saveable"))
	assert_eq([ossuary.save_id, ossuary.save_order], ["ossuary", 36])


# --- real data ----------------------------------------------------------------------------------

func test_real_old_graves_match_the_contract() -> void:
	var ids: Array = []
	for res: Resource in Database.old_graves():
		var g := res as OldGraveData
		ids.append(g.grave_id)
		var f := Phase6Fixtures.old_grave(g.grave_id)
		assert_eq([g.display_name, g.born_year, g.died_year, g.reinter_line], [f.display_name, f.born_year, f.died_year,
				f.reinter_line], g.grave_id)
		assert_not_null(g.stone_model, g.grave_id)
		assert_eq(g.reinter_line == "", not OssuaryRules.liftable(g, Phase6Fixtures.YEAR, cfg), g.grave_id + ": a line iff liftable")
	assert_eq(ids, Array(Phase6Fixtures.OLD_GRAVE_IDS))


func test_real_items_recipe_and_clue() -> void:
	for id: StringName in [&"bone_box", &"bone_box_full"]:
		var item := Database.item(id) as ItemData
		var f := Phase6Fixtures.item(id)
		assert_eq([item.display_name, item.category, item.max_stack], [f.display_name, f.category, f.max_stack], String(id))
		assert_true(item.description.length() >= 20, String(id))
	var r := Database.recipe(&"bone_box") as RecipeData
	assert_eq([r.inputs, r.output_id, r.output_amount, r.craft_minutes, r.station],
			[{&"wood": 3}, &"bone_box", 1, 15, &"workbench"])
	var c := Database.clue(&"c_crypt_draft") as ClueData
	assert_eq([c.title, c.kind, c.order], ["Der kalte Zug", &"place", 20])
	assert_true(c.text.begins_with(Phase6Fixtures.clue(&"c_crypt_draft").text), "§2.3 text")
	assert_true(c.text.contains("Unter dem Birkenhang ist es nicht still."), "margin note (W0 note 11)")


# --- OssuaryShelf -------------------------------------------------------------------------------

func test_shelf_prompts_and_reinter() -> void:
	var shelf := (load(SHELF_SCENE) as PackedScene).instantiate() as OssuaryShelf
	world.add_child(shelf)
	var player := _player()
	assert_eq(shelf.get_interaction_prompt(player), "Beinhaus – 0 von 3 Plätzen belegt")
	assert_false(shelf.can_interact(player))
	ossuary.lift("old_04", player.inventory)
	ossuary.lift("old_02", player.inventory)
	assert_eq(shelf.get_interaction_prompt(player), "[E] Gebeine beisetzen (20 Min) – 2 Kisten warten")
	assert_true(shelf.can_interact(player))
	shelf.interact(player)
	assert_eq(ossuary.reinterred(), PackedStringArray(["old_04"]))
	assert_eq(shelf.get_interaction_prompt(player), "[E] Gebeine beisetzen (20 Min) – 1 Kiste wartet")
	player.inventory.remove_item(&"bone_box_full", 1)
	assert_eq(shelf.get_interaction_prompt(player), OssuaryShelf.PROMPT_NO_BOX)
	assert_false(shelf.can_interact(player))


func test_shelf_shows_boxes_stones_and_name_board() -> void:
	var shelf := (load(SHELF_SCENE) as PackedScene).instantiate() as OssuaryShelf
	world.add_child(shelf)
	for id: String in ["old_07", "old_03"]:
		ossuary.lift(id, inv)
		ossuary.reinter(inv)
	ossuary.lift("old_02", inv)
	shelf.refresh()
	assert_eq([shelf.shown_boxes(), shelf.shown_stones()], [2, PackedStringArray(["old_07", "old_03"])], "per reinterred grave")
	var stone := shelf.get_node("OldStones").get_child(0) as Node3D
	assert_eq(stone.scene_file_path, "res://assets/models/props/ph_prop_gravestone_slab_old.glb", "the grave's own old stone")
	assert_almost(stone.transform.basis.get_scale().x, 0.9, 0.001, "0.9 ×")
	assert_eq(shelf.name_board_lines(), PackedStringArray(), "name board from crypt 3")
	_crypt(3)
	shelf.refresh()
	assert_eq(shelf.name_board_lines(), PackedStringArray(["Elias Brand, Totengräber (1690–1751)",
			"Konrad Pfister, Ratsherr (1702–1771)"]))


# --- SealedPassage ------------------------------------------------------------------------------

func test_passage_entity_per_state() -> void:
	var passage := (load(PASSAGE_SCENE) as PackedScene).instantiate() as SealedPassage
	world.add_child(passage)
	var player := _player()
	assert_false(passage.visible)
	assert_eq(passage.get_interaction_prompt(player), "")
	assert_false(passage.can_interact(player))
	ossuary.on_crypt_level(2)
	passage.refresh()
	assert_true(passage.visible)
	assert_false(passage.light.visible, "no light before the grille")
	assert_eq(passage.get_interaction_prompt(player), SealedPassage.PROMPT_LOOK)
	passage.interact(player)
	assert_eq(journal.added, [&"c_crypt_draft"])
	ossuary.on_crypt_level(3)
	passage.refresh()
	assert_eq(passage.get_interaction_prompt(player), SealedPassage.PROMPT_GRILLE)
	assert_true(passage.light.visible)
	assert_eq([passage.light.light_color, passage.light.omni_range, passage.light.shadow_enabled],
			[Color("7FA0C8"), 2.5, false], "§2.3 cold light")
	assert_almost(passage.light.light_energy, 0.25, 0.06)
	passage.interact(player)
	assert_eq(notes.back(), Ossuary.TEXT_PASSAGE_GRILLE)
	assert_eq(journal.added.size(), 1)


# --- helpers ------------------------------------------------------------------------------------

func _crypt(level: int) -> void:
	buildings.load_state({"levels": {"crypt": level}})


func _plot(id: String, old: bool) -> PlotDouble:
	var p := PlotDouble.new()
	p.grave_id = id
	p.is_old = old
	p.add_to_group(&"grave_plot")
	return p


func _player() -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := Phase6Fixtures.inv_with({&"bone_box": 3})
	fake.name = "Inventory"
	player.add_child(fake)
	player.instant_actions = true
	world.add_child(player)
	return player


func _on_state(id: String, state: int) -> void:
	events.append(["state", id, state])


func _on_lifted(id: String) -> void:
	events.append(["lifted", id])


func _on_reinterred(id: String, count: int) -> void:
	events.append(["reinterred", id, count])


func _on_payment(amount: int, reason: String) -> void:
	events.append(["payment", amount, reason])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
