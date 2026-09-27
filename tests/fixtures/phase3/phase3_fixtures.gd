class_name Phase3Fixtures
extends RefCounted
## Phase-3 test fixtures (W0, docs/PHASE3_DESIGN.md §12). W1 unit tests load these instead of
## data/ – they mirror the contract values (§2) at the time of W0 and do not follow later
## balancing of the real data files.
##
## build_mask_fixture.tres: 12 × 8 cells, origin (0, 0), cell 0.5 m (x 0…6 m, z 0…4 m).
##   columns 0–5 = section 1 (yard), columns 6–11 = section 2 (east)
##   row 0                     BLOCKED (fence)
##   cells x 2–3, z 3–4        BLOCKED (grave footprint)
##   ring x 1–4, z 2–5         section 1 | GRAVE_RING (around the grave)
##   row 7                     section | ROUTE (path)
##   everything else           plain section cell
## sections/: yard (1, open, cap 12), east (2, cap 9), north (3, needs east + dignified, cap 9).
## clearables/: bramble, rubble, stump, hedge, fence_gap (§2.1).
## decor/: the six DecorData of §2.3 (no models).
## ghost_lines_fixture.tres: placeholder lines "<pool>_<i>" (content 8, calm 3, 3 per reason,
##   2 per trait) – deterministic, not the real texts.
## ../items/: item fixtures incl. iron_fittings, seeds, rake (TOOL) and the decor_* items (DECOR).
## ../saves_v1/: Phase-2 save files (format v1) – see make_v1_saves.gd.

const DIR := "res://tests/fixtures/phase3"
const REPUTATION_CONFIG := DIR + "/reputation_config_fixture.tres"
const DECOR_CONFIG := DIR + "/decor_config_fixture.tres"
const CLEANLINESS_CONFIG := DIR + "/cleanliness_config_fixture.tres"
const GHOST_CONFIG := DIR + "/ghost_config_fixture.tres"
const GHOST_LINES := DIR + "/ghost_lines_fixture.tres"
const BUILD_MASK := DIR + "/build_mask_fixture.tres"
const SECTION_IDS: Array[StringName] = [&"yard", &"east", &"north"]
const CLEARABLE_IDS: Array[StringName] = [&"bramble", &"rubble", &"stump", &"hedge", &"fence_gap"]
const DECOR_IDS: Array[StringName] = [&"decor_bench_wood", &"decor_bench_stone", &"decor_flowerbed",
		&"decor_grave_vase", &"decor_lantern", &"decor_path_gravel"]
const NEW_ITEM_IDS: Array[StringName] = [&"iron_fittings", &"seeds", &"rake", &"decor_bench_wood",
		&"decor_bench_stone", &"decor_flowerbed", &"decor_grave_vase", &"decor_lantern", &"decor_path_gravel"]
const SAVES_V1_DIR := "res://tests/fixtures/saves_v1"
const SAVES_V1: PackedStringArray = ["slot_day3", "slot_day7_complete", "slot_interior"]


static func reputation_config() -> ReputationConfig:
	return load(REPUTATION_CONFIG) as ReputationConfig


static func decor_config() -> DecorConfig:
	return load(DECOR_CONFIG) as DecorConfig


static func cleanliness_config() -> CleanlinessConfig:
	return load(CLEANLINESS_CONFIG) as CleanlinessConfig


static func ghost_config() -> GhostConfig:
	return load(GHOST_CONFIG) as GhostConfig


static func ghost_lines() -> GhostLines:
	return load(GHOST_LINES) as GhostLines


static func build_mask() -> BuildMask:
	return load(BUILD_MASK) as BuildMask


static func section(id: StringName) -> SectionData:
	return load(DIR + "/sections/%s.tres" % id) as SectionData


static func sections() -> Array[SectionData]:
	var out: Array[SectionData] = []
	for id: StringName in SECTION_IDS:
		out.append(section(id))
	return out


static func clearable(id: StringName) -> ClearableData:
	return load(DIR + "/clearables/%s.tres" % id) as ClearableData


static func decor(id: StringName) -> DecorData:
	return load(DIR + "/decor/%s.tres" % id) as DecorData


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


## res:// path of a v1 save fixture, e.g. save_v1_path("slot_day3").
static func save_v1_path(name: String) -> String:
	return SAVES_V1_DIR.path_join(name + ".json")


## Copies a v1 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v1(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v1_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
