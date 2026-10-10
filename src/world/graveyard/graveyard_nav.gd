class_name GraveyardNav
extends Resource
## Baked walking net of the graveyard (docs/PHASE8_DESIGN.md §4.2, §4.8 point 6; graveyard_build_phase8.gd):
## a clearance grid (free distance to the nearest collision at hip height, 2 cm steps) and a small graph of
## waypoint ids (gate_inside, the visitor spots gv_*, the hut corner, the night and Lichtgang places and the
## baked intermediate points vw_*) with all-pairs shortest paths. WorldRoot.route_between answers with
## waypoint ids – visitors, the apprentice, the robber and the procession walk around graves, fences and
## buildings instead of straight through them. No autoloads (the builder preloads it).

## Graph nodes: waypoint ids and their XZ positions.
@export var ids: PackedStringArray = []
@export var points: PackedVector2Array = []
## n × n shortest walking distances (m; INF = unreachable) and the next node on that path (-1 = none).
@export var dist: PackedFloat32Array = []
@export var next: PackedInt32Array = []
## Clearance grid: origin (x, z of cell 0), cell size (m), size (cells); bytes = clearance / 0.02 m (255 = ≥ 5.1 m).
@export var origin: Vector2 = Vector2.ZERO
@export var cell: float = 0.2
@export var size: Vector2i = Vector2i.ZERO
@export var grid: PackedByteArray = []
## Clearance a walker needs on a straight leg (m).
@export var clearance: float = 0.38
## Longest straight leg between two nodes (m).
@export var edge_max: float = 14.0

const UNIT := 0.02
const INF := 1.0e9


## Free distance at `p` (0 outside the grid).
func clearance_at(p: Vector2) -> float:
	return clearance_in(grid, origin, cell, size, p)


## The straight leg a → b keeps `need` (default: clearance) from every collision.
func line_free(a: Vector2, b: Vector2, need: float = -1.0) -> bool:
	return los(grid, origin, cell, size, a, b, clearance if need < 0.0 else need)


func index_of(id: String) -> int:
	return ids.find(id)


## Node ids from node i to node j (both included; empty when unreachable).
func node_path(i: int, j: int) -> PackedStringArray:
	var out := PackedStringArray()
	var n := ids.size()
	if i < 0 or j < 0 or i >= n or j >= n or dist[i * n + j] >= INF * 0.5:
		return out
	var k := i
	out.append(ids[k])
	var guard := 0
	while k != j and guard < n + 1:
		k = next[k * n + j]
		if k < 0:
			return PackedStringArray()
		out.append(ids[k])
		guard += 1
	return out


## Up to `count` graph nodes visible from p (straight leg free), nearest first: [[index, distance], …].
func visible_nodes(p: Vector2, count: int = 6) -> Array:
	var order: Array = []
	for i: int in ids.size():
		var d := p.distance_to(points[i])
		if d <= edge_max:
			order.append([i, d])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var out: Array = []
	for e: Array in order:
		if line_free(p, points[e[0]], minf(clearance, clearance_at(p) - 0.01)) or float(e[1]) < 0.25:
			out.append(e)
			if out.size() >= count:
				break
	return out


static func clearance_in(g: PackedByteArray, o: Vector2, c: float, s: Vector2i, p: Vector2) -> float:
	var x := floori((p.x - o.x) / c)
	var z := floori((p.y - o.y) / c)
	if x < 0 or z < 0 or x >= s.x or z >= s.y:
		return 0.0
	return float(g[z * s.x + x]) * UNIT


static func los(g: PackedByteArray, o: Vector2, c: float, s: Vector2i, a: Vector2, b: Vector2, need: float) -> bool:
	var d := a.distance_to(b)
	var steps := maxi(1, ceili(d / (c * 0.5)))
	for k: int in steps + 1:
		if clearance_in(g, o, c, s, a.lerp(b, float(k) / steps)) < need:
			return false
	return true
