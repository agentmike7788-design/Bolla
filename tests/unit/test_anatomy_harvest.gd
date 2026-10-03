extends TestCase
## P4 (docs/PHASE7_DESIGN.md §2.6, §2.11, §3.4, §10): a specimen at the crypt table – CorpseCare
## organ_block_reason / harvest_organ and MorgueTable.request_organ. The depiction stays implied: the cloth
## covers the whole corpse while the action runs, the dark veil comes and goes (screen_veil_changed), the
## tool-sound hook is asked but plays nothing; the action bar carries the one quiet line. Effects per organ
## (§2.6 table): piety, reputation event, quality at the marker (EconomyConfig.harvest_malus), the ghost
## (GhostMood.robbed_penalty); no full_prep bonus; clarity = freshness at the end; at most 3 per corpse.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"
const ORGANS: Array[StringName] = [&"heart", &"lung", &"stomach", &"liver", &"kidneys", &"eyes", &"hand"]

var world: Node3D
var manager: CorpseManager
var table: MorgueTable
var care: CorpseCare
var specimens: Specimens
var piety: Piety
var rep: Reputation
var player: Player
var veil: Array = []
var notes: Array = []
var harvested: Array = []
var covered_during: Array = []
var _injected: Array[StringName] = []


func before_each() -> void:
	GameState.reset()
	GameState.stats[&"piety"] = 0
	GameState.stats[&"reputation"] = 50
	TimeManager.load_state({"day": 4, "minute_of_day": 600})
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase7Fixtures.item(id)
			_injected.append(id)
	world = Node3D.new()
	world.name = "World"
	var corpses := Node3D.new()
	corpses.name = "Corpses"
	world.add_child(corpses)
	manager = CorpseManager.new()
	manager.name = "CorpseManager"
	manager.tables = Phase7Fixtures.corpse_tables()
	manager.economy = Phase7Fixtures.economy_config()
	manager.crypt_config = Phase6Fixtures.crypt_config()
	manager.prep_config = Phase4Fixtures.prep_config()
	manager.container_path = ^"../Corpses"
	world.add_child(manager)
	world.add_child(Phase6Fixtures.crypt_at(1))
	table = (load(TABLE_SCENE) as PackedScene).instantiate() as MorgueTable
	table.name = "crypt_table"
	table.room = &"crypt"
	table.requires_level = 1
	world.add_child(table)
	care = CorpseCare.new()
	care.exam_config = Phase4Fixtures.exam_config()
	care.prep_config = Phase4Fixtures.prep_config()
	care.utilization_config = Phase4Fixtures.utilization_config()
	care.tables = Phase7Fixtures.corpse_tables()
	care.finds = Phase4Fixtures.finds()
	care.anatomy_config = Phase7Fixtures.anatomy_config()
	world.add_child(care)
	specimens = Specimens.new()
	specimens.config = Phase7Fixtures.anatomy_config()
	specimens.findings = Phase7Fixtures.findings()
	world.add_child(specimens)
	piety = Piety.new()
	piety.config = Phase7Fixtures.piety_config()
	world.add_child(piety)
	rep = Reputation.new()
	rep.config = Phase7Fixtures.reputation_config()
	world.add_child(rep)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	player.instant_actions = true
	tree.root.add_child(world)
	manager._last_delivery_day = 99
	veil.clear()
	notes.clear()
	harvested.clear()
	covered_during.clear()
	EventBus.screen_veil_changed.connect(_on_veil)
	EventBus.notification_requested.connect(_on_note)
	EventBus.corpse_harvested.connect(_on_harvested)
	EventBus.timed_action_started.connect(_on_action_started)


func after_each() -> void:
	EventBus.screen_veil_changed.disconnect(_on_veil)
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.corpse_harvested.disconnect(_on_harvested)
	EventBus.timed_action_started.disconnect(_on_action_started)
	if is_instance_valid(world):
		world.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	GameState.reset()


func _on_veil(active: bool) -> void:
	veil.append(active)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _on_harvested(id: String, kind: StringName, item: StringName) -> void:
	harvested.append([id, kind, item])


func _on_action_started(label: String, _duration: float) -> void:
	var node := manager.get_corpse_node(table.corpse_id)
	covered_during.append([label, node.is_covered() if node != null else false,
			node.dress_visual() if node != null else &""])


func _on_table(traits: Array[StringName] = [], freshness: float = 1.0) -> CorpseRecord:
	var r := Phase4Fixtures.corpse(traits, &"fever", freshness, TimeManager.total_minutes())
	r.id = ""
	var out := manager.spawn_corpse(r, table.slot_transform(), &"ground")
	manager.put_down(out.id, &"table", table.slot_transform(), table.slot_node(), &"crypt")
	return out


func _stock(n: int = 3) -> void:
	var inv := player.inventory
	inv.add_item(&"anatomy_case", 1)
	for id: StringName in [&"prep_jar", &"prep_jar_small", &"spirits", &"linen", &"beeswax"]:
		inv.add_item(id, n)


func _know() -> void:
	GameState.set_flag(&"anatomy_known", true)


func test_no_card_without_the_case_or_outside_the_crypt() -> void:
	await wait_frames(1)
	var r := _on_table()
	_stock()
	assert_eq(care.organ_block_reason(r.id, &"heart", &"jar", player.inventory), "-", "anatomy_known missing")
	table.interact(player)
	table.request_organ(&"heart", &"jar")
	assert_eq([r.harvested, veil, notes], [[] as Array[StringName], [], []], "silent: no card, nothing happens")
	_know()
	assert_eq(care.organ_block_reason(r.id, &"heart", &"jar", player.inventory), "")
	r.room = &""
	assert_eq(care.organ_block_reason(r.id, &"heart", &"jar", player.inventory), "-", "only the crypt table")
	assert_eq(care.organ_block_reason("nobody", &"heart", &"jar", player.inventory), "-")


func test_request_organ_covers_veils_and_takes_a_named_jar() -> void:
	await wait_frames(1)
	_know()
	var r := _on_table([], 0.85)
	_stock()
	var cues: Array = []
	table.sound_hook = func(cue: StringName) -> void: cues.append(cue)
	table.interact(player)
	var start := TimeManager.total_minutes()
	table.request_organ(&"heart", &"jar")
	assert_eq(TimeManager.total_minutes() - start, 20, "20 min")
	assert_eq(covered_during, [[MorgueTable.TEXT_ORGAN, true, &"shroud"]], "the cloth covers her during the action")
	assert_eq(veil, [true, false], "the veil comes and goes")
	assert_eq(cues, [&"anatomy_tool"], "the sound hook is asked (silent in Phase 7)")
	assert_eq(table.last_sound_cue, &"anatomy_tool")
	var node := manager.get_corpse_node(r.id)
	assert_eq([node.is_covered(), node.dress_visual()], [false, &""], "afterwards: no cloth, the body unchanged")
	assert_false(table.is_covering())
	assert_eq(r.harvested, [&"heart"] as Array[StringName])
	var uids := player.inventory.uids(&"specimen_jar")
	assert_eq(uids.size(), 1)
	var spec := specimens.get_record(uids[0])
	assert_almost(spec.clarity_at_harvest, r.freshness, 1e-6, "clarity = freshness at the end")
	assert_eq(harvested, [[r.id, &"heart", &"specimen_jar"]])
	assert_has(notes, "Ein Glas mehr. Auf dem Etikett steht ihr Name.")
	assert_eq([GameState.get_stat(&"piety"), GameState.get_stat(&"reputation")], [-8, 47], "heart: piety −8, reputation −3")
	assert_eq(GameState.get_stat(&"specimens_taken"), 1)
	assert_eq(int(GameState.get_flag(&"piety_used_day", 0)), TimeManager.day)
	assert_false(player.is_busy())


func test_eyes_and_hand_lines_and_containers() -> void:
	await wait_frames(1)
	_know()
	_on_table()
	_stock()
	table.interact(player)
	table.request_organ(&"eyes", &"bundle")
	assert_has(notes, SpecimenRules.TEXT_ONLY_JAR)
	assert_eq(veil, [], "refused before any veil")
	table.request_organ(&"eyes", &"jar")
	table.request_organ(&"hand", &"bundle")
	assert_eq([covered_during[0][0], covered_during[1][0]], [MorgueTable.TEXT_ORGAN_EYES, MorgueTable.TEXT_ORGAN_HAND])
	assert_eq(player.inventory.count(&"prep_jar_small"), 2, "the small dark jar")
	assert_eq(player.inventory.uids(&"specimen_bundle").size(), 1, "the hand in linen")
	assert_has(notes, "Ein Bündel in Leinen. Es hält nicht lange.")
	assert_eq([GameState.get_stat(&"piety"), GameState.get_stat(&"reputation")], [-24, 40], "eyes / hand: −12 and −5 each")


func test_at_most_three_per_corpse() -> void:
	await wait_frames(1)
	_know()
	var r := _on_table()
	r.harvested.append(&"hair")
	_stock(5)
	table.interact(player)
	for organ: StringName in [&"heart", &"lung", &"stomach", &"liver"]:
		table.request_organ(organ, &"jar")
	assert_eq(r.harvested, [&"hair", &"heart", &"lung", &"stomach"] as Array[StringName])
	assert_has(notes, "Mehr nimmst du ihr nicht.")


func test_effects_per_organ_of_the_table() -> void:
	await wait_frames(1)
	_know()
	var a := Phase7Fixtures.anatomy_config()
	var eco := Phase7Fixtures.economy_config()
	for organ: StringName in ORGANS:
		GameState.stats[&"piety"] = 0
		GameState.stats[&"reputation"] = 50
		var r := _on_table()
		_stock(1)
		var container: StringName = &"bundle" if organ == &"hand" else &"jar"
		assert_ne(care.harvest_organ(r.id, organ, container, player.inventory), "", String(organ))
		var row := a.organ(organ)
		var heavy := organ in [&"eyes", &"hand"]
		assert_eq(GameState.get_stat(&"piety"), -12 if heavy else (-8 if organ == &"heart" else -6), "%s piety" % organ)
		assert_eq(GameState.get_stat(&"reputation"), 45 if heavy else 47, "%s reputation" % organ)
		assert_eq(int(row.quality), eco.harvest_malus[organ], "%s quality" % organ)
		var with_organ := GraveQuality.compute(r, &"wooden_cross", eco)
		r.harvested.clear()
		var without := GraveQuality.compute(r, &"wooden_cross", eco)
		assert_eq(with_organ - without, -3 if heavy else -2, "%s quality at the marker" % organ)
		r.harvested.append(organ)
		assert_eq(GhostMood.robbed_penalty(r, null, a), -8 if heavy else -5, "%s ghost" % organ)
		r.location = CorpseRecord.LOCATION_BURIED  # frees the table for the next one


func test_no_full_prep_bonus_after_a_specimen() -> void:
	await wait_frames(1)
	_know()
	var r := _on_table()
	_stock()
	player.inventory.add_item(&"scrub_brush", 1)
	player.inventory.add_item(&"comb", 1)
	player.inventory.add_item(&"shroud", 1)
	table.interact(player)
	table.request_organ(&"liver", &"jar")
	var before := GameState.get_stat(&"piety")
	table.request_wash()
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	table.request_lay_out()
	assert_true(r.is_fully_prepared())
	assert_eq(GameState.get_stat(&"piety"), before, "no „Voll hergerichtet\" bonus")
	assert_eq(care.organ_block_reason(r.id, &"heart", &"jar", player.inventory), SpecimenRules.TEXT_DRESSED, "dressed: closed")


func test_too_late_for_a_specimen() -> void:
	await wait_frames(1)
	_know()
	var r := _on_table([], 0.25)
	_stock()
	assert_eq(care.organ_block_reason(r.id, &"heart", &"jar", player.inventory), SpecimenRules.TEXT_TOO_LATE)
	assert_eq(care.harvest_organ(r.id, &"heart", &"jar", player.inventory), "")
	assert_eq(r.harvested, [] as Array[StringName])
