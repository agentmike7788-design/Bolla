class_name PrepConfig
extends Resource
## Preparing the dead (docs/PHASE4_DESIGN.md §2.3, §2.5): data/config/prep_config.tres.

@export var wash_minutes: int = 15
@export var wash_tool: StringName = &"scrub_brush"
## Dress kind → {"item": consumed item, "minutes": int}.
@export var dress: Dictionary[StringName, Dictionary] = {&"shroud": {"item": &"shroud", "minutes": 10}, &"gown": {"item": &"burial_gown", "minutes": 15}}
@export var lay_out_minutes: int = 10
@export var lay_out_tool: StringName = &"comb"
@export var balm_item: StringName = &"juniper"
@export var balm_minutes: int = 10
## Decay factor inside a juniper window (0.25 = a quarter of the normal speed).
@export var balm_factor: float = 0.25
@export var balm_window_minutes: int = 1080
@export var balm_max_windows: int = 4
# Phase 5 (docs/PHASE5_DESIGN.md §2.6): herb_bundle smokes like juniper. The first available item
# in list order is used (P6); balm_item stays = the first element (compatibility).
@export var balm_items: Array[StringName] = [&"juniper", &"herb_bundle"]


## Item consumed by dressing in `kind` (&"" if unknown).
func dress_item(kind: StringName) -> StringName:
	return StringName((dress.get(kind, {}) as Dictionary).get("item", &""))


## Minutes of dressing in `kind` (0 if unknown).
func dress_minutes(kind: StringName) -> int:
	return int((dress.get(kind, {}) as Dictionary).get("minutes", 0))
