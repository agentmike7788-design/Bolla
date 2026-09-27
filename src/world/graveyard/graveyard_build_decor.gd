extends RefCounted
## Decor helpers of graveyard_builder.gd (build-time tool, static, preloaded): hut, old oak,
## background trees and forest bushes, lantern posts, the iron fence with gate posts, props,
## the signpost with its Label3D, the fallen log (each with its layout colliders) and the
## prebuilt grass scene (graveyard_build_grass.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const Grass := preload("res://src/world/graveyard/graveyard_build_grass.gd")
const TREE_ASSET := "ph_env_tree_old_oak"
const BUSH_ASSET := "ph_env_bush"


static func build_decor(ctx: Ctx, decor: Node3D) -> void:
	var layout := ctx.layout
	ctx.place("ph_bld_gravekeeper_hut", decor, Ctx.v2(layout.hut.pos), layout.hut.rot_y, "Hut")
	Colliders.collider(ctx, "ph_bld_gravekeeper_hut", ctx.ground_xform(Ctx.v2(layout.hut.pos), layout.hut.rot_y), "Hut")
	ctx.place(TREE_ASSET, decor, Ctx.v2(layout.tree.pos), layout.tree.rot_y, "Tree")
	Colliders.collider(ctx, TREE_ASSET, ctx.ground_xform(Ctx.v2(layout.tree.pos), layout.tree.rot_y), "Tree")
	var trees := ctx.group(decor, "Trees")
	var k := 0
	for t: Dictionary in layout.background_trees + layout.forest.trees:
		k += 1
		var tree := ctx.place(TREE_ASSET, trees, Ctx.v2(t.pos), t.rot_y, "Tree_%02d" % k)
		tree.scale = Vector3.ONE * float(t.scale)
		Colliders.collider(ctx, TREE_ASSET, ctx.ground_xform(Ctx.v2(t.pos), t.rot_y), "Tree_%02d" % k, float(t.scale))
	var bushes := ctx.group(decor, "Bushes")
	k = 0
	for b: Dictionary in layout.forest.bushes:
		k += 1
		var bush := ctx.place(BUSH_ASSET, bushes, Ctx.v2(b.pos), b.rot_y, "Bush_%02d" % k)
		bush.scale = Vector3.ONE * float(b.scale)
		Colliders.collider(ctx, BUSH_ASSET, ctx.ground_xform(Ctx.v2(b.pos), b.rot_y), "Bush_%02d" % k, float(b.scale))
	var posts := ctx.group(decor, "LanternPosts")
	k = 0
	for lp: Dictionary in layout.lantern_posts:
		k += 1
		ctx.place("ph_prop_lantern_post", posts, Ctx.v2(lp.pos), lp.rot_y, "LanternPost_%d" % k, lp.get("light_overrides", {}))
		Colliders.collider(ctx, "ph_prop_lantern_post", ctx.ground_xform(Ctx.v2(lp.pos), lp.rot_y), "LanternPost_%d" % k)
	build_fence(ctx, ctx.group(decor, "Fence"))
	var props := ctx.group(decor, "Props")
	k = 0
	for pr: Dictionary in layout.props:
		k += 1
		ctx.place(pr.asset, props, Ctx.v2(pr.pos), pr.rot_y, "%s_%d" % [String(pr.asset).trim_prefix("ph_prop_"), k])
		Colliders.collider(ctx, pr.asset, ctx.ground_xform(Ctx.v2(pr.pos), pr.rot_y), "Prop_%d" % k)
	var sign_cfg: Dictionary = layout.signpost
	var signpost := ctx.place("ph_prop_signpost", decor, Ctx.v2(sign_cfg.pos), sign_cfg.rot_y, "Signpost")
	Colliders.collider(ctx, "ph_prop_signpost", signpost.transform, "Signpost")
	add_sign_label(ctx, signpost, sign_cfg)
	var log_cfg: Dictionary = layout.fallen_log
	var fallen := ctx.place("ph_prop_fallen_log", decor, Ctx.v2(log_cfg.pos), log_cfg.rot_y, "FallenLog")
	Colliders.collider(ctx, "ph_prop_fallen_log", fallen.transform, "FallenLog")
	var grass := (load(Grass.OUT_GRASS) as PackedScene).instantiate()
	grass.name = "Grass"
	ctx.add(decor, grass)


static func build_fence(ctx: Ctx, fence: Node3D) -> void:
	var layout := ctx.layout
	var piece_len: float = layout.colliders["ph_prop_fence_iron"][0].size[0]
	var k := 0
	for seg: Array in layout.fence.segments:
		var a := Ctx.v2(seg[0])
		var b := Ctx.v2(seg[1])
		var d := b - a
		var count := ceili(d.length() / piece_len - 0.001)
		for i: int in count:
			k += 1
			var start := a + d.normalized() * piece_len * i
			var rot := rad_to_deg(atan2(-d.y, d.x))
			var piece := ctx.place("ph_prop_fence_iron", fence, start, rot, "fence_%02d" % k)
			var remaining := d.length() - piece_len * i
			var stretch := minf(remaining / piece_len, 1.0)
			if stretch < 1.0:
				piece.scale.x = stretch
			Colliders.collider(ctx, "ph_prop_fence_iron", ctx.ground_xform(start, rot), "Fence_%02d" % k, 1.0, stretch)
	k = 0
	for gp: Array in layout.fence.gate_posts:
		k += 1
		ctx.place("ph_prop_gate_post", fence, Ctx.v2(gp), 0.0, "gate_post_%d" % k)
		Colliders.collider(ctx, "ph_prop_gate_post", ctx.ground_xform(Ctx.v2(gp), 0.0), "GatePost_%d" % k)


## Label3D "Hollerbrück" on the signpost's label_board marker (front face, +Z).
static func add_sign_label(ctx: Ctx, signpost: Node3D, cfg: Dictionary) -> void:
	var marker := signpost.find_child("label_board", true, false) as Node3D
	if marker == null:
		push_error("signpost has no label_board marker")
		return
	var label := Label3D.new()
	label.name = "Label"
	label.text = cfg.text
	label.font_size = int(cfg.font_size)
	label.pixel_size = float(cfg.pixel_size)
	label.modulate = Color(cfg.color)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.transform = Ctx.rel_xform(marker, signpost) * Transform3D(Basis.IDENTITY, Vector3(0, 0, float(cfg.surface_offset)))
	ctx.add(signpost, label)
