class_name SectionData
extends Resource
## One cemetery section (docs/PHASE3_DESIGN.md §1.2 / §2.1): data/sections/<id>.tres.
## `order` is also the section index in the BuildMask (yard 1, east 2, north 3).

@export var id: StringName
@export var display_name: String = ""
## yard 1, east 2, north 3 (= BuildMask section index).
@export var order: int = 0
@export var starts_unlocked: bool = false
## Section that must be unlocked before this one can be worked on (&"" = none).
@export var requires_section: StringName = &""
## CemeteryRating tier required before this one can be worked on (&"" = none).
@export var requires_rating: StringName = &""
## Maximum decor points this section contributes (§2.3).
@export var decor_cap: int = 9
@export_multiline var unlock_text: String = ""
# Phase 4 (docs/PHASE4_DESIGN.md §2.10, §3.4)
## GameState flag required before this section can be worked on (&"" = none), e.g. has_elder_key.
@export var requires_flag: StringName = &""
## Dimmed obstacle text while requires_flag is missing ("Das Pförtchen ist verschlossen.").
@export var requires_flag_text: String = ""
## Counts for the Phase-3 goal cemetery_complete (elder: false).
@export var counts_for_cemetery: bool = true
## Chapter completed by filling this section (elder: &"six_pits").
@export var chapter: StringName = &""
# Phase 5 (docs/PHASE5_DESIGN.md §3.4, §4.2)
## false = a work area (bruch, quarry): no plots, no reputation section_unlocked, not in the
## cemetery overview / Ehrwürdig.
@export var is_burial: bool = true
