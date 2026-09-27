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

const TIMEOUT := 600.0
const SLOT := 94
const SEED := 20260927
## Mutations per save and layer.
const JSON_CASES := 70
const NATIVE_CASES := 90
const TRUNCATIONS := 16
const V1_FIXTURES: PackedStringArray = ["slot_day3", "slot_day7_complete", "slot_interior"]
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
	var text := await _make_v2_save()
	await _fuzz_text(text, "v2")
	print("FUZZ v2: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_fuzz_v1_fixtures() -> void:
	for id: String in V1_FIXTURES:
		var text := FileAccess.get_file_as_string("res://tests/fixtures/saves_v1/%s.json" % id)
		assert_ne(text, "", id)
		await _fuzz_text(text, id)
	print("FUZZ v1: %d loaded, %d rejected" % [stats.ok, stats.rejected])


func test_version_and_meta_are_rejected_cleanly() -> void:
	var doc: Dictionary = JSON.parse_string(await _make_v2_save())
	for v: Variant in [3, 99, 0, -1, 2.5, "2", null, true]:
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

func _fuzz_text(text: String, label: String) -> void:
	# 1. Truncated files (a crash while writing without the tmp rename, a full disk).
	for i: int in TRUNCATIONS:
		var at := int(float(text.length()) * float(i + 1) / float(TRUNCATIONS + 1))
		await _load_text(text.substr(0, at), "%s truncated at %d" % [label, at])
	var doc: Variant = JSON.parse_string(text)
	assert_true(doc is Dictionary, label)
	if not doc is Dictionary:
		return
	# 2. JSON layer: a value of the file (inside the JSON.from_native envelope too) replaced.
	var paths: Array = []
	_collect_paths(doc, [], paths)
	for i: int in JSON_CASES:
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
	for i: int in NATIVE_CASES:
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
