extends TestCase
## P1 (docs/PHASE8_DESIGN.md §2.1.3, §3.4, §10): the reaction remarks – an event noted in NpcLife is the
## first remark for two days (NpcLifeConfig.reactions), only for the people noted with it ([] = everyone)
## and only when the villager has a line for it; precedence event > friend > piety > specimens > reputation;
## nothing before p8_open; Relationships.remark once per day asks ReactionRules first; the real villager
## data carries the §2.1.3 lead lines.

var life: NpcLife
var rel: Relationships
var holder: Node


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	GameState.stats[&"reputation"] = 40
	GameState.stats[&"piety"] = 0
	TimeManager.day = 55
	TimeManager.minute_of_day = 600
	holder = Node.new()
	holder.name = "P8ReactWorld"
	tree.root.add_child(holder)
	life = NpcLife.new()
	life.config = Phase8Fixtures.npc_life_config()
	holder.add_child(life)
	rel = Relationships.new()
	rel.config = Phase8Fixtures.relationship_config()
	for v: VillagerData in Phase8Fixtures.villagers():
		rel.villagers[v.npc_id] = v
	holder.add_child(rel)


func after_each() -> void:
	holder.free()
	GameState.reset()
	TimeManager.reset()


func _open() -> void:
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)


func test_event_remark_for_two_days_only_after_p8_open() -> void:
	var smith := Phase8Fixtures.villager_data(&"smith")
	life.note_event(&"apprentice_hired")
	assert_eq(life.reaction_for(&"smith"), &"", "before p8_open nothing")
	assert_eq(rel.remark_text(&"smith", 55), smith.remarks[&"rep_respected"][0], "Phase 7 below")
	_open()
	assert_eq(life.reaction_for(&"smith"), &"apprentice_hired")
	assert_eq(ReactionRules.remark_key(&"smith", life, rel), &"event_apprentice_hired")
	assert_eq(rel.remark_text(&"smith", 55), "Der Wackernagel-Junge harkt jetzt bei dir? Gib ihm einen Stiel, der zu ihm passt.")
	TimeManager.day = 56
	assert_eq(ReactionRules.remark_key(&"smith", life, rel), &"event_apprentice_hired", "the next day too")
	TimeManager.day = 57
	assert_eq(life.reaction_for(&"smith"), &"", "§2.1.3: at most 2 days old")
	assert_eq(ReactionRules.remark_key(&"smith", life, rel), &"rep_respected")


func test_who_reacts_people_and_data() -> void:
	_open()
	life.note_event(&"jakob_scolded", [&"innkeeper"] as Array[StringName])
	assert_eq(life.reaction_for(&"innkeeper"), &"jakob_scolded")
	assert_eq(life.reaction_for(&"smith"), &"", "only the people noted")
	assert_eq(ReactionRules.remark_key(&"innkeeper", life, rel), &"event_jakob_scolded")
	# Everyone noted, but only villagers with a line react.
	life.note_event(&"lights_all")
	assert_eq(life.reaction_for(&"smith"), &"lights_all")
	assert_eq(ReactionRules.remark_key(&"smith", life, rel), &"rep_respected", "the fixture smith has no lights_all line")
	assert_eq(ReactionRules.remark_key(&"priest", life, rel), &"event_lights_all")
	# Newest first: an older event with a line still counts after a newer without one.
	TimeManager.day = 56
	life.note_event(&"grave_disturbed")
	assert_eq(life.valid_events(&"priest"), [&"grave_disturbed", &"lights_all"] as Array[StringName])
	assert_eq(ReactionRules.remark_key(&"priest", life, rel), &"event_lights_all", "no grave_disturbed line for the fixture priest")
	assert_eq(ReactionRules.remark_key(&"mayor", life, rel), &"event_grave_disturbed")
	assert_eq(life.reaction_for(&"carter"), &"grave_disturbed", "events know no villagers")
	assert_eq(ReactionRules.remark_key(&"carter", life, rel), &"", "Osric is no villager")
	# Unknown events (not in reactions) never become remarks.
	life.note_event(&"lecture_rumor")
	assert_false(life.valid_events(&"priest").has(&"lecture_rumor"))


func test_precedence_event_friend_piety_reputation() -> void:
	_open()
	var talker := VillagerData.new()
	talker.npc_id = &"talker"
	talker.display_name = "Tal Ker"
	talker.remarks = {
		&"event_wish_done": PackedStringArray(["E"]), &"friend": PackedStringArray(["F"]), &"piety_devout": PackedStringArray(["D"]),
		&"specimens": PackedStringArray(["S"]), &"rep_respected": PackedStringArray(["R"]),
	}
	rel.villagers[&"talker"] = talker
	rel.add(&"talker", 90, "x")
	GameState.stats[&"piety"] = 80
	GameState.stats[&"specimens_sold"] = Relationships.REMARK_SPECIMENS_AFTER
	assert_eq(rel.remark_text(&"talker", 55), "F", "no event: friend")
	life.note_event(&"wish_done", [&"talker"] as Array[StringName])
	assert_eq(rel.remark_text(&"talker", 55), "E", "event > friend")
	assert_eq(ReactionRules.keys(&"talker", life, rel).slice(0, 4), [&"event_wish_done", &"friend", &"piety_devout", &"specimens"])
	TimeManager.day = 57
	assert_eq(rel.remark_text(&"talker", 57), "F")
	rel.load_state({"values": {"talker": 50}, "met": ["talker"]})
	assert_eq(rel.remark_text(&"talker", 57), "D", "piety")
	GameState.stats[&"piety"] = 0
	assert_eq(rel.remark_text(&"talker", 57), "S", "specimens")
	GameState.stats[&"specimens_sold"] = 0
	assert_eq(rel.remark_text(&"talker", 57), "R", "reputation")


func test_remark_once_per_day_with_events() -> void:
	_open()
	var said: Array = []
	var on_remark := func(npc_id: StringName, text: String) -> void: said.append([npc_id, text])
	EventBus.villager_remarked.connect(on_remark)
	life.note_event(&"robber_let_go", [&"washer", &"beggar"] as Array[StringName])
	assert_eq(rel.remark(&"washer"), "Du hast ihn laufen lassen. Das hätte Lorenz auch getan.")
	assert_eq(rel.remark(&"washer"), "", "once per day")
	assert_eq(said.size(), 1)
	EventBus.villager_remarked.disconnect(on_remark)


func test_real_villager_data_reaction_lines() -> void:
	var cfg := NpcLifeConfig.new()
	var leads := {&"smith": &"event_apprentice_hired", &"innkeeper": &"event_jakob_scolded", &"grocer": &"event_wish_done",
			&"mayor": &"event_grave_disturbed", &"priest": &"event_lights_all", &"washer": &"event_robber_let_go"}
	for id: StringName in leads:
		var v := Database.villager(id) as VillagerData
		assert_not_null(v, String(id))
		assert_false(v.remarks.get(leads[id], PackedStringArray()).is_empty(), "§2.1.3 lead line %s %s" % [id, leads[id]])
	var total := 0
	for res: Resource in Database.villagers():
		var v := res as VillagerData
		for key: StringName in v.remarks:
			if String(key).begins_with("event_"):
				assert_true(StringName(String(key).trim_prefix("event_")) in cfg.reactions, "%s %s is a reaction event" % [v.npc_id, key])
				assert_eq(v.remarks[key].size(), 1, "%s %s: one line" % [v.npc_id, key])
				total += 1
	assert_true(total >= 40, "1–2 lines per person and event (%d)" % total)
	var smith := Database.villager(&"smith") as VillagerData
	assert_eq(smith.circle, [&"house_brandt"] as Array[StringName], "the data carries the Phase-8 fields")
	assert_eq(smith.mood_lines[&"cross"][0], "Heute nicht, Totengräber. Morgen.")
