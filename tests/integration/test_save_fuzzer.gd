extends TestCase
## W3 QA save fuzzer (docs/PHASE3_DESIGN.md §5, §10): truncated and mutated v2 saves of a real
## Phase-3 game (decor, cleared obstacles, heard ghosts, corpse on the table) and the three v1
## fixtures. Every load either
##   • fails with ERR_* + the notification „Spielstand ist beschädigt.“ / „… neueren Version.“
##     and leaves the running game exactly as it was (collect_state unchanged, no half-apply), or
##   • succeeds and yields a consistent, saveable world (reputation 0…100, quality ≥ 0, the state
##     survives another save → load).
## Engine errors (script errors, push_error) fail the test through the runner; warnings are the
## expected reaction to damaged values. Deterministic (fixed seed).
## Phase 4 (P6, docs/PHASE4_DESIGN.md §10): the game save is now format v3 (migration 2 → 3 on
## every v2 / v1 load), and the four Phase-3 fixtures (tests/fixtures/saves_v2/) are fuzzed too.
## W3 (Phase 4): a v3 save of a Phase-4 game in mid-play (Phase4Bot "mixed", day 7 at 23:30: a
## corpse on the table with 2 of 4 steps, a juniper window, the braid taken, clues + an insight
## in the journal, Ilse at the wall with half her linen sold) is fuzzed as well; a loaded state
## also has its piety in −100…100 and only known clues / insights in the journal.
## Phase 5 (P6, docs/PHASE5_DESIGN.md §5, §10): the game save is format v4 (migration 3 → 4 on
## every older load); the six Phase-4 fixtures (tests/fixtures/saves_v3/) are fuzzed, and a v4
## save with Phase-5 parts (workshop, gathering, stonemasonry, grave designs, tool belt, coin
## ledger – written as the contract §5.1 shows them; nodes the world does not have yet are ignored
## with a warning) gets targeted mutations of those parts. W3 (Phase 5): also a real mid-Phase-5 v4
## save played by Phase5Bot (kiln burning, rack 2/3, alders in mixed stages, full tool belt).
## Phase 6 (P6, docs/PHASE6_DESIGN.md §5, §10): the game save is format v5 (migration 4 → 5 on every
## older load); the seven Phase-5 fixtures (tests/fixtures/saves_v4/) are fuzzed, and a v5 save with
## Phase-6 parts (buildings, ossuary, chapel, shed_store, record rooms / niches / cold windows /
## services, interior_id, the new stats and flags – written as the contract §5.1 shows them; nodes
## the world does not have yet are ignored with a warning) gets targeted mutations of those parts.
## A loaded state also has in_interior ⇔ interior_id and only rooms the world has (or the hut).
## W3 (Phase 6): also a real mid-Phase-6 v5 save played by Phase6Bot (reverent6, 4 days: a corpse
## in a niche with open cold window, one on the catafalque, a box lifted and not reinterred, the
## gravekeeper in the crypt, the shed half full); a loaded state also has at most one corpse per
## niche / table / catafalque, a niche corpse only in an open niche, levels 0…3, reinterred ⊆
## lifted ⊆ the liftable old graves, and no corpse in the crypt while the crypt is a site.
## Phase 7 (W3, docs/PHASE7_DESIGN.md §10 Save-Fuzzer): besides the v5 fixtures and the v6 parts (P6, at
## the end of the file) a real mid-Phase-7 v6 save (Phase7Bot anatomist7, 3 days from the Phase-6 end state;
## then the gravekeeper in the Holderkrug, specimens in the pack and in the cold drawer, a bundle with an
## open cold window, three active orders, the consecration day) gets targeted mutations (region_id, a
## uid twice / missing, specimens.records, order states, relationship values outside 0…100, returned ⊄
## harvested). A loaded state also has: every uid in at most one slot, the region one of the world's,
## relationships 0…100, known order states, returned ⊆ harvested.
## Phase 8 (P6, docs/PHASE8_DESIGN.md §5, §10): the game save is format v7 (migration 6 → 7 on every older
## load: kin_house, the grave fields disturbed / extra_lines, empty Phase-8 nodes, the 26 stats); the six Phase-7
## fixtures (tests/fixtures/saves_v6/) are fuzzed (with them the whole chain v1 → … → v7 runs on every older
## fixture above), and a v7 save gets targeted mutations of the Phase-8 parts (kin_house unknown / of the wrong
## type, disturbed / extra_lines garbage, nonsense in the Phase-8 node states, Phase-8 stats of the wrong type).
## A loaded state also has: every kin_house a name, extra_lines only strings, the Phase-8 stats integers.
## (W3 adds the real mid-Phase-8 v7 save and the checks of §10 that need P2–P7: one wish per grave, ≤ 3 open,
## the plan only for today, no mortsafe on an EMPTY grave, disturbed only on occupied graves.)

const TIMEOUT := 600.0
const SLOT := 94
const SEED := 20260927
## Mutations per save and layer.
const JSON_CASES := 70
const NATIVE_CASES := 90
const TRUNCATIONS := 16
const V1_FIXTURES: PackedStringArray = ["slot_day3", "slot_day7_complete", "slot_interior"]
## Share of the mutations per v2 fixture (four files – keeps the run time of one test bounded).
const V2_FIXTURE_SHARE := 0.5
## Phase-4 parts of the state that get extra native mutations in the Phase-4 save.
const P4_KEYS: PackedStringArray = ["journal", "night_trade", "npc_trader", "piety", "utilized", "prepared",
		"trader_sales", "story_id", "exam_done", "finds_revealed", "finds_lost", "traits_revealed", "washed", "dress",
		"laid_out", "harvested", "balm_windows", "stench_noted", "story_delivered", "story_last_day", "stench_day",
		"trader_known", "has_elder_key", "piety_last_day", "piety_used_day", "trader_met", "trader_tools_given"]
const P4_CASES := 80
## Share of the mutations per v3 fixture (six files).
const V3_FIXTURE_SHARE := 0.2
## Phase-5 parts of the state that get extra native mutations in the v4 save (§5.1).
const P5_KEYS: PackedStringArray = ["workshop", "gathering", "stonemasonry", "design", "tools", "built", "jobs",
		"goal_done", "evict_pending", "charges", "last_taken_day", "last_refresh_day", "next_id", "ready",
		"heard_design", "crafted", "stones_set", "coins_spent", "trees_felled", "coins_spent_license",
		"coins_spent_build", "coins_spent_osric", "coins_spent_ilse", "workshop_open", "bruch_license",
		"bought_pickaxe", "p5_intro", "remark_gold"]
const P5_CASES := 60
const P5_SHARE := 0.4
## Share of the mutations per v4 fixture (seven files).
const V4_FIXTURE_SHARE := 0.15
## Phase-6 parts of the state that get extra native mutations in the v5 save (§5.1).
const P6_KEYS: PackedStringArray = ["buildings", "ossuary", "chapel", "shed_store", "levels", "goal_done", "open_day", "spent",
		"lifted", "reinterred", "passage", "devotions", "services", "storage", "room", "slot_id", "cold_windows",
		"service_held", "service_day", "interior_id", "in_interior", "services_held", "devotions_held", "bones_lifted",
		"bones_reinterred", "niche_waits", "coins_spent_building", "buildings_open", "p6_intro", "building_sites_cleared",
		"roof_and_earth_complete"]
const P6_CASES := 60
const P6_SHARE := 0.3
## Phase-7 parts of the state that get extra native mutations in the v6 save (§5.1).
const P7_KEYS: PackedStringArray = ["village", "relationships", "village_shops", "orders", "specimens", "pult_store",
		"collection_shelf", "lectures", "deductions", "region_id", "uid", "records", "values", "states", "returned",
		"hidden_cause", "revealed_cause", "harvested"]
const P7_CASES := 60
const P7_SHARE := 0.25
const ORDER_STATES: Array[StringName] = [&"", &"offered", &"accepted", &"completed", &"failed"]
## Share of the mutations per v6 fixture (six files of the Phase-7 end states – each load is a full world).
const V6_FIXTURE_SHARE := 0.1
const OK_TEXTS: PackedStringArray = [SaveManager.TEXT_CORRUPT, SaveManager.TEXT_NEWER_VERSION]

var saves_dir := TestCase.user_dir("test_saves_fuzz")
var rng := RandomNumberGenerator.new()
var notes: PackedStringArray = []
var stats := {"ok": 0, "rejected": 0}


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	rng.seed = SEED
	notes.clear()
	EventBus.notification_requested.connect(_on_note)
	await SaveManager.new_game()


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_fuzz_v2_save_of_a_phase3_game() -> void:
	# Written by the current build: format v3 (the Phase-3 game state, saved in Phase 4).
	var text := await _make_v2_save()
	assert_eq(int((JSON.parse_string(text) as Dictionary).format_version), SaveFileIO.FORMAT_VERSION, "current format")
	await _fuzz_text(text, "v3")
	print("FUZZ v3: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v3_save_of_a_phase4_game() -> void:
	var text := await _make_v3_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v3; Phase 5: v4)")
	await _fuzz_text(text, "p4")
	# Extra native mutations on the Phase-4 parts only.
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P4_KEYS:
				return true
		return false)
	assert_true(paths.size() > 20, "Phase-4 paths in the state (%d)" % paths.size())
	for i: int in P4_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p4 native %s = %s" % [_path_text(path), str(bad)])
	print("FUZZ v3 (Phase 4): %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v3_fixtures() -> void:
	for id: String in Phase5Fixtures.SAVES_V3:
		var text := FileAccess.get_file_as_string(Phase5Fixtures.save_v3_path(id))
		assert_ne(text, "", id)
		await _fuzz_text(text, id, V3_FIXTURE_SHARE)
	print("FUZZ v3 fixtures: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v4_save_with_phase5_parts() -> void:
	var text := await _make_v4_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v4; Phase 6: v5)")
	await _fuzz_text(text, "p5", P5_SHARE)
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P5_KEYS:
				return true
		return false)
	assert_true(paths.size() > 30, "Phase-5 paths in the state (%d)" % paths.size())
	for i: int in P5_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p5 native %s = %s" % [_path_text(path), str(bad)])
	print("FUZZ v4 (Phase 5): %d loaded, %d rejected" % [stats.ok, stats.rejected])


## W3 (Phase 5): a real v4 save in mid-Phase 5, played by Phase5Bot (reverent5 from the Phase-4 end
## state, 4 days) and staged through the real entities: the kiln burning, 2 of 3 stones in the rack,
## alders felled on different days (stump / shoots / tree), the tool belt full. Targeted native
## mutations of the Phase-5 parts plus the JSON / native layers; the same two allowed outcomes.
func test_fuzz_v4_real_mid_phase5_save() -> void:
	var text := await _make_real_v4_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v4; Phase 6: v5)")
	await _fuzz_text(text, "p5 real", P5_SHARE)
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P5_KEYS:
				return true
		return false)
	assert_true(paths.size() > 40, "Phase-5 paths in the real state (%d)" % paths.size())
	for i: int in P5_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p5 real native %s = %s" % [_path_text(path), str(bad)])
	print("FUZZ v4 (real Phase-5 save): %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v4_fixtures() -> void:
	for id: String in Phase6Fixtures.SAVES_V4:
		var text := FileAccess.get_file_as_string(Phase6Fixtures.save_v4_path(id))
		assert_ne(text, "", id)
		assert_eq(int((JSON.parse_string(text) as Dictionary).format_version), 4, id)
		await _fuzz_text(text, id, V4_FIXTURE_SHARE)
	print("FUZZ v4 fixtures: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v5_save_with_phase6_parts() -> void:
	var text := await _make_v5_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v5)")
	assert_eq(SaveFileIO.FORMAT_VERSION, 7)  # Phase 7 W0: v6, Phase 8 W0: v7
	await _fuzz_text(text, "p6", P6_SHARE)
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P6_KEYS:
				return true
		return false)
	assert_true(paths.size() > 40, "Phase-6 paths in the state (%d)" % paths.size())
	for i: int in P6_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p6 native %s = %s" % [_path_text(path), str(bad)])
	print("FUZZ v5 (Phase 6): %d loaded, %d rejected" % [stats.ok, stats.rejected])


## W3 (Phase 6): Phase6Bot (reverent6) plays 4 days from slot_p5_day30_reverent; then on day 34:
## a corpse in a niche (open cold window), one on the catafalque, a box lifted and waiting, the
## gravekeeper in the crypt, the shed half full – saved (v5). Targeted native mutations of the
## Phase-6 parts (incl. cold_windows, room, slot_id, interior_id) plus the JSON / native layers.
func test_fuzz_v5_real_mid_phase6_save() -> void:
	var text := await _make_real_v5_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v5)")
	await _fuzz_text(text, "p6 real", P6_SHARE)
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P6_KEYS:
				return true
		return false)
	assert_true(paths.size() > 40, "Phase-6 paths in the real state (%d)" % paths.size())
	for i: int in P6_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p6 real native %s = %s" % [_path_text(path), str(bad)])
	# Targeted: two corpses claim the same niche / the catafalque; a niche of a higher crypt level;
	# the crypt back to a site with corpses inside; reinterred beyond lifted.
	for case: int in 6:
		var st := state.duplicate(true)
		var records: Array = st.nodes.corpse_manager.corpses
		var unburied := records.filter(func(r: Variant) -> bool: return r is Dictionary and str(r.get("location")) != "buried")
		var what := ""
		match case:
			0:
				for r: Dictionary in unburied:
					r["location"] = "niche"
					r["room"] = "crypt"
					r["slot_id"] = "niche_1"
				what = "all corpses in niche_1"
			1:
				for r: Dictionary in unburied:
					r["location"] = "catafalque"
					r["room"] = "chapel"
				what = "all corpses on the catafalque"
			2:
				for r: Dictionary in unburied:
					r["location"] = "niche"
					r["room"] = "crypt"
					r["slot_id"] = "niche_6"
				what = "a niche of crypt 3"
			3:
				st.nodes.buildings.levels = {"crypt": 0, "chapel": 0, "shed": 0}
				what = "every building back to a site"
			4:
				st.nodes.ossuary.reinterred = ["old_04", "old_06", "old_07", "old_02", "old_05", "old_03", "old_01"]
				what = "reinterred beyond lifted"
			5:
				for r: Dictionary in unburied:
					r["location"] = "table"
					r["room"] = "crypt"
				what = "all corpses on the crypt table"
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p6 real targeted: " + what)
	print("FUZZ v5 (real Phase-6 save): %d loaded, %d rejected" % [stats.ok, stats.rejected])


## W3 (Phase 7): a real mid-Phase-7 v6 save (see the header) – the JSON / native layers, native
## mutations of the Phase-7 parts and targeted ones; the same two allowed outcomes.
func test_fuzz_v6_real_mid_phase7_save() -> void:
	var text := await _make_real_v6_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (v6)")
	await _fuzz_text(text, "p7 real", P7_SHARE)
	var state := SaveFileIO.decode_state(doc.get("data"))
	var paths: Array = []
	_collect_paths(state, [], paths)
	paths = paths.filter(func(path: Array) -> bool:
		for part: Variant in path:
			if str(part) in P7_KEYS:
				return true
		return false)
	assert_true(paths.size() > 40, "Phase-7 paths in the real state (%d)" % paths.size())
	for i: int in P7_CASES:
		var path: Array = paths[rng.randi() % paths.size()]
		var st := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(st, path)
			bad = "<erased>"
		else:
			_set_path(st, path, bad)
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p7 real native %s = %s" % [_path_text(path), str(bad)])
	for case: int in 8:
		var st := state.duplicate(true)
		var what := ""
		var slots: Array = st.nodes.player.inventory.get("slots", [])
		match case:
			0:
				st.nodes.player["region_id"] = "atlantis"
				what = "an unknown region"
			1:
				st.nodes.player["region_id"] = 7
				what = "a region that is no string"
			2:
				var uid := ""
				for sl: Variant in slots:
					if sl is Dictionary and str((sl as Dictionary).get("uid", "")) != "":
						uid = str(sl.uid)
				for sl: Variant in slots:
					if sl is Dictionary and str((sl as Dictionary).get("id", "")) == "linen":
						sl["uid"] = uid
				if st.nodes.has("pult_store"):
					st.nodes.pult_store["storage"] = (st.nodes.player.inventory as Dictionary).duplicate(true)
				what = "a uid twice (pack and cold drawer)"
			3:
				for sl: Variant in slots:
					if sl is Dictionary:
						(sl as Dictionary).erase("uid")
				what = "every uid missing"
			4:
				for r: Variant in st.nodes.specimens.get("records", []):
					if r is Dictionary:
						r["state"] = "held"
						r["corpse_id"] = "corpse_9999"
						r["organ"] = "brain"
				what = "specimen records of an unknown corpse / organ"
			5:
				var states: Dictionary = st.nodes.orders.get("states", {})
				for id: Variant in states.keys():
					states[id] = "eaten"
				states["o_nonsense"] = "accepted"
				what = "unknown order states and ids"
			6:
				var values: Dictionary = st.nodes.relationships.get("values", {})
				var k := 0
				for id: Variant in values.keys():
					values[id] = -50 if k % 2 == 0 else 250
					k += 1
				what = "relationships outside 0…100"
			7:
				for r: Variant in st.nodes.corpse_manager.corpses:
					if r is Dictionary:
						r["returned"] = ["heart", "eyes", "hand", "lung"]
						r["harvested"] = []
				what = "returned ⊄ harvested"
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p7 real targeted: " + what)
	print("FUZZ v6 (real Phase-7 save): %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v2_fixtures() -> void:
	for id: String in Phase4Fixtures.SAVES_V2:
		var text := FileAccess.get_file_as_string(Phase4Fixtures.save_v2_path(id))
		assert_ne(text, "", id)
		await _fuzz_text(text, id, V2_FIXTURE_SHARE)
	print("FUZZ v2 fixtures: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v1_fixtures() -> void:
	for id: String in V1_FIXTURES:
		var text := FileAccess.get_file_as_string("res://tests/fixtures/saves_v1/%s.json" % id)
		assert_ne(text, "", id)
		await _fuzz_text(text, id)
	print("FUZZ v1: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_version_and_meta_are_rejected_cleanly() -> void:
	var doc: Dictionary = JSON.parse_string(await _make_v2_save())
	for v: Variant in [SaveFileIO.FORMAT_VERSION + 1, 99, 0, -1, 2.5, "2", null, true]:
		var d := doc.duplicate(true)
		d.format_version = v
		var err := await _load_doc(d, "format_version %s" % v)
		assert_ne(err, OK, "format_version %s rejected" % v)
		if typeof(v) in [TYPE_INT, TYPE_FLOAT] and float(v) == roundf(float(v)) and int(v) > SaveFileIO.FORMAT_VERSION:
			assert_eq(notes[notes.size() - 1] if not notes.is_empty() else "", SaveManager.TEXT_NEWER_VERSION, "newer version text")
	for key: String in ["day", "minute_of_day", "saved_unix", "scene", "game_version"]:
		var d := doc.duplicate(true)
		(d.meta as Dictionary).erase(key)
		assert_ne(await _load_doc(d, "meta without " + key), OK)
	var d2 := doc.duplicate(true)
	d2.meta.scene = "res://no/such/world.tscn"
	assert_ne(await _load_doc(d2, "unknown scene"), OK)


# --- the fuzzing ------------------------------------------------------------------------------

func _fuzz_text(text: String, label: String, share: float = 1.0) -> void:
	var truncations := maxi(1, roundi(TRUNCATIONS * share))
	# 1. Truncated files (a crash while writing without the tmp rename, a full disk).
	for i: int in truncations:
		var at := int(float(text.length()) * float(i + 1) / float(truncations + 1))
		await _load_text(text.substr(0, at), "%s truncated at %d" % [label, at])
	var doc: Variant = JSON.parse_string(text)
	assert_true(doc is Dictionary, label)
	if not doc is Dictionary:
		return
	# 2. JSON layer: a value of the file (inside the JSON.from_native envelope too) replaced.
	var paths: Array = []
	_collect_paths(doc, [], paths)
	for i: int in maxi(1, roundi(JSON_CASES * share)):
		var path: Array = paths[rng.randi() % paths.size()]
		var d: Dictionary = (doc as Dictionary).duplicate(true)
		var bad: Variant = _bad_value()
		_set_path(d, path, bad)
		await _load_doc(d, "%s json %s = %s" % [label, _path_text(path), str(bad)])
	# 3. Native layer: a value of the decoded state replaced, re-encoded like a real save.
	var state := SaveFileIO.decode_state((doc as Dictionary).get("data"))
	assert_false(state.is_empty(), label + " decodes")
	var native_paths: Array = []
	_collect_paths(state, [], native_paths)
	for i: int in maxi(1, roundi(NATIVE_CASES * share)):
		var path: Array = native_paths[rng.randi() % native_paths.size()]
		var s := state.duplicate(true)
		var bad: Variant = _bad_value()
		if rng.randi() % 4 == 0:
			_erase_path(s, path)
			bad = "<erased>"
		else:
			_set_path(s, path, bad)
		var d: Dictionary = (doc as Dictionary).duplicate(true)
		d.data = JSON.from_native(s)
		await _load_doc(d, "%s native %s = %s" % [label, _path_text(path), str(bad)])


func _load_doc(doc: Dictionary, what: String) -> Error:
	return await _load_text(JSON.stringify(doc, "\t", true, true), what)


## Writes `text` as the slot file and loads it; checks the two allowed outcomes.
func _load_text(text: String, what: String) -> Error:
	UIState.clear()
	var before := SaveManager.collect_state()
	SaveFileIO.ensure_dir(saves_dir)
	var f := FileAccess.open(SaveFileIO.slot_path(saves_dir, SLOT), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	notes.clear()
	var err: Error = await SaveManager.load_game(SLOT)
	if err != OK:
		stats.rejected += 1
		assert_true(not notes.is_empty() and notes[notes.size() - 1] in OK_TEXTS, "%s: rejected (%s) with a message, got %s" % [what, error_string(err), notes])
		assert_eq(SaveManager.collect_state(), before, what + ": a failed load changes nothing")
		assert_false(SaveManager.is_loading, what + ": not stuck loading")
		return err
	stats.ok += 1
	await _check_consistent(what)
	return err


func _check_consistent(what: String) -> void:
	var world := tree.current_scene as WorldRoot
	assert_not_null(world, what + ": a world")
	if world == null:
		return
	var rep := world.get_node("Systems/Reputation") as Reputation
	var score := world.get_node("Systems/CemeteryScore") as CemeteryScore
	assert_true(rep.value() >= 0 and rep.value() <= 100, "%s: reputation %d in 0…100" % [what, rep.value()])
	assert_true(score.total() >= 0, what + ": quality ≥ 0")
	var piety := world.get_node("Systems/Piety") as Piety
	assert_true(piety.value() >= -100 and piety.value() <= 100, "%s: piety %d in −100…100" % [what, piety.value()])
	assert_eq(GameState.get_stat(&"piety"), piety.value(), what + ": stored piety clamped")
	var journal := world.get_node("Systems/Journal") as JournalManager
	for id: StringName in journal.clues():
		assert_not_null(journal.clue_by_id(id), "%s: known clue %s" % [what, id])
	for id: StringName in journal.insights():
		assert_not_null(journal.insight_by_id(id), "%s: known insight %s" % [what, id])
	# Phase 5 (W3): the loaded Phase-5 parts are within their rules (no half-applied state).
	var masonry := world.get_node_or_null("Systems/Stonemasonry") as Stonemasonry
	var shop := world.get_node_or_null("Systems/Workshop") as Workshop
	if masonry != null and shop != null:
		assert_true(masonry.ready_stones().size() <= shop.workshop_config().ready_slots, what + ": rack ≤ its slots")
		var graves := {}
		for order: Dictionary in masonry.ready_stones():
			assert_false(graves.has(order.grave_id), "%s: one ready stone per grave" % what)
			graves[order.grave_id] = true
		for id: StringName in shop.built():
			assert_not_null(Database.station(id), "%s: known station %s" % [what, id])
	var gathering := world.get_node_or_null("Systems/Gathering") as GatherManager
	if gathering != null:
		for node_id: String in gathering.node_ids():
			var c := gathering.charges(node_id)
			assert_true(c >= 0 and c <= gathering.data_of(node_id).charges_max, "%s: %s charges %d in range" % [what, node_id, c])
	var belt := world.get_player().inventory.tools()
	for id: StringName in belt:
		assert_true(belt[id] >= 1 and belt[id] <= (Database.item(id) as ItemData).max_stack, "%s: belt %s × %d" % [what, id, belt[id]])
	# Phase 6 (P6): the gravekeeper's room is consistent – inside ⇔ a room id, and one this world has
	# (the hut is always valid).
	var player := world.get_player()
	assert_eq(player.in_interior, player.interior_id != &"", "%s: in_interior ⇔ interior_id (%s)" % [what, player.interior_id])
	if player.interior_id != &"" and player.interior_id != InteriorRoom.HUT:
		assert_not_null(InteriorRoom.find(tree, player.interior_id), "%s: room %s exists" % [what, player.interior_id])
	# Phase 6 (W3): the loaded corpses and buildings are within their rules.
	var buildings := world.get_node_or_null("Systems/Buildings") as Buildings
	var ossuary := world.get_node_or_null("Systems/Ossuary") as Ossuary
	if buildings != null and ossuary != null:
		var lv := buildings.levels()
		for id: StringName in lv:
			assert_true(int(lv[id]) >= 0 and int(lv[id]) <= 3, "%s: level %s = %d in 0…3" % [what, id, lv[id]])
		var lifted := ossuary.pending() + ossuary.reinterred()
		for id: String in ossuary.reinterred():
			assert_true(id in lifted, "%s: reinterred %s was lifted" % [what, id])
		for id: String in lifted:
			assert_true(id in Phase6Fixtures.LIFTABLE_IDS, "%s: lifted %s is liftable" % [what, id])
			assert_ne(world.graveyard.get_grave(id).state, GraveRecord.State.OLD, "%s: lifted %s is no OLD grave" % [what, id])
		var taken := {}
		for r: CorpseRecord in world.corpse_manager.records():
			if r.location in [CorpseRecord.LOCATION_NICHE, CorpseRecord.LOCATION_TABLE, CorpseRecord.LOCATION_CATAFALQUE]:
				var key := "%s/%s" % [r.location, r.slot_id]
				assert_false(taken.has(key), "%s: one corpse at %s (%s, %s)" % [what, key, r.id, taken.get(key, "")])
				taken[key] = r.id
			if r.location == CorpseRecord.LOCATION_NICHE:
				var niche := CryptNiche.find(tree, r.slot_id)
				assert_true(niche != null and niche.is_open(), "%s: %s in an open niche (%s)" % [what, r.id, r.slot_id])
			if r.room == &"crypt":
				assert_true(buildings.level(&"crypt") >= 1, "%s: %s in the crypt while it is a site" % [what, r.id])
			if r.location == CorpseRecord.LOCATION_CATAFALQUE:
				assert_true(buildings.level(&"chapel") >= 1, "%s: %s on the catafalque of a ruin" % [what, r.id])
	# Phase 7 (W3): uids, region, relationships, orders, returned ⊆ harvested.
	var seen_uids := {}
	for inv: Node in tree.root.find_children("*", "Inventory", true, false):
		for uid: String in (inv as Inventory).uids():
			assert_false(seen_uids.has(uid), "%s: uid %s in one slot only" % [what, uid])
			seen_uids[uid] = true
	assert_true(player.region_id in [&"graveyard", &"village"], "%s: region %s" % [what, player.region_id])
	if RegionRoot.find(tree, player.region_id) != null:
		assert_eq(RegionRoot.current(tree), player.region_id, what + ": the active region is the player's")
	var rel := world.get_node_or_null("Systems/Relationships") as Relationships
	if rel != null:
		for id: StringName in rel.met_ids():
			assert_true(rel.value(id) >= 0 and rel.value(id) <= 100, "%s: relationship %s = %d" % [what, id, rel.value(id)])
	var orders := world.get_node_or_null("Systems/Orders") as Orders
	if orders != null:
		for o: OrderData in orders.all_orders():
			assert_true(orders.state(o.id) in ORDER_STATES, "%s: order %s state %s" % [what, o.id, orders.state(o.id)])
		assert_true(orders.active().size() <= 4, "%s: at most 4 active orders" % what)
	for r: CorpseRecord in world.corpse_manager.records():
		for organ: StringName in r.returned:
			assert_true(organ in r.harvested, "%s: %s returned %s was harvested" % [what, r.id, organ])
	# Phase 8 (P6): the migrated / loaded Phase-8 record and grave fields are well-typed.
	for r: CorpseRecord in world.corpse_manager.records():
		assert_true(r.kin_house is StringName, "%s: %s kin_house is a name" % [what, r.id])
	for g: GraveRecord in world.graveyard.graves():
		for line: String in g.extra_lines:
			assert_true(line is String and line != "", "%s: %s extra line" % [what, g.id])
	for key: StringName in SaveMigration.V7_NEW_STATS:
		assert_true(GameState.stats.get(key) is int, "%s: stat %s is an int" % [what, key])
	assert_true(TimeManager.running, what + ": the clock runs")
	TimeManager.running = false
	# The loaded state is stable: save → load gives the same state.
	UIState.clear()
	var state := SaveManager.collect_state()
	if SaveManager.save_game(SLOT + 1) != OK:
		fail(what + ": cannot save the loaded game")
		return
	var err: Error = await SaveManager.load_game(SLOT + 1)
	assert_eq(err, OK, what + ": reload")
	TimeManager.running = false
	UIState.clear()
	assert_eq(SaveManager.collect_state(), state, what + ": stable after save → load")


# --- helpers ----------------------------------------------------------------------------------

## A Phase-3 game after two bot days + clearing and decor: the v2 file text (slot SLOT).
func _make_v2_save() -> String:
	var bot := Phase3Bot.new(&"diligent", tree)
	bot.bind()
	for i: int in 2:
		await bot.run_day()
	bot.bind()
	bot.inv().add_item(&"wood", 10)
	bot.inv().add_item(&"iron_fittings", 3)
	for id: String in bot.expansion.obstacle_ids(&"east"):
		var node := bot.expansion.obstacle(id)
		if node.can_interact(bot.player):
			node.interact(bot.player)
	bot.decorations.free_build = true
	bot.decorations.place(&"decor_bench_wood", Vector2i(40, 30), 0, null)
	bot.decorations.free_build = false
	TimeManager.set_time(TimeManager.day, 1335)
	for id: String in bot.ghosts.eligible_graves():
		bot.ghosts.listen(id, bot.player)
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	return FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT))


## A Phase-4 game in mid-play (see the header): the v3 file text (slot SLOT).
func _make_v3_save() -> String:
	var bot := Phase4Bot.new(&"mixed", tree)
	bot.bind()
	for i: int in 6:
		await bot.run_day()
	bot.bind()
	TimeManager.set_time(TimeManager.day, 470)
	await wait_frames(1)
	var record: CorpseRecord = null
	for r: CorpseRecord in bot.manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF:
			record = r
	assert_not_null(record, "day 7 delivery")
	if record != null:
		var table := bot._to_table(record)
		table.request_exam_step(CorpseRecord.STEP_CLOTHING)
		table.request_exam_step(CorpseRecord.STEP_HANDS)
		bot.inv().add_item(&"juniper", 1)
		table.request_balm()
		table.request_harvest(CorpseRecord.HARVEST_HAIR)
		assert_eq(record.exam_done.size(), 2, "2 of 4 steps")
		assert_false(record.balm_windows.is_empty(), "a juniper window")
		assert_true(record.is_harvested(CorpseRecord.HARVEST_HAIR), "the braid")
	TimeManager.set_time(TimeManager.day, 1410)
	await wait_frames(2)
	assert_true(bot.trade.is_present(), "Ilse at the wall")
	bot.inv().add_item(&"coin", 4)
	assert_true(bot.trade.buy(&"linen", 1, bot.inv()), "linen from Ilse")
	assert_false(bot.journal.insights().is_empty(), "an insight")
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	return FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT))


## The Phase-4 end state (v3 fixture day20_reverent) loaded and saved by this build (v4), with the
## Phase-5 parts of §5.1 written in: a charcoal job in the forge, two ready stones, gather nodes,
## designed graves, a full tool belt and a coin ledger (the v4 file text).
func _make_v4_save() -> String:
	assert_eq(Phase5Fixtures.install_save_v3("slot_p4_day20_reverent", saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	TimeManager.running = false
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT)))
	var state := SaveFileIO.decode_state(doc.data)
	var design := {"shape": "stone_master", "inscription": "i_garden", "ornament": "orn_elder", "gilded": true,
			"text": ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."]}
	var graves: Array = state.nodes.graveyard.graves
	for i: int in graves.size():
		(graves[i] as Dictionary)["design"] = design.duplicate(true) if i < 3 else {}
	state.nodes["workshop"] = {"built": ["mason", "loom"], "jobs": {"forge": {"recipe": "charcoal", "end_total": 38400}},
			"goal_done": false, "evict_pending": {"decor_bench_wood": 1}}
	state.nodes["gathering"] = {"gather_alder_1": {"charges": 0, "last_taken_day": 23, "last_refresh_day": 24},
			"gather_clay_1": {"charges": 2, "last_taken_day": 22, "last_refresh_day": 24}}
	state.nodes["stonemasonry"] = {"next_id": 4, "ready": [{"id": "stone_0003", "grave_id": "h_01", "design": design},
			{"id": "stone_0002", "grave_id": "plot_02", "design": {"shape": "stone_stele"}}], "heard_design": ["plot_04"]}
	(state.nodes.player.inventory as Dictionary)["tools"] = {"rake": 1, "shears": 1, "pliers": 1, "comb": 1, "scrub_brush": 1,
			"pickaxe_iron": 1, "shovel_iron": 1, "axe_iron": 1}
	var stats: Dictionary = state.autoloads.GameState.stats
	for key: String in ["crafted", "stones_set", "coins_spent", "trees_felled", "coins_spent_license", "coins_spent_build",
			"coins_spent_osric", "coins_spent_ilse"]:
		stats[StringName(key)] = 3
	var flags: Dictionary = state.autoloads.GameState.flags
	for key: String in ["workshop_open", "bruch_license", "bought_pickaxe", "p5_intro", "remark_gold"]:
		flags[StringName(key)] = true
	doc.data = JSON.from_native(state)
	return JSON.stringify(doc, "\t", true, true)


## The Phase-5 end state (v4 fixture day30_reverent) loaded and saved by this build (v5), with the
## Phase-6 parts of §5.1 written in: building levels, lifted / reinterred old graves, devotions,
## the shed store, a corpse in a niche with an open cold window, one on the catafalque with a held
## service, the gravekeeper in the crypt, the Phase-6 stats and flags (the v5 file text).
func _make_v5_save() -> String:
	assert_eq(Phase6Fixtures.install_save_v4("slot_p5_day30_reverent", saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	TimeManager.running = false
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "saved as the current format (Phase 7: v6)")
	var state := SaveFileIO.decode_state(doc.data)
	state.nodes["buildings"] = {"levels": {"crypt": 2, "chapel": 1, "shed": 1}, "goal_done": false, "open_day": 30,
			"spent": {"building": 75}, "evict_pending": {}}
	state.nodes["ossuary"] = {"lifted": ["old_04", "old_06", "old_07"], "reinterred": ["old_04", "old_06"], "passage": "sealed"}
	state.nodes["chapel"] = {"devotions": {"plot_04": 2}, "services": 3}
	state.nodes["shed_store"] = {"storage": {"slots": [{"id": "wood", "amount": 12}, {"id": "stone", "amount": 6}, {}], "currency": {}}}
	var total := TimeManager.total_minutes()
	var niche := {"id": "p6_fuzz_niche", "seed": 7, "display_name": "Anna Weber", "age": 61, "cause_id": "fever",
			"location": "niche", "room": "crypt", "slot_id": "niche_2", "cold_windows": [total - 300, -1, 400],
			"balm_windows": [total - 200, total + 400, 250], "arrival_total_minutes": total - 400, "last_decay_total": total,
			"freshness": 0.9, "service_held": false, "service_day": 0}
	var catafalque := {"id": "p6_fuzz_catafalque", "seed": 8, "display_name": "Jakob Roth", "age": 40, "cause_id": "fall",
			"location": "catafalque", "room": "chapel", "slot_id": "", "cold_windows": [total - 900, total - 600, 700],
			"arrival_total_minutes": total - 1000, "last_decay_total": total, "freshness": 0.7, "dress": "shroud",
			"service_held": true, "service_day": 30}
	(state.nodes.corpse_manager.corpses as Array).append_array([niche, catafalque])
	state.nodes.player["in_interior"] = true
	state.nodes.player["interior_id"] = "crypt"
	var stats: Dictionary = state.autoloads.GameState.stats
	for key: String in ["services_held", "devotions_held", "bones_lifted", "bones_reinterred", "niche_waits", "coins_spent_building"]:
		stats[StringName(key)] = 2
	var flags: Dictionary = state.autoloads.GameState.flags
	for key: String in ["buildings_open", "p6_intro", "building_sites_cleared"]:
		flags[StringName(key)] = true
	doc.data = JSON.from_native(state)
	return JSON.stringify(doc, "\t", true, true)


## Phase6Bot (reverent6) plays 4 days from slot_p5_day30_reverent; then on day 34 (morning): a
## corpse in a niche, one on the catafalque (serviced or not), a box lifted and waiting, the shed
## half full, the gravekeeper in the crypt – saved (the v5 file text).
func _make_real_v5_save() -> String:
	assert_eq(Phase6Fixtures.install_save_v4("slot_p5_day30_reverent", saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	var bot := Phase6Bot.new(&"reverent6", tree)
	bot.bind()
	for i: int in 4:
		await bot.run_day()
	bot.bind()
	var inv := bot.inv()
	TimeManager.set_time(TimeManager.day, 600)
	UIState.clear()
	for id: StringName in [&"crypt", &"chapel", &"shed"]:
		while bot.buildings.level(id) < (2 if id == &"crypt" else 1):
			var next := BuildingRules.next_level(bot.buildings.building(id), bot.buildings.level(id))
			for item: StringName in next.inputs:
				inv.add_item(item, int(next.inputs[item]))
			inv.add_item(&"coin", next.coins)
			assert_true(bot.buildings.upgrade(id, inv), "%s up" % id)
	# A box lifted and waiting.
	for id: String in ["old_02", "old_05", "old_03"]:
		if bot.ossuary.used() < bot.ossuary.capacity() and bot.graveyard.get_grave(id).state == GraveRecord.State.OLD:
			inv.add_item(&"bone_box", 1)
			assert_true(bot.ossuary.lift(id, inv), "lifted " + id)
			break
	assert_false(bot.ossuary.pending().is_empty(), "a box waits")
	# Two corpses: one into a niche, one onto the catafalque.
	var a := bot.manager.spawn_corpse()
	var b := bot.manager.spawn_corpse()
	a.dress = CorpseRecord.DRESS_SHROUD
	b.dress = CorpseRecord.DRESS_GOWN
	var cat := InteriorRoom.find(tree, &"chapel").get_node("Entities/Catafalque") as Catafalque
	assert_true(bot.manager.put_down(b.id, CorpseRecord.LOCATION_CATAFALQUE, cat.slot_node().global_transform, null, &"chapel"))
	var niche := CryptNiche.find(tree, "niche_2")
	assert_true(bot.manager.put_down(a.id, CorpseRecord.LOCATION_NICHE, niche.slot_node().global_transform, null, &"crypt", "niche_2"))
	assert_false(a.cold_windows.is_empty(), "open cold window")
	# The shed half full.
	var shed := ShedStore.find(tree).store()
	for item: StringName in [&"wood", &"stone", &"clay", &"workstone", &"iron_ore", &"linen"]:
		shed.add_item(item, 9)
	# Into the crypt.
	var door := BuildingDoor.find(tree, &"crypt")
	HutPortal.arrive(bot.player, door.room().spawn_transform(), true, &"crypt")
	assert_eq(bot.player.interior_id, &"crypt")
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	return FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT))


## Phase7Bot (anatomist7) plays 3 days from the Phase-6 end state; then (see the header): the v6 file
## text of a game in the Holderkrug with specimens in the pack and the cold drawer, an open cold window,
## three active orders and the consecration day.
func _make_real_v6_save() -> String:
	assert_eq(Phase7Fixtures.install_save_v5("slot_p6_day40_reverent", saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	var bot := Phase7Bot.new(&"anatomist7", tree)
	bot.bind()
	for i: int in 3:
		await bot.run_day()
	bot.bind()
	var inv := bot.inv()
	TimeManager.set_time(TimeManager.day, 840)
	UIState.clear()
	# Three orders active (the board's when the givers' are done).
	for id: StringName in [&"o_rosine_berries", &"o_esch_charcoal", &"o_quast_tincture", &"o_liesel_gowns", &"o_lenz_poor"]:
		if bot.orders.active().size() >= 3:
			break
		if bot.orders.state(id) == &"" or bot.orders.state(id) == &"offered":
			bot.orders.offer(id)
			bot.orders.accept(id)
	assert_true(bot.orders.active().size() >= 2, "active orders %s" % str(bot.orders.active()))
	# Specimens: a jar in the pack, a bundle in the cold drawer with an open window.
	var record: CorpseRecord = null
	for r: CorpseRecord in bot.manager.records():
		if r.location == CorpseRecord.LOCATION_BURIED:
			record = r
	var jar := Phase7Fixtures.specimen(&"liver", SpecimenRecord.CONTAINER_JAR, 0.8, record, TimeManager.total_minutes() - 300)
	var bundle := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_BUNDLE, 0.9, record, TimeManager.total_minutes() - 60)
	jar.uid = "sp_0901"
	bundle.uid = "sp_0902"
	var saved := bot.specimens.save_state()
	var all: Array = saved.get("records", [])
	all.append(jar.to_dict())
	all.append(bundle.to_dict())
	bot.specimens.load_state({"next": int(saved.get("next", 1)), "records": all})
	bot._free_slots(3)
	assert_true(inv.add_unique(Specimens.ITEM_JAR, jar.uid), "a jar in the pack")
	var store := InteriorRoom.find(tree, &"crypt").get_node_or_null("Entities/PultPlace/station_pult/PultStore") as PultStore
	if store != null and bot._pult_built():
		assert_true(store.store().add_unique(Specimens.ITEM_BUNDLE, bundle.uid), "a bundle in the cold drawer")
		bot.specimens.note_cold(bundle.uid, true)
		assert_false(bot.specimens.get_record(bundle.uid).cold_windows.is_empty(), "an open cold window")
	# The consecration day (flag = today) and the gravekeeper in the Holderkrug.
	GameState.set_flag(&"linden_consecration_day", TimeManager.day)
	await bot._travel(&"village")
	var door := HouseDoor.find(tree, &"door_inn")
	bot.player.global_transform = door.exit_transform()
	door.interact(bot.player)
	await bot._until_arrived()
	assert_eq([bot.player.region_id, bot.player.interior_id], [&"village", &"inn"], "in the Holderkrug")
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	return FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT))


## Phase5Bot (reverent5) plays 4 days from slot_p4_day20_reverent; then, on day 24: the kiln lit,
## two stones carved into the rack, an alder felled today (another one was felled days ago), every
## tool on the belt – saved (the v4 file text).
func _make_real_v4_save() -> String:
	assert_eq(Phase5Fixtures.install_save_v3("slot_p4_day20_reverent", saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	var bot := Phase5Bot.new(&"reverent5", tree)
	bot.bind()
	for i: int in 4:
		await bot.run_day()
	bot.bind()
	var inv := bot.inv()
	TimeManager.set_time(TimeManager.day, 600)
	UIState.clear()
	assert_true(bot.shop.is_built(&"forge"), "the forge stands")
	if not bot.shop.job_of(&"forge").is_empty() and bool(bot.shop.job_of(&"forge").ready):
		bot._collect_kiln()
	if bot.shop.job_of(&"forge").is_empty():
		inv.add_item(&"wood", 4)
		assert_true(bot._craft5(&"forge", &"charcoal"), "kiln lit")
	for id: StringName in [&"shovel_master", &"axe_master", &"pickaxe_master"]:
		if inv.count(id) == 0:
			inv.add_item(id, 1)
	for id: StringName in [&"rake", &"scrub_brush", &"comb", &"shears", &"pliers"]:
		if inv.count(id) == 0:
			inv.add_item(id, 1)
	var carved := 0
	for g: GraveRecord in bot.graveyard.graves():
		if carved >= 2 or g.state != GraveRecord.State.MARKED or g.corpse_id == "":
			continue
		var d := StoneDesign.new()
		d.shape = &"stone_master"
		d.inscription = &"i_rest"
		d.ornament = &"orn_ivy"
		d.gilded = true
		inv.add_item(&"workstone", 3)
		inv.add_item(&"stone", 2)
		inv.add_item(&"iron_fittings", 2)
		inv.add_item(&"clay", 1)
		inv.add_item(&"ink", 1)
		inv.add_item(&"gold_leaf", 1)
		if bot.masonry.order_block_reason(g.id, d, inv) == "" and bot._carve_with_panel(g.id, d) != "":
			carved += 1
	assert_eq(bot.masonry.ready_stones().size(), 2, "2 of 3 stones in the rack")
	var alder := bot._gather_node("gather_alder_2")
	if alder.can_interact(bot.player):
		alder.interact(bot.player)
	var stages := {}
	for k: int in [1, 2, 3, 4, 5]:
		stages[bot.gathering.stage("gather_alder_%d" % k)] = true
	assert_true(stages.size() >= 2, "alders in mixed stages %s" % str(stages.keys()))
	assert_false(bot.shop.job_of(&"forge").is_empty(), "the kiln burns")
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	return FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, SLOT))


func _bad_value() -> Variant:
	var options: Array = [null, "", "x", -1, 0, 1, 99999999, -3.5, 1e30, true, [], {}, [1, "a"], {"a": 1},
			{"type": "Vector2i", "args": ["q"]}, {"type": "StringName", "args": []}]
	return options[rng.randi() % options.size()]


static func _collect_paths(v: Variant, prefix: Array, out: Array) -> void:
	if v is Dictionary:
		for k: Variant in v:
			var p := prefix.duplicate()
			p.append(k)
			out.append(p)
			_collect_paths(v[k], p, out)
	elif v is Array:
		for i: int in (v as Array).size():
			var p := prefix.duplicate()
			p.append(i)
			out.append(p)
			_collect_paths(v[i], p, out)


static func _parent(root: Variant, path: Array) -> Variant:
	var node: Variant = root
	for i: int in path.size() - 1:
		node = node[path[i]]
	return node


## Typed containers (Array[StringName] …) are replaced by untyped copies first – a damaged file
## decodes to untyped containers as well, and writing a wrong type into a typed one would be
## the fuzzer's own engine error.
static func _set_path(root: Variant, path: Array, value: Variant) -> void:
	var parent: Variant = _parent(root, path)
	if (parent is Array and (parent as Array).is_typed()) or (parent is Dictionary and (parent as Dictionary).is_typed()):
		var copy: Variant = [] if parent is Array else {}
		if parent is Array:
			(copy as Array).append_array(parent)
		else:
			(copy as Dictionary).merge(parent)
		_set_path(root, path.slice(0, path.size() - 1), copy)
		parent = copy
	parent[path[path.size() - 1]] = value


static func _erase_path(root: Variant, path: Array) -> void:
	var parent: Variant = _parent(root, path)
	var key: Variant = path[path.size() - 1]
	if parent is Dictionary:
		(parent as Dictionary).erase(key)
	elif parent is Array:
		(parent as Array).remove_at(int(key))


static func _path_text(path: Array) -> String:
	var parts := PackedStringArray()
	for p: Variant in path:
		parts.append(str(p))
	return ".".join(parts)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


## Phase 7 (P6, docs/PHASE7_DESIGN.md §10): the seven v5 fixtures through the v5 → v6 migration and the
## JSON / native layers.
func test_fuzz_v5_fixtures() -> void:
	for id: String in Phase7Fixtures.SAVES_V5:
		var text := FileAccess.get_file_as_string(Phase7Fixtures.save_v5_path(id))
		assert_ne(text, "", id)
		assert_eq(int((JSON.parse_string(text) as Dictionary).format_version), 5, id)
		await _fuzz_text(text, id, V4_FIXTURE_SHARE)
	print("FUZZ v5 fixtures: %d loaded, %d rejected" % [stats.ok, stats.rejected])


## Phase 7 (P6): a v6 save (the Phase-6 world saves v6 now) with targeted mutations of the Phase-7 parts
## – region_id, the record fields hidden_cause / returned (⊄ harvested) / revealed_cause, a Phase-7
## system state with nonsense (orders states, relationship values out of 0…100, specimen records).
## Unknown regions read as the graveyard; returned ⊆ harvested after the load.
func test_fuzz_v6_phase7_parts() -> void:
	var text := await _make_v5_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "saved as the current format (Phase 7: v6, Phase 8: v7)")
	var state := SaveFileIO.decode_state(doc.get("data"))
	for case: int in 8:
		var st := state.duplicate(true)
		var what := ""
		var records: Array = st.nodes.corpse_manager.corpses if st.nodes.get("corpse_manager") is Dictionary \
				and st.nodes.corpse_manager.get("corpses") is Array else []
		match case:
			0:
				st.nodes.player["region_id"] = "moon"
				what = "unknown region"
			1:
				st.nodes.player["region_id"] = 7
				what = "region not a string"
			2:
				for r: Variant in records:
					if r is Dictionary:
						r["returned"] = ["heart", "eyes", 3, "heart"]
				what = "returned ⊄ harvested"
			3:
				for r: Variant in records:
					if r is Dictionary:
						r["hidden_cause"] = 12
						r["revealed_cause"] = ["x"]
				what = "hidden / revealed cause of the wrong type"
			4:
				st.nodes["orders"] = {"states": {"o_fenner_linden": "eaten", "nope": "accepted"}, "board_day": "x"}
				what = "orders nonsense"
			5:
				st.nodes["relationships"] = {"values": {"innkeeper": 500, "smith": -40}, "met": "all"}
				what = "relationships out of range"
			6:
				st.nodes["specimens"] = {"next": -3, "records": [{"uid": "sp_0001", "state": "eaten"}, 5]}
				what = "specimen records"
			7:
				st.nodes["village"] = {"open_day": "x", "donation_steps": 99, "goal_done": "yes"}
				what = "village nonsense"
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p7 targeted: " + what)
	print("FUZZ v6 (Phase 7 parts): %d loaded, %d rejected" % [stats.ok, stats.rejected])


## Phase 8 (P6, docs/PHASE8_DESIGN.md §10): the six v6 fixtures through the v6 → v7 migration and the JSON /
## native layers.
func test_fuzz_v6_fixtures() -> void:
	for id: String in Phase8Fixtures.SAVES_V6:
		var text := FileAccess.get_file_as_string(Phase8Fixtures.save_v6_path(id))
		assert_ne(text, "", id)
		assert_eq(int((JSON.parse_string(text) as Dictionary).format_version), 6, id)
		await _fuzz_text(text, id, V6_FIXTURE_SHARE)
	print("FUZZ v6 fixtures: %d loaded, %d rejected" % [stats.ok, stats.rejected])


## Phase 8 (P6): a v7 save with targeted mutations of the Phase-8 parts (§5.1). Nodes the world does not have
## yet (W-Welt adds them in W2) are ignored with a warning; the record / grave fields and the stats load tolerantly.
func test_fuzz_v7_phase8_parts() -> void:
	var text := await _make_v5_save()
	var doc: Dictionary = JSON.parse_string(text)
	assert_eq(int(doc.format_version), 7, "saved as v7")
	var state := SaveFileIO.decode_state(doc.get("data"))
	for case: int in 10:
		var st := state.duplicate(true)
		var what := ""
		var records: Array = st.nodes.corpse_manager.corpses if st.nodes.get("corpse_manager") is Dictionary \
				and st.nodes.corpse_manager.get("corpses") is Array else []
		var graves: Array = st.nodes.graveyard.graves if st.nodes.get("graveyard") is Dictionary \
				and st.nodes.graveyard.get("graves") is Array else []
		match case:
			0:
				for r: Variant in records:
					if r is Dictionary:
						r["kin_house"] = "house_atlantis"
				what = "kin_house unknown"
			1:
				for r: Variant in records:
					if r is Dictionary:
						r["kin_house"] = [3, "house_kehr"]
				what = "kin_house of the wrong type"
			2:
				for g: Variant in graves:
					if g is Dictionary:
						g["disturbed"] = "yes"
						g["extra_lines"] = [7, "", null, "Ruhe sanft"]
				what = "disturbed / extra_lines garbage"
			3:
				for g: Variant in graves:
					if g is Dictionary:
						g["disturbed"] = true
						g["extra_lines"] = "Ruhe sanft"
				what = "disturbed on every grave, extra_lines a string"
			4:
				st.nodes["visitors"] = {"plan_day": "x", "plan": [{"visit_id": 3, "kin_id": "kin_x", "graves": "l_02"}],
						"wishes": [{"wish_id": "w_1", "grave_id": "nowhere"}, 5], "tips_on_stone": {"l_02": [-4, 9]}}
				what = "visitors: plan kaputt, wish on an unknown grave"
			5:
				st.nodes["apprentice"] = {"hired": "yes", "levels": {"rake": 7, "weed": -1}, "board": "x", "morale": 99}
				st.nodes["apprentice_box"] = {"storage": 3, "coins": -12}
				what = "apprentice: levels outside 0…2, negative coins in the box"
			6:
				st.nodes["friendship"] = {"steps": {"innkeeper": 9, "smith": -2}, "owed": 4, "favor_day": "x"}
				st.nodes["festivals"] = {"days": {"fest_lights": 3, "fest_kathrein": "x"}, "state": {"fest_lights": "eaten"}}
				what = "friendship steps > 3, a fest day in the past"
			7:
				st.nodes["npc_life"] = {"open_day": -5, "events": [1, 2], "goal_done": "maybe"}
				st.nodes["wanderers"] = {"alms": -3, "peddler_stock": 7}
				st.nodes["night_robber"] = {"target": 12, "encounters": "two", "fate": "hanged"}
				st.nodes["night_paths"] = {"observed": "all", "deaths": {"np_ott": "x"}}
				what = "night and village nonsense"
			8:
				for key: StringName in SaveMigration.V7_NEW_STATS:
					st.autoloads.GameState.stats[key] = "many" if int(String(key).length()) % 2 == 0 else -1.5
				what = "Phase-8 stats of the wrong type"
			9:
				st.autoloads.GameState.flags[&"p8_open"] = "x"
				st.autoloads.GameState.flags[&"p8_open_day"] = [53]
				st.autoloads.GameState.flags[&"ott_dead"] = {"day": 58}
				what = "Phase-8 flags of the wrong type"
		var d: Dictionary = doc.duplicate(true)
		d.data = JSON.from_native(st)
		await _load_doc(d, "p8 targeted: " + what)
	print("FUZZ v7 (Phase 8 parts): %d loaded, %d rejected" % [stats.ok, stats.rejected])
