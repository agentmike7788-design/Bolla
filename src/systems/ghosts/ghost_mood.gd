class_name GhostMood
extends RefCounted
## Pure mood / hint / line rules of the ghosts (docs/PHASE3_DESIGN.md §2.8, §3.4).
## score = grave quality + own dirt spot (grave_mood_by_level: +1/0/−2/−4) + decor bonus
## (clamped to decor_bonus_max) + robbed × GhostConfig.robbed_mood (Phase 4 §2.9: hair /
## teeth taken). ≥ 9 content · 5…8 calm · ≤ 4 restless (mood_thresholds).
## Reasons by priority (Phase 4 §2.9, Phase 5 §2.5): &"robbed", &"weeds", &"valuables", &"cold",
## &"unkempt", &"cross", &"nameless", &"waited", &"bare".

const RESTLESS := &"restless"
const CALM := &"calm"
const CONTENT := &"content"
const MOODS: Array[StringName] = [RESTLESS, CALM, CONTENT]
const LABELS: Dictionary[StringName, String] = {RESTLESS: "unruhig", CALM: "gleichmütig", CONTENT: "zufrieden"}

const REASON_ROBBED := &"robbed"
const REASON_WEEDS := &"weeds"
const REASON_VALUABLES := &"valuables"
const REASON_COLD := &"cold"
const REASON_UNKEMPT := &"unkempt"
const REASON_CROSS := &"cross"
const REASON_NAMELESS := &"nameless"
const REASON_WAITED := &"waited"
const REASON_BARE := &"bare"
const REASONS: Array[StringName] = [REASON_ROBBED, REASON_WEEDS, REASON_VALUABLES, REASON_COLD, REASON_UNKEMPT,
		REASON_CROSS, REASON_NAMELESS, REASON_WAITED, REASON_BARE]
## Phase 5 §2.5: by_design keys (GhostLines.by_design) – most specific first.
const DESIGN_S5_LORENZ := &"s5_lorenz"
const DESIGN_MASTER := &"master"
const DESIGN_GILDED := &"gilded"
const DESIGN_DEFAULT := &"default"
const MASTER_SHAPE := &"stone_master"
## Kinds of CorpseRecord.harvested that count as "robbed".
const ROBBED_KINDS: Array[StringName] = [CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH]
## Piety tiers with their own lines (GhostLines.by_piety): one heard line in PIETY_EVERY.
const PIETY_EVERY := 4
## Dirt level of the grave's own spot from which weeds are the main complaint.
const WEEDS_LEVEL := 2


## `robbed` = number of harvested kinds (robbed_count).
static func score(quality: int, dirt_level: int, decor_bonus: int, clean: CleanlinessConfig, cfg: GhostConfig, robbed: int = 0) -> int:
	var dirt := 0
	if clean != null and not clean.grave_mood_by_level.is_empty():
		var lvl := clampi(dirt_level, 0, clean.grave_mood_by_level.size() - 1)
		dirt = clean.grave_mood_by_level[lvl]
	var cap := cfg.decor_bonus_max if cfg != null else 2
	var robbed_mood := cfg.robbed_mood if cfg != null else -5
	return quality + dirt + clampi(decor_bonus, 0, cap) + maxi(robbed, 0) * robbed_mood


## Harvested kinds (hair / teeth) of a record – each costs robbed_mood.
static func robbed_count(corpse: CorpseRecord) -> int:
	if corpse == null:
		return 0
	var n := 0
	for kind: StringName in ROBBED_KINDS:
		if corpse.harvested.has(kind):
			n += 1
	return n


## &"restless", &"calm", &"content"
static func mood(value: int, cfg: GhostConfig) -> StringName:
	var t: PackedInt32Array = cfg.mood_thresholds if cfg != null and cfg.mood_thresholds.size() >= 2 else PackedInt32Array([5, 9])
	if value < t[0]:
		return RESTLESS
	if value < t[1]:
		return CALM
	return CONTENT


## Phase 3 §2.8 + Phase 4 §2.9 + Phase 5 §2.5; &"" = nothing missing. unkempt = not washed or not
## laid out; cross = a better marker item exists (wooden cross → gravestone); nameless = a
## designed stone without an inscription; waited = buried decaying or rotten.
static func main_reason(grave: GraveRecord, corpse: CorpseRecord, dirt_level: int, decor_bonus: int, economy: EconomyConfig) -> StringName:
	if robbed_count(corpse) > 0:
		return REASON_ROBBED
	if dirt_level >= WEEDS_LEVEL:
		return REASON_WEEDS
	var cfg := EconomyConfig.resolve(economy)
	if corpse != null:
		if corpse.valuables_decision == CorpseRecord.DECISION_TAKEN:
			return REASON_VALUABLES
		if not corpse.shrouded and corpse.dress == CorpseRecord.DRESS_NONE:
			return REASON_COLD
		if not corpse.washed or not corpse.laid_out:
			return REASON_UNKEMPT
	if grave != null and _marker_upgradeable(grave.marker_id, cfg):
		return REASON_CROSS
	if grave != null and _nameless(grave):
		return REASON_NAMELESS
	if corpse != null:
		var fresh := corpse.freshness_at_burial if corpse.freshness_at_burial >= 0.0 else corpse.freshness
		if CorpseRecord.stage_for(fresh, cfg) in [CorpseRecord.STAGE_DECAYING, CorpseRecord.STAGE_ROTTEN]:
			return REASON_WAITED
	if decor_bonus <= 0:
		return REASON_BARE
	return &""


## Deterministic from `seed` (hash(grave_id) + day). Content: thanks lines plus the trait
## lines of the buried person's traits; restless / calm: the main reason's hints (calm
## without a reason: calm lines). Falls back to the other pools when one is empty.
## Phase 4 §2.7/§2.9: a piety tier with its own lines (by_piety: devout, hardhearted) speaks
## one of them for every PIETY_EVERY-th seed; a story ghost (by_story) speaks only its own
## lines when content and adds them to its hints when calm (restless story ghosts complain
## like any other).
## QA (W3): `harvested` (CorpseRecord.harvested) adds GhostLines.by_harvest to the robbed hints.
static func pick_line(lines: GhostLines, mood_id: StringName, reason: StringName, traits: Array[StringName], seed: int,
		story_id: StringName = &"", piety_tier: StringName = &"", harvested: Array[StringName] = []) -> String:
	if lines == null:
		return ""
	var piety_pool: PackedStringArray = lines.by_piety.get(piety_tier, PackedStringArray()) if piety_tier != &"" else PackedStringArray()
	if not piety_pool.is_empty() and posmod(seed, PIETY_EVERY) == 0:
		return piety_pool[posmod(floori(seed / float(PIETY_EVERY)), piety_pool.size())]
	var story_pool: PackedStringArray = lines.by_story.get(story_id, PackedStringArray()) if story_id != &"" else PackedStringArray()
	var pool := PackedStringArray()
	if not story_pool.is_empty() and mood_id == CONTENT:
		pool.append_array(story_pool)
	elif not story_pool.is_empty() and mood_id == CALM:
		pool.append_array(story_pool)
		if reason != &"" and lines.by_reason.has(reason):
			pool.append_array(lines.by_reason[reason])
		_append_harvest(pool, lines, reason, harvested)
	elif mood_id == CONTENT:
		pool.append_array(lines.content)
		for t: StringName in traits:
			if lines.by_trait.has(t):
				pool.append_array(lines.by_trait[t])
	else:
		if reason != &"" and lines.by_reason.has(reason):
			pool.append_array(lines.by_reason[reason])
		_append_harvest(pool, lines, reason, harvested)
		if pool.is_empty():
			pool.append_array(lines.calm)
	if pool.is_empty():
		pool.append_array(lines.calm)
	if pool.is_empty():
		pool.append_array(lines.content)
	if pool.is_empty():
		return ""
	return pool[posmod(seed, pool.size())]


## The kind-specific robbed lines (by_harvest) of the kinds taken.
static func _append_harvest(pool: PackedStringArray, lines: GhostLines, reason: StringName, harvested: Array[StringName]) -> void:
	if reason != REASON_ROBBED:
		return
	for kind: StringName in harvested:
		if lines.by_harvest.has(kind):
			pool.append_array(lines.by_harvest[kind])


static func label(mood_id: StringName) -> String:
	return LABELS.get(mood_id, "")


## by_design pool key of a freshly set designed stone (§2.5): s5_lorenz (a story corpse renamed
## by an insight whose stone still carries the old name) · master · gilded · default.
static func design_key(design: Dictionary, corpse: CorpseRecord) -> StringName:
	var stone := StoneDesign.from_dict(design)
	if corpse != null and corpse.story_id != &"" and not stone.text.is_empty():
		for res: Resource in Database.insights():
			var insight := res as InsightData
			if insight != null and insight.rename_story == corpse.story_id and insight.rename_to != "" \
					and not "\n".join(stone.text).contains(insight.rename_to):
				return DESIGN_S5_LORENZ
	if stone.shape == MASTER_SHAPE:
		return DESIGN_MASTER
	if stone.gilded:
		return DESIGN_GILDED
	return DESIGN_DEFAULT


## One by_design line (pool of `key`, else default), deterministic from `seed`; "" = none.
static func pick_design_line(lines: GhostLines, key: StringName, seed: int) -> String:
	if lines == null:
		return ""
	var pool: PackedStringArray = lines.by_design.get(key, PackedStringArray())
	if pool.is_empty():
		pool = lines.by_design.get(DESIGN_DEFAULT, PackedStringArray())
	return pool[posmod(seed, pool.size())] if not pool.is_empty() else ""


## A better marker ITEM exists in EconomyConfig.marker_quality (designed stone shapes are no
## items and never make a marker "upgradeable" – Phase 5 §2.5).
static func _marker_upgradeable(marker_id: StringName, cfg: EconomyConfig) -> bool:
	if marker_id == &"" or not cfg.marker_quality.has(marker_id) or StoneDesignRules.is_shape(marker_id):
		return false
	var own: int = cfg.marker_quality[marker_id]
	for id: StringName in cfg.marker_quality:
		if cfg.marker_quality[id] > own and not StoneDesignRules.is_shape(id):
			return true
	return false


## A designed stone without an inscription (§2.5 "ohne Inschrift bleibt der Stein namenlos"). The
## plain gravestone of Phase 3/4 keeps its old reasons (waited / bare), so the early game's hints
## do not change.
static func _nameless(grave: GraveRecord) -> bool:
	return not grave.design.is_empty() and StoneDesign.from_dict(grave.design).inscription == &""
