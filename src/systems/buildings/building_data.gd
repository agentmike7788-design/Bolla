class_name BuildingData
extends Resource
## A building on a fixed site (docs/PHASE6_DESIGN.md §2.1, §3.4): data/buildings/<id>.tres,
## Database.building(id) / buildings() (sorted by order). Level 0 is the site (model_site);
## levels 1…max_level() are `levels` in order.

@export var id: StringName
@export var display_name: String
@export var order: int = 0
## Layout ids of the site (Entities/site_<id>) and the door (Entities/door_<id>); the interior room.
@export var site_id: String
@export var door_id: String
@export var room_id: StringName
## Outdoor model of level 0 (the site).
@export var model_site: PackedScene
@export var levels: Array[BuildingLevelData] = []
## A corpse may be carried inside (crypt, chapel true; shed false).
@export var allows_corpse: bool = true
## „[E] Gruft betreten" / „[E] Hinaufgehen".
@export var prompt_enter: String = ""
@export var prompt_exit: String = ""


## The data of `level` (1…max_level()); null outside.
func level_data(level: int) -> BuildingLevelData:
	for l: BuildingLevelData in levels:
		if l != null and l.level == level:
			return l
	return null


## The highest level (0 without levels).
func max_level() -> int:
	var top := 0
	for l: BuildingLevelData in levels:
		if l != null:
			top = maxi(top, l.level)
	return top
