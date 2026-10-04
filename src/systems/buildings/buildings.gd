class_name Buildings
extends Node
## Systems/Buildings (docs/PHASE6_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.3, §3.4, §5.1, §5.2), groups
## &"buildings", &"saveable": the levels of crypt, chapel and shed, buildings_open, the chapter
## „Unter Dach und Erde" and the one-time clearing of decor on the building sites.
## - Unlock: the first morning (first minute ≥ intro_minute) after unlock_flag was first seen sets
##   open_flag (time_tick → apply_morning); a migrated Phase-5 save (empty state) with unlock_flag
##   opens at once (post_load); a Phase-6 save keeps waiting for its morning (save → load identical).
## - Upgrade (BuildingSite after its timed action): the next level only (no skipping, no
##   demolition); items + coins at once, atomically; note_coins_spent(&"building"); apply_levels;
##   crypt: CorpseManager.restart_cold, Ossuary.on_crypt_level and on level 1
##   CorpseManager.relocate_table_corpse (onto the crypt table); building_upgraded; check_goal.
## - apply_levels: interior rooms (InteriorRoom.apply_level), the shed store (ShedStore.apply_level),
##   and a refresh of sites, doors, tables and niches – also after a load (post_load).
## - Chapter (§1.5): goal levels, held services (ChapelRites.services_buried) and reinterred boxes
##   (Ossuary.reinterred) → goal_flag, chapter_completed, summary panel (variant roof_and_earth). Once.
## - Sites (§5.2 step 5): post_load clears decor in site_rects once (flag cleared_flag) via
##   DecorationManager.evict_rects; the items go to the hut chest, overflow to the player, the rest
##   stays pending here (saved) until there is room. Nothing is lost.

const GROUP := &"buildings"
const CRYPT := &"crypt"
const CHAPEL := &"chapel"
const SHED := &"shed"
const PLAYER_GROUP := &"player"
const DECOR_GROUP := &"decorations"
const GRAVEYARD_GROUP := &"graveyard"
const MANAGER_GROUP := &"corpse_manager"
const OSSUARY_GROUP := &"ossuary"
const CHAPEL_GROUP := &"chapel_rites"
const MORGUE_GROUP := &"morgue_table"
## Entities refreshed by apply_levels (when they have refresh()).
const REFRESH_GROUPS: Array[StringName] = [&"building_site", &"building_door", &"morgue_table", &"crypt_niche",
		&"ossuary_shelf", &"sealed_passage"]
const CHEST_SAVE_ID := "hut_chest"
const REASON_BUILDING := &"building"
const SUMMARY_PANEL := &"slice_summary"
const MINUTES_PER_DAY := 1440
const TEXT_EVICTED := "Deine Zier stand am alten Grufthals unter der Eiche. Sie liegt jetzt in der Truhe."
const TEXT_FINAL_LINE := "Die Toten warten jetzt nicht mehr im Regen."

@export var save_id: String = "buildings"
@export var save_order: int = 32
## Footprint + margin + access of the building sites (the builder fills them from
## layout.buildings.site_rects); decor in them is cleared once (post_load, §5.2 step 5).
@export var site_rects: Array[Rect2] = []

## Rules; null = data/config/buildings_config.tres (resolved lazily).
var config: BuildingsConfig
## Buildings by id; empty = Database.building() / buildings() (tests inject fixtures).
var building_table: Dictionary[StringName, BuildingData] = {}

## {building_id: level 1…3} (0 = site, not stored).
var _levels: Dictionary[StringName, int] = {}
var _goal_done: bool = false
## {decor_id: count} cleared from the sites that did not fit anywhere yet.
var _evict_pending: Dictionary = {}
## Day buildings_open was set (0 = unknown / not open).
var _open_day: int = 0
## Coins spent after buildings_open by reason (coins_spent) – for the chapter panel.
var _spent: Dictionary = {}
## Content ghosts when the buildings opened (-1 = unknown).
var _content_before: int = -1
## total_minutes when unlock_flag was first seen this session (-1 = not yet; not saved).
var _unlock_seen_total: int = -1
## load_state got a Phase-6 state (not the empty {} of a migrated Phase-5 save): post_load then
## leaves the unlock to the next morning, as in play.
var _loaded_v5: bool = false
## Buildings whose loaded level was below their start_level (an older save, 04.10.2026: the crypt
## from the start) – post_load moves the old table's corpse down and notes it once.
var _lifted: Array[StringName] = []


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.chapter_completed.connect(_on_chapter_completed)
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.new_game_started.connect(_on_new_game)


## The resolved BuildingsConfig.
func buildings_config() -> BuildingsConfig:
	return _cfg()


## Flag buildings_open.
func is_open() -> bool:
	return _flag_on(_cfg().open_flag)


## 0 (site) … 3; never below BuildingData.start_level (the crypt: 1 from the start of a game).
func level(building_id: StringName) -> int:
	return maxi(int(_levels.get(building_id, 0)), start_level(building_id))


## BuildingData.start_level of `building_id` (0 when unknown).
func start_level(building_id: StringName) -> int:
	var data := building(building_id)
	return data.start_level if data != null else 0


## {building_id: level} of every known building (0 included) and every stored level.
func levels() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for data: BuildingData in all_buildings():
		out[data.id] = level(data.id)
	for id: StringName in _levels:
		out[id] = _levels[id]
	return out


## BuildingData of `building_id` (building_table / Database) or null.
func building(building_id: StringName) -> BuildingData:
	if not building_table.is_empty():
		return building_table.get(building_id)
	return Database.building(building_id) as BuildingData


## All buildings, sorted by order (then id).
func all_buildings() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	if not building_table.is_empty():
		for data: BuildingData in building_table.values():
			if data != null:
				out.append(data)
		out.sort_custom(func(a: BuildingData, b: BuildingData) -> bool:
			return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
		return out
	for res: Resource in Database.buildings():
		if res is BuildingData:
			out.append(res)
	return out


## "" or why `building_id` cannot get its next level now with `inv` (BuildingRules).
func upgrade_block_reason(building_id: StringName, inv: Inventory) -> String:
	return BuildingRules.upgrade_block_reason(building(building_id), level(building_id), inv, is_open())


## Atomic (items + coins at the end); building_upgraded; note_coins_spent(&"building");
## apply_levels; crypt 1: CorpseManager.relocate_table_corpse; check_goal.
func upgrade(building_id: StringName, inv: Inventory) -> bool:
	var data := building(building_id)
	if data == null or not is_instance_valid(inv) or upgrade_block_reason(building_id, inv) != "":
		return false
	var next := BuildingRules.next_level(data, level(building_id))
	if next == null or not _take_all(BuildingRules.cost(next), inv):
		return false
	_levels[building_id] = next.level
	if next.coins > 0:
		GameState.note_coins_spent(next.coins, REASON_BUILDING)
	# The crypt's state first (cold windows, the table corpse, the passage), then the visuals –
	# apply_levels refreshes the shelf / passage from the new ossuary state (QA6-06).
	if building_id == CRYPT:
		_on_crypt_level(next.level)
	apply_levels()
	EventBus.building_upgraded.emit(building_id, next.level)
	check_goal()
	return true


## Rooms, tables, niches, shed, sites and doors to the current levels (also post_load). Cold windows
## restart only on an actual crypt upgrade (upgrade → CorpseManager.restart_cold).
func apply_levels() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	for data: BuildingData in all_buildings():
		if data.room_id == &"":
			continue
		var room := InteriorRoom.find(tree, data.room_id)
		if room != null:
			room.apply_level(level(data.id))
	for node: Node in tree.get_nodes_in_group(ShedStore.GROUP):
		if node is ShedStore:
			(node as ShedStore).apply_level(level(SHED))
	for group: StringName in REFRESH_GROUPS:
		for node: Node in tree.get_nodes_in_group(group):
			if node.has_method(&"refresh"):
				node.call(&"refresh")


## BuildingRules.goal_progress over the levels, the buried serviced corpses and the reinterred boxes.
func goal_progress() -> Dictionary:
	return BuildingRules.goal_progress(levels(), _services_buried(), _reinterred().size(), _cfg())


## Chapter §1.5 once: goal_flag, chapter_completed, summary panel (variant = chapter_id).
func check_goal() -> void:
	var cfg := _cfg()
	if _goal_done or _flag_on(cfg.goal_flag):
		_goal_done = true
		return
	var progress := goal_progress()
	if int(progress.total) <= 0 or int(progress.done) < int(progress.total):
		return
	_goal_done = true
	GameState.set_flag(cfg.goal_flag, true)
	EventBus.chapter_completed.emit(cfg.chapter_id)
	EventBus.ui_panel_requested.emit(SUMMARY_PANEL, chapter_context())


## Context of the chapter panel (§1.5): the graveyard's summary_context (when there is one) with
## variant/chapter = chapter_id, plus days since buildings_open, the levels, services (with
## mourners, QA6-02) / devotions held, reinterred graves (names, n/liftable), corpses that waited in a niche, coins spent after
## buildings_open by reason, content ghosts before → now and the final line.
func chapter_context() -> Dictionary:
	var cfg := _cfg()
	var context := {}
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"summary_context"):
		context = graveyard.call(&"summary_context")
	context["variant"] = cfg.chapter_id
	context["chapter"] = cfg.chapter_id
	context["buildings_days"] = maxi(TimeManager.day - _open_day, 0) if _open_day > 0 else 0
	context["levels"] = levels()
	context["services_held"] = GameState.get_stat(&"services_held")
	context["services_buried"] = _services_buried()
	var rites := _first(CHAPEL_GROUP)
	if rites != null and rites.has_method(&"services_with_mourners"):
		context["services_mourners"] = int(rites.call(&"services_with_mourners"))
	context["devotions_held"] = GameState.get_stat(&"devotions_held")
	var names := PackedStringArray()
	for grave_id: String in _reinterred():
		var old := Database.old_grave(grave_id) as OldGraveData
		names.append(old.display_name if old != null and old.display_name != "" else grave_id)
	context["reinterred"] = names
	# Liftable old graves (a reinter line; old_01 / old_08 have none – rest period).
	var liftable := 0
	for res: Resource in Database.old_graves():
		var old := res as OldGraveData
		if old != null and old.reinter_line != "":
			liftable += 1
	context["reinterred_total"] = maxi(liftable, names.size())
	context["niche_waits"] = GameState.get_stat(&"niche_waits")
	context["coins_spent"] = _spent.duplicate()
	context["content_before"] = maxi(_content_before, 0)
	context["content_now"] = _content_ghosts()
	context["final_line"] = TEXT_FINAL_LINE
	return context


## Idempotent: buildings_open at the first minute ≥ intro_minute after unlock_flag was first seen.
func apply_morning(day: int) -> void:
	var cfg := _cfg()
	if is_open() or not _flag_on(cfg.unlock_flag):
		return
	var now := TimeManager.total_minutes()
	if day > TimeManager.day:
		now = maxi(now, (day - 1) * MINUTES_PER_DAY + cfg.intro_minute)
	if _unlock_seen_total < 0:
		_unlock_seen_total = now
		return
	if now >= _open_at(_unlock_seen_total, cfg.intro_minute):
		_open()


## {decor_id: count} waiting for room (§5.2 step 5).
func pending_returns() -> Dictionary:
	return _evict_pending.duplicate()


## §5.1: {"levels", "goal_done", "open_day", "spent", "evict_pending"} + "content_before".
func save_state() -> Dictionary:
	var saved_levels := {}
	for data: BuildingData in all_buildings():
		saved_levels[String(data.id)] = level(data.id)
	for id: StringName in _levels:
		saved_levels[String(id)] = _levels[id]
	var pending := {}
	for id: Variant in _evict_pending:
		pending[String(id)] = int(_evict_pending[id])
	var spent := {}
	for reason: Variant in _spent:
		spent[String(reason)] = int(_spent[reason])
	return {"levels": saved_levels, "goal_done": _goal_done, "open_day": _open_day, "spent": spent,
			"evict_pending": pending, "content_before": _content_before}


## Tolerant: missing / damaged keys fall back to the defaults ({} = all sites, a migrated v4 save).
## Levels are clamped to 0…max_level of known buildings; unknown ids are dropped (warning).
func load_state(data: Dictionary) -> void:
	_levels.clear()
	_evict_pending.clear()
	_spent.clear()
	_unlock_seen_total = -1
	_loaded_v5 = not data.is_empty()
	_lifted.clear()
	var saved: Variant = data.get("levels")
	if saved is Dictionary:
		for key: Variant in saved:
			var id := StringName(str(key))
			var raw: Variant = (saved as Dictionary)[key]
			if not (raw is int or raw is float):
				push_warning("[Buildings] saved level of '%s' is not a number – site" % id)
				continue
			var info := building(id)
			var top := info.max_level() if info != null else 3
			if info == null and not (building_table.is_empty() and Database.buildings().is_empty()):
				push_warning("[Buildings] saved building '%s' is unknown – dropped" % id)
				continue
			var n := clampi(int(raw), 0, top)
			if n != int(raw):
				push_warning("[Buildings] saved level %d of '%s' clamped to %d" % [int(raw), id, n])
			if n > 0:
				_levels[id] = n
	for info: BuildingData in all_buildings():
		if info.start_level > 0 and int(_levels.get(info.id, 0)) < info.start_level:
			_lifted.append(info.id)
	var done: Variant = data.get("goal_done", false)
	_goal_done = done is bool and done
	_evict_pending = _counts(data.get("evict_pending", {}))
	_spent = _counts(data.get("spent", {}))
	_open_day = maxi(_num(data.get("open_day"), 0), 0)
	_content_before = _num(data.get("content_before"), -1)


## v4 (empty state) with unlock_flag → buildings_open at once; decor on the site rects cleared once
## and pending returns handed out (§5.2); rooms, tables, niches and shed to the levels.
func post_load() -> void:
	if not is_open() and _flag_on(_cfg().unlock_flag) and not _loaded_v5:
		_open()
	_evict_sites()
	_flush_pending()
	_repair_start_levels()
	apply_levels()


# --- internals ------------------------------------------------------------------------------

func _on_time_tick(day: int, _minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_morning(day)
	if not _evict_pending.is_empty():
		_flush_pending()


## A new game has no decor on the sites (the build mask blocks them) – the one-time clearing counts
## as done, so the first load does not change the state (save → load identical).
func _on_new_game() -> void:
	if not site_rects.is_empty():
		GameState.set_flag(_cfg().cleared_flag, true)


## Records the unlock time (own bookkeeping only; opening follows in apply_morning).
func _on_chapter_completed(_chapter_id: StringName) -> void:
	if _unlock_seen_total < 0 and _flag_on(_cfg().unlock_flag) and not is_open():
		_unlock_seen_total = TimeManager.total_minutes()


## Bookkeeping for the chapter panel: coins spent after buildings_open, by reason.
func _on_coins_spent(amount: int, reason: StringName) -> void:
	if amount <= 0 or not is_open():
		return
	_spent[reason] = int(_spent.get(reason, 0)) + amount


## Crypt level change: cold windows restart with the new factor, the ossuary follows, and on
## level 1 the corpse on the old table moves onto the crypt table.
func _on_crypt_level(new_level: int) -> void:
	var manager := _first(MANAGER_GROUP)
	if manager != null and manager.has_method(&"restart_cold"):
		manager.call(&"restart_cold", TimeManager.total_minutes())
	if new_level == 1 and manager != null and manager.has_method(&"relocate_table_corpse"):
		var table := _crypt_table()
		var xform := table.call(&"slot_transform") as Transform3D if table != null and table.has_method(&"slot_transform") else Transform3D.IDENTITY
		manager.call(&"relocate_table_corpse", xform, null, CRYPT)
	var ossuary := _first(OSSUARY_GROUP)
	if ossuary != null and ossuary.has_method(&"on_crypt_level"):
		ossuary.call(&"on_crypt_level", new_level)


## Changed 04.10.2026 (user's wish „Gruft von Beginn an“): a save from before (v1–v6, crypt 0) gets
## the crypt at level 1 through level() already; here a corpse on the old table in front of the hut
## moves onto the crypt table with all its state (CorpseManager.relocate_table_corpse, its one note),
## and the ossuary follows the level. Only once: the next save stores level 1.
func _repair_start_levels() -> void:
	if not _lifted.has(CRYPT):
		_lifted.clear()
		return
	_lifted.clear()
	var manager := _first(MANAGER_GROUP)
	if manager != null and manager.has_method(&"relocate_table_corpse"):
		var table := _crypt_table()
		var xform := table.call(&"slot_transform") as Transform3D if table != null and table.has_method(&"slot_transform") else Transform3D.IDENTITY
		manager.call(&"relocate_table_corpse", xform, null, CRYPT)
	var ossuary := _first(OSSUARY_GROUP)
	if ossuary != null and ossuary.has_method(&"on_crypt_level"):
		ossuary.call(&"on_crypt_level", level(CRYPT))


## The MorgueTable in the crypt (room &"crypt") or null.
func _crypt_table() -> Node:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(MORGUE_GROUP):
		if node.get(&"room") == CRYPT:
			return node
	return null


func _services_buried() -> int:
	var rites := _first(CHAPEL_GROUP)
	return int(rites.call(&"services_buried")) if rites != null and rites.has_method(&"services_buried") else 0


func _reinterred() -> PackedStringArray:
	var ossuary := _first(OSSUARY_GROUP)
	if ossuary == null or not ossuary.has_method(&"reinterred"):
		return PackedStringArray()
	var raw: Variant = ossuary.call(&"reinterred")
	return raw if raw is PackedStringArray else PackedStringArray(raw if raw is Array else [])


## The first total minute with the clock at `intro_minute` strictly after `seen_total`.
static func _open_at(seen_total: int, intro_minute: int) -> int:
	var day_index := floori(float(seen_total - intro_minute) / MINUTES_PER_DAY) + 1
	return day_index * MINUTES_PER_DAY + intro_minute


## Sets buildings_open now (debug console, screenshot director; play opens through apply_morning /
## post_load). Idempotent. QA6-03: public instead of calling the private _open by name.
func open() -> void:
	if not is_open():
		_open()


func _open() -> void:
	GameState.set_flag(_cfg().open_flag, true)
	if _open_day <= 0:
		_open_day = TimeManager.day
	if _content_before < 0:
		_content_before = _content_ghosts()
	apply_levels()


## Once (cleared_flag): DecorationManager.evict_rects(site_rects) → pending returns → chest /
## player; one notification when anything was cleared.
func _evict_sites() -> void:
	var cfg := _cfg()
	if site_rects.is_empty() or _flag_on(cfg.cleared_flag):
		return
	var decor := _first(DECOR_GROUP)
	if decor == null or not decor.has_method(&"evict_rects"):
		return
	var removed: Dictionary = decor.call(&"evict_rects", site_rects)
	GameState.set_flag(cfg.cleared_flag, true)
	if removed.is_empty():
		return
	for id: Variant in removed:
		var key := StringName(str(id))
		_evict_pending[key] = int(_evict_pending.get(key, 0)) + int(removed[id])
	_flush_pending()
	EventBus.notification_requested.emit(TEXT_EVICTED, &"info")


## Pending returns → hut chest first, then the player; what fits neither stays pending.
func _flush_pending() -> void:
	if _evict_pending.is_empty():
		return
	var targets: Array[Inventory] = []
	var chest := _chest_storage()
	if chest != null:
		targets.append(chest)
	var player_inv := _player_inventory()
	if player_inv != null:
		targets.append(player_inv)
	for id: Variant in _evict_pending.keys():
		var rest := int(_evict_pending[id])
		for inv: Inventory in targets:
			if rest <= 0:
				break
			rest = inv.add_item(StringName(str(id)), rest)
		if rest > 0:
			_evict_pending[id] = rest
		else:
			_evict_pending.erase(id)


## All or nothing: removes {id: amount} from `inv`, restoring its state on a failure.
func _take_all(take: Dictionary, inv: Inventory) -> bool:
	for id: Variant in take:
		if inv.count(StringName(str(id))) < int(take[id]):
			return false
	var snapshot := inv.save_state()
	for id: Variant in take:
		if not inv.remove_item(StringName(str(id)), int(take[id])):
			push_warning("[Buildings] removing %s failed midway – inventory restored" % id)
			inv.load_state(snapshot)
			return false
	return true


func _content_ghosts() -> int:
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"summary_context"):
		return 0
	return int((graveyard.call(&"summary_context") as Dictionary).get("content_ghosts", 0))


func _chest_storage() -> Inventory:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"saveable"):
		if str(node.get(&"save_id")) == CHEST_SAVE_ID:
			var storage: Variant = node.get(&"storage")
			if storage is Inventory:
				return storage
	return null


func _player_inventory() -> Inventory:
	var player := _first(PLAYER_GROUP)
	if player == null:
		return null
	var inv: Variant = player.get(&"inventory")
	return inv if inv is Inventory else null


func _cfg() -> BuildingsConfig:
	if config == null:
		config = Database.config(&"buildings_config") as BuildingsConfig
		if config == null:
			config = BuildingsConfig.new()
	return config


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group) if is_inside_tree() else null


static func _flag_on(flag: StringName) -> bool:
	var value: Variant = GameState.get_flag(flag, false)
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value) != ""
	return false


static func _counts(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for key: Variant in raw:
		var n := _num((raw as Dictionary)[key], 0)
		if n > 0:
			out[StringName(str(key))] = n
	return out


static func _num(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
