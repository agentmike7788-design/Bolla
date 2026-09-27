class_name DecorConfig
extends Resource
## Decoration & build mode values (docs/PHASE3_DESIGN.md §2.3, §3.4): data/config/decor_config.tres.

## Build grid cell in m (= BuildMask.cell).
@export var cell_size: float = 0.5
## All placed decor together (incl. gravel).
@export var max_placed: int = 80
@export var place_minutes: int = 5
@export var remove_minutes: int = 5
## Keyboard fallback: distance of the cursor cell in front of the gravekeeper (m).
@export var cursor_distance: float = 1.2
## Mouse cursor cell is clamped to this distance around the gravekeeper (m, §3.4 cursor_cell).
@export var cursor_reach: float = 8.0
## Grid overlay radius around the cursor (m).
@export var grid_overlay_radius: float = 3.0
