class_name KinData
extends Resource
## One mourning household or a villager who visits a grave (docs/PHASE8_DESIGN.md §2.1.4, §2.2.1, §3.4):
## data/visitors/kin/<id>.tres.

@export var kin_id: StringName
@export var display_name: String
## Village house (Village.mourning_houses; &"" for villagers with fixed graves).
@export var house: StringName
## Npc layout id on the graveyard (npc_kin_kehr …) or npc_<villager>_g.
@export var npc_path_id: StringName
## Set: a villager (pays with relationship instead of coins, §2.2.5).
@export var villager_id: StringName = &""
## Women kneel (long skirt), men stand with the hat in their hands (§2.2.3).
@export var kneels: bool = true
## Model of the bouquet (ph_prop_bouquet_*; &"" = brings nothing).
@export var bouquet_model: StringName = &""
@export var dialogue_id: StringName
## Fixed graves of a villager: old_01, old_08, the D1 / S5 grave (households: from kin_house).
@export var fixed_graves: PackedStringArray = []
## Villagers (§2.1.4): every n days at visit_minute; 0 = a household by plan (§2.2.2).
@export var visit_every_days: int = 0
@export var visit_minute: int = 0
## First visit day = p8_open_day + first_offset (Esch 2, Theres 2, Liesel 1).
@export var first_offset: int = 0
