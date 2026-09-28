class_name DebugCommandsPhase5
extends RefCounted
## Phase-5 commands of the debug console (docs/PHASE5_DESIGN.md §6), dispatched by
## DebugCommands.run(): workshop open, license, build, tool, gather refill|empty, regrow, job done,
## stone, stones showcase, calendar, coins, goal and the tp targets bruch|quarry|schlag|workyard.
## Every command goes through the public API of the system (found by its group; saved state is
## rewritten through save_state / load_state where a system has no setter); without the system:
## "Keine Spielwelt geladen.". Returns {ok, text}.

const COMMANDS: PackedStringArray = ["workshop", "license", "build", "tool", "gather", "regrow", "job", "stone", "stones",
		"calendar", "coins", "goal"]
const HELP: PackedStringArray = [
	"workshop open – Werkhof sofort öffnen · license – Steinbruchbrief (Flag)",
	"build <mason|loom|forge|all> – Station sofort gebaut (ohne Material)",
	"tool <shovel|axe|pickaxe> <0-2> – Werkzeugstufe am Gürtel setzen",
	"gather refill · gather empty <node_id|all> · regrow <tage> – Sammelstellen",
	"job done – Meiler sofort fertig",
	"stone <grave_id> <shape> [inscription|-] [ornament|-] [gold] – Stein sofort gesetzt",
	"stones showcase – Steinreihe: jede Form und Zierde, schwarz und gold",
	"calendar <tag> – Inschrift-Datum · coins <n> – Münzen setzen · goal – Kapitel-Fortschritt",
	"tp <bruch|quarry|schlag|workyard> – Am Bruch / Steinbruch / Schlag / Werkhof",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const WORKSHOP_GROUP := &"workshop"
const GATHERING_GROUP := &"gathering"
const STONEMASONRY_GROUP := &"stonemasonry"
const GRAVEYARD_GROUP := &"graveyard"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const COIN := &"coin"
const MAX_COINS := 9999
const MAX_REGROW := 30
const SHOWCASE_NAME := "DebugStoneShowcase"
const SHOWCASE_SPACING := 1.3
## tp target -> [waypoint id, fallback position (§4.2, §4.3, §4.5)].
const TP_TARGETS: Dictionary[String, Array] = {
	"bruch": [&"tp_bruch", Vector3(25.5, 0.0, 0.0)],
	"quarry": [&"tp_quarry", Vector3(27.0, 0.0, -8.0)],
	"schlag": [&"tp_schlag", Vector3(-6.0, 0.0, 19.0)],
	"workyard": [&"tp_workyard", Vector3(-4.4, 0.0, -3.6)],
}

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"workshop":
			return _cmd_workshop(args)
		"license":
			return _cmd_license(args)
		"build":
			return _cmd_build(args)
		"tool":
			return _cmd_tool(args)
		"gather":
			return _cmd_gather(args)
		"regrow":
			return _cmd_regrow(args)
		"job":
			return _cmd_job(args)
		"stone":
			return _cmd_stone(args)
		"stones":
			return _cmd_stones(args)
		"calendar":
			return _cmd_calendar(args)
		"coins":
			return _cmd_coins(args)
		"goal":
			return _cmd_goal(args)
	return _error("?")


func tp_targets() -> PackedStringArray:
	return PackedStringArray(TP_TARGETS.keys())


## tp bruch|quarry|schlag|workyard: the layout's waypoint, else the contract position. null = unknown.
func tp_position(target: String) -> Variant:
	if not TP_TARGETS.has(target):
		return null
	var spec: Array = TP_TARGETS[target]
	var world := _lookup.world()
	if world != null:
		var at: Vector3 = world.call(&"get_waypoint", spec[0])
		if at != Vector3.ZERO:
			return at
	return spec[1]


# --- commands -------------------------------------------------------------------------------

func _cmd_workshop(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "open":
		return _error("Format: workshop open")
	var shop := _workshop()
	if shop == null:
		return _error(TEXT_NO_WORLD)
	GameState.set_flag(shop.workshop_config().open_flag, true)
	_refresh_sites()
	return _ok("Werkhof offen: Bauplätze, Sammelstellen und Händlerwaren sind da.")


func _cmd_license(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: license")
	var shop := _workshop()
	var flag := shop.workshop_config().license_flag if shop != null else &"bruch_license"
	GameState.set_flag(flag, true)
	return _ok("Steinbruchbrief gesetzt (%s). Die Ostpforte lässt sich aufschließen." % flag)


func _cmd_build(args: PackedStringArray) -> Dictionary:
	var shop := _workshop()
	if shop == null:
		return _error(TEXT_NO_WORLD)
	var goal := shop.workshop_config().goal_stations
	var names := PackedStringArray()
	for id: StringName in goal:
		names.append(String(id))
	if args.size() != 1 or not (args[0].to_lower() == "all" or StringName(args[0].to_lower()) in goal):
		return _error("Format: build <%s|all>" % "|".join(names))
	var wanted: Array[StringName] = []
	if args[0].to_lower() == "all":
		wanted.assign(goal)
	else:
		wanted.append(StringName(args[0].to_lower()))
	var state := shop.save_state()
	var built: Array = state.get("built", [])
	var added: Array[StringName] = []
	for id: StringName in wanted:
		if not String(id) in built:
			built.append(String(id))
			added.append(id)
	state["built"] = built
	shop.load_state(state)
	for id: StringName in added:
		EventBus.station_built.emit(id)
	shop.check_goal()
	_refresh_sites()
	return _ok("Gebaut: %s" % (Phase5Texts.stations_text(added) if not added.is_empty() else "(schon alles da)"))


func _cmd_tool(args: PackedStringArray) -> Dictionary:
	var kinds := ["shovel", "axe", "pickaxe"]
	if args.size() != 2 or not args[0].to_lower() in kinds or not args[1].is_valid_int() or args[1].to_int() < 0 or args[1].to_int() > 2:
		return _error("Format: tool <shovel|axe|pickaxe> <0-2>")
	var inv := _lookup.inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	var kind := StringName(args[0].to_lower())
	var tier := args[1].to_int()
	for id: StringName in inv.tools():
		var item := Database.item(id) as ItemData if Database.has_item(id) else null
		if item != null and item.tool_kind == kind:
			inv.remove_item(id, inv.count(id))
	var id := InventoryPanel._tool_item_id(kind, tier)
	if tier > 0:
		if id == &"":
			return _error("Kein Werkzeug %s Stufe %d in data/items." % [kind, tier])
		inv.add_item(id, 1)
	EventBus.tool_tier_changed.emit(kind, tier)
	var shop := _workshop()
	if shop != null:
		shop.check_goal()
	var tools := Database.config(&"tool_config") as ToolConfig
	var name := ToolRules.tool_name(kind, tier, tools)
	return _ok("%s: Stufe %d (%s)." % [tools.labels.get(kind, String(kind)) if tools != null else kind, tier, name if name != "" else "keine"])


func _cmd_gather(args: PackedStringArray) -> Dictionary:
	var gm := _gathering()
	if gm == null:
		return _error(TEXT_NO_WORLD)
	if args.size() == 1 and args[0].to_lower() == "refill":
		gm.load_state({})
		gm.post_load()
		return _ok("Alle %d Sammelstellen voll." % gm.node_ids().size())
	if args.size() == 2 and args[0].to_lower() == "empty":
		var target := args[1]
		var ids := gm.node_ids()
		if target.to_lower() != "all" and not target in ids:
			return _error("Unbekannte Sammelstelle '%s' – z. B.: %s" % [target, ", ".join(ids.slice(0, 6))])
		var state := gm.save_state()
		var n := 0
		for node_id: String in ids:
			if target.to_lower() != "all" and node_id != target:
				continue
			state[node_id] = {"charges": 0, "last_taken_day": TimeManager.day, "last_refresh_day": TimeManager.day}
			n += 1
		gm.load_state(state)
		gm.post_load()
		return _ok("%d Sammelstelle(n) abgeerntet." % n)
	return _error("Format: gather refill | gather empty <node_id|all>")


## Regrowth as if `days` days had passed for every node (same rule as day_started).
func _cmd_regrow(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 1 or args[0].to_int() > MAX_REGROW:
		return _error("Format: regrow <1-%d>" % MAX_REGROW)
	var gm := _gathering()
	if gm == null:
		return _error(TEXT_NO_WORLD)
	var days := args[0].to_int()
	var state := gm.save_state()
	for node_id: Variant in state:
		var s: Dictionary = state[node_id]
		if int(s.get("last_taken_day", -1)) >= 0:
			s["last_taken_day"] = int(s.last_taken_day) - days
	gm.load_state(state)
	gm.refresh(TimeManager.day)
	return _ok("Nachwachsen um %d Tag(e) vorgespult." % days)


func _cmd_job(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "done":
		return _error("Format: job done")
	var shop := _workshop()
	if shop == null:
		return _error(TEXT_NO_WORLD)
	var state := shop.save_state()
	var jobs: Dictionary = state.get("jobs", {})
	if jobs.is_empty():
		return _error("Kein Auftrag läuft.")
	for key: Variant in jobs:
		(jobs[key] as Dictionary)["end_total"] = TimeManager.total_minutes()
	shop.load_state(state)
	return _ok("Fertig: %s – holen an der Station." % ", ".join(PackedStringArray(jobs.keys())))


func _cmd_stone(args: PackedStringArray) -> Dictionary:
	if args.size() < 2 or args.size() > 5:
		return _error("Format: stone <grave_id> <shape> [inscription|-] [ornament|-] [gold]")
	var graveyard := _lookup.group_node(GRAVEYARD_GROUP) as Graveyard
	if graveyard == null:
		return _error(TEXT_NO_WORLD)
	var grave := graveyard.get_grave(args[0])
	if grave == null:
		return _error("Unbekanntes Grab '%s'." % args[0])
	var d := StoneDesign.new()
	d.shape = StringName(args[1].to_lower())
	if Database.stone_shape(d.shape) == null:
		return _error("Unbekannte Form '%s' – Formen: %s" % [args[1], _ids(Database.stone_shapes())])
	if args.size() >= 3 and args[2] != "-":
		d.inscription = StringName(args[2].to_lower())
		if Database.inscription(d.inscription) == null:
			return _error("Unbekannte Inschrift '%s' – %s" % [args[2], _ids(Database.inscriptions())])
	if args.size() >= 4 and args[3] != "-":
		d.ornament = StringName(args[3].to_lower())
		if Database.ornament(d.ornament) == null:
			return _error("Unbekannte Zierde '%s' – %s" % [args[3], _ids(Database.ornaments())])
	if args.size() == 5:
		if args[4].to_lower() != "gold":
			return _error("Das fünfte Argument ist 'gold'.")
		if d.inscription == &"":
			return _error(Stonemasonry.TEXT_GOLD_NEEDS_INSCRIPTION)
		d.gilded = true
	var manager := _lookup.group_node(CORPSE_MANAGER_GROUP)
	var corpse := manager.call(&"get_record", grave.corpse_id) as CorpseRecord if manager != null and grave.corpse_id != "" else null
	if corpse == null:
		return _error(Stonemasonry.TEXT_NO_GRAVE)
	if d.inscription != &"":
		d.text = StoneDesignRules.render_text(Database.inscription(d.inscription) as InscriptionData, corpse, _stone_config())
	var eco := graveyard.economy if graveyard.economy != null else EconomyConfig.resolve()
	if StoneDesignRules.marker_points(d, corpse, eco, _stone_config()) <= StoneDesignRules.current_marker_points(grave, corpse, eco, _stone_config()):
		return _error(Stonemasonry.TEXT_BETTER)
	var inv := _lookup.inventory()
	var diff := graveyard.set_designed_stone(args[0], d, inv)
	if graveyard.get_grave(args[0]).design != d.to_dict():
		return _error("Der Stein ließ sich nicht setzen.")
	return _ok("%s: %s gesetzt – Qualität %d (%s)." % [corpse.display_name, (Database.stone_shape(d.shape) as StoneShapeData).display_name,
			graveyard.get_grave(args[0]).quality, UIKit.signed(diff)])


## A row of stones in front of the player: every shape in ink and gold, every ornament once.
func _cmd_stones(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "showcase":
		return _error("Format: stones showcase")
	var p := _lookup.player() as Node3D
	var world := _lookup.world()
	if p == null or world == null:
		return _error(TEXT_NO_WORLD)
	var old := (world as Node).get_node_or_null(SHOWCASE_NAME)
	if old != null:
		old.free()
	var row := Node3D.new()
	row.name = SHOWCASE_NAME
	(world as Node).add_child(row)
	var designs := showcase_designs()
	var origin := p.global_position + Vector3(-(designs.size() - 1) * SHOWCASE_SPACING * 0.5, 0.0, -2.2)
	for i: int in designs.size():
		var stone := StoneVisual.build(designs[i], _stone_config())
		if stone == null:
			continue
		var at := origin + Vector3(i * SHOWCASE_SPACING, 0.0, 0.0)
		if world.has_method(&"ground_height"):
			at.y = float(world.call(&"ground_height", Vector2(at.x, at.z)))
		row.add_child(stone)
		stone.global_position = at
	return _ok("%d Steine aufgestellt (Form × Zierde, schwarz und gold)." % row.get_child_count())


## Showcase: stele / arch / master each in ink and in gold, the four ornaments spread over them.
static func showcase_designs() -> Array[StoneDesign]:
	var out: Array[StoneDesign] = []
	var cfg := Database.config(&"stone_config") as StoneConfig
	var names := ["Marthe Quendel", "Egbert Kornblum", "Hedwig Rabenstein", "Lorenz Aschau", "Ida Wendt", "Konrad Bleich"]
	var orns: Array[StringName] = [&"", &"orn_ivy", &"orn_poppy", &"orn_elder", &"orn_torch", &"orn_elder"]
	var i := 0
	for res: Resource in Database.stone_shapes():
		var s := res as StoneShapeData
		if s == null:
			continue
		for gold: bool in [false, true]:
			var d := StoneDesign.new()
			d.shape = s.id
			d.inscription = &"i_rest"
			d.gilded = gold
			d.ornament = orns[i % orns.size()]
			var year := StoneCalendar.year_of(1, cfg) if cfg != null else 1834
			d.text = PackedStringArray(["Hier ruht", names[i % names.size()], "* %d – † %s" % [year - 40 - i * 7, StoneCalendar.date_text(1 + i * 9, cfg)]])
			out.append(d)
			i += 1
	return out


func _cmd_calendar(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 1:
		return _error("Format: calendar <tag ≥ 1>")
	var day := args[0].to_int()
	return _ok("Tag %d: † %s" % [day, StoneCalendar.date_text(day, _stone_config())])


func _cmd_coins(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0 or args[0].to_int() > MAX_COINS:
		return _error("Format: coins <0-%d>" % MAX_COINS)
	var inv := _lookup.inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	var want := args[0].to_int()
	var have := inv.count(COIN)
	if want > have:
		inv.add_item(COIN, want - have)
	elif want < have:
		inv.remove_item(COIN, have - want)
	return _ok("Münzen: %d" % inv.count(COIN))


func _cmd_goal(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: goal")
	var shop := _workshop()
	if shop == null:
		return _error(TEXT_NO_WORLD)
	var p := shop.goal_progress()
	var lines := PackedStringArray(["Namen in Stein: %d/%d%s" % [int(p.done), int(p.total),
			" – erreicht" if GameState.get_flag(shop.workshop_config().goal_flag) == true else ""]])
	lines.append(Phase5Texts.chapter_line(p))
	var missing: PackedStringArray = p.get("missing", PackedStringArray())
	if not missing.is_empty():
		lines.append("Fehlt: %s" % ", ".join(missing))
	return _ok("\n".join(lines))


# --- helpers ----------------------------------------------------------------------------------

func _workshop() -> Workshop:
	return _lookup.group_node(WORKSHOP_GROUP) as Workshop


func _gathering() -> GatherManager:
	return _lookup.group_node(GATHERING_GROUP) as GatherManager


func _refresh_sites() -> void:
	var p := _lookup.player()
	if p == null:
		return
	var world := _lookup.world()
	if world != null:
		_refresh_under(world)


static func _refresh_under(node: Node) -> void:
	if node is BuildSite:
		(node as BuildSite).refresh()
	elif node is Workbench:
		(node as Workbench).refresh_built()
	for child: Node in node.get_children():
		_refresh_under(child)


func _stone_config() -> StoneConfig:
	var cfg := Database.config(&"stone_config") as StoneConfig
	return cfg if cfg != null else StoneConfig.new()


static func _ids(list: Array) -> String:
	var parts := PackedStringArray()
	for res: Resource in list:
		parts.append(String(res.get(&"id")))
	return ", ".join(parts)


static func _ok(text: String) -> Dictionary:
	return {"ok": true, "text": text}


static func _error(text: String) -> Dictionary:
	return {"ok": false, "text": text}
