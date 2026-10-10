class_name CemeteryStatus
extends RefCounted
## Read-only snapshot of the Phase-3 systems for the UI (docs/PHASE3_DESIGN.md §7): cemetery
## quality breakdown, sections, reputation, cleanliness and ghosts, as plain Dictionaries.
## Every system is found through its group; a missing system yields neutral values, so the HUD,
## the overview panel and the summaries work in Phase-2 worlds and in tests without a world.
## Never changes game state.
## Phase 5 (docs/PHASE5_DESIGN.md §3.4, §7): sections() lists only burial sections (SectionData.
## is_burial – Am Bruch and the quarry are work areas, not part of the cemetery); phase5_state()
## feeds the objective lines and chapter_progress() the HUD tooltip line.
## Phase 6 (docs/PHASE6_DESIGN.md §7): phase6_state() feeds the Phase-6 objective lines,
## chapter6_progress() the chapter line „Gruft 2/2 · … · Umbettung 3/1" and grave_counts() the line
## „Gräber 21 belegt · 2 frei · 2 alt (Ruhezeit) · 4 umgebettet" of the HUD tooltip.

const SCORE_GROUP := &"cemetery_score"
const GRAVEYARD_GROUP := &"graveyard"
const EXPANSION_GROUP := &"expansion"
const DECOR_GROUP := &"decorations"
const CLEANLINESS_GROUP := &"cleanliness"
const REPUTATION_GROUP := &"reputation"
const GHOSTS_GROUP := &"ghosts"
const DIRT_SPOT_GROUP := &"dirt_spot"
const CARE_GROUP := &"corpse_care"
const CORPSE_MANAGER_GROUP := &"corpse_manager"
const JOURNAL_GROUP := &"journal"
const KIND_WEEDS := &"weeds"
const KIND_LEAVES := &"leaves"
const LEVELS := 4
const WORKSHOP_GROUP := &"workshop"
const STONEMASONRY_GROUP := &"stonemasonry"
const SECTION_BRUCH := &"bruch"
const SECTION_QUARRY := &"quarry"
const BUILDINGS_GROUP := &"buildings"
const OSSUARY_GROUP := &"ossuary"
const CHAPEL_GROUP := &"chapel_rites"
const FLAG_P6_INTRO := &"p6_intro"
const VILLAGE_GROUP := &"village"
const ORDERS_GROUP := &"orders"
const RELATIONSHIPS_GROUP := &"relationships"
const SECTION_LINDEN := &"linden"
const ORDER_HAGEDORN := &"o_hagedorn_place"
## An order counts as urgent (objective line) with at most this many days left.
const URGENT_DAYS := 2
const FLAG_PASSAGE_SEEN := &"c_crypt_draft_seen"


## {graves, decor, dirt, total, rating, next_rating, next_at} – CemeteryScore.breakdown(), else
## the graves-only value of the Graveyard (decor/dirt 0).
static func score(tree: SceneTree) -> Dictionary:
	var node := _first(tree, SCORE_GROUP)
	if node != null and node.has_method(&"breakdown"):
		return node.call(&"breakdown")
	var graves := 0
	var graveyard := _first(tree, GRAVEYARD_GROUP)
	if graveyard != null and graveyard.has_method(&"total_quality"):
		graves = int(graveyard.call(&"total_quality"))
	return breakdown_of(graves, 0, 0, _economy())


## Pure: the breakdown for the given parts (same shape as CemeteryScore.breakdown()). Phase 4
## §2.14: the rating is gated (CemeteryRating.rating_gated – „Ehrwürdig“ also needs decor and
## tending), venerable_missing names what is lacking ("Zier 8/12", …; empty = nothing).
static func breakdown_of(graves: int, decor: int, dirt: int, economy: EconomyConfig) -> Dictionary:
	var total := maxi(0, graves + decor - dirt)
	var rating := CemeteryRating.rating_gated(total, decor, dirt, economy)
	var index := CemeteryRating.TIERS.find(rating)
	var thresholds := economy.rating_thresholds
	var next_rating := &""
	var next_at := 0
	if index >= 0 and index + 1 < CemeteryRating.TIERS.size() and index < thresholds.size():
		next_rating = CemeteryRating.TIERS[index + 1]
		next_at = thresholds[index]
	return {"graves": graves, "decor": decor, "dirt": dirt, "total": total, "rating": rating,
			"next_rating": next_rating, "next_at": next_at,
			"venerable_missing": CemeteryRating.venerable_missing(decor, dirt, economy)}


## One entry per section (by order): {id, name, order, unlocked, done, total, block, plots,
## plots_free, plots_marked, decor, decor_raw, decor_cap, gate (a flag unlocks it – the
## Holunderwinkel's key), counts_for_cemetery}. [] without an ExpansionManager.
static func sections(tree: SceneTree) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var expansion := _first(tree, EXPANSION_GROUP) as ExpansionManager
	if expansion == null:
		return out
	var graveyard := _first(tree, GRAVEYARD_GROUP) as Graveyard
	var decor_by: Dictionary = {}
	var decorations := _first(tree, DECOR_GROUP) as DecorationManager
	if decorations != null:
		decor_by = decorations.score_by_section()
	for s: SectionData in expansion.sections():
		if not s.is_burial:
			continue
		var p := expansion.progress(s.id)
		var entry := {"id": s.id, "name": s.display_name, "order": s.order,
				"unlocked": expansion.is_unlocked(s.id), "done": p.x, "total": p.y,
				"block": expansion.block_reason(s.id), "plots": 0, "plots_free": 0, "plots_marked": 0,
				"decor": 0, "decor_raw": 0, "decor_cap": s.decor_cap, "gate": s.requires_flag != &"",
				"counts_for_cemetery": s.counts_for_cemetery}
		if graveyard != null:
			for id: String in graveyard.plots_in_section(s.id):
				var g := graveyard.get_grave(id)
				if g == null or g.state == GraveRecord.State.OLD:
					continue
				entry.plots += 1
				if g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG:
					entry.plots_free += 1
				elif g.state == GraveRecord.State.MARKED:
					entry.plots_marked += 1
		if decor_by.has(s.order):
			var d: Dictionary = decor_by[s.order]
			entry.decor = int(d.get("capped", 0))
			entry.decor_raw = int(d.get("raw", 0))
			entry.decor_cap = int(d.get("cap", s.decor_cap))
		out.append(entry)
	return out


## {value, tier, label, forecast, pay_bonus, stipend, deliveries, every_other_day, next_tier,
## next_at, known} – known = false without a Reputation node (value from GameState anyway).
static func reputation(tree: SceneTree) -> Dictionary:
	var node := _first(tree, REPUTATION_GROUP) as Reputation
	var cfg := node.config if node != null and node.config != null else _rep_config()
	var value := node.value() if node != null else GameState.get_stat(&"reputation")
	return reputation_of(value, node.forecast() if node != null else 0, cfg, node != null)


## Pure: the reputation dictionary for `value` and the forecast drift.
static func reputation_of(value: int, forecast: int, cfg: ReputationConfig, known: bool = true) -> Dictionary:
	var t := ReputationRules.tier(value, cfg)
	var index := ReputationRules.tier_index(t)
	var next_tier := &""
	var next_at := 0
	if index >= 0 and index + 1 < ReputationRules.TIERS.size() and index < cfg.tier_thresholds.size():
		next_tier = ReputationRules.TIERS[index + 1]
		next_at = cfg.tier_thresholds[index]
	var every_other := index >= 0 and index < cfg.delivery_every_other_day.size() and cfg.delivery_every_other_day[index] != 0
	return {"value": value, "tier": t, "label": ReputationRules.label(t), "forecast": forecast,
			"pay_bonus": ReputationRules.pay_bonus(t, cfg), "stipend": ReputationRules.stipend(t, cfg),
			"deliveries": ReputationRules.deliveries_on(1, t, cfg), "every_other_day": every_other,
			"next_tier": next_tier, "next_at": next_at, "known": known}


## {levels: [n0, n1, n2, n3], penalty, spots, dirty, weeds (≥ 2), leaves (≥ 2), known}.
static func dirt(tree: SceneTree) -> Dictionary:
	var out := {"levels": [0, 0, 0, 0], "penalty": 0, "spots": 0, "dirty": 0, "weeds": 0, "leaves": 0, "known": false}
	var manager := _first(tree, CLEANLINESS_GROUP) as CleanlinessManager
	if manager == null:
		return out
	out.known = true
	var kinds := {}
	if tree != null:
		for node: Node in tree.get_nodes_in_group(DIRT_SPOT_GROUP):
			var spot := node as DirtSpot
			if spot != null:
				kinds[spot.spot_id] = spot.kind
	var levels: Array = out.levels
	for id: String in manager.spot_ids():
		var lvl := clampi(manager.level(id), 0, LEVELS - 1)
		levels[lvl] = int(levels[lvl]) + 1
		out.spots = int(out.spots) + 1
		if lvl >= 2:
			out.dirty = int(out.dirty) + 1
			if kinds.get(id, KIND_WEEDS) == KIND_LEAVES:
				out.leaves = int(out.leaves) + 1
			else:
				out.weeds = int(out.weeds) + 1
	out.penalty = manager.penalty()
	return out


## {content, calm, restless (heard only), eligible, heard, known}.
static func ghosts(tree: SceneTree) -> Dictionary:
	var out := {"content": 0, "calm": 0, "restless": 0, "eligible": 0, "heard": 0, "known": false}
	var manager := _first(tree, GHOSTS_GROUP) as GhostManager
	if manager == null:
		return out
	out.known = true
	var moods := manager.heard_moods()
	for key: String in ["content", "calm", "restless"]:
		out[key] = int(moods.get(key, moods.get(StringName(key), 0)))
		out.heard = int(out.heard) + int(out[key])
	out.eligible = manager.eligible_graves().size()
	return out


## Context of the cemetery overview panel (§7): {score, sections, reputation, dirt, ghosts}.
static func overview_context(tree: SceneTree) -> Dictionary:
	return {"score": score(tree), "sections": sections(tree), "reputation": reputation(tree),
			"dirt": dirt(tree), "ghosts": ghosts(tree)}


## Phase-3 part of the objective line (ObjectiveResolver `world`): {sections, weeds, leaves,
## has_rake, total, rating} + Phase 4 (§7, phase4_state): {table_loss, journal_ready,
## story_pending}.
static func objective_state(tree: SceneTree, inv: Inventory) -> Dictionary:
	var d := dirt(tree)
	var s := score(tree)
	var rake := _clean_config().rake_item
	var out := {"sections": sections(tree), "weeds": int(d.weeds), "leaves": int(d.leaves),
			"has_rake": inv != null and inv.has(rake, 1), "total": int(s.total), "rating": s.rating}
	out.merge(phase4_state(tree))
	out.merge(phase5_state(tree, inv))
	out.merge(phase6_state(tree, inv))
	out.merge(phase7_state(tree))
	# Phase 8 (docs/PHASE8_DESIGN.md §7.5): nested, so its keys never meet those of Phases 3–7.
	out["p8"] = Phase8Status.objective_state(tree)
	# 04.10.2026: in the crypt the carried corpse goes onto the crypt table (objective line).
	var player := _first(tree, &"player")
	out["in_crypt"] = player != null and player.get(&"interior_id") == &"crypt"
	return out


## {table_loss (minutes until the next find of the corpse on the table is lost, −1 = none),
## journal_ready (titles of insights whose clues are all found, not linked yet),
## story_pending (story corpses not delivered yet)} – neutral without the Phase-4 systems.
static func phase4_state(tree: SceneTree) -> Dictionary:
	var loss := -1
	var care := _first(tree, CARE_GROUP)
	var manager := _first(tree, CORPSE_MANAGER_GROUP)
	if care != null and manager != null and care.has_method(&"next_loss") and manager.has_method(&"records"):
		for r: CorpseRecord in manager.call(&"records"):
			if r.location == CorpseRecord.LOCATION_TABLE:
				var nl: Dictionary = care.call(&"next_loss", r.id)
				if not nl.is_empty():
					loss = int(nl.get("minutes", -1))
				break
	var ready := PackedStringArray()
	var journal := _first(tree, JOURNAL_GROUP)
	if journal != null and journal.has_method(&"ready_insights"):
		for i: InsightData in journal.call(&"ready_insights"):
			ready.append(i.title)
	var pending := 0
	if manager != null and manager.has_method(&"story_delivered"):
		var delivered := manager.call(&"story_delivered") as PackedStringArray
		pending = maxi(Database.story_corpses().size() - delivered.size(), 0)
	return {"table_loss": loss, "journal_ready": ready, "story_pending": pending}


## Phase-5 part of the objective line: {} without a Workshop or before workshop_open, else
## {p5: true, license, bruch_open, quarry_open, sites: [{id, name, affordable}] (unbuilt goal
## stations in goal order), kiln_ready, stone_ready (name of the dead whose stone waits, ""),
## tiers, goal_tiers, goal_missing, goal_done, nameless (graves with a dead but no name in stone)}.
static func phase5_state(tree: SceneTree, inv: Inventory) -> Dictionary:
	var shop := _first(tree, WORKSHOP_GROUP) as Workshop
	if shop == null or not shop.is_open():
		return {}
	var cfg := shop.workshop_config()
	var out := {"p5": true, "license": GameState.flag_on(cfg.license_flag)}
	var expansion := _first(tree, EXPANSION_GROUP) as ExpansionManager
	out["bruch_open"] = expansion == null or expansion.section(SECTION_BRUCH) == null or expansion.is_unlocked(SECTION_BRUCH)
	out["quarry_open"] = expansion == null or expansion.section(SECTION_QUARRY) == null or expansion.is_unlocked(SECTION_QUARRY)
	var sites: Array[Dictionary] = []
	for id: StringName in cfg.goal_stations:
		if shop.is_built(id):
			continue
		var data := Database.station(id) as StationData
		sites.append({"id": id, "name": data.display_name if data != null else String(id),
				"affordable": inv != null and data != null and WorkshopRules.missing(data, inv).is_empty()})
	out["sites"] = sites
	var kiln := false
	for id: StringName in shop.built():
		var job := shop.job_of(id)
		kiln = kiln or (not job.is_empty() and bool(job.ready))
	out["kiln_ready"] = kiln
	var ready_name := ""
	var masonry := _first(tree, STONEMASONRY_GROUP) as Stonemasonry
	if masonry != null:
		for stone: Dictionary in masonry.ready_stones():
			if bool(stone.get("fits_still", false)):
				ready_name = str(stone.name)
				break
	out["stone_ready"] = ready_name
	var progress := shop.goal_progress()
	out["tiers"] = shop.tiers()
	out["goal_tiers"] = cfg.goal_tiers.duplicate()
	out["goal_missing"] = progress.get("missing", PackedStringArray())
	out["goal_done"] = GameState.flag_on(cfg.goal_flag)
	var nameless := 0
	var graveyard := _first(tree, GRAVEYARD_GROUP) as Graveyard
	if graveyard != null:
		for g: GraveRecord in graveyard.graves():
			if g.corpse_id == "" or not (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED):
				continue
			if g.design.is_empty() or StoneDesign.from_dict(g.design).inscription == &"":
				nameless += 1
	out["nameless"] = nameless
	return out


## Workshop.goal_progress() while the workyard is open ({} otherwise) – the HUD chapter line.
static func chapter_progress(tree: SceneTree) -> Dictionary:
	var shop := _first(tree, WORKSHOP_GROUP) as Workshop
	if shop == null or not shop.is_open():
		return {}
	var out := shop.goal_progress()
	out["done_flag"] = GameState.flag_on(shop.workshop_config().goal_flag)
	return out


## Phase-6 part of the objective line: {} without Buildings, {crypt_level} before buildings_open (the
## crypt from the start, 04.10.2026), else {p6: true,
## p6_intro, levels, goal_levels, goal_done, crypt_level, chapel_level, reinter_waiting (lifted, not
## reinterred), full_boxes / boxes (in the pack), next_lift (label of the next liftable old grave),
## ossuary_free, passage_unseen (sealed / grille but not looked at), devotion_name (the most restless
## ghost without a light, once the chapel stands)}.
static func phase6_state(tree: SceneTree, inv: Inventory) -> Dictionary:
	var buildings := _first(tree, BUILDINGS_GROUP) as Buildings
	if buildings == null:
		return {}
	if not buildings.is_open():
		# Changed 04.10.2026: the crypt stands from day 1 – the corpse chain names it before Phase 6.
		return {"crypt_level": buildings.level(&"crypt")} if buildings.level(&"crypt") >= 1 else {}
	var cfg := buildings.buildings_config()
	var levels := buildings.levels()
	var out := {"p6": true, "p6_intro": GameState.flag_on(FLAG_P6_INTRO), "levels": levels,
			"goal_levels": cfg.goal_levels.duplicate(), "goal_done": GameState.flag_on(cfg.goal_flag),
			"crypt_level": int(levels.get(&"crypt", 0)), "chapel_level": int(levels.get(&"chapel", 0))}
	var ossuary := _first(tree, OSSUARY_GROUP) as Ossuary
	var crypt_cfg := ossuary.rules() if ossuary != null else CryptConfig.new()
	out["full_boxes"] = inv.count(crypt_cfg.full_item) if inv != null else 0
	out["boxes"] = inv.count(crypt_cfg.box_item) if inv != null else 0
	out["reinter_waiting"] = ossuary.pending().size() if ossuary != null else 0
	out["ossuary_free"] = ossuary != null and ossuary.used() < ossuary.capacity()
	var next_lift := ""
	var graveyard := _first(tree, GRAVEYARD_GROUP) as Graveyard
	if ossuary != null and graveyard != null:
		for grave: GraveRecord in graveyard.graves():
			if grave.state != GraveRecord.State.OLD:
				continue
			var old := ossuary.data_of(grave.id)
			if old != null and OssuaryRules.liftable(old, ossuary.year(), crypt_cfg):
				next_lift = OssuaryRules.label(old)
				break
	out["next_lift"] = next_lift
	var passage := ossuary.passage_state() if ossuary != null else Ossuary.PASSAGE_HIDDEN
	out["passage_unseen"] = passage != Ossuary.PASSAGE_HIDDEN and not GameState.flag_on(FLAG_PASSAGE_SEEN)
	var devotion := ""
	var rites := _first(tree, CHAPEL_GROUP) as ChapelRites
	if rites != null and rites.level() >= 1:
		var best := 99
		for e: Dictionary in rites.eligible_devotions():
			if int(e.get("held_level", 0)) > 0:
				continue
			var rank := int(Phase6Texts.MOOD_RANK.get(StringName(str(e.get("mood", ""))), 3))
			if rank < best and rank < 2:
				best = rank
				devotion = str(e.get("name", ""))
	out["devotion_name"] = devotion
	return out


## Buildings.goal_progress() + done_flag (roof_and_earth_complete); {} before buildings_open.
static func chapter6_progress(tree: SceneTree) -> Dictionary:
	var buildings := _first(tree, BUILDINGS_GROUP) as Buildings
	if buildings == null or not buildings.is_open():
		return {}
	var out := buildings.goal_progress()
	out["done_flag"] = GameState.flag_on(buildings.buildings_config().goal_flag)
	return out


## {taken, free, old, old_resting, reinterred} over the graves (Phase 6; {} before buildings_open).
static func grave_counts(tree: SceneTree) -> Dictionary:
	var buildings := _first(tree, BUILDINGS_GROUP) as Buildings
	var graveyard := _first(tree, GRAVEYARD_GROUP) as Graveyard
	if buildings == null or not buildings.is_open() or graveyard == null:
		return {}
	var ossuary := _first(tree, OSSUARY_GROUP) as Ossuary
	var out := {"taken": 0, "free": 0, "old": 0, "old_resting": 0, "reinterred": ossuary.reinterred().size() if ossuary != null else 0}
	for g: GraveRecord in graveyard.graves():
		match g.state:
			GraveRecord.State.EMPTY, GraveRecord.State.DUG:
				out.free += 1
			GraveRecord.State.FILLED, GraveRecord.State.MARKED:
				out.taken += 1
			GraveRecord.State.OLD:
				out.old += 1
				var data := ossuary.data_of(g.id) if ossuary != null else Database.old_grave(g.id) as OldGraveData
				var cfg := ossuary.rules() if ossuary != null else CryptConfig.new()
				var year := ossuary.year() if ossuary != null else StoneCalendar.year_of(TimeManager.day, Database.config(&"stone_config") as StoneConfig)
				if data != null and not OssuaryRules.liftable(data, year, cfg):
					out.old_resting += 1
	return out


static func _first(tree: SceneTree, group: StringName) -> Node:
	return tree.get_first_node_in_group(group) if tree != null else null


static func _economy() -> EconomyConfig:
	return EconomyConfig.resolve()


static func _rep_config() -> ReputationConfig:
	var cfg := Database.config(&"reputation_config") as ReputationConfig
	return cfg if cfg != null else ReputationConfig.new()


static func _clean_config() -> CleanlinessConfig:
	var cfg := Database.config(&"cleanliness_config") as CleanlinessConfig
	return cfg if cfg != null else CleanlinessConfig.new()


## Phase-7 part of the objective line (docs/PHASE7_DESIGN.md §7): {} before village_open, else {p7, p7_intro,
## visited, linden_granted, linden_done, linden_total, linden_cleared, consecrated, consecration_paid,
## surgeon_waiting, hagedorn_open, urgent_order {id, title, days_left}, goal_done, goal_parts, goal_total,
## board_open}.
static func phase7_state(tree: SceneTree) -> Dictionary:
	var village := _first(tree, VILLAGE_GROUP) as Village
	if village == null or not village.is_open():
		return {}
	var out := {"p7": true, "p7_intro": GameState.flag_on(&"p7_intro"),
			"visited": GameState.get_stat(&"village_trips") > 0 or RegionRoot.current(tree) == RegionRoot.VILLAGE,
			"linden_granted": GameState.flag_on(Village.FLAG_LINDEN_GRANTED), "consecrated": GameState.flag_on(Village.FLAG_CONSECRATED),
			"consecration_paid": GameState.has_flag(Village.FLAG_CONSECRATION_DAY)}
	var expansion := _first(tree, EXPANSION_GROUP) as ExpansionManager
	if expansion != null and expansion.section(SECTION_LINDEN) != null:
		var p := expansion.progress(SECTION_LINDEN)
		out["linden_done"] = p.x
		out["linden_total"] = p.y
		out["linden_cleared"] = expansion.is_unlocked(SECTION_LINDEN) or (p.y > 0 and p.x >= p.y)
	else:
		out["linden_cleared"] = true
	var rel := _first(tree, RELATIONSHIPS_GROUP) as Relationships
	out["surgeon_waiting"] = bool(out.consecrated) and not GameState.flag_on(&"anatomy_known") and not GameState.flag_on(&"anatomy_declined") \
			and (rel == null or not rel.met(&"surgeon"))
	var orders := _first(tree, ORDERS_GROUP) as Orders
	out["hagedorn_open"] = orders != null and orders.state(ORDER_HAGEDORN) == Orders.STATE_ACCEPTED and GameState.flag_on(Village.FLAG_HAGEDORN_DEAD)
	var urgent := {}
	var board_open := 0
	if orders != null:
		for id: StringName in orders.active():
			if id == ORDER_HAGEDORN or orders.deadline_day(id) <= 0:
				continue
			var left := maxi(orders.deadline_day(id) - TimeManager.day, 0)
			if left <= URGENT_DAYS and (urgent.is_empty() or left < int(urgent.days_left)):
				var o := orders.order_data(id)
				urgent = {"id": id, "title": o.title if o != null else String(id), "days_left": left}
		for id: StringName in orders.board():
			var st := orders.state(id)
			if st == &"" or st == Orders.STATE_OFFERED:
				board_open += 1
	out["urgent_order"] = urgent
	out["board_open"] = board_open
	var goal := village.goal_progress()
	out["goal_parts"] = int(goal.get("done", 0))
	out["goal_total"] = int(goal.get("total", 4))
	out["goal_done"] = GameState.flag_on(village.config.goal_flag if village.config != null else &"name_in_village_complete")
	return out
