class_name DebugCommandsPhase6
extends RefCounted
## Phase-6 commands of the debug console (docs/PHASE6_DESIGN.md §6), dispatched by
## DebugCommands.run(): buildings open, build/building <crypt|chapel|shed|all> [1-3], lift, reinter,
## service, devotion, room, niche fill, cold, candles, mourners, passage, vis, goal6 and the tp
## targets crypt|chapel|shed. Every command goes through the public API of the system (found by its
## group); without the system: "Keine Spielwelt geladen.". Returns {ok, text}.
## build: the same rules as the site (one level after the other, every side effect of
## Buildings.upgrade – the table moves down on crypt 1, cold windows restart …) but without material
## or time: the costs come from a scratch inventory (the coins count in the coin ledger as
## „building", like a real build).

const COMMANDS: PackedStringArray = ["buildings", "building", "lift", "reinter", "service", "devotion", "room", "niche", "cold",
		"candles", "mourners", "passage", "vis", "goal6"]
const BUILDING_IDS: Array[StringName] = [&"crypt", &"chapel", &"shed"]
const HELP: PackedStringArray = [
	"buildings open – Gebäude sofort freischalten (Bauplätze, Kirchpforte, Altgräber)",
	"build <crypt|chapel|shed|all> [1-3] · building <id> <stufe> – Gebäude sofort auf Stufe (ohne Material/Zeit)",
	"lift <old_id|all> – Altgrab sofort heben · reinter [all] – Gebeine sofort beisetzen",
	"service – Katafalk-Leiche sofort aussegnen · devotion <grave_id> – Andacht sofort",
	"room <hut|crypt|chapel|shed|out> – in einen Raum / hinaus · tp <crypt|chapel|shed> – vor die Tür",
	"niche fill [n] – Testleichen in die Nischen · cold – Kältefaktoren und -fenster der Leichen",
	"candles <n> – Altarkerzen setzen · mourners <0-4> – Trauergäste zeigen · passage – Gang/Gitter",
	"vis – Sichtprüfung der Gebäude (Kamerastrahlen) · goal6 – Kapitel „Unter Dach und Erde“",
]
const TEXT_NO_WORLD := "Keine Spielwelt geladen."
const BUILDINGS_GROUP := &"buildings"
const OSSUARY_GROUP := &"ossuary"
const CHAPEL_GROUP := &"chapel_rites"
const MANAGER_GROUP := &"corpse_manager"
const GRAVEYARD_GROUP := &"graveyard"
const MOURNERS_GROUP := &"mourner_set"
const CATAFALQUE_GROUP := &"catafalque"
const CANDLE := &"altar_candle"
const MAX_CANDLES := 99
const ROOMS: Array[StringName] = [&"hut", &"crypt", &"chapel", &"shed"]
## tp target -> [waypoint id, fallback position (§4.6)].
const TP_TARGETS: Dictionary[String, Array] = {
	"crypt": [&"tp_crypt", Vector3(-9.0, 0.0, 8.9)],
	"chapel": [&"tp_chapel", Vector3(4.5, 0.0, -21.0)],
	"shed": [&"tp_shed", Vector3(-12.9, 0.0, -6.4)],
}
## Height of the door point of the visibility check (§4.5: door centre 1.2 m).
const VIS_DOOR_HEIGHT := 1.2

var _lookup: DebugWorldLookup


func _init(lookup: DebugWorldLookup) -> void:
	_lookup = lookup


func handles(command: String) -> bool:
	return command in COMMANDS


## Phase 6 takes "build" when its first argument names a building (or "all" with a level).
static func takes_build(args: PackedStringArray) -> bool:
	if args.is_empty():
		return false
	var first := args[0].to_lower()
	return StringName(first) in BUILDING_IDS or (first == "all" and args.size() >= 2)


func run(command: String, args: PackedStringArray) -> Dictionary:
	match command:
		"buildings":
			return _cmd_buildings(args)
		"build", "building":
			return _cmd_build(args)
		"lift":
			return _cmd_lift(args)
		"reinter":
			return _cmd_reinter(args)
		"service":
			return _cmd_service(args)
		"devotion":
			return _cmd_devotion(args)
		"room":
			return _cmd_room(args)
		"niche":
			return _cmd_niche(args)
		"cold":
			return _cmd_cold(args)
		"candles":
			return _cmd_candles(args)
		"mourners":
			return _cmd_mourners(args)
		"passage":
			return _cmd_passage(args)
		"vis":
			return _cmd_vis(args)
		"goal6":
			return _cmd_goal6(args)
	return _error("?")


func tp_targets() -> PackedStringArray:
	return PackedStringArray(TP_TARGETS.keys())


## tp crypt|chapel|shed: the layout's waypoint, else the contract position. null = unknown.
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

func _cmd_buildings(args: PackedStringArray) -> Dictionary:
	if args.size() != 1 or args[0].to_lower() != "open":
		return _error("Format: buildings open")
	var b := _buildings()
	if b == null:
		return _error(TEXT_NO_WORLD)
	var cfg := b.buildings_config()
	GameState.set_flag(cfg.unlock_flag, true)
	if not b.is_open():
		b.open()
	b.apply_levels()
	return _ok("Gebäude offen: Bauplätze, Kirchpforte und Altgräber sind da.")


func _cmd_build(args: PackedStringArray) -> Dictionary:
	var b := _buildings()
	if b == null:
		return _error(TEXT_NO_WORLD)
	if args.is_empty() or args.size() > 2:
		return _error("Format: build <crypt|chapel|shed|all> [1-3]")
	var target := args[0].to_lower()
	var wanted: Array[StringName] = []
	if target == "all":
		wanted.assign(BUILDING_IDS)
	elif StringName(target) in BUILDING_IDS:
		wanted.append(StringName(target))
	else:
		return _error("Unbekanntes Gebäude '%s' – crypt, chapel, shed oder all." % args[0])
	var goal := -1
	if args.size() == 2:
		if not args[1].is_valid_int() or int(args[1]) < 0 or int(args[1]) > 3:
			return _error("Stufe 0 bis 3.")
		goal = int(args[1])
	if not b.is_open():
		GameState.set_flag(b.buildings_config().unlock_flag, true)
		b.open()
	var parts := PackedStringArray()
	for id: StringName in wanted:
		var data := b.building(id)
		if data == null:
			return _error("Die Welt kennt das Gebäude '%s' nicht." % id)
		var top := goal if goal >= 0 else mini(b.level(id) + 1, data.max_level())
		if top < b.level(id):
			return _error("%s steht schon auf Stufe %d – zurückbauen geht nicht." % [data.display_name, b.level(id)])
		while b.level(id) < top:
			if not _upgrade_free(b, id):
				return _error("%s: Stufe %d ließ sich nicht bauen." % [data.display_name, b.level(id) + 1])
		parts.append("%s %d" % [Phase6Texts.SHORT_NAMES.get(id, String(id)), b.level(id)])
	return _ok("Gebäude: %s" % " · ".join(parts))


func _cmd_lift(args: PackedStringArray) -> Dictionary:
	var ossuary := _ossuary()
	var graveyard := _lookup.group_node(GRAVEYARD_GROUP) as Graveyard
	var inv := _lookup.inventory()
	if ossuary == null or graveyard == null or inv == null:
		return _error(TEXT_NO_WORLD)
	if args.size() != 1:
		return _error("Format: lift <old_id|all>")
	var ids := PackedStringArray()
	if args[0].to_lower() == "all":
		for g: GraveRecord in graveyard.graves():
			if g.state == GraveRecord.State.OLD and ossuary.data_of(g.id) != null:
				ids.append(g.id)
	else:
		ids.append(args[0].to_lower())
	var lifted := PackedStringArray()
	var cfg := ossuary.rules()
	for id: String in ids:
		var added := inv.count(cfg.box_item) <= 0
		if added:
			inv.add_item(cfg.box_item, 1)
		var reason := ossuary.lift_block_reason(id, inv)
		if reason != "" or not ossuary.lift(id, inv):
			if added:
				inv.remove_item(cfg.box_item, 1)
			if args[0].to_lower() != "all":
				return _error("%s: %s" % [id, reason if reason != "" else "Heben fehlgeschlagen."])
			continue
		lifted.append(id)
	if lifted.is_empty():
		return _error("Kein Altgrab gehoben (Ruhezeit, Beinhaus voll oder Gruft verschüttet).")
	return _ok("Gehoben: %s · wartend im Beinhaus: %d" % [", ".join(lifted), ossuary.pending().size()])


func _cmd_reinter(args: PackedStringArray) -> Dictionary:
	var ossuary := _ossuary()
	var inv := _lookup.inventory()
	if ossuary == null or inv == null:
		return _error(TEXT_NO_WORLD)
	if args.size() > 1 or (args.size() == 1 and args[0].to_lower() != "all"):
		return _error("Format: reinter [all]")
	var all := args.size() == 1
	var done := PackedStringArray()
	var cfg := ossuary.rules()
	while not ossuary.pending().is_empty():
		if inv.count(cfg.full_item) <= 0:
			inv.add_item(cfg.full_item, 1)
		var id := ossuary.reinter(inv)
		if id == "":
			break
		done.append(id)
		if not all:
			break
	if done.is_empty():
		return _error("Keine Gebeine warten auf die Beisetzung.")
	return _ok("Beigesetzt: %s · umgebettet gesamt: %d" % [", ".join(done), ossuary.reinterred().size()])


func _cmd_service(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: service")
	var rites := _rites()
	var inv := _lookup.inventory()
	var catafalque := _lookup.group_node(CATAFALQUE_GROUP) as Catafalque
	if rites == null or inv == null:
		return _error(TEXT_NO_WORLD)
	var id := catafalque.occupant() if catafalque != null else ""
	if id == "":
		return _error(ChapelRules.TEXT_NO_CORPSE)
	var cfg := rites.get_config()
	if inv.count(cfg.candle_item) < cfg.candle_amount:
		inv.add_item(cfg.candle_item, cfg.candle_amount)
	var fee := rites.hold_service(id, inv)
	if fee < 0:
		return _error(rites.service_block_reason(id, inv))
	return _ok("Ausgesegnet: %s · Gebühr %d" % [id, fee])


func _cmd_devotion(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _error("Format: devotion <grave_id>")
	var rites := _rites()
	var inv := _lookup.inventory()
	if rites == null or inv == null:
		return _error(TEXT_NO_WORLD)
	var cfg := rites.get_config()
	if inv.count(cfg.candle_item) < cfg.candle_amount:
		inv.add_item(cfg.candle_item, cfg.candle_amount)
	var id := args[0]
	var reason := rites.devotion_block_reason(id, inv)
	if reason != "" or not rites.hold_devotion(id, inv):
		return _error("%s: %s" % [id, reason])
	return _ok("Andacht für %s (Stufe %d, Stimmung +%d)" % [id, rites.devotion_level(id), rites.devotion_bonus(id)])


func _cmd_room(args: PackedStringArray) -> Dictionary:
	var p := _lookup.player() as Player
	if p == null:
		return _error(TEXT_NO_WORLD)
	if args.size() != 1:
		return _error("Format: room <hut|crypt|chapel|shed|out>")
	var target := StringName(args[0].to_lower())
	if target == &"out":
		var door := BuildingDoor.find(p.get_tree(), p.interior_id) if p.interior_id != &"" and p.interior_id != &"hut" else null
		var at: Vector3 = door.exit_transform().origin if door != null else p.global_position
		if door == null:
			var hut_door := _lookup.world().call(&"get_node_by_layout_id", "hut_door") as Node3D if _lookup.world() != null else null
			at = hut_door.global_position + Vector3(0.0, 0.0, 1.4) if hut_door != null else Vector3.ZERO
		_lookup.teleport_player(p, at)
		return _ok("Draußen (%.1f, %.1f)" % [at.x, at.z])
	if not target in ROOMS:
		return _error("Unbekannter Raum '%s' – hut, crypt, chapel, shed oder out." % args[0])
	var room := InteriorRoom.find(p.get_tree(), target)
	if room == null:
		return _error("Die Welt hat keinen Raum '%s'." % target)
	HutPortal.arrive(p, room.spawn_transform(), true, target)
	var rig := _lookup.camera_rig()
	if rig != null:
		rig.snap()
	return _ok("Im Raum: %s" % target)


func _cmd_niche(args: PackedStringArray) -> Dictionary:
	if args.is_empty() or args[0].to_lower() != "fill" or args.size() > 2 or (args.size() == 2 and not args[1].is_valid_int()):
		return _error("Format: niche fill [n]")
	var manager := _lookup.group_node(MANAGER_GROUP) as CorpseManager
	if manager == null:
		return _error(TEXT_NO_WORLD)
	var want := int(args[1]) if args.size() == 2 else 6
	var filled := PackedStringArray()
	for node: Node in manager.get_tree().get_nodes_in_group(CryptNiche.GROUP):
		var niche := node as CryptNiche
		if niche == null or not niche.is_open() or niche.occupant() != "" or filled.size() >= want:
			continue
		var slot := niche.slot_node()
		var xform := slot.global_transform if slot != null else niche.global_transform
		var record := manager.spawn_corpse(null, xform, CorpseRecord.LOCATION_GROUND)
		if record == null:
			return _error("Keine Testleiche (Leichentabellen fehlen).")
		manager.put_down(record.id, CorpseRecord.LOCATION_NICHE, xform, null, niche.room(), niche.slot_id)
		filled.append(niche.slot_id)
	if filled.is_empty():
		return _error("Keine offene, freie Nische (Gruft-Stufe?).")
	return _ok("Nischen belegt: %s" % ", ".join(filled))


func _cmd_cold(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: cold")
	var manager := _lookup.group_node(MANAGER_GROUP) as CorpseManager
	if manager == null:
		return _error(TEXT_NO_WORLD)
	var lines := PackedStringArray()
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_BURIED:
			continue
		var windows := PackedStringArray()
		for i: int in range(0, r.cold_windows.size() - 2, 3):
			windows.append("[%d–%s ×%.2f]" % [r.cold_windows[i], "offen" if r.cold_windows[i + 1] < 0 else str(r.cold_windows[i + 1]),
					float(r.cold_windows[i + 2]) / 1000.0])
		lines.append("%s %s/%s%s · × %.2f · Frische %d %% %s" % [r.id, r.location, r.room if r.room != &"" else "-",
				(" " + r.slot_id) if r.slot_id != "" else "", manager.cold_factor_for(r.location, r.room), roundi(r.freshness * 100.0),
				" ".join(windows)])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine unbestattete Leiche.")


func _cmd_candles(args: PackedStringArray) -> Dictionary:
	var inv := _lookup.inventory()
	if inv == null:
		return _error(TEXT_NO_WORLD)
	if args.size() != 1 or not args[0].is_valid_int() or int(args[0]) < 0 or int(args[0]) > MAX_CANDLES:
		return _error("Format: candles <0-%d>" % MAX_CANDLES)
	var want := int(args[0])
	var have := inv.count(CANDLE)
	if want > have:
		var rest := inv.add_item(CANDLE, want - have)
		if rest > 0:
			return _error("Kein Platz: %d Kerzen passten nicht." % rest)
	elif want < have:
		inv.remove_item(CANDLE, have - want)
	return _ok("Altarkerzen: %d" % inv.count(CANDLE))


func _cmd_mourners(args: PackedStringArray) -> Dictionary:
	var set := _lookup.group_node(MOURNERS_GROUP) as MournerSet
	if set == null:
		return _error(TEXT_NO_WORLD)
	if args.size() != 1 or not args[0].is_valid_int() or int(args[0]) < 0 or int(args[0]) > 4:
		return _error("Format: mourners <0-4>")
	var n := int(args[0])
	if n == 0:
		set.hide_mourners()
	else:
		set.show_mourners(n)
	return _ok("Trauergäste: %d" % n)


func _cmd_passage(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: passage")
	var ossuary := _ossuary()
	if ossuary == null:
		return _error(TEXT_NO_WORLD)
	return _ok("Gang: %s · angesehen: %s · Beinhaus %d/%d" % [ossuary.passage_state(),
			"ja" if GameState.flag_on(&"c_crypt_draft_seen") else "nein", ossuary.used(), ossuary.capacity()])


## §4.5 in the running game, simplified: a physics ray from the camera to each building's door
## (1.2 m) – free or the first collider in the way (text only; the full AABB check is the world test).
func _cmd_vis(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: vis")
	var rig := _lookup.camera_rig()
	var p := _lookup.player() as Node3D
	if rig == null or p == null:
		return _error(TEXT_NO_WORLD)
	var cam := p.get_viewport().get_camera_3d()
	if cam == null:
		return _error("Keine Kamera.")
	var space := cam.get_world_3d().direct_space_state
	var lines := PackedStringArray()
	for node: Node in p.get_tree().get_nodes_in_group(BuildingSite.GROUP):
		var site := node as BuildingSite
		if site == null:
			continue
		var to := site.global_position + Vector3(0.0, VIS_DOOR_HEIGHT, 0.0)
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, to)
		var hit := space.intersect_ray(query)
		var blocker := ""
		if not hit.is_empty():
			var collider := hit.get("collider") as Node
			if collider != null and not site.is_ancestor_of(collider) and collider != site:
				blocker = str(collider.name)
		lines.append("%s: %s" % [site.building_id, "frei" if blocker == "" else "verdeckt von " + blocker])
	return _ok("\n".join(lines) if not lines.is_empty() else "Keine Bauplätze in der Welt.")


func _cmd_goal6(args: PackedStringArray) -> Dictionary:
	if not args.is_empty():
		return _error("Format: goal6")
	var b := _buildings()
	if b == null:
		return _error(TEXT_NO_WORLD)
	var progress := b.goal_progress()
	var done: bool = GameState.flag_on(b.buildings_config().goal_flag)
	return _ok("%s · %d/%d%s" % [Phase6Texts.chapter_line(progress), int(progress.done), int(progress.total), " · erreicht" if done else ""])


# --- helpers ----------------------------------------------------------------------------------

## One level up by the rules (Buildings.upgrade) with the costs from a scratch inventory.
func _upgrade_free(b: Buildings, id: StringName) -> bool:
	var next := BuildingRules.next_level(b.building(id), b.level(id))
	if next == null:
		return false
	var purse := Inventory.new()
	purse.slot_count = 32
	for item: Variant in BuildingRules.cost(next):
		purse.add_item(StringName(str(item)), int(BuildingRules.cost(next)[item]))
	var ok := b.upgrade(id, purse)
	purse.free()
	return ok


func _buildings() -> Buildings:
	return _lookup.group_node(BUILDINGS_GROUP) as Buildings


func _ossuary() -> Ossuary:
	return _lookup.group_node(OSSUARY_GROUP) as Ossuary


func _rites() -> ChapelRites:
	return _lookup.group_node(CHAPEL_GROUP) as ChapelRites


func _ok(text: String) -> Dictionary:
	return DebugCommands.result(true, text)


func _error(text: String) -> Dictionary:
	return DebugCommands.result(false, text)
