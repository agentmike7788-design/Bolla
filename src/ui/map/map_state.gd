class_name MapState
extends RefCounted
## The live part of the map (read-only snapshot of the systems, built when the map opens): where the
## gravekeeper is (region, room, position, heading), the people he knows, the sections and graves, the
## open orders with their place, the flags of the tabs and the shops' opening hours. Missing systems
## simply leave their part empty (headless tests, the title screen).
## Context keys: region, room, player {world: Vector3, heading: float} | {}, flags {flag: bool},
## sections {id: {name, unlocked, known}}, graves {grave_id: &"free" | &"taken" | &"tended" | &"locked"},
## people [{id, name, kind, region, world: Vector3}], orders [{id, title, region, place, giver}],
## shops {shop_id: {open: bool, hours: Array[Vector2i], keeper: String}}, minute, building_levels {id: level}.
## Phase 8 (docs/PHASE8_DESIGN.md §7.8): p8 {marks, grave_info} (MapStatePhase8) – visitors, Jakob, wishes, coins on
## the stone, Hanne, Veit, the sick light, the festival, disturbed graves; never the night digger.

const PLAYER_GROUP := &"player"
const EXPANSION_GROUP := &"expansion"
const GRAVEYARD_GROUP := &"graveyard"
const RELATIONSHIPS_GROUP := &"relationships"
const ORDERS_GROUP := &"orders"
const SHOPS_GROUP := &"village_shops"
const NPC_GROUP := &"npc"
const BUILDINGS_GROUP := &"buildings"
const ACTIVITY_SHOP := &"shop"
const GRAVE_FREE := &"free"
const GRAVE_TAKEN := &"taken"
const GRAVE_TENDED := &"tended"
const GRAVE_LOCKED := &"locked"
const KIND_VILLAGER := &"villager"
## Order kinds whose place is on the graveyard.
const GRAVEYARD_KINDS: Array[StringName] = [&"bury", &"stone", &"tend", &"section"]


static func context(tree: SceneTree, cfg: MapConfig) -> Dictionary:
	var ctx := {"region": &"graveyard", "room": &"", "player": {}, "flags": flags(cfg), "sections": {},
			"graves": {}, "people": [], "orders": [], "shops": {}, "minute": TimeManager.minute_of_day}
	if tree == null:
		return ctx
	var player := tree.get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player != null:
		var region: Variant = player.get(&"region_id")
		ctx.region = StringName(str(region)) if region != null and str(region) != "" else &"graveyard"
		var inside: Variant = player.get(&"in_interior")
		var room: Variant = player.get(&"interior_id")
		ctx.room = StringName(str(room)) if inside == true and room != null else &""
		if ctx.room != &"" and cfg.room_regions.has(ctx.room):
			ctx.region = cfg.room_regions[ctx.room]
		ctx.player = {"world": player.global_position if player.is_inside_tree() else player.position,
				"heading": player.rotation.y}
	ctx.sections = sections(tree)
	ctx.graves = graves(tree)
	ctx.people = people(tree, cfg)
	ctx.orders = orders(tree, cfg)
	ctx.shops = shops(tree)
	ctx["p8"] = MapStatePhase8.context(tree)
	var buildings := tree.get_first_node_in_group(BUILDINGS_GROUP) as Buildings
	if buildings != null:
		var levels := {}
		for id: StringName in buildings.levels():
			levels[String(id)] = buildings.level(id)
		ctx["building_levels"] = levels
	return ctx


## The flags the map asks for (tabs, buildings, hidden sections).
static func flags(cfg: MapConfig) -> Dictionary:
	var out := {}
	var names: Array[StringName] = [cfg.buildings_flag]
	for region: StringName in cfg.tab_flags:
		names.append(cfg.tab_flags[region])
	for s: Resource in Database.sections():
		var f: Variant = s.get(&"requires_flag")
		if f != null and StringName(str(f)) != &"":
			names.append(StringName(str(f)))
	for f: StringName in names:
		if f != &"":
			out[f] = GameState.flag_on(f)
	return out


## {id: {name, unlocked, known (requires_flag on or none), requires_flag}} of every section.
static func sections(tree: SceneTree) -> Dictionary:
	var out := {}
	var expansion := tree.get_first_node_in_group(EXPANSION_GROUP) as ExpansionManager
	var list: Array = expansion.sections() if expansion != null else Database.sections()
	for raw: Variant in list:
		var s := raw as SectionData
		if s == null:
			continue
		var unlocked := expansion.is_unlocked(s.id) if expansion != null else s.starts_unlocked
		out[s.id] = {"name": s.display_name, "unlocked": unlocked, "requires_flag": s.requires_flag,
				"known": s.requires_flag == &"" or GameState.flag_on(s.requires_flag), "burial": s.is_burial}
	return out


## grave_id → free (open or dug) · taken (filled, old) · tended (marked) · locked.
static func graves(tree: SceneTree) -> Dictionary:
	var out := {}
	var graveyard := tree.get_first_node_in_group(GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	for g: GraveRecord in graveyard.call(&"graves"):
		out[g.id] = grave_kind(g.state)
	return out


static func grave_kind(state: GraveRecord.State) -> StringName:
	match state:
		GraveRecord.State.EMPTY, GraveRecord.State.DUG:
			return GRAVE_FREE
		GraveRecord.State.MARKED:
			return GRAVE_TENDED
		GraveRecord.State.LOCKED:
			return GRAVE_LOCKED
	return GRAVE_TAKEN


## Present Npcs the gravekeeper knows: villagers once met (Relationships), the always known ones
## (MapConfig.known_people: Osric, Ilse once her flag lets her appear). Unknown villagers are left out.
static func people(tree: SceneTree, cfg: MapConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rel := tree.get_first_node_in_group(RELATIONSHIPS_GROUP) as Relationships
	for node: Node in tree.get_nodes_in_group(NPC_GROUP):
		var npc := node as Npc
		if npc == null or not npc.is_inside_tree() or not npc.is_present() or npc.npc_id in MapStatePhase8.ROBBER_IDS:
			continue
		var kind := &""
		var name := ""
		if cfg.known_people.has(npc.npc_id):
			kind = cfg.known_people[npc.npc_id]
		elif rel != null and rel.met(npc.npc_id):
			kind = KIND_VILLAGER
			var data := rel.villager(npc.npc_id)
			name = data.display_name if data != null else ""
		if kind == &"":
			continue
		if name == "":
			var sched := Database.schedule(npc.npc_id) as NpcSchedule
			name = sched.display_name if sched != null and sched.display_name != "" else String(npc.npc_id)
		out.append({"id": npc.npc_id, "name": name, "kind": kind, "region": npc.region_id,
				"world": npc.global_position, "heading": npc.rotation.y})
	return out


## Accepted orders with the place they are handed in or done at.
static func orders(tree: SceneTree, cfg: MapConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var o_sys := tree.get_first_node_in_group(ORDERS_GROUP) as Orders
	if o_sys == null:
		return out
	for id: StringName in o_sys.active():
		var o := o_sys.order_data(id)
		if o != null:
			out.append(order_place(o, cfg))
	return out


## {id, title, giver, region, place} – deliveries go to the recipient's / giver's place in the village,
## graves / sections to their spot on the graveyard (else MapConfig.burial_fallback_place).
static func order_place(o: OrderData, cfg: MapConfig) -> Dictionary:
	var entry := {"id": o.id, "title": o.title, "giver": o.giver, "region": &"village", "place": ""}
	if o.kind in GRAVEYARD_KINDS:
		entry.region = &"graveyard"
		entry.place = o.target if o.target != "" and o.target != "next_delivery" else cfg.burial_fallback_place
		entry["fallback"] = cfg.burial_fallback_place
	else:
		var who := o.recipient if o.recipient != &"" else o.giver
		entry.place = cfg.npc_places.get(who, "")
	return entry


## shop_id → {open: bool (VillageShops.is_open, else from the schedule), hours: Array[Vector2i] (from, to
## minute of the shop phases), keeper: String}.
static func shops(tree: SceneTree) -> Dictionary:
	var out := {}
	var vs := tree.get_first_node_in_group(SHOPS_GROUP) as VillageShops
	for raw: Resource in Database.shops():
		var s := raw as ShopData
		if s == null:
			continue
		var hours := shop_hours(Database.schedule(s.npc_id) as NpcSchedule)
		var now := TimeManager.minute_of_day
		var open := false
		if vs != null:
			open = vs.is_open(s.id)
		else:
			for h: Vector2i in hours:
				open = open or (now >= h.x and now < h.y)
		var villager := Database.villager(s.npc_id) as VillagerData
		out[s.id] = {"open": open, "hours": hours, "keeper": villager.display_name if villager != null else "",
				"title": s.title, "npc_id": s.npc_id}
	return out


## The shop phases of a schedule: [Vector2i(arrived, next phase start)] sorted by start (today's entries,
## without consecration-day extras).
static func shop_hours(sched: NpcSchedule) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if sched == null:
		return out
	var entries: Array[ScheduleEntry] = []
	for e: ScheduleEntry in sched.entries:
		if e != null and e.today_flag == &"":
			entries.append(e)
	entries.sort_custom(func(a: ScheduleEntry, b: ScheduleEntry) -> bool: return a.start_minute < b.start_minute)
	for i: int in entries.size():
		var e := entries[i]
		if e.activity != ACTIVITY_SHOP or not e.visible:
			continue
		var end := entries[i + 1].start_minute if i + 1 < entries.size() else TimeManager.MINUTES_PER_DAY
		var from := e.start_minute + e.travel_minutes
		if end > from:
			out.append(Vector2i(from, end))
	return out
