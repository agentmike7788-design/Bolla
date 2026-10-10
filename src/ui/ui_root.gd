class_name UIRoot
extends CanvasLayer
## Owns HUD, panels, dialogue box, pause menu (group ui_root, PROCESS_MODE_ALWAYS).
## Opens panels on EventBus.ui_panel_requested and the dialogue on dialogue_requested,
## each registered in UIState (modal id = panel id, &"dialogue"). Input: Esc (pause)
## closes the topmost panel/dialogue, else opens the pause menu (which also pauses the
## SceneTree); I toggles the inventory; E is swallowed while anything is open.
## Finds the player (group "player") on world_ready and hands it to the HUD.
## Phase 3 (docs/PHASE3_DESIGN.md §7): U toggles the cemetery overview (context from
## CemeteryStatus, also opened by the grave register's button); the day summary is completed
## with stipend, reputation, dirty spots and the sections unlocked since the last summary.
## Phase 7 (docs/PHASE7_DESIGN.md §7): the village panels (shop, gift, orders, anatomist, lecture, pult,
## collection, deduction), the screen veil (above the panels, below the portal fade), the region name and
## the remark bubbles.
## Phase 8 (docs/PHASE8_DESIGN.md §7): the chalk board, the wish card, the favour and festival panels, the
## encounters' bubbles, the festival banner (below the veil) and the Phase-8 rows of the day summary and of the
## chapter panel „Wer heraufkommt".
## Phase 4 (docs/PHASE4_DESIGN.md §3.6, §7): J toggles the Merkbuch (not while building, not in a
## dialogue; context JournalManager.panel_context()), the trade panel &"trader" opens over
## Ilse's dialogue (dialogue action open_panel:trader).

const GROUP := &"ui_root"
const PLAYER_GROUP := &"player"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
const PANEL_PAUSE := &"pause"
const PANEL_INVENTORY := &"inventory"
const PANEL_OVERVIEW := &"cemetery_overview"
const PANEL_DAY_SUMMARY := &"day_summary"
const PANEL_SLICE_SUMMARY := &"slice_summary"
const PANEL_JOURNAL := &"journal"
const PANEL_MAP := &"map"
const ACTION_MAP_TOGGLE := &"map_toggle"
const JOURNAL_GROUP := &"journal"
const BUILD_MODE_GROUP := &"build_mode"
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
	&"cemetery_overview": preload("res://src/ui/panels/cemetery_overview_panel.gd"),
	&"journal": preload("res://src/ui/panels/journal_panel.gd"),
	&"trader": preload("res://src/ui/panels/trader_panel.gd"),
	# Phase 5 (docs/PHASE5_DESIGN.md §7)
	&"build_site": preload("res://src/ui/panels/build_site_panel.gd"),
	&"stone_design": preload("res://src/ui/panels/stone_design_panel.gd"),
	# Phase 6 (docs/PHASE6_DESIGN.md §7)
	&"building": preload("res://src/ui/panels/building_panel.gd"),
	&"chapel": preload("res://src/ui/panels/chapel_panel.gd"),
	&"devotion": preload("res://src/ui/panels/devotion_panel.gd"),
	# Phase 7 (docs/PHASE7_DESIGN.md §7)
	&"shop": preload("res://src/ui/panels/shop_panel.gd"),
	&"gift": preload("res://src/ui/panels/gift_panel.gd"),
	&"orders": preload("res://src/ui/panels/orders_panel.gd"),
	&"anatomist": preload("res://src/ui/panels/anatomist_panel.gd"),
	&"lecture": preload("res://src/ui/panels/lecture_panel.gd"),
	&"pult": preload("res://src/ui/panels/pult_panel.gd"),
	&"collection": preload("res://src/ui/panels/collection_panel.gd"),
	&"deduction": preload("res://src/ui/panels/deduction_panel.gd"),
	# G7 Änderungsrunde 1: the map
	&"map": preload("res://src/ui/panels/map_panel.gd"),
	# Phase 8 (docs/PHASE8_DESIGN.md §7)
	&"apprentice_board": preload("res://src/ui/panels/apprentice_board_panel.gd"),
	&"wish_card": preload("res://src/ui/panels/wish_card.gd"),
	&"favor": preload("res://src/ui/panels/favor_panel.gd"),
	&"fest": preload("res://src/ui/panels/fest_panel.gd"),
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
## Phase-3 notifications (tier changes, stipend, ghost lines).
var notices: Phase3Notices
## Phase 5: gathered / crafted / built / spent since the last day summary.
var day_log: Phase5DayLog
## Phase 7 (§7): the veil of a specimen / the lecture, the region name, the villagers' remark bubbles.
var veil: ScreenVeil
var region_label: RegionLabel
var remark_bubbles: RemarkBubbles
## Phase 8 (§7.5, §7.6): the encounters' bubbles, the festival banner, the day log of the Phase-8 rows.
var chatter_bubbles: ChatterBubbles
var fest_banner: FestBanner
var day_log8: Phase8DayLog

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
	# G7 Runde 2: a region or room change (a moment that hitches anyway) re-bakes a changed map sheet.
	EventBus.region_changed.connect(_queue_prepare_map.unbind(1))
	EventBus.interior_room_changed.connect(_queue_prepare_map.unbind(1))
	dialogue_box.closed.connect(_on_dialogue_closed)
	if hud.map_badge != null:
		hud.map_badge.pressed.connect(toggle_map)
	region_label = RegionLabel.new()
	root_control.add_child(region_label)
	veil = ScreenVeil.new()
	root_control.add_child(veil)
	screen_fade = ScreenFade.new()
	root_control.add_child(screen_fade)
	remark_bubbles = RemarkBubbles.new()
	add_child(remark_bubbles)
	chatter_bubbles = ChatterBubbles.new()
	add_child(chatter_bubbles)
	fest_banner = FestBanner.new()
	root_control.add_child(fest_banner)
	root_control.move_child(fest_banner, veil.get_index())
	day_log8 = Phase8DayLog.new()
	add_child(day_log8)
	notices = Phase3Notices.new()
	notices.name = "Phase3Notices"
	add_child(notices)
	day_log = Phase5DayLog.new()
	day_log.name = "Phase5DayLog"
	add_child(day_log)
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
	elif event.is_action_pressed(PANEL_OVERVIEW):
		_consume()
		toggle_overview()
	elif event.is_action_pressed(PANEL_JOURNAL):
		_consume()
		toggle_journal()
	elif InputMap.has_action(ACTION_MAP_TOGGLE) and event.is_action_pressed(ACTION_MAP_TOGGLE):
		_consume()
		toggle_map()
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
	if panel == PANEL_DAY_SUMMARY:
		context = DaySummaryPanel.complete_context(context, get_tree() if is_inside_tree() else null, notices.take_unlocked() if notices != null else [] as Array[StringName])
		if day_log != null:
			context = DaySummaryPanel.complete_phase5(context, day_log.take())
		if day_log8 != null:
			context = DaySummaryPanel.complete_phase8(context, day_log8.take(get_tree() if is_inside_tree() else null))
	if panel == PANEL_SLICE_SUMMARY and StringName(str(context.get("variant", ""))) == Phase8Texts.CHAPTER_ID:
		context = SliceSummaryPanel.complete_who_comes_up(context, get_tree() if is_inside_tree() else null)
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


## U: opens the cemetery overview when nothing is open, closes it when it is on top.
func toggle_overview() -> void:
	if top() == PANEL_OVERVIEW:
		close_panel(PANEL_OVERVIEW)
	elif _stack.is_empty():
		open_overview()


## J: opens the Merkbuch when nothing is open (not in build mode), closes it when on top.
func toggle_journal() -> void:
	if top() == PANEL_JOURNAL:
		close_panel(PANEL_JOURNAL)
	elif _stack.is_empty() and not _build_mode_active():
		open_journal()


## Opens the Merkbuch on `page` (JournalManager.panel_context); no-op without a journal node.
func open_journal(page: StringName = &"people") -> void:
	var journal := get_tree().get_first_node_in_group(JOURNAL_GROUP) if is_inside_tree() else null
	if journal == null or not journal.has_method(&"panel_context"):
		return
	var ctx: Dictionary = journal.call(&"panel_context", page)
	# The Phase-7/8 tabs (Aufträge, Hollerbrück, Angehörige) are the panel's own: JournalManager knows only its four.
	ctx["page"] = page
	open_panel(PANEL_JOURNAL, ctx)


## M: opens the map when nothing is open (not in build mode), closes it when on top.
func toggle_map() -> void:
	if top() == PANEL_MAP:
		close_panel(PANEL_MAP)
	elif _stack.is_empty() and not _build_mode_active():
		open_map()


## Opens the map with a fresh snapshot (MapState.context) – on the sheet of `region` if given.
func open_map(region: StringName = &"") -> void:
	var ctx := MapState.context(get_tree() if is_inside_tree() else null, MapPanel.map_config())
	if region != &"":
		ctx["region_override"] = region
	open_panel(PANEL_MAP, ctx)


func _build_mode_active() -> bool:
	var mode := get_tree().get_first_node_in_group(BUILD_MODE_GROUP) if is_inside_tree() else null
	return mode != null and mode.get(&"active") == true


## Opens the overview with a fresh snapshot of the systems (also on top of the register).
func open_overview() -> void:
	open_panel(PANEL_OVERVIEW, CemeteryStatus.overview_context(get_tree() if is_inside_tree() else null))


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
		PANEL_OVERVIEW:
			open_overview()
		PANEL_MAP:
			# From the pause menu: the map replaces it (the tree pause ends, the modal pause holds).
			close_panel(PANEL_PAUSE)
			open_map()


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
	prepare_map.call_deferred()


func _queue_prepare_map() -> void:
	prepare_map.call_deferred()


## Bakes the map sheets while the world is still loading (G7 Runde 2: no stutter on the first M).
func prepare_map() -> void:
	if not is_inside_tree() or is_open(PANEL_MAP):
		return
	var panel := _panel(PANEL_MAP) as MapPanel
	panel.prepare(MapState.context(get_tree(), MapPanel.map_config()))


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
