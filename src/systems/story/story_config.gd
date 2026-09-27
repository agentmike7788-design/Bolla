class_name StoryConfig
extends Resource
## Story delivery rules (docs/PHASE4_DESIGN.md §2.11): data/config/story_config.tres.

## At least this many days between two story corpses.
@export var min_gap_days: int = 2
## From this day on (day_started) the elder key is given if still missing.
@export var key_fallback_day: int = 12
@export var key_flag: StringName = &"has_elder_key"
@export var key_clue: StringName = &"c_elder_key"
@export var chapter_section: StringName = &"elder"
@export var finale_story: StringName = &"s5_moor"
@export_multiline var key_fallback_text: String = ""
@export var reserve_note: String = "Heute nichts. Aber halt eine Grube frei."
