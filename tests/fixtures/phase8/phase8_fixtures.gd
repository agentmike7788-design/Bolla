class_name Phase8Fixtures
extends RefCounted
## Phase-8 test fixtures (W0, docs/PHASE8_DESIGN.md §12). W1 unit tests load these instead of data/ –
## they mirror the contract values and leading texts (§1–§2) at the time of W0 and do not follow later
## balancing / text edits of the real data files. Written by make_phase8_fixtures.gd (historical tool).
##
## *_config_fixture.tres: npc_life, visitor, grave_care, apprentice, robber (= the W0 data/config files =
##   class defaults) + the Phase-8 values of existing configs: npc (+ 5), relationship (gains + 13),
##   orders (max_active_friend), reputation (+ 10 events), piety (+ 4), story (underlined washer), action
##   (noisy_actions), ghost_lines (Phase-7 fixture + by_flowers … by_lights + by_story d2_ott).
## villagers/: the 8 VillagerData (data at W0 + circle, mood_lines, story_id, favor_id, visit_grave,
##   visit_every_days, graveyard_npc, reaction remarks event_<event>). kin/ (7: 4 households + Esch,
##   Theres, Liesel), wishes/ (w_tend, w_flowers, w_candle, w_vase, w_line_1…6), chatter/ (16),
##   apprentice/tasks/ (4), friendship/stories/ (7) + favors/ (7), orders/ (of_* – 22 story orders + 14
##   return favours, category friend), festivals/ (2), wanderers/ (2), night/paths/ (2), recipes/
##   memorial_plate, shops/ (peddler + grocer / smith with the Phase-8 additions), clues/ (c_n_*, 7),
##   insights/ (i_underlined = washer, i_underlined_priest / _surgeon = the other text variants, same id),
##   story/d2_ott, finds/f_d2_* (4); ../items/ + the 10 Phase-8 items (§2.11).
## layout_p7.json / village_layout_p7.json: the approved Phase-7 layouts (a499aa8), byte-identical.
## ../saves_v6/: Phase-7 save files (format v6) – see make_v6_saves.gd.

const DIR := "res://tests/fixtures/phase8"
const CONFIG_NAMES: Array[StringName] = [&"npc_life_config", &"visitor_config", &"grave_care_config", &"apprentice_config",
		&"robber_config"]
## Existing configs with Phase-8 values (W0: class default and data carry them too).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"npc_config", &"relationship_config", &"orders_config", &"reputation_config",
		&"piety_config", &"story_config", &"action_config"]
const VILLAGER_IDS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer",
		&"oldwoman"]
## The seven living villagers with a friendship story (§2.4).
const STORY_NPCS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer"]
const KIN_IDS: Array[StringName] = [&"kin_kehr", &"kin_brandt", &"kin_ott", &"kin_sieber", &"kin_smith", &"kin_grocer",
		&"kin_washer"]
const HOUSEHOLD_KIN: Array[StringName] = [&"kin_kehr", &"kin_brandt", &"kin_ott", &"kin_sieber"]
const WISH_IDS: Array[StringName] = [&"w_tend", &"w_flowers", &"w_candle", &"w_vase", &"w_line_1", &"w_line_2", &"w_line_3",
		&"w_line_4", &"w_line_5", &"w_line_6"]
const CHATTER_IDS: Array[StringName] = [&"ch_well_spin", &"ch_linden_bench", &"ch_inn_council", &"ch_inn_carter",
		&"ch_bridge_water", &"ch_church_alms", &"ch_rumor_robber", &"ch_inn_jakob", &"ch_gate_jakob", &"ch_grave_kehr",
		&"ch_market_rival", &"ch_gate_peddler", &"ch_smith_mayor", &"ch_surgery_priest", &"ch_lights_prepare", &"ch_after_lights"]
const TASK_IDS: Array[StringName] = [&"rake", &"weed", &"water", &"candle"]
const FAVOR_IDS: Array[StringName] = [&"fav_innkeeper", &"fav_smith", &"fav_grocer", &"fav_priest", &"fav_mayor", &"fav_surgeon",
		&"fav_washer"]
## Order-id names of the stories (of_<name>_<n>[_alt], of_<name>_return_<n>; §5.1 "of_esch_return_1").
const ORDER_NAMES: Dictionary[StringName, String] = {&"innkeeper": "rosine", &"smith": "esch", &"grocer": "mangold",
		&"priest": "lenz", &"mayor": "fenner", &"surgeon": "quast", &"washer": "liesel"}
const FESTIVAL_IDS: Array[StringName] = [&"fest_kathrein", &"fest_lights"]
const WANDERER_IDS: Array[StringName] = [&"beggar", &"peddler"]
const NIGHT_PATH_IDS: Array[StringName] = [&"np_ott", &"np_kehr"]
const ITEM_IDS: Array[StringName] = [&"flower_seedlings", &"grave_candle", &"watering_can", &"apprentice_rake", &"mortsafe",
		&"wax_wreath", &"register_extract", &"memorial_plate", &"quast_crate", &"lorenz_ledger_2"]
const SHOP_IDS: Array[StringName] = [&"peddler", &"grocer", &"smith"]
const CLUE_IDS: Array[StringName] = [&"c_n_veit", &"c_n_quast_visit", &"c_n_lenz_visit", &"c_n_liesel_watch", &"c_n_ott_three",
		&"c_n_kladde", &"c_n_robber"]
const UNDERLINED_VARIANTS: Array[StringName] = [&"priest", &"surgeon", &"washer"]
const FIND_IDS: Array[StringName] = [&"f_d2_bottle", &"f_d2_wax", &"f_d2_shirt", &"f_d2_mark"]
## §2.8: the third row of the Lindenacker.
const ROW3_PLOTS: PackedStringArray = ["l_09", "l_10", "l_11", "l_12"]
## §3.1: [class, save_id, save_order, group] of the Phase-8 saveable system nodes (ApprenticeBox: chest 79).
const SAVEABLES := [
	["NpcLife", "npc_life", 70, &"npc_life"], ["Visitors", "visitors", 71, &"visitors"],
	["GraveCare", "grave_care", 72, &"grave_care"], ["Apprentice", "apprentice", 73, &"apprentice"],
	["Friendship", "friendship", 74, &"friendship"], ["Festivals", "festivals", 75, &"festivals"],
	["Wanderers", "wanderers", 76, &"wanderers"], ["NightRobber", "night_robber", 77, &"night_robber"],
	["NightPaths", "night_paths", 78, &"night_paths"],
]
const SAVES_V6_DIR := "res://tests/fixtures/saves_v6"
const SAVES_V6: PackedStringArray = ["slot_p7_day53_neighbor", "slot_p7_day53_anatomist", "slot_p7_day50_eve", "slot_p7_founder",
		"slot_p7_mid_inn", "slot_p7_crypt_corpse"]
const LAYOUT_P7 := DIR + "/layout_p7.json"
const VILLAGE_LAYOUT_P7 := DIR + "/village_layout_p7.json"
## The reference opening day of arc A (§1.4: v6 slot_p7_day53_neighbor, 24. Nebelung).
const OPEN_DAY := 53

static var _corpse_counter: int = 0
static var _wish_counter: int = 0


# --- configs ------------------------------------------------------------------------------------

static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func npc_life_config() -> NpcLifeConfig:
	return config(&"npc_life_config") as NpcLifeConfig


static func visitor_config() -> VisitorConfig:
	return config(&"visitor_config") as VisitorConfig


static func grave_care_config() -> GraveCareConfig:
	return config(&"grave_care_config") as GraveCareConfig


static func apprentice_config() -> ApprenticeConfig:
	return config(&"apprentice_config") as ApprenticeConfig


static func robber_config() -> RobberConfig:
	return config(&"robber_config") as RobberConfig


static func npc_config() -> NpcConfig:
	return config(&"npc_config") as NpcConfig


static func relationship_config() -> RelationshipConfig:
	return config(&"relationship_config") as RelationshipConfig


static func orders_config() -> OrdersConfig:
	return config(&"orders_config") as OrdersConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func story_config() -> StoryConfig:
	return config(&"story_config") as StoryConfig


static func action_config() -> ActionConfig:
	return config(&"action_config") as ActionConfig


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


# --- data ---------------------------------------------------------------------------------------

static func villager_data(npc_id: StringName) -> VillagerData:
	return load(DIR + "/villagers/%s.tres" % npc_id) as VillagerData


static func villagers() -> Array[VillagerData]:
	var out: Array[VillagerData] = []
	for id: StringName in VILLAGER_IDS:
		out.append(villager_data(id))
	return out


static func kin(kin_id: StringName) -> KinData:
	return load(DIR + "/kin/%s.tres" % kin_id) as KinData


static func kin_list() -> Array[KinData]:
	var out: Array[KinData] = []
	for id: StringName in KIN_IDS:
		out.append(kin(id))
	return out


static func wish(id: StringName) -> WishData:
	return load(DIR + "/wishes/%s.tres" % id) as WishData


static func wishes() -> Array[WishData]:
	var out: Array[WishData] = []
	for id: StringName in WISH_IDS:
		out.append(wish(id))
	return out


static func chatter(id: StringName) -> ChatterData:
	return load(DIR + "/chatter/%s.tres" % id) as ChatterData


static func chatters() -> Array[ChatterData]:
	var out: Array[ChatterData] = []
	for id: StringName in CHATTER_IDS:
		out.append(chatter(id))
	return out


static func apprentice_task(id: StringName) -> ApprenticeTaskData:
	return load(DIR + "/apprentice/tasks/%s.tres" % id) as ApprenticeTaskData


static func apprentice_tasks() -> Array[ApprenticeTaskData]:
	var out: Array[ApprenticeTaskData] = []
	for id: StringName in TASK_IDS:
		out.append(apprentice_task(id))
	return out


static func friend_story(npc_id: StringName) -> FriendStoryData:
	return load(DIR + "/friendship/stories/%s.tres" % npc_id) as FriendStoryData


static func friend_stories() -> Array[FriendStoryData]:
	var out: Array[FriendStoryData] = []
	for id: StringName in STORY_NPCS:
		out.append(friend_story(id))
	return out


static func favor(id: StringName) -> FavorData:
	return load(DIR + "/friendship/favors/%s.tres" % id) as FavorData


static func favors() -> Array[FavorData]:
	var out: Array[FavorData] = []
	for id: StringName in FAVOR_IDS:
		out.append(favor(id))
	return out


## of_<name>_<n>[_alt] / of_<name>_return_<n> (OrderData, category friend).
static func order(id: StringName) -> OrderData:
	return load(DIR + "/orders/%s.tres" % id) as OrderData


## Every friend order id: the story steps (+ Liesel's variant) and the return favours.
static func order_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for npc: StringName in STORY_NPCS:
		for step: FriendStepData in friend_story(npc).steps:
			for id: StringName in step.order_ids:
				out.append(id)
		for id: StringName in favor(StringName("fav_" + String(npc))).return_orders:
			out.append(id)
	return out


static func festival(id: StringName) -> FestivalData:
	return load(DIR + "/festivals/%s.tres" % id) as FestivalData


static func festivals() -> Array[FestivalData]:
	var out: Array[FestivalData] = []
	for id: StringName in FESTIVAL_IDS:
		out.append(festival(id))
	return out


static func wanderer(id: StringName) -> WandererData:
	return load(DIR + "/wanderers/%s.tres" % id) as WandererData


static func night_path(id: StringName) -> NightPathData:
	return load(DIR + "/night/paths/%s.tres" % id) as NightPathData


static func night_paths() -> Array[NightPathData]:
	var out: Array[NightPathData] = []
	for id: StringName in NIGHT_PATH_IDS:
		out.append(night_path(id))
	return out


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


static func recipe(id: StringName = &"memorial_plate") -> RecipeData:
	return load(DIR + "/recipes/%s.tres" % id) as RecipeData


static func shop(id: StringName) -> ShopData:
	return load(DIR + "/shops/%s.tres" % id) as ShopData


static func clue(id: StringName) -> ClueData:
	return load(DIR + "/clues/%s.tres" % id) as ClueData


## i_underlined in the text variant `who` (priest | surgeon | washer; washer = StoryConfig.underlined, §14.1).
static func insight(who: StringName = &"washer") -> InsightData:
	if who == &"washer":
		return load(DIR + "/insights/i_underlined.tres") as InsightData
	return load(DIR + "/insights/i_underlined_%s.tres" % who) as InsightData


static func d2_story() -> StoryCorpseData:
	return load(DIR + "/story/d2_ott.tres") as StoryCorpseData


static func find(id: StringName) -> FindData:
	return load(DIR + "/finds/%s.tres" % id) as FindData


## The approved Phase-7 graveyard layout (a499aa8) as a Dictionary ({} if unreadable).
static func layout_p7() -> Dictionary:
	return _json(LAYOUT_P7)


static func village_layout_p7() -> Dictionary:
	return _json(VILLAGE_LAYOUT_P7)


# --- state helpers (§12 W0) -----------------------------------------------------------------------

## Opens Phase 8 in GameState (village_open, name_in_village_complete, p8_open, p8_open_day = `day`)
## and returns an NpcLife (W0 stub: is_open / open_day read these flags). Added under tree.root when a
## tree is given (group npc_life). The caller frees it.
static func p8_open(tree: SceneTree = null, day: int = OPEN_DAY) -> NpcLife:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"name_in_village_complete", true)
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", day)
	var life := NpcLife.new()
	life.config = npc_life_config()
	if tree != null:
		tree.root.add_child(life)
	return life


## A dead of `kin` buried in `plot` on `buried_day` (pure data, nothing installed):
## {"record": CorpseRecord (kin_house = the kin's house; "" for villagers with fixed graves), "grave":
## GraveRecord (id `plot`, MARKED with a cross, completed_day = buried_day)}.
static func kin_grave(kin_id: StringName, plot: String, buried_day: int) -> Dictionary:
	_corpse_counter += 1
	var r := Phase5Fixtures.corpse(64, &"old_age", &"", (buried_day - 1) * 1440 + 460)
	r.id = "corpse_p8_%04d" % _corpse_counter
	r.display_name = "Hedwig Lamprecht"
	var k := kin(kin_id)
	r.kin_house = k.house if k != null and k.villager_id == &"" else &""
	r.location = CorpseRecord.LOCATION_BURIED
	r.grave_id = plot
	r.buried_day = buried_day
	var g := GraveRecord.new()
	g.id = plot
	g.corpse_id = r.id
	g.state = GraveRecord.State.MARKED
	g.marker_id = &"wooden_cross"
	g.completed_day = buried_day
	return {"record": r, "grave": g}


## Visitors with `kin` on the graveyard now at `grave` in `phase` (§5.1 plan of `day`; the W0 key
## "phase" – see Visitors). Added under tree.root when a tree is given. The caller frees it.
static func visit_now(kin_id: StringName, grave_id: String, phase: StringName = &"mourning", tree: SceneTree = null,
		day: int = -1) -> Visitors:
	var d := day if day > 0 else TimeManager.day
	var v := Visitors.new()
	v.config = visitor_config()
	v.load_state({"plan_day": d, "plan": [{"visit_id": "v_%d_1" % d, "kin_id": String(kin_id), "graves": [grave_id],
			"slot": 570, "phase": String(phase)}], "goodwill": {String(kin_id): visitor_config().goodwill_start}})
	if tree != null:
		tree.root.add_child(v)
	return v


## Visitors with one open wish of `kind` at `grave` (state accepted by default, §5.1 wishes[]).
static func wish_open(grave_id: String, kind: StringName, tree: SceneTree = null, kin_id: StringName = &"kin_kehr",
		state: StringName = &"accepted", day: int = -1) -> Visitors:
	_wish_counter += 1
	var v := Visitors.new()
	v.config = visitor_config()
	v.load_state({"wishes": [{"wish_id": "w_%04d" % _wish_counter, "kind": String(kind), "grave_id": grave_id,
			"kin_id": String(kin_id), "state": String(state), "day": day if day > 0 else TimeManager.day, "candle_seen": false}],
			"next_wish": _wish_counter + 1})
	if tree != null:
		tree.root.add_child(v)
	return v


## GraveCare with grave flowers at `grave` in `state` (&"fresh" | &"wilted" | &"wreath" | &"" = none) at the
## current clock (§5.1 flowers{planted, watered, wreath}).
static func flowers(grave_id: String, state: StringName, tree: SceneTree = null) -> GraveCare:
	var cfg := grave_care_config()
	var now := TimeManager.total_minutes()
	var flowers_state := {}
	match state:
		&"fresh":
			flowers_state[grave_id] = {"planted": now, "watered": now, "wreath": false}
		&"wilted":
			flowers_state[grave_id] = {"planted": now - cfg.flower_fresh_minutes, "watered": now - cfg.flower_fresh_minutes, "wreath": false}
		&"wreath":
			flowers_state[grave_id] = {"planted": now, "watered": now, "wreath": true}
	var gc := GraveCare.new()
	gc.config = cfg
	gc.load_state({"flowers": flowers_state, "can_fill": {"player": cfg.can_fills, "apprentice": cfg.can_fills}})
	if tree != null:
		tree.root.add_child(gc)
	return gc


## {"apprentice": Apprentice hired with `levels` {task: 0…2} and the board `lines` [{task, area}],
## "box": ApprenticeBox (scene) with `coins` in the tin}. Added under tree.root when a tree is given
## (the box needs the tree for its Storage). The caller frees both.
static func apprentice_with(levels: Dictionary, lines: Array = [], coins: int = 0, tree: SceneTree = null) -> Dictionary:
	var a := Apprentice.new()
	a.config = apprentice_config()
	var lv := {}
	for key: Variant in levels:
		lv[str(key)] = int(levels[key])
	var board: Array = []
	for line: Variant in lines:
		if line is Dictionary:
			board.append({"task": str((line as Dictionary).get("task", "")), "area": str((line as Dictionary).get("area", "all"))})
	a.load_state({"hired": true, "hire_day": OPEN_DAY, "levels": lv, "jobs": {}, "board": board, "morale": apprentice_config().morale_start,
			"unpaid": 0})
	var box := (load("res://src/entities/apprentice_box/apprentice_box.tscn") as PackedScene).instantiate() as ApprenticeBox
	if tree != null:
		tree.root.add_child(a)
		tree.root.add_child(box)
		box.load_state({"storage": {}, "coins": coins})
	else:
		box.coins = coins
	return {"apprentice": a, "box": box}


## Friendship with `npc` at `step` done (more: {npc: step}) through load_state (§5.1 steps).
static func story_at(npc_id: StringName, step: int, tree: SceneTree = null, more: Dictionary = {}) -> Friendship:
	var steps := {String(npc_id): step}
	for key: Variant in more:
		steps[str(key)] = int(more[key])
	var f := Friendship.new()
	f.load_state({"steps": steps})
	if tree != null:
		tree.root.add_child(f)
	return f


## Festivals with `fest_id` today (or on `day`); the day flag (fest_kathrein_day / fest_lights_day) is set
## in GameState too.
static func fest_today(fest_id: StringName, tree: SceneTree = null, day: int = -1) -> Festivals:
	var d := day if day > 0 else TimeManager.day
	var data := festival(fest_id)
	if data != null:
		GameState.set_flag(data.day_flag, d)
	var f := Festivals.new()
	f.load_state({"days": {String(fest_id): d}})
	if tree != null:
		tree.root.add_child(f)
	return f


## NightRobber with `grave` as tonight's target (the night after `day`; §5.1 target_day / target).
static func robber_night(grave_id: String, tree: SceneTree = null, day: int = -1, encounters: int = 0) -> NightRobber:
	var d := day if day > 0 else TimeManager.day
	var r := NightRobber.new()
	r.config = robber_config()
	r.load_state({"target_day": d, "target": grave_id, "encounters": encounters, "disturbed": 0, "last_night": 0, "fate": ""})
	if tree != null:
		tree.root.add_child(r)
	return r


## The night `offset` of the sick-light path `path_id` (np_ott / np_kehr) with Phase 8 opened on `open_day`
## (p8_open flags set): {"day": open_day + offset, "path": NightPathData, "visits": [NightVisitData of that
## night], "burning": offset inside start_offset … end_offset}.
static func sick_light(path_id: StringName, offset: int, open_day: int = OPEN_DAY) -> Dictionary:
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", open_day)
	var path := night_path(path_id)
	var visits: Array[NightVisitData] = []
	if path != null:
		for v: NightVisitData in path.visits:
			if v.night_offset == offset:
				visits.append(v)
	return {"day": open_day + offset, "path": path, "visits": visits,
			"burning": path != null and offset >= path.start_offset and offset <= path.end_offset}


# --- v6 saves -------------------------------------------------------------------------------------

## res:// path of a v6 save fixture, e.g. save_v6_path("slot_p7_day53_neighbor").
static func save_v6_path(name: String) -> String:
	return SAVES_V6_DIR.path_join(name + ".json")


## Copies a v6 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v6(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v6_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


static func _json(path: String) -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return doc if doc is Dictionary else {}
