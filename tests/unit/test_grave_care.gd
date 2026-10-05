extends TestCase
## P2 (docs/PHASE8_DESIGN.md §2.3, §3.4, §4.9, §5.1, §10): GraveCare – grave flowers fresh 2 days / wilted
## until day 4 / gone, watering and the can's fillings, the rain barrel, the bouquet (2 days, no stacking),
## the wax wreath (ghost +0), candles 15:00–07:00 and lit_last_night, the mortsafe (≥ 10 days, reusable), the
## disturbed grave and closing it, the care bonus (≤ 2, the night of the lights +2, disturbed −3), the pool of
## candle lights, save / load. GraveCareRules as pure functions. Real Graveyard, fake inventory.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")

## Records the CleanlinessManager.set_level calls (P3 fills the real one).
class CleanDouble extends Node:
	var levels: Dictionary = {}

	func _init() -> void:
		add_to_group(&"cleanliness")

	func set_level(spot_id: String, level: int) -> void:
		levels[spot_id] = level

	func level(spot_id: String) -> int:
		return int(levels.get(spot_id, 0))


var cfg: GraveCareConfig
var graveyard: Graveyard
var care: GraveCare
var inv: Inventory
var changes: Array = []


func before_each() -> void:
	cfg = Phase8Fixtures.grave_care_config()
	GameState.reset()
	TimeManager.load_state({"day": 55, "minute_of_day": 600})
	graveyard = Graveyard.new()
	tree.root.add_child(graveyard)
	var graves: Array = []
	for spec: Array in [["l_09", GraveRecord.State.MARKED], ["l_10", GraveRecord.State.FILLED], ["l_11", GraveRecord.State.EMPTY],
			["l_12", GraveRecord.State.DUG]]:
		var g := GraveRecord.new()
		g.id = spec[0]
		g.state = spec[1]
		g.corpse_id = "c_" + String(spec[0]) if spec[1] in [GraveRecord.State.MARKED, GraveRecord.State.FILLED] else ""
		graves.append(g.to_dict())
	graveyard.load_state({"graves": graves})
	care = GraveCare.new()
	care.config = cfg
	tree.root.add_child(care)
	inv = FakeInventory.new()
	changes.clear()
	EventBus.grave_care_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.grave_care_changed.disconnect(_on_changed)
	GameState.reset()


func _on_changed(grave_id: String, kind: StringName, active: bool) -> void:
	changes.append([grave_id, kind, active])


# --- rules ---------------------------------------------------------------------------------------

func test_rules_flowers_by_minutes_since_watering() -> void:
	var e := {"planted": 1000, "watered": 1000, "wreath": false}
	assert_eq(GraveCareRules.flowers_state(e, 1000, cfg), &"fresh")
	assert_eq(GraveCareRules.flowers_state(e, 1000 + 2879, cfg), &"fresh", "fresh 2 days")
	assert_eq(GraveCareRules.flowers_state(e, 1000 + 2880, cfg), &"wilted")
	assert_eq(GraveCareRules.flowers_state(e, 1000 + 5759, cfg), &"wilted", "wilted until day 4")
	assert_eq(GraveCareRules.flowers_state(e, 1000 + 5760, cfg), &"", "then gone")
	assert_eq(GraveCareRules.flowers_state({"planted": 0, "watered": 0, "wreath": true}, 99999, cfg), &"wreath", "never wilts")
	assert_eq(GraveCareRules.flowers_state({}, 0, cfg), &"")


func test_rules_candle_window_and_night() -> void:
	assert_false(GraveCareRules.may_light_at(899, cfg), "14:59")
	assert_true(GraveCareRules.may_light_at(900, cfg), "15:00")
	assert_true(GraveCareRules.may_light_at(1439, cfg))
	assert_true(GraveCareRules.may_light_at(100, cfg), "after midnight")
	assert_false(GraveCareRules.may_light_at(420, cfg), "07:00")
	var lit := 54 * 1440 + 960  # day 55, 16:00
	assert_eq(GraveCareRules.candle_out_total(lit, cfg), 55 * 1440 + 420, "until 07:00 next morning")
	assert_eq(GraveCareRules.candle_out_total(54 * 1440 + 120, cfg), 54 * 1440 + 420, "lit at 02:00: same morning")
	assert_true(GraveCareRules.candle_burning(lit, 55 * 1440 + 419, cfg))
	assert_false(GraveCareRules.candle_burning(lit, 55 * 1440 + 420, cfg))
	assert_eq(GraveCareRules.night_of(lit), 55)
	assert_eq(GraveCareRules.night_of(55 * 1440 + 120), 55, "02:00 of day 56 belongs to night 55")


func test_rules_care_bonus_capped() -> void:
	assert_eq(GraveCareRules.care_bonus(&"fresh", false, false, false, false, cfg), 1)
	assert_eq(GraveCareRules.care_bonus(&"fresh", true, false, false, false, cfg), 1, "flowers and bouquet do not stack")
	assert_eq(GraveCareRules.care_bonus(&"", true, true, false, false, cfg), 2)
	assert_eq(GraveCareRules.care_bonus(&"wreath", false, false, false, false, cfg), 0, "wax smells of nothing")
	assert_eq(GraveCareRules.care_bonus(&"wilted", false, true, false, false, cfg), 1)
	assert_eq(GraveCareRules.care_bonus(&"", false, true, true, false, cfg), 2, "the night of the lights +2")
	assert_eq(GraveCareRules.care_bonus(&"fresh", false, true, true, false, cfg), 2, "≤ care_cap")
	assert_eq(GraveCareRules.care_bonus(&"fresh", false, true, false, true, cfg), -1, "disturbed −3 on top")


# --- flowers -------------------------------------------------------------------------------------

func test_plant_needs_a_dead_and_a_seedling() -> void:
	assert_eq(care.plant_block_reason("l_09", inv), GraveCare.TEXT_NO_SEEDLINGS)
	inv.add_item(&"flower_seedlings", 3)
	assert_eq(care.plant_block_reason("l_11", inv), GraveCare.TEXT_NOT_HERE, "EMPTY")
	assert_eq(care.plant_block_reason("l_12", inv), GraveCare.TEXT_NOT_HERE, "DUG")
	assert_eq(care.plant_block_reason("l_10", inv), "", "FILLED")
	assert_true(care.plant("l_09", inv))
	assert_eq(inv.count(&"flower_seedlings"), 2)
	assert_eq(care.flowers_state("l_09"), &"fresh")
	assert_eq(care.plant_block_reason("l_09", inv), GraveCare.TEXT_HAS_FLOWERS)
	assert_false(care.plant("l_09", inv))
	assert_eq(GameState.get_stat(&"flowers_planted"), 1)
	assert_eq(changes, [["l_09", &"flowers", true]])


func test_flowers_wilt_and_go_by_the_clock() -> void:
	inv.add_item(&"flower_seedlings", 1)
	care.plant("l_09", inv)
	TimeManager.advance(2880)
	assert_eq(care.flowers_state("l_09"), &"wilted")
	TimeManager.advance(2879)
	assert_eq(care.flowers_state("l_09"), &"wilted")
	changes.clear()
	TimeManager.advance(1)
	assert_eq(care.flowers_state("l_09"), &"")
	assert_eq(changes, [["l_09", &"flowers", false]], "gone → signal")
	assert_false(care.save_state().flowers.has("l_09"))


func test_watering_uses_fillings_and_freshens() -> void:
	inv.add_item(&"flower_seedlings", 1)
	care.plant("l_09", inv)
	assert_eq(care.can_fill(), 0, "a new can is empty")
	assert_eq(care.water_block_reason("l_09"), GraveCare.TEXT_CAN_EMPTY)
	assert_false(care.water("l_09"))
	care.refill()
	assert_eq(care.can_fill(), 6, "6 fillings")
	TimeManager.advance(3000)
	assert_eq(care.flowers_state("l_09"), &"wilted")
	assert_true(care.water("l_09"))
	assert_eq(care.flowers_state("l_09"), &"fresh", "watering sets fresh")
	assert_eq(care.can_fill(), 5)
	assert_eq(care.water_block_reason("l_10"), GraveCare.TEXT_NO_FLOWERS)
	for i: int in 5:
		assert_true(care.water("l_09"), "filling %d" % i)
	assert_eq(care.can_fill(), 0)
	assert_false(care.water("l_09"), "empty can")
	assert_eq(care.can_fill(&"apprentice"), 0, "the apprentice has his own can")
	care.refill(&"apprentice")
	assert_true(care.water("l_09", true))
	assert_eq([care.can_fill(), care.can_fill(&"apprentice")], [0, 5])


func test_wreath_never_wilts_and_gives_no_ghost_bonus() -> void:
	inv.add_item(&"wax_wreath", 1)
	assert_true(care.lay_wreath("l_09", inv))
	assert_eq(inv.count(&"wax_wreath"), 0)
	TimeManager.advance(20000)
	assert_eq(care.flowers_state("l_09"), &"wreath")
	assert_eq(care.care_bonus("l_09"), 0, "ghost +0")
	care.refill()
	assert_false(care.water("l_09"), "nothing to water")


func test_bouquet_two_days_without_stacking() -> void:
	care.place_bouquet("l_09")
	assert_true(care.bouquet_fresh("l_09"))
	assert_eq(care.care_bonus("l_09"), 1)
	inv.add_item(&"flower_seedlings", 1)
	care.plant("l_09", inv)
	assert_eq(care.care_bonus("l_09"), 1, "not on top of grave flowers")
	TimeManager.advance(2000)
	care.place_bouquet("l_09")
	TimeManager.advance(2000)
	assert_true(care.bouquet_fresh("l_09"), "a new bouquet replaces the old one")
	TimeManager.advance(880)
	assert_false(care.bouquet_fresh("l_09"), "2 days")


func test_apprentice_mistakes_wilt_and_pull() -> void:
	inv.add_item(&"flower_seedlings", 2)
	care.plant("l_09", inv)
	care.wilt_now("l_09")
	assert_eq(care.flowers_state("l_09"), &"wilted")
	care.plant("l_10", inv)
	care.remove_flowers("l_10")
	assert_eq(care.flowers_state("l_10"), &"")


# --- candles -------------------------------------------------------------------------------------

func test_candle_from_three_until_seven() -> void:
	inv.add_item(&"grave_candle", 2)
	assert_eq(care.light_block_reason("l_09", inv), GraveCare.TEXT_TOO_EARLY, "10:00")
	assert_false(care.light("l_09", inv))
	TimeManager.set_time(55, 900)
	assert_eq(care.light_block_reason("l_11", inv), GraveCare.TEXT_NOT_HERE)
	assert_true(care.light("l_09", inv))
	assert_eq(inv.count(&"grave_candle"), 1)
	assert_true(care.candle_lit("l_09"))
	assert_eq(care.light_block_reason("l_09", inv), GraveCare.TEXT_CANDLE_BURNS)
	assert_eq(care.care_bonus("l_09"), 1)
	assert_true(care.lit_last_night("l_09"), "tonight counts")
	assert_eq(care.last_lit_night("l_09"), 55)
	assert_eq(care.lit_graves(), PackedStringArray(["l_09"]))
	assert_eq(GameState.get_stat(&"candles_lit"), 1)
	changes.clear()
	TimeManager.set_time(56, 419)
	assert_true(care.candle_lit("l_09"), "06:59")
	TimeManager.advance(1)
	assert_false(care.candle_lit("l_09"), "out at 07:00")
	assert_eq(changes, [["l_09", &"candle", false]])
	assert_true(care.lit_last_night("l_09"), "the day after")
	TimeManager.set_time(57, 600)
	assert_false(care.lit_last_night("l_09"), "two days later")
	assert_eq(care.last_lit_night("l_09"), 55, "the wish remembers the night")


func test_lights_night_candle_plus_two() -> void:
	GameState.set_flag(&"fest_lights_day", 55)
	TimeManager.set_time(55, 1000)
	assert_true(care.light_free("l_09"))
	assert_eq(care.care_bonus("l_09"), 2)
	TimeManager.set_time(56, 200)
	assert_eq(care.care_bonus("l_09"), 2, "still the night of the lights")


func test_candle_pool_lights_nearest() -> void:
	var ids: Array = []
	var graves: Array = []
	for i: int in 8:
		var id := "p_%d" % i
		ids.append(id)
		var g := GraveRecord.new()
		g.id = id
		g.state = GraveRecord.State.MARKED
		g.corpse_id = "c" + id
		graves.append(g.to_dict())
		var plot := PlotDouble.new()
		plot.grave_id = id
		tree.root.add_child(plot)
		plot.position = Vector3(i * 3.0, 0, 0)
	graveyard.load_state({"graves": graves})
	TimeManager.set_time(56, 1000)
	for id: String in ids:
		care.light_free(id)
	care.update_light_pool()
	assert_eq(care.active_lights(), 6, "pool of 6")
	var lit_x: Array = []
	for c: Node in care.get_children():
		if c is OmniLight3D and (c as OmniLight3D).visible:
			assert_false((c as OmniLight3D).shadow_enabled, "no shadows")
			lit_x.append(roundi((c as OmniLight3D).global_position.x - GraveCare.CANDLE_OFFSET.x))
	lit_x.sort()
	assert_eq(lit_x, [0, 3, 6, 9, 12, 15], "nearest to the focus (origin)")
	TimeManager.set_time(57, 430)
	care.update_light_pool()
	assert_eq(care.active_lights(), 0, "out at 07:00")


class PlotDouble extends Node3D:
	var grave_id: String = ""

	func _init() -> void:
		add_to_group(&"grave_plot")


# --- mortsafe ------------------------------------------------------------------------------------

func test_mortsafe_ten_days_and_reusable() -> void:
	assert_eq(care.mortsafe_block_reason("l_10", true, inv), GraveCare.TEXT_NO_MORTSAFE)
	inv.add_item(&"mortsafe", 1)
	assert_true(care.set_mortsafe("l_10", true, inv))
	assert_true(care.has_mortsafe("l_10"))
	assert_eq(inv.count(&"mortsafe"), 0)
	assert_eq(GameState.get_stat(&"mortsafes_set"), 1)
	assert_eq(care.mortsafe_block_reason("l_10", false, inv), GraveCare.TEXT_MORTSAFE_DAYS % 10)
	assert_false(care.set_mortsafe("l_10", false, inv))
	TimeManager.advance(9 * 1440)
	assert_eq(care.mortsafe_days("l_10"), 9)
	assert_false(care.set_mortsafe("l_10", false, inv), "9 days")
	TimeManager.advance(1440)
	assert_true(care.set_mortsafe("l_10", false, inv), "10 days")
	assert_eq(inv.count(&"mortsafe"), 1, "back in the pack")
	assert_false(care.has_mortsafe("l_10"))
	assert_eq(care.mortsafe_block_reason("l_11", true, inv), GraveCare.TEXT_NOT_HERE, "no mortsafe on an empty grave")


# --- disturbed -----------------------------------------------------------------------------------

func test_disturbed_and_closing() -> void:
	var clean := CleanDouble.new()
	tree.root.add_child(clean)
	inv.add_item(&"flower_seedlings", 1)
	care.plant("l_09", inv)
	care.set_disturbed("l_09")
	assert_true(care.is_disturbed("l_09"))
	assert_true(graveyard.get_grave("l_09").disturbed, "GraveRecord.disturbed")
	assert_eq(graveyard.get_grave("l_09").state, GraveRecord.State.MARKED, "the dead stays in the grave")
	assert_eq(graveyard.get_grave("l_09").corpse_id, "c_l_09")
	assert_eq(clean.levels.get("dirt_l_09"), 3, "care spot level 3")
	assert_eq(care.flowers_state("l_09"), &"", "trodden")
	assert_eq(care.care_bonus("l_09"), -3)
	assert_eq(care.plant_block_reason("l_09", inv), GraveCare.TEXT_DISTURBED)
	assert_eq(GameState.get_stat(&"graves_disturbed"), 1)
	care.set_disturbed("l_11")
	assert_false(care.is_disturbed("l_11"), "only an occupied grave")
	assert_true(care.close_disturbed("l_09"))
	assert_false(care.is_disturbed("l_09"))
	assert_false(graveyard.get_grave("l_09").disturbed)
	assert_false(care.close_disturbed("l_09"))
	assert_eq(GameState.get_stat(&"graves_closed"), 1)
	assert_has(changes, ["l_09", &"disturbed", true])
	assert_has(changes, ["l_09", &"disturbed", false])


# --- save / load ---------------------------------------------------------------------------------

func test_save_load_roundtrip_by_the_clock() -> void:
	inv.add_item(&"flower_seedlings", 1)
	inv.add_item(&"mortsafe", 1)
	care.plant("l_09", inv)
	care.place_bouquet("l_10")
	care.set_mortsafe("l_10", true, inv)
	care.refill()
	care.water("l_09")
	TimeManager.set_time(55, 1000)
	care.light_free("l_10")
	care.set_disturbed("l_09")
	var state := care.save_state()
	assert_eq(state.keys(), ["flowers", "bouquets", "candles", "lit_nights", "mortsafes", "disturbed", "can_fill", "light_pool"])
	var json: Variant = JSON.parse_string(JSON.stringify(state))
	var other := GraveCare.new()
	other.config = cfg
	tree.root.add_child(other)
	other.load_state(json)
	assert_eq(other.save_state(), state, "identical after JSON")
	assert_true(other.candle_lit("l_10"))
	assert_true(other.has_mortsafe("l_10"))
	assert_true(other.bouquet_fresh("l_10"))
	assert_eq(other.can_fill(), 5)
	assert_true(other.is_disturbed("l_09"))
	other.load_state({"flowers": {"x": "bad", "l_10": {"planted": 1.0e3}}, "candles": [1], "can_fill": {"player": 99},
			"disturbed": "nope"})
	assert_eq(other.can_fill(), 6, "clamped")
	assert_eq(other.save_state().flowers.keys(), [], "an entry withered long ago is dropped")
	other.queue_free()
	await wait_frames(1)


func test_stub_free_and_state_empty() -> void:
	assert_false(FileAccess.get_file_as_string("res://src/systems/grave_care/grave_care.gd").contains("## STUB ("))
	assert_false(FileAccess.get_file_as_string("res://src/systems/grave_care/grave_care_rules.gd").contains("## STUB ("))
	var fresh := GraveCare.new()
	assert_eq(fresh.save_state().flowers, {})
	fresh.free()


# --- GravePlot prompts, TipStone, RainBarrel (§1.3, §3.4, §7.5) ------------------------------------

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const PLOT_SCENE := "res://src/entities/grave/grave_plot.tscn"
const ACTIONS := "res://tests/fixtures/phase5/action_config_fixture.tres"


func _plot_world() -> Dictionary:
	var plot := (load(PLOT_SCENE) as PackedScene).instantiate() as GravePlot
	plot.grave_id = "l_09"
	tree.root.add_child(plot)
	var state := graveyard.save_state()
	graveyard.load_state(state)
	var corpses := CorpseManager.new()
	tree.root.add_child(corpses)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	player.actions = load(ACTIONS) as ActionConfig
	player.instant_actions = true
	player.position = Vector3(0, 0, 5)
	tree.root.add_child(player)
	await wait_frames(2)
	return {"plot": plot, "player": player, "inv": fake, "corpses": corpses}


func test_grave_plot_care_prompts_in_order() -> void:
	var w: Dictionary = await _plot_world()
	var plot: GravePlot = w.plot
	var player: Player = w.player
	var pinv: Inventory = w.inv
	assert_eq(plot.get_interaction_prompt(player).begins_with("Grab von"), true, "nothing to do: the info line")
	assert_false(plot.can_interact(player))
	pinv.add_item(&"flower_seedlings", 1)
	pinv.add_item(&"grave_candle", 1)
	assert_eq(plot.get_interaction_prompt(player), "[E] Grabblumen setzen (15 Min)", "flowers before the candle")
	plot.interact(player)
	await wait_frames(1)
	assert_eq(care.flowers_state("l_09"), &"fresh")
	assert_eq(plot.get_interaction_prompt(player), "Erst am Nachmittag.", "the candle dimmed before 15:00")
	assert_false(plot.can_interact(player))
	TimeManager.set_time(55, 960)
	assert_eq(plot.get_interaction_prompt(player), "[E] Grabkerze anzünden (3 Min)")
	plot.interact(player)
	await wait_frames(1)
	assert_true(care.candle_lit("l_09"))
	assert_eq(pinv.count(&"grave_candle"), 0)
	assert_not_null(plot.get_node_or_null(^"CareVisual/Candle"), "the candle shows")
	assert_not_null(plot.get_node_or_null(^"CareVisual/Flowers"))
	pinv.add_item(&"watering_can", 1)
	TimeManager.advance(1500)
	assert_eq(plot.get_interaction_prompt(player), "Die Gießkanne ist leer.", "wilting soon: water – the can is empty")
	care.refill()
	assert_eq(plot.get_interaction_prompt(player), "[E] Blumen gießen (5 Min)")
	plot.interact(player)
	await wait_frames(1)
	assert_eq(care.can_fill(), 5)
	pinv.add_item(&"mortsafe", 1)
	assert_eq(plot.get_interaction_prompt(player), "[E] Grabgitter aufsetzen (20 Min)")
	plot.interact(player)
	await wait_frames(1)
	assert_true(care.has_mortsafe("l_09"))
	assert_not_null(plot.get_node_or_null(^"CareVisual/Mortsafe"))
	assert_eq(plot.get_interaction_prompt(player), GraveCare.TEXT_MORTSAFE_DAYS % 10, "off only after 10 days (dimmed)")
	care.set_disturbed("l_09")
	assert_eq(plot.get_interaction_prompt(player), "[E] Grab wieder schließen (30 Min)", "closing first")
	plot.interact(player)
	await wait_frames(1)
	assert_false(care.is_disturbed("l_09"))
	(w.player as Node).queue_free()
	plot.queue_free()
	(w.corpses as Node).queue_free()
	await wait_frames(1)


func test_grave_plot_line_wish_and_coins_on_the_stone() -> void:
	var w: Dictionary = await _plot_world()
	var plot: GravePlot = w.plot
	var player: Player = w.player
	var pinv: Inventory = w.inv
	graveyard.get_grave("l_09").design = {"shape": "stone_round", "inscription": "", "ornament": "", "gilded": false,
			"text": ["Hedwig Lamprecht", "1790 – 1834"]}
	var visitors := Phase8Fixtures.wish_open("l_09", &"line", tree)
	var state := visitors.save_state()
	state.wishes[0]["template"] = "w_line_1"
	state.tips_on_stone = {"l_09": [2, "kin_kehr"]}
	visitors.load_state(state)
	assert_eq(plot.get_interaction_prompt(player), "[E] 2 Münzen auf dem Stein (Martha Kehr)", "coins first (no TipStone child)")
	plot.interact(player)
	assert_eq(pinv.count(&"coin"), 2)
	assert_eq(plot.get_interaction_prompt(player), "Für die Zeile fehlt Tinte.")
	pinv.add_item(&"ink", 1)
	assert_eq(plot.get_interaction_prompt(player), "[E] Zeile nachmeißeln: ‚Ruhe sanft' (30 Min)")
	plot.interact(player)
	await wait_frames(1)
	assert_eq(graveyard.get_grave("l_09").extra_lines, PackedStringArray(["Ruhe sanft"]))
	assert_eq(pinv.count(&"ink"), 0)
	assert_eq(plot.extra_lines, PackedStringArray(["Ruhe sanft"]), "the stone shows the new line")
	visitors.queue_free()
	(w.player as Node).queue_free()
	plot.queue_free()
	(w.corpses as Node).queue_free()
	await wait_frames(1)


func test_tip_stone_and_rain_barrel() -> void:
	var w: Dictionary = await _plot_world()
	var plot: GravePlot = w.plot
	var player: Player = w.player
	var pinv: Inventory = w.inv
	var visitors := Phase8Fixtures.wish_open("l_09", &"flowers", tree)
	var stone := (load("res://src/entities/tip_stone/tip_stone.tscn") as PackedScene).instantiate() as TipStone
	plot.add_child(stone)
	await wait_frames(1)
	assert_eq(stone.grave_id, "l_09", "from the parent plot")
	assert_false(stone.can_interact(player))
	assert_false(stone.interactable.enabled)
	var state := visitors.save_state()
	state.tips_on_stone = {"l_09": [3, "kin_brandt"]}
	visitors.load_state(state)
	stone.refresh()
	assert_true(stone.can_interact(player))
	assert_eq(stone.get_interaction_prompt(player), "[E] 3 Münzen auf dem Stein (Hinrich Brandt)")
	assert_true(plot.get_interaction_prompt(player).begins_with("Grab von"), "the plot leaves the coins to the TipStone")
	stone.interact(player)
	assert_eq(pinv.count(&"coin"), 3)
	assert_false(stone.can_interact(player), "taken once")
	var barrel := (load("res://src/entities/rain_barrel/rain_barrel.tscn") as PackedScene).instantiate() as RainBarrel
	tree.root.add_child(barrel)
	await wait_frames(1)
	assert_eq(barrel.get_interaction_prompt(player), RainBarrel.TEXT_NO_CAN)
	assert_false(barrel.can_interact(player))
	pinv.add_item(&"watering_can", 1)
	assert_eq(barrel.get_interaction_prompt(player), RainBarrel.PROMPT)
	barrel.interact(player)
	await wait_frames(1)
	assert_eq(care.can_fill(), 6)
	assert_eq(barrel.get_interaction_prompt(player), RainBarrel.TEXT_FULL)
	barrel.queue_free()
	visitors.queue_free()
	(w.player as Node).queue_free()
	plot.queue_free()
	(w.corpses as Node).queue_free()
	await wait_frames(1)
