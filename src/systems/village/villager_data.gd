class_name VillagerData
extends Resource
## One villager of Hollerbrück (docs/PHASE7_DESIGN.md §2.1, §3.4): data/village/villagers/<npc_id>.tres.

@export var npc_id: StringName
@export var display_name: String
@export var role: String = ""
## Dialogue of the villager (v_<npc_id>).
@export var dialogue_id: StringName
## ShopData.id (&"" = no shop).
@export var shop_id: StringName = &""
## HouseDoor.door_id of the villager's house (&"" = none / a cottage without interior).
@export var home_door: StringName = &""
## Item ids the villager likes as a gift (§2.4 gift +4).
@export var gifts_liked: Array[StringName] = []
## Relationship at the first meeting before the reputation / piety bonus (§2.1 „Start").
@export var start_value: int = 20
## Relationship change per specimen sold to Quast (priest −4, washer −3, oldwoman −2, surgeon +2).
@export var specimen_delta: int = 0
## Relationship change per specimen returned to its grave (priest +1, washer +2).
@export var returned_delta: int = 0
## true: the start value also gets RelationshipConfig.piety_start_bonus (priest, washer).
@export var piety_sensitive: bool = false
## Remarks (§2.4 Gerede) by key: rep_<tier>, piety_<tier>, friend, specimens.
@export var remarks: Dictionary[StringName, PackedStringArray] = {}
