class_name DebugCommandsPhase7
extends RefCounted
## Phase-7 commands of the debug console (docs/PHASE7_DESIGN.md §6), dispatched by DebugCommands.run():
## village open · region · room <inn|surgery|office> · tp <village|anger|linden> · rel · orders · order ·
## board · linden · anatomy · specimen · specimens · spoil · shelf · standing · lecture · rumor · cards ·
## deduce · teach · medicine · hidden · hagedorn · npclod · remark · vis7 · goal7. Every command goes
## through the public API of the system (found by its group); without it: "Keine Spielwelt geladen.".
## Returns {ok, text}. Shortcuts for testing only – they skip time and ingredients, never the rules of the
## systems themselves (an order accept still follows Orders.accept).

const COMMANDS: PackedStringArray = ["village", "region", "rel", "orders", "order", "board", "linden", "anatomy", "specimen",
		"specimens", "spoil", "shelf", "standing", "lecture", "rumor", "cards", "deduce", "teach", "medicine", "hidden",
		"hagedorn", "npclod", "remark", "vis7", "goal7"]
const HELP: PackedStringArray = [
	"village open – Dorf sofort öffnen · region <graveyard|village> – Region wechseln (ohne Zeit)",
	"room <inn|surgery|office> – in einen Dorf-Innenraum · tp <village|anger|linden> – teleportieren",
	"rel <npc|all> <0-100> – Beziehung setzen · remark <npc> – Gerede-Blase zeigen",
	"orders – Aufträge mit Zustand und Frist · order <id> <offer|accept|done|fail> · board – Tafel neu würfeln",
	"linden <grant|clear|consecrate|open> – Lindenacker freigeben / räumen / weihen / öffnen",
	"anatomy – Präparierbesteck + anatomy_known · specimen <organ> [jar|bundle] – Präparat von der Tisch-Leiche",
	"specimens – Präparate mit Klarheit/Zustand · spoil <uid> – Bündel verderben · shelf <organ…> – Sammlung füllen",
	"standing <0-4> – Ansehen bei der Universität · lecture – heute Vorlesungsabend (Einladung) · rumor <on|off>",
	"cards <corpse|table> – Karten zeigen · deduce <corpse|table> <cause> · teach <l_id|all> · medicine <id>",
	"hidden <cause> – verborgene Ursache der Tisch-Leiche · hagedorn – D1 morgen fällig",
	"npclod – LOD-Stufen über den Köpfen · vis7 – Sichtprüfung im Dorf · goal7 – Kapitel „Ein Name im Dorf“",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const REASON_DEBUG := "Debug"
const VILLAGE_ROOMS: Array[StringName] = [&"inn", &"surgery", &"office"]
const REGIONS: Array[StringName] = [&"graveyard", &"village"]
## tp target -> [region, waypoint, fallback (region-local for the village)].
const TP_TARGETS: Dictionary[String, Array] = {
	"village": [&"village", &"tp_village", Vector3(-20.0, 0.0, 1.5)],
	"anger": [&"village", &"tp_anger", Vector3(0.0, 0.0, 2.0)],
	"linden": [&"graveyard", &"tp_linden", Vector3(16.0, 0.0, 14.8)],
}
const SPAWN_IN := {&"village": &"from_graveyard", &"graveyard": &"from_village"}
const LOD_TAG := &"LodTag"
const LOD_COLORS: Array[Color] = [Color(0.45, 0.85, 0.45), Color(0.95, 0.8, 0.3), Color(0.85, 0.35, 0.3)]
const VIS_HEIGHT := 1.6

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


## Phase 7 takes "room" for the village rooms.
static func takes_room(args: PackedStringArray) -> bool:
	return args.size() == 1 and StringName(args[0].to_lower()) in VILLAGE_ROOMS


func tp_targets() -> PackedStringArray:
	return PackedStringArray(TP_TARGETS.keys())


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"village":
			return _cmd_village(args)
		"region":
			return _cmd_region(args)
		"room":
			return _cmd_room(args)
		"tp":
			return cmd_tp(args)
		"rel":
			return _cmd_rel(args)
		"orders":
			return _cmd_orders(args)
		"order":
			return _cmd_order(args)
		"board":
			return _cmd_board(args)
		"linden":
			return _cmd_linden(args)
		"anatomy":
			return _cmd_anatomy(args)
		"specimen":
			return _cmd_specimen(args)
		"specimens":
			return _cmd_specimens(args)
		"spoil":
			return _cmd_spoil(args)
		"shelf":
			return _cmd_shelf(args)
		"standing":
			return _cmd_standing(args)
		"lecture":
			return _cmd_lecture(args)
		"rumor":
			return _cmd_rumor(args)
		"cards":
			return _cmd_cards(args)
		"deduce":
			return _cmd_deduce(args)
		"teach":
			return _cmd_teach(args)
		"medicine":
			return _cmd_medicine(args)
		"hidden":
			return _cmd_hidden(args)
		"hagedorn":
			return _cmd_hagedorn(args)
		"npclod":
			return _cmd_npclod(args)
		"remark":
			return _cmd_remark(args)
		"vis7":
			return _cmd_vis7(args)
		"goal7":
			return _cmd_goal7(args)
	return _error("?")


# --- regions --------------------------------------------------------------------------------------

func _cmd_village(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "open":
		return _error("Format: village open")
	var v := _system(&"village") as Village
	if v == null:
		return _error(TEXT_NO_WORLD)
	v.open()
	return _ok("Hollerbrück ist offen (Tag %d). Der Wegstein am Kutschweg zeigt den Weg." % TimeManager.day)


func _cmd_region(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not StringName(args[0].to_lower()) in REGIONS:
		return _error("Format: region <graveyard|village>")
	var p := _lookup.player() as Player
	if p == null:
		return _error(TEXT_NO_WORLD)
	var target := StringName(args[0].to_lower())
	var region := RegionRoot.find(p.get_tree(), target)
	if region == null:
		return _error("Die Welt hat keine Region '%s'." % target)
	var spawn := region.spawn_transform(SPAWN_IN[target])
	HutPortal.arrive(p, spawn, false)
	p.set_region(target)
	var rig := _lookup.camera_rig()
	if rig != null:
		rig.snap()
	return _ok("Region: %s (%.1f, %.1f)" % [target, spawn.origin.x, spawn.origin.z])


func _cmd_room(args: PackedStringArray) -> Dictionary:
	var p := _lookup.player() as Player
	if p == null:
		return _error(TEXT_NO_WORLD)
	if not takes_room(args):
		return _error("Format: room <inn|surgery|office>")
	var target := StringName(args[0].to_lower())
	var room := InteriorRoom.find(p.get_tree(), target)
	if room == null:
		return _error("Die Welt hat keinen Raum '%s'." % target)
	if p.region_id != RegionRoot.VILLAGE:
		p.set_region(RegionRoot.VILLAGE)
	HutPortal.arrive(p, room.spawn_transform(), true, target)
	var rig := _lookup.camera_rig()
	if rig != null:
		rig.snap()
	return _ok("Im Raum: %s" % target)


## tp village|anger|linden: the region's waypoint, else the contract position; switches the region.
func cmd_tp(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not TP_TARGETS.has(args[0].to_lower()):
		return _error("Format: tp <village|anger|linden>")
	var p := _lookup.player() as Player
	if p == null:
		return _error(TEXT_NO_WORLD)
	var spec: Array = TP_TARGETS[args[0].to_lower()]
	var region := RegionRoot.find(p.get_tree(), spec[0])
	var at: Vector3 = spec[2]
	if region != null:
		var wp := region.get_waypoint(spec[1])
		at = wp if wp != region.origin() else region.origin() + (spec[2] as Vector3)
	if p.in_interior and p.has_method(&"set_in_interior"):
		p.set_in_interior(false)
	_lookup.teleport_player(p, at)
	if p.region_id != spec[0]:
		p.set_region(spec[0])
	return _ok("Teleportiert: %s (%.1f, %.1f)" % [args[0].to_lower(), at.x, at.z])


# --- people & orders --------------------------------------------------------------------------------

func _cmd_rel(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[1].is_valid_int():
		return _error("Format: rel <npc|all> <0-100>")
	var rel := _system(&"relationships") as Relationships
	if rel == null:
		return _error(TEXT_NO_WORLD)
	var value := clampi(args[1].to_int(), 0, 100)
	var ids: Array[StringName] = []
	if args[0].to_lower() == "all":
		ids.assign(Phase7Texts.VILLAGER_ORDER)
	else:
		var id := StringName(args[0].to_lower())
		if rel.villager(id) == null:
			return _error("Unbekannte Person '%s' – %s." % [args[0], ", ".join(PackedStringArray(Phase7Texts.VILLAGER_ORDER))])
		ids.append(id)
	var parts := PackedStringArray()
	for id: StringName in ids:
		rel.meet(id)
		rel.add(id, value - rel.value(id), REASON_DEBUG)
		parts.append("%s %d (%s)" % [Phase7Texts.short_name(id), rel.value(id), RelationshipRules.word(rel.tier(id))])
	return _ok(" · ".join(parts))


func _cmd_orders(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: orders")
	var orders := _system(&"orders") as Orders
	if orders == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	for o: OrderData in orders.all_orders():
		var st := orders.state(o.id)
		if st == &"" and not orders.offers().has(o.id):
			continue
		var deadline := orders.deadline_day(o.id)
		lines.append("%s · %s%s%s" % [o.id, st if st != &"" else &"angeboten", " · Frist Tag %d" % deadline if deadline > 0 else "",
				" · Tafel" if orders.board().has(o.id) else ""])
	lines.append("Erledigt: %d · Auftraggeber: %s" % [orders.done_count(), ", ".join(orders.done_givers())])
	return _ok("\n".join(lines))


func _cmd_order(args: PackedStringArray) -> Dictionary:
	if args.size() != 2 or not args[1].to_lower() in ["offer", "accept", "done", "fail"]:
		return _error("Format: order <id> <offer|accept|done|fail>")
	var orders := _system(&"orders") as Orders
	if orders == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0])
	if orders.order_data(id) == null:
		return _error("Unbekannter Auftrag '%s'." % args[0])
	match args[1].to_lower():
		"offer":
			if not orders.offer(id):
				return _error("Nicht anzubieten: %s" % orders.block_reason(id))
		"accept":
			if orders.state(id) != Orders.STATE_ACCEPTED and not orders.accept(id):
				return _error("Nicht anzunehmen: %s" % orders.block_reason(id))
		"done":
			orders.complete(id)
		"fail":
			if orders.state(id) != Orders.STATE_ACCEPTED:
				return _error("Nur ein angenommener Auftrag kann scheitern.")
			orders.fail(id)
	return _ok("%s: %s" % [id, orders.state(id)])


func _cmd_board(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: board")
	var orders := _system(&"orders") as Orders
	if orders == null:
		return _error(TEXT_NO_WORLD)
	var state := orders.save_state()
	state["board_day"] = 0
	state["board"] = []
	orders.load_state(state)
	orders.apply_morning(TimeManager.day)
	return _ok("Tafel: %s" % ", ".join(PackedStringArray(Array(orders.board()).map(func(i: StringName) -> String: return String(i)))))


func _cmd_remark(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: remark <npc>")
	var rel := _system(&"relationships") as Relationships
	if rel == null:
		return _error(TEXT_NO_WORLD)
	var id := StringName(args[0].to_lower())
	var text := rel.remark_text(id, TimeManager.day)
	if text == "":
		return _error("%s hat nichts zu sagen." % args[0])
	EventBus.villager_remarked.emit(id, text)
	return _ok("%s: „%s“" % [Phase7Texts.short_name(id), text])


# --- the Lindenacker ---------------------------------------------------------------------------------

func _cmd_linden(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["grant", "clear", "consecrate", "open"]:
		return _error("Format: linden <grant|clear|consecrate|open>")
	var expansion := _system(&"expansion") as ExpansionManager
	var village := _system(&"village") as Village
	if expansion == null and village == null:
		return _error(TEXT_NO_WORLD)
	var what := args[0].to_lower()
	if what in ["grant", "open"]:
		GameState.set_flag(Village.FLAG_LINDEN_GRANTED, true)
	if what in ["clear", "open"] and expansion != null and expansion.section(&"linden") != null:
		var st := expansion.save_state()
		var cleared: Array = st.get("cleared", [])
		for id: String in expansion.obstacle_ids(&"linden"):
			if not cleared.has(id):
				cleared.append(id)
		st["cleared"] = cleared
		expansion.load_state(st)
		var p := expansion.progress(&"linden")
		EventBus.section_progress_changed.emit(&"linden", p.x, p.y)
		var orders := _system(&"orders") as Orders
		if orders != null:
			orders.note_section_progress(&"linden", p.x, p.y)
		expansion.try_unlock(&"linden")
	if what in ["consecrate", "open"]:
		if village != null:
			village.consecrate()
		else:
			GameState.set_flag(Village.FLAG_CONSECRATED, true)
		if expansion != null:
			expansion.try_unlock(&"linden")
	var unlocked := expansion != null and expansion.is_unlocked(&"linden")
	var prog := expansion.progress(&"linden") if expansion != null else Vector2i.ZERO
	return _ok("Lindenacker: freigegeben %s · geräumt %d/%d · geweiht %s · offen %s" % [_yes(GameState.flag_on(Village.FLAG_LINDEN_GRANTED)),
			prog.x, prog.y, _yes(GameState.flag_on(Village.FLAG_CONSECRATED)), _yes(unlocked)])


func _cmd_hagedorn(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: hagedorn")
	var story := Database.story_corpse(&"d1_hagedorn") as StoryCorpseData
	var after := story.after_days if story != null else 8
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(Village.FLAG_OPEN_DAY, TimeManager.day + 1 - after)
	GameState.set_flag(Village.FLAG_CONSECRATED, true)
	return _ok("Wiebke Hagedorn ist ab morgen fällig (village_open_day %d, Lindenacker geweiht)." % (TimeManager.day + 1 - after))


# --- anatomy ------------------------------------------------------------------------------------------

func _cmd_anatomy(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: anatomy")
	var inv := _lookup.inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	var cfg := _anatomy()
	if not inv.has(cfg.tool_item):
		inv.add_item(cfg.tool_item, 1)
	GameState.set_flag(cfg.known_flag, true)
	GameState.set_flag(&"quast_recipes", true)
	var lectures := _system(&"lectures") as Lectures
	if lectures != null:
		for t: StringName in cfg.basic_teachings:
			lectures.learn(t)
	return _ok("Präparierbesteck und Rezeptbuch – anatomy_known gesetzt.")


func _cmd_specimen(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args.size() > 2:
		return _error("Format: specimen <organ> [jar|bundle]")
	var care := _system(&"corpse_care") as CorpseCare
	var inv := _lookup.inventory()
	var record := _table_record()
	if care == null or inv == null:
		return _error(TEXT_NO_WORLD)
	if record == null:
		return _error("Auf dem Gruft-Tisch liegt niemand.")
	var organ := StringName(args[0].to_lower())
	var cfg := care.get_anatomy_config()
	if cfg.organ(organ).is_empty():
		return _error("Unbekanntes Organ '%s' – %s." % [args[0], ", ".join(PackedStringArray(AnatomyConfig.ORGANS))])
	var allowed: Array = cfg.organ(organ).get("containers", [])
	var container := StringName(args[1].to_lower()) if args.size() == 2 else StringName(str(allowed[0]))
	if not inv.has(cfg.tool_item):
		inv.add_item(cfg.tool_item, 1)
	GameState.set_flag(cfg.known_flag, true)
	var inputs := SpecimenRules.harvest_inputs(organ, container, cfg)
	for id: StringName in inputs:
		var missing := inputs[id] - inv.count(id)
		if missing > 0:
			inv.add_item(id, missing)
	var uid := care.harvest_organ(record.id, organ, container, inv)
	if uid == "":
		return _error("Geht nicht: %s" % care.organ_block_reason(record.id, organ, container, inv))
	var specimens := _system(&"specimens") as Specimens
	return _ok("%s: %s" % [uid, specimens.label(uid) if specimens != null else String(organ)])


func _cmd_specimens(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: specimens")
	var specimens := _system(&"specimens") as Specimens
	if specimens == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	var data := specimens.save_state()
	for raw: Variant in data.get("records", []):
		var uid := str((raw as Dictionary).get("uid", ""))
		var spec := specimens.get_record(uid)
		if spec == null:
			continue
		lines.append("%s · %s · %s · %s · Klarheit %.2f%s" % [uid, Phase7Texts.organ_label(spec.organ), spec.corpse_name,
				Phase7Texts.container_word(spec.container), specimens.clarity(uid), " · " + String(spec.state)])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine Präparate.")


func _cmd_spoil(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: spoil <uid>")
	var specimens := _system(&"specimens") as Specimens
	if specimens == null:
		return _error(TEXT_NO_WORLD)
	var spec := specimens.get_record(args[0])
	if spec == null:
		return _error("Unbekanntes Präparat '%s'." % args[0])
	if spec.container != SpecimenRecord.CONTAINER_BUNDLE:
		return _error("Nur ein Bündel verdirbt.")
	spec.cold_windows = PackedInt32Array()
	spec.harvest_total = TimeManager.total_minutes() - _anatomy().bundle_minutes - 1
	specimens.check_spoiled(TimeManager.total_minutes())
	return _ok("%s ist verdorben." % args[0])


func _cmd_shelf(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error("Format: shelf <organ…> (z. B. shelf heart lung)")
	var shelf := _shelf()
	var specimens := _system(&"specimens") as Specimens
	var inv := _lookup.inventory()
	var record := _table_record()
	if record == null:
		var manager := _system(&"corpse_manager") as CorpseManager
		record = manager.records()[0] if manager != null and not manager.records().is_empty() else null
	if shelf == null or specimens == null or inv == null:
		return _error(TEXT_NO_WORLD)
	if record == null:
		return _error("Keine Leiche bekannt, von der die Stücke stammen könnten.")
	var cfg := specimens.get_config()
	var placed := PackedStringArray()
	for raw: String in args:
		var organ := StringName(raw.to_lower())
		if cfg.organ(organ).is_empty() or shelf.uid_at(organ) != "":
			continue
		var container := SpecimenRecord.CONTAINER_BUNDLE if organ == CorpseRecord.HARVEST_HAND else SpecimenRecord.CONTAINER_JAR
		var scratch := _scratch(SpecimenRules.harvest_inputs(organ, container, cfg))
		var uid := specimens.harvest(record.id, organ, container, scratch)
		if uid == "":
			scratch.free()
			continue
		if organ == CorpseRecord.HARVEST_HAND:
			for id: StringName in PultRules.BONE_INPUTS:
				scratch.add_item(id, PultRules.BONE_INPUTS[id])
			specimens.make_bone(uid, scratch)
		var item := scratch.uid_item(uid)
		scratch.remove_uid(uid)
		scratch.free()
		inv.add_unique(item, uid)
		if shelf.place(uid, inv):
			placed.append(Phase7Texts.organ_label(organ, cfg))
	return _ok("Ins Regal: %s · Ansehen %d · Sätze: %s" % [", ".join(placed) if not placed.is_empty() else "nichts",
			shelf.standing(), ", ".join(shelf.sets_done())])


func _cmd_standing(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].is_valid_int() or args[0].to_int() < 0 or args[0].to_int() > 4:
		return _error("Format: standing <0-4>")
	GameState.stats[&"university_standing"] = args[0].to_int()
	return _ok("Ansehen bei der Universität: %d" % args[0].to_int())


func _cmd_lecture(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: lecture")
	var lectures := _system(&"lectures") as Lectures
	if lectures == null:
		return _error(TEXT_NO_WORLD)
	lectures.invite()
	var cfg := _anatomy()
	var every := maxi(int(cfg.lecture.get("every_days", 3)), 1)
	var start := int(cfg.lecture.get("start", 1380))
	if not lectures.tonight():
		var day := TimeManager.day
		while day % every != 0:
			day += 1
		if day == TimeManager.day and TimeManager.minute_of_day < start:
			TimeManager.set_time(day, start)
		elif day != TimeManager.day:
			TimeManager.advance((day - TimeManager.day) * TimeManager.MINUTES_PER_DAY)
			TimeManager.set_time(TimeManager.day, start)
	return _ok("Vorlesungsabend: Tag %d, %s – eingeladen. %s" % [TimeManager.day, TimeManager.format_clock(), lectures.night_line()])


func _cmd_rumor(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or not args[0].to_lower() in ["on", "off"]:
		return _error("Format: rumor <on|off>")
	var lectures := _system(&"lectures") as Lectures
	if lectures == null:
		return _error(TEXT_NO_WORLD)
	var want := args[0].to_lower() == "on"
	var night := lectures.tonight_day() if lectures.tonight_day() > 0 else TimeManager.day
	var rep := _system(&"reputation") as Reputation
	var tier := rep.tier() if rep != null else &"respected"
	for s: int in 500:
		if LectureRules.rumor(night, s, tier, _anatomy()) == want:
			lectures.seed = s
			return _ok("Gerede heute Nacht: %s (Seed %d)." % ["ja" if want else "nein", s])
	return _error("Kein passender Seed gefunden.")


func _cmd_cards(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: cards <corpse|table>")
	var d := _system(&"deductions") as Deductions
	if d == null:
		return _error(TEXT_NO_WORLD)
	var id := _corpse_arg(args[0])
	var lines := PackedStringArray()
	for card: String in d.cards(id):
		var c := Phase7Texts.card(card)
		lines.append("%s · %s · %s" % [card, str(c.kind_word), str(c.text) if str(c.text) != "" else str(c.title)])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine Karten für %s." % id)


func _cmd_deduce(args: PackedStringArray) -> Dictionary:
	if args.size() != 2:
		return _error("Format: deduce <corpse|table> <cause>")
	var d := _system(&"deductions") as Deductions
	if d == null:
		return _error(TEXT_NO_WORLD)
	var id := _corpse_arg(args[0])
	var cause := StringName(args[1].to_lower())
	var held := d.cards(id)
	for data: Resource in Database.deductions():
		var dd := data as DeductionData
		if dd == null or dd.cause_id != cause:
			continue
		var chosen := PackedStringArray()
		for need: StringName in dd.needs_all:
			if held.has(String(need)):
				chosen.append(String(need))
		for any: StringName in dd.needs_any:
			if held.has(String(any)):
				chosen.append(String(any))
				break
		while chosen.size() < DeductionRules.MIN_CARDS and chosen.size() < held.size():
			for c: String in held:
				if not chosen.has(c):
					chosen.append(c)
					break
		var r := d.deduce(id, chosen, cause)
		if bool(r.get("ok", false)):
			return _ok("Gedeutet: %s – %s" % [Phase7Texts.cause_label(cause), str(r.get("text", ""))])
	return _error(DeductionRules.TEXT_NO_MATCH)


func _cmd_teach(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: teach <l_id|all>")
	var lectures := _system(&"lectures") as Lectures
	if lectures == null:
		return _error(TEXT_NO_WORLD)
	var ids: Array[StringName] = []
	if args[0].to_lower() == "all":
		for res: Resource in Database.teachings():
			if res is TeachingData:
				ids.append((res as TeachingData).id)
	else:
		ids.append(StringName(args[0]))
	for t: StringName in ids:
		lectures.learn(t)
	return _ok("Lehrsätze: %s" % ", ".join(lectures.known_teachings()))


func _cmd_medicine(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: medicine <antidote|bitter_drops|dropsy_powder>")
	var med := Database.medicine(StringName(args[0].to_lower())) as MedicineData
	var inv := _lookup.inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	if med == null:
		return _error("Unbekannte Arznei '%s'." % args[0])
	var n := maxi(med.amount, 1)
	var rest := inv.add_item(med.output, n)
	GameState.add_stat(&"medicines_made", 1)
	return _ok("%d × %s" % [n - rest, UIKit.item_name(med.output)])


func _cmd_hidden(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: hidden <cause>")
	var record := _table_record()
	if record == null:
		return _error("Auf dem Tisch liegt niemand." if _system(&"corpse_manager") != null else TEXT_NO_WORLD)
	record.hidden_cause = StringName(args[0].to_lower()) if args[0].to_lower() != "none" else &""
	var manager := _system(&"corpse_manager") as CorpseManager
	manager.notify_changed(record.id)
	return _ok("%s: verborgene Ursache %s" % [record.display_name, record.hidden_cause if record.hidden_cause != &"" else &"keine"])


# --- views ----------------------------------------------------------------------------------------

func _cmd_npclod(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: npclod")
	var lod := _system(&"npc_lod") as NpcLod
	var p := _lookup.player()
	if lod == null or p == null:
		return _error(TEXT_NO_WORLD)
	var removed := 0
	var shown := PackedStringArray()
	for node: Node in p.get_tree().get_nodes_in_group(&"npc"):
		var npc := node as Npc
		if npc == null:
			continue
		var tag := npc.get_node_or_null(NodePath(String(LOD_TAG))) as Label3D
		if tag != null:
			tag.queue_free()
			removed += 1
			continue
		var level := lod.lod_of(npc)
		tag = Label3D.new()
		tag.name = LOD_TAG
		tag.text = "LOD %d" % level
		tag.position = Vector3(0.0, 2.6, 0.0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = LOD_COLORS[clampi(level, 0, 2)]
		tag.font_size = 40
		tag.pixel_size = 0.005
		npc.add_child(tag)
		shown.append("%s %d" % [npc.npc_id, level])
	if removed > 0 and shown.is_empty():
		return _ok("LOD-Anzeige aus.")
	return _ok("LOD: %s" % " · ".join(shown))


func _cmd_vis7(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: vis7")
	var p := _lookup.player() as Node3D
	if p == null:
		return _error(TEXT_NO_WORLD)
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return _error("Keine Kamera.")
	var space := cam.get_world_3d().direct_space_state
	var lines := PackedStringArray()
	for node: Node in p.get_tree().root.find_children("*", "Node3D", true, false):
		if not (node is HouseDoor or node is ShopCounter or node is VillageBoard or node is RegionPortal):
			continue
		var n3 := node as Node3D
		if not n3.is_visible_in_tree():
			continue
		var to := n3.global_position + Vector3(0.0, VIS_HEIGHT, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, to))
		var blocker := ""
		if not hit.is_empty():
			var collider := hit.get("collider") as Node
			if collider != null and collider != n3 and not n3.is_ancestor_of(collider):
				blocker = str(collider.name)
		lines.append("%s: %s" % [n3.name, "frei" if blocker == "" else "verdeckt von " + blocker])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine Dorf-Ziele im Bild.")


func _cmd_goal7(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: goal7")
	var v := _system(&"village") as Village
	if v == null:
		return _error(TEXT_NO_WORLD)
	var g := v.goal_progress()
	return _ok("Ein Name im Dorf %d/%d · geweiht %s · Aufträge %d/%d (%d/%d Auftraggeber) · vertraut %d/%d · „Vorher eingetragen“ %s%s" % [
			int(g.done), int(g.total), _yes(bool(g.consecrated)), int(g.orders_done), int(g.orders_goal), int(g.orders_givers),
			int(g.givers_goal), int(g.trusted), int(g.trusted_goal), _yes(bool(g.insight)),
			" · erreicht" if GameState.flag_on(&"name_in_village_complete") else ""])


# --- helpers ----------------------------------------------------------------------------------

func _system(group: StringName) -> Node:
	return _lookup.group_node(group)


func _anatomy() -> AnatomyConfig:
	var sp := _system(&"specimens") as Specimens
	if sp != null:
		return sp.get_config()
	var cfg := Database.config(&"anatomy_config") as AnatomyConfig
	return cfg if cfg != null else AnatomyConfig.new()


## The corpse on a table (the crypt table first).
func _table_record() -> CorpseRecord:
	var manager := _system(&"corpse_manager") as CorpseManager
	if manager == null:
		return null
	var other: CorpseRecord = null
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			if r.room == &"crypt":
				return r
			if other == null:
				other = r
	return other


func _corpse_arg(raw: String) -> String:
	if raw.to_lower() == "table":
		var r := _table_record()
		return r.id if r != null else ""
	return raw


func _shelf() -> CollectionShelf:
	var p := _lookup.player()
	if p == null:
		return null
	for node: Node in p.get_tree().get_nodes_in_group(&"saveable"):
		if node is CollectionShelf:
			return node as CollectionShelf
	return null


func _scratch(items: Dictionary) -> Inventory:
	var inv := Inventory.new()
	inv.slot_count = 16
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))
	return inv


static func _yes(on: bool) -> String:
	return "ja" if on else "nein"


static func _ok(text: String) -> Dictionary:
	return DebugCommands.result(true, text)


static func _error(text: String) -> Dictionary:
	return DebugCommands.result(false, text)
