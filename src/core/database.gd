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

var _items: Dictionary = {}       # StringName -> ItemData
var _recipes: Dictionary = {}     # StringName -> RecipeData
var _dialogues: Dictionary = {}   # StringName -> DialogueData
var _schedules: Dictionary = {}   # StringName -> NpcSchedule
var _configs: Dictionary = {}     # StringName -> Resource
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
