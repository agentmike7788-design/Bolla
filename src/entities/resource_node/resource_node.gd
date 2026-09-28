class_name ResourceNode
extends Node3D
## Gatherable pile (wood/stone) with a daily amount (saveable). Refilled to daily_amount on
## day_started and on new_game_started; a load from an earlier day refills as well.
## One interaction = gather_minutes (timed, cancellable) → gather_amount items.

const ANIM := &"interact"
const PROMPT := "[E] %s (%d Min) – %d übrig"
const PROMPT_EMPTY := "Für heute leer"
const PROMPT_NO_ROOM := "Kein Platz im Inventar"
const LABEL_DEFAULT := "%s sammeln"
const TEXT_REWARD := "+%d %s"
const TEXT_NO_ROOM := "Kein Platz im Inventar."

@export var save_id: String = ""
@export var save_order: int = 20
@export var item_id: StringName
@export var daily_amount: int = 4
@export var model: PackedScene
## Verb shown in the prompt and progress bar ("Holz sammeln"); empty = "<Item> sammeln".
@export var action_label: String = ""
## Items per interaction.
@export var gather_amount: int = 1

## Items left today; full resources exist only after new_game_started / a new day / a load.
var remaining: int = 0
var last_reset_day: int = 0

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(&"saveable", true)


func _ready() -> void:
	if model != null and get_node_or_null(^"Model") == null:
		var inst := model.instantiate()
		inst.name = "Model"
		add_child(inst)
		move_child(inst, 0)
	EventBus.day_started.connect(_on_day_started)
	EventBus.new_game_started.connect(_on_new_game_started)


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not _is_carrying(player) and remaining > 0 \
			and player.inventory.can_add(item_id, gather_amount)


func get_interaction_prompt(player: Player) -> String:
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	if remaining <= 0:
		return PROMPT_EMPTY
	if player != null and not player.inventory.can_add(item_id, gather_amount):
		return PROMPT_NO_ROOM
	return PROMPT % [label(), _minutes(player), remaining]


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	player.start_timed_action(label(), _minutes(player), _finish_gather.bind(player.inventory), true, ANIM)


## "Holz sammeln"
func label() -> String:
	if action_label != "":
		return action_label
	return LABEL_DEFAULT % _item_name()


## Refills to daily_amount for `day`.
func refill(day: int) -> void:
	remaining = maxi(daily_amount, 0)
	last_reset_day = day


func save_state() -> Dictionary:
	return {"remaining": remaining, "last_reset_day": last_reset_day}


func load_state(data: Dictionary) -> void:
	remaining = clampi(_int(data.get("remaining"), 0), 0, maxi(daily_amount, 0))
	last_reset_day = maxi(_int(data.get("last_reset_day"), 0), 0)
	if TimeManager.day > last_reset_day:
		refill(TimeManager.day)


## A save without this node's state (older / damaged save) keeps the default 0 – refill like a
## load_state of an earlier day would (QA-08: otherwise the next save → load differs).
func post_load() -> void:
	if last_reset_day < TimeManager.day:
		refill(TimeManager.day)


func _finish_gather(inv: Inventory) -> void:
	if remaining <= 0:
		return
	var rest := inv.add_item(item_id, mini(gather_amount, remaining))
	var added := mini(gather_amount, remaining) - rest
	if added > 0:
		remaining -= added
		EventBus.notification_requested.emit(TEXT_REWARD % [added, _item_name()], &"reward")
	if rest > 0:
		EventBus.notification_requested.emit(TEXT_NO_ROOM, &"warning")


func _on_day_started(day: int) -> void:
	refill(day)


func _on_new_game_started() -> void:
	refill(TimeManager.day)


func _item_name() -> String:
	var item := Database.item(item_id) as ItemData if Database.has_item(item_id) else null
	return item.display_name if item != null and item.display_name != "" else String(item_id)


## Phase 5 §3.4 (P3): the minute source goes through the tool rules (ActionConfig.action_tools has
## no &"gather" entry, so the wood and stone piles keep gather_minutes).
static func _minutes(player: Player) -> int:
	var actions := _actions(player)
	return ToolRules.action_minutes(actions, &"gather", actions.gather_minutes, player.inventory if player != null else null)


static func _actions(player: Player) -> ActionConfig:
	if player != null and player.actions != null:
		return player.actions
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	return fallback
