class_name Phase7Fixtures
extends RefCounted
## Phase-7 test fixtures (W0, docs/PHASE7_DESIGN.md §12). W1 unit tests load these instead of data/ –
## they mirror the contract values and leading texts (§1–§2) at the time of W0 and do not follow later
## balancing / text edits of the real data files. Written by make_phase7_fixtures.gd (historical tool).
##
## *_config_fixture.tres: village, relationship, orders, anatomy, npc (= the W0 data/config files =
##   class defaults) + the Phase-7 values of existing configs: economy (harvest_malus + 7 organs),
##   reputation (+ organ_taken, organ_taken_grave, lecture_rumor, donation, order_failed), piety
##   (+ organ_taken, lecture_attended, specimen_returned, specimen_returned_grave), prep (balm_items +
##   corpse_balm), shed (excluded_items + the 4 specimen items), corpse_tables (data + hidden_causes),
##   ghost_lines (Phase-6 fixture + by_organ, by_returned).
## regions/: graveyard, village (RegionConfig). villagers/: the 8 VillagerData (§2.1). schedules/: the 8
##   villagers' NpcSchedule (§2.2, region village; the priest's consecration day with today_flag on the
##   graveyard) + carter_schedule.tres (data + Osric's village entries). shops/ (6), orders/ (23),
##   findings/ (15), teachings/ (7), deductions/ (5), medicines/ (3), sets/ (4), recipes/ (3),
##   stations/pult.tres, sections/linden.tres, story/d1_hagedorn.tres, finds/f_d1_*, clues/c_v_* (7),
##   insights/ (i_deathbook, i_burn_it), interiors/ (inn, surgery, office InteriorConfig),
##   ../items/ + the 17 Phase-7 items (§2.8).
## village_layout.json: region-local plan of Hollerbrück (§4.2–§4.4); linden_layout.json: the graveyard
##   additions (§4.6); layout_p6.json: the approved Phase-6 graveyard layout (705bd5a), byte-identical.
## ../saves_v5/: Phase-6 save files (format v5) – see make_v5_saves.gd.

const DIR := "res://tests/fixtures/phase7"
const CONFIG_NAMES: Array[StringName] = [&"village_config", &"relationship_config", &"orders_config", &"anatomy_config",
		&"npc_config"]
## Existing configs with Phase-7 values (fixtures only; the data files belong to their owners).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"economy_config", &"reputation_config", &"piety_config", &"prep_config",
		&"shed_config"]
const REGION_IDS: Array[StringName] = [&"graveyard", &"village"]
const VILLAGER_IDS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer",
		&"oldwoman"]
const SHOP_IDS: Array[StringName] = [&"grocer", &"smith", &"inn", &"priest", &"surgeon", &"washer"]
const ORDER_IDS: Array[StringName] = [&"o_fenner_linden", &"o_fenner_well", &"o_fenner_bridge", &"o_rosine_berries",
		&"o_rosine_tincture", &"o_esch_charcoal", &"o_esch_stone", &"o_mangold_stone", &"o_lenz_service", &"o_lenz_poor",
		&"o_quast_tincture", &"o_quast_specimen", &"o_quast_antidote", &"o_fenner_dropsy", &"o_quast_cabinet",
		&"o_liesel_gowns", &"o_hagedorn_place", &"ob_wood", &"ob_stone", &"ob_herbs", &"ob_yarn", &"ob_gown", &"ob_tend"]
const BOARD_IDS: Array[StringName] = [&"ob_wood", &"ob_stone", &"ob_herbs", &"ob_yarn", &"ob_gown", &"ob_tend"]
const FINDING_IDS: Array[StringName] = [&"b_still_heart", &"b_old_heart", &"b_white_stomach", &"b_empty_stomach",
		&"b_dry_lungs", &"b_wet_lungs", &"b_spotted_lungs", &"b_hard_liver", &"b_pale_liver", &"b_stones", &"b_moor_eyes",
		&"b_fever_eyes", &"b_oath_hand", &"b_worker_hand", &"b_plain"]
const TEACHING_IDS: Array[StringName] = [&"l_lung", &"l_liver", &"l_heart", &"l_stomach", &"l_kidneys", &"l_eyes", &"l_hand"]
const DEDUCTION_IDS: Array[StringName] = [&"d_arsenic", &"d_dry_lungs", &"d_still_heart", &"d_drink", &"d_moor"]
const MEDICINE_IDS: Array[StringName] = [&"antidote", &"bitter_drops", &"dropsy_powder"]
const SET_IDS: Array[StringName] = [&"set_chest", &"set_body", &"set_senses", &"set_complete"]
const RECIPE_IDS: Array[StringName] = [&"fever_tincture", &"wound_salve", &"corpse_balm"]
const ITEM_IDS: Array[StringName] = [&"prep_jar", &"prep_jar_small", &"spirits", &"beeswax", &"anatomy_case",
		&"specimen_jar", &"specimen_bundle", &"bone_specimen", &"antidote", &"bitter_drops", &"dropsy_powder",
		&"display_specimen", &"fever_tincture", &"wound_salve", &"corpse_balm", &"honey_cake", &"elder_wine"]
const UNIQUE_ITEMS: Array[StringName] = [&"specimen_jar", &"specimen_bundle", &"display_specimen", &"bone_specimen"]
const CLUE_IDS: Array[StringName] = [&"c_v_three_visitors", &"c_v_deathbook", &"c_v_washing", &"c_v_hagedorn",
		&"c_v_arsenic", &"c_v_dry_lungs", &"c_v_still_heart"]
const INSIGHT_IDS: Array[StringName] = [&"i_deathbook", &"i_burn_it"]
const FIND_IDS: Array[StringName] = [&"f_d1_poppy", &"f_d1_mark", &"f_d1_note"]
const LINDEN_PLOTS: PackedStringArray = ["l_01", "l_02", "l_03", "l_04", "l_05", "l_06", "l_07", "l_08"]
## §4.3: world origin, floor size (m), camera distance / zoom of the village rooms; door id.
const ROOMS: Dictionary = {
	&"inn": {"origin": Vector3(240, 0, -200), "size": Vector2(8, 6), "distance": 10.0, "zoom": Vector2(8, 12), "door": &"door_inn"},
	&"surgery": {"origin": Vector3(300, 0, -200), "size": Vector2(6, 5), "distance": 9.0, "zoom": Vector2(7, 11), "door": &"door_surgery"},
	&"office": {"origin": Vector3(360, 0, -200), "size": Vector2(6, 5), "distance": 9.0, "zoom": Vector2(7, 11), "door": &"door_office"},
}
## §2.2: opening windows of the houses ([from, to, …] minutes of day).
const OPEN_WINDOWS: Dictionary = {
	&"door_inn": [410, 1410], &"door_surgery": [475, 720, 840, 1080], &"door_office": [475, 720, 785, 960],
}
## §3.1: [class, save_id, save_order, group] of the Phase-7 saveables.
const SAVEABLES := [
	["Village", "village", 50, &"village"], ["Relationships", "relationships", 51, &"relationships"],
	["VillageShops", "village_shops", 52, &"village_shops"], ["Orders", "orders", 53, &"orders"],
	["Specimens", "specimens", 54, &"specimens"], ["Lectures", "lectures", 55, &"lectures"],
	["Deductions", "deductions", 56, &"deductions"],
]
const SAVES_V5_DIR := "res://tests/fixtures/saves_v5"
const SAVES_V5: PackedStringArray = ["slot_p6_day40_reverent", "slot_p6_day45_harvester", "slot_p6_day41_mender",
		"slot_p6_day37_founder", "slot_p6_day37_eve", "slot_p6_crypt_table", "slot_p6_chapel_carry"]
const LAYOUT_P6 := DIR + "/layout_p6.json"
const VILLAGE_LAYOUT := DIR + "/village_layout.json"
const LINDEN_LAYOUT := DIR + "/linden_layout.json"

static var _uid_counter: int = 0


# --- configs ------------------------------------------------------------------------------------

static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func village_config() -> VillageConfig:
	return config(&"village_config") as VillageConfig


static func relationship_config() -> RelationshipConfig:
	return config(&"relationship_config") as RelationshipConfig


static func orders_config() -> OrdersConfig:
	return config(&"orders_config") as OrdersConfig


static func anatomy_config() -> AnatomyConfig:
	return config(&"anatomy_config") as AnatomyConfig


static func npc_config() -> NpcConfig:
	return config(&"npc_config") as NpcConfig


static func economy_config() -> EconomyConfig:
	return config(&"economy_config") as EconomyConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func prep_config() -> PrepConfig:
	return config(&"prep_config") as PrepConfig


static func shed_config() -> ShedConfig:
	return config(&"shed_config") as ShedConfig


static func corpse_tables() -> CorpseTables:
	return load(DIR + "/corpse_tables_fixture.tres") as CorpseTables


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


static func region(id: StringName) -> RegionConfig:
	return load(DIR + "/regions/%s.tres" % id) as RegionConfig


## InteriorConfig of a village room (inn, surgery, office).
static func room_config(room_id: StringName) -> InteriorConfig:
	return load(DIR + "/interiors/%s.tres" % room_id) as InteriorConfig


# --- data ---------------------------------------------------------------------------------------

static func villager_data(npc_id: StringName) -> VillagerData:
	return load(DIR + "/villagers/%s.tres" % npc_id) as VillagerData


static func villagers() -> Array[VillagerData]:
	var out: Array[VillagerData] = []
	for id: StringName in VILLAGER_IDS:
		out.append(villager_data(id))
	return out


## NpcSchedule of a villager or carter (data + Osric's village entries).
static func schedule(npc_id: StringName) -> NpcSchedule:
	return load(DIR + "/schedules/%s_schedule.tres" % npc_id) as NpcSchedule


static func shop(id: StringName) -> ShopData:
	return load(DIR + "/shops/%s.tres" % id) as ShopData


static func shops() -> Array[ShopData]:
	var out: Array[ShopData] = []
	for id: StringName in SHOP_IDS:
		out.append(shop(id))
	return out


static func order(id: StringName) -> OrderData:
	return load(DIR + "/orders/%s.tres" % id) as OrderData


static func orders(board_only: bool = false) -> Array[OrderData]:
	var out: Array[OrderData] = []
	for id: StringName in ORDER_IDS:
		var o := order(id)
		if not board_only or o.board:
			out.append(o)
	return out


static func finding(id: StringName) -> SpecimenFindingData:
	return load(DIR + "/findings/%s.tres" % id) as SpecimenFindingData


## All findings in the order of §2.6.3 (b_plain last).
static func findings() -> Array[SpecimenFindingData]:
	var out: Array[SpecimenFindingData] = []
	for id: StringName in FINDING_IDS:
		out.append(finding(id))
	return out


static func teaching(id: StringName) -> TeachingData:
	return load(DIR + "/teachings/%s.tres" % id) as TeachingData


static func teachings() -> Array[TeachingData]:
	var out: Array[TeachingData] = []
	for id: StringName in TEACHING_IDS:
		out.append(teaching(id))
	return out


static func deduction(id: StringName) -> DeductionData:
	return load(DIR + "/deductions/%s.tres" % id) as DeductionData


static func deductions() -> Array[DeductionData]:
	var out: Array[DeductionData] = []
	for id: StringName in DEDUCTION_IDS:
		out.append(deduction(id))
	return out


static func medicine(id: StringName) -> MedicineData:
	return load(DIR + "/medicines/%s.tres" % id) as MedicineData


static func medicines() -> Array[MedicineData]:
	var out: Array[MedicineData] = []
	for id: StringName in MEDICINE_IDS:
		out.append(medicine(id))
	return out


static func collection_set(id: StringName) -> CollectionSetData:
	return load(DIR + "/sets/%s.tres" % id) as CollectionSetData


static func collection_sets() -> Array[CollectionSetData]:
	var out: Array[CollectionSetData] = []
	for id: StringName in SET_IDS:
		out.append(collection_set(id))
	return out


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


static func recipe(id: StringName) -> RecipeData:
	return load(DIR + "/recipes/%s.tres" % id) as RecipeData


static func pult_station() -> StationData:
	return load(DIR + "/stations/pult.tres") as StationData


static func linden_section() -> SectionData:
	return load(DIR + "/sections/linden.tres") as SectionData


static func d1_story() -> StoryCorpseData:
	return load(DIR + "/story/d1_hagedorn.tres") as StoryCorpseData


static func find(id: StringName) -> FindData:
	return load(DIR + "/finds/%s.tres" % id) as FindData


static func clue(id: StringName) -> ClueData:
	return load(DIR + "/clues/%s.tres" % id) as ClueData


static func insight(id: StringName) -> InsightData:
	return load(DIR + "/insights/%s.tres" % id) as InsightData


static func village_layout() -> Dictionary:
	return _json(VILLAGE_LAYOUT)


static func linden_layout() -> Dictionary:
	return _json(LINDEN_LAYOUT)


## The approved Phase-6 layout (705bd5a) as a Dictionary ({} if unreadable).
static func layout_p6() -> Dictionary:
	return _json(LAYOUT_P6)


# --- state helpers (§12 W0) -----------------------------------------------------------------------

## A RegionRoot `id` with its fixture config (not in a world). Added under tree.root when a tree is
## given (group region_root – RegionRoot.find finds it). The caller frees it.
static func region_at(id: StringName, tree: SceneTree = null) -> RegionRoot:
	var r := RegionRoot.new()
	r.name = "Region_%s" % id
	r.region_id = id
	r.config = region(id)
	if tree != null:
		tree.root.add_child(r)
	return r


## Relationships with `npc_id` met at `value` (more: values {npc: value}) through load_state (§5.1
## format; works with the W0 stub and with P2). Added under tree.root when a tree is given (group
## relationships). The caller frees it.
static func villager(npc_id: StringName, value: int, tree: SceneTree = null, more: Dictionary = {}) -> Relationships:
	var rel := Relationships.new()
	rel.config = relationship_config()
	var values := {String(npc_id): value}
	for key: Variant in more:
		values[str(key)] = int(more[key])
	rel.load_state({"values": values, "met": values.keys()})
	if tree != null:
		tree.root.add_child(rel)
	return rel


## Orders with `order_id` in `state` (offered | accepted | completed | failed; more: {id: state})
## through load_state (§5.1). Added under tree.root when a tree is given (group orders). The caller
## frees it.
static func order_in(order_id: StringName, state: StringName, tree: SceneTree = null, more: Dictionary = {},
		accepted_day: int = 1) -> Orders:
	var o := Orders.new()
	o.config = orders_config()
	var states := {String(order_id): String(state)}
	var days := {}
	for key: Variant in more:
		states[str(key)] = str(more[key])
	for key: String in states:
		if states[key] == "accepted":
			days[key] = accepted_day
	o.load_state({"states": states, "accepted_day": days})
	if tree != null:
		tree.root.add_child(o)
	return o


## A SpecimenRecord (pure data, uid "sp_9xxx"): `organ` in `container` with `clarity`, of `corpse`
## (Phase5Fixtures.corpse(58, fever) „Hedwig Lamprecht" when null), harvested at `harvest_total`.
static func specimen(organ: StringName, container: StringName = SpecimenRecord.CONTAINER_JAR, clarity: float = 0.9,
		corpse: CorpseRecord = null, harvest_total: int = 600) -> SpecimenRecord:
	_uid_counter += 1
	var c := corpse
	if c == null:
		c = Phase5Fixtures.corpse(58, &"fever")
		c.id = "c_test"
		c.display_name = "Hedwig Lamprecht"
	var s := SpecimenRecord.new()
	s.uid = "sp_%04d" % (9000 + _uid_counter)
	s.corpse_id = c.id
	s.corpse_name = c.display_name
	s.organ = organ
	s.container = container
	s.clarity_at_harvest = clarity
	s.harvest_total = harvest_total
	s.day = harvest_total / 1440 + 1
	return s


## {organ: SpecimenRecord} as CollectionRules.completed_sets reads the shelf (W0-Notizen); organs in
## `display` are display specimens, the hand a bone specimen, all others jars.
static func shelf_with(organs: Array, display: Array = []) -> Dictionary:
	var out := {}
	for o: Variant in organs:
		var organ := StringName(str(o))
		var container := SpecimenRecord.CONTAINER_JAR
		if organ == &"hand":
			container = SpecimenRecord.CONTAINER_BONE
		if display.has(o) or display.has(organ):
			container = SpecimenRecord.CONTAINER_DISPLAY
		out[organ] = specimen(organ, container)
	return out


## Lectures invited, knowing the basic teachings (+ `teachings`), the last lecture 3 days before `day`
## (§5.1). lecture_minute(day) is 23:30 of that night. Added under tree.root when a tree is given.
static func lecture_night(day: int = 3, tree: SceneTree = null, teachings: Array = []) -> Lectures:
	var l := Lectures.new()
	l.config = anatomy_config()
	var known: Array = ["l_lung", "l_liver"]
	for t: Variant in teachings:
		if not known.has(str(t)):
			known.append(str(t))
	l.load_state({"invited": true, "last_day": day - 3, "attended": 0, "teachings": known})
	if tree != null:
		tree.root.add_child(l)
	return l


## Total minutes of 23:30 on `day` (TimeManager.total_minutes formula) – inside the lecture window.
static func lecture_minute(day: int = 3) -> int:
	return (day - 1) * 1440 + 23 * 60 + 30


## Deductions holding the cards `ids` for `corpse_id` (§5.1). Added under tree.root when a tree is given.
static func cards_for(corpse_id: String, ids: Array, tree: SceneTree = null) -> Deductions:
	var d := Deductions.new()
	var cards: Array = []
	for id: Variant in ids:
		cards.append(str(id))
	d.load_state({"cards": {corpse_id: cards}, "done": {}})
	if tree != null:
		tree.root.add_child(d)
	return d


## VillageShops with today's stock {shop_id: {item: left}} (§5.1 stock_left; bought_left {shop_id:
## {item: left}} optional) for `day`. Added under tree.root when a tree is given.
static func shop_with(stock: Dictionary, day: int = 1, bought: Dictionary = {}, tree: SceneTree = null) -> VillageShops:
	var s := VillageShops.new()
	s.load_state({"stock_day": day, "stock_left": stock.duplicate(true), "bought_left": bought.duplicate(true)})
	if tree != null:
		tree.root.add_child(s)
	return s


## Sets village_open (day `open_day`), linden_granted and linden_consecrated in GameState and – when the
## tree holds an ExpansionManager – unlocks the section linden (the obstacles count as cleared).
## Returns whether the section is unlocked afterwards (false without a world or before P3).
static func linden_open(tree: SceneTree = null, open_day: int = 40) -> bool:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"village_open_day", open_day)
	GameState.set_flag(&"linden_granted", true)
	GameState.set_flag(&"linden_consecrated", true)
	if tree == null:
		return false
	for node: Node in tree.root.find_children("*", "ExpansionManager", true, false):
		var em := node as ExpansionManager
		if em.section(&"linden") == null:
			return false
		em.unlock(&"linden")
		return em.is_unlocked(&"linden")
	return false


## Unlimited test inventory (Phase5Fixtures.inv_with_tools) with `items`. The caller frees it.
static func inv_with(items: Dictionary = {}, tiers: Dictionary = {}) -> Inventory:
	return Phase5Fixtures.inv_with_tools(tiers, items)


# --- v5 saves -------------------------------------------------------------------------------------

## res:// path of a v5 save fixture, e.g. save_v5_path("slot_p6_day40_reverent").
static func save_v5_path(name: String) -> String:
	return SAVES_V5_DIR.path_join(name + ".json")


## Copies a v5 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v5(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v5_path(name))
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
