class_name DecorData
extends Resource
## One placeable decor kind (docs/PHASE3_DESIGN.md §2.3): data/decor/<item_id>.tres.

## = item id (decor_bench_wood …).
@export var id: StringName
@export var display_name: String = ""
@export var model: PackedScene
## Cells (0.5 m) at rotation 0 (X × Z).
@export var footprint: Vector2i = Vector2i.ONE
## Contribution of a kind = floor(min(count, counted_max) × zier / zier_divisor) (§2.3).
@export var zier: int = 1
@export var zier_divisor: int = 1
## Pieces that count at most (0 = unlimited).
@export var counted_max: int = 0
## Pieces that may be placed at most (0 = unlimited; DecorConfig.max_placed applies anyway).
@export var place_max: int = 0
## Gravel: walkable; walkable and non-walkable decor never share a cell.
@export var walkable: bool = false
@export var allow_route: bool = false
@export var allow_grave_ring: bool = false
@export var suppresses_dirt: bool = false
## Ghost mood bonus radius in m (0 = none, §2.8).
@export var ghost_bonus_radius: float = 0.0
## Box collider size (ZERO = no collision).
@export var collider_size: Vector3 = Vector3.ZERO
