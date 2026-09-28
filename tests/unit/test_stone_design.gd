extends TestCase
## P4 (docs/PHASE5_DESIGN.md §2.5, §10): StoneCalendar (day 1 = 3. Gilbhart 1834, month / year
## change), StoneDesignRules (render_text of all 7 templates, name wrap > 22 characters, fits by
## cause / age / story, points / minutes / material, maximum 9, breakdown lines), the stone data
## files (= Phase-5 fixtures) and the StoneVisual inscription / ornament placement.

var cfg: StoneConfig
var eco: EconomyConfig


func before_each() -> void:
	cfg = Phase5Fixtures.stone_config()
	eco = Phase5Fixtures.economy_config()


# --- calendar -------------------------------------------------------------------------------

func test_calendar_day_one_is_3_gilbhart_1834() -> void:
	assert_eq(StoneCalendar.date_text(1, cfg), "3. Gilbhart 1834")
	assert_eq(StoneCalendar.year_of(1, cfg), 1834)
	assert_eq(StoneCalendar.date_text(0, cfg), "3. Gilbhart 1834", "days < 1 count as day 1")


func test_calendar_month_and_year_change() -> void:
	assert_eq(StoneCalendar.date_text(29, cfg), "31. Gilbhart 1834", "Gilbhart has 31 days")
	assert_eq(StoneCalendar.date_text(30, cfg), "1. Nebelung 1834")
	assert_eq(StoneCalendar.date_text(37, cfg), "8. Nebelung 1834", "§2.5 example")
	assert_eq(StoneCalendar.date_text(59, cfg), "30. Nebelung 1834", "Nebelung has 30 days")
	assert_eq(StoneCalendar.date_text(60, cfg), "1. Julmond 1834")
	assert_eq(StoneCalendar.date_text(90, cfg), "31. Julmond 1834")
	assert_eq(StoneCalendar.date_text(91, cfg), "1. Hartung 1835", "new year")
	assert_eq(StoneCalendar.year_of(91, cfg), 1835)
	assert_eq(StoneCalendar.date_text(91 + 31, cfg), "1. Hornung 1835")
	assert_eq(StoneCalendar.date_text(91 + 31 + 28, cfg), "1. Lenzing 1835", "Hornung 28 days")
	assert_eq(StoneCalendar.date_text(1 + 365, cfg), "3. Gilbhart 1835", "one year later")


func test_calendar_reads_the_config() -> void:
	var other := cfg.duplicate(true) as StoneConfig
	other.calendar["start_year"] = 1900
	other.calendar["start_month"] = 12
	other.calendar["start_day"] = 31
	assert_eq(StoneCalendar.date_text(1, other), "31. Julmond 1900")
	assert_eq(StoneCalendar.date_text(2, other), "1. Hartung 1901")
	assert_eq(StoneCalendar.date_text(1, null), "3. Gilbhart 1834", "null → class defaults")


# --- render_text ------------------------------------------------------------------------------

func test_render_text_of_all_seven_templates() -> void:
	var c := _corpse("Marthe Quendel", 63, &"fever", &"s1_quendel", 37)
	var dates := "* 1771 – † 8. Nebelung 1834"
	var expected := {
		&"i_rest": ["Hier ruht", "Marthe Quendel", dates],
		&"i_long_road": ["Marthe Quendel", dates, "Ein langer Weg, gut gegangen."],
		&"i_too_soon": ["Marthe Quendel", dates, "Zu früh. Viel zu früh."],
		&"i_water": ["Marthe Quendel", "† 8. Nebelung 1834", "Das Wasser nahm dich. Die Erde hält dich."],
		&"i_fever": ["Marthe Quendel", dates, "Die Hitze ist vorbei. Schlaf kühl."],
		&"i_road": ["Marthe Quendel", dates, "Mitten im Weg. Nun angekommen."],
		&"i_garden": ["Marthe Quendel", dates, "Was du gesät hast, blüht noch."],
	}
	assert_eq(Phase5Fixtures.inscriptions().size(), 7)
	for ins: InscriptionData in Phase5Fixtures.inscriptions():
		assert_eq(Array(StoneDesignRules.render_text(ins, c, cfg)), expected[ins.id], String(ins.id))


func test_render_text_dates_and_placeholders() -> void:
	var ins := InscriptionData.new()
	ins.lines = PackedStringArray(["{name} ({age})", "{born}", "{died}"])
	var c := _corpse("Jakob Hain", 30, &"fever", &"", 1)
	assert_eq(Array(StoneDesignRules.render_text(ins, c, cfg)), ["Jakob Hain (30)", "* 1804", "† 3. Gilbhart 1834"])
	c.arrival_total_minutes = 0
	c.buried_day = 91
	assert_eq(Array(StoneDesignRules.render_text(ins, c, cfg)), ["Jakob Hain (30)", "* 1805", "† 1. Hartung 1835"],
			"no arrival → buried_day, birth year from the death year")
	c.arrival_total_minutes = 29 * 1440 + 1439
	assert_eq(StoneDesignRules.render_text(ins, c, cfg)[2], "† 1. Nebelung 1834", "arrival minute → game day 30")


func test_render_text_drops_the_uncertain_mark() -> void:
	var c := _corpse("Lorenz Aschau (?)", 58, &"moor_cold", &"s5_moor", 20)
	var text := StoneDesignRules.render_text(Phase5Fixtures.inscription(&"i_water"), c, cfg)
	assert_eq(text[0], "Lorenz Aschau", "§2.5: register name without ' (?)'")


func test_long_names_wrap_into_two_lines() -> void:
	var c := _corpse("Wilhelmine Kunigunde Rabenstein", 70, &"fever", &"", 5)
	assert_true(c.display_name.length() > 22)
	var text := StoneDesignRules.render_text(Phase5Fixtures.inscription(&"i_rest"), c, cfg)
	assert_eq(Array(text), ["Hier ruht", "Wilhelmine Kunigunde", "Rabenstein", "* 1764 – † 7. Gilbhart 1834"])
	assert_true(text.size() <= StoneDesignRules.MAX_LINES)
	var short := _corpse("Anna Maria Rabensteiner", 70, &"fever", &"", 5)
	assert_eq(Array(StoneDesignRules.wrap_name(short.display_name)), ["Anna Maria", "Rabensteiner"], "23 characters wrap")
	assert_eq(Array(StoneDesignRules.wrap_name("Anna Maria Rabenstein")), ["Anna Maria Rabenstein"], "22 characters stay")
	for ins: InscriptionData in Phase5Fixtures.inscriptions():
		assert_true(StoneDesignRules.render_text(ins, c, cfg).size() <= 4, "%s ≤ 4 lines" % ins.id)


# --- fits -------------------------------------------------------------------------------------

func test_fits_by_cause_age_and_story() -> void:
	var cases := [
		[&"i_rest", _corpse("A", 90, &"drowned_millpond", &"s1_quendel", 1), false, "i_rest never fits"],
		[&"i_long_road", _corpse("A", 60, &"fever", &"", 1), true, "age 60"],
		[&"i_long_road", _corpse("A", 59, &"fever", &"", 1), false, "age 59"],
		[&"i_too_soon", _corpse("A", 35, &"fever", &"", 1), true, "age 35"],
		[&"i_too_soon", _corpse("A", 36, &"fever", &"", 1), false, "age 36"],
		[&"i_water", _corpse("A", 50, &"drowned_millpond", &"", 1), true, "drowned"],
		[&"i_water", _corpse("A", 50, &"moor_cold", &"", 1), true, "moor"],
		[&"i_water", _corpse("A", 50, &"fever", &"", 1), false, "fever is no water"],
		[&"i_fever", _corpse("A", 50, &"fever", &"", 1), true, "fever"],
		[&"i_fever", _corpse("A", 50, &"poisoned", &"", 1), true, "poisoned"],
		[&"i_road", _corpse("A", 50, &"coach_accident", &"", 1), true, "coach"],
		[&"i_road", _corpse("A", 50, &"fall_hayloft", &"", 1), true, "hayloft"],
		[&"i_road", _corpse("A", 50, &"fever", &"", 1), false, "not on the road"],
		[&"i_garden", _corpse("A", 50, &"fever", &"s1_quendel", 1), true, "story s1_quendel"],
		[&"i_garden", _corpse("A", 50, &"fever", &"s2_hemmerling", 1), false, "other story"],
	]
	for case: Array in cases:
		assert_eq(StoneDesignRules.fits(Phase5Fixtures.inscription(case[0]), case[1]), case[2], case[3])
	assert_false(StoneDesignRules.fits(null, cases[1][1]))
	assert_false(StoneDesignRules.fits(Phase5Fixtures.inscription(&"i_long_road"), null))


# --- points / minutes / material ------------------------------------------------------------

func test_marker_points_per_shape_and_surcharge() -> void:
	var c := _corpse("A", 50, &"fever", &"", 1)
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele"), c), 3)
	assert_eq(_points(Phase5Fixtures.design(&"stone_arch"), c), 4)
	assert_eq(_points(Phase5Fixtures.design(&"stone_master"), c), 5)
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"i_rest"), c), 4, "inscription +1")
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"i_fever"), c), 5, "fitting +1")
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"i_fever", &"", true), c), 6, "gilded +1")
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"", &"", true), c), 3, "gold without inscription counts nothing")
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"", &"orn_ivy"), c), 4, "ornament +1")
	assert_eq(_points(Phase5Fixtures.design(&"stone_stele", &"i_fever", &"orn_ivy", true), c), 7, "stele max 7")
	assert_eq(_points(Phase5Fixtures.design(&"stone_arch", &"i_fever", &"orn_torch", true), c), 8, "arch max 8")
	assert_eq(_points(Phase5Fixtures.design(&"stone_master", &"i_fever", &"orn_elder", true), c), 9, "master max 9")
	assert_eq(_points(StoneDesign.new(), c), 0, "empty design")
	assert_eq(_points(Phase5Fixtures.design(&"stone_nope"), c), 0, "unknown shape")


func test_maximum_nine_over_all_designs() -> void:
	var c := _corpse("A", 50, &"fever", &"s1_quendel", 1)
	var best := 0
	for shape: StoneShapeData in Phase5Fixtures.stone_shapes():
		for ins: Variant in [&""] + Phase5Fixtures.INSCRIPTION_IDS:
			for orn: Variant in [&""] + Phase5Fixtures.ORNAMENT_IDS:
				for gilded: bool in [false, true]:
					best = maxi(best, _points(Phase5Fixtures.design(shape.id, ins, orn, gilded), c))
	assert_eq(best, 9)


func test_breakdown_lines() -> void:
	var c := _corpse("A", 50, &"fever", &"", 1)
	var lines := StoneDesignRules.breakdown_lines(Phase5Fixtures.design(&"stone_master", &"i_fever", &"orn_elder", true), c, eco, cfg)
	assert_eq(lines, [{"label": "Meisterstein", "points": 5}, {"label": "Inschrift", "points": 1},
			{"label": "Passende Inschrift", "points": 1}, {"label": "Vergoldet", "points": 1},
			{"label": "Zierde: Holunderdolde", "points": 1}] as Array[Dictionary])
	var plain := StoneDesignRules.breakdown_lines(Phase5Fixtures.design(&"stone_arch", &"i_rest"), c, eco, cfg)
	assert_eq(plain, [{"label": "Rundbogenstein", "points": 4}, {"label": "Inschrift", "points": 1}] as Array[Dictionary])


func test_inputs_and_minutes() -> void:
	var full := Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true)
	assert_eq(StoneDesignRules.inputs(full, cfg), {&"workstone": 3, &"stone": 2, &"iron_fittings": 2, &"clay": 1, &"ink": 1, &"gold_leaf": 1})
	assert_eq(StoneDesignRules.minutes(full, cfg), 205, "§2.5: 150 + 20 + 10 + 25")
	assert_eq(StoneDesignRules.inputs(Phase5Fixtures.design(&"stone_stele"), cfg), {&"stone": 4})
	assert_eq(StoneDesignRules.minutes(Phase5Fixtures.design(&"stone_stele"), cfg), 50)
	var arch := Phase5Fixtures.design(&"stone_arch", &"i_rest", &"orn_ivy")
	assert_eq(StoneDesignRules.inputs(arch, cfg), {&"stone": 5, &"clay": 1, &"ink": 1})
	assert_eq(StoneDesignRules.minutes(arch, cfg), 70 + 20 + 25)
	var gold_only := Phase5Fixtures.design(&"stone_stele", &"", &"", true)
	assert_eq(StoneDesignRules.inputs(gold_only, cfg), {&"stone": 4}, "no gold leaf without inscription")
	assert_eq(StoneDesignRules.minutes(gold_only, cfg), 50)
	assert_eq(StoneDesignRules.inputs(StoneDesign.new(), cfg), {})
	assert_eq(StoneDesignRules.minutes(StoneDesign.new(), cfg), 0)


func test_current_marker_points() -> void:
	var c := _corpse("A", 50, &"fever", &"", 1)
	assert_eq(StoneDesignRules.current_marker_points(Phase5Fixtures.grave_with(c), c, eco, cfg), 0, "FILLED: none")
	assert_eq(StoneDesignRules.current_marker_points(Phase5Fixtures.grave_with(c, &"wooden_cross"), c, eco, cfg), 1)
	assert_eq(StoneDesignRules.current_marker_points(Phase5Fixtures.grave_with(c, &"gravestone_simple"), c, eco, cfg), 3)
	var designed := Phase5Fixtures.grave_with(c, &"", Phase5Fixtures.design(&"stone_arch", &"i_fever", &"orn_ivy"))
	assert_eq(StoneDesignRules.current_marker_points(designed, c, eco, cfg), 7, "designed = its sum")
	assert_eq(StoneDesignRules.current_marker_points(null, c, eco, cfg), 0)


# --- data -------------------------------------------------------------------------------------

func test_stone_data_matches_the_fixtures() -> void:
	assert_eq(Database.stone_shapes().size(), 3)
	assert_eq(Database.inscriptions().size(), 7)
	assert_eq(Database.ornaments().size(), 4)
	var ids: Array = []
	for s: StoneShapeData in Database.stone_shapes():
		ids.append(s.id)
		var f := Phase5Fixtures.stone_shape(s.id)
		assert_eq([s.display_name, s.inputs, s.minutes, s.max_lines], [f.display_name, f.inputs, f.minutes, f.max_lines], String(s.id))
		assert_true(EconomyConfig.resolve().marker_quality.has(s.id), "%s in economy_config.marker_quality" % s.id)
	assert_eq(ids, Phase5Fixtures.SHAPE_IDS, "sorted by order")
	for ins: InscriptionData in Database.inscriptions():
		var f := Phase5Fixtures.inscription(ins.id)
		assert_eq([ins.lines, ins.fits_causes, ins.fits_min_age, ins.fits_max_age, ins.fits_story],
				[f.lines, f.fits_causes, f.fits_min_age, f.fits_max_age, f.fits_story], String(ins.id))
		for line: String in ins.lines:
			assert_true(line.length() <= 44, "%s: short line '%s'" % [ins.id, line])
	var names: Array = []
	for orn: OrnamentData in Database.ornaments():
		names.append(orn.display_name)
		assert_eq([orn.points, orn.minutes], [1, 25], String(orn.id))
		assert_true(orn.tooltip != "", String(orn.id) + " tooltip")
	assert_eq(names, ["Efeuranke", "Mohnkapsel", "Holunderdolde", "Gesenkte Fackel"])
	var real := Database.config(&"stone_config") as StoneConfig
	assert_eq([real.inscription_points, real.fitting_points, real.gilded_points, real.set_minutes, real.calendar],
			[cfg.inscription_points, cfg.fitting_points, cfg.gilded_points, cfg.set_minutes, cfg.calendar])


# --- visual -----------------------------------------------------------------------------------

func test_stone_visual_inscription_and_ornament() -> void:
	var c := _corpse("Marthe Quendel", 63, &"fever", &"s1_quendel", 37)
	var d := Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true)
	d.text = StoneDesignRules.render_text(Phase5Fixtures.inscription(&"i_garden"), c, cfg)
	var stone := StoneVisual.build(d, cfg)
	assert_not_null(stone)
	var model := stone.get_node(^"Model") as Node3D
	var marker := model.find_child("inscription", true, false) as Node3D
	assert_not_null(marker, "marker inscription")
	assert_not_null(model.find_child("ornament", true, false), "marker ornament")
	var inscription := stone.get_node(^"Inscription") as Node3D
	assert_not_null(inscription)
	var labels := inscription.find_children("*", "Label3D", true, false)
	assert_true(labels.size() >= d.text.size(), "one label per line (dates may split)")
	var joined := PackedStringArray()
	for node: Node in labels:
		var l := node as Label3D
		assert_true(l.shaded and not l.double_sided, "§8 label flags")
		assert_true(l.outline_size > 0 and l.outline_modulate.is_equal_approx(cfg.ink_color), "gilded: dark cut edge (W-UI readability)")
		assert_eq(l.alpha_cut, Label3D.ALPHA_CUT_DISCARD)
		assert_true(l.modulate.is_equal_approx(StoneVisual.gilded_fill(cfg)), "gilded → gold")
		assert_almost(l.visibility_range_end, 40.0)
		joined.append(l.text)
	assert_true(" ".join(joined).contains("Marthe Quendel") and " ".join(joined).contains("8. Nebelung 1834"))
	assert_true(inscription.position.z > marker.position.z, "in front of the face (surface_offset)")
	assert_not_null(stone.get_node_or_null(^"Ornament"), "relief")
	stone.free()
	var ink := Phase5Fixtures.design(&"stone_stele", &"i_rest")
	ink.text = StoneDesignRules.render_text(Phase5Fixtures.inscription(&"i_rest"), c, cfg)
	var plain := StoneVisual.build(ink, cfg)
	var first := plain.get_node(^"Inscription").get_child(0) as Label3D
	assert_true(first.modulate.is_equal_approx(cfg.ink_color), "ink colour")
	assert_eq(first.outline_size, 0, "§8: ink letters without outline")
	assert_null(plain.get_node_or_null(^"Ornament"))
	plain.free()
	var nameless := StoneVisual.build(Phase5Fixtures.design(&"stone_arch"), cfg)
	assert_null(nameless.get_node_or_null(^"Inscription"), "no inscription → no label")
	nameless.free()
	assert_null(StoneVisual.build(StoneDesign.new(), cfg))


func test_inscription_lines_fit_the_label_width() -> void:
	var c := _corpse("Wilhelmine Kunigunde Rabenstein", 70, &"fever", &"", 5)
	for shape: StoneShapeData in Phase5Fixtures.stone_shapes():
		var d := Phase5Fixtures.design(shape.id, &"i_rest")
		d.text = StoneDesignRules.render_text(Phase5Fixtures.inscription(&"i_rest"), c, cfg)
		var node := StoneVisual.build_inscription(d, shape.label_width, cfg)
		for child: Node in node.get_children():
			var l := child as Label3D
			var px := ThemeDB.fallback_font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x
			assert_true(px * l.pixel_size <= shape.label_width + 0.001 or l.font_size * l.pixel_size <= StoneVisual.EM_MIN + 0.0005,
					"%s: '%s' fits %.2f m" % [shape.id, l.text, shape.label_width])
		node.free()


# --- helpers ----------------------------------------------------------------------------------

func _points(d: StoneDesign, c: CorpseRecord) -> int:
	return StoneDesignRules.marker_points(d, c, eco, cfg)


func _corpse(name: String, age: int, cause: StringName, story: StringName, day: int) -> CorpseRecord:
	var r := Phase5Fixtures.corpse(age, cause, story, (day - 1) * 1440 + 460)
	r.display_name = name
	return r
