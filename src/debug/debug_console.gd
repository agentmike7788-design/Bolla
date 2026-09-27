class_name DebugConsole
extends CanvasLayer
## Autoload "Debug" (docs §6): F1 (debug_toggle) opens a console – only while
## GameConfig.debug_enabled. While open it is modal (UIState &"debug"), so the player gets
## no input. Command line + output log + quick buttons; execute(line) runs one command and
## returns {ok: bool, text: String}. Works without a world: commands that need one say so.
## Commands: time HH:MM · day +N · pause · give <item> [n] · spawn corpse · npc carter here ·
## tp <gate|hut|road|workbench|table> · save [slot] · load [slot] · camera ortho|persp ·
## flags · flags clear · quality · fps · instant on|off · clear · help

const MODAL_ID := &"debug"
const TIME_PAUSE := &"debug"
const DEFAULT_SLOT := 1
const MAX_DAYS := 30
const MAX_GIVE := 999
const HISTORY_SIZE := 30
const PLAYER_GROUP := &"player"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const DROPOFF_GROUP := &"dropoff"
const NPC_GROUP := &"npc"
## Metres from an entity (toward the camera, +Z) where "tp" puts the player.
const TP_ENTITY_OFFSET := Vector3(0.0, 0.0, 1.4)
## Metres in front of the player where "npc … here" places the NPC / next to the NPC for the player.
const NPC_OFFSET := 1.6
## tp target -> [kind, id]: kind "layout" (WorldRoot.get_node_by_layout_id) or "waypoint".
const TP_TARGETS: Dictionary[String, Array] = {
	"gate": ["layout", "dropoff"],
	"hut": ["layout", "hut_door"],
	"road": ["waypoint", "road_mid"],
	"workbench": ["layout", "workbench"],
	"table": ["layout", "morgue_table"],
}
## [button text, command]
const QUICK_COMMANDS: Array[Array] = [
	["07:30", "time 07:30"], ["12:00", "time 12:00"], ["18:00", "time 18:00"], ["+1 Tag", "day +1"],
	["Pause", "pause"], ["Leiche", "spawn corpse"], ["Kutscher", "npc carter here"],
	["+Holz", "give wood 5"], ["+Stein", "give stone 5"], ["+Leinen", "give linen 2"],
	["Instant", "instant"], ["Speichern", "save"], ["Laden", "load"], ["Kamera", "camera"],
	["Flags", "flags"], ["Qualität", "quality"], ["FPS", "fps"], ["Hilfe", "help"],
]
const HELP := [
	"time HH:MM – Uhrzeit setzen (früher als jetzt = nächster Tag)",
	"day +N – N Tage vorspulen (Standard 1)",
	"pause – Spielzeit anhalten / weiterlaufen lassen",
	"give <item> [n] – Item ins Inventar (%s)",
	"spawn corpse – Leiche an der Bahre, sonst neben dir",
	"npc carter here – Kutscher herholen; ist er nicht da: Zeit bis zu seinem Auftritt vorspulen",
	"tp <gate|hut|road|workbench|table> – teleportieren",
	"save [slot] / load [slot] – speichern / laden (Standard: Slot 1)",
	"camera ortho|persp – Kameraprojektion (ohne Argument umschalten)",
	"flags · flags clear – Flags & Statistik zeigen / Flags löschen (Quest zurücksetzen)",
	"quality – Friedhofsqualität und alle Gräber",
	"fps – FPS-Anzeige an/aus",
	"instant on|off – Aktionen sofort fertig (Spielzeit läuft trotzdem)",
	"clear – Ausgabe leeren · help – diese Hilfe",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const TEXT_UNKNOWN := "Unbekannter Befehl '%s' – 'help' zeigt alle Befehle."
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
var _time_paused: bool = false
var _history: PackedStringArray = []
var _history_index: int = -1


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
	if _time_paused:
		TimeManager.pop_pause(TIME_PAUSE)
	_time_paused = false
	log_label.clear()
	_history.clear()
	_history_index = -1


## Runs one command line and logs it. Returns {ok: bool, text: String}.
func execute(line: String) -> Dictionary:
	var text := line.strip_edges()
	if text == "":
		return _result(false, "")
	_log_line("> " + text, COLOR_COMMAND)
	var parts := text.split(" ", false)
	var command := parts[0].to_lower()
	var args := parts.slice(1)
	var result: Dictionary
	match command:
		"help", "?":
			result = _ok("\n".join(_help_lines()))
		"time":
			result = _cmd_time(args)
		"day":
			result = _cmd_day(args)
		"pause":
			result = _cmd_pause(args)
		"give":
			result = _cmd_give(args)
		"spawn":
			result = _cmd_spawn(args)
		"npc":
			result = _cmd_npc(args)
		"tp":
			result = _cmd_tp(args)
		"save":
			result = _cmd_save(args)
		"load":
			result = _cmd_load(args)
		"camera":
			result = _cmd_camera(args)
		"flags":
			result = _cmd_flags(args)
		"quality":
			result = _cmd_quality(args)
		"fps":
			result = _cmd_fps(args)
		"instant":
			result = _cmd_instant(args)
		"clear":
			log_label.clear()
			return _ok("")
		_:
			result = _error(TEXT_UNKNOWN % command)
	_log_line(result.text, COLOR_OK if result.ok else COLOR_ERROR)
	return result


func log_text() -> String:
	return log_label.get_parsed_text()


# --- commands -------------------------------------------------------------------------------

func _cmd_time(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: time HH:MM (z. B. time 07:30)")
	var minute := parse_clock(args[0])
	if minute < 0:
		return _error("Ungültige Uhrzeit '%s' – erlaubt sind 00:00 bis 23:59." % args[0])
	var before := TimeManager.total_minutes()
	TimeManager.set_time(TimeManager.day, minute)
	return _ok("Zeit: Tag %d, %s (+%d Min)" % [TimeManager.day, TimeManager.format_clock(), TimeManager.total_minutes() - before])


func _cmd_day(args: PackedStringArray) -> Dictionary:
	var days := 1
	if args.size() > 1:
		return _error("Format: day +N (z. B. day +1)")
	if args.size() == 1:
		var raw := args[0].trim_prefix("+")
		if not raw.is_valid_int() or raw.to_int() < 1 or raw.to_int() > MAX_DAYS:
			return _error("Ungültige Anzahl '%s' – erlaubt: +1 bis +%d." % [args[0], MAX_DAYS])
		days = raw.to_int()
	TimeManager.advance(days * TimeManager.MINUTES_PER_DAY)
	return _ok("Tag %d, %s (+%d Tag%s)" % [TimeManager.day, TimeManager.format_clock(), days, "" if days == 1 else "e"])


func _cmd_pause(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: pause (ohne Argument)")
	_time_paused = not _time_paused
	if _time_paused:
		TimeManager.push_pause(TIME_PAUSE)
		return _ok("Spielzeit angehalten (nochmal 'pause' zum Fortsetzen).")
	TimeManager.pop_pause(TIME_PAUSE)
	return _ok("Spielzeit läuft wieder.")


func _cmd_give(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2:
		return _error("Format: give <item> [n] – Items: %s" % _item_ids())
	var id := StringName(args[0].to_lower())
	if not Database.has_item(id):
		return _error("Unbekanntes Item '%s' – Items: %s" % [args[0], _item_ids()])
	var amount := 1
	if args.size() == 2:
		if not args[1].is_valid_int() or args[1].to_int() < 1 or args[1].to_int() > MAX_GIVE:
			return _error("Ungültige Menge '%s' – erlaubt: 1 bis %d." % [args[1], MAX_GIVE])
		amount = args[1].to_int()
	var inv := _inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	var rest := inv.add_item(id, amount)
	if rest >= amount:
		return _error("Kein Platz im Inventar für %s." % UIKit.item_name(id))
	var text := "Gegeben: %d× %s" % [amount - rest, UIKit.item_name(id)]
	if rest > 0:
		text += " (kein Platz für %d)" % rest
	return _ok(text)


func _cmd_spawn(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "corpse":
		return _error("Format: spawn corpse")
	var manager := _group_node(CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"spawn_corpse"):
		return _error(TEXT_NO_WORLD)
	var at := Transform3D()
	var location := &"dropoff"
	var where := "an der Bahre"
	var dropoff := _group_node(DROPOFF_GROUP)
	if dropoff != null and dropoff.has_method(&"is_free") and bool(dropoff.call(&"is_free")) and dropoff.has_method(&"slot_transform"):
		at = dropoff.call(&"slot_transform")
	else:
		var p := _player()
		if p == null or not p.has_method(&"drop_position"):
			return _error("Die Bahre ist belegt und es gibt keinen Spieler.")
		at = p.call(&"drop_position")
		if at == Transform3D():
			return _error("Die Bahre ist belegt und neben dir ist kein Platz.")
		location = &"ground"
		where = "neben dir"
	var record := manager.call(&"spawn_corpse", null, at, location) as CorpseRecord
	if record == null:
		return _error("Leiche konnte nicht erzeugt werden.")
	var tables := Database.corpse_tables() as CorpseTables
	var cause := str(tables.get_cause(record.cause_id).get("label", record.cause_id)) if tables != null else String(record.cause_id)
	var traits := ", ".join(Array(record.traits).map(func(t: StringName) -> String: return String(t)))
	return _ok("Leiche %s: %s (%d, %s) %s. Merkmale: %s" % [record.id, record.display_name, record.age, cause, where,
			traits if traits != "" else "keine"])


func _cmd_npc(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or args[1].to_lower() != "here":
		return _error("Format: npc <id> here (z. B. npc carter here)")
	var npc_id := StringName(args[0].to_lower())
	var schedule := Database.schedule(npc_id) as NpcSchedule
	if schedule == null:
		return _error("Unbekannter NPC '%s'." % args[0])
	var p := _player() as Node3D
	var npc := _npc_node(npc_id)
	if p == null or npc == null:
		return _error(TEXT_NO_WORLD)
	var who := schedule.display_name if schedule.display_name != "" else String(npc_id)
	var entry := ScheduleResolver.entry_at(schedule, TimeManager.minute_of_day)
	if entry != null and entry.visible:
		var forward := p.global_basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.BACK
		if npc.has_method(&"debug_teleport"):
			npc.call(&"debug_teleport", p.global_position + forward * NPC_OFFSET)
			return _ok("%s steht jetzt vor dir." % who)
		_teleport_player(p, npc.global_position + Vector3(0.0, 0.0, NPC_OFFSET))
		return _ok("%s folgt seinem Tagesplan – du stehst jetzt neben ihm." % who)
	var wait := _minutes_to_next_presence(schedule)
	if wait < 0:
		return _error("%s hat heute keinen Auftritt." % who)
	TimeManager.advance(wait)
	return _ok("%s ist gerade nicht da – Zeit auf Tag %d, %s vorgespult (+%d Min). 'npc %s here' holt dich zu ihm." % [
			who, TimeManager.day, TimeManager.format_clock(), wait, npc_id])


func _cmd_tp(args: PackedStringArray) -> Dictionary:
	var names := ", ".join(TP_TARGETS.keys())
	if args.size() != 1:
		return _error("Format: tp <%s>" % names.replace(", ", "|"))
	var target := args[0].to_lower()
	if not TP_TARGETS.has(target):
		return _error("Unbekanntes Ziel '%s' – Ziele: %s" % [args[0], names])
	var p := _player() as Node3D
	var world := _world()
	if p == null or world == null:
		return _error(TEXT_NO_WORLD)
	var spec: Array = TP_TARGETS[target]
	var pos: Vector3
	if spec[0] == "layout":
		var node := world.call(&"get_node_by_layout_id", spec[1]) as Node3D
		if node == null:
			return _error("Die Welt kennt '%s' nicht." % spec[1])
		pos = node.global_position + TP_ENTITY_OFFSET
	else:
		pos = world.call(&"get_waypoint", StringName(spec[1]))
	_teleport_player(p, pos)
	return _ok("Teleportiert: %s (%.1f, %.1f)" % [target, pos.x, pos.z])


func _cmd_save(args: PackedStringArray) -> Dictionary:
	var slot := _slot_arg(args)
	if slot < 0:
		return _error("Format: save [slot] (Slot ist eine Zahl ≥ 0)")
	if _world() == null and _player() == null:
		return _error(TEXT_NO_WORLD)
	var p := _player()
	if p != null and p.has_method(&"is_busy") and bool(p.call(&"is_busy")):
		return _error("Eine Aktion läuft – später speichern.")
	var err := SaveManager.save_game(slot)
	if err != OK:
		return _error("Speichern in Slot %d fehlgeschlagen: %s" % [slot, error_string(err)])
	return _ok("Gespeichert in Slot %d." % slot)


func _cmd_load(args: PackedStringArray) -> Dictionary:
	var slot := _slot_arg(args)
	if slot < 0:
		return _error("Format: load [slot] (Slot ist eine Zahl ≥ 0)")
	if not SaveManager.has_save(slot):
		return _error("Slot %d ist leer." % slot)
	close()
	SaveManager.load_game(slot)
	return _ok("Lade Slot %d …" % slot)


func _cmd_camera(args: PackedStringArray) -> Dictionary:
	if args.size() > 1 or (args.size() == 1 and not args[0].to_lower() in ["ortho", "persp"]):
		return _error("Format: camera ortho|persp")
	var rig := _camera_rig()
	if rig == null:
		return _error("Keine Kamera (CameraRig) in der Szene.")
	var want_ortho := not rig.orthographic if args.is_empty() else args[0].to_lower() == "ortho"
	if rig.orthographic != want_ortho:
		rig.toggle_projection()
	return _ok("Kamera: %s" % ("orthografisch" if rig.orthographic else "Perspektive"))


func _cmd_flags(args: PackedStringArray) -> Dictionary:
	if args.size() == 1 and args[0].to_lower() == "clear":
		var count := GameState.flags.size()
		GameState.clear_flags()
		return _ok("%d Flag(s) gelöscht – Quest zurückgesetzt." % count)
	if not args.is_empty():
		return _error("Format: flags | flags clear")
	var lines: PackedStringArray = ["Flags:"]
	var keys := GameState.flags.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key: Variant in keys:
		lines.append("  %s = %s" % [key, var_to_str(GameState.flags[key])])
	if keys.is_empty():
		lines.append("  (keine)")
	lines.append("Statistik:")
	var stats := GameState.stats.keys()
	stats.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key: Variant in stats:
		lines.append("  %s = %s" % [key, GameState.stats[key]])
	lines.append("Ruf: %s" % GameState.reputation_label())
	return _ok("\n".join(lines))


func _cmd_quality(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: quality (ohne Argument)")
	var graveyard := _group_node(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return _error(TEXT_NO_WORLD)
	var total := int(graveyard.call(&"total_quality"))
	var rating := StringName(graveyard.call(&"rating"))
	var lines: PackedStringArray = ["Friedhofsqualität %d · %s" % [total, CemeteryRating.label(rating)]]
	for grave: GraveRecord in graveyard.call(&"graves"):
		var state_name: String = GraveRecord.State.keys()[grave.state]
		var detail := ""
		if grave.state == GraveRecord.State.MARKED:
			detail = " Qualität %d (%s)" % [grave.quality, UIKit.item_name(grave.marker_id)]
		elif grave.corpse_id != "":
			detail = " (%s)" % grave.corpse_id
		lines.append("  %s: %s%s" % [grave.id, state_name, detail])
	return _ok("\n".join(lines))


func _cmd_fps(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: fps (ohne Argument)")
	fps_panel.visible = not fps_panel.visible
	return _ok("FPS-Anzeige %s." % ("an" if fps_panel.visible else "aus"))


func _cmd_instant(args: PackedStringArray) -> Dictionary:
	if args.size() > 1 or (args.size() == 1 and not args[0].to_lower() in ["on", "off"]):
		return _error("Format: instant on|off")
	var p := _player()
	if p == null or not (&"instant_actions" in p):
		return _error(TEXT_NO_WORLD)
	var value := not bool(p.get(&"instant_actions")) if args.is_empty() else args[0].to_lower() == "on"
	p.set(&"instant_actions", value)
	return _ok("Sofort-Aktionen %s." % ("an" if value else "aus"))


# --- parsing & helpers ------------------------------------------------------------------------

## "HH:MM" / "H:MM" → minute of day, -1 when invalid.
static func parse_clock(text: String) -> int:
	var parts := text.strip_edges().split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or parts[1].length() != 2 or parts[0].length() > 2:
		return -1
	var hour := parts[0].to_int()
	var minute := parts[1].to_int()
	if hour < 0 or hour > 23 or minute < 0 or minute > 59 or parts[0].begins_with("-") or parts[1].begins_with("-"):
		return -1
	return hour * TimeManager.MINUTES_PER_HOUR + minute


## Minutes from now until the NPC next arrives at a visible phase with a dialogue
## (any visible phase if none has one); -1 if it never shows up.
static func _minutes_to_next_presence(schedule: NpcSchedule) -> int:
	var best := -1
	for with_dialogue: bool in [true, false]:
		for entry: ScheduleEntry in schedule.entries:
			if entry == null or not entry.visible or (with_dialogue and entry.dialogue_id == &""):
				continue
			var wait := TimeManager.minutes_until(ScheduleResolver.arrival_minute(entry))
			if wait == 0:
				wait = TimeManager.MINUTES_PER_DAY
			if best < 0 or wait < best:
				best = wait
		if best >= 0:
			return best
	return best


func _help_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in HELP:
		out.append(line % _item_ids() if line.contains("%s") else line)
	return out


func _item_ids() -> String:
	var ids: PackedStringArray = []
	for item: Resource in Database.items():
		ids.append(String(item.get("id")))
	ids.sort()
	return ", ".join(ids)


func _slot_arg(args: PackedStringArray) -> int:
	if args.is_empty():
		return DEFAULT_SLOT
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0:
		return -1
	return args[0].to_int()


func _teleport_player(p: Node3D, pos: Vector3) -> void:
	p.global_position = pos
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	var rig := _camera_rig()
	if rig != null:
		rig.snap()


func _player() -> Node:
	return _group_node(PLAYER_GROUP)


func _inventory() -> Inventory:
	var p := _player()
	return p.get(&"inventory") as Inventory if p != null else null


func _group_node(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group)


## The world root: the current scene or a root child offering get_waypoint (WorldRoot API).
func _world() -> Node:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"get_waypoint") and scene.has_method(&"get_node_by_layout_id"):
		return scene
	for child: Node in get_tree().root.get_children():
		if child.has_method(&"get_waypoint") and child.has_method(&"get_node_by_layout_id"):
			return child
	return null


func _npc_node(npc_id: StringName) -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(NPC_GROUP):
		if StringName(str(node.get(&"npc_id"))) == npc_id and node is Node3D:
			return node as Node3D
	return null


func _camera_rig() -> CameraRig:
	return _find_rig(get_tree().root)


func _find_rig(node: Node) -> CameraRig:
	if node is CameraRig:
		return node as CameraRig
	for child: Node in node.get_children():
		if child == self:
			continue
		var found := _find_rig(child)
		if found != null:
			return found
	return null


func _ok(text: String) -> Dictionary:
	return _result(true, text)


func _error(text: String) -> Dictionary:
	return _result(false, text)


func _result(ok: bool, text: String) -> Dictionary:
	return {"ok": ok, "text": text}


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
	_time_paused = false
