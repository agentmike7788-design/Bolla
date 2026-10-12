extends TestCase
## G8 Runde 4 (user: „ja soll etwas länger dauern"): the work at the table runs long enough to be seen – the bar of a
## table action lasts at least ToolAnimConfig.table_real_seconds_min and the tool's draw plus table_work_cycles
## cycles of the work clip (ToolAnimConfig.table_seconds, Player.table_action_seconds); every other action keeps
## ActionConfig.real_seconds_min; the game minutes stay those of the action.

const GRAVEKEEPER := "res://assets/models/characters/ph_chr_gravekeeper.glb"
const TABLE_CLIPS: Array[StringName] = [&"table_examine", &"table_search", &"table_wash", &"table_cut", &"table_comb",
		&"table_smoke", &"table_shroud", &"table_snip", &"table_pull"]


static func _tools() -> ToolAnimConfig:
	return Database.config(&"tool_anim_config") as ToolAnimConfig


static func _actions() -> ActionConfig:
	return Database.config(&"action_config") as ActionConfig


func test_values_in_data() -> void:
	var cfg := _tools()
	assert_not_null(cfg)
	assert_true(cfg.table_real_seconds_min >= 3.0 and cfg.table_real_seconds_min <= 5.0,
			"at least about 3 s (%.1f)" % cfg.table_real_seconds_min)
	assert_true(cfg.table_work_cycles >= 2.0, "at least two cycles of the clip")
	assert_almost(_actions().real_seconds_min, 1.5, 0.001, "every other action keeps its 1.5 s")


## A fake rig: the clip lengths decide.
func test_table_seconds_counts_draw_and_cycles() -> void:
	var cfg := _tools()
	var anim := _fake_anim({&"table_wash": 1.4, &"hand_draw": 0.33, &"table_snip": 0.9, &"table_shroud": 1.8,
			&"table_examine": 1.6})
	assert_almost(cfg.table_seconds(anim, &"table_wash", 1.5), maxf(cfg.table_real_seconds_min, 0.33 + cfg.table_work_cycles * 1.4), 0.001,
			"draw + cycles of the washing")
	assert_almost(cfg.table_seconds(anim, &"table_examine", 1.5), maxf(cfg.table_real_seconds_min, cfg.table_work_cycles * 1.6), 0.001,
			"bare hands: no draw")
	assert_almost(cfg.table_seconds(anim, &"table_snip", 1.5), maxf(cfg.table_real_seconds_min, 0.33 + cfg.table_work_cycles * 0.9), 0.001)
	assert_almost(cfg.table_seconds(anim, &"table_shroud", 6.0), 6.0, 0.001, "a longer bar stays")
	assert_almost(cfg.table_seconds(null, &"table_wash", 1.5), cfg.table_real_seconds_min, 0.001, "no rig: the minimum")
	assert_almost(cfg.table_seconds(anim, &"no_such_clip", 1.5), cfg.table_real_seconds_min, 0.001)
	anim.free()


## The gravekeeper's real clips: every table clip gets ≥ 2 cycles after the draw and at least the minimum.
func test_real_clips_get_their_cycles() -> void:
	var cfg := _tools()
	var scene := (load(GRAVEKEEPER) as PackedScene).instantiate()
	var anim := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim)
	if anim == null:
		scene.free()
		return
	for clip: StringName in TABLE_CLIPS:
		assert_true(anim.has_animation(clip), String(clip))
		var secs := cfg.table_seconds(anim, clip, _actions().real_seconds_for(10))
		var draw: StringName = cfg.draw_clips.get(cfg.held_tools.get(clip, &""), &"")
		var draw_len := anim.get_animation(draw).length if draw != &"" else 0.0
		var cycles := (secs - draw_len) / anim.get_animation(clip).length
		assert_true(secs >= cfg.table_real_seconds_min - 0.001, "%s: %.2f s" % [clip, secs])
		assert_true(cycles >= 2.0 - 0.001 and cycles <= 3.5, "%s: %.2f cycles after the draw" % [clip, cycles])
		assert_true(secs <= 5.0, "%s: not dragged out (%.2f s)" % [clip, secs])
	scene.free()


func _fake_anim(lengths: Dictionary) -> AnimationPlayer:
	var anim := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for clip: StringName in lengths:
		var a := Animation.new()
		a.length = float(lengths[clip])
		lib.add_animation(clip, a)
	anim.add_animation_library(&"", lib)
	return anim
