extends RefCounted
## The body of qa_p9_pck.gd – loaded at run time, after the autoloads exist (a -s script compiled with the game's classes
## in its signature would compile them before EventBus / Database are registered).
## W3 QA (docs/PHASE9_DESIGN.md §12 W3 „Prüfung im exportierten pck"): the Phase-9 content inside the exported Web pck,
## in the Compatibility renderer – the browser's path without Chromium. Run from the project root:
##   godot --headless --path . --export-debug "Web" build/webqa/index.html
##   GODOT=<godot> tools/godot_run.sh --main-pack build/webqa/index.pck --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 -s /abs/docs/reviews/phase9_wip/qa_p9_pck.gd -- \
##       --out=/abs/dir --fixture=/abs/tests/fixtures/saves_v7/slot_p8_day63_kindly.json
## (docs/ and tests/ are not in the pck: this script and the v7 fixture come from the file system.) Checks, one line each
## (PASS / FAIL) → <out>/pck_check_p9.txt, pictures → <out>/pck_p9_*.jpg:
## - the Phase-9 data in the pck: quests (steps, choices), the light list, letters, Brenneisen's offers, the large
##   requests with their parts, the Packed*Arrays of the new data (conditions, schedules' paths, night path np_sieber),
##   the new dialogues (stranger, kin_sieber_v, sieber_door) with their Phase-9 nodes;
## - the world from the Phase-8 end state: Phase 9 opens, the chain H1–H3 through the systems, row 4 open, a delivery's
##   pocket letter (the letter card), the Merkbuch pages „Vorhaben" / „Die Liste" / „Briefe", Brenneisen at the gate
##   (his figure on stranger_gate, the gate bell), Johann on his bench in the village (sit_bench), day and night
##   (the sun's energy at noon / midnight).

var _out := ""
var _fixture := ""
var _lines: PackedStringArray = []
var _fails := 0
var tree: SceneTree


func run(p_tree: SceneTree) -> void:
	tree = p_tree
	await _run()


func _check(ok: bool, what: String) -> void:
	_lines.append("%s %s" % ["PASS" if ok else "FAIL", what])
	print("[PCK9] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _run() -> void:
	await tree.process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--fixture="):
			_fixture = arg.trim_prefix("--fixture=")
	DirAccess.make_dir_recursive_absolute(_out)
	_check(not bool(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true)),
			"convert_text_resources_to_binary = false in the pck's project settings")
	_check_data()
	await _check_world()
	var f := FileAccess.open(_out.path_join("pck_check_p9.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n%d FAIL\n" % _fails)
	f.close()
	tree.quit(0 if _fails == 0 else 1)


# --- data ---------------------------------------------------------------------------------------------

func _check_data() -> void:
	var db := tree.root.get_node(^"Database")
	var quests: Array = db.call(&"quests")
	_check(quests.size() == 3, "quests in the pck: %d (q_who_knows, q_letters, q_case)" % quests.size())
	var steps := 0
	var choices := 0
	for q: Variant in quests:
		for s: Variant in (q as QuestData).steps:
			steps += 1
			choices += (s as QuestStepData).choices.size()
	_check(steps >= 16 and choices >= 10, "quest steps %d, choices %d" % [steps, choices])
	var main := db.call(&"quest", &"q_who_knows") as QuestData
	var open_cond := main.open_conditions if main != null else PackedStringArray()
	_check(main != null and not open_cond.is_empty(), "q_who_knows.open_conditions (PackedStringArray) %s" % str(open_cond))
	var list := load("res://data/quests/who_knows/list.tres") as LightListData
	_check(list != null and list.entries.size() == 6, "the light list: %d entries" % (list.entries.size() if list != null else -1))
	var letters: Array = db.call(&"letters")
	_check(letters.size() >= 16, "letters: %d" % letters.size())
	var conds := 0
	for l: Variant in letters:
		conds += (l as LetterData).conditions.size()
	_check(conds > 0, "letters' conditions (PackedStringArray) kept: %d" % conds)
	var offers: Array = db.call(&"stranger_offers")
	_check(offers.size() == 4, "Brenneisen's offers: %d" % offers.size())
	var large: Array = db.call(&"large_requests")
	var parts := 0
	for r: Variant in large:
		parts += (r as OrderData).parts.size()
	_check(large.size() == 12 and parts >= 30, "large requests %d with %d parts" % [large.size(), parts])
	for sched_id: StringName in [&"stranger", &"kin_sieber_v", &"watchman"]:
		var sched := db.call(&"schedule", sched_id) as NpcSchedule
		var paths := 0
		var entries := 0
		if sched != null:
			for e: ScheduleEntry in sched.entries:
				entries += 1
				paths += 1 if not e.path.is_empty() else 0
		_check(sched != null and entries > 0 and paths > 0, "schedule %s: %d entries, %d with a path" % [sched_id, entries, paths])
	var np := load("res://data/night/paths/np_sieber.tres") as NightPathData
	_check(np != null and np.visits.size() >= 3, "night path np_sieber: %d visits" % (np.visits.size() if np != null else -1))
	for dlg_id: StringName in [&"stranger", &"kin_sieber_v", &"sieber_door", &"kin_sieber", &"v_washer"]:
		var d := db.call(&"dialogue", dlg_id) as DialogueData
		var p9 := 0
		if d != null:
			for n: DialogueNode in d.nodes:
				for c: DialogueChoice in n.choices:
					for a: String in c.actions:
						if a.begins_with("quest_") or a.begins_with("stranger_") or a.begins_with("letter_") or a.begins_with("witness") \
								or a == "mark_seen":
							p9 += 1
				for a: String in n.actions:
					if a.begins_with("witness") or a.begins_with("add_clue:c_q") or a == "mark_seen":
						p9 += 1
		_check(d != null and (p9 > 0 or dlg_id == &"sieber_door"), "dialogue %s: %d nodes, %d Phase-9 actions" % [dlg_id,
				d.nodes.size() if d != null else -1, p9])


# --- the world ----------------------------------------------------------------------------------------

func _check_world() -> void:
	var saves := tree.root.get_node(^"SaveManager")
	saves.set("save_dir", "user://pck_qa_p9")
	var dir := ProjectSettings.globalize_path("user://pck_qa_p9")
	DirAccess.make_dir_recursive_absolute(dir)
	var text := FileAccess.get_file_as_string(_fixture)
	_check(text != "", "the v7 fixture read from %s" % _fixture)
	var f := FileAccess.open(dir.path_join("slot_3.json"), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var err: Error = await saves.call(&"load_game", 3)
	_check(err == OK, "slot_p8_day63_kindly loads in the pck (%s)" % error_string(err))
	if err != OK:
		return
	for i: int in 3:
		await tree.process_frame
	var world := tree.current_scene as WorldRoot
	var clock := tree.root.get_node(^"TimeManager")
	clock.set("running", false)
	var player := world.get_player()
	player.instant_actions = true
	var ui := world.get_node(^"UI") as UIRoot
	var quests := world.get_node_or_null(^"Systems/Quests") as Quests
	var who := world.get_node_or_null(^"Systems/WhoKnows") as WhoKnows
	var letters := world.get_node_or_null(^"Systems/Letters") as Letters
	var stranger := world.get_node_or_null(^"Systems/Stranger") as Stranger
	_check(quests != null and who != null and letters != null and stranger != null, "the four Phase-9 systems in the world")
	if quests == null or who == null or letters == null or stranger == null:
		return
	_check(quests.is_open() and quests.open_day() == 63, "Phase 9 open on loading (day %d)" % quests.open_day())
	# H1–H3 through the systems (the desk's / graves' / dialogues' calls).
	if who.read_block_reason(player.inventory) != "":
		player.inventory.add_item(&"lorenz_ledger_2", 1)
	who.read_kladde()
	who.compare_register()
	for g: GraveRecord in world.graveyard.graves():
		if who.can_compare(g.id):
			who.compare_grave(g.id)
	for e: StringName in [&"e_quendel", &"e_wernstein", &"e_hagedorn"]:
		who.witness(e)
	var journal := tree.get_first_node_in_group(&"journal") as JournalManager
	var picked: Array[StringName] = [&"c_q_dates", &"c_q_three_weeks", &"c_q_light_quendel", &"c_q_light_wernstein", &"c_q_light_hagedorn"]
	journal.try_link(picked)
	_check(quests.current_step(&"q_who_knows") == &"h4", "the chain at H4 (%s)" % quests.current_step(&"q_who_knows"))
	# Row 4 and a delivery with its pocket letter.
	tree.root.get_node(^"GameState").call(&"set_flag", &"linden_row4_granted", true)
	var expansion := world.get_node(^"Systems/Expansion") as ExpansionManager
	for id: String in ["obs_l_stump_13", "obs_l_bramble_13"]:
		expansion.clear(id, player.inventory)
	_check(expansion.is_unlocked(&"linden_row4"), "row 4 open")
	await _run_to(64, 7 * 60)
	var r := world.corpse_manager.try_daily_delivery(64)
	if r == null:
		await _run_to(64, 8 * 60)
		for rec: CorpseRecord in world.corpse_manager.records():
			if rec.location != CorpseRecord.LOCATION_BURIED and int(rec.arrival_total_minutes / 1440.0) + 1 == 64:
				r = rec
	_check(r != null, "a delivery on day 64")
	if r != null:
		(tree.get_first_node_in_group(&"corpse_care") as CorpseCare).exam_step(r.id, &"pockets")
		_check(r.letter_id != &"" and not letters.open_uids().is_empty(), "its pocket letter %s in the bag" % r.letter_id)
	var uid := letters.open_uids()[0] if not letters.open_uids().is_empty() else ""
	if uid != "":
		ui.open_panel(&"letter", {"uid": uid, "inventory": player.inventory, "player": player})
		await _shot("pck_p9_letter_card_web")
		_check(ui.get_panel(&"letter") != null and ui.get_panel(&"letter").is_open, "the letter card opens")
		ui.close_all()
	for page: StringName in [&"plans", &"list", &"letters"]:
		ui.open_panel(JournalManager.PANEL, journal.panel_context(page))
		await _shot("pck_p9_journal_%s_web" % page)
		var panel := ui.get_panel(JournalManager.PANEL)
		_check(panel != null and panel.is_open, "Merkbuch page %s opens" % page)
		ui.close_all()
	tree.root.get_node(^"UIState").call(&"clear")
	# Brenneisen at the gate (his first visit day, 14:10–15:30) and the gate bell.
	var visit := stranger.visit_days()[0] if not stranger.visit_days().is_empty() else 65
	var bell := world.get_node_or_null(^"StrangerBell")
	var rings := int(bell.get(&"rings")) if bell != null else -1
	await _run_to(visit, 14 * 60 + 25)
	var bren := world.get_node_or_null(^"Entities/npc_stranger_g") as Npc
	if bren != null:
		bren.refresh()
	var spot := world.get_waypoint(&"stranger_gate")
	_check(stranger.present(&"graveyard") and bren != null and bren.is_present(), "Brenneisen at the gate on day %d 14:25" % visit)
	if bren != null:
		_check(Vector2(bren.global_position.x, bren.global_position.z).distance_to(Vector2(spot.x, spot.z)) < 0.5,
				"his figure on stranger_gate (%.2f m)" % Vector2(bren.global_position.x, bren.global_position.z).distance_to(Vector2(spot.x, spot.z)))
	_check(bell != null and int(bell.get(&"rings")) > rings, "the gate bell rang (%d → %d)" % [rings, int(bell.get(&"rings")) if bell != null else -1])
	player.global_position = spot + Vector3(1.4, 0, -2.4)
	await _shot("pck_p9_brenneisen_gate_web")
	ui.open_panel(&"stranger", {"player": player, "inventory": player.inventory})
	await _shot("pck_p9_stranger_panel_web")
	_check(ui.get_panel(&"stranger") != null and ui.get_panel(&"stranger").is_open, "Brenneisen's panel opens")
	ui.close_all()
	tree.root.get_node(^"UIState").call(&"clear")
	# Johann on his bench in the village (from H4 daily, 14:00–16:00).
	await _run_to(visit + 1, 14 * 60 + 30)
	player.set_region(&"village")
	for i: int in 3:
		await tree.process_frame
	var johann := world.get_node_or_null(^"Regions/Village/Entities/npc_kin_sieber_v") as Npc
	if johann != null:
		johann.refresh()
	var seat := (world.get_node(^"Regions/Village") as RegionRoot).get_waypoint(&"v_sieber_bench")
	_check(johann != null and johann.is_present(), "Johann on his bench on day %d 14:30" % (visit + 1))
	if johann != null and johann.is_present():
		_check(Vector2(johann.global_position.x, johann.global_position.z).distance_to(Vector2(seat.x, seat.z)) < 0.4
				and johann.current_animation() == &"sit_bench", "on v_sieber_bench, clip %s" % johann.current_animation())
		player.global_position = johann.global_position + Vector3(1.6, 0, 1.6)
		await _shot("pck_p9_johann_bench_web")
	# Day and night.
	var sun := _sun(world)
	_check(sun != null, "the sun light")
	if sun != null:
		await _run_to(visit + 2, 12 * 60)
		for i: int in 10:
			await tree.process_frame
		var noon := sun.light_energy
		await _shot("pck_p9_village_noon_web")
		await _run_to(visit + 2, 23 * 60 + 30)
		for i: int in 10:
			await tree.process_frame
		var night := sun.light_energy
		await _shot("pck_p9_village_night_web")
		_check(noon > night + 0.2, "day / night: the sun %.2f at noon, %.2f at 23:30" % [noon, night])
	player.set_region(&"graveyard")


func _sun(world: Node) -> DirectionalLight3D:
	for n: Node in world.find_children("*", "DirectionalLight3D", true, false):
		if (n as DirectionalLight3D).visible:
			return n as DirectionalLight3D
	return null


func _run_to(day: int, minute: int) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var target := (day - 1) * 1440 + minute
	while int(clock.call(&"total_minutes")) < target:
		clock.call(&"advance", mini(20, target - int(clock.call(&"total_minutes"))))
		await tree.process_frame
	tree.root.get_node(^"UIState").call(&"clear")


func _shot(shot_name: String) -> void:
	for i: int in 30:
		await tree.process_frame
	var path := _out.path_join(shot_name + ".jpg")
	tree.root.get_viewport().get_texture().get_image().save_jpg(path, 0.88)
	print("[PCK9] ", path)
