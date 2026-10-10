class_name Phase8Status
extends RefCounted
## Read-only snapshots of the Phase-8 systems for the UI (docs/PHASE8_DESIGN.md §7): the objective state
## (ObjectiveResolver world.p8 → Phase8Texts.objective), the per-grave care info (grave tooltip on the map,
## the register column), the next visit of a kin and the most urgent open wish. Every system is found by
## its group; a missing one leaves its part empty (headless tests, Phase-7 worlds).

const NPC_LIFE_GROUP := &"npc_life"
const VISITORS_GROUP := &"visitors"
const GRAVE_CARE_GROUP := &"grave_care"
const APPRENTICE_GROUP := &"apprentice"
const BOX_GROUP := &"apprentice_box"
const FRIENDSHIP_GROUP := &"friendship"
const FESTIVALS_GROUP := &"festivals"
const WANDERERS_GROUP := &"wanderers"
const NIGHT_PATHS_GROUP := &"night_paths"
const JOURNAL_GROUP := &"journal"
const GRAVEYARD_GROUP := &"graveyard"
const MANAGER_GROUP := &"corpse_manager"
const ORDERS_GROUP := &"orders"
const PLAYER_GROUP := &"player"
const OPEN_FLAG := &"p8_open"
const INTRO_FLAG := &"p8_intro"
const GOAL_FLAG := &"who_comes_up_complete"
const INNKEEPER := &"innkeeper"
const MAYOR := &"mayor"
const TEACH_ORDER: Array[StringName] = [&"rake", &"weed", &"water"]
const CLUE_VEIT := &"c_n_veit"
const OBSERVE_CLUES: Array[StringName] = [&"c_n_quast_visit", &"c_n_lenz_visit", &"c_n_liesel_watch"]
## The sick light counts for the objective line from 20:00 until 05:00.
const SICK_FROM := 1200
const SICK_UNTIL := 300
## Hanne's places and until when she stands there (Wanderers.PEDDLER_WELL / PEDDLER_GATE).
const PEDDLER_UNTIL: Dictionary[StringName, int] = {&"v_well_peddler": 840, &"peddler_gate": 980}
## Fenner's place with a view (story step 2, of_fenner_2 → l_12).
const RESERVED: Dictionary[String, Array] = {"l_12": [&"of_fenner_2", &"mayor", 2]}
const CAL_PEDDLER_TODAY := "Hanne Vogelsang: heute da"
const CAL_PEDDLER := "Hanne Vogelsang: nächster Besuch in %d %s"
const CAL_PEDDLER_TOMORROW := "Hanne Vogelsang: nächster Besuch morgen"
const CAL_FEST := "%s: %s"


static func is_open() -> bool:
	return GameState.flag_on(OPEN_FLAG)


## {} before p8_open, else the keys Phase8Texts.objective reads (§7.5).
static func objective_state(tree: SceneTree) -> Dictionary:
	if tree == null or not is_open():
		return {}
	var out := {"intro": GameState.flag_on(INTRO_FLAG), "minute": TimeManager.minute_of_day}
	var player := _first(tree, PLAYER_GROUP)
	var on_graveyard := player == null or StringName(str(player.get(&"region_id"))) in [&"graveyard", &""]
	var visitors := _first(tree, VISITORS_GROUP) as Visitors
	if visitors != null and on_graveyard:
		var w := visitors.waiting_visit()
		if not w.is_empty():
			out["waiting"] = Phase8Texts.person_name(StringName(str(w.get("kin_id", ""))))
	var fest := _first(tree, FESTIVALS_GROUP) as Festivals
	if fest != null:
		out["fest_today"] = fest.today()
		if fest.today() == Festivals.LIGHTS:
			out["lights"] = fest.lights_count()
	var app := _first(tree, APPRENTICE_GROUP) as Apprentice
	var hired := app != null and app.is_hired()
	out["hired"] = hired
	var friendship := _first(tree, FRIENDSHIP_GROUP) as Friendship
	out["rosine_ready"] = friendship != null and friendship.step_done(INNKEEPER) == 0 and friendship.offerable_step(INNKEEPER) > 0
	if hired:
		out["board_empty"] = app.board_lines().is_empty()
		var taught := 0
		for task: StringName in Apprentice.TASKS:
			if app.level(task) >= 1:
				taught += 1
		var life_cfg := _life_config(tree)
		if taught < life_cfg.goal_levels:
			for task: StringName in TEACH_ORDER:
				if app.level(task) == 0:
					out["teach"] = task
					break
		var box := _first(tree, BOX_GROUP) as ApprenticeBox
		var cfg := app.config if app.config != null else ApprenticeConfig.new()
		out["tin_empty"] = box != null and box.coins < cfg.wage + app.debt()
	if visitors != null:
		out["wish"] = urgent_wish(tree, visitors)
	var wanderers := _first(tree, WANDERERS_GROUP) as Wanderers
	if wanderers != null:
		var place := wanderers.place(Wanderers.PEDDLER, TimeManager.day, TimeManager.minute_of_day)
		if PEDDLER_UNTIL.has(place):
			out["peddler"] = {"place": place, "until": PEDDLER_UNTIL[place]}
	var journal := _first(tree, JOURNAL_GROUP)
	var veit := journal != null and journal.has_method(&"has_clue") and bool(journal.call(&"has_clue", CLUE_VEIT))
	if veit:
		var observed := false
		for c: StringName in OBSERVE_CLUES:
			observed = observed or bool(journal.call(&"has_clue", c))
		var paths := _first(tree, NIGHT_PATHS_GROUP) as NightPaths
		var m := TimeManager.minute_of_day
		if paths != null and (m >= SICK_FROM or m < SICK_UNTIL):
			var houses := paths.sick_houses(TimeManager.day, m)
			if not houses.is_empty():
				out["sick_light"] = StringName(houses[0])
		out["night_question"] = not observed and not out.has("sick_light")
	out["disturbed"] = not disturbed_graves(tree).is_empty()
	var life := _first(tree, NPC_LIFE_GROUP) as NpcLife
	if life != null:
		var p := life.goal_progress()
		out["goal_parts"] = int(p.get("done", 0))
		out["goal_total"] = int(p.get("total", 4))
	out["goal_done"] = GameState.flag_on(GOAL_FLAG)
	return out


## The open accepted wish whose kin comes back soonest: {kind, name (the dead), days, grave_id, kin_id} | {}.
static func urgent_wish(tree: SceneTree, visitors: Visitors) -> Dictionary:
	var best := {}
	for w: Dictionary in visitors.open_wishes():
		if str(w.get("state", "")) != "accepted":
			continue
		var kin := StringName(str(w.get("kin_id", "")))
		var next := next_visit_day(tree, visitors, kin)
		var days := next - TimeManager.day if next >= 0 else 99
		if best.is_empty() or days < int(best.days):
			var grave := str(w.get("grave_id", ""))
			best = {"kind": StringName(str(w.get("kind", ""))), "name": dead_name(tree, grave), "days": days,
					"grave_id": grave, "kin_id": kin}
	if not best.is_empty() and int(best.days) >= 99:
		best.days = -1
	return best


## The day `kin_id` comes next (today while the visit is planned and not gone; −1 unknown).
static func next_visit_day(tree: SceneTree, visitors: Visitors, kin_id: StringName) -> int:
	if visitors == null:
		return -1
	var today := visitors.visit_of(kin_id)
	if not today.is_empty() and StringName(str(today.get("phase", ""))) != &"gone":
		return TimeManager.day
	var kin := Database.kin(kin_id) as KinData
	if kin == null:
		return -1
	var state := visitors.save_state()
	var open_day := int(GameState.get_flag(&"p8_open_day")) if GameState.has_flag(&"p8_open_day") else TimeManager.day
	var cfg := visitors.config if visitors.config != null else Database.config(&"visitor_config") as VisitorConfig
	if cfg == null:
		cfg = VisitorConfig.new()
	var lights_day := int(GameState.get_flag(&"fest_lights_day")) if GameState.has_flag(&"fest_lights_day") else -1
	var due := -1
	if kin.villager_id != &"":
		var last_kin: Dictionary = state.get("last_kin", {})
		due = VisitRules.villager_due(int(last_kin.get(String(kin_id), -1)), open_day, kin.first_offset, kin.visit_every_days, lights_day)
	else:
		var last: Dictionary = state.get("last_visit", {})
		var dues: Array = []
		for g: String in visitors.graves_of(kin_id):
			dues.append(VisitRules.next_due(g, buried_day(tree, g), int(last.get(g, -1)), open_day, cfg))
		due = VisitRules.household_due(dues)
	if due >= 0 and due <= TimeManager.day:
		due = TimeManager.day + 1
	return due


## The last day `kin_id` looked at one of its graves (−1 = never).
static func last_visit_day(visitors: Visitors, kin_id: StringName) -> int:
	if visitors == null:
		return -1
	var state := visitors.save_state()
	var kin := Database.kin(kin_id) as KinData
	if kin != null and kin.villager_id != &"":
		var last_kin: Dictionary = state.get("last_kin", {})
		return int(last_kin.get(String(kin_id), -1))
	var last: Dictionary = state.get("last_visit", {})
	var best := -1
	for g: String in visitors.graves_of(kin_id):
		best = maxi(best, int(last.get(g, -1)))
	return best


static func buried_day(tree: SceneTree, grave_id: String) -> int:
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"get_grave"):
		return 0
	var g := graveyard.call(&"get_grave", grave_id) as GraveRecord
	if g == null:
		return 0
	var record := corpse_of(tree, g)
	if record != null and record.buried_day > 0:
		return record.buried_day
	return g.completed_day


static func corpse_of(tree: SceneTree, g: GraveRecord) -> CorpseRecord:
	var manager := _first(tree, MANAGER_GROUP)
	if g == null or g.corpse_id == "" or manager == null or not manager.has_method(&"get_record"):
		return null
	return manager.call(&"get_record", g.corpse_id) as CorpseRecord


## The name of the dead in `grave_id` (the grave id when unknown).
static func dead_name(tree: SceneTree, grave_id: String) -> String:
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	var g := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	var r := corpse_of(tree, g)
	return r.display_name if r != null and r.display_name != "" else grave_id


static func disturbed_graves(tree: SceneTree) -> PackedStringArray:
	var out := PackedStringArray()
	var care := _first(tree, GRAVE_CARE_GROUP) as GraveCare
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	if care == null or graveyard == null or not graveyard.has_method(&"graves"):
		return out
	for g: GraveRecord in graveyard.call(&"graves"):
		if care.is_disturbed(g.id):
			out.append(g.id)
	return out


## grave_id → {flowers, fresh_left, bouquet, candle, mortsafe_days, disturbed, kin, goodwill, wish_kind, coins,
## giver, reserved} for every grave something of Phase 8 is to say about ({} before p8_open).
static func grave_info(tree: SceneTree) -> Dictionary:
	var out := {}
	if tree == null or not is_open():
		return out
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	if graveyard == null or not graveyard.has_method(&"graves"):
		return out
	var care := _first(tree, GRAVE_CARE_GROUP) as GraveCare
	var visitors := _first(tree, VISITORS_GROUP) as Visitors
	var wishes := {}
	var stones := PackedStringArray()
	if visitors != null:
		for w: Dictionary in visitors.open_wishes():
			wishes[str(w.get("grave_id", ""))] = StringName(str(w.get("kind", "")))
		stones = visitors.stones()
	for g: GraveRecord in graveyard.call(&"graves"):
		var info := {}
		if care != null:
			var f := care.flowers_state(g.id)
			if f != &"":
				info["flowers"] = f
				info["fresh_left"] = care.fresh_minutes_left(g.id)
			if care.bouquet_fresh(g.id):
				info["bouquet"] = true
			if care.candle_lit(g.id):
				info["candle"] = true
			var ms := care.mortsafe_days(g.id)
			if ms >= 0:
				info["mortsafe_days"] = ms
			if care.is_disturbed(g.id):
				info["disturbed"] = true
		if visitors != null and (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED):
			var kin := visitors.kin_for_grave(g.id)
			if kin != &"":
				info["kin"] = kin
				info["goodwill"] = visitors.goodwill(kin)
		if wishes.has(g.id):
			info["wish_kind"] = wishes[g.id]
		if g.id in stones:
			info["coins"] = visitors.tip_on_stone(g.id).x
			info["giver"] = visitors.tip_giver(g.id)
		var reserved := reserved_by(tree, g.id)
		if reserved != "":
			info["reserved"] = reserved
		if not info.is_empty():
			out[g.id] = info
	return out


## „Fenner" while l_12 is held for him (§7.6: his story step 2), else "".
static func reserved_by(tree: SceneTree, grave_id: String) -> String:
	if not RESERVED.has(grave_id):
		return ""
	var r: Array = RESERVED[grave_id]
	var orders := _first(tree, ORDERS_GROUP) as Orders
	var friendship := _first(tree, FRIENDSHIP_GROUP) as Friendship
	var held := orders != null and orders.state(r[0]) == Orders.STATE_ACCEPTED
	held = held or (friendship != null and friendship.step_done(r[1]) >= int(r[2]))
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	var g := graveyard.call(&"get_grave", grave_id) as GraveRecord if graveyard != null and graveyard.has_method(&"get_grave") else null
	if not held or (g != null and g.state != GraveRecord.State.EMPTY):
		return ""
	return Phase7Texts.short_name(r[1])


## The calendar tooltip of the HUD's day ("" before p8_open): „Hanne Vogelsang: heute da" / „… nächster Besuch in 4
## Tagen", the festivals still to come with their day.
static func calendar_text(tree: SceneTree) -> String:
	if tree == null or not is_open():
		return ""
	var lines := PackedStringArray()
	var wanderers := tree.get_first_node_in_group(WANDERERS_GROUP) as Wanderers
	if wanderers != null:
		if wanderers.peddler_day(TimeManager.day):
			lines.append(CAL_PEDDLER_TODAY)
		else:
			var d := wanderers.next_peddler_day(TimeManager.day) - TimeManager.day
			lines.append(CAL_PEDDLER_TOMORROW if d == 1 else CAL_PEDDLER % [d, "Tag" if d == 1 else "Tagen"])
	var fest := tree.get_first_node_in_group(FESTIVALS_GROUP) as Festivals
	if fest != null:
		for f: FestivalData in fest.all_festivals():
			var day := fest.fest_day(f.id)
			if day >= TimeManager.day:
				lines.append(CAL_FEST % [Phase8Texts.fest_name(f.id), "heute" if day == TimeManager.day else "Tag %d" % day])
	return "\n".join(lines)


static func _life_config(tree: SceneTree) -> NpcLifeConfig:
	var life := _first(tree, NPC_LIFE_GROUP) as NpcLife
	if life != null and life.config != null:
		return life.config
	var cfg := Database.config(&"npc_life_config") as NpcLifeConfig
	return cfg if cfg != null else NpcLifeConfig.new()


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null
