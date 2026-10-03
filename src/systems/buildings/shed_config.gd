class_name ShedConfig
extends Resource
## The storage shed (docs/PHASE6_DESIGN.md §2.5): data/config/shed_config.tres. Arrays by shed
## level 0…3.

@export var slots_by_level: PackedInt32Array = [0, 24, 32, 40]
## Stack size multiplier for stack_categories (level 3: × 2).
@export var stack_mult_by_level: PackedInt32Array = [1, 1, 1, 2]
## ItemData.Category values (RESOURCE 0, MATERIAL 6).
@export var stack_categories: Array[int] = [0, 6]
## „Fehlendes aus dem Schuppen holen" from this level (minutes by level).
@export var fetch_min_level: int = 2
@export var fetch_minutes_by_level: PackedInt32Array = [0, 0, 10, 0]
## „Überschuss einlagern" from this level; never these items.
@export var store_min_level: int = 3
## W3 QA6-04: §2.5 „keine Gebeinkisten" – the empty boxes and the altar candles stay with the gravekeeper
## too (an old grave and the altar have no fetch).
@export var excluded_items: Array[StringName] = [&"bone_box_full", &"bone_box", &"altar_candle"]
