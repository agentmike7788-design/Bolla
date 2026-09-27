class_name BuildGrid
extends RefCounted
## STUB (P2) – docs/PHASE3_DESIGN.md §3.4. Pure placement logic on a BuildMask, testable
## without a scene tree.
## check() reasons, in this test order: &"ok", &"blocked", &"locked_section", &"obstacle",
## &"route", &"grave_ring", &"occupied". occupied = {Vector2i: uid}; walkable decor (gravel) and
## non-walkable decor exclude each other; all cells must lie in the same section.

var mask: BuildMask


func _init(build_mask: BuildMask) -> void:
	mask = build_mask


## Cells of a `size` footprint anchored at `cell` (bottom-left); rot 1/3 swaps X and Z.
static func footprint_cells(_cell: Vector2i, _size: Vector2i, _rot: int) -> Array[Vector2i]:
	return []


func check(_decor: DecorData, _cell: Vector2i, _rot: int, _occupied: Dictionary, _blockers: Array[Rect2], _unlocked: PackedInt32Array) -> StringName:
	return &"blocked"
