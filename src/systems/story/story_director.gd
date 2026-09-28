class_name StoryDirector
extends RefCounted
## Pure rules of the story corpses S1–S5 (docs/PHASE4_DESIGN.md §2.11, §3.4). No node, no
## state: the CorpseManager saves story_delivered / story_last_day, calls due_story before the
## random corpse of a delivery day and daily_checks at day_started (key fallback).

const CHECK_ELDER_KEY := &"elder_key"


## The next undelivered story (by order) with day ≥ earliest_day and
## day ≥ last_story_day + min_gap_days; null = none due. Stories are strictly sequential:
## a later one never overtakes an earlier undelivered one.
static func due_story(day: int, delivered: PackedStringArray, last_story_day: int, stories: Array[StoryCorpseData], cfg: StoryConfig) -> StoryCorpseData:
	var next := _next_undelivered(delivered, stories)
	if next == null:
		return null
	var gap := cfg.min_gap_days if cfg != null else StoryConfig.new().min_gap_days
	if day < next.earliest_day:
		return null
	if last_story_day > 0 and day < last_story_day + gap:
		return null
	return next


## Stories not yet delivered (reservation of free plots).
static func pending_count(delivered: PackedStringArray, stories: Array[StoryCorpseData]) -> int:
	var count := 0
	for story: StoryCorpseData in stories:
		if story != null and not delivered.has(String(story.id)):
			count += 1
	return count


## Name / age / cause / traits (forced from the data) / valuables / story_id from the data,
## freshness 1, seed. id stays "" (the CorpseManager assigns it).
static func make_record(story: StoryCorpseData, seed: int) -> CorpseRecord:
	var record := CorpseRecord.new()
	record.seed = seed
	record.freshness = CorpseDecay.START_FRESHNESS
	if story == null:
		push_warning("[StoryDirector] make_record without story data")
		return record
	record.story_id = story.id
	record.display_name = story.display_name
	record.age = story.age
	record.cause_id = story.cause_id
	for t: StringName in story.traits:
		if t != &"" and not t in record.traits:
			record.traits.append(t)
	record.valuables_coins = maxi(0, story.valuables_coins)
	if record.valuables_coins > 0 and not record.has_trait(CorpseRecord.TRAIT_VALUABLES):
		record.traits.append(CorpseRecord.TRAIT_VALUABLES)
	return record


## Fallbacks due today: &"elder_key" from key_fallback_day on without the key (idempotent:
## once the key flag is set, nothing is due any more).
static func daily_checks(day: int, has_key: bool, cfg: StoryConfig) -> Array[StringName]:
	var out: Array[StringName] = []
	var c := cfg if cfg != null else StoryConfig.new()
	if not has_key and day >= c.key_fallback_day:
		out.append(CHECK_ELDER_KEY)
	return out


## Stories sorted by order (ties by id).
static func sorted(stories: Array[StoryCorpseData]) -> Array[StoryCorpseData]:
	var out: Array[StoryCorpseData] = []
	for story: StoryCorpseData in stories:
		if story != null:
			out.append(story)
	out.sort_custom(func(a: StoryCorpseData, b: StoryCorpseData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## The first story by order whose id is not in `delivered`.
static func _next_undelivered(delivered: PackedStringArray, stories: Array[StoryCorpseData]) -> StoryCorpseData:
	for story: StoryCorpseData in sorted(stories):
		if not delivered.has(String(story.id)):
			return story
	return null


## The story with `id` (null = unknown).
static func find(stories: Array[StoryCorpseData], id: StringName) -> StoryCorpseData:
	for story: StoryCorpseData in stories:
		if story != null and story.id == id:
			return story
	return null
