extends TestCase
## G8 Runde 3 (user: „annimationen fehlen", „die leichen preperation annimation fehlen auch"): the gravekeeper's work
## clips (tools/blender/asset_character_work.py), the small hand tools (asset_tools_hand.py) and their wiring
## (data/config/tool_anim_config.tres). Poses are evaluated offline with test_assets_characters' Rig.

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const GK := "res://assets/models/characters/ph_chr_gravekeeper.glb"
const TOOL_DIR := "res://assets/models/props/"
## The table's centre line in front of him (asset_character_work TABLE_D) and the body's surface on it.
const TABLE_D := 0.76
const TOP := 1.05
## Clip -> its tool kind (&"" = bare hands).
const TABLE_CLIPS := {
	&"table_examine": &"", &"table_search": &"", &"table_wash": &"washcloth", &"table_cut": &"scalpel",
	&"table_comb": &"comb", &"table_smoke": &"juniper", &"table_shroud": &"linen", &"table_snip": &"shears",
	&"table_pull": &"pliers",
}
const HAND_ONLY: Array[StringName] = [&"table_examine", &"table_search", &"pray", &"write", &"bench_work", &"place_low",
		&"weed_pull", &"fill_can"]
const TOOLS := {"scalpel": 40, "washcloth": 80, "comb": 40, "juniper": 100, "shears": 80, "pliers": 80, "linen": 160,
		"rake": 200}
## Every timed action of the table (MorgueTable "morgue_<key>") and the clips it must not fall back from.
const TABLE_KEYS: Array[StringName] = [&"examine", &"exam_all", &"exam_clothing", &"exam_hands", &"exam_wounds",
		&"exam_pockets", &"wash", &"dress_shroud", &"dress_gown", &"lay_out", &"balm", &"harvest_hair", &"harvest_teeth",
		&"organ"]
## The other hand work of the audit (docs/reviews/phase8_round3/animations_audit.md) -> its clip.
const OTHER := {&"grave_flowers": &"kneel_place", &"grave_wreath": &"kneel_place", &"grave_candle": &"kneel_place",
		&"grave_line": &"chisel", &"grave_mortsafe": &"hammer", &"dirt_weeds": &"weed_pull", &"dirt_leaves": &"rake",
		&"barrel_fill": &"fill_can", &"chapel_service": &"pray", &"chapel_devotion": &"pray", &"desk_copy": &"write",
		&"archive_help": &"bench_work", &"ossuary_reinter": &"place_low", &"resource_gather": &"place_low",
		&"decor_place": &"place_low", &"decor_remove": &"place_low", &"shed_fetch": &"place_low",
		&"pult_seal": &"bench_work", &"pult_display": &"bench_work", &"pult_medicine": &"bench_work",
		&"pult_bone": &"table_wash", &"pult_inspect": &"table_examine", &"anatomist_expertise": &"idle",
		&"lecture_hold": &"idle"}

var _rig: Chars.Rig


func after_each() -> void:
	if _rig != null:
		_rig.free_scene()
		_rig = null


func _gk() -> Chars.Rig:
	if _rig == null:
		_rig = Chars.Rig.new(GK)
	return _rig


static func _cfg() -> ToolAnimConfig:
	return Database.config(&"tool_anim_config") as ToolAnimConfig


func test_every_table_action_has_its_own_clip_in_the_rig() -> void:
	var r := _gk()
	var cfg := _cfg()
	var used := {}
	for key: StringName in TABLE_KEYS:
		var clip: StringName = cfg.action_clips.get(StringName("morgue_" + String(key)), &"")
		assert_true(clip in TABLE_CLIPS, "morgue_%s has a table clip (%s)" % [key, clip])
		assert_ne(MorgueTable.clip_for(key), &"interact", "morgue_%s: not the generic reach" % key)
		assert_not_null(r.animation(clip), "rig has %s" % clip)
		used[clip] = true
	assert_eq(used.size(), TABLE_CLIPS.size(), "every table clip is used: %s" % [used.keys()])


func test_the_other_hand_work_is_wired() -> void:
	var r := _gk()
	var cfg := _cfg()
	for key: StringName in OTHER:
		assert_eq(cfg.action_clips.get(key, &""), OTHER[key], "%s → %s" % [key, OTHER[key]])
		assert_not_null(r.animation(OTHER[key]), "rig has %s" % OTHER[key])
	for f: String in ["flax_bed", "herb_patch"]:
		assert_eq(load("res://data/gather/%s.tres" % f).get(&"animation"), &"weed_pull", f + ": pulled kneeling")
	assert_has(cfg.can_clips, &"fill_can", "the can shows at the barrel")


func test_tools_are_wired_like_the_belt_tools() -> void:
	var cfg := _cfg()
	var r := _gk()
	for clip: StringName in TABLE_CLIPS:
		var kind: StringName = TABLE_CLIPS[clip]
		if kind == &"":
			assert_false(cfg.held_tools.has(clip), "%s: bare hands" % clip)
			continue
		assert_eq(cfg.held_tools.get(clip), kind, "%s held with the %s" % [clip, kind])
		assert_eq(cfg.draw_clips.get(kind), &"hand_draw", "%s from the tool bag" % kind)
		assert_eq(cfg.stow_clips.get(kind), &"hand_stow")
		assert_eq(cfg.stow_walk_clips.get(kind), &"hand_stow_walk")
		assert_almost(float(cfg.hold_blends.get(clip, 0.0)), 0.25, 0.001, "%s cross-fades from the draw" % clip)
		assert_true(ResourceLoader.exists(cfg.tool_scenes.get(kind, "")), "%s scene" % kind)
	assert_eq(cfg.held_tools.get(&"rake"), &"rake")
	assert_true(ResourceLoader.exists(cfg.tool_scenes.get(&"rake", "")), "rake scene")
	for c: StringName in [&"hand_draw", &"hand_stow", &"hand_stow_walk", &"rake_take", &"rake_put", &"rake_put_walk"]:
		assert_not_null(r.animation(c), c)
		assert_eq(r.animation(c).loop_mode, Animation.LOOP_NONE, "%s one-shot" % c)
	# work beats in step with the stroke (wash, the scalpel, the comb, the shears, the pliers, the rake)
	for c: StringName in [&"table_wash", &"table_cut", &"table_comb", &"table_snip", &"table_pull", &"rake"]:
		assert_true(cfg.bite_at.has(c), "%s: a beat" % c)


func test_the_tool_marker_and_the_scenes() -> void:
	var scene := (load(GK) as PackedScene).instantiate()
	var marker := scene.find_child("tool_hand", true, false) as Node3D
	assert_not_null(marker, "the tool marker")
	if marker != null:
		var att := marker.get_parent() as BoneAttachment3D
		assert_true(att != null and att.bone_name == "tool", "on the tool bone")
		var sk := scene.get_node("Armature/Skeleton3D") as Skeleton3D
		var bone := sk.find_bone("tool")
		# the marker sits at the tool bone's rest frame (tool space = bone space)
		var rest := sk.get_bone_global_rest(bone)
		var mg := rest * marker.transform
		assert_true(mg.origin.distance_to(rest.origin) < 0.01, "marker at the bone's head (%s)" % mg.origin)
	scene.free()
	for t: String in TOOLS:
		var path := TOOL_DIR + "ph_tool_%s.glb" % t
		assert_true(ResourceLoader.exists(path), path)
		var inst := (load(path) as PackedScene).instantiate()
		var tris := 0
		var box := AABB()
		var first := true
		for n: Node in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			for s: int in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				var m := mi.mesh.surface_get_material(s)
				assert_true(m != null and m.resource_path.begins_with("res://assets/materials/"), "%s: shared material" % t)
			box = mi.get_aabb() if first else box.merge(mi.get_aabb())
			first = false
		assert_true(tris > 0 and tris <= int(TOOLS[t]), "%s: %d tris <= %d" % [t, tris, TOOLS[t]])
		# the butt (grip) at the origin: the tool reaches from it (Godot -Z = Blender +Y, the handle)
		assert_true(box.grow(0.03).has_point(Vector3.ZERO), "%s: grip at the origin (%s)" % [t, box])
		inst.free()


func test_hand_clips_keep_the_shovel_on_the_back() -> void:
	var r := _gk()
	var tool := r.skeleton.find_bone("tool")
	var rest := r.skeleton.get_bone_rest(tool)
	for c: StringName in HAND_ONLY:
		var a := r.animation(c)
		for k: int in 5:
			var p := r.local_pose(a, tool, a.length * k / 4.0)
			assert_true(p.origin.distance_to(rest.origin) < 0.002, "%s: shovel on the back" % c)


func test_the_hands_work_on_the_body() -> void:
	var r := _gk()
	# Godot axes: he faces +Z, the table's centre line at z = TABLE_D, the body's surface at y ≈ TOP
	for c: StringName in [&"table_examine", &"table_wash", &"table_cut", &"table_search"]:
		var a := r.animation(c)
		for k: int in 6:
			var t := a.length * k / 6.0
			var h := r.hand(a, "arm_r", t)
			assert_true(h.z > TABLE_D - 0.45 and h.z < TABLE_D + 0.2, "%s: right hand over the body (z %.2f, t %.2f)" % [c, h.z, t])
			assert_true(h.y > TOP - 0.2 and h.y < TOP + 0.35, "%s: right hand at the body's height (y %.2f)" % [c, h.y])
	# the wash stroke goes along the body, the comb towards him
	var w := r.animation(&"table_wash")
	var xs: Array[float] = []
	for k: int in 12:
		xs.append(r.hand(w, "arm_r", w.length * k / 12.0).x)
	assert_true(xs.max() - xs.min() > 0.3, "wash: a long stroke along the body (%.2f m)" % (xs.max() - xs.min()))


func test_the_tool_follows_the_right_fist() -> void:
	var r := _gk()
	var tool := r.skeleton.find_bone("tool")
	for c: StringName in [&"table_wash", &"table_cut", &"table_comb", &"table_snip", &"table_pull", &"table_smoke"]:
		var a := r.animation(c)
		for k: int in 4:
			var t := a.length * k / 4.0
			var origin := r.global_pose(a, tool, t).origin
			var fist := r.hand(a, "arm_r", t)
			assert_true(origin.distance_to(fist) < 0.14, "%s: the tool in the right fist (%.2f m, t %.2f)" % [c, origin.distance_to(fist), t])


func test_the_linen_between_both_fists() -> void:
	var r := _gk()
	var a := r.animation(&"table_shroud")
	var tool := r.skeleton.find_bone("tool")
	var high := -INF
	for k: int in 8:
		var t := a.length * k / 8.0
		var gap := r.hand(a, "arm_r", t).distance_to(r.hand(a, "arm_l", t))
		assert_true(gap > 0.35 and gap < 0.8, "shroud: both fists along the edge (%.2f m)" % gap)
		high = maxf(high, r.global_pose(a, tool, t).origin.y)
	assert_true(high > 1.3, "shroud: the linen is lifted to be cast (%.2f m)" % high)


func test_pray_and_kneel_work() -> void:
	var r := _gk()
	var pray := r.animation(&"pray")
	var rest := r.centroid(r.posed(null, "head", 0.0))
	assert_true(r.centroid(r.posed(pray, "head", pray.length * 0.25)).z - rest.z > 0.04, "pray: the head bowed")
	var hl := r.hand(pray, "arm_l", 0.0)
	var hr := r.hand(pray, "arm_r", 0.0)
	assert_true(hl.distance_to(hr) < 0.25, "pray: the hands together (%.2f m)" % hl.distance_to(hr))
	var weed := r.animation(&"weed_pull")
	assert_true(r.hand(weed, "arm_r", weed.length * 0.34).y < 0.45, "weed_pull: the hand down at the mound")
	var low := r.animation(&"place_low")
	assert_true(r.hand(low, "arm_r", low.length * 0.55).y < 0.55, "place_low: the hands go down low")
