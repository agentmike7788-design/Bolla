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
# Phase 9 (docs/PHASE9_DESIGN.md §2.2.2, §3.4; np_sieber).
## Offsets relative to the day in this GameState flag ("" = p8_open_day; np_sieber: q_light_day).
@export var anchor_flag: StringName = &""
## Set → the sequence does not run (ending A: sieber_gone).
@export var cancel_flag: StringName = &""
