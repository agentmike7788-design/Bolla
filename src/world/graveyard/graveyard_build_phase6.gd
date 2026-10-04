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
		node.transform = ctx.ground_xform(Ctx.v2(site.pos), float(site.rot_y))
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
	var k := 0
	for c: Array in st.get("cheeks", []):
		k += 1
		var r := Rect2(float(c[0]), float(c[1]), float(c[2]) - float(c[0]), float(c[3]) - float(c[1]))
		var cheek := _box_shape(ctx, body, "Cheek%d" % k, r, -depth - 0.2, float(st.get("cheek_height", 1.2)))
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
	cover.transform = ctx.ground_xform(Ctx.v2(site.pos), float(site.rot_y))
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
