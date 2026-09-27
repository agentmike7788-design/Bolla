class_name BuildGrid
extends RefCounted
## Pure placement logic on a BuildMask (docs/PHASE3_DESIGN.md §3.4), testable without a scene
## tree. check() reasons, in this test order (each over the whole footprint):
##   &"blocked"        a cell is not buildable (section 0 / outside) or the cells span sections
##   &"locked_section" the section is not unlocked
##   &"obstacle"       a cell overlaps a standing obstacle (world XZ rects)
##   &"route"          a ROUTE cell and the decor is not allow_route
##   &"grave_ring"     a GRAVE_RING cell and the decor is not allow_grave_ring
##   &"occupied"       a cell already holds decor (occupied = {Vector2i: uid}); walkable decor
##                     (gravel) and non-walkable decor exclude each other like any two pieces
##   &"ok"

const REASON_OK := &"ok"
const REASON_BLOCKED := &"blocked"
const REASON_LOCKED_SECTION := &"locked_section"
const REASON_OBSTACLE := &"obstacle"
const REASON_ROUTE := &"route"
const REASON_GRAVE_RING := &"grave_ring"
const REASON_OCCUPIED := &"occupied"

var mask: BuildMask


func _init(build_mask: BuildMask) -> void:
	mask = build_mask


## Footprint size after `rot` quarter turns: rot 1/3 swaps X and Z.
static func rotated_size(size: Vector2i, rot: int) -> Vector2i:
	return Vector2i(size.y, size.x) if posmod(rot, 2) == 1 else size


## Cells of a `size` footprint anchored at `cell` (bottom-left = min x, min z); rot 1/3 swaps X and Z.
static func footprint_cells(cell: Vector2i, size: Vector2i, rot: int) -> Array[Vector2i]:
	var s := rotated_size(size, rot)
	var out: Array[Vector2i] = []
	for z: int in maxi(s.y, 0):
		for x: int in maxi(s.x, 0):
			out.append(cell + Vector2i(x, z))
	return out


## World XZ rect covered by the footprint.
func footprint_rect(cell: Vector2i, size: Vector2i, rot: int) -> Rect2:
	var s := rotated_size(size, rot)
	return Rect2(mask.origin + Vector2(cell) * mask.cell, Vector2(s) * mask.cell)


## World XZ rect of one cell.
func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(mask.origin + Vector2(c) * mask.cell, Vector2(mask.cell, mask.cell))


func check(decor: DecorData, cell: Vector2i, rot: int, occupied: Dictionary, blockers: Array[Rect2], unlocked: PackedInt32Array) -> StringName:
	if decor == null or mask == null:
		return REASON_BLOCKED
	var cells := footprint_cells(cell, decor.footprint, rot)
	if cells.is_empty():
		return REASON_BLOCKED
	var section := mask.section_at(cells[0])
	for c: Vector2i in cells:
		var s := mask.section_at(c)
		if s == 0 or s != section:
			return REASON_BLOCKED
	if not unlocked.has(section):
		return REASON_LOCKED_SECTION
	for c: Vector2i in cells:
		var r := cell_rect(c)
		for b: Rect2 in blockers:
			if b.intersects(r):
				return REASON_OBSTACLE
	if not decor.allow_route:
		for c: Vector2i in cells:
			if mask.flags_at(c) & BuildMask.ROUTE:
				return REASON_ROUTE
	if not decor.allow_grave_ring:
		for c: Vector2i in cells:
			if mask.flags_at(c) & BuildMask.GRAVE_RING:
				return REASON_GRAVE_RING
	for c: Vector2i in cells:
		if occupied.has(c):
			return REASON_OCCUPIED
	return REASON_OK
