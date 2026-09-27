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
