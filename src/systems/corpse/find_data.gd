class_name FindData
extends Resource
## One find of the examination (docs/PHASE4_DESIGN.md §2.2): data/finds/<id>.tres.
## Revealed when its step completes with freshness ≥ min_freshness, otherwise lost.

@export var id: StringName
## CorpseRecord.STEP_* (clothing, hands, wounds, pockets).
@export var step: StringName
@export var label: String = ""
## "" = the trait's reveal_text from CorpseTables.
@export_multiline var text: String = ""
@export_multiline var lost_text: String = ""
## 0.0 paper / objects (never lost) · 0.3 skin marks · 0.6 fine traces.
@export var min_freshness: float = 0.0
## Generic find of this trait; a story find with trait_id replaces the generic one.
@export var trait_id: StringName = &""
## Generic cause detail (f_cause_<cause>).
@export var cause_id: StringName = &""
## Only on story corpses (listed in StoryCorpseData.finds).
@export var story_only: bool = false
## ClueData id added to the journal on reveal (&"" = none).
@export var clue_id: StringName = &""
## GameState flag set on reveal (&"" = none), e.g. has_elder_key.
@export var sets_flag: StringName = &""


## Lost at this freshness (strictly below min_freshness).
func is_lost_at(freshness: float) -> bool:
	return freshness < min_freshness


func is_generic() -> bool:
	return not story_only
