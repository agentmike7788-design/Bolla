class_name Phase4Fixtures
extends RefCounted
## Phase-4 test fixtures (W0, docs/PHASE4_DESIGN.md §12). W1 unit tests load these instead of
## data/ – they mirror the contract values and leading texts (§2) at the time of W0 and do not
## follow later balancing / text edits of the real data files.
##
## *_config_fixture.tres: exam, prep, piety, utilization, trader, story, decay_visual (= the W0
##   data/config files) + economy (Phase-4 values: quality_max 13, dress / rot / harvest lines,
##   venerable gate), cleanliness (penalty [0, 0, 1, 3]), reputation (+ hair/teeth/stench).
## ghost_lines_fixture.tres: placeholders "<pool>_<i>" incl. robbed / unkempt (3), by_story (2
##   per story corpse), by_piety (devout / hardhearted, 2).
## finds/: all 28 finds of §2.2 (4 generic trait finds, 7 cause details f_cause_<cause>, 17 story
##   finds; f_s3_mark / f_s3_letter replace f_mark / f_letter via trait_id).
## story/: S1–S5 (§2.11), clues/: the 18 clues, insights/: the 5 + 1 optional insights (§2.12).
## sections/elder.tres, clearables/{gate_small, elder_thicket, sunken_pit}.tres (§2.10; the
##   fence gap is Phase3Fixtures.clearable(&"fence_gap")).
## trader_schedule_fixture.tres: Ilse 22:40 → 23:00 spot → 03:00 → 03:20 away (§2.6).
## ../items/: + scrub_brush, comb, shears, pliers (TOOL), burial_gown (CRAFTED), juniper
##   (RESOURCE), hair_braid, teeth_pouch (GOODS).
## ../saves_v2/: Phase-3 save files (format v2) – see make_v2_saves.gd.

const DIR := "res://tests/fixtures/phase4"
const CONFIG_NAMES: Array[StringName] = [&"exam_config", &"prep_config", &"piety_config", &"utilization_config",
		&"trader_config", &"story_config", &"decay_visual_config"]
const STORY_IDS: Array[StringName] = [&"s1_quendel", &"s2_hemmerling", &"s3_wernstein", &"s4_uhlig", &"s5_moor"]
const GENERIC_FIND_IDS: Array[StringName] = [&"f_valuables", &"f_letter", &"f_tattoo", &"f_mark",
		&"f_cause_fever", &"f_cause_drowned_millpond", &"f_cause_fall_hayloft", &"f_cause_old_age",
		&"f_cause_poisoned", &"f_cause_coach_accident", &"f_cause_moor_cold"]
const STORY_FIND_IDS: Array[StringName] = [&"f_s1_sprig", &"f_s1_soil", &"f_s1_page", &"f_s2_jacket", &"f_s2_wrists",
		&"f_s2_key", &"f_s3_coat", &"f_s3_ink", &"f_s3_mark", &"f_s3_letter", &"f_s4_collar", &"f_s4_scar", &"f_s4_token",
		&"f_s5_coat", &"f_s5_buckle", &"f_s5_hands", &"f_s5_list"]
const CLUE_IDS: Array[StringName] = [&"c_mark", &"c_warning_letter", &"c_anchor_snake", &"c_page_1", &"c_ferry_jacket",
		&"c_elder_key", &"c_six_pits", &"c_mark_healed", &"c_letter_late", &"c_oath_scar", &"c_ferry_token", &"c_coat",
		&"c_buckle", &"c_soft_hands", &"c_page_list", &"c_trader_note", &"c_trader_lorenz", &"c_trader_marked"]
const INSIGHT_IDS: Array[StringName] = [&"i_warnings", &"i_marked", &"i_ferry", &"i_still_writing", &"i_not_lorenz", &"i_kranich"]
const CLEARABLE_IDS: Array[StringName] = [&"gate_small", &"elder_thicket", &"sunken_pit"]
const NEW_ITEM_IDS: Array[StringName] = [&"scrub_brush", &"comb", &"burial_gown", &"juniper", &"shears", &"pliers",
		&"hair_braid", &"teeth_pouch"]
const SAVES_V2_DIR := "res://tests/fixtures/saves_v2"
const SAVES_V2: PackedStringArray = ["slot_p3_day5_table", "slot_p3_day9_night", "slot_p3_day14_complete", "slot_p3_interior"]


static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func exam_config() -> ExamConfig:
	return config(&"exam_config") as ExamConfig


static func prep_config() -> PrepConfig:
	return config(&"prep_config") as PrepConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func utilization_config() -> UtilizationConfig:
	return config(&"utilization_config") as UtilizationConfig


static func trader_config() -> TraderConfig:
	return config(&"trader_config") as TraderConfig


static func story_config() -> StoryConfig:
	return config(&"story_config") as StoryConfig


static func decay_visual_config() -> DecayVisualConfig:
	return config(&"decay_visual_config") as DecayVisualConfig


static func economy_config() -> EconomyConfig:
	return config(&"economy_config") as EconomyConfig


static func cleanliness_config() -> CleanlinessConfig:
	return config(&"cleanliness_config") as CleanlinessConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


static func trader_schedule() -> NpcSchedule:
	return load(DIR + "/trader_schedule_fixture.tres") as NpcSchedule


static func find(id: StringName) -> FindData:
	return load(DIR + "/finds/%s.tres" % id) as FindData


## Generic + story finds (the order of GENERIC_FIND_IDS, then STORY_FIND_IDS).
static func finds() -> Array[FindData]:
	var out: Array[FindData] = []
	for id: StringName in GENERIC_FIND_IDS + STORY_FIND_IDS:
		out.append(find(id))
	return out


static func story(id: StringName) -> StoryCorpseData:
	return load(DIR + "/story/%s.tres" % id) as StoryCorpseData


## S1–S5 by order.
static func stories() -> Array[StoryCorpseData]:
	var out: Array[StoryCorpseData] = []
	for id: StringName in STORY_IDS:
		out.append(story(id))
	return out


static func clue(id: StringName) -> ClueData:
	return load(DIR + "/clues/%s.tres" % id) as ClueData


static func clues() -> Array[ClueData]:
	var out: Array[ClueData] = []
	for id: StringName in CLUE_IDS:
		out.append(clue(id))
	return out


static func insight(id: StringName) -> InsightData:
	return load(DIR + "/insights/%s.tres" % id) as InsightData


static func insights() -> Array[InsightData]:
	var out: Array[InsightData] = []
	for id: StringName in INSIGHT_IDS:
		out.append(insight(id))
	return out


static func elder_section() -> SectionData:
	return load(DIR + "/sections/elder.tres") as SectionData


static func clearable(id: StringName) -> ClearableData:
	return load(DIR + "/clearables/%s.tres" % id) as ClearableData


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


## A fresh CorpseRecord for rule tests (no manager): freshness 1, arrival at `arrival_total`.
static func corpse(traits: Array[StringName] = [], cause: StringName = &"fever", freshness: float = 1.0, arrival_total: int = 460) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.id = "corpse_test"
	r.display_name = "Test Toter"
	r.age = 50
	r.cause_id = cause
	r.traits = traits.duplicate()
	r.freshness = freshness
	r.arrival_total_minutes = arrival_total
	r.last_decay_total = arrival_total
	if r.has_trait(CorpseRecord.TRAIT_VALUABLES):
		r.valuables_coins = 6
	return r


## res:// path of a v2 save fixture, e.g. save_v2_path("slot_p3_day5_table").
static func save_v2_path(name: String) -> String:
	return SAVES_V2_DIR.path_join(name + ".json")


## Copies a v2 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v2(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v2_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
