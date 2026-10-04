extends RefCounted
## Phase-7 helpers of graveyard_builder.gd (build-time tool, static, preloaded –
## docs/PHASE7_DESIGN.md §3.1, §4.1, §4.3, §4.6): the new system nodes (Village, Relationships,
## VillageShops, Orders, Specimens, Lectures, Deductions, NpcLod), the regions (Regions/Graveyard =
## RegionRoot over the existing outdoor nodes, Regions/Village = the Hollerbrück scene from
## village_build.gd at (0, 0, 400)), the milestone at the end of the coach road (RegionPortal
## road_exit with model, collision and Label3D) and the three village rooms (InteriorRoom scenes from
## interior_build.gd, region village, in the row of rooms at z −200). The Lindenacker itself
## (section, plots, obstacles, fences, walls, moved trees, the old linden, overgrowth, the priest's
## waypoints and his Npc) is layout data that the Phase-3…6 helpers build. Scripts are loaded by path
## (see graveyard_builder.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const Decor := preload("res://src/world/graveyard/graveyard_build_decor.gd")
const VillageBuild := preload("res://src/world/village/village_build.gd")
const InteriorBuild := preload("res://src/world/interiors/interior_build.gd")
const PORTAL_SCENE := "res://src/entities/region_portal/region_portal.tscn"
const REGION_SCRIPT := "res://src/world/regions/region_root.gd"
const GRAVEYARD_REGION := "res://data/config/regions/graveyard.tres"
## §3.1: node name → script (groups / save_id / save_order are set by the scripts themselves:
## village 50 … deductions 56; NpcLod is not saved).
const SYSTEMS := [
	["Village", "res://src/systems/village/village.gd"],
	["Relationships", "res://src/systems/village/relationships.gd"],
	["VillageShops", "res://src/systems/village/village_shops.gd"],
	["Orders", "res://src/systems/village/orders.gd"],
	["Specimens", "res://src/systems/anatomy/specimens.gd"],
	["Lectures", "res://src/systems/anatomy/lectures.gd"],
	["Deductions", "res://src/systems/anatomy/deductions.gd"],
	["NpcLod", "res://src/systems/npc/npc_lod.gd"],
]
## Interiors/<Name> per village room (§4.3).
## G7 round 1: the village church walk-in as well.
const ROOM_NODES := {"inn": "InnInterior", "surgery": "SurgeryInterior", "office": "OfficeInterior", "church": "ChurchInterior"}


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		ctx.add(systems, node)


## WorldRoot/Regions: Graveyard (RegionRoot, managed_paths from data/config/regions/graveyard.tres)
## and Village (village.tscn instance at the region origin). Both get the world's CameraRig.
static func build_regions(ctx: Ctx, scene_root: Node3D) -> void:
	var regions := ctx.group(scene_root, "Regions")
	var gy := Node3D.new()
	gy.name = "Graveyard"
	gy.set_script(load(REGION_SCRIPT))
	gy.set("region_id", &"graveyard")
	gy.set("config", load(GRAVEYARD_REGION))
	gy.set("camera_rig_path", NodePath("../../CameraRig"))
	ctx.add(regions, gy)
	var path := VillageBuild.build_and_save(ctx.tree)
	var village := (load(path) as PackedScene).instantiate() as Node3D
	village.name = "Village"
	var cfg: Resource = village.get("config")
	village.position = cfg.get("origin") if cfg != null else Vector3(0.0, 0.0, 400.0)
	village.set("camera_rig_path", NodePath("../../CameraRig"))
	ctx.add(regions, village)


## Entities/<id> per layout region_portals entry (R1: the milestone road_exit): RegionPortal with the
## model as child "Model" (+ the label on its label_board marker) and its layout collider.
static func build_portals(ctx: Ctx, entities: Node3D) -> void:
	for p: Dictionary in ctx.layout.get("region_portals", []):
		var portal := (load(PORTAL_SCENE) as PackedScene).instantiate() as Node3D
		portal.name = String(p.id)
		portal.transform = ctx.ground_xform(Ctx.v2(p.pos), float(p.get("rot_y", 0.0)))
		portal.set("target_region", StringName(p.target_region))
		portal.set("target_spawn", StringName(p.target_spawn))
		portal.set("requires_flag", StringName(p.get("requires_flag", "")))
		portal.set("prompt", String(p.prompt))
		ctx.add(entities, portal)
		var asset := String(p.model)
		var model := (load(Ctx.model_path(asset)) as PackedScene).instantiate() as Node3D
		model.name = "Model"
		ctx.add(portal, model)
		if p.has("label"):
			var cfg: Dictionary = (p.get("label_cfg", {}) as Dictionary).merged({"text": String(p.label)})
			Decor.add_sign_label(ctx, model, cfg)
		Colliders.collider(ctx, asset, portal.transform, String(p.id))


## Builds and saves the three village room scenes and instances them under Interiors/ at their
## origins (village_layout.json "interiors"); camera_rig_path / outdoor_sun_path point at the world's
## rig and sun (like the Phase-6 rooms).
static func build_interiors(ctx: Ctx, scene_root: Node3D) -> void:
	var group := scene_root.get_node_or_null(^"Interiors") as Node3D
	if group == null:
		group = ctx.group(scene_root, "Interiors")
	var cfg: Dictionary = VillageBuild.load_layout().get("interiors", {})
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
