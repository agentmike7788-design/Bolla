class_name WandererData
extends Resource
## A wanderer of Phase 8 (docs/PHASE8_DESIGN.md §2.6, §3.4): data/village/wanderers/<id>.tres –
## beggar Veit Ammer, peddler Hanne Vogelsang (the robber has its own RobberConfig).

@export var id: StringName
@export var display_name: String
@export var dialogue_id: StringName
## Shop of the peddler (ShopData.id; &"" = none) and her days (day % every_days == day_rest; Hanne 6 / 1).
@export var shop_id: StringName = &""
@export var every_days: int = 0
@export var day_rest: int = 0
## Alms (Veit): coins per alms, the piety event, alms on different days for the clue (1 / alms / 3).
@export var alms_coins: int = 0
@export var alms_piety: StringName = &""
@export var alms_for_clue: int = 0
@export var clue_id: StringName = &""
