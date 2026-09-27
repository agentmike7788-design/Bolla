class_name BuildMask
extends Resource
## Baked build mask (docs/PHASE3_DESIGN.md §4.3): src/world/graveyard/build_mask.res, written by
## the world builder. One byte per cell: low nibble = section index (SectionData.order; 0 = not
## buildable), plus the GRAVE_RING / ROUTE flags. Row-major: index = c.y * size.x + c.x, where
## c.x runs along world X and c.y along world Z.

const BLOCKED := 0
const SECTION_MASK := 0x0F
const GRAVE_RING := 0x10
const ROUTE := 0x20

## World XZ of the grid corner (min x, min z).
@export var origin: Vector2 = Vector2.ZERO
@export var cell: float = 0.5
@export var size: Vector2i = Vector2i.ZERO
@export var cells: PackedByteArray = PackedByteArray()


## Cell containing world XZ point `p` (may lie outside the mask).
func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))


## World XZ of the cell centre.
func cell_to_world(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


## Flags of cell `c`; outside the mask = BLOCKED.
func flags_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return BLOCKED
	var i := c.y * size.x + c.x
	return cells[i] if i < cells.size() else BLOCKED


## Section index of cell `c` (flags & SECTION_MASK; 0 = not buildable).
func section_at(c: Vector2i) -> int:
	return flags_at(c) & SECTION_MASK
