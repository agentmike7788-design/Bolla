class_name StoryDirector
extends RefCounted
## STUB (P1) – docs/PHASE4_DESIGN.md §2.11, §3.4. Pure rules of the story corpses S1–S5 (no
## node; the CorpseManager saves story_delivered / story_last_day and calls these).


## The next undelivered story (by order) with day ≥ earliest_day and
## day ≥ last_story_day + min_gap_days; null = none due.
static func due_story(_day: int, _delivered: PackedStringArray, _last_story_day: int, _stories: Array[StoryCorpseData], _cfg: StoryConfig) -> StoryCorpseData:
	return null


## Stories not yet delivered (reservation of free plots).
static func pending_count(_delivered: PackedStringArray, _stories: Array[StoryCorpseData]) -> int:
	return 0


## Name / age / cause / traits / story_id from the data, freshness 1.
static func make_record(_story: StoryCorpseData, _seed: int) -> CorpseRecord:
	return CorpseRecord.new()


## Fallbacks due today: &"elder_key" from key_fallback_day on without the key.
static func daily_checks(_day: int, _has_key: bool, _cfg: StoryConfig) -> Array[StringName]:
	return []
