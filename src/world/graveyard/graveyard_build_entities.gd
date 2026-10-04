extends RefCounted
## Entity helpers of graveyard_builder.gd (build-time tool, static, preloaded): GravePlots
## (entities and old graves), the layout "entities" (stations, resource nodes, NPCs, hut door)
## with their model colliders, and the NPC waypoint markers (layout waypoint_facing).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const PLOT_SCENE := "res://src/entities/grave/grave_plot.tscn"
const ENTITY_SCENES := {
	"morgue_table": "res://src/entities/morgue_table/morgue_table.tscn",
	"workbench": "res://src/entities/workbench/workbench.tscn",
	"dropoff": "res://src/entities/dropoff/dropoff.tscn",
	"resource_node": "res://src/entities/resource_node/resource_node.tscn",
	"hut_door": "res://src/entities/hut_door/hut_door.tscn",
	"npc": "res://src/entities/npc/npc.tscn",
}


## GravePlot (entity or old grave) with its state-dependent collision shapes.
static func build_plot(ctx: Ctx, parent: Node, g: Dictionary, old: bool) -> void:
	var plot := (load(PLOT_SCENE) as PackedScene).instantiate() as Node3D
	plot.name = g.id
	plot.set("grave_id", g.id)
	plot.set("is_old", old)
	if not old:
		plot.set("section_id", StringName(g.get("section", "yard")))
		# QA7 (§4.6 L1): l_04 / l_08 stand at the Lindenacker's east fence – their spoil heap lies at the
		# foot end (like a lifted old grave), the side heap would reach through the fence.
		plot.set("pit_variant", StringName(g.get("pit_variant", "")))
	plot.transform = ctx.ground_xform(Ctx.v2(g.pos), float(g.rot_y))
	if old:
		plot.set("old_stone", g.stone)
		plot.set("old_mound", g.mound)
		# Phase 6 (§2.3): once lifted and dug again, the spoil heap lies at the foot end.
		plot.set("pit_variant", StringName(g.get("pit_variant", "")))
	ctx.add(parent, plot)
	Colliders.build_plot_collision(ctx, plot, g, old)


static func build_entity(ctx: Ctx, parent: Node, ent: Dictionary) -> void:
	var node := (load(ENTITY_SCENES[ent.type]) as PackedScene).instantiate() as Node3D
	node.name = ent.id
	var pos := Ctx.v2(ent.pos)
	node.transform = ctx.ground_xform(pos, float(ent.rot_y))
	var params: Dictionary = ent.get("params", {})
	match String(ent.type):
		"resource_node":
			node.set("save_id", params.save_id)
			node.set("item_id", StringName(params.item_id))
			node.set("daily_amount", int(params.daily_amount))
			node.set("model", load(Ctx.model_path(params.model)))
			node.set("action_label", params.get("action_label", ""))
		"npc":
			node.set("save_id", params.save_id)
			node.set("npc_id", StringName(params.npc_id))
			node.set("model", load(Ctx.model_path(params.model)))
			# Phase 4 (Ilse, §4.2): flag gate, lantern marker, walk cycle speed, no turning.
			if params.has("requires_flag"):
				node.set("requires_flag", StringName(params.requires_flag))
			if params.has("lantern_marker"):
				node.set("lantern_marker", StringName(params.lantern_marker))
			for key: String in ["walk_anim_speed", "face_player_range"]:
				if params.has(key):
					node.set(key, float(params[key]))
		"workbench":
			node.set("station", StringName(params.get("station", "workbench")))
	ctx.add(parent, node)
	var asset: String = Ctx.ENTITY_ASSETS.get(ent.type, params.get("model", "") if ent.type == "resource_node" else "")
	if asset != "":
		Colliders.collider(ctx, asset, node.transform, ent.id)


## Marker3D per layout waypoint on the ground; waypoint_facing sets its yaw (meta "facing").
static func build_waypoints(ctx: Ctx, waypoints: Node3D) -> void:
	var layout := ctx.layout
	var facing: Dictionary = layout.get("waypoint_facing", {})
	for id: String in layout.waypoints:
		var marker := Marker3D.new()
		marker.name = id
		var p := Ctx.v2(layout.waypoints[id])
		marker.position = Vector3(p.x, ctx.ground_height(p), p.y)
		if facing.has(id):
			marker.rotation_degrees.y = float(facing[id])
			marker.set_meta(&"facing", true)
		ctx.add(waypoints, marker)
