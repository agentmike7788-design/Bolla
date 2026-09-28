extends Node
## Read-only registry of all game data under res://data/.
## Resources are keyed by their `id` property (items, recipes, dialogues) or
## by `npc_id` (schedules); configs by file name (data/config/<name>.tres).
## Works in exported builds (scans via ResourceLoader.list_directory).

const ITEM_DIR := "res://data/items"
const RECIPE_DIR := "res://data/recipes"
const DIALOGUE_DIR := "res://data/dialogue"
const NPC_DIR := "res://data/npc"
const CONFIG_DIR := "res://data/config"
const CORPSE_TABLES := "res://data/corpses/corpse_tables.tres"
const ICON_DIR := "res://assets/ui/icons"
# Phase 3 (docs/PHASE3_DESIGN.md §3.5)
const SECTION_DIR := "res://data/sections"
const CLEARABLE_DIR := "res://data/clearables"
const DECOR_DIR := "res://data/decor"
const GHOST_DIR := "res://data/ghosts"
const GHOST_LINES := &"ghost_lines"
# Phase 4 (docs/PHASE4_DESIGN.md §3.5)
const FIND_DIR := "res://data/finds"
const STORY_DIR := "res://data/story"
const CLUE_DIR := "res://data/journal/clues"
const INSIGHT_DIR := "res://data/journal/insights"
# Phase 5 (docs/PHASE5_DESIGN.md §3.5)
const STATION_DIR := "res://data/stations"
const GATHER_DIR := "res://data/gather"
const STONE_SHAPE_DIR := "res://data/stone/shapes"
const INSCRIPTION_DIR := "res://data/stone/inscriptions"
const ORNAMENT_DIR := "res://data/stone/ornaments"

var _items: Dictionary = {}       # StringName -> ItemData
var _recipes: Dictionary = {}     # StringName -> RecipeData
var _dialogues: Dictionary = {}   # StringName -> DialogueData
var _schedules: Dictionary = {}   # StringName -> NpcSchedule
var _configs: Dictionary = {}     # StringName -> Resource
var _sections: Dictionary = {}    # StringName -> SectionData
var _clearables: Dictionary = {}  # StringName -> ClearableData
var _decors: Dictionary = {}      # StringName -> DecorData
var _ghosts: Dictionary = {}      # StringName (file name) -> Resource
var _finds: Dictionary = {}       # StringName -> FindData
var _stories: Dictionary = {}     # StringName -> StoryCorpseData
var _clues: Dictionary = {}       # StringName -> ClueData
var _insights: Dictionary = {}    # StringName -> InsightData
var _stations: Dictionary = {}    # StringName -> StationData
var _gather: Dictionary = {}      # StringName -> GatherNodeData
var _shapes: Dictionary = {}      # StringName -> StoneShapeData
var _inscriptions: Dictionary = {}  # StringName -> InscriptionData
var _ornaments: Dictionary = {}   # StringName -> OrnamentData
var _icons: Dictionary = {}       # StringName -> Texture2D
var _placeholder: Texture2D


func _ready() -> void:
	reload()


func reload() -> void:
	_items = _load_dir(ITEM_DIR, "id")
	_recipes = _load_dir(RECIPE_DIR, "id")
	_dialogues = _load_dir(DIALOGUE_DIR, "id")
	_schedules = _load_dir(NPC_DIR, "npc_id")
	_configs.clear()
	for path: String in _resource_files(CONFIG_DIR):
		_configs[StringName(path.get_file().get_basename())] = load(path)
	_sections = _load_dir(SECTION_DIR, "id")
	_clearables = _load_dir(CLEARABLE_DIR, "id")
	_decors = _load_dir(DECOR_DIR, "id")
	_ghosts.clear()
	for path: String in _resource_files(GHOST_DIR):
		_ghosts[StringName(path.get_file().get_basename())] = load(path)
	_finds = _load_dir(FIND_DIR, "id")
	_stories = _load_dir(STORY_DIR, "id")
	_clues = _load_dir(CLUE_DIR, "id")
	_insights = _load_dir(INSIGHT_DIR, "id")
	_stations = _load_dir(STATION_DIR, "id")
	_gather = _load_dir(GATHER_DIR, "id")
	_shapes = _load_dir(STONE_SHAPE_DIR, "id")
	_inscriptions = _load_dir(INSCRIPTION_DIR, "id")
	_ornaments = _load_dir(ORNAMENT_DIR, "id")


func item(id: StringName) -> Resource:
	if not _items.has(id):
		push_warning("[Database] unknown item '%s'" % id)
	return _items.get(id)


func has_item(id: StringName) -> bool:
	return _items.has(id)


func items() -> Array:
	return _items.values()


func recipe(id: StringName) -> Resource:
	return _recipes.get(id)


func recipes(station: StringName = &"") -> Array:
	var out: Array = []
	for r: Resource in _recipes.values():
		if station == &"" or r.get("station") == station:
			out.append(r)
	out.sort_custom(func(a: Resource, b: Resource) -> bool: return String(a.get("id")) < String(b.get("id")))
	return out


func dialogue(id: StringName) -> Resource:
	return _dialogues.get(id)


func schedule(npc_id: StringName) -> Resource:
	return _schedules.get(npc_id)


## data/config/<name>.tres, e.g. config(&"time_config")
func config(name: StringName) -> Resource:
	if not _configs.has(name):
		push_warning("[Database] unknown config '%s'" % name)
	return _configs.get(name)


## data/sections/<id>.tres (SectionData), null if unknown.
func section(id: StringName) -> Resource:
	return _sections.get(id)


## All sections, sorted by `order`.
func sections() -> Array:
	var out: Array = _sections.values()
	out.sort_custom(func(a: Resource, b: Resource) -> bool: return int(a.get("order")) < int(b.get("order")))
	return out


## data/clearables/<kind>.tres (ClearableData), null if unknown.
func clearable(id: StringName) -> Resource:
	return _clearables.get(id)


## data/decor/<item_id>.tres (DecorData), null if unknown.
func decor(id: StringName) -> Resource:
	return _decors.get(id)


## All decor kinds, sorted by id.
func decors() -> Array:
	var out: Array = _decors.values()
	out.sort_custom(func(a: Resource, b: Resource) -> bool: return String(a.get("id")) < String(b.get("id")))
	return out


func has_decor(id: StringName) -> bool:
	return _decors.has(id)


## data/ghosts/ghost_lines.tres (GhostLines), null while missing.
func ghost_lines() -> Resource:
	return _ghosts.get(GHOST_LINES)


# --- Phase 4 ---------------------------------------------------------------------------------

## data/finds/<id>.tres (FindData), null if unknown.
func find(id: StringName) -> Resource:
	return _finds.get(id)


## All finds, sorted by id.
func finds() -> Array:
	return _sorted(_finds.values(), "id")


## data/story/<id>.tres (StoryCorpseData), null if unknown.
func story_corpse(id: StringName) -> Resource:
	return _stories.get(id)


## All story corpses, sorted by `order`.
func story_corpses() -> Array:
	return _sorted(_stories.values(), "order")


## data/journal/clues/<id>.tres (ClueData), null if unknown.
func clue(id: StringName) -> Resource:
	return _clues.get(id)


## All clues, sorted by `order`.
func clues() -> Array:
	return _sorted(_clues.values(), "order")


## data/journal/insights/<id>.tres (InsightData), null if unknown.
func insight(id: StringName) -> Resource:
	return _insights.get(id)


## All insights, sorted by `order`.
func insights() -> Array:
	return _sorted(_insights.values(), "order")


# --- Phase 5 ---------------------------------------------------------------------------------

## data/stations/<id>.tres (StationData), null if unknown.
func station(id: StringName) -> Resource:
	return _stations.get(id)


## All stations, sorted by id.
func stations() -> Array:
	return _sorted(_stations.values(), "id")


## data/gather/<kind>.tres (GatherNodeData), null if unknown.
func gather_kind(id: StringName) -> Resource:
	return _gather.get(id)


## All gather kinds, sorted by id.
func gather_kinds() -> Array:
	return _sorted(_gather.values(), "id")


## data/stone/shapes/<id>.tres (StoneShapeData), null if unknown.
func stone_shape(id: StringName) -> Resource:
	return _shapes.get(id)


## All stone shapes, sorted by `order` (ties by id).
func stone_shapes() -> Array:
	return _sorted(_shapes.values(), "order")


## data/stone/inscriptions/<id>.tres (InscriptionData), null if unknown.
func inscription(id: StringName) -> Resource:
	return _inscriptions.get(id)


## All inscription templates, sorted by `order` (ties by id).
func inscriptions() -> Array:
	return _sorted(_inscriptions.values(), "order")


## data/stone/ornaments/<id>.tres (OrnamentData), null if unknown.
func ornament(id: StringName) -> Resource:
	return _ornaments.get(id)


## All ornaments, sorted by `order` (ties by id).
func ornaments() -> Array:
	return _sorted(_ornaments.values(), "order")


func corpse_tables() -> Resource:
	return load(CORPSE_TABLES) if ResourceLoader.exists(CORPSE_TABLES) else null


## Item icon rendered by src/ui/tools/icon_renderer.gd, or a generated placeholder.
func icon(id: StringName) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var path := ICON_DIR.path_join(String(id) + ".png")
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else _placeholder_icon()
	_icons[id] = tex
	return tex


func _placeholder_icon() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.29, 0.21, 0.15))
		img.fill_rect(Rect2i(8, 8, 48, 48), Color(0.95, 0.66, 0.23))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


## Sorted by `key` (int keys numerically, then by id for ties; String keys lexically).
static func _sorted(values: Array, key: String) -> Array:
	var out := values.duplicate()
	out.sort_custom(func(a: Resource, b: Resource) -> bool:
		var ka: Variant = a.get(key)
		var kb: Variant = b.get(key)
		if ka is int and kb is int:
			if ka != kb:
				return ka < kb
			return String(a.get("id")) < String(b.get("id"))
		return String(ka) < String(kb))
	return out


func _load_dir(dir: String, key_property: String) -> Dictionary:
	var out: Dictionary = {}
	for path: String in _resource_files(dir):
		var res := load(path)
		if res == null:
			push_error("[Database] failed to load " + path)
			continue
		var key: Variant = res.get(key_property)
		if key == null or String(key) == "":
			push_error("[Database] %s has no '%s'" % [path, key_property])
			continue
		if out.has(StringName(key)):
			push_error("[Database] duplicate id '%s' in %s" % [key, path])
		out[StringName(key)] = res
	return out


func _resource_files(dir: String) -> PackedStringArray:
	var files: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir):
		return files
	# list_directory() reports original names even for exported (*.remap) resources.
	for f: String in ResourceLoader.list_directory(dir):
		if (f.ends_with(".tres") or f.ends_with(".res")) and not files.has(dir.path_join(f)):
			files.append(dir.path_join(f))
	files.sort()
	return files
