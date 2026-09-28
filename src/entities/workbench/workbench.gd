class_name Workbench
extends Node3D
## Crafting station. Free hands: opens the crafting panel, which calls request_craft(recipe_id).
## A craft runs as a timed action (recipe.craft_minutes, not cancellable), then CraftingSystem.craft.

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

@export var station: StringName = &"workbench"
## STUB (P1) Phase 5 §3.4: invisible and without collision until Workshop.is_built(station) –
## no effect yet. The panel comes from StationData.panel; background recipes → Workshop.start_job.
@export var requires_built: bool = false

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## Player of the last interaction (the panel crafts for them).
var _player: Player


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not _is_carrying(player)


func get_interaction_prompt(player: Player) -> String:
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	return PROMPT_USE


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	_player = player
	EventBus.ui_panel_requested.emit(PANEL, {"station": station, "inventory": player.inventory, "workbench": self, "player": player})


## Panel: crafts `recipe_id` for the player of the last interaction (warning when impossible).
func request_craft(recipe_id: StringName) -> void:
	var recipe := Database.recipe(recipe_id) as RecipeData
	var player := _player if is_instance_valid(_player) else _first_player()
	if recipe == null or recipe.station != station:
		_warn(TEXT_UNKNOWN)
		return
	if player == null or player.is_busy() or _is_carrying(player):
		_warn(TEXT_BUSY)
		return
	var inv := player.inventory
	if not CraftingSystem.can_craft(recipe, inv):
		var missing := CraftingSystem.missing(recipe, inv)
		_warn(TEXT_MISSING % _describe(missing) if not missing.is_empty() else TEXT_NO_ROOM)
		return
	player.start_timed_action(LABEL_CRAFT % _recipe_name(recipe), recipe.craft_minutes, _finish_craft.bind(recipe, inv), false, ANIM)


func _finish_craft(recipe: RecipeData, inv: Inventory) -> void:
	if not CraftingSystem.craft(recipe, inv):
		_warn(TEXT_FAILED)
		return
	EventBus.notification_requested.emit(TEXT_REWARD % [recipe.output_amount, _item_name(recipe.output_id)], &"reward")


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


func _first_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func _warn(text: String) -> void:
	EventBus.notification_requested.emit(text, &"warning")


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
