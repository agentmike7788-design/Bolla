extends TestCase
## Phase 9 W3 QA-Fix (docs/reviews/phase9_round1/qafix/qafix.md): guards of the small findings without a world.


func _node(d: DialogueData, id: StringName) -> DialogueNode:
	for n: DialogueNode in d.nodes:
		if n.id == id:
			return n
	return null


## QA9-T1: a hard-hearted gravekeeper (the anatomist's way, piety −45 …) gets Osric's curt menu_cold – it lacked every
## Phase-8/9 line: the post (Gesa's errand, the letters to town), the large request's hand-over, the list's witness. The
## curt menu keeps the work of the warm one (only the greeting is shorter).
func test_qa9_t1_osrics_cold_menu_keeps_the_phase8_9_lines() -> void:
	var d := load("res://data/dialogue/carter.tres") as DialogueData
	var warm := _node(d, &"menu")
	var cold := _node(d, &"menu_cold")
	assert_not_null(warm)
	assert_not_null(cold)
	if warm == null or cold == null:
		return
	var cold_texts := cold.choices.map(func(c: DialogueChoice) -> String: return c.text)
	for c: DialogueChoice in warm.choices:
		var p89 := c.text.begins_with("[Brief]") or c.text.begins_with("[Bitte]") or c.text.begins_with("[Die Liste]") \
				or c.text.begins_with("[Auftrag] Die Kiste") or "letter_post:carter" in c.actions or "large_turn_in:carter" in c.actions
		if p89:
			assert_true(c.text in cold_texts, "menu_cold offers „%s“" % c.text)
	assert_eq(cold.choices.back().text, "Das war alles. Mach's gut, Osric.", "the goodbye stays last")


## QA9-09: Phase8Bot made ink with _craft5(&"workbench") – there is no Entities/station_workbench (engine error as soon
## as an extract was wanted without ink); it crafts at the hill's workbench now (Phase 3's _craft).
func test_qa9_09_phase8_bot_has_no_station_workbench_call() -> void:
	var src := FileAccess.get_file_as_string("res://tests/integration/phase8_bot.gd")
	assert_ne(src, "")
	assert_false(src.contains("_craft5(&\"workbench\""), "no _craft5 at a station „workbench“")
	assert_true(src.contains("_craft(world.get_node_by_layout_id(\"workbench\") as Workbench, &\"ink\")"))
