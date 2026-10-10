extends TestCase
## Phase 8 assets (P5, docs/PHASE8_DESIGN.md §8): the eight new figures on the shared rig (8 bones, Jakob and
## Lambert 9 with `tool`), their clips and child meshes (glTF extras "show_with" -> node meta "extras"), the
## faces from lib_faces (marker `face`), the villagers and the gravekeeper re-exported with additional clips
## (body mesh and the old clips unchanged: hashes taken from the Phase-7 exports), the fiddler, the props,
## tools, interior pieces and the item models (icons).
## Sizes use Godot axes: x = width, y = height, z = depth (front = +Z).

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const GROUND := "res://assets/materials/mat_ground.tres"
const BONES: PackedStringArray = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const GENERATORS: Array[String] = ["asset_mourners", "asset_apprentice", "asset_wanderers", "asset_props_phase8"]

const TRAUER_W: Array[String] = ["idle", "walk", "talk", "idle_low", "kneel_in", "kneel", "kneel_out", "lay_flowers",
		"lantern_walk"]
## name -> bones (8 / 9), triangle budget (body + child meshes, §8.1), height range (m), clips, child meshes (name -> bone)
const FIGURES := {
	"ph_chr_apprentice": {"bones": 9, "tris": 8000, "height": [1.4, 1.5],
		"clips": ["idle", "walk", "talk", "rake", "weed", "water", "candle", "watch", "read_board", "sit_eat", "sweep",
				"carry_can_walk", "oops", "whistle", "idle_low", "lantern_walk", "dance", "clap"],
		"children": {"rake": "tool", "watering_can": "tool", "broom": "tool", "lantern": "tool"}},
	"ph_chr_mourner_w_a": {"bones": 8, "tris": 7500, "height": [1.55, 1.68], "clips": TRAUER_W,
		"children": {"bouquet": "arm_r", "basket": "arm_l", "lantern_prop": "arm_l"}},
	"ph_chr_mourner_w_b": {"bones": 8, "tris": 7500, "height": [1.52, 1.66], "clips": TRAUER_W,
		"children": {"bouquet": "arm_r", "lantern_prop": "arm_l"}},
	"ph_chr_mourner_m_a": {"bones": 8, "tris": 7500, "height": [1.72, 1.86],
		"clips": ["idle", "walk", "talk", "idle_low", "lay_flowers", "mourn_stand", "lantern_walk"],
		"children": {"hat_head": "head", "hat_hand": "arm_r", "bouquet": "arm_r", "lantern_prop": "arm_l"}},
	"ph_chr_mourner_m_b": {"bones": 8, "tris": 7500, "height": [1.6, 1.74],
		"clips": ["idle", "walk", "talk", "idle_low", "mourn_stand", "lantern_walk"],
		"children": {"hat_head": "head", "hat_hand": "arm_r", "lantern_prop": "arm_r"}},
	"ph_chr_beggar": {"bones": 8, "tris": 8500, "height": [1.7, 1.84],
		"clips": ["idle", "walk", "walk_stiff", "talk", "sit_beg", "sit_ground", "stand_up", "idle_low"],
		"children": {"tin_cup": "arm_r"}},
	"ph_chr_peddler": {"bones": 8, "tris": 9000, "height": [1.56, 1.7],
		"clips": ["idle", "walk", "talk", "offer", "kiepe_off", "kiepe_on", "idle_low", "lantern_walk", "dance", "clap"],
		"children": {"kiepe": "spine", "kiepe_down": "root", "staff": "arm_l", "lantern_prop": "arm_r"}},
	"ph_chr_robber": {"bones": 9, "tris": 8500, "height": [1.72, 1.86],
		"clips": ["idle", "walk", "talk", "dig_night", "startle", "run", "climb", "sit_ground"],
		"children": {"scarf_up": "head", "scarf_down": "spine", "spade": "tool", "lantern_blind": "arm_l"}},
}
const KIEPE_MAX := 1800
const ONE_SHOTS: Array[String] = ["kneel_in", "kneel_out", "lay_flowers", "knock", "candle", "read_board", "oops",
		"stand_up", "kiepe_off", "kiepe_on", "startle", "climb", "kneel_place"]
## one-shots that end in a held pose (the next clip starts there) / start in one
const ENDS_POSED: Array[String] = ["kneel_in"]
const STARTS_POSED: Array[String] = ["kneel_out", "stand_up"]

## Phase-7 exports (before the Phase-8 re-export): body mesh hash and the hash of every old clip
## (computed with _mesh_hash / _anim_hash on bb21a75).
const REEXPORT := {
	"ph_chr_v_innkeeper": ["345dcf07833268ae", {"idle": "c3ccc18a775fbef1", "talk": "55e2fc2fd43cfe2b", "walk": "8d1d5c09d7baa3b2"},
		["idle_low", "lantern_walk", "kneel_in", "kneel", "kneel_out", "lay_flowers", "dance", "clap"]],
	"ph_chr_v_smith": ["b4af662ec7bb1648", {"idle": "5cc18f8b90e389da", "talk": "184733d754a8eace", "walk": "a4ab56839db3087c",
		"work": "159ad01d436e5972"}, ["idle_low", "lantern_walk", "mourn_stand", "dance"]],
	"ph_chr_v_grocer": ["256617124feb3feb", {"idle": "7f965bb4a908613d", "talk": "b3e2290ceb122dc9", "walk": "117d2e1b2916fffd",
		"work": "2c3a9f5d8d9f2c14"}, ["idle_low", "lantern_walk", "kneel_in", "kneel", "kneel_out", "lay_flowers", "dance", "clap"]],
	"ph_chr_v_priest": ["26348b345348fac2", {"idle": "873992174879bc58", "talk": "5a0b6a0514dfd618", "walk": "376b87024b0cc8e2"},
		["idle_low", "lantern_walk", "mourn_stand", "knock", "clap"]],
	"ph_chr_v_mayor": ["f9a47d391292ea95", {"idle": "96c632eda6270322", "talk": "b1d12af31c97d52f", "walk": "187d5eea6c85a0e8"},
		["idle_low", "lantern_walk", "mourn_stand", "dance"]],
	"ph_chr_v_surgeon": ["1c247121022d9db1", {"idle": "43e40c61f18b4839", "talk": "240391f41f748cf7", "walk": "2c98c3e7554af50f"},
		["idle_low", "lantern_walk", "knock"]],
	"ph_chr_v_washer": ["aae89767caa710be", {"idle": "0f7cd103de0d069c", "talk": "97f8726c1f33c801", "walk": "7ba126621da75a21",
		"work": "15f0d8cb00f5b1c0"}, ["idle_low", "lantern_walk", "kneel_in", "kneel", "kneel_out", "lay_flowers", "knock", "dance",
		"clap"]],
	"ph_chr_v_oldwoman": ["a7bdf845e58d049c", {"idle": "aa85d2473a1201a9", "sit": "3c81f8e034b2f7d1", "talk": "87a93367967b8d29",
		"walk": "dc57382cafc8a07c"}, ["idle_low", "lantern_walk"]],
}
const GRAVEKEEPER_MESH := "2b30f35eb0a71d85"
const GRAVEKEEPER_NEW: Array[String] = ["kneel_place", "water", "sit_bench", "dance"]

## props: name -> [category, min size, max size, triangle budget (§8.4)]
const PROPS := {
	"ph_prop_grave_flowers": ["props", Vector3(0.4, 0.06, 0.6), Vector3(0.75, 0.3, 1.1), 500],
	"ph_prop_grave_flowers_wilted": ["props", Vector3(0.4, 0.04, 0.6), Vector3(0.75, 0.3, 1.1), 500],
	"ph_prop_wax_wreath": ["props", Vector3(0.3, 0.04, 0.3), Vector3(0.5, 0.15, 0.5), 600],
	"ph_prop_bouquet_heath": ["props", Vector3(0.05, 0.03, 0.15), Vector3(0.3, 0.2, 0.4), 250],
	"ph_prop_bouquet_fir": ["props", Vector3(0.05, 0.02, 0.15), Vector3(0.35, 0.2, 0.45), 250],
	"ph_prop_bouquet_straw": ["props", Vector3(0.05, 0.03, 0.15), Vector3(0.3, 0.2, 0.4), 250],
	"ph_prop_bouquet_rose": ["props", Vector3(0.05, 0.03, 0.15), Vector3(0.3, 0.2, 0.4), 250],
	"ph_prop_grave_candle": ["props", Vector3(0.05, 0.1, 0.05), Vector3(0.1, 0.2, 0.1), 120],
	"ph_prop_mortsafe": ["props", Vector3(0.9, 0.9, 1.9), Vector3(1.15, 1.1, 2.2), 1200],
	"ph_prop_grave_disturbed": ["props", Vector3(0.7, 0.1, 0.8), Vector3(1.4, 0.4, 1.4), 800],
	"ph_prop_tip_coins": ["props", Vector3(0.06, 0.005, 0.04), Vector3(0.2, 0.05, 0.15), 150],
	"ph_prop_chalkboard": ["props", Vector3(0.8, 1.2, 0.04), Vector3(1.1, 1.4, 0.3), 600],
	"ph_prop_apprentice_box": ["props", Vector3(0.5, 0.3, 0.3), Vector3(0.75, 0.5, 0.5), 500],
	"ph_prop_apprentice_bench": ["props", Vector3(0.9, 0.3, 0.2), Vector3(1.3, 0.45, 0.4), 400],
	"ph_prop_rain_barrel": ["props", Vector3(0.5, 0.75, 0.5), Vector3(0.7, 0.95, 0.7), 600],
	"ph_tool_rake_small": ["props", Vector3(0.25, 1.1, 0.03), Vector3(0.45, 1.4, 0.15), 300],
	"ph_tool_watering_can": ["props", Vector3(0.1, 0.25, 0.25), Vector3(0.25, 0.4, 0.45), 300],
	"ph_tool_broom": ["props", Vector3(0.1, 1.2, 0.08), Vector3(0.25, 1.4, 0.2), 300],
	"ph_tool_lantern_hand": ["props", Vector3(0.06, 0.15, 0.06), Vector3(0.12, 0.25, 0.12), 300],
	"ph_tool_spade_robber": ["props", Vector3(0.14, 1.1, 0.02), Vector3(0.3, 1.35, 0.1), 300],
	"ph_tool_lantern_blind": ["props", Vector3(0.06, 0.12, 0.06), Vector3(0.12, 0.25, 0.12), 300],
	"ph_prop_peddler_kiepe": ["props", Vector3(0.4, 0.8, 0.25), Vector3(0.7, 1.1, 0.75), 1500],
	"ph_prop_tin_cup": ["props", Vector3(0.06, 0.06, 0.06), Vector3(0.12, 0.1, 0.1), 100],
	"ph_int_church_archive": ["interior", Vector3(1.1, 1.9, 0.45), Vector3(1.4, 2.2, 0.7), 1200],
	"ph_int_memorial_plate": ["interior", Vector3(0.25, 0.15, 0.015), Vector3(0.35, 0.22, 0.05), 200],
	"ph_int_inn_fest_decor": ["interior", Vector3(2.8, 0.3, 0.05), Vector3(3.4, 0.8, 0.3), 800],
	"ph_chr_fiddler": ["characters", Vector3(0.4, 1.0, 0.4), Vector3(1.0, 1.5, 1.0), 2500],
}
## Where a lantern / candle may glow (mat_emissive_warm); every other surface is not emissive.
const MAY_GLOW: Array[String] = ["ph_prop_grave_candle", "ph_tool_lantern_hand", "ph_tool_lantern_blind", "ph_item_grave_candle"]
const ITEMS: Array[String] = ["flower_seedlings", "grave_candle", "watering_can", "apprentice_rake", "mortsafe", "wax_wreath",
		"register_extract", "memorial_plate", "quast_crate", "lorenz_ledger_2"]
const ITEM_MIN := Vector3(0.1, 0.005, 0.1)
const ITEM_MAX := Vector3(0.45, 0.35, 0.45)
const PROP_HEIGHT_MAX := 1.4

var _to_free: Array[Node] = []
var _rigs: Dictionary = {}


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()
	for r: Variant in _rigs.values():
		r.free_scene()
	_rigs.clear()


# --- the new figures ----------------------------------------------------------------------------------

func test_figures_exist_on_the_shared_rig() -> void:
	for c: String in FIGURES:
		var r := _rig(c)
		assert_not_null(r.skeleton, c + ": skeleton")
		assert_not_null(r.player, c + ": AnimationPlayer")
		if r.skeleton == null:
			continue
		var n: int = FIGURES[c].bones
		assert_eq(r.skeleton.get_bone_count(), n, "%s: %d bones" % [c, n])
		for b: String in BONES:
			assert_true(r.skeleton.find_bone(b) >= 0, "%s: bone %s" % [c, b])
		if n == 9:
			var t := r.skeleton.find_bone("tool")
			assert_true(t >= 0 and r.skeleton.get_bone_name(r.skeleton.get_bone_parent(t)) == "spine", c + ": tool on spine")
		assert_true(r.rigid_ok, c + ": rigid skinning")
		assert_eq(r.player.autoplay, "", c + ": no autoplay")


func test_figure_budgets_and_heights() -> void:
	for c: String in FIGURES:
		var r := _rig(c)
		var tris := 0
		for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
			tris += _mesh_tris((n as MeshInstance3D).mesh)
		assert_true(tris <= int(FIGURES[c].tris) and tris >= 3000, "%s: %d tris (<= %d, body + child meshes)" % [c, tris, FIGURES[c].tris])
		var box := AABB(r.verts[0], Vector3.ZERO)
		for v: Vector3 in r.verts:
			box = box.expand(v)
		var lim: Array = FIGURES[c].height
		assert_true(box.end.y >= lim[0] and box.end.y <= lim[1], "%s: height %.2f in %s" % [c, box.end.y, lim])
		assert_true(absf(box.position.y) < 0.012, "%s: feet on the ground (%.3f)" % [c, box.position.y])
	var k := _child(_rig("ph_chr_peddler"), "kiepe")
	assert_true(k != null and _mesh_tris(k.mesh) <= KIEPE_MAX, "Hanne's kiepe <= %d tris" % KIEPE_MAX)


func test_jakob_is_a_boy_of_about_one_forty_five() -> void:
	var r := _rig("ph_chr_apprentice")
	var top := -INF
	for v: Vector3 in r.verts:
		top = maxf(top, v.y)
	assert_true(absf(top - 1.45) <= 0.05, "Jakob %.2f m" % top)
	var head := r.posed(null, "head", 0.0)
	var hb := AABB(head[0], Vector3.ZERO)
	for p: Vector3 in head:
		hb = hb.expand(p)
	assert_true(top / hb.size.y > 4.0 and top / hb.size.y < 5.2, "about 4.5 head heights (%.2f)" % (top / hb.size.y))


func test_clip_lists() -> void:
	for c: String in FIGURES:
		assert_eq(_clips(c), _sorted(FIGURES[c].clips), c + ": clip list")


func test_loops_and_one_shots() -> void:
	for c: String in FIGURES:
		_check_clips(c, _sorted(FIGURES[c].clips))


func test_figures_face_plus_z_and_keep_root_still() -> void:
	for c: String in FIGURES:
		var r := _rig(c)
		for leg: String in ["leg_l", "leg_r"]:
			var front := -INF
			var back := INF
			for p: Vector3 in r.boot(null, leg, 0.0):
				front = maxf(front, p.z)
				back = minf(back, p.z)
			assert_true(front > -back + 0.03, "%s: %s toes point to +Z" % [c, leg])


func test_child_meshes_on_their_bones_with_show_with() -> void:
	for c: String in FIGURES:
		var r := _rig(c)
		var clips := _clips(c)
		var kids: Dictionary = FIGURES[c].children
		for kid: String in kids:
			var m := _child(r, kid)
			assert_not_null(m, "%s: child mesh %s" % [c, kid])
			if m == null:
				continue
			var att := m.get_parent() as BoneAttachment3D
			assert_true(att != null and att.bone_name == kids[kid], "%s/%s on bone %s" % [c, kid, kids[kid]])
			assert_null(m.skin, "%s/%s not skinned into the body" % [c, kid])
			var shown := _show_with(m)
			assert_false(shown.is_empty(), "%s/%s: extras show_with" % [c, kid])
			for clip: String in shown:
				assert_has(clips, clip, "%s/%s: show_with names a clip of the figure (%s)" % [c, kid, clip])
		# every child mesh of the figure is listed (no stray meshes)
		var found := 0
		for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
			if n != r.mesh_instance:
				found += 1
		assert_eq(found, kids.size(), c + ": child mesh count")


func test_hats_and_bouquets_follow_the_visit() -> void:
	for c: String in ["ph_chr_mourner_m_a", "ph_chr_mourner_m_b"]:
		var r := _rig(c)
		var head := _show_with(_child(r, "hat_head"))
		var hand := _show_with(_child(r, "hat_hand"))
		assert_has(hand, "mourn_stand", c + ": the hat in the hands while mourning")
		assert_has(head, "walk", c + ": the hat on the head when walking")
		for clip: String in hand:
			assert_false(clip in head, "%s: never two hats (%s)" % [c, clip])
	for c: String in ["ph_chr_mourner_w_a", "ph_chr_mourner_w_b", "ph_chr_mourner_m_a"]:
		var b := _show_with(_child(_rig(c), "bouquet"))
		assert_has(b, "lay_flowers", c + ": the bunch until it is laid down")
		assert_false("kneel" in b or "mourn_stand" in b, c + ": no bunch in the hand while mourning")
	var kiepe := _show_with(_child(_rig("ph_chr_peddler"), "kiepe"))
	assert_false("offer" in kiepe, "Hanne sells with the kiepe set down beside her")
	assert_eq(Array(_show_with(_child(_rig("ph_chr_peddler"), "kiepe_down"))), ["offer"], "W3: the set-down kiepe beside her while she offers")
	assert_has(kiepe, "walk", "Hanne walks with the kiepe on her back")
	var r2 := _rig("ph_chr_robber")
	assert_false("sit_ground" in _show_with(_child(r2, "scarf_up")), "Lambert caught: the neckerchief is down")
	assert_has(_show_with(_child(r2, "scarf_down")), "sit_ground", "the face is readable when he is caught")


func test_tools_ride_on_the_tool_bone() -> void:
	var ja := FIGURES["ph_chr_apprentice"].children as Dictionary
	for tool: String in ja:
		var m := _child(_rig("ph_chr_apprentice"), tool)
		assert_true(m != null and String((m.get_meta("extras", {}) as Dictionary).get("carry_with", "")) != "",
				"Jakob's %s says where it may be carried" % tool)
	var r := _rig("ph_chr_apprentice")
	var rake := r.animation(&"rake")
	var tool := r.skeleton.find_bone("tool")
	for k: int in 4:
		var t := rake.length * k / 4.0
		var xf := r.global_pose(rake, tool, t)
		var fist := r.hand(rake, "arm_r", t)
		assert_true(xf.origin.distance_to(fist) < 0.09, "rake: the tool in the right fist (%.3f)" % xf.origin.distance_to(fist))
		# the rake head (0.97 m up the shaft, tool space +Y) lies on the ground in front of him
		var head := xf * Vector3(0, 0.97, 0)
		assert_true(head.y < 0.12 and head.z > 0.3, "rake: the head on the ground in front (%s)" % head)
	var water := r.animation(&"water")
	var up := r.global_pose(water, tool, 0.0).basis.y.normalized()
	assert_true(rad_to_deg(up.angle_to(Vector3.UP)) > 25.0 and up.z > 0.0, "water: the can tilted forward (%s)" % up)
	var walk := r.animation(&"walk")
	var shaft := r.global_pose(walk, tool, 0.0).basis.y.normalized()
	assert_true(shaft.y > 0.8, "walking: the rake carried upright, the head up (%s)" % shaft)
	var lam := _rig("ph_chr_robber")
	var dig := lam.animation(&"dig_night")
	var lt := lam.skeleton.find_bone("tool")
	var blade := lam.global_pose(dig, lt, 0.0) * Vector3(0, 0.95, 0)
	assert_true(blade.y < 0.15, "dig_night: the spade's blade in the earth (%s)" % blade)


func test_faces_are_built_by_lib_faces() -> void:
	for c: String in FIGURES:
		var r := _rig(c)
		var f := r.scene.find_child("face", true, false) as Node3D
		assert_not_null(f, c + ": face marker")
		if f == null:
			continue
		var att := f.get_parent() as BoneAttachment3D
		assert_true(att != null and att.bone_name == "head", c + ": face marker on the head bone")
	for gen: String in ["asset_mourners", "asset_apprentice", "asset_wanderers"]:
		var src := FileAccess.get_file_as_string("res://tools/blender/%s.py" % gen)
		assert_true(src.contains("from lib_faces import") and src.contains("_head(parts"), gen + " builds its faces with lib_faces._head")
	assert_true(FileAccess.get_file_as_string("res://tools/blender/asset_mourners.py").contains("_stable_glb(path)"),
			"Phase-8 figures are canonicalised")


# --- poses: what the clips show -------------------------------------------------------------------------

func test_kneeling_lowers_the_hips_and_keeps_the_feet_down() -> void:
	for c: String in ["ph_chr_mourner_w_a", "ph_chr_mourner_w_b", "ph_chr_v_innkeeper", "ph_chr_v_grocer", "ph_chr_v_washer"]:
		var r := _rig(c)
		var kneel := r.animation(&"kneel")
		var drop := r.centroid(r.posed(null, "hips", 0.0)).y - r.centroid(r.posed(kneel, "hips", kneel.length * 0.5)).y
		assert_true(drop > 0.3 and drop < 0.5, "%s: kneeling, the hips %.2f m lower" % [c, drop])
		for leg: String in ["leg_l", "leg_r"]:
			assert_true(r.lowest_y(r.posed(kneel, leg, 0.0)) > -0.02, "%s/%s above the ground" % [c, leg])
		var head := r.centroid(r.posed(kneel, "head", 0.0))
		var hands := (r.hand(kneel, "arm_l", 0.0) + r.hand(kneel, "arm_r", 0.0)) * 0.5
		assert_true(hands.y < head.y - 0.25, "%s: nothing brought to the face" % c)
		# kneel_in ends where kneel begins, kneel_out starts there
		_same_pose(r, r.animation(&"kneel_in"), 1.0, kneel, 0.0, c + ": kneel_in -> kneel")
		_same_pose(r, kneel, 0.0, r.animation(&"kneel_out"), 0.0, c + ": kneel -> kneel_out")


func test_folded_hands_meet_in_front_of_the_belly() -> void:
	for c: String in ["ph_chr_mourner_m_a", "ph_chr_mourner_m_b", "ph_chr_v_priest", "ph_chr_v_mayor", "ph_chr_v_smith"]:
		var r := _rig(c)
		var a := r.animation(&"mourn_stand")
		var l := r.hand(a, "arm_l", 0.0)
		var rr := r.hand(a, "arm_r", 0.0)
		var head := r.centroid(r.posed(a, "head", 0.0))
		if c == "ph_chr_mourner_m_a":   # the others hold a stick, a book, the staff or the hammer
			assert_true(l.distance_to(rr) < 0.32, "%s: the hands meet in front (%.2f m apart)" % [c, l.distance_to(rr)])
			assert_true(l.z > 0.12 and l.y < head.y - 0.45, "%s: low in front of the belly (%s)" % [c, l])
		var rest_head := r.centroid(r.posed(null, "head", 0.0))
		assert_true(head.z > rest_head.z + 0.01, "%s: the head lowered" % c)


func test_lay_flowers_reaches_down_to_the_mound() -> void:
	for c: String in ["ph_chr_mourner_w_a", "ph_chr_mourner_m_a", "ph_chr_v_grocer"]:
		var r := _rig(c)
		var a := r.animation(&"lay_flowers")
		var rest := r.hand(null, "arm_r", 0.0)
		var at := r.hand(a, "arm_r", a.length * 30.0 / 45.0)
		assert_true(at.y < rest.y - 0.2 and at.z > rest.z + 0.3, "%s: at frame 30 the hand is low in front (%s)" % [c, at])


func test_lantern_walk_holds_the_lantern_forward() -> void:
	for c: String in ["ph_chr_mourner_w_a", "ph_chr_v_priest", "ph_chr_v_oldwoman", "ph_chr_apprentice"]:
		var r := _rig(c)
		var a := r.animation(&"lantern_walk")
		var lantern := "lantern" if c == "ph_chr_apprentice" else "lantern_prop"
		assert_has(_show_with(_child(r, lantern)), "lantern_walk", c + ": the lantern shows in lantern_walk")
		var lb := _child(r, lantern).get_parent() as BoneAttachment3D
		var arm := "arm_r" if lb.bone_name in ["arm_r", "tool"] else "arm_l"
		var h := r.hand(a, arm, a.length * 0.5)
		assert_true(h.z > r.hand(null, arm, 0.0).z + 0.1, "%s: the lantern arm forward (%s)" % [c, h])


func test_sitting_clips_put_the_hips_on_a_seat() -> void:
	for spec: Array in [["ph_chr_apprentice", &"sit_eat", 0.2, 0.36], ["ph_chr_beggar", &"sit_beg", 0.25, 0.45], ["ph_chr_beggar", &"sit_ground", 0.55, 0.85],
			["ph_chr_gravekeeper", &"sit_bench", 0.2, 0.36], ["ph_chr_robber", &"sit_ground", 0.55, 0.85]]:
		var r := _rig(spec[0])
		var a := r.animation(spec[1])
		var drop := r.centroid(r.posed(null, "hips", 0.0)).y - r.centroid(r.posed(a, "hips", a.length * 0.3)).y
		assert_true(drop > float(spec[2]) and drop < float(spec[3]), "%s/%s: the hips %.2f m lower" % [spec[0], spec[1], drop])
		for leg: String in ["leg_l", "leg_r"]:
			var low := r.lowest_y(r.posed(a, leg, a.length * 0.3))
			assert_true(low > -0.03, "%s/%s: %s above the ground (%.3f)" % [spec[0], spec[1], leg, low])


func test_veit_walks_with_a_stiff_right_leg() -> void:
	var r := _rig("ph_chr_beggar")
	var a := r.animation(&"walk_stiff")
	var swing := {}
	for leg: String in ["leg_l", "leg_r"]:
		var lo := INF
		var hi := -INF
		for k: int in 8:
			var z := r.centroid(r.boot(a, leg, a.length * k / 8.0)).z
			lo = minf(lo, z)
			hi = maxf(hi, z)
		swing[leg] = hi - lo
	assert_true(float(swing["leg_r"]) < float(swing["leg_l"]) * 0.75, "the right leg swings less (%s)" % swing)
	assert_eq(_anim_hash(r.animation(&"walk")), _anim_hash(a), "his walk is the stiff walk")


# --- the re-exported villagers and the gravekeeper ----------------------------------------------------

func test_villagers_reexport_keeps_mesh_and_old_clips() -> void:
	for c: String in REEXPORT:
		var r := _rig(c)
		assert_eq(_mesh_hash(r.mesh_instance), String(REEXPORT[c][0]), c + ": body mesh unchanged (geometry, faces, materials)")
		var old: Dictionary = REEXPORT[c][1]
		for clip: String in old:
			assert_eq(_anim_hash(r.animation(clip)), String(old[clip]), "%s/%s unchanged" % [c, clip])
		var want: Array = old.keys()
		want.append_array(REEXPORT[c][2])
		assert_eq(_clips(c), _sorted(want), c + ": Phase-7 clips + the Phase-8 clips")
		_check_clips(c, _sorted(REEXPORT[c][2]))
		var lan := _child(r, "lantern_prop")
		assert_true(lan != null and _show_with(lan) == PackedStringArray(["lantern_walk"]), c + ": lantern_prop only in lantern_walk")
	assert_false(_clips("ph_chr_v_surgeon").has("kneel"), "Quast does not kneel")
	assert_false(_clips("ph_chr_carter").has("dance"), "Osric does not dance")


func test_gravekeeper_gets_the_grave_clips() -> void:
	var r := _rig("ph_chr_gravekeeper")
	assert_eq(_mesh_hash(r.mesh_instance), GRAVEKEEPER_MESH, "gravekeeper body unchanged")
	var clips := _clips("ph_chr_gravekeeper")
	for c: String in GRAVEKEEPER_NEW:
		assert_has(clips, c, "gravekeeper: " + c)
	_check_clips("ph_chr_gravekeeper", GRAVEKEEPER_NEW)
	var tool := r.skeleton.find_bone("tool")
	var rest := r.skeleton.get_bone_rest(tool)
	for c: String in GRAVEKEEPER_NEW:
		var a := r.animation(c)
		for k: int in 4:
			var p := r.local_pose(a, tool, a.length * k / 3.0)
			assert_true(p.origin.distance_to(rest.origin) < 0.002, "%s: the shovel stays on the back" % c)
	var grip := r.scene.find_child("can_grip", true, false) as Node3D
	assert_true(grip != null and (grip.get_parent() as BoneAttachment3D).bone_name == "arm_r", "the can's grip on the right arm")
	var kp := r.animation(&"kneel_place")
	var low := r.hand(kp, "arm_r", kp.length * 0.6)
	assert_true(low.y < 0.5 and low.z > 0.3, "kneel_place: the hand at the mound (%s)" % low)


# --- props, tools, items -------------------------------------------------------------------------------

func test_props_exist_with_budgets_and_sizes() -> void:
	for p: String in PROPS:
		var path := _path(p)
		assert_true(ResourceLoader.exists(path), "missing " + path)
		if not ResourceLoader.exists(path):
			continue
		var inst := _load_free(path)
		var tris := _triangles(inst)
		assert_true(tris <= int(PROPS[p][3]) and tris >= 40, "%s: %d tris (<= %d)" % [p, tris, PROPS[p][3]])
		var box := _aabb(inst)
		var lo: Vector3 = PROPS[p][1]
		var hi: Vector3 = PROPS[p][2]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis], "%s size %s outside %s..%s" % [p, box.size, lo, hi])
		if p != "ph_int_inn_fest_decor":
			assert_true(box.position.y <= 0.02 and box.position.y >= -0.05, "%s rests on the ground (%.3f)" % [p, box.position.y])
		if String(PROPS[p][0]) == "props":
			assert_true(box.end.y <= PROP_HEIGHT_MAX, "%s: %.2f m <= %.1f m" % [p, box.end.y, PROP_HEIGHT_MAX])
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Light3D", "Camera3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [p, cls])
	assert_true(_aabb(_load_free(_path("ph_prop_mortsafe"))).end.y <= 1.1, "the grave cage <= 1.1 m")
	var decor := _aabb(_load_free(_path("ph_int_inn_fest_decor")))
	assert_true(decor.end.y <= 0.1, "the fest garland hangs below its nails (%s)" % decor)


func test_shared_materials_and_glow() -> void:
	var names: Array[String] = []
	for p: String in PROPS:
		names.append(p)
	for it: String in ITEMS:
		names.append("ph_item_" + it)
	for n: String in names:
		var mats := _materials(_load_free(_path(n)))
		for m: String in mats:
			assert_true(m.begins_with(MATERIAL_DIR) and m.ends_with(".tres"), "%s uses a shared material (%s)" % [n, m])
		assert_eq(EMISSIVE in mats, n in MAY_GLOW, "%s glows only if it is a lantern / candle" % n)
	assert_true(GROUND in _materials(_load_free(_path("ph_prop_grave_disturbed"))), "the thrown-up earth is ground")
	for c: String in FIGURES:
		var body := _materials(_rig(c).mesh_instance)
		assert_false(EMISSIVE in body, c + ": the body does not glow")
		for m: String in body:
			assert_true(m.begins_with(MATERIAL_DIR), "%s: shared material %s" % [c, m])


func test_no_red_except_hannes_band() -> void:
	# §8.4: no red except the little band on Hanne's kiepe; grief and earth stay muted
	for p: String in PROPS:
		if p in ["ph_prop_peddler_kiepe", "ph_chr_fiddler"]:   # the band; the fiddler's lips (lib_faces)
			continue
		var worst := 0.0
		for c: Color in _colours(_load_free(_path(p))):
			var s := c.linear_to_srgb()
			if (s.h < 0.04 or s.h > 0.95) and s.v > 0.2:
				worst = maxf(worst, s.s)
		assert_true(worst < 0.45, "%s has no red (saturation %.2f)" % [p, worst])


func test_disturbed_grave_shows_only_earth() -> void:
	var box := _aabb(_load_free(_path("ph_prop_grave_disturbed")))
	assert_true(box.position.y > -0.05, "no hole down into the grave (%.3f)" % box.position.y)


func test_archive_has_its_use_marker() -> void:
	var inst := _load_free(_path("ph_int_church_archive"))
	var m := inst.find_child("use", true, false) as Node3D
	assert_not_null(m, "archive: marker use")
	if m != null:
		assert_true(m.position.z > 0.5 and absf(m.position.y) < 0.01, "use in front of the doors (%s)" % m.position)


func test_fiddler_has_a_bow_arm_child() -> void:
	var inst := _load_free(_path("ph_chr_fiddler"))
	var bow := inst.find_child("bow", true, false) as MeshInstance3D
	assert_not_null(bow, "the bow arm is its own node")
	if bow != null:
		assert_true(bow.position.y > 0.8 and bow.position.y < 1.2, "its origin at the right shoulder (%s)" % bow.position)
		assert_true(bow.position.x < 0.0, "the right shoulder (-X)")
	assert_true(inst.find_children("*", "Skeleton3D", true, false).is_empty(), "the fiddler has no rig")


func test_items() -> void:
	for it: String in ITEMS:
		var path := MODEL_DIR + "items/ph_item_%s.glb" % it
		assert_true(ResourceLoader.exists(path), "missing " + path)
		if not ResourceLoader.exists(path):
			continue
		var inst := _load_free(path)
		var tris := _triangles(inst)
		assert_true(tris <= 800 and tris >= 40, "ph_item_%s: %d tris" % [it, tris])
		var box := _aabb(inst)
		assert_true(absf(box.position.y) <= 0.02, "ph_item_%s bottom at 0 (%.3f)" % [it, box.position.y])
		for axis: int in 3:
			if axis == 1:
				assert_true(box.size.y >= ITEM_MIN.y and box.size.y <= ITEM_MAX.y, "ph_item_%s height %.3f" % [it, box.size.y])
			else:
				assert_true(maxf(box.size.x, box.size.z) >= ITEM_MIN.x and box.size[axis] <= ITEM_MAX[axis],
						"ph_item_%s size %s" % [it, box.size])
	var src := FileAccess.get_file_as_string("res://tools/blender/asset_items.py")
	assert_true(src.contains("PHASE8_ITEMS"), "asset_items lists the Phase-8 items")


func test_sources_generators_and_determinism() -> void:
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		var src := FileAccess.get_file_as_string(script)
		assert_true(src.contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")
		assert_true(src.contains("_stable_glb") or src.contains("finish_stable") or src.contains("export_figure("),
				module + " exports deterministically")
	var names: Array[String] = []
	names.append_array(FIGURES.keys())
	for p: String in PROPS:
		names.append(p)
	for n: String in names:
		var cat := "characters" if n.begins_with("ph_chr_") else String(PROPS.get(n, ["props"])[0])
		var src := BLEND_DIR + cat + "/" + n + ".blend"
		assert_true(FileAccess.file_exists(src), "source " + src)
	var rig := FileAccess.get_file_as_string("res://tools/blender/rig.py")
	assert_true(rig.contains("def kneel(") and rig.contains("def folded("), "rig.py: the Phase-8 pose helpers")
	assert_true(rig.contains("BONES = (\"root\", \"hips\", \"spine\", \"head\", \"arm_l\", \"arm_r\", \"leg_l\", \"leg_r\")"),
			"rig.py: still the eight bones")


# --- helpers -------------------------------------------------------------------------------------------

func _check_clips(c: String, clips: Array) -> void:
	var r := _rig(c)
	for a: String in clips:
		var anim := r.animation(a)
		assert_not_null(anim, "%s: clip %s" % [c, a])
		if anim == null:
			continue
		var one := a in ONE_SHOTS
		assert_eq(anim.loop_mode == Animation.LOOP_NONE, one, "%s/%s: %s" % [c, a, "one-shot" if one else "loops"])
		assert_true(anim.length > 0.4 and anim.length < 3.2, "%s/%s length %.2f" % [c, a, anim.length])
		var root := r.skeleton.find_bone("root")
		for k: int in 5:
			assert_true(r.local_pose(anim, root, anim.length * k / 4.0).is_equal_approx(r.skeleton.get_bone_rest(root)),
					"%s/%s: root at rest" % [c, a])
		for b: String in BONES:
			var bi := r.skeleton.find_bone(b)
			var p0 := r.local_pose(anim, bi, 0.0)
			var p1 := r.local_pose(anim, bi, anim.length)
			var rest := r.skeleton.get_bone_rest(bi)
			if not one:
				assert_true(_close(p0, p1), "%s/%s seamless (%s)" % [c, a, b])
			else:
				if not a in STARTS_POSED:
					assert_true(_close(p0, rest), "%s/%s starts at rest (%s)" % [c, a, b])
				if not a in ENDS_POSED:
					assert_true(_close(p1, rest), "%s/%s ends at rest (%s)" % [c, a, b])


func _close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.003 and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) < 0.012


func _same_pose(r: Chars.Rig, a: Animation, ta: float, b: Animation, tb: float, what: String) -> void:
	for bone: String in BONES:
		var bi := r.skeleton.find_bone(bone)
		assert_true(_close(r.local_pose(a, bi, a.length * ta), r.local_pose(b, bi, b.length * tb)), "%s (%s)" % [what, bone])


func _clips(c: String) -> Array:
	var out: Array = []
	var r := _rig(c)
	if r.player == null:
		return out
	for n: StringName in r.player.get_animation_list():
		out.append(String(n))
	out.sort()
	return out


func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


func _child(r: Chars.Rig, child_name: String) -> MeshInstance3D:
	return r.scene.find_child(child_name, true, false) as MeshInstance3D


func _show_with(m: Node) -> PackedStringArray:
	if m == null or not m.has_meta("extras"):
		return PackedStringArray()
	var ex: Dictionary = m.get_meta("extras")
	return String(ex.get("show_with", "")).split(",", false)


func _rig(char_name: String) -> Chars.Rig:
	if not _rigs.has(char_name):
		_rigs[char_name] = Chars.Rig.new(MODEL_DIR + "characters/" + char_name + ".glb")
	return _rigs[char_name]


func _path(name: String) -> String:
	if name.begins_with("ph_item_"):
		return MODEL_DIR + "items/" + name + ".glb"
	return MODEL_DIR + String(PROPS[name][0]) + "/" + name + ".glb"


func _load_free(path: String) -> Node3D:
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	_to_free.append(inst)
	return inst


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _aabb(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes(inst):
		var b := _xf(mi, inst) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _mesh_tris(mesh: Mesh) -> int:
	var tris := 0
	for s: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _triangles(inst: Node) -> int:
	var tris := 0
	for mi: MeshInstance3D in _meshes(inst):
		tris += _mesh_tris(mi.mesh)
	return tris


func _materials(node: Node) -> Array[String]:
	var paths: Array[String] = []
	for mi: MeshInstance3D in _meshes(node):
		for s: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var p := mat.resource_path if mat != null else "<none>"
			if not p in paths:
				paths.append(p)
	return paths


func _colours(node: Node) -> PackedColorArray:
	var out: PackedColorArray = []
	for mi: MeshInstance3D in _meshes(node):
		for s: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_COLOR] != null:
				out.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	return out


## Body mesh fingerprint: every surface's arrays + material path (sha256, 16 hex digits).
static func _mesh_hash(mi: MeshInstance3D) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var mesh := mi.mesh
	for s: int in mesh.get_surface_count():
		ctx.update(var_to_bytes(mesh.surface_get_arrays(s)))
		var mat := mesh.surface_get_material(s)
		ctx.update((mat.resource_path if mat != null else "").to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 16)


## Clip fingerprint: length, loop mode, every track's path, type and keys.
static func _anim_hash(anim: Animation) -> String:
	if anim == null:
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes([anim.length, anim.loop_mode, anim.get_track_count()]))
	for i: int in anim.get_track_count():
		ctx.update(var_to_bytes([String(anim.track_get_path(i)), anim.track_get_type(i), anim.track_get_key_count(i)]))
		for k: int in anim.track_get_key_count(i):
			ctx.update(var_to_bytes([anim.track_get_key_time(i, k), anim.track_get_key_value(i, k)]))
	return ctx.finish().hex_encode().substr(0, 16)
