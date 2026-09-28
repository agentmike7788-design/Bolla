class_name DebugCommands
extends RefCounted
## Command table of the debug console (DebugConsole / autoload "Debug", docs §6): dispatches
## one parsed command to its handler and returns {ok: bool, text: String}. The console keeps
## the UI, the log and the history; scene lookups live in DebugWorldLookup, argument parsing
## in DebugCommandParser. Owns the debug clock pause ("pause").

const TIME_PAUSE := &"debug"
const DEFAULT_SLOT := 1
const MAX_DAYS := 30
const MAX_GIVE := 999
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
const HELP := [
	"time HH:MM – Uhrzeit setzen (früher als jetzt = nächster Tag)",
	"day +N – N Tage vorspulen (Standard 1)",
	"pause – Spielzeit anhalten / weiterlaufen lassen",
	"give <item> [n] – Item ins Inventar (%s)",
	"spawn corpse – Leiche an der Bahre, sonst neben dir",
	"npc carter here – Kutscher herholen; ist er nicht da: Zeit bis zu seinem Auftritt vorspulen",
	"tp <gate|hut|road|workbench|table|east|north|elder|trader> – teleportieren",
	"save [slot] / load [slot] – speichern / laden (Standard: Slot 1)",
	"camera ortho|persp – Kameraprojektion (ohne Argument umschalten)",
	"flags · flags clear – Flags & Statistik zeigen / Flags löschen (Quest zurücksetzen)",
	"quality – Friedhofsqualität (Gräber, Zier, Pflege, Ruf) und alle Gräber",
	"fps – FPS-Anzeige an/aus",
	"instant on|off – Aktionen sofort fertig (Spielzeit läuft trotzdem)",
	"clear – Ausgabe leeren · help – diese Hilfe",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const TEXT_UNKNOWN := "Unbekannter Befehl '%s' – 'help' zeigt alle Befehle."

## True while "pause" holds the clock (TIME_PAUSE pushed on TimeManager).
var time_paused: bool = false

var _console: DebugConsole
var _lookup: DebugWorldLookup
## Phase-3 commands (§6 of docs/PHASE3_DESIGN.md).
var _phase3: DebugCommandsPhase3
## Phase-4 commands (§6 of docs/PHASE4_DESIGN.md).
var _phase4: DebugCommandsPhase4


func _init(console: DebugConsole) -> void:
	_console = console
	_lookup = DebugWorldLookup.new(console)
	_phase3 = DebugCommandsPhase3.new(_lookup)
	_phase4 = DebugCommandsPhase4.new(_lookup)


## Runs one command (lower-case name + arguments; "clear" is handled by the console).
func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"help", "?":
			return _ok("\n".join(help_lines()))
		"time":
			return _cmd_time(args)
		"day":
			return _cmd_day(args)
		"pause":
			return _cmd_pause(args)
		"give":
			return _cmd_give(args)
		"spawn":
			return _cmd_spawn(args)
		"npc":
			return _cmd_npc(args)
		"tp":
			return _cmd_tp(args)
		"save":
			return _cmd_save(args)
		"load":
			return _cmd_load(args)
		"camera":
			return _cmd_camera(args)
		"flags":
			return _cmd_flags(args)
		"quality":
			return _cmd_quality(args)
		"fps":
			return _cmd_fps(args)
		"instant":
			return _cmd_instant(args)
	if _phase3.handles(command):
		return _phase3.run(command, args)
	if _phase4.handles(command):
		return _phase4.run(command, args)
	return _error(TEXT_UNKNOWN % command)


## Lifts the "pause" clock hold, if any.
func release_pause() -> void:
	if time_paused:
		TimeManager.pop_pause(TIME_PAUSE)
	time_paused = false


func help_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in HELP:
		out.append(line % DebugCommandParser.item_ids() if line.contains("%s") else line)
	out.append_array(DebugCommandsPhase3.HELP)
	out.append_array(DebugCommandsPhase4.HELP)
	return out


static func result(ok: bool, text: String) -> Dictionary:
	return {"ok": ok, "text": text}


# --- commands -------------------------------------------------------------------------------

func _cmd_time(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: time HH:MM (z. B. time 07:30)")
	var minute := DebugCommandParser.parse_clock(args[0])
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
	time_paused = not time_paused
	if time_paused:
		TimeManager.push_pause(TIME_PAUSE)
		return _ok("Spielzeit angehalten (nochmal 'pause' zum Fortsetzen).")
	TimeManager.pop_pause(TIME_PAUSE)
	return _ok("Spielzeit läuft wieder.")


func _cmd_give(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2:
		return _error("Format: give <item> [n] – Items: %s" % DebugCommandParser.item_ids())
	var id := StringName(args[0].to_lower())
	if not Database.has_item(id):
		return _error("Unbekanntes Item '%s' – Items: %s" % [args[0], DebugCommandParser.item_ids()])
	var amount := 1
	if args.size() == 2:
		if not args[1].is_valid_int() or args[1].to_int() < 1 or args[1].to_int() > MAX_GIVE:
			return _error("Ungültige Menge '%s' – erlaubt: 1 bis %d." % [args[1], MAX_GIVE])
		amount = args[1].to_int()
	var inv := _lookup.inventory()
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
	var manager := _lookup.group_node(DebugWorldLookup.CORPSE_MANAGER_GROUP)
	if manager == null or not manager.has_method(&"spawn_corpse"):
		return _error(TEXT_NO_WORLD)
	var at := Transform3D()
	var location := &"dropoff"
	var where := "an der Bahre"
	var dropoff := _lookup.group_node(DebugWorldLookup.DROPOFF_GROUP)
	if dropoff != null and dropoff.has_method(&"is_free") and bool(dropoff.call(&"is_free")) and dropoff.has_method(&"slot_transform"):
		at = dropoff.call(&"slot_transform")
	else:
		var p := _lookup.player()
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
	var p := _lookup.player() as Node3D
	var npc := _lookup.npc_node(npc_id)
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
		_lookup.teleport_player(p, npc.global_position + Vector3(0.0, 0.0, NPC_OFFSET))
		return _ok("%s folgt seinem Tagesplan – du stehst jetzt neben ihm." % who)
	var wait := DebugCommandParser.minutes_to_next_presence(schedule)
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
	if target in ["east", "north", "elder", "trader"]:
		var p3 := _lookup.player() as Node3D
		var at: Variant = _phase4.tp_position(target, _phase3) if target in ["elder", "trader"] else _phase3.section_position(StringName(target))
		if p3 == null or at == null:
			return _error(TEXT_NO_WORLD)
		_lookup.teleport_player(p3, at)
		return _ok("Teleportiert: %s (%.1f, %.1f)" % [target, (at as Vector3).x, (at as Vector3).z])
	if not TP_TARGETS.has(target):
		return _error("Unbekanntes Ziel '%s' – Ziele: %s" % [args[0], names])
	var p := _lookup.player() as Node3D
	var world := _lookup.world()
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
	_lookup.teleport_player(p, pos)
	return _ok("Teleportiert: %s (%.1f, %.1f)" % [target, pos.x, pos.z])


func _cmd_save(args: PackedStringArray) -> Dictionary:
	var slot := DebugCommandParser.parse_slot(args, DEFAULT_SLOT)
	if slot < 0:
		return _error("Format: save [slot] (Slot ist eine Zahl ≥ 0)")
	if _lookup.world() == null and _lookup.player() == null:
		return _error(TEXT_NO_WORLD)
	var p := _lookup.player()
	if p != null and p.has_method(&"is_busy") and bool(p.call(&"is_busy")):
		return _error("Eine Aktion läuft – später speichern.")
	var err := SaveManager.save_game(slot)
	if err != OK:
		return _error("Speichern in Slot %d fehlgeschlagen: %s" % [slot, error_string(err)])
	return _ok("Gespeichert in Slot %d." % slot)


func _cmd_load(args: PackedStringArray) -> Dictionary:
	var slot := DebugCommandParser.parse_slot(args, DEFAULT_SLOT)
	if slot < 0:
		return _error("Format: load [slot] (Slot ist eine Zahl ≥ 0)")
	if not SaveManager.has_save(slot):
		return _error("Slot %d ist leer." % slot)
	_console.close()
	SaveManager.load_game(slot)
	return _ok("Lade Slot %d …" % slot)


func _cmd_camera(args: PackedStringArray) -> Dictionary:
	if args.size() > 1 or (args.size() == 1 and not args[0].to_lower() in ["ortho", "persp"]):
		return _error("Format: camera ortho|persp")
	var rig := _lookup.camera_rig()
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
	var graveyard := _lookup.group_node(DebugWorldLookup.GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return _error(TEXT_NO_WORLD)
	var score := CemeteryStatus.score(graveyard.get_tree())
	var lines: PackedStringArray = ["Friedhofsqualität %d · %s" % [int(score.total), CemeteryRating.label(score.rating)]]
	lines.append_array(_phase3.quality_lines())
	lines.append_array(_phase4.quality_lines())
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
	_console.fps_panel.visible = not _console.fps_panel.visible
	return _ok("FPS-Anzeige %s." % ("an" if _console.fps_panel.visible else "aus"))


func _cmd_instant(args: PackedStringArray) -> Dictionary:
	if args.size() > 1 or (args.size() == 1 and not args[0].to_lower() in ["on", "off"]):
		return _error("Format: instant on|off")
	var p := _lookup.player()
	if p == null or not (&"instant_actions" in p):
		return _error(TEXT_NO_WORLD)
	var value := not bool(p.get(&"instant_actions")) if args.is_empty() else args[0].to_lower() == "on"
	p.set(&"instant_actions", value)
	return _ok("Sofort-Aktionen %s." % ("an" if value else "aus"))


static func _ok(text: String) -> Dictionary:
	return result(true, text)


static func _error(text: String) -> Dictionary:
	return result(false, text)
