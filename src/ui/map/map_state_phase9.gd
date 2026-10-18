class_name MapStatePhase9
extends RefCounted
## The Phase-9 part of the map's live context (docs/PHASE9_DESIGN.md §7.6, W-UI): marks [{kind, region, world: Vector3 |
## place: String, text, id}] in the format of MapStatePhase8 – drawn on the live layer, never baked:
## | kind        | where                                         | when                                              |
## | stranger    | Brenneisen's Npc, else his place              | while he is here (gate outside / the Holderkrug)  |
## | large       | the gate (inside) / the parish board          | while a large request hangs or runs there         |
## | sick_light  | Haus Sieber                                   | Ende B / C, at night, while Johann lives          |
## | bookmark    | the fixed place of the pinned entry's next step | only a fixed place (hut, grave, house, gate) –  |
## |             |                                               | no arrow, no distance (Prio B)                    |

const NPC_GROUP := &"npc"
const STRANGER_ID := &"stranger"
const HILL_GROUP := &"hill_requests"
const QUESTS_GROUP := &"quests"
const GATE_PLACE := "gate_inside"
const GATE_OUTSIDE := "gate_outside"
const VILLAGE_BOARD := "v_board"
const GATE_BOARD := "notice_board"
const INN_PLACE := "v_inn"
const HUT_PLACE := "hut"
const SIEBER_HOUSE := "house_sieber"
## The night of the sick light on the map (20:00 … 05:00), as Phase 8.
const NIGHT_FROM := 1200
const NIGHT_UNTIL := 300
## Steps whose next place is fixed: step id → [region, place].
const STEP_PLACES: Dictionary[StringName, Array] = {
	&"h1": [&"graveyard", HUT_PLACE], &"h2": [&"graveyard", HUT_PLACE], &"h4": [&"village", SIEBER_HOUSE],
	&"k1": [&"graveyard", GATE_OUTSIDE], &"k4": [&"village", INN_PLACE], &"l4": [&"graveyard", HUT_PLACE],
}


## {marks: [...]} ({} before p9_open and without a large request).
static func context(tree: SceneTree) -> Dictionary:
	if tree == null:
		return {}
	var marks: Array[Dictionary] = []
	_stranger(tree, marks)
	_large(tree, marks)
	_sieber_light(tree, marks)
	_bookmark(tree, marks)
	return {"marks": marks} if not marks.is_empty() else {}


static func _stranger(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var s := tree.get_first_node_in_group(&"stranger") as Stranger
	if s == null or s.gone() or not s.here():
		return
	var mark := {"kind": &"stranger", "id": String(STRANGER_ID), "text": Phase9Texts.MAP_STRANGER}
	var npc := _npc(tree, STRANGER_ID)
	if npc != null and npc.is_present():
		mark["world"] = npc.global_position
		mark["region"] = npc.region_id
	elif s.present(&"graveyard"):
		mark["region"] = &"graveyard"
		mark["place"] = GATE_OUTSIDE
	else:
		mark["region"] = &"village"
		mark["place"] = INN_PLACE
	marks.append(mark)


static func _large(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var hill := tree.get_first_node_in_group(HILL_GROUP) as HillRequests
	if hill == null:
		return
	for place: StringName in [&"gate", &"village"]:
		var ids := hill.large_board(place)
		if ids.is_empty():
			continue
		var r := hill.large_data(ids[0])
		marks.append({"kind": &"large", "region": &"graveyard" if place == &"gate" else &"village",
				"place": GATE_BOARD if place == &"gate" else VILLAGE_BOARD, "id": String(ids[0]),
				"text": "%s: %s" % [Phase9Texts.MAP_LARGE, r.title if r != null else String(ids[0])]})


static func _sieber_light(tree: SceneTree, marks: Array[Dictionary]) -> void:
	if not (GameState.flag_on(&"q_end_stay") or GameState.flag_on(&"q_end_public")):
		return
	if GameState.flag_on(&"sieber_dead") or GameState.flag_on(&"sieber_gone"):
		return
	var m := TimeManager.minute_of_day
	if not (m >= NIGHT_FROM or m < NIGHT_UNTIL):
		return
	marks.append({"kind": &"sick_light", "region": &"village", "place": SIEBER_HOUSE, "id": SIEBER_HOUSE,
			"text": Phase9Texts.MAP_SIEBER_LIGHT})


## Prio B: the pinned entry's next step at a fixed place (a large request: its board).
static func _bookmark(tree: SceneTree, marks: Array[Dictionary]) -> void:
	var pinned := QuestLog.objective(tree)
	if pinned.is_empty():
		return
	var id := StringName(str(pinned.get("id", "")))
	var group := StringName(str(pinned.get("group", "")))
	var at: Array = []
	if group == &"large":
		var hill := tree.get_first_node_in_group(HILL_GROUP) as HillRequests
		var r := hill.large_data(id) if hill != null else null
		if r != null:
			at = [&"graveyard", GATE_BOARD] if r.place == &"gate" else [&"village", VILLAGE_BOARD]
	elif group == &"main" or group == &"side":
		var quests := tree.get_first_node_in_group(QUESTS_GROUP) as Quests
		if quests != null:
			at = STEP_PLACES.get(quests.current_step(id), [])
	if at.is_empty():
		return
	marks.append({"kind": &"bookmark", "region": at[0], "place": at[1], "id": String(id),
			"text": Phase9Texts.MAP_BOOKMARK % str(pinned.get("title", ""))})


static func _npc(tree: SceneTree, npc_id: StringName) -> Npc:
	for node: Node in tree.get_nodes_in_group(NPC_GROUP):
		var npc := node as Npc
		if npc != null and npc.npc_id == npc_id and npc.is_inside_tree():
			return npc
	return null
