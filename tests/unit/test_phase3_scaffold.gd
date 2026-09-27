extends TestCase
## Lead / W0 (docs/PHASE3_DESIGN.md §12): the Phase-3 scaffold – every stub class loads with
## its contract signature, every new data class / config .tres holds valid contract values,
## EventBus signals, input actions (incl. mouse build bindings §3.6), shader globals, appended
## enum values, Database folders, save format v2 + migration chain, and the W1 fixtures.

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["DecorPlacement", "BuildGrid", "DecorationManager", "BuildMode", "BuildCursor",
		"GrassClearMask", "PlacedDecor"]
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	"res://src/systems/expansion/expansion_manager.gd": "ExpansionManager",
	"res://src/entities/clearable/clearable.gd": "ClearableObstacle",
	"res://src/systems/decoration/decor_placement.gd": "DecorPlacement",
	"res://src/systems/decoration/build_grid.gd": "BuildGrid",
	"res://src/systems/decoration/decoration_manager.gd": "DecorationManager",
	"res://src/systems/decoration/build_mode.gd": "BuildMode",
	"res://src/systems/decoration/build_cursor.gd": "BuildCursor",
	"res://src/systems/decoration/grass_clear_mask.gd": "GrassClearMask",
	"res://src/entities/decor/placed_decor.gd": "PlacedDecor",
	"res://src/systems/cleanliness/dirt_growth.gd": "DirtGrowth",
	"res://src/systems/cleanliness/cleanliness_manager.gd": "CleanlinessManager",
	"res://src/entities/dirt_spot/dirt_spot.gd": "DirtSpot",
	"res://src/systems/graveyard/cemetery_score.gd": "CemeteryScore",
	"res://src/systems/reputation/reputation_rules.gd": "ReputationRules",
	"res://src/systems/reputation/reputation.gd": "Reputation",
	"res://src/systems/ghosts/ghost_mood.gd": "GhostMood",
	"res://src/systems/ghosts/ghost_manager.gd": "GhostManager",
	"res://src/entities/ghost/ghost.gd": "Ghost",
	"res://src/systems/save/save_migration.gd": "SaveMigration",
	"res://src/entities/notice_board/notice_board.gd": "NoticeBoard",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"ExpansionManager": ["sections", "is_unlocked", "unlocked_indices", "block_reason", "is_cleared", "obstacle_ids",
			"progress", "missing_cost", "can_clear", "clear", "unlock", "save_state", "load_state", "post_load"],
	"ClearableObstacle": ["world_rect", "apply_cleared", "can_interact", "get_interaction_prompt", "interact"],
	"DecorPlacement": ["to_dict", "from_dict"],
	"BuildGrid": ["footprint_cells", "check"],
	"DecorationManager": ["placements", "can_place", "place", "remove", "placement_at", "decor_score", "score_by_section",
			"suppresses_dirt_at", "ghost_bonus_at", "save_state", "load_state"],
	"BuildMode": ["enter", "exit", "toggle", "available", "select", "rotate", "cursor_cell", "cursor_reason",
			"focused_placement", "confirm_place", "confirm_remove"],
	"GrassClearMask": ["repaint"],
	"DirtGrowth": ["rate", "grow", "level"],
	"CleanlinessManager": ["spot_ids", "level", "progress", "is_growing", "tend_minutes", "tend", "penalty", "dirty_count",
			"update_to", "apply_start_state", "save_state", "load_state"],
	"DirtSpot": ["show_level", "can_interact", "get_interaction_prompt", "interact"],
	"CemeteryScore": ["compute", "total", "rating", "breakdown", "refresh"],
	"ReputationRules": ["tier", "tier_index", "label", "target", "drift", "pay_bonus", "stipend", "deliveries_on", "migrate_v1"],
	"Reputation": ["value", "tier", "change", "event", "apply_daily", "forecast", "last_daily"],
	"GhostMood": ["score", "mood", "main_reason", "pick_line"],
	"GhostManager": ["is_ghost_time", "fade_at", "eligible_graves", "mood_of", "active_ghosts", "listen", "save_state", "load_state"],
	"Ghost": ["bind", "set_mood", "set_fade", "say", "can_interact", "get_interaction_prompt", "interact"],
	"SaveMigration": ["migrate", "migrate_1_to_2"],
}
## Stub methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/systems/graveyard/graveyard.gd": ["unlock_section", "plots_in_section", "upgrade_options", "upgrade_marker"],  # P1
	"res://src/systems/graveyard/grave_quality.gd": ["payment_parts"],  # P1
	"res://src/systems/corpse/corpse_manager.gd": ["deliveries_of"],  # P1
	"res://src/systems/corpse/corpse_delivery_rules.gd": ["free_dropoffs"],  # P1
	"res://src/entities/player/player.gd": ["set_build_mode"],  # P2
}
const SCENES := {
	"res://src/entities/clearable/clearable.tscn": ["ClearableObstacle", 8],
	"res://src/entities/dirt_spot/dirt_spot.tscn": ["DirtSpot", 6],
	"res://src/entities/ghost/ghost.tscn": ["Ghost", 15],
	"res://src/entities/decor/placed_decor.tscn": ["PlacedDecor", -1],
	"res://src/entities/notice_board/notice_board.tscn": ["NoticeBoard", -1],
}
## Saveable stubs: [class, save_id, save_order, identity group] (§3.1).
const SAVEABLES := [
	["ExpansionManager", "expansion", 5, &"expansion"],
	["CleanlinessManager", "cleanliness", 12, &"cleanliness"],
	["DecorationManager", "decorations", 15, &"decorations"],
	["GhostManager", "ghosts", 30, &"ghosts"],
]
const SIGNALS := {
	"obstacle_cleared": 2, "section_progress_changed": 3, "section_unlocked": 1, "grave_quality_changed": 2,
	"cemetery_completed": 0, "decor_changed": 3, "build_mode_changed": 1, "dirt_changed": 2, "cleanliness_changed": 2,
	"reputation_changed": 4, "ghost_spoke": 3, "ghost_night_changed": 1, "slice_completed": 0, "cemetery_quality_changed": 2,
}


func test_stub_scripts_load_with_their_class_names() -> void:
	var global := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		global[String(entry["class"])] = String(entry["path"])
	for path: String in STUBS:
		var script := load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		assert_true(script.can_instantiate(), path + " parses")
		var cls: String = STUBS[path]
		assert_eq(global.get(cls), path, "class_name %s → %s" % [cls, path])
		if not IMPLEMENTED.has(cls):
			assert_true(script.source_code.contains("## STUB ("), cls + " is marked as stub")
		var names := {}
		for m: Dictionary in script.get_script_method_list():
			names[String(m.name)] = true
		for method: String in METHODS.get(cls, []):
			assert_true(names.has(method), "%s.%s" % [cls, method])


func test_node_stubs_instantiate() -> void:
	for path: String in STUBS:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			continue
		var base := script.get_instance_base_type()
		if not ClassDB.is_parent_class(base, &"Node"):
			continue
		var node: Node = script.new()
		assert_not_null(node, path)
		node.free()
	var grid := BuildGrid.new(Phase3Fixtures.build_mask())
	assert_not_null(grid.mask)
	assert_not_null(DecorPlacement.new())


func test_saveable_stubs_carry_their_ids_and_groups() -> void:
	for spec: Array in SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		node.free()
	for spec: Array in [["BuildMode", &"build_mode"], ["CemeteryScore", &"cemetery_score"], ["Reputation", &"reputation"]]:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_true(node.is_in_group(spec[1]), spec[0])
		assert_false(node.is_in_group(&"saveable"), spec[0] + " is not saved")
		node.free()


func test_stub_methods_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var script := load(path) as GDScript
		var names := {}
		for m: Dictionary in script.get_script_method_list():
			names[String(m.name)] = true
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	assert_eq(GraveRecord.new().completed_day, 0)
	var plot: Node = (load("res://src/entities/grave/grave_plot.gd") as GDScript).new()
	assert_true("section_id" in plot, "GravePlot.section_id")
	assert_eq(plot.get(&"section_id"), &"yard")
	plot.free()


func test_stub_scenes_instantiate() -> void:
	for path: String in SCENES:
		var packed := load(path) as PackedScene
		assert_not_null(packed, path)
		var node := packed.instantiate()
		assert_eq((node.get_script() as Script).get_global_name(), StringName(SCENES[path][0]), path)
		var prio: int = SCENES[path][1]
		var area := node.get_node_or_null(^"Interactable") as Interactable
		if prio < 0:
			assert_null(area, path + " has no Interactable")
		else:
			assert_not_null(area, path + " Interactable")
			if area != null:
				assert_eq(area.priority, prio, path + " priority (§3.4)")
				assert_true(area.get_child_count() > 0, path + " Interactable has a shape")
		node.free()


func test_reputation_rules_constants() -> void:
	assert_eq(Array(ReputationRules.TIERS), [&"disreputable", &"unremarkable", &"respected", &"esteemed", &"renowned"])
	var labels: Array = []
	for t: StringName in ReputationRules.TIERS:
		labels.append(ReputationRules.LABELS[String(t)])
	assert_eq(labels, ["Verrufen", "Unauffällig", "Geachtet", "Geschätzt", "Gerühmt"], "§14.4 names")


func test_reputation_config_values() -> void:
	for cfg: ReputationConfig in [Database.config(&"reputation_config"), Phase3Fixtures.reputation_config(), ReputationConfig.new()]:
		assert_not_null(cfg)
		var n := ReputationRules.TIERS.size()
		assert_eq(cfg.tier_thresholds.size(), n - 1, "thresholds")
		_assert_ascending(cfg.tier_thresholds, "tier_thresholds")
		for arr: PackedInt32Array in [cfg.pay_bonus, cfg.stipend, cfg.deliveries_per_day, cfg.delivery_every_other_day]:
			assert_eq(arr.size(), n, "one value per tier")
		assert_true(cfg.min_value <= cfg.start_value and cfg.start_value <= cfg.max_value)
		assert_eq(cfg.start_value, 25)
		assert_eq(cfg.tier_thresholds, PackedInt32Array([15, 35, 55, 80]))
		assert_eq(cfg.pay_bonus, PackedInt32Array([-2, 0, 1, 2, 3]))
		assert_eq(cfg.stipend, PackedInt32Array([0, 1, 2, 3, 4]))
		assert_eq(cfg.deliveries_per_day, PackedInt32Array([1, 1, 1, 1, 1]), "one corpse per day in every tier (§14.2)")
		assert_eq(cfg.delivery_every_other_day, PackedInt32Array([1, 0, 0, 0, 0]))
		assert_true(cfg.drift_factor > 0.0 and cfg.drift_factor <= 1.0 and cfg.drift_max > 0)
		var points := {&"grave_good": 2, &"grave_poor": -3, &"missed_delivery": -4, &"marker_upgrade": 1, &"section_unlocked": 4}
		assert_eq(cfg.event_points.size(), points.size())
		for kind: StringName in points:
			assert_eq(cfg.event_points.get(kind), points[kind], String(kind))
		assert_true(cfg.grave_poor_max < cfg.grave_good_min)


func test_decor_config_values() -> void:
	for cfg: DecorConfig in [Database.config(&"decor_config"), Phase3Fixtures.decor_config(), DecorConfig.new()]:
		assert_not_null(cfg)
		assert_eq([cfg.cell_size, cfg.max_placed, cfg.place_minutes, cfg.remove_minutes], [0.5, 80, 5, 5])
		assert_eq([cfg.cursor_distance, cfg.cursor_reach, cfg.grid_overlay_radius], [1.2, 8.0, 3.0])


func test_cleanliness_config_values() -> void:
	for cfg: CleanlinessConfig in [Database.config(&"cleanliness_config"), Phase3Fixtures.cleanliness_config(), CleanlinessConfig.new()]:
		assert_not_null(cfg)
		assert_eq(cfg.max_level, 3)
		for arr: PackedInt32Array in [cfg.penalty_by_level, cfg.grave_mood_by_level, cfg.weed_minutes]:
			assert_eq(arr.size(), cfg.max_level + 1, "one value per level")
		assert_eq(cfg.penalty_by_level, PackedInt32Array([0, 0, 1, 2]))
		assert_eq(cfg.grave_mood_by_level, PackedInt32Array([1, 0, -2, -4]))
		assert_eq(cfg.weed_minutes, PackedInt32Array([0, 15, 15, 25]))
		assert_almost(cfg.growth_per_day[&"weeds"], 0.30)
		assert_almost(cfg.growth_per_day[&"leaves"], 0.40)
		assert_true(cfg.growth_jitter >= 0.0 and cfg.growth_jitter < 1.0)
		assert_eq([cfg.rake_minutes, cfg.rake_item], [10, &"rake"])


func test_ghost_config_values() -> void:
	for cfg: GhostConfig in [Database.config(&"ghost_config"), Phase3Fixtures.ghost_config(), GhostConfig.new()]:
		assert_not_null(cfg)
		assert_eq([cfg.appear_minute, cfg.vanish_minute, cfg.fade_minutes], [1290, 270, 30], "21:30 … 04:30")
		assert_true(cfg.appear_minute < 1440 and cfg.vanish_minute < cfg.appear_minute, "window wraps over midnight")
		assert_eq(cfg.max_active, 6)
		assert_eq(cfg.mood_thresholds, PackedInt32Array([5, 9]))
		_assert_ascending(cfg.mood_thresholds, "mood_thresholds")
		assert_eq(cfg.speeds.size(), 3)
		assert_eq([cfg.speeds.get(&"content"), cfg.speeds.get(&"calm"), cfg.speeds.get(&"restless")], [0.0, 0.4, 0.8])
		assert_eq([cfg.decor_bonus_max, cfg.repeat_minutes, cfg.gift_coins], [2, 60, 2])
		assert_eq([cfg.listen_radius, cfg.face_radius, cfg.wander_radius, cfg.bubble_seconds], [2.2, 3.5, 2.0, 4.0])


func test_ghost_lines_fixture() -> void:
	var lines := Phase3Fixtures.ghost_lines()
	assert_not_null(lines)
	assert_eq(lines.content.size(), 8)
	for reason: StringName in [&"weeds", &"valuables", &"cold", &"cross", &"waited", &"bare"]:
		assert_eq(lines.by_reason[reason].size(), 3, String(reason))
	for t: StringName in [&"letter", &"tattoo", &"strange_wound"]:
		assert_eq(lines.by_trait[t].size(), 2, String(t))
	assert_eq(GhostLines.new().gift, "Der Geist deutet ins Moos – zwei Münzen.")
	assert_null(Database.ghost_lines(), "data/ghosts/ghost_lines.tres is P4's")


func test_sections_in_data_and_fixtures() -> void:
	var real: Array = Database.sections()
	assert_eq(real.size(), 3)
	for list: Array in [real, Phase3Fixtures.sections()]:
		var ids: Array = []
		for s: SectionData in list:
			ids.append(s.id)
		assert_eq(ids, [&"yard", &"east", &"north"], "sorted by order")
		var yard: SectionData = list[0]
		var east: SectionData = list[1]
		var north: SectionData = list[2]
		assert_eq([yard.order, east.order, north.order], [1, 2, 3])
		assert_eq([yard.starts_unlocked, east.starts_unlocked, north.starts_unlocked], [true, false, false])
		assert_eq([yard.decor_cap, east.decor_cap, north.decor_cap], [12, 9, 9], "max decor 30 (§2.3)")
		assert_eq([east.requires_section, east.requires_rating], [&"", &""])
		assert_eq([north.requires_section, north.requires_rating], [&"east", &"dignified"])
		assert_eq(east.display_name, "Ostwiese")
		assert_true(east.unlock_text.contains("3 neue Grabstellen"))
	assert_eq(Database.section(&"north"), real[2])
	assert_null(Database.section(&"nope"))


func test_clearables_match_the_section_totals() -> void:
	# §2.1: east = 4 bramble + 3 rubble + 3 fence gaps, north = hedge + 3 bramble + 2 rubble + 2 stumps + 3 gaps.
	var east := {&"bramble": 4, &"rubble": 3, &"fence_gap": 3}
	var north := {&"hedge": 1, &"bramble": 3, &"rubble": 2, &"stump": 2, &"fence_gap": 3}
	for source: String in ["data", "fixture"]:
		var get_kind := func(id: StringName) -> ClearableData:
			return (Database.clearable(id) if source == "data" else Phase3Fixtures.clearable(id)) as ClearableData
		for id: StringName in Phase3Fixtures.CLEARABLE_IDS:
			var c: ClearableData = get_kind.call(id)
			assert_not_null(c, "%s %s" % [source, id])
			assert_eq(c.id, id)
			assert_true(c.display_name != "" and c.verb != "" and c.minutes > 0, String(id))
		var totals := [_totals(east, get_kind), _totals(north, get_kind)]
		assert_eq(totals[0], [330, {&"wood": 6, &"iron_fittings": 3}, {&"wood": 4, &"stone": 6}], source + " east")
		assert_eq(totals[1], [440, {&"wood": 6, &"iron_fittings": 3}, {&"wood": 9, &"stone": 4}], source + " north")


func test_decor_fixtures() -> void:
	var gravel := Phase3Fixtures.decor(&"decor_path_gravel")
	assert_eq([gravel.zier, gravel.zier_divisor, gravel.counted_max], [1, 4, 24])
	assert_true(gravel.walkable and gravel.allow_route and gravel.suppresses_dirt)
	var lantern := Phase3Fixtures.decor(&"decor_lantern")
	assert_eq([lantern.place_max, lantern.ghost_bonus_radius], [6, 3.0])
	assert_true(lantern.allow_grave_ring)
	assert_eq(Phase3Fixtures.decor(&"decor_flowerbed").footprint, Vector2i(2, 2))
	assert_eq(Phase3Fixtures.decor(&"decor_bench_wood").footprint, Vector2i(3, 1))
	for id: StringName in Phase3Fixtures.DECOR_IDS:
		var d := Phase3Fixtures.decor(id)
		assert_eq(d.id, id)
		assert_eq(Phase3Fixtures.item(id).category, ItemData.Category.DECOR, String(id))
	assert_eq(Phase3Fixtures.item(&"rake").category, ItemData.Category.TOOL)
	assert_eq(Phase3Fixtures.item(&"iron_fittings").max_stack, 20)
	# data/decor is P2's (W1): it mirrors the fixtures.
	assert_eq(Database.decors().size(), Phase3Fixtures.DECOR_IDS.size())
	assert_true(Database.has_decor(&"decor_lantern"))


func test_build_mask_fixture_and_helpers() -> void:
	var mask := Phase3Fixtures.build_mask()
	assert_eq([mask.size, mask.cells.size(), mask.cell], [Vector2i(12, 8), 96, 0.5])
	assert_eq(mask.flags_at(Vector2i(0, 0)), BuildMask.BLOCKED, "fence row")
	assert_eq(mask.flags_at(Vector2i(2, 3)), BuildMask.BLOCKED, "grave")
	assert_eq(mask.flags_at(Vector2i(1, 2)), 1 | BuildMask.GRAVE_RING)
	assert_eq(mask.flags_at(Vector2i(8, 7)), 2 | BuildMask.ROUTE)
	assert_eq(mask.section_at(Vector2i(8, 7)), 2)
	assert_eq(mask.section_at(Vector2i(5, 5)), 1)
	assert_eq(mask.flags_at(Vector2i(-1, 3)), BuildMask.BLOCKED, "outside")
	assert_eq(mask.flags_at(Vector2i(12, 3)), BuildMask.BLOCKED, "outside")
	assert_eq(mask.world_to_cell(Vector2(0.74, 1.26)), Vector2i(1, 2))
	assert_eq(mask.world_to_cell(Vector2(-0.1, 0.0)), Vector2i(-1, 0))
	assert_eq(mask.cell_to_world(Vector2i(1, 2)), Vector2(0.75, 1.25))


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")


func test_input_actions() -> void:
	var keys := {"build_mode": KEY_B, "build_rotate": KEY_R, "build_place": KEY_E, "build_remove": KEY_X, "cemetery_overview": KEY_U}
	for i: int in range(1, 9):
		keys["hotbar_%d" % i] = KEY_0 + i
	for action: String in keys:
		assert_true(InputMap.has_action(action), action)
		assert_has(_keys_of(action), keys[action], action + " key")
	assert_has(_buttons_of("build_place"), MOUSE_BUTTON_LEFT, "left click places (§14.3)")
	assert_has(_buttons_of("build_remove_mouse"), MOUSE_BUTTON_RIGHT, "right click removes (§14.3)")
	assert_has(_buttons_of("build_rotate"), MOUSE_BUTTON_WHEEL_UP, "wheel rotates")
	assert_has(_buttons_of("build_rotate"), MOUSE_BUTTON_WHEEL_DOWN, "wheel rotates")
	assert_eq(_keys_of("build_remove_mouse"), [], "X only on build_remove (no double removal)")


func test_shader_globals() -> void:
	var mask: Dictionary = ProjectSettings.get_setting("shader_globals/grass_clear_mask")
	assert_eq(mask.type, "sampler2D")
	var tex := load(String(mask.value)) as Texture2D
	assert_not_null(tex, "default mask texture")
	if tex != null:
		assert_eq(tex.get_size(), Vector2(1, 1))
		assert_eq(tex.get_image().get_pixel(0, 0).r, 0.0, "black = grass shown")
	var rect: Dictionary = ProjectSettings.get_setting("shader_globals/grass_clear_rect")
	assert_eq(rect.type, "vec4")
	assert_eq(rect.value, Vector4.ZERO, "off by default (art prototype unchanged)")


func test_appended_enum_values() -> void:
	assert_eq([GraveRecord.State.EMPTY, GraveRecord.State.DUG, GraveRecord.State.FILLED, GraveRecord.State.MARKED,
			GraveRecord.State.OLD, GraveRecord.State.LOCKED], [0, 1, 2, 3, 4, 5])
	assert_eq(GraveRecord.from_dict({"state": 5}).state, GraveRecord.State.LOCKED)
	assert_eq([ItemData.Category.RESOURCE, ItemData.Category.CRAFTED, ItemData.Category.CURRENCY,
			ItemData.Category.DECOR, ItemData.Category.TOOL], [0, 1, 2, 3, 4])
	assert_eq(RecipeData.new().category, &"grave")
	for r: RecipeData in Database.recipes():
		if not String(r.id).begins_with("decor_"):
			assert_eq(r.category, &"grave", "existing recipe %s" % r.id)


func test_save_format_v2_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 2)
	assert_eq(SaveFileIO.FORMAT_VERSION, SaveMigration.CURRENT)
	assert_eq(SaveManager.FORMAT_VERSION, 2)
	var state := {"autoloads": {"TimeManager": {}, "GameState": {}}, "nodes": {}}
	assert_eq(SaveMigration.migrate(state, 2), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 3), {}, "newer → corrupt")
	assert_eq(SaveMigration.migrate(state, 0), {}, "unknown → corrupt")
	var migrated := SaveMigration.migrate(state, 1, {"day": 3})
	assert_true(migrated.get("autoloads") is Dictionary and migrated.get("nodes") is Dictionary, "v1 → v2 keeps the envelope")
	assert_false(is_same(migrated, state), "no aliasing of the decoded state")


# --- helpers ----------------------------------------------------------------------------------

func _path_of(cls: String) -> String:
	for path: String in STUBS:
		if STUBS[path] == cls:
			return path
	return ""


func _assert_ascending(values: PackedInt32Array, label: String) -> void:
	for i: int in range(1, values.size()):
		assert_true(values[i] > values[i - 1], "%s ascending" % label)


## [minutes, cost, yield] of `counts` {kind: n}.
func _totals(counts: Dictionary, get_kind: Callable) -> Array:
	var minutes := 0
	var cost := {}
	var gain := {}
	for kind: StringName in counts:
		var c: ClearableData = get_kind.call(kind)
		var n: int = counts[kind]
		minutes += c.minutes * n
		for id: StringName in c.cost:
			cost[id] = int(cost.get(id, 0)) + c.cost[id] * n
		for id: StringName in c.yield_items:
			gain[id] = int(gain.get(id, 0)) + c.yield_items[id] * n
	return [minutes, _sorted(cost), _sorted(gain)]


func _sorted(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) > String(b))
	var out := {}
	for k: Variant in keys:
		out[k] = d[k]
	return out


func _keys_of(action: String) -> Array:
	var out: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append((e as InputEventKey).physical_keycode)
	return out


func _buttons_of(action: String) -> Array:
	var out: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventMouseButton:
			out.append((e as InputEventMouseButton).button_index)
	return out
