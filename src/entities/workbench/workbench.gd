class_name Workbench
extends Node3D
## Crafting station. Free hands: opens the crafting panel, which calls request_craft(recipe_id).
## A craft runs as a timed action (recipe.craft_minutes, not cancellable), then CraftingSystem.craft.
## Phase 5 (docs/PHASE5_DESIGN.md §2.1, §3.4) – the workyard stations (mason, loom, forge) are
## Workbench nodes with `station` + requires_built:
## - requires_built: invisible and without collision until Workshop.is_built(station).
## - The panel comes from StationData.panel (default &"crafting"); the prompt from prompt_use.
## - Background recipe (the charcoal kiln): stacking as a timed action, then Workshop.start_job;
##   a ready job turns the prompt into "[E] Holzkohle holen (3)" → timed action → Workshop.collect.
## - A crafted tool (ItemData.tool_kind) → tool_tier_changed + a note + Workshop.check_goal.

const PANEL := &"crafting"
const ANIM := &"interact"
const PROMPT_USE := "[E] Werkbank benutzen"
const LABEL_CRAFT := "%s herstellen"
const TEXT_REWARD := "+%d %s"
const TEXT_UNKNOWN := "Dieses Rezept gibt es hier nicht."
const TEXT_MISSING := "Es fehlt: %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar."
const TEXT_FAILED := "Herstellen fehlgeschlagen."
const TEXT_BUSY := "Gerade nicht möglich."
# Phase 5
const WORKSHOP_GROUP := &"workshop"
const PROMPT_COLLECT := "[E] %s holen (%d)"
const LABEL_COLLECT := "%s holen"
const TEXT_JOB_RUNNING := "Hier läuft schon ein Auftrag."
const TEXT_JOB_STARTED := "%s – läuft jetzt allein."
## "Graben dauert jetzt 35 statt 50 Minuten."
const TEXT_TOOL_FASTER := "%s dauert jetzt %d statt %d Minuten."
const TEXT_TOOL_NEW := "%s hängt jetzt am Gürtel."
## Names of the tool-driven actions for the note (ActionConfig.action_tools keys).
const ACTION_NAMES := {&"dig": "Graben", &"bury": "Bestatten"}
const STAT_CRAFTED := &"crafted"

@export var station: StringName = &"workbench"
## Phase 5 §3.4: invisible and without collision until Workshop.is_built(station).
@export var requires_built: bool = false

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Player of the last interaction (the panel crafts for them).
var _player: Player
## Items by id; empty = Database.item() (tests inject fixtures for the tool items).
var item_table: Dictionary[StringName, ItemData] = {}
## Durations for the tool note; null = data/config/action_config.tres.
var action_config: ActionConfig


func _ready() -> void:
	if requires_built:
		EventBus.station_built.connect(_on_station_built)
		EventBus.game_loaded.connect(_on_game_loaded)
		refresh_built()


## Built (or never needs building).
func is_available() -> bool:
	if not requires_built:
		return true
	var shop := workshop()
	return shop != null and shop.is_built(station)


## requires_built: visible, with collision and interactable only once built.
func refresh_built() -> void:
	if not requires_built:
		return
	var on := is_available()
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func can_interact(player: Player) -> bool:
	return player != null and is_available() and not player.is_busy() and not _is_carrying(player)


func get_interaction_prompt(player: Player) -> String:
	if not is_available():
		return ""
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	var job := _ready_job()
	if not job.is_empty():
		return PROMPT_COLLECT % [_item_name(job.output_id), int(job.amount)]
	var data := station_data()
	return data.prompt_use if data != null and data.prompt_use != "" else PROMPT_USE


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	if not _ready_job().is_empty():
		_start_collect(player)
		return
	var data := station_data()
	var panel := data.panel if data != null and data.panel != &"" else PANEL
	var context := {"station": station, "inventory": player.inventory, "workbench": self, "player": player}
	if panel == &"stone_design":
		context["bench"] = self  # §7: {inventory, player, bench}
	EventBus.ui_panel_requested.emit(panel, context)


## Panel: crafts `recipe_id` for the player of the last interaction (warning when impossible).
## A background recipe stacks for craft_minutes, then runs on its own (Workshop.start_job).
func request_craft(recipe_id: StringName) -> void:
	var recipe := Database.recipe(recipe_id) as RecipeData
	var player := _player if is_instance_valid(_player) else _first_player()
	if recipe == null or recipe.station != station:
		_warn(TEXT_UNKNOWN)
		return
	if player == null or player.is_busy() or _is_carrying(player) or not is_available():
		_warn(TEXT_BUSY)
		return
	var inv := player.inventory
	if recipe.background:
		var shop := workshop()
		var reason := shop.job_block_reason(station, recipe, inv) if shop != null else TEXT_BUSY
		if reason != "":
			_warn(reason)
			return
		player.start_timed_action(_recipe_name(recipe), recipe.craft_minutes, _start_job.bind(recipe, inv), false, ANIM)
		return
	if not CraftingSystem.can_craft(recipe, inv):
		var missing := CraftingSystem.missing(recipe, inv)
		_warn(TEXT_MISSING % _describe(missing) if not missing.is_empty() else TEXT_NO_ROOM)
		return
	player.start_timed_action(LABEL_CRAFT % _recipe_name(recipe), recipe.craft_minutes, _finish_craft.bind(recipe, inv), false, ANIM)


func _finish_craft(recipe: RecipeData, inv: Inventory) -> void:
	var tool := _item_data(recipe.output_id)
	var tier_before := _belt_tier(inv, tool.tool_kind) if tool != null and tool.tool_kind != &"" else 0
	if not CraftingSystem.craft(recipe, inv):
		_warn(TEXT_FAILED)
		return
	GameState.add_stat(STAT_CRAFTED, 1)
	EventBus.notification_requested.emit(TEXT_REWARD % [recipe.output_amount, _item_name(recipe.output_id)], &"reward")
	if tool != null and tool.tool_kind != &"":
		# QA5-04: a lower tool next to a better one on the belt changes no tier (no "faster" note).
		if tool.tool_tier > tier_before:
			EventBus.tool_tier_changed.emit(tool.tool_kind, tool.tool_tier)
			EventBus.notification_requested.emit(tool_note(tool), &"info")
		else:
			EventBus.notification_requested.emit(TEXT_TOOL_NEW % (tool.display_name if tool.display_name != "" else String(tool.id)), &"info")
		var shop := workshop()
		if shop != null:
			shop.check_goal()


## "Graben dauert jetzt 35 statt 50 Minuten." for a kind that drives an action (shovel), else
## "Holzfälleraxt hängt jetzt am Gürtel."
func tool_note(tool: ItemData) -> String:
	var actions := _actions()
	for action: StringName in actions.action_tools:
		if actions.action_tools[action] != tool.tool_kind:
			continue
		var base_name := String(action) + "_minutes"
		var base: Variant = actions.get(base_name)
		if not base is int:
			continue
		var before := actions.tool_minutes(base, maxi(tool.tool_tier - 1, 0))
		var after := actions.tool_minutes(base, tool.tool_tier)
		if after < before:
			return TEXT_TOOL_FASTER % [ACTION_NAMES.get(action, String(action)), after, before]
	return TEXT_TOOL_NEW % (tool.display_name if tool.display_name != "" else String(tool.id))


func _start_job(recipe: RecipeData, inv: Inventory) -> void:
	var shop := workshop()
	if shop == null or not shop.start_job(station, recipe, inv):
		_warn(TEXT_FAILED)
		return
	EventBus.notification_requested.emit(TEXT_JOB_STARTED % _recipe_name(recipe), &"info")


func _start_collect(player: Player) -> void:
	var job := _ready_job()
	var shop := workshop()
	if job.is_empty() or shop == null:
		return
	var minutes := shop.workshop_config().collect_minutes
	player.start_timed_action(LABEL_COLLECT % _item_name(job.output_id), minutes, _finish_collect.bind(player.inventory), false, ANIM)


func _finish_collect(inv: Inventory) -> void:
	var shop := workshop()
	if shop == null:
		return
	var job := shop.job_of(station)
	var got := shop.collect(station, inv)
	if got > 0:
		EventBus.notification_requested.emit(TEXT_REWARD % [got, _item_name(job.output_id)], &"reward")


## The station's ready background job ({} when none / not ready).
func _ready_job() -> Dictionary:
	var shop := workshop()
	if shop == null:
		return {}
	var job := shop.job_of(station)
	return job if not job.is_empty() and job.ready else {}


## Systems/Workshop (group workshop) or null.
func workshop() -> Workshop:
	return get_tree().get_first_node_in_group(WORKSHOP_GROUP) as Workshop if is_inside_tree() else null


## StationData of `station` (Database) or null.
func station_data() -> StationData:
	return Database.station(station) as StationData


func _on_station_built(station_id: StringName) -> void:
	if station_id == station:
		refresh_built()


func _on_game_loaded(_slot: int) -> void:
	refresh_built()


## "2 Holz, 1 Stein"
static func _describe(missing: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: Variant in missing:
		parts.append("%d %s" % [int(missing[id]), _item_name(StringName(id))])
	return ", ".join(parts)


static func _recipe_name(recipe: RecipeData) -> String:
	return recipe.display_name if recipe.display_name != "" else _item_name(recipe.output_id)


static func _item_name(id: StringName) -> String:
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)


## Highest tool_tier of `kind` on the belt of `inv` (the items of item_table / Database).
func _belt_tier(inv: Inventory, kind: StringName) -> int:
	var best := 0
	if inv == null or kind == &"":
		return best
	for id: StringName in inv.tools():
		var item := _item_data(id)
		if item != null and item.tool_kind == kind:
			best = maxi(best, item.tool_tier)
	return best


func _item_data(id: StringName) -> ItemData:
	if not item_table.is_empty():
		return item_table.get(id)
	return Database.item(id) as ItemData if Database.has_item(id) else null


func _actions() -> ActionConfig:
	if action_config == null:
		action_config = Database.config(&"action_config") as ActionConfig
		if action_config == null:
			action_config = ActionConfig.new()
	return action_config


func _first_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
