extends TestCase
## W3 QA regressions of the Phase-4 review (docs/reviews/phase4_wip/qa_playthrough.md,
## "Befunde"): each test failed before its fix. Runs on the real graveyard world.

const TIMEOUT := 180.0
const SLOT := 95
const DELIVERY := 460

var saves_dir := TestCase.user_dir("test_saves_p4_qa")
var bot: Phase4Bot


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	await SaveManager.new_game()
	bot = Phase4Bot.new(&"reverent", tree)
	bot.bind()


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


# --- QA4-01: finds resolve with the freshness at the end of the step, not the last full hour --
# In real-time play the clock ticks minute by minute (no time_skipped) and the CorpseManager
# decays only on hour_changed – a step finished at xx:55 used the freshness of xx:00.

func test_exam_step_uses_current_freshness_in_real_time() -> void:
	var record := _corpse_crossing(0.6)
	var cause_find := StringName("f_cause_%s" % record.cause_id)
	assert_true(record.freshness >= 0.6, "setup: the stored freshness is still of the last full hour (%.4f)" % record.freshness)
	var result := bot.care.exam_step(record.id, CorpseRecord.STEP_WOUNDS)
	assert_false(result.is_empty(), "wounds examined")
	assert_has(record.finds_lost, cause_find, "the cause detail (0.6) is lost now – forecast and result agree")
	assert_false(record.finds_revealed.has(cause_find))
	assert_true(record.freshness < 0.6, "the record carries the freshness of now (%.4f)" % record.freshness)


func test_hair_uses_current_freshness_in_real_time() -> void:
	var record := _corpse_crossing(0.3)
	bot.inv().add_item(&"shears", 1)
	GameState.set_flag(&"trader_known", true)
	assert_ne(bot.care.harvest_block_reason(record.id, CorpseRecord.HARVEST_HAIR, bot.inv()), "",
			"the hair is too brittle now (freshness %.4f of now)" % CorpseDecay.freshness_at(record,
			TimeManager.total_minutes(), CorpseDecay.decay_per_hour(record, bot.manager.tables), 0.25))
	assert_false(bot.care.harvest(record.id, CorpseRecord.HARVEST_HAIR, bot.inv()))


# --- QA4-02: the decay effects show at the default gameplay camera distance ------------------
# visibility_range 22 m was measured from the camera – at the default distance (22 m) the
# corpses themselves lay beyond it and never showed flies, wisps or smoke.

func test_decay_effects_reach_beyond_the_camera_zoom() -> void:
	var rig := bot.world.get_node("CameraRig")
	var cfg := Database.config(&"decay_visual_config") as DecayVisualConfig
	assert_true(cfg.visibility_range > float(rig.get(&"zoom_max")) + 4.0,
			"decay effects visible up to the maximum zoom (%.0f m vs %.0f m)" % [cfg.visibility_range, float(rig.get(&"zoom_max"))])


func test_fly_cloud_follows_the_flies() -> void:
	var v := CorpseDecayVisual.new()
	bot.world.add_child(v)
	v.apply(0.9, &"fresh", false, false)
	assert_false(v.cloud_node.visible, "fresh: no fly cloud")
	v.apply(0.2, &"decaying", false, false)
	assert_true(v.cloud_node.visible, "decaying: the fly cloud reads from afar")
	var faint := v.cloud_node.transparency
	v.apply(0.05, &"rotten", false, false)
	assert_true(v.cloud_node.transparency < faint, "denser with more flies")
	assert_eq(v.cloud_node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(v.live_particles(), 15, "the cloud is no particle (§9 budget unchanged)")
	v.queue_free()


# --- QA4-03: no grass through a corpse lying on the ground -----------------------------------

func test_grass_cleared_under_a_corpse_on_the_ground() -> void:
	var mask := bot.world.get_node("Systems/GrassClearMask") as GrassClearMask
	var spot := Vector2(-1.2, -3.2)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), Vector3(spot.x, 0.0, spot.y))
	assert_eq(_texel(mask, spot), 0, "setup: grass on the lawn")
	var record := bot.manager.spawn_corpse(null, xf, CorpseRecord.LOCATION_GROUND)
	assert_eq(_texel(mask, spot), 255, "grass cleared under the body")
	# Along the body (local X, 0.8 m from the centre) cleared, beside it (0.8 m across) not.
	var node := bot.manager.get_corpse_node(record.id)
	var along := Vector2(node.global_transform.basis.x.x, node.global_transform.basis.x.z).normalized()
	assert_eq(_texel(mask, spot + along * 0.8), 255, "the legs too")
	assert_eq(_texel(mask, spot + along.orthogonal() * 0.8), 0, "not beside the body")
	bot.manager.pick_up(record.id, bot.player)
	assert_eq(_texel(mask, spot), 0, "the grass is back once the corpse is carried")


# --- QA4-04: a ghost whose teeth were taken does not ask for its braid ------------------------

func test_robbed_lines_match_the_kind_taken() -> void:
	var lines := Database.ghost_lines() as GhostLines
	var none: Array[StringName] = []
	var teeth: Array[StringName] = [CorpseRecord.HARVEST_TEETH]
	var hair: Array[StringName] = [CorpseRecord.HARVEST_HAIR]
	var hair_line := false
	for seed: int in 40:
		for mood: StringName in [GhostMood.RESTLESS, GhostMood.CALM]:
			var t := GhostMood.pick_line(lines, mood, GhostMood.REASON_ROBBED, none, seed, &"", &"", teeth)
			assert_false(t.contains("Zopf"), "teeth only: %s" % t)
			hair_line = hair_line or GhostMood.pick_line(lines, mood, GhostMood.REASON_ROBBED, none, seed, &"", &"", hair).contains("Zopf")
	assert_true(hair_line, "the braid line stays for a ghost whose hair was taken")


# --- QA4-06 (perf): a hidden NPC rests – its skeleton is not animated, it updates per minute ---

func test_hidden_npc_rests_and_comes_back_on_time() -> void:
	var ilse := bot.ilse
	var anim := ilse.find_child("AnimationPlayer", true, false) as AnimationPlayer
	TimeManager.running = false
	TimeManager.set_time(2, 700)
	await wait_frames(3)
	assert_false(ilse.visible, "unknown: hidden")
	if anim != null:
		assert_false(anim.is_playing(), "hidden: no skeleton animation")
	GameState.set_flag(&"trader_known", true)
	TimeManager.set_time(2, 1400)
	await wait_frames(3)
	assert_true(ilse.visible and ilse.is_talkable(), "23:20 at the wall again")
	if anim != null:
		assert_true(anim.is_playing(), "shown: animated")


# --- helpers ----------------------------------------------------------------------------------

## A generated corpse on the table whose freshness falls below `threshold` at a minute that is
## not a full hour; the clock is then ticked minute by minute (as in real-time play) to the
## first minute below the threshold.
func _corpse_crossing(threshold: float) -> CorpseRecord:
	TimeManager.running = false
	var t := bot.manager.tables
	var rec := CorpseGenerator.generate(CorpseGenerator.seed_for(TimeManager.day, 7), t, TimeManager.day)
	var rate := CorpseDecay.decay_per_hour(rec, t)
	rec.arrival_total_minutes = TimeManager.total_minutes()
	var until := CorpseDecay.minutes_until(rec, TimeManager.total_minutes(), rate, 0.25, threshold)
	if (TimeManager.total_minutes() + until) % 60 == 0:
		TimeManager.advance(1)  # the crossing on a full hour would be caught by the hourly decay
	var cross := TimeManager.total_minutes() + until
	var record := bot.manager.spawn_corpse(rec, bot._table().slot_transform(), CorpseRecord.LOCATION_TABLE)
	@warning_ignore("integer_division")
	var last_hour := cross / 60 * 60
	if last_hour > TimeManager.total_minutes():
		TimeManager.advance(last_hour - TimeManager.total_minutes())
	while CorpseDecay.freshness_at(record, TimeManager.total_minutes(), rate, 0.25) >= threshold:
		TimeManager.advance(1)
	return record


func _texel(mask: GrassClearMask, p: Vector2) -> int:
	var m := (bot.world.get_node("Systems/Decorations") as DecorationManager).mask
	var texel := m.cell / GrassClearMask.TEXELS_PER_CELL
	var x := floori((p.x - m.origin.x) / texel)
	var y := floori((p.y - m.origin.y) / texel)
	return mask.image.get_pixel(x, y).r8 if mask.image != null else -1
