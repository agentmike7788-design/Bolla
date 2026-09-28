class_name GatherNode
extends Node3D
## Entities/gather_<id> (docs/PHASE5_DESIGN.md §2.2, §3.4, §4.2–4.4): an Interactable gather node.
## State lives in GatherManager (Systems/Gathering); this node only registers itself, shows the
## model of its stage and runs the timed action. Group &"gather_node".
## Models: children "Full" / "Empty" / "Regrow" (made from GatherNodeData.model_* unless the builder
## already added them): full + partial → Full, empty → Empty, regrowing → Regrow (Empty when there
## is no Regrow). A node without models (the elder bush child) never changes any visuals.
## Prompt "[E] Erle fällen (50 Min) → +4 Holz"; before requires_flag (workshop_open) no prompt at
## all; while the section is closed the section's text ("Findlinge versperren den Weg.").
## Minutes: ActionConfig.tool_minutes(data.minutes, player.tool_tier(data.tool_kind)).

const GROUP := &"gather_node"
const MANAGER_GROUP := &"gathering"
const EXPANSION_GROUP := &"expansion"
const FULL_NAME := "Full"
const EMPTY_NAME := "Empty"
const REGROW_NAME := "Regrow"
const PROMPT := "[E] %s (%d Min) → +%d %s"
const TEXT_REWARD := "+%d %s"
const TEXT_FAILED := "Das geht hier gerade nicht."

@export var node_id: String = ""
@export var kind: StringName = &""
## &"" = no section gate (bruch / quarry: ExpansionManager.is_unlocked).
@export var section_id: StringName = &""

var shown_stage: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _init() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var data := _data()
	if data != null:
		_ensure_model(data.model_full, FULL_NAME)
		_ensure_model(data.model_empty, EMPTY_NAME)
		_ensure_model(data.model_regrow, REGROW_NAME)
	var manager := _manager()
	if manager != null:
		register_with(manager)
	else:
		apply_stage(GatherRules.STAGE_FULL)


func _enter_tree() -> void:
	if not EventBus.gather_node_changed.is_connected(_on_changed):
		EventBus.gather_node_changed.connect(_on_changed)


func _exit_tree() -> void:
	if EventBus.gather_node_changed.is_connected(_on_changed):
		EventBus.gather_node_changed.disconnect(_on_changed)


## Registers this node (idempotent) and shows its stage.
func register_with(manager: GatherManager) -> void:
	if node_id == "":
		push_warning("[GatherNode] %s has no node_id" % get_path())
		return
	var data := manager.data_for_kind(kind)
	if data == null:
		push_warning("[GatherNode] %s: unknown kind '%s'" % [node_id, kind])
		return
	manager.register(node_id, data)
	apply_stage(manager.stage(node_id))


## Model of `stage` (no-op without models).
func apply_stage(stage: StringName) -> void:
	shown_stage = stage
	var full := get_node_or_null(FULL_NAME) as Node3D
	var empty := get_node_or_null(EMPTY_NAME) as Node3D
	var regrow := get_node_or_null(REGROW_NAME) as Node3D
	var show_full := stage == GatherRules.STAGE_FULL or stage == GatherRules.STAGE_PARTIAL
	var show_regrow := stage == GatherRules.STAGE_REGROWING and regrow != null
	if full != null:
		full.visible = show_full
	if regrow != null:
		regrow.visible = show_regrow
	if empty != null:
		empty.visible = not show_full and not show_regrow


func flag_ok() -> bool:
	var data := _data()
	return data != null and (data.requires_flag == &"" or GameState.has_flag(data.requires_flag))


func section_open() -> bool:
	if section_id == &"":
		return true
	var expansion := _expansion()
	return expansion == null or expansion.is_unlocked(section_id)


## Text while the section is closed: its requires_flag_text ("Findlinge versperren den Weg."),
## else its prerequisite, else a plain fallback.
func section_text() -> String:
	var expansion := _expansion()
	var s := expansion.section(section_id) if expansion != null else null
	if s != null and s.requires_flag_text != "":
		return s.requires_flag_text
	var reason := expansion.block_reason(section_id) if expansion != null else ""
	return reason if reason != "" else GatherRules.TEXT_SECTION


## "" = gatherable now (flag, section, charges, tool tier, room).
func block_reason(player: Player) -> String:
	var manager := _manager()
	var data := _data()
	if manager == null or data == null or not manager.is_registered(node_id):
		return GatherRules.TEXT_NOT_OPEN
	if not flag_ok():
		return GatherRules.TEXT_NOT_OPEN
	if not section_open():
		return section_text()
	var inv := player.inventory if player != null else null
	return manager.block_reason(node_id, inv, _tier(player, data))


func minutes(player: Player) -> int:
	var data := _data()
	return GatherRules.minutes_for(data, _tier(player, data), _actions(player))


func can_interact(player: Player) -> bool:
	if player == null or player.is_busy() or _is_carrying(player):
		return false
	return block_reason(player) == ""


func get_interaction_prompt(player: Player) -> String:
	var data := _data()
	if data == null or not flag_ok():
		return ""
	if player != null and _is_carrying(player):
		return Player.TEXT_HANDS_FULL
	var reason := block_reason(player)
	if reason != "":
		return reason
	return PROMPT % [data.verb, minutes(player), GatherRules.yield_for(data, _tier(player, data)), _item_name(data.item_id)]


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var data := _data()
	player.start_timed_action(data.verb, minutes(player), _finish.bind(player), true, data.animation)


func _finish(player: Player) -> void:
	var manager := _manager()
	var data := _data()
	if manager == null or data == null or not is_instance_valid(player) or not flag_ok() or not section_open():
		EventBus.notification_requested.emit(TEXT_FAILED, &"warning")
		return
	var got := manager.gather(node_id, player.inventory, _tier(player, data))
	if got <= 0:
		EventBus.notification_requested.emit(TEXT_FAILED, &"warning")
		return
	EventBus.notification_requested.emit(TEXT_REWARD % [got, _item_name(data.item_id)], &"reward")


func _on_changed(changed_id: String, _charges: int, stage: StringName) -> void:
	if changed_id == node_id:
		apply_stage(stage)


func _ensure_model(scene: PackedScene, node_name: String) -> void:
	if scene == null or get_node_or_null(node_name) != null:
		return
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return
	inst.name = node_name
	add_child(inst)


func _data() -> GatherNodeData:
	var manager := _manager()
	if manager != null and manager.is_registered(node_id):
		return manager.data_of(node_id)
	if manager != null:
		return manager.data_for_kind(kind)
	return Database.gather_kind(kind) as GatherNodeData if kind != &"" else null


func _manager() -> GatherManager:
	return get_tree().get_first_node_in_group(MANAGER_GROUP) as GatherManager if is_inside_tree() else null


func _expansion() -> ExpansionManager:
	return get_tree().get_first_node_in_group(EXPANSION_GROUP) as ExpansionManager if is_inside_tree() else null


static func _tier(player: Player, data: GatherNodeData) -> int:
	if player == null or data == null or data.tool_kind == &"":
		return 0
	return player.tool_tier(data.tool_kind)


static func _actions(player: Player) -> ActionConfig:
	if player != null and player.actions != null:
		return player.actions
	var cfg := Database.config(&"action_config") as ActionConfig
	return cfg if cfg != null else ActionConfig.new()


static func _item_name(id: StringName) -> String:
	var item := Database.item(id) as ItemData if Database.has_item(id) else null
	return item.display_name if item != null and item.display_name != "" else String(id)


static func _is_carrying(player: Player) -> bool:
	return is_instance_valid(player.carried)
