class_name Phase5Fixtures
extends RefCounted
## Phase-5 test fixtures (W0, docs/PHASE5_DESIGN.md §12). W1 unit tests load these instead of
## data/ – they mirror the contract values and leading texts (§2) at the time of W0 and do not
## follow later balancing / text edits of the real data files.
##
## *_config_fixture.tres: workshop, tool, stone (= the W0 data/config files) + the Phase-5 values of
##   existing configs: action (tool factors / action_tools / step 5), player (20 slots), economy
##   (stone shapes in marker_quality, quality_max 19), reputation (+ master_stone 3), piety
##   (full_prep_requires_unharvested), prep (balm_items juniper + herb_bundle), trader (+ gold_leaf
##   6 / 2 per night).
## ghost_lines_fixture.tres: the Phase-4 placeholders + by_reason.nameless and by_design (default,
##   gilded, master, s5_lorenz) with the leading texts of §2.5.
## stations/: workbench (prebuilt), mason, loom, forge (§2.1). gather/: the 8 gather kinds (§2.2).
## clearables/: boulder (pickaxe 1), gate_east. sections/: bruch, quarry (is_burial false).
## recipes/: the 13 new recipes (§2.4; charcoal is background). stone/: 3 shapes, 7 inscription
##   templates, 4 ornaments (§2.5).
## ../items/: + 13 MATERIAL items and 6 tier tools (shovel/axe/pickaxe × iron/master).
## ../saves_v3/: Phase-4 save files (format v3) – see make_v3_saves.gd. layout_p4.json: the
##   approved Phase-4 layout (69f8d49) for the W-Welt layout diff.

const DIR := "res://tests/fixtures/phase5"
const CONFIG_NAMES: Array[StringName] = [&"workshop_config", &"tool_config", &"stone_config"]
## Existing configs with Phase-5 values (fixtures only; the data files belong to their owners).
const EXTENDED_CONFIG_NAMES: Array[StringName] = [&"action_config", &"player_config", &"economy_config",
		&"reputation_config", &"piety_config", &"prep_config", &"trader_config"]
const STATION_IDS: Array[StringName] = [&"workbench", &"mason", &"loom", &"forge"]
const GATHER_IDS: Array[StringName] = [&"alder", &"flax_bed", &"clay_pit", &"rubble_face", &"ore_vein",
		&"workstone_ledge", &"elder_bush", &"herb_patch"]
const CLEARABLE_IDS: Array[StringName] = [&"boulder", &"gate_east"]
const SECTION_IDS: Array[StringName] = [&"bruch", &"quarry"]
const RECIPE_IDS: Array[StringName] = [&"charcoal", &"iron_bar", &"iron_fittings_forge", &"shovel_iron", &"axe_iron",
		&"shovel_master", &"axe_master", &"pickaxe_master", &"yarn", &"linen_woven", &"burial_gown_loom", &"ink", &"herb_bundle"]
const MATERIAL_IDS: Array[StringName] = [&"flax", &"yarn", &"clay", &"iron_ore", &"iron_bar", &"charcoal", &"workstone",
		&"elderberries", &"herbs", &"ink", &"herb_bundle", &"gold_leaf", &"steel_rod"]
const TOOL_IDS: Array[StringName] = [&"shovel_iron", &"shovel_master", &"axe_iron", &"axe_master", &"pickaxe_iron", &"pickaxe_master"]
## Tool item by kind and tier (tier 0 is no item).
const TOOL_ITEMS: Dictionary = {&"shovel": [&"", &"shovel_iron", &"shovel_master"], &"axe": [&"", &"axe_iron", &"axe_master"],
		&"pickaxe": [&"", &"pickaxe_iron", &"pickaxe_master"]}
const SHAPE_IDS: Array[StringName] = [&"stone_stele", &"stone_arch", &"stone_master"]
const INSCRIPTION_IDS: Array[StringName] = [&"i_rest", &"i_long_road", &"i_too_soon", &"i_water", &"i_fever", &"i_road", &"i_garden"]
const ORNAMENT_IDS: Array[StringName] = [&"orn_ivy", &"orn_poppy", &"orn_elder", &"orn_torch"]
const SAVES_V3_DIR := "res://tests/fixtures/saves_v3"
const SAVES_V3: PackedStringArray = ["slot_p4_day7_table", "slot_p4_day13_complete", "slot_p4_day20_reverent",
		"slot_p4_day20_mixed", "slot_p4_day25_harvester", "slot_p4_interior_chest_tools"]
const LAYOUT_P4 := DIR + "/layout_p4.json"
const FAKE_TOOL_INVENTORY := DIR + "/fake_tool_inventory.gd"


static func config(name: StringName) -> Resource:
	return load(DIR + "/%s_fixture.tres" % name)


static func workshop_config() -> WorkshopConfig:
	return config(&"workshop_config") as WorkshopConfig


static func tool_config() -> ToolConfig:
	return config(&"tool_config") as ToolConfig


static func stone_config() -> StoneConfig:
	return config(&"stone_config") as StoneConfig


static func action_config() -> ActionConfig:
	return config(&"action_config") as ActionConfig


static func player_config() -> PlayerConfig:
	return config(&"player_config") as PlayerConfig


static func economy_config() -> EconomyConfig:
	return config(&"economy_config") as EconomyConfig


static func reputation_config() -> ReputationConfig:
	return config(&"reputation_config") as ReputationConfig


static func piety_config() -> PietyConfig:
	return config(&"piety_config") as PietyConfig


static func prep_config() -> PrepConfig:
	return config(&"prep_config") as PrepConfig


static func trader_config() -> TraderConfig:
	return config(&"trader_config") as TraderConfig


static func ghost_lines() -> GhostLines:
	return load(DIR + "/ghost_lines_fixture.tres") as GhostLines


static func station(id: StringName) -> StationData:
	return load(DIR + "/stations/%s.tres" % id) as StationData


static func stations() -> Array[StationData]:
	var out: Array[StationData] = []
	for id: StringName in STATION_IDS:
		out.append(station(id))
	return out


static func gather_kind(id: StringName) -> GatherNodeData:
	return load(DIR + "/gather/%s.tres" % id) as GatherNodeData


static func gather_kinds() -> Array[GatherNodeData]:
	var out: Array[GatherNodeData] = []
	for id: StringName in GATHER_IDS:
		out.append(gather_kind(id))
	return out


static func clearable(id: StringName) -> ClearableData:
	return load(DIR + "/clearables/%s.tres" % id) as ClearableData


static func section(id: StringName) -> SectionData:
	return load(DIR + "/sections/%s.tres" % id) as SectionData


static func recipe(id: StringName) -> RecipeData:
	return load(DIR + "/recipes/%s.tres" % id) as RecipeData


static func recipes(station_id: StringName = &"") -> Array[RecipeData]:
	var out: Array[RecipeData] = []
	for id: StringName in RECIPE_IDS:
		var r := recipe(id)
		if station_id == &"" or r.station == station_id:
			out.append(r)
	return out


static func item(id: StringName) -> ItemData:
	return load("res://tests/fixtures/items/%s.tres" % id) as ItemData


static func stone_shape(id: StringName) -> StoneShapeData:
	return load(DIR + "/stone/shapes/%s.tres" % id) as StoneShapeData


static func stone_shapes() -> Array[StoneShapeData]:
	var out: Array[StoneShapeData] = []
	for id: StringName in SHAPE_IDS:
		out.append(stone_shape(id))
	return out


static func inscription(id: StringName) -> InscriptionData:
	return load(DIR + "/stone/inscriptions/%s.tres" % id) as InscriptionData


static func inscriptions() -> Array[InscriptionData]:
	var out: Array[InscriptionData] = []
	for id: StringName in INSCRIPTION_IDS:
		out.append(inscription(id))
	return out


static func ornament(id: StringName) -> OrnamentData:
	return load(DIR + "/stone/ornaments/%s.tres" % id) as OrnamentData


static func ornaments() -> Array[OrnamentData]:
	var out: Array[OrnamentData] = []
	for id: StringName in ORNAMENT_IDS:
		out.append(ornament(id))
	return out


## A StoneDesign value (text empty unless given).
static func design(shape: StringName, ins: StringName = &"", orn: StringName = &"", gilded: bool = false,
		text: PackedStringArray = []) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = shape
	d.inscription = ins
	d.ornament = orn
	d.gilded = gilded
	d.text = text
	return d


## A CorpseRecord for rule tests (Phase4Fixtures.corpse + age, story, burial day).
static func corpse(age: int = 50, cause: StringName = &"fever", story_id: StringName = &"", arrival_total: int = 460) -> CorpseRecord:
	var r := Phase4Fixtures.corpse([], cause, 1.0, arrival_total)
	r.age = age
	r.story_id = story_id
	return r


## A GraveRecord holding `corpse` (id "plot_test", completed day 1): MARKED with `marker`
## (a designed stone: marker_id = design.shape, design = design.to_dict()), FILLED when both are
## empty. quality / breakdown from GraveQuality with the Phase-5 economy fixture (design lines
## come with P4).
static func grave_with(corpse_record: CorpseRecord, marker: StringName = &"", stone: StoneDesign = null) -> GraveRecord:
	var g := GraveRecord.new()
	g.id = "plot_test"
	g.corpse_id = corpse_record.id if corpse_record != null else ""
	var marker_id := marker
	if stone != null and not stone.is_empty():
		marker_id = stone.shape
		g.design = stone.to_dict()
	g.marker_id = marker_id
	g.state = GraveRecord.State.MARKED if marker_id != &"" else GraveRecord.State.FILLED
	if corpse_record != null:
		var eco := economy_config()
		g.breakdown = GraveQuality.breakdown(corpse_record, marker_id, eco, g.design)
		g.quality = GraveQuality.compute(corpse_record, marker_id, eco, g.design)
	g.completed_day = 1
	return g


## Unlimited test inventory with a tool belt: tiers {kind: tier} → the tool item of that tier on
## the belt (tier 0 = nothing). `items` go into the (unlimited) bag. The caller frees it.
static func inv_with_tools(tiers: Dictionary, items: Dictionary = {}) -> Inventory:
	var inv: Inventory = (load(FAKE_TOOL_INVENTORY) as GDScript).new()
	inv.tool_belt = true
	var belt: Dictionary[StringName, int] = {}
	for kind: Variant in tiers:
		var tier := int(tiers[kind])
		var ids: Array = TOOL_ITEMS.get(StringName(str(kind)), [])
		if tier > 0 and tier < ids.size():
			belt[ids[tier]] = 1
	inv.set(&"belt", belt)
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))
	return inv


## res:// path of a v3 save fixture, e.g. save_v3_path("slot_p4_day20_reverent").
static func save_v3_path(name: String) -> String:
	return SAVES_V3_DIR.path_join(name + ".json")


## Copies a v3 fixture to <save_dir>/slot_<slot>.json (for SaveManager.load_game).
static func install_save_v3(name: String, save_dir: String, slot: int) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var text := FileAccess.get_file_as_string(save_v3_path(name))
	if text == "":
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(SaveFileIO.slot_path(save_dir, slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


## The approved Phase-4 layout (69f8d49) as a Dictionary ({} if unreadable).
static func layout_p4() -> Dictionary:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_P4))
	return doc if doc is Dictionary else {}
