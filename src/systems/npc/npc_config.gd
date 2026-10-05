class_name NpcConfig
extends Resource
## NPC level of detail and remarks (docs/PHASE7_DESIGN.md §3.4, §9): data/config/npc_config.tres.

## Distance (m) to the camera focus up to which an NPC is fully animated (level 0) / from which
## it rests (level 2, animation paused).
@export var lod_full_distance: float = 26.0
@export var lod_rest_distance: float = 40.0
## Level 1: schedule evaluation every reduced_interval s (5 Hz), animation keeps running.
@export var reduced_interval: float = 0.2
## At most this many NPCs on level 0 (§9: ≤ 6 fully animated).
@export var max_full: int = 6
## NpcLod re-ranks this often per second.
@export var governor_hz: float = 2.0
## A villager closer than this (m) to the gravekeeper says its remark (once per day).
@export var remark_distance: float = 4.0
# Phase 8 (docs/PHASE8_DESIGN.md §3.2, §3.4, §9): runtime schedules walk 3.2 m per game minute
# (1.6 m/s real time); visible caps per region (graveyard 9, 16 on the night of the lights); standing
# figures (idle / kneel / mourn) rest from 26 m; level-1 rate 3 Hz on a festival.
@export var walk_m_per_minute: float = 3.2
@export var max_visible_graveyard: int = 9
@export var max_visible_fest: int = 16
@export var stand_rest_distance: float = 26.0
@export var fest_reduced_interval: float = 0.33
