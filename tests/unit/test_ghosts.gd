extends TestCase
## P4 (docs/PHASE3_DESIGN.md §2.8, §3.4, §10): GhostMood rules (score, mood, main reason,
## deterministic lines), GhostManager (eligibility, time window + fade, max 6 nearest with
## hysteresis, listen: repeat within 60 min, one-time gift, save/load), the Ghost entity
## (prompt, fade, bubble, placeholder model, soul light), mat_ghost / ghost.gdshader and the
## real ghost lines. Phase 4 (docs/PHASE4_DESIGN.md §2.7, §2.9): robbed mood, reasons robbed /
## unkempt in priority, story and piety lines, gift 0 / 2 / 3 by Pietät tier (Piety double).
## Other modules are replaced by doubles (read only through their groups).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const GHOST_SCENE := "res://src/entities/ghost/ghost.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const SHADER := "res://assets/shaders/ghost.gdshader"
const MATERIAL := "res://assets/materials/mat_ghost.tres"
const REASONS: Array[StringName] = [&"robbed", &"weeds", &"valuables", &"cold", &"unkempt", &"cross", &"nameless", &"waited", &"bare"]
const STORIES: Array[StringName] = [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]
const TRAITS: Array[StringName] = [&"letter", &"tattoo", &"strange_wound"]
const MARKED := GraveRecord.State.MARKED


## Grave place with the properties Graveyard and GhostManager read.
class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


## CorpseManager read through get_record only.
class CorpsesDouble extends CorpseManager:
	var recs: Dictionary = {}

	func _ready() -> void:
		pass

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord


## CleanlinessManager API used by the ghosts: level(spot_id).
class CleanDouble extends Node:
	var levels: Dictionary = {}

	func _init() -> void:
		add_to_group(&"cleanliness")

	func level(spot_id: String) -> int:
		return int(levels.get(spot_id, 0))


## DecorationManager API used by the ghosts: ghost_bonus_at(p).
class DecorDouble extends Node:
	var bonus: Dictionary = {}  # Vector2i(round x, round z) -> int

	func _init() -> void:
		add_to_group(&"decorations")

	func ghost_bonus_at(p: Vector2) -> int:
		return int(bonus.get(Vector2i(roundi(p.x), roundi(p.y)), 0))


## Piety API used by the ghosts (group piety): gift_coins(), tier().
class PietyDouble extends Node:
	var coins: int = 2
	var tier_id: StringName = &"matter_of_fact"

	func _init() -> void:
		add_to_group(&"piety")

	func gift_coins() -> int:
		return coins

	func tier() -> StringName:
		return tier_id


var cfg: GhostConfig
var clean_cfg: CleanlinessConfig
var economy: EconomyConfig
var lines: GhostLines
var world: Node3D
var graveyard: Graveyard
var corpses: CorpsesDouble
var clean: CleanDouble
var decor: DecorDouble
var ghosts: GhostManager
var spoke: Array = []
var nights: Array = []
var payments: Array = []
var notes: Array = []


func before_each() -> void:
	cfg = Phase3Fixtures.ghost_config()
	clean_cfg = Phase3Fixtures.cleanliness_config()
	economy = load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig
	lines = Phase3Fixtures.ghost_lines()
	GameState.reset()
	TimeManager.load_state({"day": 3, "minute_of_day": 600})
	spoke.clear()
	nights.clear()
	payments.clear()
	EventBus.ghost_spoke.connect(_on_spoke)
	EventBus.ghost_night_changed.connect(_on_night)
	EventBus.payment_received.connect(_on_payment)
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.ghost_spoke.disconnect(_on_spoke)
	EventBus.ghost_night_changed.disconnect(_on_night)
	EventBus.payment_received.disconnect(_on_payment)
	GameState.reset()


# --- GhostMood: score + mood ---------------------------------------------------------------

func test_score_adds_dirt_and_capped_decor() -> void:
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, cfg), 10, "fresh grave spot +1")
	assert_eq(GhostMood.score(9, 1, 0, clean_cfg, cfg), 9, "level 1: 0")
	assert_eq(GhostMood.score(9, 2, 0, clean_cfg, cfg), 7, "level 2: −2")
	assert_eq(GhostMood.score(9, 3, 0, clean_cfg, cfg), 5, "level 3: −4")
	assert_eq(GhostMood.score(7, 1, 1, clean_cfg, cfg), 8)
	assert_eq(GhostMood.score(7, 1, 5, clean_cfg, cfg), 9, "decor bonus capped at decor_bonus_max 2")
	assert_eq(GhostMood.score(7, 9, 0, clean_cfg, cfg), 3, "dirt level clamped to the table")


func test_mood_thresholds() -> void:
	var expected := {0: &"restless", 4: &"restless", 5: &"calm", 8: &"calm", 9: &"content", 13: &"content", -3: &"restless"}
	for value: int in expected:
		assert_eq(GhostMood.mood(value, cfg), expected[value], "score %d" % value)


func test_contract_examples() -> void:
	# Shroud + gravestone + examined + fresh = 9, tended +1 → content.
	var best := GhostMood.score(9, 0, 0, clean_cfg, cfg)
	assert_eq(GhostMood.mood(best, cfg), &"content")
	# Wooden cross only: 7 + 1 = 8 → calm; with a vase 9 → content.
	assert_eq(GhostMood.mood(GhostMood.score(7, 0, 0, clean_cfg, cfg), cfg), &"calm")
	assert_eq(GhostMood.mood(GhostMood.score(7, 0, 1, clean_cfg, cfg), cfg), &"content")
	# Valuables taken 5, overgrown −4 → restless.
	assert_eq(GhostMood.mood(GhostMood.score(5, 3, 0, clean_cfg, cfg), cfg), &"restless")


# --- GhostMood: main reason ----------------------------------------------------------------

func test_main_reason_priority() -> void:
	var grave := _grave_record(&"wooden_cross")
	var corpse := _corpse_record(false, &"taken", 0.1)
	corpse.washed = false
	corpse.laid_out = false
	corpse.harvested = [&"hair"]
	assert_eq(GhostMood.main_reason(grave, corpse, 2, 0, economy), &"robbed", "robbed before everything (hair / teeth)")
	corpse.harvested = []
	assert_eq(GhostMood.main_reason(grave, corpse, 2, 0, economy), &"weeds", "weeds first (level ≥ 2)")
	assert_eq(GhostMood.main_reason(grave, corpse, 1, 0, economy), &"valuables")
	corpse.valuables_decision = &"left"
	assert_eq(GhostMood.main_reason(grave, corpse, 1, 0, economy), &"cold", "no shroud")
	corpse.shrouded = true
	assert_eq(GhostMood.main_reason(grave, corpse, 1, 0, economy), &"unkempt", "shrouded, not washed / laid out")
	corpse.washed = true
	corpse.laid_out = true
	assert_eq(GhostMood.main_reason(grave, corpse, 1, 0, economy), &"cross", "wooden cross can be upgraded")
	grave.marker_id = &"gravestone_simple"
	assert_eq(GhostMood.main_reason(grave, corpse, 1, 0, economy), &"waited", "buried decaying")
	corpse.freshness_at_burial = 0.9
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 0, economy), &"bare", "no decor bonus")
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"", "nothing missing")


func test_main_reason_uses_current_freshness_before_burial() -> void:
	var grave := _grave_record(&"gravestone_simple")
	var corpse := _corpse_record(true, &"", -1.0)
	corpse.freshness = 0.1
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 2, economy), &"waited")
	corpse.freshness = 0.8
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 2, economy), &"")


func test_phase4_reasons_unkempt_and_waited_rotten() -> void:
	var grave := _grave_record(&"gravestone_simple")
	var corpse := _corpse_record(true, &"left", 0.9)
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"", "washed + dressed + laid out: nothing")
	corpse.laid_out = false
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"unkempt", "not laid out")
	corpse.laid_out = true
	corpse.washed = false
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"unkempt", "not washed")
	grave.marker_id = &"wooden_cross"
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"unkempt", "unkempt before cross")
	corpse.washed = true
	corpse.shrouded = false
	corpse.dress = &"gown"
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"cross", "a burial gown counts as dressed (not cold)")
	corpse.dress = &""
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"cold", "cold before unkempt")
	corpse.dress = &"shroud"
	corpse.shrouded = true
	grave.marker_id = &"gravestone_simple"
	corpse.freshness_at_burial = 0.05
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"waited", "rotten at burial counts as waited")
	corpse.harvested = [&"teeth"]
	corpse.valuables_decision = &"taken"
	assert_eq(GhostMood.main_reason(grave, corpse, 3, 0, economy), &"robbed", "teeth: robbed before weeds / valuables")


func test_robbed_mood_per_harvested_kind() -> void:
	var p4 := Phase4Fixtures.economy_config()
	assert_not_null(p4)
	assert_eq(cfg.robbed_mood, -5)
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, cfg, 0), GhostMood.score(9, 0, 0, clean_cfg, cfg), "default: not robbed")
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, cfg, 1), 5, "9 + 1 − 5")
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, cfg, 2), 0, "9 + 1 − 10")
	# §2.9 examples: fully prepared 12 +1 → content; hair 12 − 1 − 5 + 1 = 7 calm; hair + teeth 12 − 3 − 10 + 1 = 0.
	assert_eq(GhostMood.mood(GhostMood.score(12, 0, 0, clean_cfg, cfg), cfg), &"content")
	assert_eq(GhostMood.score(11, 0, 0, clean_cfg, cfg, 1), 7)
	assert_eq(GhostMood.mood(GhostMood.score(11, 0, 0, clean_cfg, cfg, 1), cfg), &"calm")
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, cfg, 2), 0)
	assert_eq(GhostMood.mood(GhostMood.score(9, 0, 0, clean_cfg, cfg, 2), cfg), &"restless")
	# Wooden cross + shroud 7 + 1 = 8 calm; washed + laid out 9 + 1 = 10 → content.
	assert_eq(GhostMood.mood(GhostMood.score(9, 0, 0, clean_cfg, cfg), cfg), &"content")
	var c := CorpseRecord.new()
	assert_eq(GhostMood.robbed_count(c), 0)
	c.harvested = [&"hair", &"teeth"]
	assert_eq(GhostMood.robbed_count(c), 2)
	assert_eq(GhostMood.robbed_count(null), 0)
	var custom := GhostConfig.new()
	custom.robbed_mood = -3
	assert_eq(GhostMood.score(9, 0, 0, clean_cfg, custom, 2), 4, "robbed_mood from the config")


# --- GhostMood: lines ----------------------------------------------------------------------

func test_pick_line_is_deterministic_and_from_the_right_pool() -> void:
	var none: Array[StringName] = []
	for seed: int in [0, 1, 7, 12345, -3]:
		var a := GhostMood.pick_line(lines, &"calm", &"weeds", none, seed)
		assert_eq(a, GhostMood.pick_line(lines, &"calm", &"weeds", none, seed), "same seed, same line")
		assert_true(a.begins_with("weeds_"), a)
		assert_true(GhostMood.pick_line(lines, &"restless", &"cold", none, seed).begins_with("cold_"))
		assert_true(GhostMood.pick_line(lines, &"calm", &"", none, seed).begins_with("calm_"), "calm without reason")
		assert_true(GhostMood.pick_line(lines, &"content", &"bare", none, seed).begins_with("content_"), "content ignores reasons")
	var seen := {}
	for seed: int in 30:
		seen[GhostMood.pick_line(lines, &"restless", &"cross", none, seed)] = true
	assert_eq(seen.size(), 3, "all three hints of a reason are used")


func test_pick_line_content_includes_trait_lines() -> void:
	var traits: Array[StringName] = [&"tattoo", &"valuables"]
	var seen := {}
	for seed: int in 40:
		seen[GhostMood.pick_line(lines, &"content", &"", traits, seed)] = true
	assert_eq(seen.size(), 10, "8 thanks + 2 tattoo lines")
	assert_true(seen.has("tattoo_0") and seen.has("tattoo_1"))
	assert_false(seen.has("letter_0"))


func test_pick_line_fallbacks() -> void:
	var none: Array[StringName] = []
	assert_eq(GhostMood.pick_line(null, &"calm", &"", none, 1), "")
	var empty := GhostLines.new()
	assert_eq(GhostMood.pick_line(empty, &"restless", &"weeds", none, 1), "")
	empty.calm = PackedStringArray(["only"])
	assert_eq(GhostMood.pick_line(empty, &"restless", &"weeds", none, 5), "only", "reason pool missing → calm lines")


func test_pick_line_story_ghosts_speak_their_own_lines() -> void:
	var p4 := Phase4Fixtures.ghost_lines()
	var none: Array[StringName] = []
	for story: StringName in STORIES:
		var seen := {}
		for seed: int in 20:
			seen[GhostMood.pick_line(p4, &"content", &"", none, seed, story)] = true
		assert_eq(seen.keys(), ["%s_0" % story, "%s_1" % story], "content %s: only its two lines" % story)
		var calm := {}
		for seed: int in 40:
			calm[GhostMood.pick_line(p4, &"calm", &"cross", none, seed, story)] = true
		assert_true(calm.has("%s_0" % story) and calm.has("cross_0"), "calm: story lines + hints %s" % [calm.keys()])
		assert_true(GhostMood.pick_line(p4, &"restless", &"robbed", none, 3, story).begins_with("robbed_"), "restless: complaints")
	assert_true(GhostMood.pick_line(p4, &"content", &"", none, 3, &"unknown").begins_with("content_"), "unknown story → normal")
	assert_eq(GhostMood.pick_line(p4, &"content", &"", none, 5, &"s2_hemmerling"),
			GhostMood.pick_line(p4, &"content", &"", none, 5, &"s2_hemmerling"), "deterministic")


func test_pick_line_piety_lines_one_in_four() -> void:
	var p4 := Phase4Fixtures.ghost_lines()
	var none: Array[StringName] = []
	for tier: StringName in [&"devout", &"hardhearted"]:
		var own := 0
		for seed: int in 40:
			var line := GhostMood.pick_line(p4, &"calm", &"weeds", none, seed, &"", tier)
			if line.begins_with(String(tier) + "_"):
				own += 1
				assert_eq(posmod(seed, 4), 0, "piety line on every 4th seed")
			else:
				assert_true(line.begins_with("weeds_"), line)
		assert_eq(own, 10, "%s: 1 in 4" % tier)
		var both := {}
		for seed: int in 16:
			both[GhostMood.pick_line(p4, &"content", &"", none, seed * 4, &"s1_quendel", tier)] = true
		assert_eq(both.size(), 2, "both %s lines are used, also by story ghosts" % tier)
	for tier: StringName in [&"callous", &"matter_of_fact", &"considerate", &""]:
		for seed: int in 12:
			assert_true(GhostMood.pick_line(p4, &"calm", &"weeds", none, seed, &"", tier).begins_with("weeds_"), "%s: no own lines" % tier)


# --- GhostManager: time --------------------------------------------------------------------

func test_ghost_time_window_wraps_over_midnight() -> void:
	var m := _bare_manager()
	var cases := {1289: false, 1290: true, 1439: true, 0: true, 150: true, 269: true, 270: false, 600: false, 1260: false}
	for minute: int in cases:
		assert_eq(m.is_ghost_time(minute), cases[minute], "minute %d" % minute)


func test_fade_in_and_out_over_30_minutes() -> void:
	var m := _bare_manager()
	var cases := {1290.0: 0.0, 1305.0: 0.5, 1320.0: 1.0, 1400.0: 1.0, 0.0: 1.0, 240.0: 1.0, 255.0: 0.5, 270.0: 0.0, 700.0: 0.0, 1289.0: 0.0}
	for minute: float in cases:
		assert_almost(m.fade_at(minute), cases[minute], 0.0001, "minute %s" % minute)


func test_night_changed_signal_on_transitions() -> void:
	await _make_world(1)
	TimeManager.load_state({"day": 3, "minute_of_day": 1289})
	ghosts._process(0.0)
	assert_eq(nights, [])
	TimeManager.load_state({"day": 3, "minute_of_day": 1290})
	ghosts._process(0.0)
	TimeManager.load_state({"day": 4, "minute_of_day": 100})
	ghosts._process(0.0)
	TimeManager.load_state({"day": 4, "minute_of_day": 270})
	ghosts._process(0.0)
	assert_eq(nights, [true, false], "21:30 on, 04:30 off")


# --- GhostManager: eligibility + selection -------------------------------------------------

func test_eligible_marked_graves_from_the_night_after_completion() -> void:
	await _make_world(4)
	_mark("plot_01", 9, 0)  # migrated → immediately
	_mark("plot_02", 9, 3)  # completed today (daytime) → tonight
	_mark("plot_03", 9, 4)  # completed tomorrow (future) → not yet
	graveyard.get_grave("plot_04").state = GraveRecord.State.FILLED
	TimeManager.load_state({"day": 3, "minute_of_day": 1300})
	assert_eq(Array(ghosts.eligible_graves()), ["plot_01", "plot_02"])
	# Completed after 21:00 → only from the following night.
	_mark("plot_04", 9, 3)
	EventBus.grave_completed.emit("plot_04", "c_plot_04", 9, [])
	assert_false(ghosts.eligible_graves().has("plot_04"), "same night: not yet")
	TimeManager.load_state({"day": 4, "minute_of_day": 120})
	assert_false(ghosts.eligible_graves().has("plot_04"), "after midnight: still the same night")
	TimeManager.load_state({"day": 4, "minute_of_day": 1300})
	assert_true(ghosts.eligible_graves().has("plot_04"), "next night")
	assert_true(ghosts.eligible_graves().has("plot_03"), "completed on day 4 (daytime) → night of day 4")


func test_select_nearest_with_hysteresis() -> void:
	var d := {"a": 1.0, "b": 2.0, "c": 3.0, "d": 3.5}
	assert_eq(Array(GhostManager.select_nearest(d, PackedStringArray(), 2, 2.0)), ["a", "b"])
	assert_eq(Array(GhostManager.select_nearest(d, PackedStringArray(["d"]), 2, 2.0)), ["a", "d"], "d stays (3.5 − 2 < 2)")
	var near := {"a": 1.0, "b": 2.5, "e": 0.6}
	assert_eq(Array(GhostManager.select_nearest(near, PackedStringArray(["a", "b"]), 2, 2.0)), ["a", "b"], "e only 1.9 m nearer than b")
	near["e"] = 0.4
	assert_eq(Array(GhostManager.select_nearest(near, PackedStringArray(["a", "b"]), 2, 2.0)), ["a", "e"], "clearly nearer ones replace")
	d["e"] = 0.5
	assert_eq(GhostManager.select_nearest({}, PackedStringArray(), 6, 2.0).size(), 0)
	assert_eq(GhostManager.select_nearest(d, PackedStringArray(), 9, 2.0).size(), 5, "never more than candidates")


func test_at_most_six_nearest_ghosts_from_a_fixed_pool() -> void:
	await _make_world(9)
	for i: int in 9:
		_mark("plot_%02d" % (i + 1), 9, 0)
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	ghosts.reselect()
	var ids := _active_ids()
	assert_eq(ids, ["plot_01", "plot_02", "plot_03", "plot_04", "plot_05", "plot_06"], "nearest to the origin (no player)")
	var container := world.get_node("Ghosts")
	assert_eq(container.get_child_count(), 6, "pool of max_active nodes")
	var pool := container.get_children()
	# Move the far plots next to the origin: only clearly nearer ones replace current ghosts.
	(world.get_node("plot_09") as Node3D).position = Vector3(0.2, 0, 0)
	(world.get_node("plot_08") as Node3D).position = Vector3(14.5, 0, 0)  # 15 m vs. plot_06 at 15 m: not > 2 m nearer
	ghosts.reselect()
	ids = _active_ids()
	assert_true(ids.has("plot_09"), "plot_09 is clearly nearer")
	assert_false(ids.has("plot_06"), "farthest current ghost released")
	assert_false(ids.has("plot_08"), "hysteresis keeps plot_05 against plot_08")
	assert_eq(container.get_children(), pool, "no node created or freed per switch")
	TimeManager.load_state({"day": 4, "minute_of_day": 600})
	ghosts.reselect()
	assert_eq(ghosts.active_ghosts().size(), 0, "released by day")


func test_ghosts_fade_with_the_clock_and_hide_inside() -> void:
	await _make_world(1)
	_mark("plot_01", 9, 0)
	TimeManager.load_state({"day": 3, "minute_of_day": 1305})
	ghosts.reselect()
	ghosts.update_visuals(1305.0)
	var ghost := ghosts.active_ghosts()[0]
	assert_almost(ghost.fade, 0.5, 0.001)
	assert_true(ghost.visible)
	ghosts.update_visuals(1320.0)
	assert_almost(ghost.fade, 1.0, 0.001)
	ghosts.forced = true
	ghosts.update_visuals(700.0)
	assert_almost(ghost.fade, 1.0, 0.001, "debug: forced")


# --- GhostManager: mood + listen -----------------------------------------------------------

func test_mood_of_reads_dirt_and_decor_and_updates_ghosts() -> void:
	await _make_world(2)
	_mark("plot_01", 7, 0)
	assert_eq(ghosts.mood_of("plot_01"), &"calm", "7 + 1")
	decor.bonus[Vector2i(0, 0)] = 1
	assert_eq(ghosts.mood_of("plot_01"), &"content", "7 + 1 + vase")
	assert_eq(ghosts.mood_info("plot_01").reason, &"cross")
	clean.levels["dirt_plot_01"] = 3
	assert_eq(ghosts.mood_of("plot_01"), &"restless", "7 − 4 + 1")
	assert_eq(ghosts.mood_info("plot_01").reason, &"weeds")
	assert_eq(ghosts.mood_of("plot_02"), &"", "not marked – no ghost")
	assert_eq(ghosts.mood_of("nope"), &"")
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	ghosts.reselect()
	var ghost := ghosts.active_ghosts()[0]
	assert_eq(ghost.mood, &"restless")
	clean.levels["dirt_plot_01"] = 0
	EventBus.dirt_changed.emit("dirt_plot_01", 0)
	ghosts.update_visuals(1350.0)
	assert_eq(ghost.mood, &"content", "recomputed on dirt_changed")


func test_listen_repeats_within_60_minutes_then_changes_deterministically() -> void:
	await _make_world(1)
	_mark("plot_01", 7, 0)  # calm, reason cross
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	var first := ghosts.listen("plot_01", null)
	assert_true(first.begins_with("cross_"), first)
	assert_eq(first, lines.by_reason[&"cross"][posmod(GhostManager.line_seed("plot_01", 3), 3)], "hash(grave_id) + day")
	TimeManager.load_state({"day": 3, "minute_of_day": 1409})
	assert_eq(ghosts.listen("plot_01", null), first, "same line within 60 minutes")
	TimeManager.load_state({"day": 3, "minute_of_day": 1411})
	var later := ghosts.listen("plot_01", null)
	assert_eq(later, lines.by_reason[&"cross"][posmod(GhostManager.line_seed("plot_01", 3) + 1, 3)], "next line of the day")
	assert_eq(spoke.size(), 3)
	assert_eq(spoke[0], ["plot_01", &"calm", first])
	assert_true(GameState.has_flag(&"ghosts_seen"))
	assert_true(ghosts.was_heard("plot_01"))
	assert_eq(ghosts.listen("plot_02", null), "", "no ghost")


func test_gift_exactly_once_per_content_grave() -> void:
	await _make_world(2)
	var player := await _player()
	_mark("plot_01", 9, 0)  # content
	_mark("plot_02", 7, 0)  # calm
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	ghosts.listen("plot_02", player)
	assert_eq(player.inventory.count(&"coin"), 0, "calm ghosts give nothing")
	ghosts.listen("plot_01", player)
	assert_eq(player.inventory.count(&"coin"), 2, "gift_coins")
	assert_eq(payments, [[2, lines.gift]])
	assert_true(ghosts.gift_given("plot_01"))
	TimeManager.load_state({"day": 5, "minute_of_day": 1350})
	ghosts.listen("plot_01", player)
	assert_eq(player.inventory.count(&"coin"), 2, "only once")
	assert_eq(ghosts.save_state().gifts, {"plot_01": 3})


func test_gift_total_is_bounded_by_the_graves() -> void:
	await _make_world(12)
	var player := await _player()
	for i: int in 12:
		_mark("plot_%02d" % (i + 1), 10, 0)
	for night: int in 3:
		for i: int in 12:
			ghosts.listen("plot_%02d" % (i + 1), player)
	assert_eq(player.inventory.count(&"coin"), 24, "12 graves × 2 = at most 24 coins")


func test_save_load_roundtrip() -> void:
	await _make_world(2)
	var player := await _player()
	_mark("plot_01", 9, 0)
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	ghosts.listen("plot_01", player)
	var saved := ghosts.save_state()
	assert_eq(saved, {"gifts": {"plot_01": 3}, "heard": {"plot_01": 3}})
	var restored := GhostManager.new()
	world.add_child(restored)
	restored.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(restored.save_state(), saved, "JSON floats read back as ints")
	restored.config = cfg
	restored.lines = lines
	restored.listen("plot_01", player)
	assert_eq(player.inventory.count(&"coin"), 2, "no second gift after loading")
	restored.load_state({})
	assert_eq(restored.save_state(), {"gifts": {}, "heard": {}}, "{} = fresh state")
	restored.queue_free()


func test_gift_by_piety_tier_0_2_3() -> void:
	await _make_world(4)
	var player := await _player()
	var piety := PietyDouble.new()
	world.add_child(piety)
	lines = Phase4Fixtures.ghost_lines()
	lines.gift_by_coins = {3: "drei"}
	ghosts.lines = lines
	for i: int in 4:
		_mark("plot_%02d" % (i + 1), 10, 0)
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	# Hartherzig: no gift, the line once per night, the grave keeps its gift.
	piety.coins = 0
	ghosts.listen("plot_01", player)
	ghosts.listen("plot_02", player)
	assert_eq(player.inventory.count(&"coin"), 0, "hardhearted: no gift")
	assert_false(ghosts.gift_given("plot_01"))
	assert_eq(notes.count(lines.no_gift), 1, "no-gift line once per night")
	TimeManager.load_state({"day": 4, "minute_of_day": 100})
	ghosts.listen("plot_01", player)
	assert_eq(notes.count(lines.no_gift), 1, "after midnight: still the same night")
	TimeManager.load_state({"day": 4, "minute_of_day": 1350})
	ghosts.listen("plot_01", player)
	assert_eq(notes.count(lines.no_gift), 2, "next night again")
	# Sachlich: 2 (gift text), Andächtig: 3 (own text).
	piety.coins = 2
	ghosts.listen("plot_01", player)
	assert_eq(player.inventory.count(&"coin"), 2)
	assert_eq(payments[-1], [2, lines.gift])
	piety.coins = 3
	ghosts.listen("plot_02", player)
	assert_eq(player.inventory.count(&"coin"), 5)
	assert_eq(payments[-1], [3, "drei"])
	ghosts.listen("plot_02", player)
	assert_eq(player.inventory.count(&"coin"), 5, "still once per grave")
	assert_eq(ghosts.gift_amount(), 3)
	piety.queue_free()
	await wait_frames(1)
	assert_eq(ghosts.gift_amount(), cfg.gift_coins, "without Piety: GhostConfig.gift_coins")
	assert_eq(ghosts.piety_tier(), &"")


func test_listen_uses_story_piety_and_robbed_mood() -> void:
	await _make_world(2)
	var piety := PietyDouble.new()
	world.add_child(piety)
	lines = Phase4Fixtures.ghost_lines()
	ghosts.lines = lines
	_mark("plot_01", 12, 0)
	_mark("plot_02", 12, 0)
	corpses.recs["c_plot_01"].story_id = &"s3_wernstein"
	var robbed: CorpseRecord = corpses.recs["c_plot_02"]
	robbed.harvested = [&"hair"]
	graveyard.get_grave("plot_02").quality = 11
	assert_eq(ghosts.mood_info("plot_02").score, 7, "12 − 1 (quality) − 5 + 1")
	assert_eq(ghosts.mood_of("plot_02"), &"calm")
	assert_eq(ghosts.mood_info("plot_02").reason, &"robbed")
	robbed.harvested = [&"hair", &"teeth"]
	graveyard.get_grave("plot_02").quality = 9
	assert_eq(ghosts.mood_of("plot_02"), &"restless", "hair + teeth: 0")
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	var seed := GhostManager.line_seed("plot_01", 3)
	var text := ghosts.listen("plot_01", null)
	if posmod(seed, 4) == 0:
		assert_true(text.begins_with("matter_of_fact") or text.begins_with("s3_wernstein_"), text)
	assert_true(text.begins_with("s3_wernstein_"), "content story ghost: " + text)
	assert_true(ghosts.listen("plot_02", null).begins_with("robbed_"))
	piety.tier_id = &"devout"
	var devout := 0
	for day: int in range(10, 30):
		TimeManager.load_state({"day": day, "minute_of_day": 1350})
		if ghosts.listen("plot_02", null).begins_with("devout_"):
			devout += 1
	assert_true(devout > 0 and devout < 20, "devout lines now and then (%d / 20)" % devout)


# --- Ghost entity --------------------------------------------------------------------------

func test_ghost_entity_prompt_fade_and_bubble() -> void:
	var ghost := (load(GHOST_SCENE) as PackedScene).instantiate() as Ghost
	ghost.config = cfg
	tree.root.add_child(ghost)
	await wait_frames(1)
	ghost.bind("plot_01", Transform3D(Basis.IDENTITY, Vector3(3, 0, 2)), "Hedwig Rabenstein")
	ghost.set_mood(&"restless")
	ghost.set_fade(0.3)
	assert_eq(ghost.get_interaction_prompt(null), "", "not addressable while faint")
	assert_false(ghost.interactable.enabled)
	ghost.set_fade(1.0)
	assert_eq(ghost.get_interaction_prompt(null), "[E] Zuhören – Hedwig Rabenstein wirkt unruhig")
	ghost.set_mood(&"content")
	assert_eq(ghost.get_interaction_prompt(null), "[E] Zuhören – Hedwig Rabenstein wirkt zufrieden")
	assert_true(ghost.interactable.enabled)
	assert_true(ghost.global_position.is_equal_approx(Vector3(3, 0, 2)))
	ghost.say("Hallo", 0.05)
	assert_true(ghost.is_speaking())
	assert_eq(ghost.bubble.text, "Hallo")
	await wait_frames(8)
	ghost._process(0.1)
	assert_false(ghost.is_speaking(), "bubble hides after its seconds")
	ghost.set_fade(0.0)
	assert_false(ghost.visible)
	ghost.queue_free()


func test_ghost_hovers_over_its_grave() -> void:
	var ghost := (load(GHOST_SCENE) as PackedScene).instantiate() as Ghost
	ghost.config = cfg
	tree.root.add_child(ghost)
	await wait_frames(1)
	ghost.bind("plot_01", Transform3D.IDENTITY, "X")
	ghost.set_fade(1.0)
	for m: StringName in [&"content", &"calm", &"restless"]:
		ghost.set_mood(m)
		for i: int in 60:
			ghost._process(0.1)
			var p := ghost.body.position
			assert_true(p.y >= 0.3 - 0.081 and p.y <= 0.6 + 0.081, "%s hover %f" % [m, p.y])
			assert_true(Vector2(p.x, p.z).length() <= cfg.wander_radius + 0.01, "%s stays at its grave (%s)" % [m, p])
	ghost.queue_free()


func test_ghost_model_material_and_soul_light() -> void:
	var ghost := (load(GHOST_SCENE) as PackedScene).instantiate() as Ghost
	tree.root.add_child(ghost)
	await wait_frames(1)
	var meshes := ghost.get_node("Body/Model").find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "a model (ph_chr_ghost or the placeholder)")
	for node: Node in meshes:
		var mesh := node as MeshInstance3D
		assert_eq(mesh.material_override.resource_path, MATERIAL)
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ghosts never cast shadows")
	if not ResourceLoader.exists(Ghost.MODEL_PATH):
		assert_eq(meshes[0].name, "ph_ghost_placeholder")
	var light := ghost.soul_light
	assert_false(light.shadow_enabled)
	assert_true(light.light_color.is_equal_approx(Color("#6FE3D2")))
	assert_almost(light.omni_range, 2.5)
	assert_almost(light.light_volumetric_fog_energy, 1.0)
	ghost.set_fade(1.0)
	assert_almost(light.light_energy, 0.5)
	ghost.set_fade(0.5)
	assert_almost(light.light_energy, 0.25)
	var mesh := GhostPlaceholderMesh.build()
	var aabb := mesh.get_aabb()
	assert_almost(aabb.position.y, 0.0, 0.02, "pivot at the hem")
	assert_true(aabb.size.y > 1.5 and aabb.size.y < 1.8, "about 1.65 m high")
	ghost.queue_free()


func test_shader_contract() -> void:
	var shader := load(SHADER) as Shader
	assert_not_null(shader)
	var code := shader.code
	for token: String in ["blend_mix", "cull_disabled", "painted_common.gdshaderinc", "uniform float fade", "uniform float unrest", "brush_noise"]:
		assert_true(code.contains(token), token)
	for line: String in code.split("\n"):
		assert_false(line.get_slice("//", 0).contains("TIME"), "no TIME (PERF-01) – anim_time comes from the script: " + line)
	var mat := load(MATERIAL) as ShaderMaterial
	assert_eq(mat.shader, shader)
	assert_not_null(mat.get_shader_parameter(&"brush_noise"))


# --- data ----------------------------------------------------------------------------------

func test_real_ghost_lines() -> void:
	var real := Database.ghost_lines() as GhostLines
	assert_not_null(real)
	assert_eq(real.content.size(), 8, "8 thanks lines")
	assert_true(real.calm.size() >= 3, "calm lines")
	assert_eq(real.by_reason.size(), REASONS.size(), "9 reasons incl. robbed / unkempt / nameless")
	for reason: StringName in REASONS:
		assert_eq(real.by_reason.get(reason, PackedStringArray()).size(), 3, String(reason))
	assert_eq(real.by_trait.size(), TRAITS.size())
	for t: StringName in TRAITS:
		assert_eq(real.by_trait.get(t, PackedStringArray()).size(), 2, String(t))
	var all := {}
	var pools: Array = [real.content, real.calm]
	pools.append_array(real.by_reason.values())
	pools.append_array(real.by_trait.values())
	pools.append_array(real.by_story.values())
	pools.append_array(real.by_piety.values())
	for pool: PackedStringArray in pools:
		for line: String in pool:
			assert_true(line.length() > 0 and line.length() <= 90, "≤ 90 characters: " + line)
			assert_false(all.has(line), "duplicate: " + line)
			all[line] = true
	assert_eq(real.gift, "Der Geist deutet ins Moos – zwei Münzen.")
	assert_eq((Database.config(&"ghost_config") as GhostConfig).gift_coins, 2)


# --- Phase 5 (P4, docs/PHASE5_DESIGN.md §2.5) ---------------------------------------------

func test_phase5_nameless_reason_in_priority() -> void:
	var grave := _grave_record(&"stone_stele")
	grave.design = Phase5Fixtures.design(&"stone_stele").to_dict()
	var corpse := _corpse_record(true, &"", 0.9)
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"nameless", "a stone without a name")
	corpse.laid_out = false
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"unkempt", "unkempt before nameless")
	corpse.laid_out = true
	corpse.freshness_at_burial = 0.2
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 0, economy), &"nameless", "nameless before waited / bare")
	grave.design = Phase5Fixtures.design(&"stone_stele", &"i_rest", &"", false, PackedStringArray(["Hier ruht", "A"])).to_dict()
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 0, economy), &"waited", "with an inscription: the old reasons")
	corpse.freshness_at_burial = 0.9
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 0, economy), &"bare")
	assert_eq(GhostMood.main_reason(grave, corpse, 0, 1, economy), &"")
	# The shapes in marker_quality do not turn the plain gravestone into a "cross" complaint.
	assert_true(economy.marker_quality.has(&"stone_master"), "Phase-5 shapes in the economy")
	var plain := _grave_record(&"gravestone_simple")
	assert_eq(GhostMood.main_reason(plain, corpse, 0, 1, economy), &"", "gravestone: nothing missing (Phase 3/4)")
	var cross := _grave_record(&"wooden_cross")
	assert_eq(GhostMood.main_reason(cross, corpse, 0, 1, economy), &"cross")
	assert_eq(GhostMood.REASONS.find(&"nameless"), GhostMood.REASONS.find(&"cross") + 1)


func test_phase5_mood_numbers_of_the_contract() -> void:
	var eco := Phase5Fixtures.economy_config()
	# Mixed grave: braid taken, shroud, plain stone → 8 + 1 − 5 = 4 restless; master stone complete → 10 content.
	var mixed := _corpse_record(true, &"", 0.9)
	mixed.washed = false
	mixed.laid_out = false
	mixed.examined = true
	mixed.cause_id = &"fever"
	mixed.harvested = [&"hair"]
	var q_plain := GraveQuality.compute(mixed, &"gravestone_simple", eco)
	assert_eq(q_plain, 8)
	var before := GhostMood.score(q_plain, 0, 0, clean_cfg, cfg, GhostMood.robbed_count(mixed))
	assert_eq([before, GhostMood.mood(before, cfg)], [4, &"restless"])
	var master := Phase5Fixtures.design(&"stone_master", &"i_fever", &"orn_elder", true).to_dict()
	var q_master := GraveQuality.compute(mixed, &"stone_master", eco, master)
	assert_eq(q_master - q_plain, 6, "up to +6 over the plain gravestone")
	var after := GhostMood.score(q_master, 0, 0, clean_cfg, cfg, GhostMood.robbed_count(mixed))
	assert_eq([after, GhostMood.mood(after, cfg)], [10, &"content"])
	# Fully robbed (hair + teeth): −4 → +6 = 2, stays restless.
	var robbed := _corpse_record(true, &"", 0.9)
	robbed.washed = false
	robbed.laid_out = false
	robbed.cause_id = &"fever"
	robbed.harvested = [&"hair", &"teeth"]
	var r_plain := GhostMood.score(GraveQuality.compute(robbed, &"gravestone_simple", eco), 0, 0, clean_cfg, cfg, 2)
	var r_master := GhostMood.score(GraveQuality.compute(robbed, &"stone_master", eco, master), 0, 0, clean_cfg, cfg, 2)
	assert_eq([r_plain, r_master], [-4, 2])
	assert_eq(GhostMood.mood(r_master, cfg), &"restless", "a stone does not give back what was taken")


func test_phase5_design_key_and_line() -> void:
	var p5 := Phase5Fixtures.ghost_lines()
	var c := _corpse_record(true, &"", 0.9)
	var plain := Phase5Fixtures.design(&"stone_stele", &"i_rest", &"", false, PackedStringArray(["Hier ruht", "Anna"])).to_dict()
	var gilded := Phase5Fixtures.design(&"stone_arch", &"i_rest", &"", true, PackedStringArray(["Hier ruht", "Anna"])).to_dict()
	var master := Phase5Fixtures.design(&"stone_master", &"i_rest", &"", true, PackedStringArray(["Hier ruht", "Anna"])).to_dict()
	assert_eq(GhostMood.design_key(plain, c), &"default")
	assert_eq(GhostMood.design_key(gilded, c), &"gilded")
	assert_eq(GhostMood.design_key(master, c), &"master", "master before gilded")
	var s5 := _corpse_record(true, &"", 0.9)
	s5.story_id = &"s5_moor"
	var lorenz := Phase5Fixtures.design(&"stone_stele", &"i_rest", &"", false, PackedStringArray(["Hier ruht", "Lorenz Aschau"])).to_dict()
	var dorn := Phase5Fixtures.design(&"stone_stele", &"i_rest", &"", false, PackedStringArray(["Hier ruht", "Kaspar Dorn"])).to_dict()
	assert_eq(GhostMood.design_key(lorenz, s5), &"s5_lorenz", "S5 with Lorenz' name in the stone")
	assert_eq(GhostMood.design_key(dorn, s5), &"default", "S5 under his own name")
	assert_eq(GhostMood.pick_design_line(p5, &"s5_lorenz", 3), "Da steht Lorenz’ Name. Er würde lachen.")
	assert_eq(GhostMood.pick_design_line(p5, &"master", 0), "Ein Stein wie für einen Ratsherrn. Die im Dorf werden reden.")
	assert_true(Array(p5.by_design[&"default"]).has(GhostMood.pick_design_line(p5, &"nope", 1)), "unknown key → default")
	assert_eq(GhostMood.pick_design_line(GhostLines.new(), &"default", 0), "")


func test_phase5_by_design_once_per_grave() -> void:
	await _make_world(2)
	ghosts.lines = Phase5Fixtures.ghost_lines()
	var masonry := Stonemasonry.new()
	world.add_child(masonry)
	_mark("plot_01", 12, 0)
	_mark("plot_02", 2, 0)
	for id: String in ["plot_01", "plot_02"]:
		var g := graveyard.get_grave(id)
		g.marker_id = &"stone_master"
		g.design = Phase5Fixtures.design(&"stone_master", &"i_rest", &"", false, PackedStringArray(["Hier ruht", "Tote"])).to_dict()
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	assert_true(masonry.design_line_pending("plot_01"))
	var first := ghosts.listen("plot_01", null)
	assert_eq(first, "Ein Stein wie für einen Ratsherrn. Die im Dorf werden reden.", "content ghost: by_design (master)")
	assert_false(masonry.design_line_pending("plot_01"), "heard")
	TimeManager.load_state({"day": 4, "minute_of_day": 1350})
	var next := ghosts.listen("plot_01", null)
	assert_false(Array(Phase5Fixtures.ghost_lines().by_design[&"master"]).has(next), "only once: " + next)
	assert_eq(ghosts.mood_of("plot_02"), &"restless")
	assert_false(Array(Phase5Fixtures.ghost_lines().by_design[&"master"]).has(ghosts.listen("plot_02", null)), "restless: no by_design")
	assert_true(masonry.design_line_pending("plot_02"), "still pending for a restless ghost")
	assert_eq(masonry.save_state().heard_design, ["plot_01"], "saved by Stonemasonry")


func test_phase5_real_ghost_lines() -> void:
	var real := Database.ghost_lines() as GhostLines
	var fixture := Phase5Fixtures.ghost_lines()
	assert_eq(real.by_reason[&"nameless"], fixture.by_reason[&"nameless"], "§2.5 leading texts")
	assert_eq(real.by_design, fixture.by_design)
	for key: StringName in [&"default", &"gilded", &"master", &"s5_lorenz"]:
		assert_true(real.by_design.has(key), String(key))
		for line: String in real.by_design[key]:
			assert_true(line.length() <= 90, line)


# --- Phase 6 (P4, docs/PHASE6_DESIGN.md §2.4, §2.7) ------------------------------------------

func test_phase6_score_adds_the_devotion() -> void:
	assert_eq(GhostMood.score(7, 0, 0, clean_cfg, cfg, 0, 1), GhostMood.score(7, 0, 0, clean_cfg, cfg) + 1)
	assert_eq(GhostMood.score(9, 1, 1, clean_cfg, cfg, 2, 3), 9 + 0 + 1 - 10 + 3)
	assert_eq(GhostMood.score(7, 0, 0, clean_cfg, cfg, 0, -4), GhostMood.score(7, 0, 0, clean_cfg, cfg), "never a malus")


func test_phase6_mood_info_reads_the_devotion_capped_for_robbed() -> void:
	await _make_world(3)
	var chapel := _chapel({"plot_01": 1, "plot_02": 3})
	_mark("plot_01", 7, 0)
	_mark("plot_02", 11, 0)
	_mark("plot_03", 7, 0)
	(corpses.recs["c_plot_02"] as CorpseRecord).harvested = [&"hair", &"teeth"] as Array[StringName]
	# plot_01: wooden cross 7 + 1 = 8 calm → devotion 1: 9 content.
	assert_eq([ghosts.mood_info("plot_01").devotion, ghosts.mood_info("plot_01").score], [1, 9])
	assert_eq(ghosts.mood_of("plot_01"), &"content")
	# plot_02: fully robbed 11 + 1 − 10 = 2 → devotion 3: 5 calm.
	assert_eq([ghosts.mood_info("plot_02").devotion, ghosts.mood_info("plot_02").score], [3, 5])
	assert_eq(ghosts.mood_of("plot_02"), &"calm")
	graveyard.get_grave("plot_02").quality = 16
	assert_eq(ghosts.mood_info("plot_02").score, 8, "robbed: capped at 8 (calm), never content")
	assert_eq(ghosts.mood_info("plot_02").devotion, 1)
	assert_eq(ghosts.mood_info("plot_03").devotion, 0, "no devotion")
	chapel.free()
	assert_eq(ghosts.mood_info("plot_01").score, 8, "without a chapel no bonus")


func test_phase6_by_service_once_per_grave() -> void:
	await _make_world(2)
	ghosts.lines = Phase6Fixtures.ghost_lines()
	_mark("plot_01", 12, 0)
	_mark("plot_02", 12, 0)
	corpses.recs["c_plot_01"].service_held = true
	var pool := Array(Phase6Fixtures.ghost_lines().by_service)
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	var first := ghosts.listen("plot_01", null)
	assert_true(pool.has(first), "first night: by_service – " + first)
	assert_false(pool.has(ghosts.listen("plot_02", null)), "no service, no by_service line")
	TimeManager.load_state({"day": 4, "minute_of_day": 1350})
	assert_false(pool.has(ghosts.listen("plot_01", null)), "only once")
	assert_eq(ghosts.save_state().service_heard, {"plot_01": 3}, "saved")


func test_phase6_by_devotion_once_per_level_with_robbed_pool() -> void:
	await _make_world(2)
	ghosts.lines = Phase6Fixtures.ghost_lines()
	var chapel := _chapel({"plot_01": 1, "plot_02": 2})
	_mark("plot_01", 12, 0)
	_mark("plot_02", 12, 0)
	(corpses.recs["c_plot_02"] as CorpseRecord).harvested = [&"hair"] as Array[StringName]
	var fixture := Phase6Fixtures.ghost_lines()
	TimeManager.load_state({"day": 3, "minute_of_day": 1350})
	assert_true(Array(fixture.by_devotion[&"default"]).has(ghosts.listen("plot_01", null)))
	assert_eq(ghosts.listen("plot_02", null), "Eine Kerze. Und trotzdem fehlt mir etwas.", "robbed pool")
	TimeManager.load_state({"day": 4, "minute_of_day": 1350})
	assert_false(Array(fixture.by_devotion[&"default"]).has(ghosts.listen("plot_01", null)), "once per level")
	chapel.load_state({"devotions": {"plot_01": 3, "plot_02": 2}})
	TimeManager.load_state({"day": 5, "minute_of_day": 1350})
	assert_true(Array(fixture.by_devotion[&"default"]).has(ghosts.listen("plot_01", null)), "a new devotion level speaks again")
	var saved := ghosts.save_state()
	assert_eq(saved.devotion_heard, {"plot_01": 3, "plot_02": 2})
	var restored := GhostManager.new()
	world.add_child(restored)
	restored.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(restored.save_state(), saved, "roundtrip")
	restored.queue_free()
	chapel.free()


func test_phase6_real_ghost_lines() -> void:
	var real := Database.ghost_lines() as GhostLines
	var fixture := Phase6Fixtures.ghost_lines()
	for line: String in fixture.by_service:
		assert_true(Array(real.by_service).has(line), "§2.4 leading text: " + line)
	for key: StringName in [&"default", &"robbed"]:
		assert_true(real.by_devotion.has(key), String(key))
		for line: String in fixture.by_devotion[key]:
			assert_true(Array(real.by_devotion[key]).has(line), "§2.4 leading text: " + line)
	var all: Array = Array(real.by_service)
	for key: StringName in real.by_devotion:
		all.append_array(Array(real.by_devotion[key]))
	for line: String in all:
		assert_true(line.length() <= 90 and line != "", line)


func _chapel(devotions: Dictionary) -> ChapelRites:
	var chapel := ChapelRites.new()
	chapel.config = Phase6Fixtures.chapel_config()
	chapel.load_state({"devotions": devotions})
	world.add_child(chapel)
	return chapel


# --- helpers -------------------------------------------------------------------------------

func _bare_manager() -> GhostManager:
	var m := GhostManager.new()
	m.config = cfg
	m.free.call_deferred()
	return m


## World with `count` plots plot_01… on the +X axis, 3 m apart (plot_01 at the origin).
func _make_world(count: int) -> void:
	world = Node3D.new()
	world.name = "World"
	var container := Node3D.new()
	container.name = "Ghosts"
	world.add_child(container)
	corpses = CorpsesDouble.new()
	world.add_child(corpses)
	graveyard = Graveyard.new()
	graveyard.economy = economy
	for i: int in count:
		var plot := PlotDouble.new()
		plot.grave_id = "plot_%02d" % (i + 1)
		plot.name = plot.grave_id
		plot.position = Vector3(i * 3.0, 0, 0)
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	world.add_child(graveyard)
	clean = CleanDouble.new()
	world.add_child(clean)
	decor = DecorDouble.new()
	world.add_child(decor)
	ghosts = GhostManager.new()
	ghosts.config = cfg
	ghosts.lines = lines
	ghosts.cleanliness_config = clean_cfg
	ghosts.economy = economy
	ghosts.container_path = ^"../Ghosts"
	world.add_child(ghosts)
	tree.root.add_child(world)
	await wait_frames(1)


## Marks a grave with `quality` (shrouded, fresh, wooden cross unless quality ≥ 9).
func _mark(id: String, quality: int, completed_day: int) -> void:
	var grave := graveyard.get_grave(id)
	grave.state = MARKED
	grave.quality = quality
	grave.marker_id = &"gravestone_simple" if quality >= 9 else &"wooden_cross"
	grave.completed_day = completed_day
	grave.corpse_id = "c_" + id
	var corpse := _corpse_record(true, &"", 0.9)
	corpse.id = grave.corpse_id
	corpse.display_name = "Tote " + id
	corpses.recs[corpse.id] = corpse


func _player() -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	player.position = Vector3(0, 0, 40)
	world.add_child(player)
	await wait_frames(1)
	return player


func _active_ids() -> Array:
	var ids: Array = []
	for g: Ghost in ghosts.active_ghosts():
		ids.append(g.grave_id)
	ids.sort()
	return ids


func _grave_record(marker: StringName) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = "plot_01"
	g.state = MARKED
	g.marker_id = marker
	return g


func _corpse_record(shrouded: bool, decision: StringName, fresh_at_burial: float) -> CorpseRecord:
	var c := CorpseRecord.new()
	c.shrouded = shrouded
	c.dress = CorpseRecord.DRESS_SHROUD if shrouded else CorpseRecord.DRESS_NONE
	c.washed = true
	c.laid_out = true
	c.valuables_decision = decision
	c.freshness_at_burial = fresh_at_burial
	return c


func _on_spoke(grave_id: String, mood: StringName, text: String) -> void:
	spoke.append([grave_id, mood, text])


func _on_night(active: bool) -> void:
	nights.append(active)


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
