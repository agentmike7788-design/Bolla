class_name UIRoot
extends CanvasLayer
## Owns HUD, panels, dialogue box, pause menu (group ui_root, PROCESS_MODE_ALWAYS).
## Opens panels on EventBus.ui_panel_requested and the dialogue on dialogue_requested,
## each registered in UIState (modal id = panel id, &"dialogue"). Input: Esc (pause)
## closes the topmost panel/dialogue, else opens the pause menu (which also pauses the
## SceneTree); I toggles the inventory; E is swallowed while anything is open.
## Finds the player (group "player") on world_ready and hands it to the HUD.

const GROUP := &"ui_root"
const PLAYER_GROUP := &"player"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PANEL_PAUSE := &"pause"
const PANEL_INVENTORY := &"inventory"
const DEBUG_MODAL := &"debug"
const ACTION_TITLE := &"title"
const ACTION_QUIT := &"quit"
## Panel id -> script (docs §7 contexts; chest and grave_register: docs §11).
const PANEL_SCRIPTS: Dictionary[StringName, Script] = {
	&"inventory": preload("res://src/ui/panels/inventory_panel.gd"),
	&"corpse_exam": preload("res://src/ui/panels/corpse_exam_panel.gd"),
	&"crafting": preload("res://src/ui/panels/crafting_panel.gd"),
	&"marker_choice": preload("res://src/ui/panels/marker_choice_panel.gd"),
	&"day_summary": preload("res://src/ui/panels/day_summary_panel.gd"),
	&"slice_summary": preload("res://src/ui/panels/slice_summary_panel.gd"),
	&"pause": preload("res://src/ui/panels/pause_menu.gd"),
	&"chest": preload("res://src/ui/panels/chest_panel.gd"),
	&"grave_register": preload("res://src/ui/panels/grave_register_panel.gd"),
}

## Called for "Beenden" (tests replace it).
var quit_handler: Callable = _quit_game
## Current player (duck-typed: inventory, is_busy()); null without a world.
var player: Node

@onready var root_control: Control = $Root
@onready var hud: GameHud = $Root/HUD
@onready var dim: Panel = $Root/Dim
@onready var panel_layer: Control = $Root/Panels
@onready var dialogue_box: DialogueBox = $Root/DialogueBox
@onready var notifications: NotificationStack = $Root/Overlay/Notifications
@onready var reward_card: RewardCard = $Root/Overlay/RewardCard
## Black portal fade over everything (created in _ready, docs §11).
var screen_fade: ScreenFade

## Open UI, bottom → top: panel ids and &"dialogue".
var _stack: Array[StringName] = []
var _panels: Dictionary[StringName, UIPanel] = {}
## True while this node holds the SceneTree pause (pause menu).
var _paused_tree: bool = false
## Set while UIState.clear() tears everything down, so no pop_modal is sent back.
var _syncing: bool = false


func _init() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	EventBus.ui_panel_requested.connect(open_panel)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.game_loaded.connect(_on_game_refresh.unbind(1))
	EventBus.new_game_started.connect(_on_game_refresh)
	EventBus.ui_modal_changed.connect(_on_ui_modal_changed)
	dialogue_box.closed.connect(_on_dialogue_closed)
	screen_fade = ScreenFade.new()
	root_control.add_child(screen_fade)
	_bind_player(get_tree().get_first_node_in_group(PLAYER_GROUP))
	_update_dim()


func _exit_tree() -> void:
	# A world being replaced (load / new game) leaves the tree before it is freed; stop
	# listening so the old UI never reacts to the next world's signals.
	for sig: Signal in [EventBus.ui_panel_requested, EventBus.dialogue_requested, EventBus.world_ready,
			EventBus.game_loaded, EventBus.new_game_started, EventBus.ui_modal_changed]:
		for c: Dictionary in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)
	var open_now := _stack.duplicate()
	_stack.clear()
	for id: StringName in open_now:
		UIState.pop_modal(id)
	if dialogue_box.is_active():
		dialogue_box.abort()
	_release_tree_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	if UIState.top() == DEBUG_MODAL or SaveManager.is_loading:
		return
	if event.is_action_pressed(&"pause"):
		_consume()
		if _stack.is_empty():
			open_panel(PANEL_PAUSE, {})
		else:
			close_top_panel()
	elif event.is_action_pressed(&"inventory"):
		_consume()
		toggle_inventory()
	elif top() == DialogueBox.MODAL_ID and dialogue_box.handle_choice_input(event):
		_consume()
	elif not _stack.is_empty() and event.is_action_pressed(&"interact"):
		_consume()


## Opens (or refreshes, if already open) a panel of docs §7 with its context.
func open_panel(panel: StringName, context: Dictionary) -> void:
	if not PANEL_SCRIPTS.has(panel):
		push_warning("[UIRoot] unknown panel '%s'" % panel)
		return
	var node := _panel(panel)
	if top() != panel:
		if panel in _stack:
			_stack.erase(panel)
			UIState.pop_modal(panel)
		_stack.append(panel)
		UIState.push_modal(panel)
	if panel == PANEL_PAUSE:
		_hold_tree_pause()
	node.open(context)
	_update_visibility()


## Closes the topmost panel or dialogue (no-op when nothing is open).
func close_top_panel() -> void:
	if _stack.is_empty():
		return
	var id: StringName = _stack.back()
	if id == DialogueBox.MODAL_ID:
		dialogue_box.end_dialogue()
	else:
		close_panel(id)


## Closes one panel wherever it is in the stack (idempotent).
func close_panel(panel: StringName) -> void:
	if not panel in _stack or panel == DialogueBox.MODAL_ID:
		return
	_stack.erase(panel)
	if _panels.has(panel):
		_panels[panel].close()
	if not _syncing:
		UIState.pop_modal(panel)
	if panel == PANEL_PAUSE:
		_release_tree_pause()
	_update_visibility()


## I: opens the inventory when nothing is open, closes it when it is on top.
func toggle_inventory() -> void:
	if top() == PANEL_INVENTORY:
		close_panel(PANEL_INVENTORY)
	elif _stack.is_empty():
		var inv: Variant = player.get(&"inventory") if is_instance_valid(player) else null
		if inv is Inventory:
			open_panel(PANEL_INVENTORY, {"inventory": inv})


## Starts a dialogue with the player's inventory in the context.
func open_dialogue(dialogue_id: StringName, speaker: Node) -> void:
	var inv: Variant = player.get(&"inventory") if is_instance_valid(player) else null
	if dialogue_box.start(dialogue_id, speaker, inv as Object):
		_stack.append(DialogueBox.MODAL_ID)
		_update_visibility()


func top() -> StringName:
	return _stack.back() if not _stack.is_empty() else &""


func is_open(id: StringName) -> bool:
	return id in _stack


func open_ids() -> Array[StringName]:
	return _stack.duplicate()


func get_panel(panel: StringName) -> UIPanel:
	return _panel(panel) if PANEL_SCRIPTS.has(panel) else null


## Closes every panel and the dialogue (and lifts the pause menu's tree pause).
func close_all() -> void:
	for id: StringName in _stack.duplicate():
		if id == DialogueBox.MODAL_ID:
			dialogue_box.end_dialogue()
		else:
			close_panel(id)
	_stack.clear()
	_release_tree_pause()
	_update_visibility()


## Leaves the world: closes everything, stops the clock and shows the title screen.
func go_to_title() -> void:
	close_all()
	TimeManager.clear_pauses()
	TimeManager.running = false
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- internals ------------------------------------------------------------------------------

func _panel(id: StringName) -> UIPanel:
	if _panels.has(id):
		return _panels[id]
	var node := (PANEL_SCRIPTS[id] as GDScript).new() as UIPanel
	node.name = String(id).to_pascal_case()
	node.panel_id = id
	node.close_requested.connect(close_panel.bind(id))
	node.action_requested.connect(_on_panel_action)
	panel_layer.add_child(UIKit.centered(node))
	_panels[id] = node
	return node


## Only the topmost panel is visible; the dim covers the world behind panels.
func _update_visibility() -> void:
	var top_panel := &""
	for i: int in range(_stack.size() - 1, -1, -1):
		if _stack[i] != DialogueBox.MODAL_ID:
			top_panel = _stack[i]
			break
	for id: StringName in _panels:
		var show_it := id == top_panel and top() == top_panel
		_panels[id].get_parent().visible = show_it
		_panels[id].visible = show_it and _panels[id].is_open
	dialogue_box.visible = dialogue_box.is_active() and top() == DialogueBox.MODAL_ID
	_update_dim()
	if top_panel != &"" and top() == top_panel:
		_panels[top_panel].focus_default()


func _update_dim() -> void:
	dim.visible = not _stack.is_empty() and top() != DialogueBox.MODAL_ID


func _hold_tree_pause() -> void:
	_paused_tree = true
	get_tree().paused = true


func _release_tree_pause() -> void:
	if _paused_tree and is_inside_tree():
		get_tree().paused = false
	_paused_tree = false


func _bind_player(node: Node) -> void:
	player = node
	hud.bind_player(node)


func _consume() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _quit_game() -> void:
	get_tree().quit()


func _on_panel_action(action: StringName) -> void:
	match action:
		ACTION_TITLE:
			go_to_title()
		ACTION_QUIT:
			quit_handler.call()


func _on_dialogue_requested(dialogue_id: StringName, speaker: Node) -> void:
	open_dialogue(dialogue_id, speaker)


func _on_dialogue_closed(_dialogue_id: StringName) -> void:
	_stack.erase(DialogueBox.MODAL_ID)
	_update_visibility()


func _on_world_ready(_world: Node) -> void:
	if not is_inside_tree():
		return
	_bind_player(get_tree().get_first_node_in_group(PLAYER_GROUP))
	hud.refresh_all()


func _on_game_refresh() -> void:
	if not is_inside_tree():
		return
	_bind_player(get_tree().get_first_node_in_group(PLAYER_GROUP))
	hud.refresh_all()


## UIState.clear() (loading, new game) closed every modal: follow without popping again.
func _on_ui_modal_changed(open: bool) -> void:
	if open or _stack.is_empty() or UIState.is_modal():
		return
	_syncing = true
	for id: StringName in _stack.duplicate():
		if id == DialogueBox.MODAL_ID:
			dialogue_box.abort()
		else:
			close_panel(id)
	_stack.clear()
	_syncing = false
	_release_tree_pause()
	_update_visibility()
