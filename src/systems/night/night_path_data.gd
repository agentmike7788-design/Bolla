class_name NightPathData
extends Resource
## A sick-light sequence (docs/PHASE8_DESIGN.md §1.6, §3.4): data/night/paths/<id>.tres – np_ott, np_kehr.
## Deterministic from p8_open_day.

@export var id: StringName
@export var house: StringName
@export var patient: String
## The sick light burns in the nights p8_open_day + start_offset … + end_offset.
@export var start_offset: int
@export var end_offset: int
@export var visits: Array[NightVisitData] = []
## Death (np_ott): the night after p8_open_day + death_offset at death_minute (02:10) sets death_flag.
@export var death_offset: int = -1
@export var death_minute: int = 130
@export var death_flag: StringName = &""
## WatchSpot id (watch_ott / watch_kehr).
@export var watch_spot: StringName
