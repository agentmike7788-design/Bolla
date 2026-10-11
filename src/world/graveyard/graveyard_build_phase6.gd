extends RefCounted
## Phase-6 helpers of graveyard_builder.gd (build-time tool, static, preloaded –
## docs/PHASE6_DESIGN.md §3.1, §4): the new system nodes (Buildings with the site rects, Ossuary,
## Chapel = ChapelRites), the three building sites (BuildingSite – the level models are swapped at
## runtime from data/buildings, the footprint collides) with their outdoor dressing
## (building_exterior.gd: marker lights, bell, soul lantern), the doors (BuildingDoor at the model
## marker door_outside), the interiors (InteriorRoom scenes from interior_build.gd, far from the
## world under Interiors/) and the retirement of the old table in front of the hut (§4.4: the
## table retires at crypt level 1, the wash basin, the smoke bowl and their colliders follow it).
## The Kirchpforte is a layout clearable (graveyard_build_phase3.gd builds it, Phase5.build_bruch
## stretches it like the Ostpforte). Scripts are loaded by path (see graveyard_builder.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const InteriorBuild := preload("res://src/world/interiors/interior_build.gd")
const SITE_SCENE := "res://src/entities/building_site/building_site.tscn"
const DOOR_SCENE := "res://src/entities/building_door/building_door.tscn"
const EXTERIOR_SCRIPT := "res://src/world/graveyard/building_exterior.gd"
## G7 round 1: the crypt stair (walk-through portal, the sod cover over the pit until level 1).
const STAIR_PORTAL_SCRIPT := "res://src/world/interiors/stair_portal.gd"
const SITE_COVER_SCRIPT := "res://src/entities/building_site/site_cover.gd"
const PAVING_ASSET := "ph_env_crypt_paving"
## §3.1: node name → script (groups / save_id / save_order are set by the scripts themselves:
## buildings 32, ossuary 36, chapel 37).
const SYSTEMS := [
	["Buildings", "res://src/systems/buildings/buildings.gd"],
	["Ossuary", "res://src/systems/ossuary/ossuary.gd"],
	["Chapel", "res://src/systems/chapel/chapel_rites.gd"],
]
## Interiors/<Name> per building room (§3.1).
const ROOM_NODES := {"crypt": "CryptInterior", "chapel": "ChapelInterior", "shed": "ShedInterior"}
## Light rule of each marker (building_exterior.gd): chapel windows only during a rite / at night
## from level 3, the soul lantern at night.
const LIGHT_RULES := {"light_window_1": "rite_or_night3", "light_window_3": "rite_or_night3", "light_soul": "night"}
## Layout light key per building: every level model uses the markers of this asset's table rows.
const LIGHT_ASSETS := {"crypt": "ph_bld_crypt_l3", "chapel": "ph_bld_chapel_l1", "shed": ""}
const OLD_TABLE := "morgue_table"
const FOLLOW_META := &"follows_table"
const OLD_TABLE_PROPS: Array[String] = ["Decor/Phase4Props/WashBasin", "Entities/morgue_table/SmokeBowl",
		"Colliders/WashBasin", "Colliders/morgue_table"]


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		if entry[0] == "Buildings":
			node.set("site_rects", site_rects(ctx.layout))
		ctx.add(systems, node)


## layout.buildings.site_rects as world Rect2 (Buildings.site_rects, §5.2 step 5).
static func site_rects(layout: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in layout.get("buildings", {}).get("site_rects", []):
		out.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return out


## The site on the ground. G8 round 2: the crypt's pivot (the front of its portal wall) lies over its
## own stair pit – a site with a stair takes the ground height at the back of its footprint (the flat
## zone of asset_ground_graveyard.py, outside the pit).
static func site_xform(ctx: Ctx, site: Dictionary) -> Transform3D:
	var xf := ctx.ground_xform(Ctx.v2(site.pos), float(site.rot_y))
	if site.has("stair"):
		var fp := footprint(site)
		var back := Ctx.v2(site.pos) + Vector2(fp.get_center().x, fp.position.y + 0.05).rotated(-deg_to_rad(float(site.rot_y)))
		xf.origin.y = ctx.ground_height(back)
	return xf


static func footprint(site: Dictionary) -> Rect2:
	var fp: Array = site.footprint
	return Rect2(float(fp[0]), float(fp[1]), float(fp[2]), float(fp[3]))


# --- sites & doors (§4.1–§4.3) --------------------------------------------------------------

## Entities/site_<id>: BuildingSite (building_id), a StaticBody "Collision" over the footprint
## (height from the layout), the Exterior dressing; the chapel's soul lantern under it.
static func build_sites(ctx: Ctx, entities: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.get("buildings", {})
	for site: Dictionary in cfg.get("sites", []):
		var node := (load(SITE_SCENE) as PackedScene).instantiate() as Node3D
		node.name = site.id
		node.set("building_id", StringName(site.building))
		node.transform = site_xform(ctx, site)
		if site.has("access"):
			# G8 round 2: BuildingSite.free_area() puts whoever a load leaves in its walls here.
			var a := Ctx.v2(site.access)
			node.set("access_point", node.transform.affine_inverse() * Vector3(a.x, ctx.ground_height(a), a.y))
			node.set("has_access_point", true)
		ctx.add(entities, node)
		var fp := footprint(site)
		var h := float(site.get("height", 2.5))
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = Ctx.WORLD_LAYER
		body.collision_mask = 0
		ctx.add(node, body)
		if site.has("stair"):
			_stair_collision(ctx, body, fp, h, site.stair)
			_stair_cover(ctx, entities, site)
		else:
			_box_shape(ctx, body, "Footprint", fp, 0.0, h)
		_build_exterior(ctx, node, site, cfg)


## G7 round 1: the footprint around the stair passage ("Footprint" behind it, "FootprintWest/East"
## beside it), the plug over the passage until level 1 (meta max_level 0) and the stair cheeks from
## level 1 (meta min_level 1, from below the stair foot) – BuildingSite._apply_level_shapes.
static func _stair_collision(ctx: Ctx, body: StaticBody3D, fp: Rect2, h: float, st: Dictionary) -> void:
	var ps: Array = st.passage
	var pass_rect := Rect2(float(ps[0]), float(ps[1]), float(ps[2]) - float(ps[0]), float(ps[3]) - float(ps[1]))
	_box_shape(ctx, body, "Footprint", Rect2(fp.position.x, fp.position.y, fp.size.x, pass_rect.position.y - fp.position.y), 0.0, h)
	_box_shape(ctx, body, "FootprintWest", Rect2(fp.position.x, pass_rect.position.y, pass_rect.position.x - fp.position.x,
			fp.end.y - pass_rect.position.y), 0.0, h)
	_box_shape(ctx, body, "FootprintEast", Rect2(pass_rect.end.x, pass_rect.position.y, fp.end.x - pass_rect.end.x,
			fp.end.y - pass_rect.position.y), 0.0, h)
	var plug := _box_shape(ctx, body, "PassagePlug", pass_rect, 0.0, h)
	plug.set_meta(&"max_level", 0)
	var depth := float(st.depth)
	# The walkable stair (the ground lies `under` below the treads): the landing at ground level in
	# front, then the ramp down to the door – from level 1.
	var top := float(st.top_z)
	var bottom := float(st.bottom_z)
	var w := pass_rect.size.x
	var landing := _box_shape(ctx, body, "StairLanding", Rect2(pass_rect.position.x, top, w, float(st.get("landing", top + 0.2)) - top),
			-0.3, 0.0)
	landing.set_meta(&"min_level", 1)
	var ramp := CollisionShape3D.new()
	ramp.name = "StairRamp"
	var ramp_len := Vector2(top - bottom, depth).length()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.3, ramp_len + 0.1)
	ramp.shape = box
	var basis := Basis(Vector3.RIGHT, -atan2(depth, top - bottom))
	ramp.transform = Transform3D(basis, Vector3(pass_rect.get_center().x, -depth * 0.5, (top + bottom) * 0.5) - basis.y * 0.15)
	ramp.set_meta(&"min_level", 1)
	ctx.add(body, ramp)
	if st.has("foot"):
		# G8 round 2: the landing at the foot of the stair in front of the door (between the door
		# recess and the bottom of the ramp, which lies on the step edges).
		var f: Array = st.foot
		var foot := _box_shape(ctx, body, "StairFoot", Rect2(pass_rect.position.x, float(f[0]), w, float(f[1]) - float(f[0])),
				-depth - 0.3, -depth)
		foot.set_meta(&"min_level", 1)
	var k := 0
	for c: Array in st.get("cheeks", []):
		k += 1
		var r := Rect2(float(c[0]), float(c[1]), float(c[2]) - float(c[0]), float(c[3]) - float(c[1]))
		# G8 round 2: an optional 5th value = this cheek's own top (the near one carries a railing).
		var top_y := float(c[4]) if c.size() > 4 else float(st.get("cheek_height", 1.2))
		var cheek := _box_shape(ctx, body, "Cheek%d" % k, r, -depth - 0.2, top_y)
		cheek.set_meta(&"min_level", 1)


static func _box_shape(ctx: Ctx, body: Node3D, shape_name: String, r: Rect2, y0: float, y1: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.name = shape_name
	var box := BoxShape3D.new()
	box.size = Vector3(r.size.x, y1 - y0, r.size.y)
	shape.shape = box
	shape.position = Vector3(r.get_center().x, (y0 + y1) * 0.5, r.get_center().y)
	ctx.add(body, shape)
	return shape


## G7 round 1: the height of the stair treads (ramp) of `building`'s site at world `p`, NAN when
## `p` is not on a stair.
static func _stair_height(ctx: Ctx, building: String, p: Vector2) -> float:
	for site: Dictionary in ctx.layout.get("buildings", {}).get("sites", []):
		if String(site.building) != building or not site.has("stair"):
			continue
		var st: Dictionary = site.stair
		var origin := Ctx.v2(site.pos)
		var local := (p - origin).rotated(deg_to_rad(float(site.rot_y)))
		var t := clampf((float(st.top_z) - local.y) / (float(st.top_z) - float(st.bottom_z)), 0.0, 1.0)
		return site_xform(ctx, site).origin.y - float(st.depth) * t
	return NAN


## G7 round 1: Entities/<site>_cover – the sod patch (cover_asset) over the stair pit with a walkable
## slab, shown until the building reaches level 1 (SiteCover).
static func _stair_cover(ctx: Ctx, entities: Node3D, site: Dictionary) -> void:
	var st: Dictionary = site.stair
	if not st.has("cover_rect"):
		return
	var cover := Node3D.new()
	cover.name = String(site.id) + "_cover"
	cover.set_script(load(SITE_COVER_SCRIPT))
	cover.set("building_id", StringName(site.building))
	cover.transform = site_xform(ctx, site)
	ctx.add(entities, cover)
	var model := (load(Ctx.model_path(String(st.cover_asset))) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	ctx.add(cover, model)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(cover, body)
	var c: Array = st.cover_rect
	_box_shape(ctx, body, "Slab", Rect2(float(c[0]), float(c[1]), float(c[2]) - float(c[0]), float(c[3]) - float(c[1])), -0.3, 0.004)


static func _build_exterior(ctx: Ctx, site_node: Node3D, site: Dictionary, cfg: Dictionary) -> void:
	var building := String(site.building)
	var ext := Node3D.new()
	ext.name = "Exterior"
	ext.set_script(load(EXTERIOR_SCRIPT))
	ext.set("building_id", StringName(building))
	var lights := {}
	var rules := {}
	var prefix := String(LIGHT_ASSETS.get(building, "")) + "/"
	for key: String in ctx.layout.get("lights", {}):
		if prefix != "/" and key.begins_with(prefix):
			var marker := key.trim_prefix(prefix)
			lights[marker] = ctx.layout.lights[key]
			if LIGHT_RULES.has(marker):
				rules[marker] = LIGHT_RULES[marker]
	ext.set("lights", lights)
	ext.set("light_rule", rules)
	ctx.add(site_node, ext)
	var soul: Dictionary = cfg.get("soul_lantern", {})
	if building == "chapel" and not soul.is_empty():
		ext.set("soul_level", int(soul.get("min_level", 3)))
		ext.set("light_rule", rules.merged({"light_soul": LIGHT_RULES.light_soul}))
		var asset := String(soul.asset)
		var world_xf := ctx.ground_xform(Ctx.v2(soul.pos), float(soul.get("rot_y", 0.0)))
		var model := (load(Ctx.model_path(asset)) as PackedScene).instantiate() as Node3D
		model.name = "SoulLantern"
		model.transform = site_node.transform.affine_inverse() * world_xf
		model.visible = false
		ctx.add(ext, model)
		for marker: Node in model.find_children("light_*", "", true, false):
			var key := asset + "/" + String(marker.name)
			if not ctx.layout.lights.has(key):
				continue
			var lc: Dictionary = ctx.layout.lights[key]
			var light := OmniLight3D.new()
			light.name = "Light_" + String(marker.name).trim_prefix("light_")
			light.transform = Ctx.rel_xform(marker as Node3D, model)
			light.light_color = Color(lc.color)
			light.omni_range = float(lc.range)
			light.omni_attenuation = 1.4
			light.shadow_enabled = false
			light.light_energy = 0.0
			light.visible = false
			light.set_meta(&"energy_on", float(lc.energy))
			light.set_meta(&"base_energy", 0.0)
			light.set_meta(&"marker", String(marker.name))
			if lc.flicker:
				light.set_script(Ctx.FLICKER)
			ctx.add(model, light)
			light.add_to_group("warm_lights", true)
		var body := StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = Ctx.WORLD_LAYER
		body.collision_mask = 0
		ctx.add(model, body)
		Colliders.add_shapes(ctx, body, ctx.layout.colliders.get(asset, []), Transform3D.IDENTITY, 1.0, 1.0, "")


## Entities/door_<id>: BuildingDoor at the layout position (= the site's door_outside marker).
static func build_doors(ctx: Ctx, entities: Node3D) -> void:
	for d: Dictionary in ctx.layout.get("building_doors", []):
		var node := (load(DOOR_SCENE) as PackedScene).instantiate() as Node3D
		node.name = d.id
		node.set("building_id", StringName(d.params.building))
		node.transform = ctx.ground_xform(Ctx.v2(d.pos), float(d.rot_y))
		var on_stair := _stair_height(ctx, String(d.params.building), Ctx.v2(d.pos))
		if not is_nan(on_stair):
			node.position.y = on_stair   # G7 round 1: on the stair treads, not on the ground under them
		ctx.add(entities, node)
		if d.has("stair_trigger"):
			# G7 round 1: walking down the crypt stair into the doorway uses the door.
			var st: Dictionary = d.stair_trigger
			var area := Area3D.new()
			area.name = "StairPortal"
			area.set_script(load(STAIR_PORTAL_SCRIPT))
			area.set("direction", Ctx.v2(st.dir))
			area.set("target_path", NodePath(".."))
			ctx.add(node, area)
			var r: Array = st.rect
			_box_shape(ctx, area, "Shape", Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])),
					-0.2, float(st.get("height", 2.0)))


## G8 round 2: Decor/CryptPaving – the flagstone walk from the main path to the paved forecourt of
## the crypt stair (ph_env_crypt_paving from asset_ground_graveyard.py, world coordinates like the
## ground, no collision: the ground carries the gravekeeper).
static func build_paving(ctx: Ctx, decor: Node3D) -> void:
	if not ctx.layout.get("buildings", {}).has("paving"):
		return
	ctx.place(PAVING_ASSET, decor, Vector2.ZERO, 0.0, "CryptPaving").transform = Transform3D.IDENTITY


# --- interiors (§4.7) -----------------------------------------------------------------------

## Builds and saves the three room scenes (interior_build.gd) and instances them under Interiors/
## at their origins; camera_rig_path / outdoor_sun_path point at the world's rig and sun.
static func build_interiors(ctx: Ctx, scene_root: Node3D) -> void:
	var group := ctx.group(scene_root, "Interiors")
	var cfg: Dictionary = ctx.layout.get("interiors", {})
	for room_id: String in ROOM_NODES:
		if not cfg.has(room_id):
			continue
		var path := InteriorBuild.save_scene(InteriorBuild.build(InteriorBuild.load_layout(room_id)), room_id)
		var room := (load(path) as PackedScene).instantiate() as Node3D
		room.name = ROOM_NODES[room_id]
		room.position = Ctx.v3(cfg[room_id].origin)
		room.set("camera_rig_path", NodePath("../../CameraRig"))
		room.set("outdoor_sun_path", NodePath("../../Sun"))
		ctx.add(group, room)


# --- the old table (§4.4) -------------------------------------------------------------------

## The table in front of the hut retires at crypt level 1; the wash basin, the smoke bowl and the
## table's / basin's colliders follow it (meta follows_table = the table's node name).
static func retire_old_table(ctx: Ctx) -> void:
	var table := ctx.scene_root.get_node_or_null(NodePath("Entities/" + OLD_TABLE))
	if table == null:
		return
	table.set("retire_at_level", 1)
	for path: String in OLD_TABLE_PROPS:
		var node := ctx.scene_root.get_node_or_null(NodePath(path))
		assert(node != null, "old table prop missing: " + path)
		node.set_meta(FOLLOW_META, OLD_TABLE)
