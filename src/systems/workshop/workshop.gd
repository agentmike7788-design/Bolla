class_name Workshop
extends Node
## Systems/Workshop (docs/PHASE5_DESIGN.md §1.2, §1.5, §2.1, §3.1, §3.4, §5.1, §5.2), groups
## &"workshop", &"saveable": built stations, the one background job per station (the charcoal
## kiln), workshop_open, the chapter "Namen in Stein" and the one-time clearing of decor on the
## workyard.
## - Unlock: the first morning (first minute ≥ intro_minute) after unlock_flag was first seen
##   sets open_flag (time_tick → apply_morning); a loaded save with unlock_flag opens at once
##   (post_load).
## - Build (BuildSite after its timed action): items + coins at once, atomically; station_built,
##   coins_spent(&"build") (+ stats.coins_spent); check_goal.
## - Background job (Workbench → start_job): ingredients at once, ends background_minutes later
##   (WorkshopConfig; 0 → the recipe's craft_minutes); collect puts the yield into an inventory
##   (full → nothing, the job stays). workshop_job_changed started / ready / collected.
## - Chapter (§1.5): all goal stations built, goal tool tiers on the player's belt, master
##   stones (stone_master with an inscription) set → goal_flag, chapter_completed, summary panel
##   (variant names_in_stone). Once.
## - Workyard (§5.2 step 5): post_load clears decor in workyard_rects once (flag
##   workyard_cleared) via DecorationManager.evict_rects; the items go to the hut chest, overflow
##   to the player, the rest stays pending here (saved) until there is room. Nothing is lost.

const GROUP := &"workshop"
const PLAYER_GROUP := &"player"
const DECOR_GROUP := &"decorations"
const GRAVEYARD_GROUP := &"graveyard"
const CHEST_SAVE_ID := "hut_chest"
const FLAG_CLEARED := &"workyard_cleared"
const STAT_COINS_SPENT := &"coins_spent"
const STAT_CRAFTED := &"crafted"
const REASON_BUILD := &"build"
const JOB_STARTED := &"started"
const JOB_READY := &"ready"
const JOB_COLLECTED := &"collected"
const SUMMARY_PANEL := &"slice_summary"
const MASTER_SHAPE := &"stone_master"
const MINUTES_PER_DAY := 1440
const TEXT_EVICTED := "Deine Zier stand auf dem neuen Werkhof. Sie liegt jetzt in der Truhe."
const TEXT_JOB_READY := "%s ist fertig – %s holen."
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const TEXT_FINAL_LINE := "Die Namen stehen jetzt da, wo der Regen sie nicht wegwäscht."

@export var save_id: String = "workshop"
@export var save_order: int = 30
## Footprint + margin + access of the workyard (the builder fills them from
## layout.workyard.blocked_rects); decor in them is cleared once (post_load, §5.2 step 5).
@export var workyard_rects: Array[Rect2] = []

## Rules; null = data/config/workshop_config.tres (resolved lazily).
var config: WorkshopConfig
## Stations by id; empty = Database.station() (tests inject fixtures).
var station_table: Dictionary[StringName, StationData] = {}
## Recipes by id; empty = Database.recipe() (tests inject fixtures).
var recipe_table: Dictionary[StringName, RecipeData] = {}
## Items by id for the tool tiers; empty = Database.item() (tests inject fixtures).
var item_table: Dictionary[StringName, ItemData] = {}
## Inventory whose tool belt counts for the chapter; null = the player's.
var tool_inventory: Inventory

var _built: Array[StringName] = []
## {station_id: {"recipe": StringName, "end_total": int}}
var _jobs: Dictionary = {}
var _goal_done: bool = false
## {decor_id: count} cleared from the workyard that did not fit anywhere yet.
var _evict_pending: Dictionary = {}
## Day workshop_open was set (0 = unknown / not open).
var _open_day: int = 0
## Coins spent after workshop_open by reason (coins_spent) – for the chapter panel.
var _spent: Dictionary = {}
## Content ghosts when the workshop opened (-1 = unknown).
var _content_before: int = -1
## total_minutes when unlock_flag was first seen this session (-1 = not yet; not saved: a
## loaded save with the flag opens at once).
var _unlock_seen_total: int = -1
## load_state got a Phase-5 state (not the empty {} of a migrated Phase-4 save): then post_load
## leaves the unlock to the next morning, as in play (save → load identical, W-Welt W2).
var _loaded_v4: bool = false
## Stations whose ready job was announced (not saved: at worst announced once more).
var _announced: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.cemetery_completed.connect(_on_cemetery_completed)
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.new_game_started.connect(_on_new_game)


## The resolved WorkshopConfig (config or data/config/workshop_config.tres).
func workshop_config() -> WorkshopConfig:
	return _cfg()


## Flag workshop_open.
func is_open() -> bool:
	return _flag_on(_cfg().open_flag)


## Built on its site, or prebuilt (the workbench).
func is_built(station_id: StringName) -> bool:
	if _built.has(station_id):
		return true
	var s := _station(station_id)
	return s != null and s.prebuilt


## Stations built on their sites, in build order (the prebuilt workbench is not listed).
func built() -> Array[StringName]:
	return _built.duplicate()


## "" or why `station_id` cannot be built now with `inv` (WorkshopRules).
func build_block_reason(station_id: StringName, inv: Inventory) -> String:
	return WorkshopRules.build_block_reason(_station(station_id), inv, is_built(station_id), is_open())


## Atomic: items + coins at the end of the build; station_built, coins_spent(&"build"); check_goal.
func build(station_id: StringName, inv: Inventory) -> bool:
	var s := _station(station_id)
	if s == null or not is_instance_valid(inv):
		return false
	if build_block_reason(station_id, inv) != "":
		return false
	var take: Dictionary = {}
	for id: StringName in s.build_inputs:
		take[id] = int(s.build_inputs[id])
	if s.build_coins > 0:
		take[WorkshopRules.COIN] = s.build_coins
	if not _take_all(take, inv):
		return false
	_built.append(station_id)
	if s.build_coins > 0:
		GameState.add_stat(STAT_COINS_SPENT, s.build_coins)
		EventBus.coins_spent.emit(s.build_coins, REASON_BUILD)
	EventBus.station_built.emit(station_id)
	check_goal()
	return true


## "" or why the background `recipe` cannot start at `station_id`.
func job_block_reason(station_id: StringName, recipe: RecipeData, inv: Inventory) -> String:
	if recipe == null or not recipe.background or recipe.station != station_id:
		return Workbench.TEXT_UNKNOWN
	if not is_built(station_id):
		return Workbench.TEXT_BUSY
	if _jobs.has(station_id):
		return Workbench.TEXT_JOB_RUNNING
	if not is_instance_valid(inv):
		return Workbench.TEXT_BUSY
	var gaps := CraftingSystem.missing(recipe, inv)
	if not gaps.is_empty():
		return Workbench.TEXT_MISSING % WorkshopRules.describe(gaps)
	return ""


## Only background recipes; ingredients at once; end = now + background_minutes (0 → the
## recipe's craft_minutes). At most one job per station.
func start_job(station_id: StringName, recipe: RecipeData, inv: Inventory) -> bool:
	if job_block_reason(station_id, recipe, inv) != "":
		return false
	if not _take_all(recipe.inputs, inv):
		return false
	var minutes := _cfg().background_minutes if _cfg().background_minutes > 0 else recipe.craft_minutes
	_jobs[station_id] = {"recipe": recipe.id, "end_total": TimeManager.total_minutes() + maxi(minutes, 0)}
	_announced.erase(station_id)
	EventBus.workshop_job_changed.emit(station_id, recipe.id, JOB_STARTED)
	return true


## {} | {recipe (id), end_total, ready: bool, output_id, amount}
func job_of(station_id: StringName) -> Dictionary:
	if not _jobs.has(station_id):
		return {}
	var job: Dictionary = _jobs[station_id]
	var recipe := _recipe(job.recipe)
	return {"recipe": job.recipe, "end_total": int(job.end_total), "ready": TimeManager.total_minutes() >= int(job.end_total),
			"output_id": recipe.output_id if recipe != null else &"", "amount": recipe.output_amount if recipe != null else 0}


## Yield into the inventory (not ready / full → 0, the job stays); workshop_job_changed collected.
func collect(station_id: StringName, inv: Inventory) -> int:
	var job := job_of(station_id)
	if job.is_empty() or not job.ready or not is_instance_valid(inv):
		return 0
	var recipe := _recipe(job.recipe)
	if recipe == null:
		push_warning("[Workshop] job '%s' at %s has an unknown recipe – dropped" % [job.recipe, station_id])
		_jobs.erase(station_id)
		return 0
	if not inv.can_add(recipe.output_id, recipe.output_amount):
		EventBus.notification_requested.emit(TEXT_NO_ROOM, &"warning")
		return 0
	var rest := inv.add_item(recipe.output_id, recipe.output_amount)
	if rest > 0:
		push_warning("[Workshop] collect %s: %d did not fit" % [station_id, rest])
	_jobs.erase(station_id)
	_announced.erase(station_id)
	GameState.add_stat(STAT_CRAFTED, 1)
	EventBus.workshop_job_changed.emit(station_id, recipe.id, JOB_COLLECTED)
	return recipe.output_amount - rest


## WorkshopRules.goal_progress over the built stations, the player's tool tiers and the master
## stones set.
func goal_progress() -> Dictionary:
	return WorkshopRules.goal_progress(built(), tiers(), master_stones(), _cfg())


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
## variant/chapter = chapter_id, plus days since workshop_open, stations, tool tiers, stones set
## (master stones), graves with a name n/total, coins spent by reason, content ghosts before/now.
func chapter_context() -> Dictionary:
	var cfg := _cfg()
	var context := {}
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"summary_context"):
		context = graveyard.call(&"summary_context")
	context["variant"] = cfg.chapter_id
	context["chapter"] = cfg.chapter_id
	context["workshop_days"] = maxi(TimeManager.day - _open_day, 0) if _open_day > 0 else 0
	context["stations"] = built()
	context["tool_tiers"] = tiers()
	context["stones_set"] = GameState.get_stat(&"stones_set")
	context["master_stones"] = master_stones()
	var named := _named_graves()
	context["named_graves"] = named[0]
	context["graves_total"] = named[1]
	context["coins_spent"] = _spent.duplicate()
	context["content_before"] = maxi(_content_before, 0)
	context["content_now"] = _content_ghosts()
	context["final_line"] = TEXT_FINAL_LINE
	return context


## Idempotent: workshop_open at the first minute ≥ intro_minute after unlock_flag was first
## seen (the first morning after cemetery_complete; §1.2).
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


## Tool tiers {kind: tier} of the goal kinds on the player's belt (ToolRules, and the belt's
## ItemData.tool_tier as a fallback).
func tiers() -> Dictionary:
	var out := {}
	var inv := _tool_inventory()
	for kind: StringName in _cfg().goal_tiers:
		out[kind] = _tier_of(inv, kind)
	return out


## Graves with a master stone (stone_master) that carries an inscription.
func master_stones() -> int:
	var n := 0
	for grave: GraveRecord in _graves():
		if grave.marker_id != MASTER_SHAPE:
			continue
		var design := StoneDesign.from_dict(grave.design)
		if design.shape == MASTER_SHAPE and design.inscription != &"":
			n += 1
	return n


## {decor_id: count} waiting for room (§5.2 step 5).
func pending_returns() -> Dictionary:
	return _evict_pending.duplicate()


## §5.1: {"built", "jobs", "goal_done", "evict_pending"} + "open_day", "spent", "content_before".
func save_state() -> Dictionary:
	var built_list: Array = []
	for id: StringName in _built:
		built_list.append(String(id))
	var jobs := {}
	for station_id: StringName in _jobs:
		var job: Dictionary = _jobs[station_id]
		jobs[String(station_id)] = {"recipe": String(job.recipe), "end_total": int(job.end_total)}
	var pending := {}
	for id: Variant in _evict_pending:
		pending[String(id)] = int(_evict_pending[id])
	var spent := {}
	for reason: Variant in _spent:
		spent[String(reason)] = int(_spent[reason])
	return {"built": built_list, "jobs": jobs, "goal_done": _goal_done, "evict_pending": pending,
			"open_day": _open_day, "spent": spent, "content_before": _content_before}


## Tolerant: missing / damaged keys fall back to the defaults ({} = nothing built).
func load_state(data: Dictionary) -> void:
	_built.clear()
	_jobs.clear()
	_evict_pending.clear()
	_spent.clear()
	_announced.clear()
	_unlock_seen_total = -1
	_loaded_v4 = not data.is_empty()
	var raw_built: Variant = data.get("built", [])
	if raw_built is Array:
		for raw: Variant in raw_built:
			var id := StringName(str(raw)) if (raw is String or raw is StringName) else &""
			if id == &"" or _built.has(id):
				continue
			if _station(id) == null:
				push_warning("[Workshop] saved station '%s' is unknown – dropped" % id)
				continue
			_built.append(id)
	var raw_jobs: Variant = data.get("jobs", {})
	if raw_jobs is Dictionary:
		for key: Variant in raw_jobs:
			var job: Variant = (raw_jobs as Dictionary)[key]
			if not job is Dictionary:
				continue
			var recipe_id := StringName(str((job as Dictionary).get("recipe", "")))
			var end: Variant = (job as Dictionary).get("end_total")
			if recipe_id == &"" or not (end is int or end is float) or _recipe(recipe_id) == null:
				push_warning("[Workshop] saved job %s dropped" % [job])
				continue
			_jobs[StringName(str(key))] = {"recipe": recipe_id, "end_total": int(end)}
	var done: Variant = data.get("goal_done", false)
	_goal_done = done is bool and done
	_evict_pending = _counts(data.get("evict_pending", {}))
	_spent = _counts(data.get("spent", {}))
	_open_day = maxi(_num(data.get("open_day"), 0), 0)
	_content_before = _num(data.get("content_before"), -1)


## workshop_open at once when unlock_flag holds (§1.2 – a migrated save; a Phase-5 save whose
## unlock is still waiting for its morning keeps waiting); decor on the workyard cleared once and
## pending returns handed out (§5.2 step 5).
func post_load() -> void:
	if not is_open() and _flag_on(_cfg().unlock_flag) and not _loaded_v4:
		_open()
	_evict_workyard()
	_flush_pending()


# --- internals ------------------------------------------------------------------------------

func _on_time_tick(day: int, _minute: int) -> void:
	if SaveManager.is_loading:
		return
	apply_morning(day)
	_announce_ready_jobs()
	if not _evict_pending.is_empty():
		_flush_pending()


## W-Welt (W2): a new game has no decor on the workyard (the build mask blocks it) – the one-time
## clearing counts as done, so the first load does not change the state (save → load identical).
func _on_new_game() -> void:
	if not workyard_rects.is_empty():
		GameState.set_flag(FLAG_CLEARED, true)


## Records the unlock time (own bookkeeping only; opening follows in apply_morning).
func _on_cemetery_completed() -> void:
	if _unlock_seen_total < 0 and _cfg().unlock_flag == &"cemetery_complete":
		_unlock_seen_total = TimeManager.total_minutes()


## Bookkeeping for the chapter panel: coins spent after workshop_open, by reason.
func _on_coins_spent(amount: int, reason: StringName) -> void:
	if amount <= 0 or not is_open():
		return
	_spent[reason] = int(_spent.get(reason, 0)) + amount


## The first total minute with the clock at `intro_minute` strictly after `seen_total`.
static func _open_at(seen_total: int, intro_minute: int) -> int:
	var day_index := floori(float(seen_total - intro_minute) / MINUTES_PER_DAY) + 1
	return day_index * MINUTES_PER_DAY + intro_minute


func _open() -> void:
	GameState.set_flag(_cfg().open_flag, true)
	if _open_day <= 0:
		_open_day = TimeManager.day
	if _content_before < 0:
		_content_before = _content_ghosts()


func _announce_ready_jobs() -> void:
	for station_id: StringName in _jobs:
		if _announced.has(station_id):
			continue
		var job := job_of(station_id)
		if not job.ready:
			continue
		_announced[station_id] = true
		EventBus.workshop_job_changed.emit(station_id, job.recipe, JOB_READY)
		var recipe := _recipe(job.recipe)
		if recipe != null:
			var name := Workbench._item_name(recipe.output_id)
			EventBus.notification_requested.emit(TEXT_JOB_READY % [recipe.display_name if recipe.display_name != "" else name, name], &"info")


## Once (flag workyard_cleared): DecorationManager.evict_rects(workyard_rects) → pending returns
## → chest / player; one notification when anything was cleared.
func _evict_workyard() -> void:
	if workyard_rects.is_empty() or _flag_on(FLAG_CLEARED):
		return
	var decor := _first(DECOR_GROUP)
	if decor == null or not decor.has_method(&"evict_rects"):
		return
	var removed: Dictionary = decor.call(&"evict_rects", workyard_rects)
	GameState.set_flag(FLAG_CLEARED, true)
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
			push_warning("[Workshop] removing %s failed midway – inventory restored" % id)
			inv.load_state(snapshot)
			return false
	return true


func _tier_of(inv: Inventory, kind: StringName) -> int:
	if inv == null:
		return 0
	var best := ToolRules.tier(inv, kind)
	var belt: Dictionary = inv.tools()
	for id: Variant in belt:
		var item := _item(StringName(str(id)))
		if item != null and item.tool_kind == kind:
			best = maxi(best, item.tool_tier)
	return best


## [graves with an inscription on their stone, graves that count] (§1.5 "Gräber mit Namen n/18").
func _named_graves() -> Array:
	var named := 0
	var total := 0
	for grave: GraveRecord in _graves():
		if grave.state == GraveRecord.State.MARKED or grave.state == GraveRecord.State.FILLED:
			total += 1
			if StoneDesign.from_dict(grave.design).inscription != &"":
				named += 1
	return [named, total]


func _graves() -> Array[GraveRecord]:
	var out: Array[GraveRecord] = []
	var graveyard := _first(GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"graves"):
		out.assign(graveyard.call(&"graves"))
	return out


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


func _tool_inventory() -> Inventory:
	if is_instance_valid(tool_inventory):
		return tool_inventory
	return _player_inventory()


func _station(id: StringName) -> StationData:
	if not station_table.is_empty():
		return station_table.get(id)
	return Database.station(id) as StationData


func _recipe(id: StringName) -> RecipeData:
	if not recipe_table.is_empty():
		return recipe_table.get(id)
	return Database.recipe(id) as RecipeData


func _item(id: StringName) -> ItemData:
	if not item_table.is_empty():
		return item_table.get(id)
	return Database.item(id) as ItemData if Database.has_item(id) else null


func _cfg() -> WorkshopConfig:
	if config == null:
		config = Database.config(&"workshop_config") as WorkshopConfig
		if config == null:
			config = WorkshopConfig.new()
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
