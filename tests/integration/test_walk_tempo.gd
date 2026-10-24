extends TestCase
## G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1, docs/reviews/phase9_round1/tempo/tempo.md): every
## schedule walk of the villagers keeps the band of NpcConfig – walking 0.5–1.0 m per game minute (1.0–2.0 m/s real at
## 0.5 s per game minute, the walk clip at speed_scale 0.6–1.2), pushing / riding on the cart 0.4–0.7 (the push clip at
## 0.7–1.2); run and climb (the robber's flight, the fence) are no walks. Measured on the real world (WalkTempo):
## 1. the target pace is the pace of the clips (no sliding feet, no hurried steps);
## 2. every walk of the data schedules (data/npc/*: Phase 7 villagers, the Phase-8 overlays – visits, meetings, the
##    Kathreintanz, the Lichtgang, the night visits –, Veit, Hanne, Jakob, Brenneisen, Johann, the night watchman);
## 3. the runtime walks of ScheduleBuilder on every baked route (Visitors, Festivals, Apprentice, Friendship), the
##    Lichtgang procession, Jakob's day in the village and on the hill, the robber, Osric's unloading.

const TIMEOUT := 240.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
const SPM := 0.5

var world: WorldRoot


func before_each() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	tree.current_scene = world
	await tree.process_frame
	await tree.process_frame


func _band(g: StringName) -> Vector2:
	return WalkTempo.band(g)


func _check(e: ScheduleEntry, node: Node, label: String) -> float:
	var r := WalkTempo.measure(e, node, label)
	var b := _band(StringName(r.gait))
	assert_true(bool(r.ok), "%s %s→%s %s: %.1f m in %d min = %.2f m/min (band %.2f–%.2f, %s)" % [label, r.from, r.to,
			WalkTempo.hhmm(int(r.start)), float(r.length), int(r.travel), float(r.pace), b.x, b.y, r.gait])
	return float(r.pace)


func test_the_pace_is_the_pace_of_the_clips() -> void:
	var cfg := WalkTempo.config()
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	assert_not_null(npc)
	var spm := TimeManager.config.seconds_per_game_minute
	assert_almost(spm, SPM, 0.0001, "1 game minute = 0.5 s real")
	var walk_scale := cfg.walk_m_per_minute / spm / npc.walk_anim_speed
	var cart_scale := cfg.cart_m_per_minute / spm / npc.push_anim_speed
	assert_true(walk_scale > 0.9 and walk_scale < 1.1, "the walk clip at speed_scale %.2f (no sliding, no hurrying)" % walk_scale)
	assert_true(cart_scale > 0.9 and cart_scale < 1.1, "the cart clip at speed_scale %.2f" % cart_scale)
	for g: StringName in [WalkTempo.GAIT_WALK, WalkTempo.GAIT_CART]:
		var b := _band(g)
		var target := cfg.cart_m_per_minute if g == WalkTempo.GAIT_CART else cfg.walk_m_per_minute
		assert_true(b.x < target and target < b.y, "%s: target %.2f inside the band %.2f–%.2f" % [g, target, b.x, b.y])
		var clip := npc.push_anim_speed if g == WalkTempo.GAIT_CART else npc.walk_anim_speed
		assert_true(b.y / spm / clip <= 1.25, "%s: the fastest walk plays the clip at most 1.25 × (%.2f)" % [g, b.y / spm / clip])
		assert_true(b.x / spm / clip >= 0.6, "%s: the slowest at least 0.6 × (%.2f)" % [g, b.x / spm / clip])
	assert_almost(cfg.walk_m_per_minute, ScheduleBuilder._speed(), 0.0001, "the runtime walks take the same pace")


func test_every_data_walk_keeps_the_band() -> void:
	var rows := WalkTempo.data_walks(world)
	assert_true(rows.size() >= 130, "%d walks in data/npc" % rows.size())
	var npcs := {}
	for r: Dictionary in rows:
		npcs[r.npc] = true
		var node := WalkTempo.region_node(world, _entry_of(r))
		for id: String in r.path:
			assert_true(ScheduleBuilder.has_point(node, id), "%s: waypoint %s exists" % [r.npc, id])
		assert_true(float(r.length) > 0.5, "%s %s: a real way (%.1f m)" % [r.npc, WalkTempo.hhmm(int(r.start)), float(r.length)])
		var b := _band(StringName(r.gait))
		assert_true(bool(r.ok), "%s %s %s %s→%s: %.1f m in %d min = %.2f m/min (band %.2f–%.2f)" % [r.npc, r.flag, WalkTempo.hhmm(int(r.start)),
				r.from, r.to, float(r.length), int(r.travel), float(r.pace), b.x, b.y])
	for id: String in ["apprentice", "beggar", "carter", "grocer", "innkeeper", "kin_sieber_v", "mayor", "oldwoman", "peddler",
			"priest", "smith", "stranger", "surgeon", "trader", "washer", "watchman"]:
		assert_true(npcs.has(id), "%s has walks" % id)


func _entry_of(r: Dictionary) -> ScheduleEntry:
	var e := ScheduleEntry.new()
	e.region = StringName(str(r.region))
	return e


func test_runtime_walks_on_every_baked_route() -> void:
	var n := 0
	for key: Variant in world.visitor_routes:
		var route: PackedStringArray = world.visitor_route(str(key))
		if route.size() < 2:
			continue
		var up := ScheduleBuilder.walk(StringName(route[0]), route.slice(1), 600, &"", world)
		_check(up, world, "route %s up" % key)
		var back := route.duplicate()
		back.reverse()
		var down := ScheduleBuilder.walk(StringName(back[0]), back.slice(1), 900, &"", world)
		_check(down, world, "route %s down" % key)
		n += 1
	assert_true(n >= 50, "%d baked routes" % n)
	# A short hop between two care spots (the apprentice, ApprenticePlanner) and the minimum of one minute.
	var hop := ScheduleBuilder.walk(&"apprentice_board", PackedStringArray(["apprentice_box"]), 600, &"", world)
	assert_true(hop.travel_minutes >= 1)
	assert_true(ScheduleBuilder.path_length(hop.path, world) / float(hop.travel_minutes) <= _band(WalkTempo.GAIT_WALK).y + 0.0001,
			"short hops are not hurried")


func test_lichtgang_procession_at_the_graves_on_time() -> void:
	var fest := tree.get_first_node_in_group(Festivals.GROUP) as Festivals
	assert_not_null(fest, "Systems/Festivals")
	fest._days[Festivals.LIGHTS] = TimeManager.day
	fest.apply_procession()
	var plan := fest.procession_plan()
	assert_true(plan.size() >= 2, "Lenz and Jakob at least")
	var checked := 0
	for node: Node in tree.get_nodes_in_group(&"npc"):
		var npc := node as Npc
		if npc == null or npc.region_id != &"graveyard" or npc._runtime == null:
			continue
		for e: ScheduleEntry in npc._schedule().entries:
			if e.travel_minutes > 0 and e.path.size() >= 2:
				_check(e, world, "procession %s" % npc.name)
				checked += 1
		for p: Dictionary in plan:
			if StringName(str(p.npc)) == StringName(npc.name) or StringName(str(p.npc)) == npc.npc_id:
				var at := ScheduleResolver.entry_at(npc._schedule(), int(p.at_grave))
				assert_eq(at.travel_minutes, 0, "%s stands at the graves at %s (arrived)" % [npc.name, WalkTempo.hhmm(int(p.at_grave))])
	assert_true(checked >= 4, "%d procession walks" % checked)


func test_apprentice_village_and_hill() -> void:
	var app := tree.get_first_node_in_group(&"apprentice") as Apprentice
	if app == null:
		app = world.get_node_or_null("Systems/Apprentice") as Apprentice
	assert_not_null(app, "Systems/Apprentice")
	app.hire()
	var day := TimeManager.day + 1
	while not app.works_today(day):
		day += 1
	var hill := app.graveyard_schedule(day)
	var walks := 0
	for e: ScheduleEntry in hill.entries:
		if e.travel_minutes > 0 and e.path.size() >= 2:
			_check(e, world, "Jakob on the hill")
			walks += 1
	assert_true(walks >= 2, "up to the board and home (%d)" % walks)
	assert_eq(app.board_minute(), 505, "at the board at 08:25 as before")
	var village := world.get_node("Regions/Village")
	var vs := app.village_schedule(day)
	var vwalks := 0
	for e: ScheduleEntry in vs.entries:
		if e.travel_minutes > 0 and e.path.size() >= 2:
			_check(e, village, "Jakob in the village")
			vwalks += 1
			assert_false(String(e.path[0]).begins_with("v_in_") or String(e.path[e.path.size() - 1]).begins_with("v_in_"),
					"no walk out of the room 650 m away (%s)" % " ".join(e.path))
	assert_eq(vwalks, 2, "to the bridge in the morning, back of an evening")
	# Off the map on the Kutschweg: out of the village before he starts up the hill, back after he is down.
	var out_end := -1
	var back_start := -1
	for e: ScheduleEntry in vs.entries:
		if e.travel_minutes > 0:
			if out_end < 0:
				out_end = e.start_minute + e.travel_minutes
			else:
				back_start = e.start_minute
	assert_true(out_end <= app._cfg().arrive_minute, "at the bridge (%s) before the walk up (%s)" % [WalkTempo.hhmm(out_end),
			WalkTempo.hhmm(app._cfg().arrive_minute)])
	assert_true(back_start >= app.hill_home_minute(day), "back over the bridge (%s) after the way down (%s)" % [
			WalkTempo.hhmm(back_start), WalkTempo.hhmm(app.hill_home_minute(day))])


func test_robber_walks_and_digs_from_his_arrival() -> void:
	var robber := tree.get_first_node_in_group(NightRobber.GROUP) as NightRobber
	assert_not_null(robber, "Systems/NightRobber")
	var cfg := robber._cfg()
	for grave: String in ["l_16", "l_08", "l_01"]:
		robber._target = grave
		robber._apply_schedule()
		var npc := robber._npc() as Npc
		assert_not_null(npc, "npc_robber")
		var dig := -1
		for e: ScheduleEntry in npc._schedule().entries:
			if e.travel_minutes > 0 and e.path.size() >= 2:
				_check(e, world, "robber to %s" % grave)
			if e.animation == &"dig_night":
				dig = e.start_minute
		var walk_end := 0
		for e: ScheduleEntry in npc._schedule().entries:
			if e.travel_minutes > 0:
				walk_end = maxi(walk_end, e.start_minute + e.travel_minutes)
		assert_eq(dig, maxi(cfg.dig_from, walk_end), "%s: he digs once he is there" % grave)
		robber._flee_schedule()
		for e: ScheduleEntry in npc._schedule().entries:
			if e.travel_minutes > 0 and e.path.size() >= 2:
				assert_true(e.animation in WalkTempo.RUN_ANIMS, "the flight is a run / climb (%s)" % e.animation)


func test_osric_unloading_and_the_bell_walks() -> void:
	await SaveManager.new_game()
	world = tree.current_scene as WorldRoot
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	TimeManager.running = false
	var max_walk := _band(WalkTempo.GAIT_WALK).y
	var seen := {}
	TimeManager.set_time(TimeManager.day, 440)
	await tree.process_frame
	for step: int in range(0, 140):
		var minute_f := 440.0 + float(step) * 0.25
		npc._update_cargo(minute_f)
		var u: Dictionary = npc._unload
		if not bool(u.get("active", false)):
			continue
		var anim := StringName(str(u.get("anim", "")))
		if float(u.get("anim_t", -1.0)) >= 0.0 or anim == &"idle" or anim == &"ring_bell":
			continue
		seen[anim] = true
		var speed := float(u.get("speed", 0.0))
		var clip := npc.carry_anim_speed if anim == CartUnload.ANIM_CARRY else npc.walk_anim_speed
		assert_true(speed <= max_walk + 0.0001, "%.2f: %s at %.2f m/min (≤ %.2f)" % [minute_f, anim, speed, max_walk])
		assert_true(speed / SPM / clip <= 1.25, "%.2f: %s clip at %.2f ×" % [minute_f, anim, speed / SPM / clip])
	assert_true(seen.has(CartUnload.ANIM_WALK) and seen.has(CartUnload.ANIM_CARRY), "the steps and the carrying (%s)" % str(seen.keys()))


## The longer ways keep a villager away longer – the dialogue conditions (Village.villager_present: „[Zuhören]“, the
## round, the register copy) read the clock, not the last frame's state of the figure: the bots talk right after a
## time skip without a frame between (save_load9 = kindly9: Liesel's „[Zuhören]“ at her visit on the hill).
func test_villager_present_by_the_clock_between_frames() -> void:
	var village := world.get_node("Systems/Village") as Village
	var day := TimeManager.day
	var minute := TimeManager.minute_of_day
	var changes := 0
	for npc_id: StringName in [&"washer", &"innkeeper", &"mayor", &"surgeon"]:
		var npc: Npc = null
		for n: Node in tree.get_nodes_in_group(&"npc"):
			if n is Npc and (n as Npc).npc_id == npc_id and (n as Npc).region_id == &"village":
				npc = n as Npc
		assert_not_null(npc, "village figure %s" % npc_id)
		if npc == null:
			continue
		TimeManager.day = 50
		TimeManager.minute_of_day = 300
		npc.refresh()
		for m: int in range(300, 1440, 10):
			TimeManager.minute_of_day = m
			var stale := npc.is_present()
			var by_clock := village.villager_present(npc_id)
			npc.refresh()
			assert_eq(by_clock, npc.is_present(), "%s at %s: present by the clock = the next frame" % [npc_id, WalkTempo.hhmm(m)])
			if stale != npc.is_present():
				changes += 1
	assert_true(changes > 0, "the clock moved the figures between the checks (%d)" % changes)
	TimeManager.day = day
	TimeManager.minute_of_day = minute
