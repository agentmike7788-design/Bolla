class_name MapStatePhase8
extends RefCounted
## The Phase-8 part of the map's live context (docs/PHASE8_DESIGN.md §7.8): marks [{kind, region, world: Vector3 |
## place: String, text, id}] for the live layer – never on the baked sheet – and grave_info for the grave tooltip:
## | kind        | where                                  | when                                       |
## | visitor     | the visitor's Npc, else its grave      | during the visit (name in the tooltip)     |
## | apprentice  | Jakob's Npc / his current place        | his working hours („harkt im Alten Hof")   |
## | wish        | the grave                              | open (deadline in the tooltip)             |
## | coins       | the grave                              | until taken                                |
## | peddler     | Hanne's Npc / her place                | her day (times in the tooltip)             |
## | beggar      | Veit's Npc                             | while he is about                          |
## | sick_light  | the house                              | only once c_n_veit is known, while it burns|
## | fest        | graveyard + bridge / the Holderkrug    | on the festival day                        |
## | disturbed   | the grave                              | until closed                               |
## The night digger is NEVER on the map (one has to look at night oneself).

const NPC_GROUP := &"npc"
const VISITORS_GROUP := &"visitors"
const APPRENTICE_GROUP := &"apprentice"
const WANDERERS_GROUP := &"wanderers"
const NIGHT_PATHS_GROUP := &"night_paths"
const FESTIVALS_GROUP := &"festivals"
const JOURNAL_GROUP := &"journal"
const GRAVEYARD_GROUP := &"graveyard"
const ROBBER_IDS: Array[StringName] = [&"robber"]
const CLUE_VEIT := &"c_n_veit"
const TEXT_APPRENTICE := "Jakob %s"
const TEXT_APPRENTICE_IN := "Jakob %s %s"
const APPRENTICE_VERBS: Dictionary[StringName, String] = {&"rake": "harkt", &"weed": "jätet", &"water": "gießt",
		&"candle": "setzt Kerzen", &"refill": "füllt die Kanne", &"lunch": "macht Brotzeit", &"sweep": "kehrt die Ecke"}
const TEXT_APPRENTICE_WAY := "Jakob ist auf dem Weg"
const TEXT_WISH := "Wunsch: %s (%s, ≈ %d %s)"
const TEXT_WISH_NODAYS := "Wunsch: %s (%s)"
const TEXT_PEDDLER := "Hanne Vogelsang – Brunnen %s–%s · Tor %s–%s"
const TEXT_SICK := "Bei den %s brennt Licht"
const TEXT_FEST := "Heute: %s"
const TEXT_DISTURBED := "Aufgewühltes Grab"
## Festival → [[region, place]] of its marks.
const FEST_PLACES: Dictionary[StringName, Array] = {
	&"fest_lights": [[&"graveyard", "gate_inside"], [&"village", "bridge"]],
	&"fest_kathrein": [[&"village", "v_inn"]],
}
const FEST_GLYPHS: Dictionary[StringName, StringName] = {&"fest_lights": &"lantern", &"fest_kathrein": &"fiddle"}


## {marks: [...], grave_info: {...}} ({} before p8_open).
static func context(tree: SceneTree) -> Dictionary:
	if tree == null or not GameState.flag_on(&"p8_open"):
		return {}
	var marks: Array[Dictionary] = []
	_visitors(tree, marks)
	_apprentice(tree, marks)
	_wanderers(tree, marks)
	_sick_lights(tree, marks)
	_fest(tree, marks)
	var info := Phase8Status.grave_info(tree)
	for g: Variant in info:
		var i: Dictionary = info[g]
		if i.has("wish_kind"):
			marks.append({"kind": &"wish", "region": &"graveyard", "place": String(g), "id": String(g), "text": _wish_text(tree, String(g))})
		if int(i.get("coins", 0)) > 0:
			marks.append({"kind": &"coins", "region": &"graveyard", "place": String(g), "id": String(g),
					"text": Phase8Texts.TIP_COINS % [int(i.coins), Phase8Texts.coins(int(i.coins)), str(i.get("giver", ""))]})
		if bool(i.get("disturbed", false)):
			marks.append({"kind": &"disturbed", "region": &"graveyard", "place": String(g), "id": String(g), "text": TEXT_DISTURBED})
	return {"marks": marks, "grave_info": info}


static func _visitors(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var visitors := tree.get_first_node_in_group(VISITORS_GROUP) as Visitors
	if visitors == null:
		return
	for v: Dictionary in visitors.active_visits():
		var kin := Database.kin(StringName(str(v.get("kin_id", "")))) as KinData
		if kin == null:
			continue
		var mark := {"kind": &"visitor", "region": &"graveyard", "id": String(kin.kin_id), "text": kin.display_name}
		var npc := _npc_named(tree, String(kin.npc_path_id))
		if npc != null and npc.is_present():
			mark["world"] = npc.global_position
			mark["region"] = npc.region_id
		else:
			mark["place"] = str(v.get("grave_id", ""))
		marks.append(mark)


static func _apprentice(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var app := tree.get_first_node_in_group(APPRENTICE_GROUP) as Apprentice
	if app == null or not app.is_hired() or not app.on_graveyard():
		return
	var mark := {"kind": &"apprentice", "region": &"graveyard", "id": "apprentice", "text": apprentice_text(tree, app)}
	if app.npc != null and app.npc.is_inside_tree() and app.npc.is_present():
		mark["world"] = app.npc.global_position
	else:
		mark["place"] = app.position_point()
	marks.append(mark)


## „Jakob harkt im Alten Hof" from the plan entry running now.
static func apprentice_text(tree: SceneTree, app: Apprentice) -> String:
	var m := TimeManager.minute_of_day
	for e: Dictionary in app.today_plan():
		if int(e.get("start", 0)) <= m and m < int(e.get("end", 0)):
			var task := StringName(str(e.get("task", "")))
			var verb: String = APPRENTICE_VERBS.get(task, "")
			if verb == "":
				return TEXT_APPRENTICE_WAY
			var graveyard := tree.get_first_node_in_group(GRAVEYARD_GROUP)
			var gid := str(e.get("grave_id", ""))
			var where := ""
			if gid != "" and graveyard != null and graveyard.has_method(&"section_of"):
				where = Phase8Texts.AREA_IN.get(StringName(str(graveyard.call(&"section_of", gid))), "")
			return TEXT_APPRENTICE_IN % [verb, where] if where != "" else TEXT_APPRENTICE % verb
	return TEXT_APPRENTICE_WAY


static func _wanderers(tree: SceneTree, marks: Array[Dictionary]) -> void:
	for id: StringName in [Phase8Texts.PEDDLER, Phase8Texts.BEGGAR]:
		var npc := _npc_by_id(tree, id)
		if npc == null or not npc.is_present():
			continue
		var text := Phase8Texts.person_name(id)
		if id == Phase8Texts.PEDDLER:
			text = TEXT_PEDDLER % [UIKit.clock(Wanderers.PEDDLER_WELL[0]), UIKit.clock(Wanderers.PEDDLER_WELL[1]),
					UIKit.clock(Wanderers.PEDDLER_GATE[0]), UIKit.clock(Wanderers.PEDDLER_GATE[1])]
		marks.append({"kind": id, "region": npc.region_id, "world": npc.global_position, "id": String(id), "text": text})


static func _sick_lights(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var journal := tree.get_first_node_in_group(JOURNAL_GROUP)
	if journal == null or not journal.has_method(&"has_clue") or not bool(journal.call(&"has_clue", CLUE_VEIT)):
		return
	var paths := tree.get_first_node_in_group(NIGHT_PATHS_GROUP) as NightPaths
	if paths == null:
		return
	for house: String in paths.sick_houses(TimeManager.day, TimeManager.minute_of_day):
		marks.append({"kind": &"sick_light", "region": &"village", "place": house, "id": house,
				"text": TEXT_SICK % Phase8Texts.SICK_HOUSE_NAMES.get(StringName(house), Phase8Texts.house_label(StringName(house)))})


static func _fest(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var fest := tree.get_first_node_in_group(FESTIVALS_GROUP) as Festivals
	if fest == null or fest.today() == &"":
		return
	var id := fest.today()
	for p: Array in FEST_PLACES.get(id, []):
		marks.append({"kind": &"fest", "glyph": FEST_GLYPHS.get(id, &"lantern"), "region": p[0], "place": p[1], "id": String(id),
				"text": TEXT_FEST % Phase8Texts.fest_name(id)})


static func _wish_text(tree: SceneTree, grave_id: String) -> String:
	var visitors := tree.get_first_node_in_group(VISITORS_GROUP) as Visitors
	if visitors == null:
		return ""
	for w: Dictionary in visitors.open_wishes():
		if str(w.get("grave_id", "")) != grave_id:
			continue
		var kin := StringName(str(w.get("kin_id", "")))
		var next := Phase8Status.next_visit_day(tree, visitors, kin)
		var label := Phase8Texts.wish_kind_label(StringName(str(w.get("kind", ""))))
		if next < 0:
			return TEXT_WISH_NODAYS % [label, Phase8Texts.household(kin)]
		var d := maxi(next - TimeManager.day, 0)
		return TEXT_WISH % [label, Phase8Texts.household(kin), d, Phase8Texts.days_word(d)]
	return ""


static func _npc_named(tree: SceneTree, node_name: String) -> Npc:
	for node: Node in tree.get_nodes_in_group(NPC_GROUP):
		if node is Npc and String(node.name) == node_name and node.is_inside_tree():
			return node as Npc
	return null


static func _npc_by_id(tree: SceneTree, npc_id: StringName) -> Npc:
	var other: Npc = null
	for node: Node in tree.get_nodes_in_group(NPC_GROUP):
		var npc := node as Npc
		if npc == null or npc.npc_id != npc_id or not npc.is_inside_tree():
			continue
		if npc.is_present():
			return npc
		if other == null:
			other = npc
	return other
