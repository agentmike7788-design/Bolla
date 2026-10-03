extends RefCounted
## Grass helpers of graveyard_builder.gd (build-time tool, static, preloaded): scatters the
## tufts (seeded, noise-clumped) into chunked MultiMeshes so the camera culls what it does not
## see, keeps paths, roads, NPC routes and placed objects free, thins out ground the camera
## cannot see, and saves the result as grass.scn. Phase 5 (docs/PHASE5_DESIGN.md §4.5): half density
## Am Bruch, none in the quarry, keep-outs around the workyard stations, the kiln and every gather
## node (flax beds, clay pit, herbs, quarry spots, alder trunks). Phase 6 (docs/PHASE6_DESIGN.md §4.1 G3,
## §4.2): none under the building footprints and on their forecourts, × 0.6 in the churchyard.

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const OUT_GRASS := "res://src/world/graveyard/grass.scn"
const GRASS_ASSET := "ph_env_grass_tuft"
## Phase 5: keep-out radius (m, before grass.gather_keep_out) per gather kind ≈ half the model.
const GATHER_RADIUS := {"alder": 0.45, "flax_bed": 0.9, "clay_pit": 1.25, "herb_patch": 0.55, "ore_vein": 0.75,
		"workstone_ledge": 0.85, "rubble_face": 0.95}


# --- grass (chunked MultiMeshes so the camera culls what it does not see) -----

static func build(ctx: Ctx) -> Node3D:
	var layout := ctx.layout
	var cfg: Dictionary = layout.grass
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var clump := FastNoiseLite.new()
	clump.seed = int(cfg.seed)
	clump.frequency = 0.18
	var lo := Vector2(ctx.grid_min) * ctx.cell + Vector2(0.5, 0.5)
	var hi := Vector2(ctx.grid_max) * ctx.cell - Vector2(0.5, 0.5)
	var area := (hi.x - lo.x) * (hi.y - lo.y)
	var target := int(float(cfg.density) * area)
	var keep := _keep_out(ctx)
	var wb: Dictionary = layout.walkable_bounds
	var inner := Rect2(Ctx.v2(wb.min), Ctx.v2(wb.max) - Ctx.v2(wb.min)).grow(float(cfg.outer_margin))
	var chunk := float(cfg.chunk)
	var chunks: Dictionary = {}   # Vector2i -> Array[Transform3D]
	var placed := 0
	var tries := 0
	while placed < target and tries < target * 20:
		tries += 1
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if clump.get_noise_2d(p.x * 10.0, p.y * 10.0) * 0.5 + 0.5 < rng.randf() * 0.85:
			continue
		if not inner.has_point(p) and rng.randf() > float(cfg.outer_density):
			continue
		if _kept_out(p, keep):
			continue
		if (keep.no_grass as Array).any(func(r: Rect2) -> bool: return r.has_point(p)):
			continue
		if (keep.thin as Array).any(func(r: Rect2) -> bool: return r.has_point(p)) and rng.randf() > float(cfg.get("bruch_density_scale", 1.0)):
			continue
		if (keep.thin_churchyard as Array).any(func(r: Rect2) -> bool: return r.has_point(p)) and \
				rng.randf() > float(cfg.get("churchyard_density_scale", 1.0)):
			continue
		if _hidden(p, keep) and rng.randf() > float(cfg.hidden_density):
			continue
		var s := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		var key := Vector2i(floori(p.x / chunk), floori(p.y / chunk))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(Transform3D(basis, Vector3(p.x, ctx.ground_height(p) - 0.01, p.y)))
		placed += 1
	var tuft := (load(Ctx.model_path(GRASS_ASSET)) as PackedScene).instantiate()
	var mesh := ((tuft.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh).duplicate() as Mesh
	tuft.free()
	var root := Node3D.new()
	root.name = "Grass"
	var keys := chunks.keys()
	keys.sort()
	for key: Vector2i in keys:
		var xforms: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunk_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(cfg.visibility_range)
		root.add_child(mmi)
		mmi.owner = root
	print("  grass tufts: %d in %d chunks" % [placed, keys.size()])
	return root


static func save(root: Node3D) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed: grass")
	err = ResourceSaver.save(ps, OUT_GRASS)
	assert(err == OK, "save failed: grass")
	print("  saved ", OUT_GRASS)
	root.free()


## Keep-out shapes: polylines {pts, r}, circles {c, r}, rotated rects {pos, rot, rect}.
static func _keep_out(ctx: Ctx) -> Dictionary:
	var layout := ctx.layout
	var cfg: Dictionary = layout.grass
	var lines: Array[Dictionary] = []
	lines.append({"pts": _points(layout.path.points), "r": float(cfg.keep_out_radius_path)})
	lines.append({"pts": _points(layout.road.points), "r": float(cfg.keep_out_radius_road)})
	for route: Array[Vector2] in _npc_routes(ctx):
		lines.append({"pts": route, "r": float(cfg.keep_out_route)})
	var circles: Array[Dictionary] = []
	circles.append({"c": Ctx.v2(layout.tree.pos), "r": 0.9})
	for t: Dictionary in layout.background_trees + layout.forest.trees:
		circles.append({"c": Ctx.v2(t.pos), "r": 1.0 * float(t.scale)})
	for b: Dictionary in layout.forest.bushes:
		circles.append({"c": Ctx.v2(b.pos), "r": 0.5 * float(b.scale)})
	for b: Dictionary in layout.get("birches", []):
		circles.append({"c": Ctx.v2(b.pos), "r": 0.35 * float(b.scale)})
	if layout.has("notice_board"):
		circles.append({"c": Ctx.v2(layout.notice_board.pos), "r": 0.5})
	for pa: Dictionary in layout.fence.get("passages", []):
		var dir := Vector2(1, 0).rotated(-deg_to_rad(float(pa.rot_y)))
		circles.append({"c": Ctx.v2(pa.pos) + dir * 0.17, "r": 0.35})
		circles.append({"c": Ctx.v2(pa.pos) + dir * (float(pa.width) - 0.17), "r": 0.35})
	circles.append({"c": Ctx.v2(layout.hut.pos), "r": float(cfg.keep_out_building)})
	for lp: Dictionary in layout.lantern_posts:
		circles.append({"c": Ctx.v2(lp.pos), "r": 0.35})
	for gp: Array in layout.fence.gate_posts:
		circles.append({"c": Ctx.v2(gp), "r": 0.35})
	circles.append({"c": Ctx.v2(layout.signpost.pos), "r": 0.35})
	for pr: Dictionary in layout.props:
		circles.append({"c": Ctx.v2(pr.pos), "r": 0.5})
	var rects: Array[Dictionary] = []
	var plot_rect: Array = layout.ground.plot_flat_rect
	for pl: Dictionary in layout.plots:
		rects.append({"pos": Ctx.v2(pl.pos), "rot": float(pl.rot_y),
				"rect": Rect2(plot_rect[0], plot_rect[1], plot_rect[2] - plot_rect[0], plot_rect[3] - plot_rect[1])})
	for g: Dictionary in layout.old_graves:
		# W3 art QA (G6): the old grave's mound and – once lifted and dug – the foot-end pit with its
		# spoil heap (GravePlot.foot_footprint −0.72…0.72 × −1.25…2.13): grass grew into the open pit.
		rects.append({"pos": Ctx.v2(g.pos), "rot": float(g.rot_y), "rect": Rect2(-0.72, -1.35, 1.44, 3.48)})
	var margin := float(cfg.keep_out_station)
	for ent: Dictionary in layout.entities:
		var asset: String = Ctx.ENTITY_ASSETS.get(ent.type, (ent.params as Dictionary).get("model", ""))
		var defs: Array = layout.colliders.get(asset, [])
		if ent.type == "hut_door":
			rects.append({"pos": Ctx.v2(ent.pos), "rot": float(ent.rot_y), "rect": Rect2(-0.9, -1.0, 1.8, 1.8)})
		elif not defs.is_empty():
			var size := Ctx.v3(defs[0].size)
			var off := Ctx.v3(defs[0].offset)
			rects.append({"pos": Ctx.v2(ent.pos), "rot": float(ent.rot_y),
					"rect": Rect2(off.x - size.x * 0.5, off.z - size.z * 0.5, size.x, size.z).grow(margin)})
	# Phase 5: workyard footprints, the kiln, the gather nodes (model half size + gather_keep_out).
	for site: Dictionary in layout.get("workyard", {}).get("build_sites", []):
		var fp: Array = site.footprint
		rects.append({"pos": Ctx.v2(site.pos), "rot": float(site.rot_y), "rect": Rect2(fp[0], fp[1], fp[2], fp[3]).grow(margin)})
	if layout.get("workyard", {}).has("meiler"):
		circles.append({"c": Ctx.v2(layout.workyard.meiler.pos), "r": float(layout.workyard.meiler.radius) + margin})
	var gather_out := float(cfg.get("gather_keep_out", 0.0))
	for g: Dictionary in layout.get("gather_nodes", []):
		circles.append({"c": Ctx.v2(g.pos), "r": float(GATHER_RADIUS.get(String(g.kind), 0.6)) + gather_out})
	var no_grass: Array[Rect2] = []
	var thin: Array[Rect2] = []
	var thin_churchyard: Array[Rect2] = []
	for sec: Dictionary in layout.sections:
		var r: Array = sec.rect
		var rect := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		if sec.id == "quarry":
			no_grass.append(rect)
		elif sec.id == "bruch":
			thin.append(rect)
		elif sec.id == "churchyard":
			thin_churchyard.append(rect)
	# Phase 6 (§4.1 G3, §4.2): no grass under the building footprints (+ keep_out_station) and on
	# the forecourt in front of each door (access + building_access_keep_out); the soul lantern.
	var access_out := float(cfg.get("building_access_keep_out", 0.0))
	for site: Dictionary in layout.get("buildings", {}).get("sites", []):
		var fp: Array = site.footprint
		rects.append({"pos": Ctx.v2(site.pos), "rot": float(site.rot_y), "rect": Rect2(fp[0], fp[1], fp[2], fp[3]).grow(margin)})
		circles.append({"c": Ctx.v2(site.access), "r": access_out})
	var soul: Dictionary = layout.get("buildings", {}).get("soul_lantern", {})
	if not soul.is_empty():
		circles.append({"c": Ctx.v2(soul.pos), "r": 0.5})
	var log_def: Dictionary = layout.colliders["ph_prop_fallen_log"][0]
	var log_size := Ctx.v3(log_def.size)
	var log_off := Ctx.v3(log_def.offset)
	rects.append({"pos": Ctx.v2(layout.fallen_log.pos), "rot": float(layout.fallen_log.rot_y),
			"rect": Rect2(log_off.x - log_size.x * 0.5, log_off.z - log_size.z * 0.5, log_size.x, log_size.z).grow(margin)})
	# Ground the camera cannot see: behind tree crowns (north of the trunk) and the hut roof.
	var hidden: Array[Dictionary] = []
	for t: Dictionary in [layout.tree] + layout.background_trees + layout.forest.trees:
		var s := float(t.get("scale", 1.0))
		hidden.append({"c": Ctx.v2(t.pos) + Vector2(0.0, -float(cfg.hidden_crown_offset) * s),
				"r": float(cfg.hidden_crown_radius) * s})
	var hut := Ctx.v2(layout.hut.pos)
	var hut_rect := Rect2(-2.9, -2.4 - float(cfg.hidden_hut_depth), 5.8, float(cfg.hidden_hut_depth))
	return {"lines": lines, "circles": circles, "rects": rects, "hidden": hidden, "no_grass": no_grass, "thin": thin,
			"thin_churchyard": thin_churchyard,
			"hidden_rects": [{"pos": hut, "rot": float(layout.hut.rot_y), "rect": hut_rect}]}


static func _hidden(p: Vector2, keep: Dictionary) -> bool:
	for c: Dictionary in keep.hidden:
		if p.distance_to(c.c) < float(c.r):
			return true
	for r: Dictionary in keep.hidden_rects:
		var local := (p - (r.pos as Vector2)).rotated(deg_to_rad(float(r.rot)))
		if (r.rect as Rect2).has_point(local):
			return true
	return false


static func _kept_out(p: Vector2, keep: Dictionary) -> bool:
	for line: Dictionary in keep.lines:
		if _dist_to_polyline(p, line.pts) < float(line.r):
			return true
	for c: Dictionary in keep.circles:
		if p.distance_to(c.c) < float(c.r):
			return true
	for r: Dictionary in keep.rects:
		var local := (p - (r.pos as Vector2)).rotated(deg_to_rad(float(r.rot)))
		if (r.rect as Rect2).has_point(local):
			return true
	return false


## Waypoint polylines of every NPC schedule entry (the carter's cart track stays free of grass).
static func _npc_routes(ctx: Ctx) -> Array:
	var layout := ctx.layout
	var routes: Array = []
	for ent: Dictionary in layout.entities:
		if ent.type != "npc":
			continue
		# Autoload names are not globals while this -s script compiles: look the node up.
		var sched: Resource = ctx.tree.root.get_node(^"Database").call(&"schedule", StringName(ent.params.npc_id))
		if sched == null:
			continue
		for e: Resource in sched.get("entries"):
			var path: PackedStringArray = e.get("path")
			if path.size() < 2:
				continue
			var pts: Array[Vector2] = []
			for id: String in path:
				pts.append(Ctx.v2(layout.waypoints[id]))
			routes.append(pts)
	return routes


static func _points(raw: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Array in raw:
		out.append(Ctx.v2(p))
	return out


static func _dist_to_polyline(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for k: int in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])))
	return best
