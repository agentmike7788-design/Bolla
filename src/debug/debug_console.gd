class_name DebugConsole
extends CanvasLayer
## Autoload "Debug" (docs §6): F1 (debug_toggle) opens a console – only while
## GameConfig.debug_enabled. While open it is modal (UIState &"debug"), so the player gets
## no input. Command line + output log + quick buttons; execute(line) runs one command and
## returns {ok: bool, text: String}. Works without a world: commands that need one say so.
## Commands: time HH:MM · day +N · pause · give <item> [n] · spawn corpse · npc carter here ·
## tp <gate|hut|road|workbench|table> · save [slot] · load [slot] · camera ortho|persp ·
## flags · flags clear · quality · fps · instant on|off · clear · help
## The command table lives in DebugCommands (+ DebugCommandParser, DebugWorldLookup); this
## script is the console UI, log and history.

const MODAL_ID := &"debug"
const TIME_PAUSE := DebugCommands.TIME_PAUSE
const DEFAULT_SLOT := DebugCommands.DEFAULT_SLOT
const MAX_DAYS := DebugCommands.MAX_DAYS
const MAX_GIVE := DebugCommands.MAX_GIVE
const HISTORY_SIZE := 30
const PLAYER_GROUP := DebugWorldLookup.PLAYER_GROUP
const CORPSE_MANAGER_GROUP := DebugWorldLookup.CORPSE_MANAGER_GROUP
const GRAVEYARD_GROUP := DebugWorldLookup.GRAVEYARD_GROUP
const DROPOFF_GROUP := DebugWorldLookup.DROPOFF_GROUP
const NPC_GROUP := DebugWorldLookup.NPC_GROUP
## Metres from an entity (toward the camera, +Z) where "tp" puts the player.
const TP_ENTITY_OFFSET := DebugCommands.TP_ENTITY_OFFSET
## Metres in front of the player where "npc … here" places the NPC / next to the NPC for the player.
const NPC_OFFSET := DebugCommands.NPC_OFFSET
## tp target -> [kind, id]: kind "layout" (WorldRoot.get_node_by_layout_id) or "waypoint".
const TP_TARGETS: Dictionary[String, Array] = DebugCommands.TP_TARGETS
## [button text, command]
const QUICK_COMMANDS: Array[Array] = [
	["07:30", "time 07:30"], ["12:00", "time 12:00"], ["18:00", "time 18:00"], ["+1 Tag", "day +1"],
	["Pause", "pause"], ["Leiche", "spawn corpse"], ["Kutscher", "npc carter here"],
	["+Holz", "give wood 5"], ["+Stein", "give stone 5"], ["+Leinen", "give linen 2"],
	["Instant", "instant"], ["Speichern", "save"], ["Laden", "load"], ["Kamera", "camera"],
	["Flags", "flags"], ["Qualität", "quality"], ["FPS", "fps"], ["Hilfe", "help"],
]
const HELP := DebugCommands.HELP
const TEXT_NO_WORLD := DebugCommands.TEXT_NO_WORLD
const TEXT_UNKNOWN := DebugCommands.TEXT_UNKNOWN
const COLOR_COMMAND := "f2a93b"
const COLOR_OK := "e8dcc0"
const COLOR_ERROR := "db7566"

var root_control: Control
var panel: PanelContainer
var log_label: RichTextLabel
var input: LineEdit
var fps_panel: PanelContainer
var fps_label: Label

var _open: bool = false
var _history: PackedStringArray = []
var _history_index: int = -1
var _commands := DebugCommands.new(self)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)
	EventBus.ui_modal_changed.connect(_on_ui_modal_changed)
	EventBus.new_game_started.connect(_on_time_reset)
	EventBus.game_loaded.connect(_on_time_reset.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		get_viewport().set_input_as_handled()
		toggle()
	elif _open and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if fps_panel.visible:
		fps_label.text = "FPS %d · Draw %d" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


## Opens the console; false while debugging is disabled.
func open() -> bool:
	if not GameConfig.debug_enabled:
		return false
	if _open:
		return true
	_open = true
	UIState.push_modal(MODAL_ID)
	panel.visible = true
	input.grab_focus()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	panel.visible = false
	input.release_focus()
	UIState.pop_modal(MODAL_ID)


## Back to the startup state (tests): closed, no FPS overlay, clock pause lifted, log empty.
func reset() -> void:
	close()
	fps_panel.visible = false
	_commands.release_pause()
	log_label.clear()
	_history.clear()
	_history_index = -1


## Runs one command line and logs it. Returns {ok: bool, text: String}.
func execute(line: String) -> Dictionary:
	var text := line.strip_edges()
	if text == "":
		return DebugCommands.result(false, "")
	_log_line("> " + text, COLOR_COMMAND)
	var parts := text.split(" ", false)
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	if command == "clear" and args.is_empty():
		log_label.clear()
		return DebugCommands.result(true, "")
	var result := _commands.run(command, args)
	_log_line(result.text, COLOR_OK if result.ok else COLOR_ERROR)
	return result


func log_text() -> String:
	return log_label.get_parsed_text()


## "HH:MM" / "H:MM" → minute of day, -1 when invalid.
static func parse_clock(text: String) -> int:
	return DebugCommandParser.parse_clock(text)


func _log_line(text: String, color: String) -> void:
	if text == "":
		return
	log_label.append_text("[color=#%s]%s[/color]\n" % [color, text.replace("[", "[lb]")])


# --- UI ---------------------------------------------------------------------------------------

func _build() -> void:
	root_control = Control.new()
	root_control.name = "Root"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = UIKit.theme()
	add_child(root_control)
	panel = UIKit.panel(&"DebugPanel")
	panel.name = "Console"
	panel.anchor_right = 1.0
	panel.offset_bottom = 0.0
	panel.visible = false
	root_control.add_child(panel)
	var box := UIKit.vbox(10)
	panel.add_child(box)
	var head := UIKit.hbox()
	var title := UIKit.label("Debug-Konsole", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.label("[F1] / [Esc] schließen · 'help' zeigt alle Befehle", &"DimLabel"))
	box.add_child(head)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.selection_enabled = true
	log_label.custom_minimum_size.y = 330.0
	log_label.focus_mode = Control.FOCUS_NONE
	box.add_child(log_label)
	var quick := HFlowContainer.new()
	quick.add_theme_constant_override(&"h_separation", 8)
	quick.add_theme_constant_override(&"v_separation", 8)
	for entry: Array in QUICK_COMMANDS:
		var button := UIKit.button(str(entry[0]))
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(entry[1])
		button.pressed.connect(_on_quick_pressed.bind(str(entry[1])))
		quick.add_child(button)
	box.add_child(quick)
	input = LineEdit.new()
	input.placeholder_text = "Befehl eingeben – z. B. time 07:30, give wood 5, tp table"
	input.text_submitted.connect(_on_submitted)
	input.gui_input.connect(_on_input_gui)
	box.add_child(input)
	fps_panel = UIKit.panel(&"HudPanel")
	fps_panel.name = "Fps"
	fps_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	fps_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fps_panel.offset_left = 28.0
	fps_panel.offset_bottom = -28.0
	fps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_panel.visible = false
	fps_label = UIKit.label("", &"HudLabel")
	fps_panel.add_child(fps_label)
	root_control.add_child(fps_panel)


func _on_submitted(text: String) -> void:
	input.clear()
	if text.strip_edges() == "":
		return
	_history.append(text)
	if _history.size() > HISTORY_SIZE:
		_history.remove_at(0)
	_history_index = -1
	execute(text)


func _on_quick_pressed(command: String) -> void:
	execute(command)
	if _open:
		input.grab_focus()


func _on_input_gui(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _history.is_empty():
		return
	if key.keycode == KEY_UP:
		_history_index = _history.size() - 1 if _history_index < 0 else maxi(_history_index - 1, 0)
	elif key.keycode == KEY_DOWN and _history_index >= 0:
		_history_index += 1
		if _history_index >= _history.size():
			_history_index = -1
	else:
		return
	input.text = _history[_history_index] if _history_index >= 0 else ""
	input.caret_column = input.text.length()
	input.accept_event()


func _on_debug_mode_changed(enabled: bool) -> void:
	if not enabled:
		close()


## UIState.clear() (loading / new game) dropped the modal: follow it.
func _on_ui_modal_changed(open_now: bool) -> void:
	if not open_now and _open and not UIState.is_open(MODAL_ID):
		_open = false
		panel.visible = false


func _on_time_reset() -> void:
	_commands.time_paused = false
