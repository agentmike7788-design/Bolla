class_name Phase6Fixtures
extends RefCounted
## Phase-6 test fixtures (W0, docs/PHASE6_DESIGN.md §12). W1 unit tests load these instead of
## data/ – they mirror the contract values and leading texts (§2) at the time of W0 and do not
## follow later balancing / text edits of the real data files.
##
## *_config_fixture.tres: buildings, crypt, chapel, shed (= the W0 data/config files) + the Phase-6
##   values of existing configs: economy (quality_service 1, quality_max 20), reputation (+ reinterred
##   1), piety (+ service, devotion, reinterred 1), ghost (+ devotion_robbed_cap 8), decay_visual
##   (+ niche_fly_scale 0, niche_wisp_scale 0.5, niche_chill_particles 2).
## ghost_lines_fixture.tres: the Phase-5 fixture + by_service and by_devotion (default, robbed) with
##   the leading texts of §2.4.
## buildings/: crypt, chapel, shed with their 3 levels (§2.1; texts are W0 drafts – P1 words them).
## old_graves/: old_01…08 (§2.3; old_01 / old_08 in their rest period, reinter_line "").
## recipes/bone_box.tres, clues/c_crypt_draft.tres, ../items/{altar_candle, bone_box, bone_box_full}.
## interiors/: InteriorConfig per room (crypt, chapel, shed; §4.8). ROOMS: origins, bounds and
##   camera of the rooms (§4.7). NICHES: slot ids and min_level (§2.2).
## ../saves_v4/: Phase-5 save files (format v4) – see make_v4_saves.gd. layout_p5.json: the
##   approved Phase-5 layout (c5bd76d) for the W-Welt layout diff.

const DIR := "res://tests/fixtures/phase6"
const CONFIG_NAMES: Array[StringName] = [&"buildings_config", &"crypt_config", &"chapel_config", &"shed_config"]
## Existing configs with Phase-6 values (fixtures only; the data files belong to their owners).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"economy_config", &"reputation_config", &"piety_config",
		&"ghost_config", &"decay_visual_config"]
const BUILDING_IDS: Array[StringName] = [&"crypt", &"chapel", &"shed"]
const OLD_GRAVE_IDS: PackedStringArray = ["old_01", "old_02", "old_03", "old_04", "old_05", "old_06", "old_07", "old_08"]
## The 6 liftable old graves (rest period over in 1834).
const LIFTABLE_IDS: PackedStringArray = ["old_02", "old_03", "old_04", "old_05", "old_06", "old_07"]
const ITEM_IDS: Array[StringName] = [&"altar_candle", &"bone_box", &"bone_box_full"]
const ROOM_IDS: Array[StringName] = [&"crypt", &"chapel", &"shed"]
## The game year of Phase 6 (StoneConfig.calendar.start_year).
const YEAR := 1834
## slot_id → min_level (§2.2 CryptNiche).
const NICHES: Dictionary = {"niche_1": 1, "niche_2": 1, "niche_3": 2, "niche_4": 2, "niche_5": 3, "niche_6": 3}
## §4.7: world origin, floor size (m), camera distance / zoom of the rooms.
const ROOMS: Dictionary = {
	&"hut": {"origin": Vector3(0, 0, -200), "size": Vector2(5, 4), "distance": 9.0, "zoom": Vector2(7, 11), "building": &""},
	&"crypt": {"origin": Vector3(60, 0, -200), "size": Vector2(8, 6), "distance": 10.0, "zoom": Vector2(8, 12), "building": &"crypt"},
	&"chapel": {"origin": Vector3(120, 0, -200), "size": Vector2(5, 7.5), "distance": 11.0, "zoom": Vector2(9, 13), "building": &"chapel"},
	&"shed": {"origin": Vector3(180, 0, -200), "size": Vector2(3.2, 3.6), "distance": 8.0, "zoom": Vector2(7, 10), "building": &"shed"},
}
const SAVES_V4_DIR := "res://tests/fixtures/saves_v4"
const SAVES_V4: PackedStringArray = ["slot_p5_day30_reverent", "slot_p5_day35_harvester", "slot_p5_day30_mender",
		"slot_p5_day16_table", "slot_p5_day16_carry", "slot_p5_day20_crafter", "slot_p5_interior"]
const LAYOUT_P5 := DIR + "/layout_p5.json"


static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func buildings_config() -> BuildingsConfig:
	return config(&"buildings_config") as BuildingsConfig


static func crypt_config() -> CryptConfig:
	return config(&"crypt_config") as CryptConfig


static func chapel_config() -> ChapelConfig:
	return config(&"chapel_config") as ChapelConfig


static func shed_config() -> ShedConfig:
	return config(&"shed_config") as ShedConfig


static func economy_config() -> EconomyConfig:
	return config(&"economy_config") as EconomyConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func ghost_config() -> GhostConfig:
	return config(&"ghost_config") as GhostConfig


static func decay_visual_config() -> DecayVisualConfig:
	return config(&"decay_visual_config") as DecayVisualConfig


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


static func building(id: StringName) -> BuildingData:
	return load(DIR + "/buildings/%s.tres" % id) as BuildingData


static func buildings() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for id: StringName in BUILDING_IDS:
		out.append(building(id))
	return out


## The old grave data of `grave_id`; died_year overridden when ≥ 0 (rest-period tests).
static func old_grave(grave_id: String, died_year: int = -1) -> OldGraveData:
	var data := load(DIR + "/old_graves/%s.tres" % grave_id) as OldGraveData
	if data == null or died_year < 0:
		return data
	var copy := data.duplicate() as OldGraveData
	copy.died_year = died_year
	return copy


static func old_graves() -> Array[OldGraveData]:
	var out: Array[OldGraveData] = []
	for id: String in OLD_GRAVE_IDS:
		out.append(old_grave(id))
	return out


## A GraveRecord of an old grave (State.OLD, section yard) as Graveyard._collect_plots makes it.
static func old_grave_record(grave_id: String) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = grave_id
	g.state = GraveRecord.State.OLD
	return g


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


static func recipe(id: StringName) -> RecipeData:
	return load(DIR + "/recipes/%s.tres" % id) as RecipeData


static func clue(id: StringName) -> ClueData:
	return load(DIR + "/clues/%s.tres" % id) as ClueData


## InteriorConfig of a room (hut → the real data/config/interior_config.tres).
static func room_config(room_id: StringName) -> InteriorConfig:
	if room_id == &"hut":
		return load("res://data/config/interior_config.tres") as InteriorConfig
	return load(DIR + "/interiors/%s.tres" % room_id) as InteriorConfig


## A Buildings node with the given levels ({building_id: level}) through load_state (§5.1 format;
## works with the W0 stub and with P1's implementation). Added under tree.root when a tree is
## given (group &"buildings" – the consumers find it there). The caller frees it.
static func buildings_at(levels: Dictionary, tree: SceneTree = null) -> Buildings:
	var b := Buildings.new()
	b.config = buildings_config()
	var saved := {}
	for id: Variant in levels:
		saved[String(id)] = int(levels[id])
	b.load_state({"levels": saved})
	if tree != null:
		tree.root.add_child(b)
	return b


## Buildings with the crypt at `level` (chapel, shed 0). The caller frees it.
static func crypt_at(level: int, tree: SceneTree = null) -> Buildings:
	return buildings_at({&"crypt": level}, tree)


## A CorpseRecord (Phase5Fixtures.corpse) at `location` in `room` / `slot_id`, optionally with cold
## windows [start, end (-1 = open), factor‰, …].
static func record_in(location: StringName, room: StringName = &"", slot_id: String = "",
		cold_windows: PackedInt32Array = PackedInt32Array(), arrival_total: int = 460) -> CorpseRecord:
	var r := Phase5Fixtures.corpse(50, &"fever", &"", arrival_total)
	r.location = location
	r.room = room
	r.slot_id = slot_id
	r.cold_windows = cold_windows
	return r


## A corpse ready for the funeral service: dressed (gown or shroud), `freshness`, on the catafalque.
static func service_corpse(freshness: float = 1.0, dress: StringName = CorpseRecord.DRESS_GOWN) -> CorpseRecord:
	var r := record_in(CorpseRecord.LOCATION_CATAFALQUE, &"chapel")
	r.dress = dress
	r.shrouded = dress != CorpseRecord.DRESS_NONE
	r.freshness = freshness
	return r


## A MARKED grave of a corpse with a held service (service_day `day`), quality from the Phase-6
## economy fixture once P4 adds the „Ausgesegnet" line.
static func serviced_grave(day: int = 31, marker: StringName = &"wooden_cross") -> GraveRecord:
	var r := service_corpse()
	r.service_held = true
	r.service_day = day
	r.location = CorpseRecord.LOCATION_BURIED
	r.room = &""
	return Phase5Fixtures.grave_with(r, marker)


## Unlimited test inventory (Phase5Fixtures.inv_with_tools) with `items`. The caller frees it.
static func inv_with(items: Dictionary = {}, tiers: Dictionary = {}) -> Inventory:
	return Phase5Fixtures.inv_with_tools(tiers, items)


## res:// path of a v4 save fixture, e.g. save_v4_path("slot_p5_day30_reverent").
static func save_v4_path(name: String) -> String:
	return SAVES_V4_DIR.path_join(name + ".json")


## Copies a v4 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v4(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v4_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


## The approved Phase-5 layout (c5bd76d) as a Dictionary ({} if unreadable).
static func layout_p5() -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_P5))
	return doc if doc is Dictionary else {}
