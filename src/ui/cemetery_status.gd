class_name CemeteryStatus
extends RefCounted
## Read-only snapshot of the Phase-3 systems for the UI (docs/PHASE3_DESIGN.md §7): cemetery
## quality breakdown, sections, reputation, cleanliness and ghosts, as plain Dictionaries.
## Every system is found through its group; a missing system yields neutral values, so the HUD,
## the overview panel and the summaries work in Phase-2 worlds and in tests without a world.
## Never changes game state.

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
