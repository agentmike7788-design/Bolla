class_name Phase9Fixtures
extends RefCounted
## Phase-9 test fixtures (W0, docs/PHASE9_DESIGN.md §12). W1 unit tests load these instead of data/ –
## they mirror the contract values and leading texts (§1–§2) at the time of W0 and do not follow later
## balancing / text edits of the real data files. Written by make_phase9_fixtures.gd (historical tool).
##
## *_config_fixture.tres: quest, who_knows, letters, stranger (= the W0 data/config files = class defaults;
##   stranger_config with the 6 questions) + the Phase-9 values of existing configs: orders (max_active_quest),
##   hill_requests (large_*), reputation (+ 8 events), piety (+ 16), relationship (gains + 11), npc_life (reactions
##   + 5); ghost_lines (Phase-8 fixture + by_letter + by_story d3_sieber).
## quests/ (q_who_knows, q_letters, q_case – steps, choices, endings), quests/who_knows/list.tres (6 entries),
##   letters/ (11 pocket + 5 post), stranger/offers/ (4), hill_requests/large/ (12 larger requests with parts),
##   orders/ (oq_* – 6, category quest), clues/ (c_q_*, 12), insights/i_light_before, story/d3_sieber,
##   finds/f_d3_* (2), night/paths/np_sieber, sections/linden_row4; ../items/ + the 7 Phase-9 items (§2.9).
## layout_p8.json / village_layout_p8.json: the approved Phase-8 layouts (10e310e), byte-identical.
## ../saves_v7/: Phase-8 save files (format v7) – see make_v7_saves.gd.

const DIR := "res://tests/fixtures/phase9"
const CONFIG_NAMES: Array[StringName] = [&"quest_config", &"who_knows_config", &"letters_config", &"stranger_config"]
## Existing configs with Phase-9 values (W0: class default and data carry them too).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"orders_config", &"hill_requests_config", &"reputation_config",
		&"piety_config", &"relationship_config", &"npc_life_config"]
const QUEST_IDS: Array[StringName] = [&"q_who_knows", &"q_letters", &"q_case"]
const MAIN_STEPS: Array[StringName] = [&"h1", &"h2", &"h3", &"h4", &"h5", &"h6"]
const LETTERS_STEPS: Array[StringName] = [&"l1", &"l2", &"l3", &"l4", &"l5"]
const CASE_STEPS: Array[StringName] = [&"k1", &"k2", &"k3", &"k4", &"k5"]
const ENDINGS: Array[StringName] = [&"away", &"stay", &"public", &"silent"]
const ENTRY_IDS: Array[StringName] = [&"e_dorn", &"e_quendel", &"e_wernstein", &"e_hagedorn", &"e_ott", &"e_open"]
## The five witnesses of H3 (§2.2.4) – e_open (Veit) is H4.
const WITNESS_ENTRIES: Array[StringName] = [&"e_dorn", &"e_quendel", &"e_wernstein", &"e_hagedorn", &"e_ott"]
const POCKET_IDS: Array[StringName] = [&"lg_grocer", &"lg_lambert", &"lg_nobody", &"lg_priest", &"lg_smith", &"lg_town",
		&"lg_wife", &"lp_d3_grete", &"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"]
const POST_IDS: Array[StringName] = [&"lpo_aschau", &"lpo_hagedorn", &"lpo_ott", &"lpo_quendel", &"lpo_wernstein"]
const OFFER_IDS: Array[StringName] = [&"so_kladde", &"so_register", &"so_soil", &"so_specimen"]
const LARGE_IDS: Array[StringName] = [&"hrl_ferry_graves", &"hrl_crosses", &"hrl_proper_grave", &"hrl_bench_path", &"hrl_restless",
		&"hrl_widow_wood", &"hrl_lantern_path", &"hrl_old_names", &"hrv_bridge_stones", &"hrv_paul_day", &"hrv_inn_cellar",
		&"hrv_church_candles"]
const GATE_LARGE: Array[StringName] = [&"hrl_ferry_graves", &"hrl_crosses", &"hrl_proper_grave", &"hrl_bench_path", &"hrl_restless",
		&"hrl_widow_wood", &"hrl_lantern_path", &"hrl_old_names"]
const ORDER_IDS: Array[StringName] = [&"oq_gesa_brother", &"oq_fenner_seal", &"oq_liesel_bundle", &"oq_jakob_father",
		&"oq_johann_evening", &"oq_case_return"]
const ITEM_IDS: Array[StringName] = [&"letter", &"letter_reply", &"nameless_letter", &"stranger_case", &"case_card", &"soil_pouch",
		&"straw_bouquet"]
const CLUE_IDS: Array[StringName] = [&"c_q_dates", &"c_q_three_weeks", &"c_q_light_dorn", &"c_q_light_quendel",
		&"c_q_light_wernstein", &"c_q_light_hagedorn", &"c_q_light_ott", &"c_q_sieber", &"c_q_hand_answers", &"c_q_ferry_letter",
		&"c_q_case_lorenz", &"c_q_case_list"]
const FIND_IDS: Array[StringName] = [&"f_d3_mark", &"f_d3_ribbon"]
## §2.6: the fourth row of the Lindenacker.
const ROW4_PLOTS: PackedStringArray = ["l_13", "l_14", "l_15", "l_16"]
## §3.1: [class, save_id, save_order, group] of the Phase-9 saveable system nodes.
const SAVEABLES := [
	["Quests", "quests", 81, &"quests"], ["WhoKnows", "who_knows", 82, &"who_knows"],
	["Letters", "letters", 83, &"letters"], ["Stranger", "stranger", 84, &"stranger"],
]
const SAVES_V7_DIR := "res://tests/fixtures/saves_v7"
const SAVES_V7: PackedStringArray = ["slot_p8_day63_kindly", "slot_p8_day63_anatomist", "slot_p8_day63_letgo", "slot_p8_founder",
		"slot_p8_mid", "slot_p8_day2_hill", "slot_p8_day30_village_hill"]
const LAYOUT_P8 := DIR + "/layout_p8.json"
const VILLAGE_LAYOUT_P8 := DIR + "/village_layout_p8.json"
## The reference opening day of arc A (§1.4: v7 slot_p8_day63_kindly, 4. Julmond 1834).
const OPEN_DAY := 63
## The dead under the list in slot_p8_day63_kindly (W0 check, §12.1): story → [grave, arrival day, record id].
## Light day = arrival − 1 − 21 (D2: night_paths.deaths.np_ott 58 − 21 = 37). S1/S3/S5 lie before game day 1.
const LIST_DEAD := {&"s1_quendel": ["plot_06", 6, "corpse_0006"], &"s3_wernstein": ["h_01", 13, "corpse_0013"],
		&"s5_moor": ["h_06", 19, "corpse_0018"], &"d1_hagedorn": ["l_07", 48, "corpse_0030"], &"d2_ott": ["l_12", 59, "corpse_0036"]}

static var _letter_counter: int = 0
static var _injected: Array[StringName] = []


# --- configs ------------------------------------------------------------------------------------

static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func quest_config() -> QuestConfig:
	return config(&"quest_config") as QuestConfig


static func who_knows_config() -> WhoKnowsConfig:
	return config(&"who_knows_config") as WhoKnowsConfig


static func letters_config() -> LettersConfig:
	return config(&"letters_config") as LettersConfig


static func stranger_config() -> StrangerConfig:
	return config(&"stranger_config") as StrangerConfig


static func orders_config() -> OrdersConfig:
	return config(&"orders_config") as OrdersConfig


static func hill_requests_config() -> HillRequestsConfig:
	return config(&"hill_requests_config") as HillRequestsConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func relationship_config() -> RelationshipConfig:
	return config(&"relationship_config") as RelationshipConfig


static func npc_life_config() -> NpcLifeConfig:
	return config(&"npc_life_config") as NpcLifeConfig


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


# --- data ---------------------------------------------------------------------------------------

static func quest(id: StringName) -> QuestData:
	return load(DIR + "/quests/%s.tres" % id) as QuestData


static func quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id: StringName in QUEST_IDS:
		out.append(quest(id))
	return out


static func letter(id: StringName) -> LetterData:
	return load(DIR + "/letters/%s.tres" % id) as LetterData


static func letters() -> Array[LetterData]:
	var out: Array[LetterData] = []
	for id: StringName in POCKET_IDS + POST_IDS:
		out.append(letter(id))
	return out


## Letters by id (Letters.letter_table).
static func letter_table() -> Dictionary[StringName, LetterData]:
	var out: Dictionary[StringName, LetterData] = {}
	for l: LetterData in letters():
		out[l.id] = l
	return out


static func stranger_offer(id: StringName) -> StrangerOfferData:
	return load(DIR + "/stranger/offers/%s.tres" % id) as StrangerOfferData


static func stranger_offers() -> Array[StrangerOfferData]:
	var out: Array[StrangerOfferData] = []
	for id: StringName in OFFER_IDS:
		out.append(stranger_offer(id))
	return out


static func large_request(id: StringName) -> OrderData:
	return load(DIR + "/hill_requests/large/%s.tres" % id) as OrderData


static func large_requests() -> Array[OrderData]:
	var out: Array[OrderData] = []
	for id: StringName in LARGE_IDS:
		out.append(large_request(id))
	return out


static func order(id: StringName) -> OrderData:
	return load(DIR + "/orders/%s.tres" % id) as OrderData


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


static func clue(id: StringName) -> ClueData:
	return load(DIR + "/clues/%s.tres" % id) as ClueData


static func insight() -> InsightData:
	return load(DIR + "/insights/i_light_before.tres") as InsightData


static func d3_story() -> StoryCorpseData:
	return load(DIR + "/story/d3_sieber.tres") as StoryCorpseData


static func find(id: StringName) -> FindData:
	return load(DIR + "/finds/%s.tres" % id) as FindData


static func night_path() -> NightPathData:
	return load(DIR + "/night/paths/np_sieber.tres") as NightPathData


static func row4_section() -> SectionData:
	return load(DIR + "/sections/linden_row4.tres") as SectionData


static func layout_p8() -> Dictionary:
	return _json(LAYOUT_P8)


static func village_layout_p8() -> Dictionary:
	return _json(VILLAGE_LAYOUT_P8)


# --- state helpers (§12.1 W0) ---------------------------------------------------------------------

## Opens Phase 9 in GameState (village_open, name_in_village_complete, p8_open, who_comes_up_complete, p9_open,
## p9_open_day = `day`, q_light_day = day − 12) and returns a Quests (W0 stub: is_open / open_day read these
## flags). Added under tree.root when a tree is given (group quests). The caller frees it.
static func p9_open(tree: SceneTree = null, day: int = OPEN_DAY) -> Quests:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"name_in_village_complete", true)
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"who_comes_up_complete", true)
	GameState.set_flag(&"p9_open", true)
	GameState.set_flag(&"p9_open_day", day)
	GameState.set_flag(&"q_light_day", day + who_knows_config().open_light_offset)
	var q := Quests.new()
	q.config = quest_config()
	q.load_state({"open_day": day, "open": ["q_who_knows", "q_letters"]})
	if tree != null:
		tree.root.add_child(q)
	return q


## Quests with `quest_id` open at `step` (the steps before it done, §5.1 step / done). Phase 9 open in GameState.
static func quest_at(quest_id: StringName, step: StringName, tree: SceneTree = null) -> Quests:
	var q := p9_open(null)
	var data := quest(quest_id)
	var done: Array = []
	if data != null:
		for s: QuestStepData in data.steps:
			if s.id == step:
				break
			done.append(String(s.id))
	q.load_state({"open_day": OPEN_DAY, "open": [String(quest_id)], "step": {String(quest_id): String(step)},
			"done": {String(quest_id): done}})
	if tree != null:
		tree.root.add_child(q)
	return q


## The list (§2.2.1). With a tree: a WhoKnows (group who_knows) is added too, with the list's light day
## (q_light_day of GameState) – the caller frees it (tree.get_first_node_in_group(&"who_knows")).
static func light_list(tree: SceneTree = null) -> LightListData:
	var list := load(DIR + "/quests/who_knows/list.tres") as LightListData
	if tree != null:
		var w := WhoKnows.new()
		w.config = who_knows_config()
		w.load_state({"light_day": int(GameState.get_flag(&"q_light_day", OPEN_DAY - 12))})
		tree.root.add_child(w)
	return list


## The story records of the dead under the list as in slot_p8_day63_kindly (LIST_DEAD; buried, pure data).
static func list_records() -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for story: StringName in LIST_DEAD:
		var row: Array = LIST_DEAD[story]
		var r := CorpseRecord.new()
		r.id = str(row[2])
		r.story_id = story
		r.grave_id = str(row[0])
		r.arrival_total_minutes = (int(row[1]) - 1) * 1440 + 460
		r.buried_day = int(row[1])
		r.location = CorpseRecord.LOCATION_BURIED
		r.traits = [&"strange_wound"] as Array[StringName]
		out.append(r)
	return out


## WhoKnows with `entries` witnessed (§5.1 witnessed).
static func witnessed(entries: Array[StringName], tree: SceneTree = null) -> WhoKnows:
	var w := WhoKnows.new()
	w.config = who_knows_config()
	w.load_state({"witnessed": entries.map(func(e: StringName) -> String: return String(e))})
	if tree != null:
		tree.root.add_child(w)
	return w


## H4 done: flag q_sieber_marked + WhoKnows marked_seen (all five witnesses asked).
static func sieber_marked(tree: SceneTree = null) -> WhoKnows:
	GameState.set_flag(&"q_sieber_marked", true)
	var w := WhoKnows.new()
	w.config = who_knows_config()
	w.load_state({"marked_seen": true, "witnessed": WITNESS_ENTRIES.map(func(e: StringName) -> String: return String(e))})
	if tree != null:
		tree.root.add_child(w)
	return w


## Quests with q_who_knows ended in `e` (away | stay | public | silent): the flag q_end_<e> (+ q_sieber_dies for B/C/silent,
## sieber_gone for A) in GameState, all six steps done.
static func ending(e: StringName, tree: SceneTree = null) -> Quests:
	var q := p9_open(null)
	GameState.set_flag(StringName("q_end_" + String(e)), true)
	if e == &"away":
		GameState.set_flag(&"sieber_gone", true)
	else:
		GameState.set_flag(&"q_sieber_dies", true)
	q.load_state({"open_day": OPEN_DAY, "open": ["q_who_knows"], "done": {"q_who_knows": MAIN_STEPS.map(func(s: StringName) -> String:
			return String(s))}, "choices": {"q_who_knows": {"h6": String(e)}}, "ending": {"q_who_knows": String(e)}})
	if tree != null:
		tree.root.add_child(q)
	return q


## A pocket letter `id` found in `inv` (the unique item letter with a new uid; the fixture item is injected into the
## Database when data/items has none yet – test-only) and a Letters with its record {id, corpse, state found, day}.
## Returns {"letters": Letters, "uid": String}.
static func letter_in(inv: Inventory, id: StringName, tree: SceneTree = null) -> Dictionary:
	_inject_items()
	_letter_counter += 1
	var uid := "lt_%04d" % _letter_counter
	if inv != null:
		inv.add_unique(&"letter", uid)
	var l := Letters.new()
	l.config = letters_config()
	l.letter_table = letter_table()
	l.load_state({"next_uid": _letter_counter + 1, "records": {uid: {"id": String(id), "corpse": "corpse_%04d" % (40 + _letter_counter),
			"state": "found", "day": TimeManager.day}}})
	if tree != null:
		tree.root.add_child(l)
	return {"letters": l, "uid": uid}


## Post for the dead `id` waiting (state received, Osric brought it today). Returns {"letters": Letters, "uid": String}.
static func post_waiting(id: StringName, tree: SceneTree = null) -> Dictionary:
	_letter_counter += 1
	var uid := "lt_%04d" % _letter_counter
	var l := Letters.new()
	l.config = letters_config()
	l.letter_table = letter_table()
	l.load_state({"next_uid": _letter_counter + 1, "records": {uid: {"id": String(id), "corpse": "", "state": "received",
			"day": TimeManager.day}}, "post_done": [3]})
	if tree != null:
		tree.root.add_child(l)
	return {"letters": l, "uid": uid}


## The first day of Brenneisen's `k`-th visit (1, 2, …) with Phase 9 opened on OPEN_DAY: OPEN_DAY + arrive_offset +
## (k − 1) × return_every (B3 = day 65, B8 = day 70). Opens Phase 9 in GameState.
static func stranger_day(k: int) -> int:
	var cfg := stranger_config()
	var q := p9_open(null)
	q.free()
	return OPEN_DAY + cfg.arrive_offset + maxi(0, k - 1) * cfg.return_every


## HillRequests (request_table = the large fixture `id`) with `id` accepted at the gate / board of its place and the
## parts flags `parts_done` (§5.1 large_board, parts; W0 stub stores). Added under tree.root when a tree is given.
static func large_pinned(id: StringName, parts_done: Array[bool], tree: SceneTree = null) -> HillRequests:
	var h := HillRequests.new()
	h.config = hill_requests_config()
	var o := large_request(id)
	if o != null:
		var table: Dictionary[StringName, OrderData] = {}
		table[id] = o
		h.request_table = table
	var place := String(o.place) if o != null else "gate"
	h.load_state({"large_board": {place: [String(id)]}, "parts": {String(id): parts_done.duplicate()}})
	if tree != null:
		tree.root.add_child(h)
	return h


# --- v7 saves -------------------------------------------------------------------------------------

## res:// path of a v7 save fixture, e.g. save_v7_path("slot_p8_day63_kindly").
static func save_v7_path(name: String) -> String:
	return SAVES_V7_DIR.path_join(name + ".json")


## Copies a v7 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v7(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v7_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


## The Phase-9 fixture items in the Database while data/items has none of them (test-only; P3 adds the real ones).
## Tests that call letter_in remove them again in after_each (remove_injected_items) – test_inventory counts the items.
static func _inject_items() -> void:
	for id: StringName in ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = item(id)
			_injected.append(id)


## Removes the fixture items letter_in put into the Database (the real data/items ones stay).
static func remove_injected_items() -> void:
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()


static func _json(path: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return doc if doc is Dictionary else {}
