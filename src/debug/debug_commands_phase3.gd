class_name DebugCommandsPhase3
extends RefCounted
## Phase-3 commands of the debug console (docs/PHASE3_DESIGN.md §6), dispatched by
## DebugCommands.run(): unlock, clear, dirt, rep, ghosts, ghost mood, decor clear, build free,
## tp east|north and the extra lines of "quality". Every command goes through the public API
## of the system (found by its group); without the system: "Keine Spielwelt geladen.".
## Returns {ok, text} like DebugCommands.

const COMMANDS: PackedStringArray = ["unlock", "clear", "dirt", "rep", "ghosts", "ghost", "decor", "build"]
const HELP: PackedStringArray = [
	"unlock <east|north> – Abschnitt sofort freigeben",
	"clear <hindernis|east|north> – Hindernis (ohne Kosten) oder ganzen Abschnitt räumen",
	"dirt <0-3> · dirt grow <tage> – alle Pflegestellen setzen / wachsen lassen",
	"rep <0-100> – Ruf setzen",
	"ghosts on|off – Geisterzeit erzwingen / normal · ghost mood – Stimmung je Grab",
	"decor clear – alle Zier entfernen (ohne Rückgabe) · build free on|off – Bauen ohne Items",
	"tp <east|north> – zu einem neuen Abschnitt",
]
const REASON_DEBUG := "Debug"
const MAX_GROW_DAYS := 30
const MOOD_LABELS := {&"content": "zufrieden", &"calm": "gleichmütig", &"restless": "unruhig"}

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"unlock":
			return _cmd_unlock(args)
		"clear":
			return _cmd_clear(args)
		"dirt":
			return _cmd_dirt(args)
		"rep":
			return _cmd_rep(args)
		"ghosts":
			return _cmd_ghosts(args)
		"ghost":
			return _cmd_ghost(args)
		"decor":
			return _cmd_decor(args)
		"build":
			return _cmd_build(args)
	return _error("?")


## Extra lines for "quality": decor, care, reputation (empty without CemeteryScore).
func quality_lines() -> PackedStringArray:
	var tree := _tree()
	var out := PackedStringArray()
	if tree.get_first_node_in_group(CemeteryStatus.SCORE_GROUP) != null:
		var s := CemeteryStatus.score(tree)
		out.append("Gräber %d · Zier %s · Pflege %s = %d" % [int(s.graves), UIKit.signed(int(s.decor)), UIKit.signed(-int(s.dirt)), int(s.total)])
	var rep := CemeteryStatus.reputation(tree)
	if bool(rep.known):
		out.append("Ruf %d · %s (morgen %s)" % [int(rep.value), rep.label, UIKit.signed(int(rep.forecast))])
	return out


## Where "tp east|north" goes: the layout waypoint tp_<section> (free ground inside the section,
## also while it is overgrown), else the first plot of the section, else its first obstacle.
func section_position(section_id: StringName) -> Variant:
	var tree := _tree()
	var world := tree.current_scene
	var marker := world.get_node_or_null(NodePath("Waypoints/tp_%s" % section_id)) as Node3D if world != null else null
	if marker != null and marker.is_inside_tree():
		return marker.global_position
	var graveyard := tree.get_first_node_in_group(&"graveyard") as Graveyard
	if graveyard != null:
		var ids := graveyard.plots_in_section(section_id)
		for node: Node in tree.get_nodes_in_group(&"grave_plot"):
			if not ids.is_empty() and str(node.get(&"grave_id")) == ids[0] and node is Node3D:
				return (node as Node3D).global_position + Vector3(0.0, 0.0, 1.6)
	var expansion := _expansion()
	if expansion != null:
		for id: String in expansion.obstacle_ids(section_id):
			var o := expansion.obstacle(id)
			if o != null:
				return o.global_position + Vector3(0.0, 0.0, 2.0)
	return null


# --- commands -------------------------------------------------------------------------------

func _cmd_unlock(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: unlock <east|north>")
	var expansion := _expansion()
	if expansion == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	var s := expansion.section(id)
	if s == null:
		return _error("Unbekannter Abschnitt '%s' – Abschnitte: %s" % [args[0], _section_ids(expansion)])
	if expansion.is_unlocked(id):
		return _ok("%s ist schon freigelegt." % s.display_name)
	expansion.unlock(id)
	return _ok("%s freigelegt." % s.display_name)


func _cmd_clear(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: clear <hindernis|east|north>")
	var expansion := _expansion()
	if expansion == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var raw := args[0]
	if expansion.section(StringName(raw.to_lower())) != null:
		return _cmd_unlock(PackedStringArray([raw]))
	if expansion.obstacle(raw) == null:
		return _error("Unbekanntes Hindernis '%s'." % raw)
	if expansion.is_cleared(raw):
		return _ok("%s ist schon geräumt." % raw)
	var inv := _lookup.inventory()
	if inv == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var block := expansion.block_reason(expansion.obstacle(raw).section_id)
	if block != "":
		return _error("Noch nicht möglich: %s (unlock <abschnitt> gibt ihn trotzdem frei)." % block)
	# Without cost: hand the missing cost over first, clear() takes it back.
	var missing := expansion.missing_cost(raw, inv)
	for id: Variant in missing:
		inv.add_item(StringName(id), int(missing[id]))
	if not expansion.clear(raw, inv):
		return _error("%s lässt sich nicht räumen (Inventar voll?)." % raw)
	var p := expansion.progress(expansion.obstacle(raw).section_id)
	return _ok("%s geräumt (%d/%d)." % [raw, p.x, p.y])


func _cmd_dirt(args: PackedStringArray) -> Dictionary:
	var manager := _tree().get_first_node_in_group(CemeteryStatus.CLEANLINESS_GROUP) as CleanlinessManager
	if manager == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	if args.size() == 2 and args[0].to_lower() == "grow":
		if not args[1].is_valid_int() or args[1].to_int() < 1 or args[1].to_int() > MAX_GROW_DAYS:
			return _error("Ungültige Anzahl '%s' – erlaubt: 1 bis %d Tage." % [args[1], MAX_GROW_DAYS])
		var days := args[1].to_int()
		manager.last_total -= days * TimeManager.MINUTES_PER_DAY
		manager.update_to(TimeManager.total_minutes())
		return _ok("Pflegestellen um %d Tag%s gewachsen – %d verwildert (≥ 2), Abzug %d." % [days, "" if days == 1 else "e",
				manager.dirty_count(2), manager.penalty()])
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0 or args[0].to_int() > 3:
		return _error("Format: dirt <0-3> | dirt grow <tage>")
	var level := args[0].to_int()
	var spots := {}
	for id: String in manager.spot_ids():
		spots[id] = float(level)
	manager.load_state({"last_total": TimeManager.total_minutes(), "spots": spots})
	return _ok("%d Pflegestellen auf Stufe %d – Abzug %d." % [spots.size(), level, manager.penalty()])


func _cmd_rep(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0 or args[0].to_int() > 100:
		return _error("Format: rep <0-100>")
	var rep := _tree().get_first_node_in_group(CemeteryStatus.REPUTATION_GROUP) as Reputation
	if rep == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	rep.change(args[0].to_int() - rep.value(), REASON_DEBUG)
	return _ok("Ruf %d · %s" % [rep.value(), ReputationRules.label(rep.tier())])


func _cmd_ghosts(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["on", "off"]:
		return _error("Format: ghosts on|off")
	var manager := _ghosts()
	if manager == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	manager.forced = args[0].to_lower() == "on"
	manager.reselect()
	if manager.forced:
		return _ok("Geisterzeit erzwungen – %d Geist(er) berechtigt." % manager.eligible_graves().size())
	return _ok("Geister folgen wieder der Uhr (21:30–04:30).")


func _cmd_ghost(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "mood":
		return _error("Format: ghost mood")
	var manager := _ghosts()
	var graveyard := _tree().get_first_node_in_group(&"graveyard") as Graveyard
	if manager == null or graveyard == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var lines := PackedStringArray(["Geister (Grab → Wert · Stimmung · Grund):"])
	for grave: GraveRecord in graveyard.graves():
		var info := manager.mood_info(grave.id)
		if info.is_empty():
			continue
		var reason := String(info.reason) if StringName(info.reason) != &"" else "–"
		lines.append("  %s: %d · %s · %s%s" % [grave.id, int(info.score), MOOD_LABELS.get(info.mood, info.mood), reason,
				" (gehört)" if manager.was_heard(grave.id) else ""])
	if lines.size() == 1:
		lines.append("  (kein vollendetes Grab)")
	return _ok("\n".join(lines))


func _cmd_decor(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "clear":
		return _error("Format: decor clear")
	var manager := _decorations()
	if manager == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var n := manager.placements().size()
	manager.clear_all()
	return _ok("%d Zierstück(e) entfernt." % n)


func _cmd_build(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or args[0].to_lower() != "free" or not args[1].to_lower() in ["on", "off"]:
		return _error("Format: build free on|off")
	var manager := _decorations()
	if manager == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	manager.free_build = args[1].to_lower() == "on"
	return _ok("Bauen ohne Items %s." % ("an" if manager.free_build else "aus"))


# --- helpers --------------------------------------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _expansion() -> ExpansionManager:
	return _lookup.group_node(CemeteryStatus.EXPANSION_GROUP) as ExpansionManager


func _ghosts() -> GhostManager:
	return _lookup.group_node(CemeteryStatus.GHOSTS_GROUP) as GhostManager


func _decorations() -> DecorationManager:
	return _lookup.group_node(CemeteryStatus.DECOR_GROUP) as DecorationManager


static func _section_ids(expansion: ExpansionManager) -> String:
	var ids := PackedStringArray()
	for s: SectionData in expansion.sections():
		if not s.starts_unlocked:
			ids.append(String(s.id))
	return ", ".join(ids)


static func _ok(text: String) -> Dictionary:
	return DebugCommands.result(true, text)


static func _error(text: String) -> Dictionary:
	return DebugCommands.result(false, text)
