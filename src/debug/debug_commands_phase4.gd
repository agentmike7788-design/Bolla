class_name DebugCommandsPhase4
extends RefCounted
## Phase-4 commands of the debug console (docs/PHASE4_DESIGN.md §6), dispatched by
## DebugCommands.run(): corpse fresh|stage, exam all, prep all, harvest, piety, clue, insight,
## story, trader, decay row, the tp targets elder|trader and the Ehrwürdig line of "quality".
## Every command goes through the public API of the system (found by its group); without the
## system: "Keine Spielwelt geladen.". "unlock elder" is the Phase-3 unlock. Returns {ok, text}.

const COMMANDS: PackedStringArray = ["corpse", "exam", "prep", "harvest", "piety", "clue", "insight", "story", "trader", "decay"]
const HELP: PackedStringArray = [
	"corpse fresh <0-1> · corpse stage <fresh|wilted|decaying|rotten> – Frische der Tisch-Leiche",
	"exam all – alle Schritte ohne Zeit · prep all – waschen, einkleiden, aufbahren (ohne Zeit)",
	"harvest <hair|teeth> – verwerten (Werkzeug wird gegeben)",
	"piety <-100..100> – Pietät setzen (nur Debug zeigt die Zahl)",
	"clue <id|all> · insight <id> – Hinweis / Erkenntnis ins Merkbuch",
	"story <id|next|list> – Geschichts-Leiche sofort liefern / Liste",
	"trader known|here|stock – Ilse bekannt / an die Mauer holen / Vorrat auffüllen",
	"decay row – 4 Leichen in den 4 Verfallsstufen neben dem Tisch",
	"tp <elder|trader> · unlock elder – Holunderwinkel / Westmauer",
]
const REASON_DEBUG := "Debug"
const STAGE_FRESHNESS: Dictionary[String, float] = {"fresh": 0.95, "wilted": 0.45, "decaying": 0.2, "rotten": 0.05}
const TRADER_ARRIVE := 1385
const TRADER_LEAVE := 180
const FLAG_KNOWN := &"trader_known"

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"corpse":
			return _cmd_corpse(args)
		"exam":
			return _cmd_exam(args)
		"prep":
			return _cmd_prep(args)
		"harvest":
			return _cmd_harvest(args)
		"piety":
			return _cmd_piety(args)
		"clue":
			return _cmd_clue(args)
		"insight":
			return _cmd_insight(args)
		"story":
			return _cmd_story(args)
		"trader":
			return _cmd_trader(args)
		"decay":
			return _cmd_decay(args)
	return _error("?")


## Extra line of "quality": what „Ehrwürdig“ still lacks ("" = nothing / no score).
func quality_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var tree := _tree()
	if tree.get_first_node_in_group(CemeteryStatus.SCORE_GROUP) == null:
		return out
	var s := CemeteryStatus.score(tree)
	var text := Phase4Texts.venerable_missing_text(s.get("venerable_missing", PackedStringArray()))
	out.append(text if text != "" else Phase4Texts.TEXT_VENERABLE_OK % CemeteryRating.label(&"venerable"))
	return out


## tp elder|trader: the elder section (Phase-3 lookup) / next to Ilse's spot. null = unknown.
func tp_position(target: String, phase3: DebugCommandsPhase3) -> Variant:
	if target == "elder":
		return phase3.section_position(&"elder")
	if target == "trader":
		var world := _lookup.world()
		if world != null:
			var spot: Vector3 = world.call(&"get_waypoint", &"trader_spot")
			if spot != Vector3.ZERO:
				return spot + Vector3(1.4, 0.0, 0.0)
		var npc := _lookup.npc_node(&"trader")
		if npc != null:
			return npc.global_position + Vector3(1.4, 0.0, 0.0)
	return null


# --- commands -------------------------------------------------------------------------------

func _cmd_corpse(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[0].to_lower() in ["fresh", "stage"]:
		return _error("Format: corpse fresh <0-1> | corpse stage <fresh|wilted|decaying|rotten>")
	var value := 0.0
	if args[0].to_lower() == "fresh":
		if not args[1].is_valid_float() or args[1].to_float() < 0.0 or args[1].to_float() > 1.0:
			return _error("Ungültige Frische '%s' – erlaubt: 0 bis 1." % args[1])
		value = args[1].to_float()
	else:
		if not STAGE_FRESHNESS.has(args[1].to_lower()):
			return _error("Unbekannte Stufe '%s' – Stufen: %s" % [args[1], ", ".join(STAGE_FRESHNESS.keys())])
		value = STAGE_FRESHNESS[args[1].to_lower()]
	var record := _table_record()
	if record == null:
		return _error("Keine Leiche auf dem Tisch.")
	set_freshness(record, value)
	return _ok("%s: Frische %d %% (%s)." % [record.display_name, roundi(record.freshness * 100.0),
			CorpseExamPanel.STAGE_LABELS.get(record.freshness_stage(), "")])


## Sets the freshness by moving the arrival back (the decay formula keeps it from then on).
func set_freshness(record: CorpseRecord, value: float) -> void:
	var manager := _manager()
	var tables := Database.corpse_tables() as CorpseTables
	var rate := CorpseDecay.decay_per_hour(record, tables)
	var now := TimeManager.total_minutes()
	record.balm_windows = PackedInt32Array()
	if rate > 0.0:
		record.arrival_total_minutes = now - roundi((1.0 - clampf(value, 0.0, 1.0)) / rate * 60.0)
	record.freshness = CorpseDecay.freshness_at(record, now, rate) if rate > 0.0 else value
	record.last_decay_total = now
	if manager != null:
		manager.notify_changed(record.id)


func _cmd_exam(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "all":
		return _error("Format: exam all")
	var care := _care()
	var record := _table_record()
	if care == null or record == null:
		return _error(DebugCommands.TEXT_NO_WORLD if care == null else "Keine Leiche auf dem Tisch.")
	var result := care.exam_all_instant(record.id)
	return _ok("Untersucht: %d Funde, %d verloren." % [(result.get("revealed", []) as Array).size(), (result.get("lost", []) as Array).size()])


func _cmd_prep(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "all":
		return _error("Format: prep all")
	var care := _care()
	var record := _table_record()
	var inv := _lookup.inventory()
	if care == null or record == null or inv == null:
		return _error(DebugCommands.TEXT_NO_WORLD if care == null else "Keine Leiche auf dem Tisch.")
	if record.needs_valuables_decision():
		_manager().decide_valuables(record.id, false, inv)
	var prep := care.get_prep_config()
	for id: StringName in [prep.wash_tool, prep.lay_out_tool]:
		if not inv.has(id):
			inv.add_item(id, 1)
	var done := PackedStringArray()
	if care.wash(record.id, inv):
		done.append("gewaschen")
	if not record.is_dressed():
		var item := prep.dress_item(&"shroud")
		if not inv.has(item):
			inv.add_item(item, 1)
		if care.dress(record.id, &"shroud", inv):
			done.append("Leichentuch")
	if care.lay_out(record.id, inv):
		done.append("aufgebahrt")
	return _ok("Hergerichtet: %s." % (", ".join(done) if not done.is_empty() else "nichts mehr zu tun"))


func _cmd_harvest(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["hair", "teeth"]:
		return _error("Format: harvest <hair|teeth>")
	var care := _care()
	var record := _table_record()
	var inv := _lookup.inventory()
	if care == null or record == null or inv == null:
		return _error(DebugCommands.TEXT_NO_WORLD if care == null else "Keine Leiche auf dem Tisch.")
	var kind := StringName(args[0].to_lower())
	var tool := StringName(str(care.get_utilization_config().kind(kind).get("tool", "")))
	if tool != &"" and not inv.has(tool):
		inv.add_item(tool, 1)
	var reason := care.harvest_block_reason(record.id, kind, inv)
	if reason == UtilizationRules.HIDDEN:
		return _error("Ilse ist noch nicht bekannt – erst 'trader known'.")
	if reason != "" or not care.harvest(record.id, kind, inv):
		return _error("Nicht möglich: %s" % reason)
	return _ok("Verwertet: %s." % str(care.get_utilization_config().kind(kind).get("label", kind)))


func _cmd_piety(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < -100 or args[0].to_int() > 100:
		return _error("Format: piety <-100..100>")
	var piety := _lookup.group_node(&"piety") as Piety
	if piety == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	piety.change(args[0].to_int() - piety.value(), REASON_DEBUG)
	return _ok("Pietät %d · %s" % [piety.value(), PietyRules.label(piety.tier())])


func _cmd_clue(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: clue <id|all>")
	var journal := _journal()
	if journal == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	if args[0].to_lower() == "all":
		var n := 0
		for c: ClueData in Database.clues():
			if journal.add_clue(c.id, "", true):
				n += 1
		return _ok("%d Hinweis(e) ins Merkbuch." % n)
	var id := StringName(args[0].to_lower())
	if Database.clue(id) == null:
		return _error("Unbekannter Hinweis '%s' – z. B. %s" % [args[0], _ids(Database.clues())])
	if not journal.add_clue(id):
		return _ok("%s steht schon im Merkbuch." % id)
	return _ok("Ins Merkbuch: %s" % (Database.clue(id) as ClueData).title)


func _cmd_insight(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: insight <id>")
	var journal := _journal()
	if journal == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var data := Database.insight(StringName(args[0].to_lower())) as InsightData
	if data == null:
		return _error("Unbekannte Erkenntnis '%s' – z. B. %s" % [args[0], _ids(Database.insights())])
	if journal.has_insight(data.id):
		return _ok("%s ist schon erkannt." % data.title)
	for id: StringName in data.requires:
		journal.add_clue(id, "", true)
	var result := journal.try_link(data.requires.duplicate())
	return _ok("Erkenntnis: %s" % data.title) if result == data.id else _error("Verknüpfen fehlgeschlagen.")


func _cmd_story(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: story <id|next|list>")
	var manager := _manager()
	if manager == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var delivered := manager.story_delivered()
	var arg := args[0].to_lower()
	if arg == "list":
		var lines := PackedStringArray(["Geschichts-Leichen (ab Tag · Status):"])
		for s: StoryCorpseData in Database.story_corpses():
			lines.append("  %s: %s, ab Tag %d · %s" % [s.id, s.display_name, s.earliest_day, "geliefert" if delivered.has(String(s.id)) else "offen"])
		return _ok("\n".join(lines))
	var id := StringName(arg)
	if arg == "next":
		id = &""
		for s: StoryCorpseData in Database.story_corpses():
			if not delivered.has(String(s.id)):
				id = s.id
				break
		if id == &"":
			return _ok("Alle Geschichts-Leichen sind geliefert.")
	var record := manager.deliver_story_now(id)
	if record == null:
		return _error("%s lässt sich nicht liefern (unbekannt, schon geliefert, Bahre belegt oder keine freie Grabstelle)." % id)
	return _ok("Geliefert: %s (%s)." % [record.display_name, id])


func _cmd_trader(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["known", "here", "stock"]:
		return _error("Format: trader known|here|stock")
	var trade := _lookup.group_node(&"night_trade") as NightTrade
	if trade == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	match args[0].to_lower():
		"known":
			GameState.set_flag(FLAG_KNOWN, true)
			return _ok("Ilse Kranich ist bekannt (ab 23:00 an der Westmauer).")
		"stock":
			var state := trade.save_state()
			state["stock_night"] = -1
			state["stock_left"] = {}
			trade.load_state(state)
			return _ok("Ilses Vorrat für heute Nacht ist aufgefüllt.")
	GameState.set_flag(FLAG_KNOWN, true)
	var m := TimeManager.minute_of_day
	if not trade.is_present() and not (m >= TRADER_ARRIVE or m < TRADER_LEAVE):
		TimeManager.set_time(TimeManager.day, TRADER_ARRIVE)
	var npc := _lookup.npc_node(&"trader")
	if npc != null and npc.has_method(&"refresh"):
		npc.call(&"refresh")
	return _ok("Ilse steht an der Westmauer (Tag %d, %s). 'tp trader' bringt dich hin." % [TimeManager.day, TimeManager.format_clock()])


## Four corpses in the four stages in a row beside the table (screenshot p4_02).
func _cmd_decay(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "row":
		return _error("Format: decay row")
	var manager := _manager()
	var table := _lookup.group_node(&"morgue_table") as Node3D
	if manager == null or table == null:
		return _error(DebugCommands.TEXT_NO_WORLD)
	var names := PackedStringArray()
	var i := 0
	for stage: String in STAGE_FRESHNESS:
		var at := Transform3D(table.global_basis, table.global_position + table.global_basis.z * 1.6 + table.global_basis.x * (float(i) - 1.5) * 1.1)
		var record := manager.spawn_corpse(null, at, CorpseRecord.LOCATION_GROUND)
		if record != null:
			set_freshness(record, STAGE_FRESHNESS[stage])
			names.append("%s (%s)" % [record.display_name, stage])
		i += 1
	return _ok("Verfall-Reihe: %s" % ", ".join(names))


# --- helpers --------------------------------------------------------------------------------

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _manager() -> CorpseManager:
	return _lookup.group_node(DebugWorldLookup.CORPSE_MANAGER_GROUP) as CorpseManager


func _care() -> CorpseCare:
	return _lookup.group_node(&"corpse_care") as CorpseCare


func _journal() -> JournalManager:
	return _lookup.group_node(&"journal") as JournalManager


func _table_record() -> CorpseRecord:
	var manager := _manager()
	if manager == null:
		return null
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			return r
	return null


static func _ids(list: Array) -> String:
	var out := PackedStringArray()
	for r: Variant in list:
		var id: Variant = (r as Resource).get(&"id") if r is Resource else null
		if id != null:
			out.append(String(id))
		if out.size() >= 6:
			break
	return ", ".join(out)


static func _ok(text: String) -> Dictionary:
	return DebugCommands.result(true, text)


static func _error(text: String) -> Dictionary:
	return DebugCommands.result(false, text)
