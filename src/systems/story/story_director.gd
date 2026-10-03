class_name StoryDirector
extends RefCounted
## Pure rules of the story corpses S1–S5 (docs/PHASE4_DESIGN.md §2.11, §3.4). No node, no
## state: the CorpseManager saves story_delivered / story_last_day, calls due_story before the
## random corpse of a delivery day and daily_checks at day_started (key fallback).
## Phase 7 (docs/PHASE7_DESIGN.md §2.9, §3.4, P6): a story may wait for a flag (requires_flag) and
## come at the earliest after_days after the day stored in after_flag (D1 Wiebke Hagedorn:
## village_open_day + 8, only with linden_consecrated). Such a story only reserves a place while it
## can come (pending_count), and daily_checks sets its due_flag (hagedorn_dead) at 00:00 of the day it
## is due. The only side effect of this class: that flag (GameState), read from the running world.

const CHECK_ELDER_KEY := &"elder_key"
## daily_checks: a story's due_flag was set today.
const CHECK_DUE_FLAG := &"due_flag"


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
	if not can_come(next, day):
		return null
	return next


## Phase 7: requires_flag set and day ≥ the day in after_flag + after_days (a missing / non-numeric
## after_flag holds the story back).
static func can_come(story: StoryCorpseData, day: int) -> bool:
	if story == null:
		return false
	if story.requires_flag != &"" and not GameState.flag_on(story.requires_flag):
		return false
	if story.after_flag != &"":
		var since: Variant = GameState.get_flag(story.after_flag)
		if not (since is int or since is float):
			return false
		if day < int(since) + story.after_days:
			return false
	return true


## Phase 7: the due_flags of the story due on `day` (pure; daily_checks sets them).
static func due_flags(day: int, delivered: PackedStringArray, last_story_day: int, stories: Array[StoryCorpseData], cfg: StoryConfig) -> Array[StringName]:
	var out: Array[StringName] = []
	var story := due_story(day, delivered, last_story_day, stories, cfg)
	if story != null and story.due_flag != &"":
		out.append(story.due_flag)
	return out


## Stories not yet delivered (reservation of free plots). Phase 7: a story whose requires_flag is not
## set cannot come and reserves nothing (D1 before the consecration – Phase-6 games unchanged).
static func pending_count(delivered: PackedStringArray, stories: Array[StoryCorpseData]) -> int:
	var count := 0
	for story: StoryCorpseData in stories:
		if story == null or delivered.has(String(story.id)):
			continue
		if story.requires_flag != &"" and not GameState.flag_on(story.requires_flag):
			continue
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
## Phase 7: the due_flag of the story due today (D1 → hagedorn_dead = day, her Npc disappears) is set
## here, once (stories / deliveries from the CorpseManager of the running world) → &"due_flag".
static func daily_checks(day: int, has_key: bool, cfg: StoryConfig) -> Array[StringName]:
	var out: Array[StringName] = []
	var c := cfg if cfg != null else StoryConfig.new()
	if not has_key and day >= c.key_fallback_day:
		out.append(CHECK_ELDER_KEY)
	var tree := Engine.get_main_loop() as SceneTree
	var manager := tree.get_first_node_in_group(&"corpse_manager") if tree != null else null
	if manager != null and manager.has_method(&"story_delivered") and manager.has_method(&"story_last_day"):
		var stories: Array[StoryCorpseData] = []
		var injected: Variant = manager.get(&"stories")
		var list: Array = injected if injected is Array and not (injected as Array).is_empty() else Database.story_corpses()
		for res: Variant in list:
			if res is StoryCorpseData:
				stories.append(res)
		for flag: StringName in due_flags(day, manager.call(&"story_delivered"), int(manager.call(&"story_last_day")), stories, c):
			if not GameState.has_flag(flag):
				GameState.set_flag(flag, day)
				out.append(CHECK_DUE_FLAG)
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
