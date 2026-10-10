extends RefCounted
## Phase-8 helpers of graveyard_builder.gd (build-time tool, static, preloaded – docs/PHASE8_DESIGN.md §3.1,
## §4.1–§4.5, §4.8): the new system nodes (NpcLife, ChatterRunner, Visitors, GraveCare, Apprentice, Friendship,
## Festivals, Wanderers, NightRobber, NightPaths), the hut corner (ApprenticeBoard, ApprenticeBox, the bench,
## RainBarrel – layout phase8.corner), a TipStone under every grave plot and old grave, and the walking net:
## the visitor spots gv_<plot> (layout phase8.visitor_spot), the intermediate points vw_* and the baked routes
## (road_end → … → gate_inside → … → gv_<plot>) from an occupancy grid of the colliders at hip height
## (GraveyardNav, src/world/graveyard/graveyard_nav.res; WorldRoot.visitor_route / route_between). The baked
## spots, points and routes are written back into graveyard_layout.json (visitor_spots, visitor_waypoints,
## visitor_routes). The third Lindenacker row, its fence, obstacles and the new Npc are layout data that the
## Phase-3…7 helpers build. Scripts are loaded by path (see graveyard_builder.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const Nav := preload("res://src/world/graveyard/graveyard_nav.gd")
const LAYOUT_PATH := "res://data/world/graveyard_layout.json"
const OUT_NAV := "res://src/world/graveyard/graveyard_nav.res"
## §3.1: node name → script (groups / save_id / save_order are set by the scripts themselves: npc_life 70 …
## night_paths 78; ChatterRunner is not saved).
const SYSTEMS := [
	["NpcLife", "res://src/systems/npc_life/npc_life.gd"],
	["ChatterRunner", "res://src/systems/npc_life/chatter_runner.gd"],
	["Visitors", "res://src/systems/visitors/visitors.gd"],
	["GraveCare", "res://src/systems/grave_care/grave_care.gd"],
	["Apprentice", "res://src/systems/apprentice/apprentice.gd"],
	["Friendship", "res://src/systems/friendship/friendship.gd"],
	["Festivals", "res://src/systems/festivals/festivals.gd"],
	["Wanderers", "res://src/systems/village/wanderers.gd"],
	["NightRobber", "res://src/systems/night/night_robber.gd"],
	["NightPaths", "res://src/systems/night/night_paths.gd"],
]
const CORNER_SCENES := {
	"apprentice_board": "res://src/entities/apprentice_board/apprentice_board.tscn",
	"apprentice_box": "res://src/entities/apprentice_box/apprentice_box.tscn",
	"rain_barrel": "res://src/entities/rain_barrel/rain_barrel.tscn",
}
const TIP_SCENE := "res://src/entities/tip_stone/tip_stone.tscn"
const GATE_BELL_SCENE := "res://src/entities/gate_bell/gate_bell.tscn"
## The coins lie on the mound right in front of the stone (plot-local; the stone stands at z −1,02).
const TIP_LOCAL := Vector3(-0.2, 0.17, -0.74)
const ROLE_PIT := "pit"
## Subtrees whose shapes are no obstacles of the walking net (the far-away rooms, the village, the player, the
## Npc bodies, the overgrowth of locked sections).
const SKIP_ROOTS: Array[String] = ["GroundCollision", "Player", "Interiors", "HutInterior", "Regions", "Decor/Overgrowth", "UI"]
const SQRT2 := 1.41421356


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		ctx.add(systems, node)


## Entities/<id> per layout phase8.corner entry: the entity scene (or a plain Node3D for a prop) with its
## model as child "Model" and the layout collider.
static func build_corner(ctx: Ctx, entities: Node3D) -> void:
	for c: Dictionary in ctx.layout.get("phase8", {}).get("corner", []):
		var node: Node3D
		if CORNER_SCENES.has(String(c.type)):
			node = (load(CORNER_SCENES[String(c.type)]) as PackedScene).instantiate() as Node3D
		else:
			node = Node3D.new()
		node.name = String(c.id)
		node.transform = ctx.ground_xform(Ctx.v2(c.pos), float(c.get("rot_y", 0.0)))
		ctx.add(entities, node)
		var model := (load(Ctx.model_path(String(c.model))) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		ctx.add(node, model)
		Colliders.collider(ctx, String(c.model), node.transform, String(c.id))


## G8 Runde 1 (B8-1): Entities/gate_bell – GateBell with its model (child "Model", the swinging mesh `bell`) on the
## road face of the east gate post (layout phase8.gate_bell). No collider: it hangs above head height and the walking
## net stays as baked.
static func build_gate_bell(ctx: Ctx, entities: Node3D) -> void:
	var c: Dictionary = ctx.layout.get("phase8", {}).get("gate_bell", {})
	if c.is_empty():
		return
	var node := (load(GATE_BELL_SCENE) as PackedScene).instantiate() as Node3D
	node.name = String(c.id)
	node.transform = ctx.ground_xform(Ctx.v2(c.pos), float(c.get("rot_y", 0.0)))
	ctx.add(entities, node)
	var model := (load(Ctx.model_path(String(c.model))) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	ctx.add(node, model)


## A TipStone (coins on the stone) under every grave plot and old grave.
static func build_tip_stones(ctx: Ctx) -> void:
	for parent: String in ["Entities", "Decor/OldGraves"]:
		var group := ctx.scene_root.get_node(parent)
		for child: Node in group.get_children():
			if child.get("grave_id") == null or child.get_node_or_null(^"TipStone") != null:
				continue
			var stone := (load(TIP_SCENE) as PackedScene).instantiate() as Node3D
			stone.name = "TipStone"
			stone.position = TIP_LOCAL
			ctx.add(child, stone)


# --- the walking net (§4.2, §4.8 point 6) -------------------------------------------------------------------

## Bakes spots, points, routes and the GraveyardNav; adds the markers gv_* / vw_* under Waypoints, sets
## WorldRoot.visitor_routes / nav and writes the baked keys back into the layout file.
@warning_ignore("integer_division")
static func bake_nav(ctx: Ctx, waypoints: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.phase8.nav
	var r: Array = cfg.rect
	var cell := float(cfg.cell)
	var origin := Vector2(float(r[0]), float(r[1]))
	var size := Vector2i(ceili((float(r[2]) - origin.x) / cell), ceili((float(r[3]) - origin.y) / cell))
	var need := float(cfg.clearance)
	var t0 := Time.get_ticks_msec()
	var occ := _occupancy(ctx, origin, cell, size, Ctx.v2(cfg.band))
	var dist := _distance(occ, size, cell)
	print("  nav grid %s in %d ms" % [size, Time.get_ticks_msec() - t0])
	var grid := PackedByteArray()
	grid.resize(size.x * size.y)
	for i: int in dist.size():
		grid[i] = clampi(roundi(dist[i] / Nav.UNIT), 0, 255)
	var wp: Dictionary = ctx.layout.waypoints
	var spots := _visitor_spots(ctx, grid, origin, cell, size)
	var pos := {}
	for id: String in wp:
		pos[id] = Ctx.v2(wp[id])
	for id: String in spots:
		pos[id] = Vector2(float(spots[id][0]), float(spots[id][1]))
	# Grid Dijkstra from the start; every target's cell path, smoothed to corner points, merged to vw_*.
	var start := String(cfg.start)
	var field := _dijkstra(grid, origin, cell, size, pos[start], need, float(cfg.near_cost), float(cfg.near_range))
	print("  nav field in %d ms" % (Time.get_ticks_msec() - t0))
	var targets: Array[String] = []
	for id: String in spots:
		targets.append(id)
	for id: String in cfg.extra_targets:
		targets.append(String(id))
	# Jakob's stands at the care spots (ApprenticePlanner.SPOT_STAND, 0.7 m towards the camera) join the net as
	# "@x,y,z" literals – ScheduleBuilder.point reads them like waypoints.
	var stand := Ctx.v2(cfg.get("care_stand", [0.0, 0.7]))
	for dspot: Dictionary in ctx.layout.dirt_spots:
		var p := Ctx.v2(dspot.pos) + stand
		var lit := "@%.2f,%.2f,%.2f" % [p.x, ctx.ground_height(p), p.y]
		pos[lit] = p
		targets.append(lit)
	var vw: Dictionary = {}   # id -> Vector2
	var vw_order: Array[String] = []
	var seqs: Array = []   # per target: the node ids of its smoothed way (start, vw…, target)
	for t: String in targets:
		var cells := _cell_path(field, size, origin, cell, pos[t], grid, need)
		if cells.is_empty():
			push_error("[nav] no path to %s" % t)
			continue
		var pts: Array[Vector2] = [pos[start]]
		for c: int in cells:
			pts.append(origin + (Vector2(c % size.x, c / size.x) + Vector2(0.5, 0.5)) * cell)
		pts.append(pos[t])
		var corners := _smooth(pts, grid, origin, cell, size, need)
		var prev: Vector2 = pos[start]
		var seq: Array[String] = [start]
		for k: int in range(1, corners.size() - 1):
			var p: Vector2 = corners[k]
			var hit := ""
			for id: String in vw_order:
				if (vw[id] as Vector2).distance_to(p) <= float(cfg.merge) and Nav.los(grid, origin, cell, size, prev, vw[id], need) \
						and Nav.los(grid, origin, cell, size, vw[id], corners[k + 1], minf(need, Nav.clearance_in(grid, origin, cell, size, corners[k + 1]) - 0.01)):
					hit = id
					break
			if hit == "":
				hit = "vw_%02d" % (vw_order.size() + 1)
				vw[hit] = Vector2(snappedf(p.x, 0.05), snappedf(p.y, 0.05))
				vw_order.append(hit)
			prev = vw[hit]
			if seq[seq.size() - 1] != hit:
				seq.append(hit)
		seq.append(t)
		seqs.append(seq)
	for id: String in vw_order:
		pos[id] = vw[id]
	print("  nav paths in %d ms (%d vw)" % [Time.get_ticks_msec() - t0, vw_order.size()])
	# The graph: start, named targets, spots and vw points; straight legs with clearance (endpoints at their own).
	var ids := PackedStringArray([start])
	for t: String in targets:
		if not ids.has(t):
			ids.append(t)
	for id: String in vw_order:
		ids.append(id)
	var n := ids.size()
	var points := PackedVector2Array()
	for id: String in ids:
		points.append(pos[id])
	var d := PackedFloat32Array()
	d.resize(n * n)
	var nx := PackedInt32Array()
	nx.resize(n * n)
	d.fill(Nav.INF)
	nx.fill(-1)
	for i: int in n:
		d[i * n + i] = 0.0
		nx[i * n + i] = i
	var own := PackedFloat32Array()
	for i: int in n:
		own.append(Nav.clearance_in(grid, origin, cell, size, points[i]))
	var edges := 0
	for i: int in n:
		for j: int in range(i + 1, n):
			var len := points[i].distance_to(points[j])
			if len > float(cfg.edge_max):
				continue
			var lo := minf(need, minf(own[i], own[j]) - 0.01)
			if not Nav.leg_free(grid, origin, cell, size, points[i], points[j], need, lo):
				continue
			d[i * n + j] = len
			d[j * n + i] = len
			nx[i * n + j] = j
			nx[j * n + i] = i
			edges += 1
	# The smoothed ways themselves are legs (a snapped corner may miss the strict check by a hair).
	for seq: Array in seqs:
		for k: int in range(1, seq.size()):
			var i := ids.find(String(seq[k - 1]))
			var j := ids.find(String(seq[k]))
			if i < 0 or j < 0 or i == j or d[i * n + j] < Nav.INF * 0.5:
				continue
			var len := points[i].distance_to(points[j])
			d[i * n + j] = len
			d[j * n + i] = len
			nx[i * n + j] = j
			nx[j * n + i] = i
			edges += 1
	for k: int in n:
		for i: int in n:
			var dik := d[i * n + k]
			if dik >= Nav.INF * 0.5:
				continue
			for j: int in n:
				var alt := dik + d[k * n + j]
				if alt < d[i * n + j]:
					d[i * n + j] = alt
					nx[i * n + j] = nx[i * n + k]
	var nav: Resource = Nav.new()
	nav.set("ids", ids)
	nav.set("points", points)
	nav.set("dist", d)
	nav.set("next", nx)
	nav.set("origin", origin)
	nav.set("cell", cell)
	nav.set("size", size)
	nav.set("grid", grid)
	nav.set("clearance", need)
	nav.set("edge_max", float(cfg.edge_max))
	var err := ResourceSaver.save(nav, OUT_NAV, ResourceSaver.FLAG_COMPRESS)
	assert(err == OK, "save failed: " + OUT_NAV)
	print("  saved %s (%d nodes, %d legs, %d vw, grid %s)" % [OUT_NAV, n, edges, vw_order.size(), size])
	# Routes: route_in + the graph path start → target.
	var route_in: PackedStringArray = PackedStringArray(cfg.route_in)
	var routes := {}
	for t: String in targets:
		if t.begins_with("@"):
			continue
		var path: PackedStringArray = nav.call(&"node_path", 0, ids.find(t))
		if path.is_empty():
			push_error("[nav] target %s not connected" % t)
			continue
		var full := route_in.duplicate()
		for k: int in range(1, path.size()):
			full.append(path[k])
		routes[t.trim_prefix("gv_") if t.begins_with("gv_") else t] = full
	# Markers, the world root's data, the layout file.
	for id: String in spots:
		var m := Marker3D.new()
		m.name = id
		var p: Vector2 = pos[id]
		m.position = Vector3(p.x, ctx.ground_height(p), p.y)
		m.rotation_degrees.y = float(spots[id][2])
		m.set_meta(&"facing", true)
		ctx.add(waypoints, m)
	for id: String in vw_order:
		var m := Marker3D.new()
		m.name = id
		var p: Vector2 = pos[id]
		m.position = Vector3(p.x, ctx.ground_height(p), p.y)
		ctx.add(waypoints, m)
	ctx.scene_root.set("visitor_routes", routes)
	ctx.scene_root.set("nav", load(OUT_NAV))
	_write_layout(spots, vw, vw_order, routes)


## Occupancy (1 = a collision at hip height) of every CollisionShape3D of a StaticBody3D in the world, except
## the far rooms / village / player / overgrowth, the clearable obstacles (counted as cleared) and the plots'
## pit shapes (graves count with mound and marker).
static func _occupancy(ctx: Ctx, origin: Vector2, cell: float, size: Vector2i, band: Vector2) -> PackedByteArray:
	var occ := PackedByteArray()
	occ.resize(size.x * size.y)
	var root := ctx.scene_root
	for node: Node in root.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if not shape_node.get_parent() is StaticBody3D or shape_node.shape == null:
			continue
		var rel := String(root.get_path_to(shape_node))
		var skip := false
		for s: String in SKIP_ROOTS:
			if rel.begins_with(s + "/"):
				skip = true
		if skip or String(shape_node.get_meta(&"role", "")) == ROLE_PIT or _in_obstacle(shape_node, root):
			continue
		var xf := Ctx.rel_xform(shape_node, root)
		var at := Vector2(xf.origin.x, xf.origin.z)
		var g := ctx.ground_height(at)
		if shape_node.shape is BoxShape3D:
			var he := (shape_node.shape as BoxShape3D).size * 0.5
			var hy := absf(xf.basis.y.y) * he.y
			if xf.origin.y + hy < g + band.x or xf.origin.y - hy > g + band.y:
				continue
			var ax := Vector2(xf.basis.x.x, xf.basis.x.z)
			var az := Vector2(xf.basis.z.x, xf.basis.z.z)
			var ex := ax.length() * he.x
			var ez := az.length() * he.z
			ax = ax.normalized()
			az = az.normalized()
			var reach := Vector2(absf(ax.x) * ex + absf(az.x) * ez, absf(ax.y) * ex + absf(az.y) * ez)
			occ = _fill(occ, origin, cell, size, at - reach, at + reach, {"at": at, "ax": ax, "az": az, "ex": ex, "ez": ez})
		elif shape_node.shape is CylinderShape3D:
			var cyl := shape_node.shape as CylinderShape3D
			var hy := absf(xf.basis.y.y) * cyl.height * 0.5
			if xf.origin.y + hy < g + band.x or xf.origin.y - hy > g + band.y:
				continue
			var rad := cyl.radius * Vector2(xf.basis.x.x, xf.basis.x.z).length()
			occ = _fill(occ, origin, cell, size, at - Vector2(rad, rad), at + Vector2(rad, rad), {"at": at, "r": rad})
	return occ


static func _in_obstacle(node: Node, root: Node) -> bool:
	# A cleared fence gap is a repaired fence: its RepairedCollision stays an obstacle.
	if node.get_parent() != null and String(node.get_parent().name) == "RepairedCollision":
		return false
	var n := node.get_parent()
	while n != null and n != root:
		if n.get("obstacle_id") != null:
			return true
		n = n.get_parent()
	return false


## Marks the cells whose centre lies in the shape: {at, r} = circle, {at, ax, az, ex, ez} = oriented rect.
## (Packed arrays are values in GDScript: the filled copy is returned.)
static func _fill(occ: PackedByteArray, origin: Vector2, cell: float, size: Vector2i, lo: Vector2, hi: Vector2, shape: Dictionary) -> PackedByteArray:
	var x0 := maxi(0, floori((lo.x - origin.x) / cell))
	var x1 := mini(size.x - 1, floori((hi.x - origin.x) / cell))
	var z0 := maxi(0, floori((lo.y - origin.y) / cell))
	var z1 := mini(size.y - 1, floori((hi.y - origin.y) / cell))
	var at: Vector2 = shape.at
	var circle := shape.has("r")
	for z: int in range(z0, z1 + 1):
		for x: int in range(x0, x1 + 1):
			var q := origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell - at
			# A cell counts when the shape touches it (0.35 cell of slack): a 14 cm fence between two cell
			# centres must not vanish from the grid.
			var inside := false
			if circle:
				inside = q.length() <= float(shape.r) + cell * 0.35
			else:
				inside = absf(q.dot(shape.ax)) <= float(shape.ex) + cell * 0.35 and absf(q.dot(shape.az)) <= float(shape.ez) + cell * 0.35
			if inside:
				occ[z * size.x + x] = 1
	return occ


## Chamfer distance (m) from every cell centre to the nearest occupied cell's edge.
static func _distance(occ: PackedByteArray, size: Vector2i, cell: float) -> PackedFloat32Array:
	var w := size.x
	var h := size.y
	var d := PackedFloat32Array()
	d.resize(w * h)
	for i: int in w * h:
		d[i] = 0.0 if occ[i] == 1 else 1.0e6
	var diag := cell * SQRT2
	for z: int in h:
		for x: int in w:
			var i := z * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[i - 1] + cell)
			if z > 0:
				v = minf(v, d[i - w] + cell)
				if x > 0:
					v = minf(v, d[i - w - 1] + diag)
				if x < w - 1:
					v = minf(v, d[i - w + 1] + diag)
			d[i] = v
	for z: int in range(h - 1, -1, -1):
		for x: int in range(w - 1, -1, -1):
			var i := z * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x < w - 1:
				v = minf(v, d[i + 1] + cell)
			if z < h - 1:
				v = minf(v, d[i + w] + cell)
				if x < w - 1:
					v = minf(v, d[i + w + 1] + diag)
				if x > 0:
					v = minf(v, d[i + w - 1] + diag)
			d[i] = v
	for i: int in w * h:
		d[i] = maxf(0.0, d[i] - cell * 0.25)
	return d


## gv_<plot> for every plot and old grave: [x, z, facing°] (first free candidate; layout overrides win).
static func _visitor_spots(ctx: Ctx, grid: PackedByteArray, origin: Vector2, cell: float, size: Vector2i) -> Dictionary:
	var cfg: Dictionary = ctx.layout.phase8.visitor_spot
	var radius := float(cfg.radius)
	var out := {}
	for g: Dictionary in ctx.layout.plots + ctx.layout.old_graves:
		var at := Ctx.v2(g.pos)
		var rot := deg_to_rad(float(g.rot_y))
		var local: Vector2 = Vector2.ZERO
		var found := false
		var overrides: Dictionary = cfg.get("overrides", {})
		var cands: Array = [overrides[g.id]] if overrides.has(g.id) else cfg.candidates
		for c: Array in cands:
			local = Ctx.v2(c)
			if Nav.clearance_in(grid, origin, cell, size, at + local.rotated(-rot)) >= radius or overrides.has(g.id):
				found = true
				break
		if not found:
			push_error("[nav] no free visitor spot at %s" % g.id)
		var p := at + local.rotated(-rot)
		var stone := at + Vector2(0.0, -1.02).rotated(-rot)
		var facing := rad_to_deg(atan2(stone.x - p.x, stone.y - p.y))
		out["gv_" + String(g.id)] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(facing, 0.1)]
	return out


## Dijkstra over the free cells (clearance ≥ need) from `from`; cost grows near collisions. Returns the
## predecessor of every cell (-1 = start; -2 = not reached).
@warning_ignore("integer_division")
static func _dijkstra(grid: PackedByteArray, origin: Vector2, cell: float, size: Vector2i, from: Vector2, need: float,
		near_cost: float, near_range: float) -> PackedInt32Array:
	var w := size.x
	var total := w * size.y
	var prev := PackedInt32Array()
	prev.resize(total)
	prev.fill(-2)
	var cost := PackedFloat64Array()
	cost.resize(total)
	cost.fill(1.0e9)
	var s := floori((from.y - origin.y) / cell) * w + floori((from.x - origin.x) / cell)
	cost[s] = 0.0
	prev[s] = -1
	# A binary min-heap in two local arrays (inline: element writes on members / parameters copy the array).
	var hc := PackedFloat64Array([0.0])
	var hi := PackedInt32Array([s])
	var count := 1
	var offs := [[1, 0, 1.0], [-1, 0, 1.0], [0, 1, 1.0], [0, -1, 1.0], [1, 1, SQRT2], [1, -1, SQRT2], [-1, 1, SQRT2], [-1, -1, SQRT2]]
	var need_u := need / Nav.UNIT
	while count > 0:
		var c := hc[0]
		var i := hi[0]
		count -= 1
		hc[0] = hc[count]
		hi[0] = hi[count]
		var k := 0
		while true:
			var l := k * 2 + 1
			var m := k
			if l < count and hc[l] < hc[m]:
				m = l
			if l + 1 < count and hc[l + 1] < hc[m]:
				m = l + 1
			if m == k:
				break
			var tc := hc[m]
			hc[m] = hc[k]
			hc[k] = tc
			var ti := hi[m]
			hi[m] = hi[k]
			hi[k] = ti
			k = m
		if c > cost[i]:
			continue
		var x := i % w
		var z := i / w
		for o: Array in offs:
			var xx: int = x + int(o[0])
			var zz: int = z + int(o[1])
			if xx < 0 or zz < 0 or xx >= w or zz >= size.y:
				continue
			var j := zz * w + xx
			if float(grid[j]) < need_u:
				continue
			var clear := float(grid[j]) * Nav.UNIT
			var step: float = float(o[2]) * cell * (1.0 + near_cost * maxf(0.0, (near_range - clear) / near_range))
			var nc := c + step
			if nc < cost[j]:
				cost[j] = nc
				prev[j] = i
				if count == hc.size():
					hc.append(nc)
					hi.append(j)
				else:
					hc[count] = nc
					hi[count] = j
				var q := count
				count += 1
				while q > 0:
					var p := (q - 1) / 2
					if hc[p] <= hc[q]:
						break
					var tc2 := hc[p]
					hc[p] = hc[q]
					hc[q] = tc2
					var ti2 := hi[p]
					hi[p] = hi[q]
					hi[q] = ti2
					q = p
	return prev


## A binary min-heap of (cost, cell) – a class, so the packed arrays are changed in place.
## Cells from the start to the reached cell nearest to `to` (within 1 m), start excluded.
static func _cell_path(prev: PackedInt32Array, size: Vector2i, origin: Vector2, cell: float, to: Vector2, grid: PackedByteArray,
		need: float) -> PackedInt32Array:
	var w := size.x
	var cx := floori((to.x - origin.x) / cell)
	var cz := floori((to.y - origin.y) / cell)
	var best := -1
	var best_d := 1.0e9
	var reach := ceili(1.0 / cell)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= w or z >= size.y:
				continue
			var i := z * w + x
			if prev[i] == -2:
				continue
			var p := origin + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell
			var dd := p.distance_to(to)
			if dd < best_d:
				best_d = dd
				best = i
	var out := PackedInt32Array()
	if best < 0:
		return out
	var k := best
	while k >= 0 and prev[k] != -1:
		out.append(k)
		k = prev[k]
	out.reverse()
	return out


## Line-of-sight smoothing (string pulling): from each corner the farthest point still visible (clearance need; the
## last leg only needs the target's own clearance).
static func _smooth(pts: Array[Vector2], grid: PackedByteArray, origin: Vector2, cell: float, size: Vector2i, need: float) -> Array[Vector2]:
	var out: Array[Vector2] = [pts[0]]
	var i := 0
	var last := pts.size() - 1
	var end_need := minf(need, Nav.clearance_in(grid, origin, cell, size, pts[last]) - 0.01)
	while i < last:
		# The whole rest visible at once (the common case near the end), else scan forward to the first block.
		var j := i + 1
		if Nav.leg_free(grid, origin, cell, size, pts[i], pts[last], need, end_need):
			j = last
		else:
			while j + 1 < last and Nav.leg_free(grid, origin, cell, size, pts[i], pts[j + 1], need, need):
				j += 1
		out.append(pts[j])
		i = j
	return out


## Replaces (or appends) the three baked keys at the end of graveyard_layout.json – one entry per line.
static func _write_layout(spots: Dictionary, vw: Dictionary, vw_order: Array[String], routes: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(LAYOUT_PATH)
	var marker := ',\n  "_baked_phase8":'
	var at := text.find(marker)
	if at >= 0:
		text = text.substr(0, at) + "\n}\n"
	text = text.strip_edges()
	assert(text.ends_with("}"), "layout end")
	text = text.substr(0, text.length() - 1).strip_edges(false, true)
	var lines := PackedStringArray()
	lines.append('  "_baked_phase8": "Phase 8 §4.2 (graveyard_build_phase8.gd, beim Welt-Bau geschrieben – nicht von Hand ändern): visitor_spots gv_<plot> [x, z, Blick°], visitor_waypoints vw_* [x, z], visitor_routes je Grab bzw. Lichtgang-/Ecken-Platz (road_end → … → Ziel)."')
	var sp := PackedStringArray()
	for id: String in spots:
		sp.append('    "%s": [%s, %s, %s]' % [id, _n(spots[id][0]), _n(spots[id][1]), _n(spots[id][2])])
	lines.append('  "visitor_spots": {\n' + ",\n".join(sp) + "\n  }")
	var vp := PackedStringArray()
	for id: String in vw_order:
		vp.append('    "%s": [%s, %s]' % [id, _n(vw[id].x), _n(vw[id].y)])
	lines.append('  "visitor_waypoints": {\n' + ",\n".join(vp) + "\n  }")
	var rp := PackedStringArray()
	var keys := routes.keys()
	for id: Variant in keys:
		var parts := PackedStringArray()
		for w: String in routes[id]:
			parts.append('"%s"' % w)
		rp.append('    "%s": [%s]' % [id, ", ".join(parts)])
	lines.append('  "visitor_routes": {\n' + ",\n".join(rp) + "\n  }")
	text += ",\n" + ",\n".join(lines) + "\n}\n"
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("  wrote baked spots / routes into ", LAYOUT_PATH)


static func _n(v: float) -> String:
	var s := "%.2f" % v
	if s.contains("."):
		s = s.rstrip("0")
		if s.ends_with("."):
			s += "0"
	return s
