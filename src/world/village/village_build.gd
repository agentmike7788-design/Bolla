extends RefCounted
## Builds the outdoor region Hollerbrück (docs/PHASE7_DESIGN.md §3.1, §4.1–§4.5, §4.7) from
## data/world/village_layout.json – build-time tool, static, preloaded by village_builder.gd and
## graveyard_build_phase7.gd (no class_name; scripts that use autoloads are loaded by path, see
## graveyard_builder.gd). It reuses the graveyard build context (graveyard_build_context.gd: ground
## height lookup from the painted ground mesh, place(), marker lights) with the village layout and
## the village ground, and graveyard_build_colliders.gd. Region-local coordinates; the world builder
## instances the scene under WorldRoot/Regions/Village at (0, 0, 400).
##   Village (RegionRoot region village, hide_when_inactive)
##   ├─ Ground (ph_env_ground_village)   ├─ GroundCollision/Shape (HeightMapShape3D)
##   ├─ Buildings/<id> (models + window / lantern / ember lights)   ├─ Decor/ (props, trees, bushes,
##   │   garden fences, brook, Grass)   ├─ Entities/ (9 Npc, HouseDoor × 3, ShopCounter × 2,
##   │   VillageBoard, RegionPortal road_out, MourningRibbon × 6)   ├─ Waypoints/   ├─ Spawns/
##   ├─ Colliders/ (footprints, props, bank walls, Bounds)   └─ Dressing (village_dressing.gd)

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const Entities := preload("res://src/world/graveyard/graveyard_build_entities.gd")
const Decor := preload("res://src/world/graveyard/graveyard_build_decor.gd")
const LAYOUT_PATH := "res://data/world/village_layout.json"
const OUT_SCENE := "res://src/world/village/village.tscn"
const OUT_GRASS := "res://src/world/village/village_grass.scn"
const OUT_GROUND_SHAPE := "res://src/world/village/ground_shape.res"
const REGION_SCRIPT := "res://src/world/regions/region_root.gd"
const REGION_CONFIG := "res://data/config/regions/village.tres"
const DRESSING_SCRIPT := "res://src/world/village/village_dressing.gd"
const PORTAL_SCENE := "res://src/entities/region_portal/region_portal.tscn"
const DOOR_SCENE := "res://src/entities/house_door/house_door.tscn"
const COUNTER_SCENE := "res://src/entities/shop_counter/shop_counter.tscn"
const BOARD_SCENE := "res://src/entities/village_board/village_board.tscn"
const RIBBON_SCENE := "res://src/entities/mourning_ribbon/mourning_ribbon.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const RIBBON_ASSET := "ph_prop_v_ribbon"
const GRASS_ASSET := "ph_env_grass_tuft"
const FENCE_ASSET := "ph_env_garden_fence"
const FENCE_PIECE := 2.04
## Collision height of the house footprints (the camera rays use the meshes, not these).
const HOUSE_COLLIDER_HEIGHT := 3.0
## Sign label (like the graveyard signpost, §8).
const SIGN_LABEL := {"font_size": 64, "pixel_size": 0.0021, "color": "#2a1f18", "surface_offset": 0.012}
## A window light sits this far outside its pane (m) unless the layout says "out".
const WINDOW_OUT := 0.5
## Npc ids of the village (schedule data/npc/<npc_id>_schedule.tres).
const META_UNTIL := &"until"
const META_ON := &"energy_on"


static func load_layout() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))


## A fresh build context for the village (layout parsed, ground heights read from the village ground).
static func make_context(tree: SceneTree) -> Ctx:
	var ctx := Ctx.new(tree)
	ctx.layout = load_layout()
	ctx.ground_asset = String(ctx.layout.ground.asset)
	ctx.cell = float(ctx.layout.ground.cell)
	ctx.build_height_lookup()
	return ctx


## Builds the grass (needs a real renderer: MultiMesh data) and the scene; saves both.
static func build_and_save(tree: SceneTree) -> String:
	var ctx := make_context(tree)
	save_grass(build_grass(ctx))
	var root := build(ctx)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed: village")
	err = ResourceSaver.save(ps, OUT_SCENE)
	assert(err == OK, "save failed: " + OUT_SCENE)
	print("  saved ", OUT_SCENE, " (colliders ", ctx.collider_count, ")")
	root.free()
	return OUT_SCENE


static func build(ctx: Ctx) -> Node3D:
	var layout := ctx.layout
	var root := Node3D.new()
	root.name = "Village"
	root.set_script(load(REGION_SCRIPT))
	root.set("region_id", &"village")
	root.set("config", load(REGION_CONFIG))
	root.set("hide_when_inactive", true)
	ctx.scene_root = root
	var ground := ctx.place(ctx.ground_asset, root, Vector2.ZERO, 0.0, "Ground")
	ground.transform = Transform3D.IDENTITY
	Colliders.build_ground_collision(ctx, OUT_GROUND_SHAPE)
	ctx.colliders = ctx.group(root, "Colliders")
	var buildings := ctx.group(root, "Buildings")
	var decor := ctx.group(root, "Decor")
	var entities := ctx.group(root, "Entities")
	for b: Dictionary in layout.buildings:
		_build_house(ctx, buildings, b)
	_build_props(ctx, decor)
	_build_decor(ctx, decor)
	_build_entities(ctx, entities, buildings)
	Entities.build_waypoints(ctx, ctx.group(root, "Waypoints"))
	var spawns := ctx.group(root, "Spawns")
	for id: String in layout.spawns:
		var s: Dictionary = layout.spawns[id]
		var marker := Marker3D.new()
		marker.name = id
		marker.transform = ctx.ground_xform(Ctx.v2(s.pos), float(s.get("rot_y", 0.0)))
		ctx.add(spawns, marker)
	_build_bank_walls(ctx)
	Colliders.build_bounds(ctx)
	if ResourceLoader.exists(OUT_GRASS):
		var grass := (load(OUT_GRASS) as PackedScene).instantiate()
		grass.name = "Grass"
		ctx.add(decor, grass)
	var dressing := Node.new()
	dressing.name = "Dressing"
	dressing.set_script(load(DRESSING_SCRIPT))
	ctx.add(root, dressing)
	return root


# --- houses (§4.2) ---------------------------------------------------------------------------

## Buildings/<id>: the model at its §4.2 centre with its lights, a collision box over the footprint
## (or the layout's own rects for the open smithy / remise).
static func _build_house(ctx: Ctx, parent: Node3D, b: Dictionary) -> void:
	var asset := String(b.model)
	var node := ctx.place(asset, parent, Ctx.v2(b.pos), float(b.get("rot_y", 0.0)), String(b.id))
	_window_lights(ctx, asset, node)
	var rects: Array = b.get("collision", [ctx.layout.footprints[asset]])
	var body := StaticBody3D.new()
	body.name = String(b.id)
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	body.transform = node.transform
	ctx.add(ctx.colliders, body)
	ctx.collider_count += 1
	var k := 0
	for r: Array in rects:
		k += 1
		var shape := CollisionShape3D.new()
		shape.name = "Shape%d" % k
		var box := BoxShape3D.new()
		box.size = Vector3(float(r[2]) - float(r[0]), HOUSE_COLLIDER_HEIGHT, float(r[3]) - float(r[1]))
		shape.shape = box
		shape.position = Vector3((float(r[0]) + float(r[2])) * 0.5, HOUSE_COLLIDER_HEIGHT * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		ctx.add(body, shape)


## The window lights sit outside the glass (no light leaks into the closed room); lights with "until"
## carry the metas the dressing switches by the clock (§4.7).
static func _window_lights(ctx: Ctx, asset: String, model: Node3D) -> void:
	var cfgs: Dictionary = ctx.layout.lights
	for light: Node in model.find_children("Light_*", "OmniLight3D", false, false):
		var marker := "light_" + String(light.name).trim_prefix("Light_")
		var cfg: Dictionary = cfgs.get(asset + "/" + marker, {})
		if cfg.is_empty():
			continue
		var l := light as OmniLight3D
		if marker.begins_with("light_window"):
			var fp: Array = ctx.layout.footprints[asset]
			var p := l.position
			var hx := (float(fp[2]) - float(fp[0])) * 0.5
			var hz := (float(fp[3]) - float(fp[1])) * 0.5
			var out := float(cfg.get("out", WINDOW_OUT))
			if absf(p.x) / hx > absf(p.z) / hz:
				l.position.x += signf(p.x) * out
			else:
				l.position.z += signf(p.z) * out
		if cfg.has("until"):
			l.set_meta(META_UNTIL, int(cfg.until))
			l.set_meta(META_ON, float(cfg.energy))


# --- props, decor (§4.2) ---------------------------------------------------------------------

static func _build_props(ctx: Ctx, decor: Node3D) -> void:
	var props := ctx.group(decor, "Props")
	for pr: Dictionary in ctx.layout.props:
		var node := ctx.place(String(pr.asset), props, Ctx.v2(pr.pos), float(pr.get("rot_y", 0.0)), String(pr.id))
		if pr.has("label"):
			Decor.add_sign_label(ctx, node, SIGN_LABEL.merged({"text": String(pr.label)}))
		if pr.has("collider"):
			_collider(ctx, node.transform, pr.collider if pr.collider is Array else [pr.collider], String(pr.id), 1.0)


static func _build_decor(ctx: Ctx, decor: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.decor
	var trees := ctx.group(decor, "Trees")
	var k := 0
	for t: Dictionary in cfg.trees:
		k += 1
		var node := ctx.place(String(t.asset), trees, Ctx.v2(t.pos), float(t.rot_y), "Tree_%02d" % k)
		node.scale = Vector3.ONE * float(t.scale)
		_collider(ctx, ctx.ground_xform(Ctx.v2(t.pos), 0.0),
				[{"shape": "cylinder", "radius": 0.5, "height": 3.0, "offset": [0.0, 1.5, 0.0]}], "Tree_%02d" % k, float(t.scale))
	var bushes := ctx.group(decor, "Bushes")
	k = 0
	for b: Dictionary in cfg.bushes:
		k += 1
		var node := ctx.place(String(b.asset), bushes, Ctx.v2(b.pos), float(b.rot_y), "Bush_%02d" % k)
		node.scale = Vector3.ONE * float(b.scale)
	var fences := ctx.group(decor, "GardenFences")
	k = 0
	for seg: Array in cfg.garden_fences:
		var a := Ctx.v2(seg[0])
		var b2 := Ctx.v2(seg[1])
		var d := b2 - a
		var count := ceili(d.length() / FENCE_PIECE - 0.001)
		var rot := rad_to_deg(atan2(-d.y, d.x))
		for i: int in count:
			k += 1
			var remaining := d.length() - FENCE_PIECE * i
			var stretch := minf(remaining / FENCE_PIECE, 1.0)
			var mid := a + d.normalized() * (FENCE_PIECE * i + FENCE_PIECE * stretch * 0.5)
			var piece := ctx.place(FENCE_ASSET, fences, mid, rot, "fence_%02d" % k)
			if stretch < 1.0:
				piece.scale.x = stretch
			_collider(ctx, ctx.ground_xform(mid, rot),
					[{"shape": "box", "size": [FENCE_PIECE * stretch, 1.0, 0.2], "offset": [0.0, 0.5, 0.0]}], "Fence_%02d" % k, 1.0)
	var brook: Dictionary = ctx.layout.brook
	var water := ctx.place(String(brook.asset), decor, Ctx.v2(brook.pos), float(brook.rot_y), "Brook")
	water.position.y = 0.0


## A StaticBody3D with layout-style shape defs at `xform` (layer 1).
static func _collider(ctx: Ctx, xform: Transform3D, defs: Array, body_name: String, scale: float) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	body.transform = xform
	ctx.add(ctx.colliders, body)
	Colliders.add_shapes(ctx, body, defs, Transform3D.IDENTITY, scale, 1.0, "")
	ctx.collider_count += 1


## Invisible walls along the Hollerbach (thinner than the bounds; §4.2 „unsichtbare Wand am Ufer
## außer an Brücke und Waschplatz") and the bridge rails.
static func _build_bank_walls(ctx: Ctx) -> void:
	var cfg: Dictionary = ctx.layout.bank_walls
	var h := float(ctx.layout.walkable_bounds.wall_height)
	var t := float(cfg.thickness)
	var body := StaticBody3D.new()
	body.name = "BankWalls"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(ctx.colliders, body)
	var k := 0
	for seg: Array in cfg.lines:
		k += 1
		var a := Ctx.v2(seg[0])
		var b := Ctx.v2(seg[1])
		var d := b - a
		var shape := CollisionShape3D.new()
		shape.name = "Bank_%d" % k
		var box := BoxShape3D.new()
		box.size = Vector3(d.length() + t, h, t)
		shape.shape = box
		var mid := (a + b) * 0.5
		shape.transform = Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(mid.x, h * 0.5, mid.y))
		ctx.add(body, shape)


# --- entities (§3.1, §4.2, §4.4) -------------------------------------------------------------

static func _build_entities(ctx: Ctx, entities: Node3D, buildings: Node3D) -> void:
	for ent: Dictionary in ctx.layout.entities:
		match String(ent.type):
			"RegionPortal":
				var portal := _instance(PORTAL_SCENE, String(ent.id))
				portal.transform = ctx.ground_xform(Ctx.v2(ent.pos), float(ent.get("rot_y", 0.0)))
				portal.set("target_region", StringName(ent.target_region))
				portal.set("target_spawn", StringName(ent.target_spawn))
				portal.set("requires_flag", StringName(ent.get("requires_flag", "")))
				portal.set("prompt", String(ent.prompt))
				ctx.add(entities, portal)
			"HouseDoor":
				var house := buildings.get_node(String(ent.house)) as Node3D
				var marker := house.find_child("door_outside", true, false) as Node3D
				var at := house.transform * Ctx.rel_xform(marker, house).origin
				var away := Vector2(at.x - house.position.x, at.z - house.position.z)
				var door := _instance(DOOR_SCENE, String(ent.id))
				door.transform = Transform3D(Basis(Vector3.UP, atan2(away.x, away.y)), at)
				door.set("door_id", StringName(ent.id))
				door.set("room_id", StringName(ent.room_id))
				door.set("display_name", String(ent.display_name))
				door.set("open_windows", PackedInt32Array(ent.open_windows))
				ctx.add(entities, door)
			"ShopCounter", "VillageBoard":
				var scene := COUNTER_SCENE if ent.type == "ShopCounter" else BOARD_SCENE
				var node := _instance(scene, String(ent.id))
				node.transform = ctx.ground_xform(Ctx.v2(ent.pos), float(ent.get("rot_y", 0.0)))
				if ent.has("shop_id"):
					node.set("shop_id", StringName(ent.shop_id))
				ctx.add(entities, node)
				if ent.has("reach"):
					_reach(ctx, node, Ctx.v3(ent.reach), Ctx.v3(ent.get("reach_offset", [0.0, float(ent.reach[1]) * 0.5, 0.0])))
			"MourningRibbon":
				var house := buildings.get_node(String(ent.house_id)) as Node3D
				var marker := house.find_child("ribbon", true, false) as Node3D
				var ribbon := _instance(RIBBON_SCENE, String(ent.id))
				ribbon.transform = house.transform * Ctx.rel_xform(marker, house)
				ribbon.set("house_id", StringName(ent.house_id))
				ctx.add(entities, ribbon)
				var model := (load(Ctx.model_path(RIBBON_ASSET)) as PackedScene).instantiate() as Node3D
				model.name = "Model"
				ctx.add(ribbon, model)
	for n: Dictionary in ctx.layout.npcs:
		var npc := _instance(NPC_SCENE, String(n.id))
		npc.set("save_id", "")  # the Npc's state is the clock; the village figures are not saved (§5.1)
		npc.set("npc_id", StringName(n.npc_id))
		npc.set("model", load(Ctx.model_path(String(n.model))))
		npc.set("region_id", &"village")
		if n.has("hide_flag"):
			npc.set("hide_flag", StringName(n.hide_flag))
		ctx.add(entities, npc)


## The entity's Interactable box (editable instance child).
static func _reach(ctx: Ctx, node: Node3D, size: Vector3, offset: Vector3) -> void:
	var shape := node.get_node_or_null(^"Interactable/Shape") as CollisionShape3D
	if shape == null:
		return
	ctx.scene_root.set_editable_instance(node, true)
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset


static func _instance(path: String, node_name: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = node_name
	return node


# --- grass (§4.2, §9: × 0.5 of the graveyard) ------------------------------------------------

## Chunked MultiMeshes like the graveyard's grass (graveyard_build_grass.gd), with the village's
## keep-outs: paving, paths, the brook, building footprints, props, trees and the NPC routes.
static func build_grass(ctx: Ctx) -> Node3D:
	var layout := ctx.layout
	var cfg: Dictionary = layout.grass
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var clump := FastNoiseLite.new()
	clump.seed = int(cfg.seed)
	clump.frequency = 0.18
	var lo := Vector2(ctx.grid_min) * ctx.cell + Vector2(0.5, 0.5)
	var hi := Vector2(ctx.grid_max) * ctx.cell - Vector2(0.5, 0.5)
	var target := int(float(cfg.density) * (hi.x - lo.x) * (hi.y - lo.y))
	var wb: Dictionary = layout.walkable_bounds
	var inner := Rect2(Ctx.v2(wb.min), Ctx.v2(wb.max) - Ctx.v2(wb.min)).grow(float(cfg.outer_margin))
	var chunk := float(cfg.chunk)
	var chunks: Dictionary = {}
	var placed := 0
	var tries := 0
	while placed < target and tries < target * 20:
		tries += 1
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if clump.get_noise_2d(p.x * 10.0, p.y * 10.0) * 0.5 + 0.5 < rng.randf() * 0.85:
			continue
		if not inner.has_point(p) and rng.randf() > float(cfg.outer_density):
			continue
		if grass_blocked(layout, p):
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
	print("  village grass tufts: %d in %d chunks" % [placed, keys.size()])
	return root


static func save_grass(root: Node3D) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed: village grass")
	err = ResourceSaver.save(ps, OUT_GRASS)
	assert(err == OK, "save failed: " + OUT_GRASS)
	print("  saved ", OUT_GRASS)
	root.free()


## No grass on the paving, the paths, in the brook, under footprints (+ margin), at props and trunks.
static func grass_blocked(layout: Dictionary, p: Vector2) -> bool:
	var cfg: Dictionary = layout.grass
	for r: Array in layout.paving.rects:
		if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(0.3).has_point(p):
			return true
	for c: Array in layout.paving.get("circles", []):
		if p.distance_to(Vector2(c[0], c[1])) < float(c[2]) + 0.3:
			return true
	for line: Dictionary in layout.paving.get("lines", []):
		var pts: Array = line.pts
		for k: int in pts.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, Ctx.v2(pts[k]), Ctx.v2(pts[k + 1]))) < float(line.width) * 0.5 + 0.3:
				return true
	var path_r := float(layout.paths.width) * 0.5 + float(cfg.keep_out_path)
	for line: Array in layout.paths.lines:
		for k: int in line.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, Ctx.v2(line[k]), Ctx.v2(line[k + 1]))) < path_r:
				return true
	if absf(p.x - float(layout.brook.pos[0])) < float(layout.brook.half_width) + 0.3:
		return true
	var margin := float(cfg.keep_out_building)
	for b: Dictionary in layout.buildings:
		var fp: Array = layout.footprints[b.model]
		var local := (p - Ctx.v2(b.pos)).rotated(deg_to_rad(float(b.get("rot_y", 0.0))))
		if Rect2(fp[0], fp[1], fp[2] - fp[0], fp[3] - fp[1]).grow(margin).has_point(local):
			return true
	for pr: Dictionary in layout.props:
		if p.distance_to(Ctx.v2(pr.pos)) < float(cfg.keep_out_prop) + (1.0 if String(pr.id) in ["well", "bridge", "wash_stones", "cart_rest"] else 0.4):
			return true
	for t: Dictionary in layout.decor.trees:
		if p.distance_to(Ctx.v2(t.pos)) < 0.9 * float(t.scale):
			return true
	return false
