extends TestCase
## Phase 9 assets (P7, docs/PHASE9_DESIGN.md §8): Cornelius Brenneisen on the shared rig (9 bones, the case on
## `tool`), his clips and child meshes (glTF extras "show_with"), his face from lib_faces; Johann Sieber
## re-exported with the Phase-9 clips (body mesh and the Phase-8 clips unchanged: hashes taken from the Phase-8
## export b30c5b3); the props and the item models (icons).
## Sizes use Godot axes: x = width (the figure's left +X), y = height, z = depth (front = +Z).

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const P8 := preload("res://tests/unit/test_assets_phase8.gd")
const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const BONES: PackedStringArray = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const GENERATORS: Array[String] = ["asset_stranger", "asset_props_phase9"]

const STRANGER := "ph_chr_stranger"
const STRANGER_CLIPS: Array[String] = ["idle", "walk", "talk", "write_notebook", "tip_hat", "wait_gate", "sit_inn"]
const STRANGER_CHILDREN := {"hat_head": "head", "hat_hand": "root", "case": "tool", "notebook": "arm_l", "pencil": "arm_r"}
const STRANGER_TRIS := 9000
const STRANGER_HEIGHT := [1.72, 1.86]   # the body (the top hat is a child mesh)
## The clips in which the case stands on the ground beside him (asset_stranger.CASE_DOWN); in all others it
## hangs plumb from the left fist.
const CASE_DOWN: Array[String] = ["write_notebook", "wait_gate", "sit_inn"]
const CASE_TOP := 0.35                  # the handle's top above the ground when the case stands (0.3 + 0.05)
const WRITING: Array[String] = ["write_notebook", "sit_inn"]
const ONE_SHOTS: Array[String] = ["tip_hat", "show_mark", "slip_letter", "knock"]
## The inn bench and table (ph_int_inn_table): seat 0.46 m, the table top 0.795 m, its near edge 0.28 m in front
## of the seat marker, its far edge 1.08 m.
const TABLE_TOP := 0.795

const JOHANN := "ph_chr_mourner_m_b"
## The Phase-8 export (b30c5b3): body mesh hash and every Phase-8 clip (test_assets_phase8 _mesh_hash / _anim_hash).
const JOHANN_MESH := "52abf69adc5317a0"
const JOHANN_OLD := {"idle": "0bfcac4d56aed46b", "idle_low": "2815b000d94d2371", "lantern_idle": "bcc7bbb7903b167a",
		"lantern_walk": "48d8c515f75ca0b8", "mourn_stand": "fe7a4b162285ef0d", "talk": "9b9e6e69a8b73667",
		"walk": "538ff44ba216d02c"}
const JOHANN_NEW: Array[String] = ["sit_bench", "show_mark", "walk_bundle", "sit_cart"]
const JOHANN_CHILDREN := {"hat_head": "head", "hat_hand": "arm_r", "lantern_prop": "arm_r", "bundle": "arm_r", "bundle_down": "root"}
const JOHANN_TRIS := 7500

const GRAVEKEEPER := "ph_chr_gravekeeper"
## Every clip of the Phase-8 export (b30c5b3, _anim_hash); the body is P8.GRAVEKEEPER_MESH.
const GRAVEKEEPER_OLD := {"axe_draw": "7fc9a4578374ae03", "axe_stow": "725d1359418de125", "axe_stow_walk": "6d330b026169323a",
		"bench_work": "9df6667585633b37", "carry_idle": "3c2f250bc2155117", "carry_walk": "90a8dec736b457c4", "chisel": "895f5a28b255c5a3",
		"chop": "8823123bb5be0ae9", "corpse_lower": "907c1027ca7e7507", "dance": "e71b7d627fd68ff7", "dig": "3a6a9a17dd20d3bf",
		"dig_bare": "8ab9b2603cc158dd", "fill_can": "72ae1725613c785f", "hammer": "46e54dc47273c22f", "hammer_draw": "4d78248886390355",
		"hammer_stow": "7225cea5d9cae01c", "hammer_stow_walk": "8810cdb1f04bb880", "hand_draw": "c18ac82c807fad03",
		"hand_stow": "31728f5db2ecfced", "hand_stow_walk": "1c5615a466e6922a", "idle": "100c42b5645bb344", "interact": "fc90811cc405350a",
		"kneel_place": "dba2e412712c21d6", "mourn": "b4802a30aed0b5b5", "pick": "66b6ad53b649d468", "pick_draw": "49f7deaab8aa3a93",
		"pick_stow": "1e0b9dfa51c11ee5", "pick_stow_walk": "54c51909259347c9", "place_low": "c0b122da4c36c06e", "pray": "ec29b44ed3df16ed",
		"rake": "e436da95de30f6ef", "rake_put": "386d1d545e79e684", "rake_put_walk": "df61147ad46be323", "rake_take": "4e575f375501be51",
		"saw": "3082ece3caa49ae6", "saw_draw": "8348fca8a0c96f59", "saw_stow": "d0bec5711adc02b9", "saw_stow_walk": "b50ce6b1c4e68afc",
		"shovel_draw": "a26932b8e2b431f1", "shovel_stow": "1cf7741a42bdac7e", "shovel_stow_walk": "29ecc1d83ed0cd00",
		"sit_bench": "9563c4446cff6c99", "table_comb": "d7b61e0a29356492", "table_cut": "4429f076a9030098",
		"table_examine": "f1922543294ea127", "table_pull": "d0d96b7abd9cc920", "table_search": "a1b17f315721c61e",
		"table_shroud": "2d37052d2f407aa0", "table_smoke": "7041f64d0a6a46dd", "table_snip": "60664c1c2f3107fa",
		"table_wash": "dd84ba0e2c5a002f", "walk": "b49b9de1d36dcb95", "water": "6a415f062fa87d1d", "weed_pull": "5d2b1ce9a930619b",
		"write": "642ae7a550935952"}
const GRAVEKEEPER_NEW: Array[String] = ["read_book", "kneel_read", "write_letter", "read_letter", "read_aloud_grave",
		"burn_letter", "slip_letter", "knock", "take_soil", "carry_case"]
const HOLD_MARKERS := {"hold_r": "arm_r", "hold_l": "arm_l"}
## the gravekeeper's hand props (asset_character.HOLD_PROPS) -> triangle budget
const HAND_PROPS := {"ph_tool_letter": 200, "ph_tool_letter_open": 320, "ph_tool_kladde": 220, "ph_tool_quill": 60,
		"ph_tool_soil_cloth": 200, "ph_tool_case": 320}

## props: name -> [min size, max size, triangle budget (§8.4), markers]
const PROPS := {
	"ph_prop_letter": [Vector3(0.14, 0.005, 0.09), Vector3(0.18, 0.03, 0.12), 250, ["grip"]],
	"ph_prop_letter_open": [Vector3(0.14, 0.005, 0.22), Vector3(0.18, 0.03, 0.26), 350, ["grip"]],
	"ph_prop_case": [Vector3(0.1, 0.3, 0.38), Vector3(0.16, 0.4, 0.5), 450, ["grip"]],
	"ph_prop_notebook": [Vector3(0.18, 0.005, 0.1), Vector3(0.32, 0.05, 0.2), 200, []],
	"ph_prop_watch_lantern": [Vector3(0.18, 1.2, 0.18), Vector3(0.4, 1.4, 0.4), 450, ["light_lantern"]],
	"ph_prop_bundle": [Vector3(0.22, 0.18, 0.16), Vector3(0.36, 0.3, 0.28), 300, ["grip"]],
	"ph_prop_soil_pouch": [Vector3(0.09, 0.09, 0.09), Vector3(0.2, 0.17, 0.16), 250, ["grip"]],
}
const MAY_GLOW: Array[String] = ["ph_prop_watch_lantern"]
const PROP_HEIGHT_MAX := 1.4
const CASE_LONG_MAX := 0.5
## §8.4 icons: the item models (src/ui/tools/icon_renderer.gd renders them to assets/ui/icons/<id>.png).
const ITEMS: Array[String] = ["letter", "letter_reply", "nameless_letter", "stranger_case", "case_card", "soil_pouch",
		"straw_bouquet"]
const ITEM_MIN := Vector3(0.08, 0.002, 0.05)
const ITEM_MAX := Vector3(0.45, 0.35, 0.45)

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


# --- Brenneisen -------------------------------------------------------------------------------------------

func test_stranger_on_the_shared_rig() -> void:
	var r := _rig(STRANGER)
	assert_not_null(r.skeleton, "skeleton")
	assert_not_null(r.player, "AnimationPlayer")
	if r.skeleton == null:
		return
	assert_eq(r.skeleton.get_bone_count(), 9, "9 bones")
	for b: String in BONES:
		assert_true(r.skeleton.find_bone(b) >= 0, "bone " + b)
	var t := r.skeleton.find_bone("tool")
	assert_true(t >= 0 and r.skeleton.get_bone_name(r.skeleton.get_bone_parent(t)) == "spine", "tool on spine")
	assert_true(r.rigid_ok, "rigid skinning")
	assert_eq(r.player.autoplay, "", "no autoplay")


func test_stranger_budget_and_height() -> void:
	var r := _rig(STRANGER)
	var tris := 0
	for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
		tris += _mesh_tris((n as MeshInstance3D).mesh)
	assert_true(tris <= STRANGER_TRIS and tris >= 5000, "%d tris (<= %d, body + child meshes)" % [tris, STRANGER_TRIS])
	var box := AABB(r.verts[0], Vector3.ZERO)
	for v: Vector3 in r.verts:
		box = box.expand(v)
	assert_true(box.end.y >= STRANGER_HEIGHT[0] and box.end.y <= STRANGER_HEIGHT[1], "height %.2f" % box.end.y)
	assert_true(absf(box.position.y) < 0.012, "feet on the ground (%.3f)" % box.position.y)
	var hat := _aabb_of(_child(r, "hat_head"), r.scene)
	assert_true(hat.end.y > box.end.y + 0.12 and hat.end.y < 2.05, "a tall top hat (top %.2f)" % hat.end.y)
	var case_box := _aabb_of(_child(r, "case"), r.scene)
	assert_true(maxf(case_box.size.x, case_box.size.z) <= CASE_LONG_MAX, "the case <= 0.5 m (%s)" % case_box.size)


func test_stranger_clips_loops_and_one_shots() -> void:
	assert_eq(_clips(STRANGER), _sorted(STRANGER_CLIPS), "clip list")
	_check_clips(STRANGER, STRANGER_CLIPS)


func test_stranger_child_meshes_and_show_with() -> void:
	var r := _rig(STRANGER)
	_check_children(r, STRANGER, STRANGER_CHILDREN)
	var head := _show_with(_child(r, "hat_head"))
	var hand := _show_with(_child(r, "hat_hand"))
	assert_eq(Array(hand), ["sit_inn"], "the hat set down on the bench at the inn table")
	for c: String in STRANGER_CLIPS:
		assert_true((c in head) != (c in hand), "%s: exactly one hat" % c)
	assert_eq(_sorted(Array(_show_with(_child(r, "case")))), _sorted(STRANGER_CLIPS), "the case in every clip")
	for kid: String in ["notebook", "pencil"]:
		assert_eq(_sorted(Array(_show_with(_child(r, kid)))), _sorted(WRITING), kid + " only while he writes")
	var bench := _aabb_of(_child(r, "hat_hand"), r.scene)
	assert_true(absf(bench.position.y - 0.46) < 0.02 and bench.get_center().x > 0.3, "hat_hand on the bench beside him (%s)" % bench)


func test_stranger_face_from_lib_faces() -> void:
	var r := _rig(STRANGER)
	var f := r.scene.find_child("face", true, false) as Node3D
	assert_not_null(f, "face marker")
	if f != null:
		var att := f.get_parent() as BoneAttachment3D
		assert_true(att != null and att.bone_name == "head", "face marker on the head bone")
	var src := FileAccess.get_file_as_string("res://tools/blender/asset_stranger.py")
	assert_true(src.contains("from lib_faces import") and src.contains("_head(parts"), "the face is built by lib_faces._head")
	assert_false(src.contains("def _head("), "lib_faces is only used, not copied")


func test_case_hangs_from_the_left_fist_or_stands_beside_him() -> void:
	var r := _rig(STRANGER)
	var tool := r.skeleton.find_bone("tool")
	var rest := r.global_rest(tool)
	var case_box := _aabb_of(_child(r, "case"), r.scene)
	for c: String in STRANGER_CLIPS:
		var a := r.animation(c)
		for k: int in 4:
			var t := a.length * k / 4.0
			var xf := r.global_pose(a, tool, t)
			var turn := rad_to_deg(xf.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()))
			assert_true(turn < 1.5, "%s: the case stays upright (%.1f deg)" % [c, turn])
			var bottom := case_box.position.y + (xf.origin - rest.origin).y
			if c in CASE_DOWN:
				assert_true(absf(xf.origin.y - CASE_TOP) < 0.03, "%s: the case stands (handle %.3f)" % [c, xf.origin.y])
				assert_true(absf(bottom) < 0.02, "%s: on the ground (%.3f)" % [c, bottom])
				var off := Vector2(xf.origin.x, xf.origin.z).length()
				assert_true(off > 0.2 and off < 0.45, "%s: beside his feet (%.2f m)" % [c, off])
			else:
				var fist := r.hand(a, "arm_l", t) - r.hand(null, "arm_l", 0.0)
				assert_true((xf.origin - rest.origin).distance_to(fist) < 0.03, "%s: the case in the left fist" % c)
				assert_true(bottom > 0.25, "%s: carried clear of the ground (%.2f)" % [c, bottom])


func test_sit_inn_writes_on_the_table() -> void:
	var r := _rig(STRANGER)
	var a := r.animation(&"sit_inn")
	var drop := r.centroid(r.posed(null, "hips", 0.0)).y - r.centroid(r.posed(a, "hips", a.length * 0.3)).y
	assert_true(drop > 0.2 and drop < 0.36, "seated on the bench: the hips %.2f m lower" % drop)
	for k: int in 4:
		var t := a.length * k / 4.0
		for arm: String in ["arm_l", "arm_r"]:
			var h := r.hand(a, arm, t)
			assert_true(h.y > TABLE_TOP + 0.01 and h.y < TABLE_TOP + 0.14, "%s: %s on the table top (%.3f)" % [k, arm, h.y])
			assert_true(h.z > 0.32 and h.z < 0.75, "%s: %s over the table (%.2f m forward)" % [k, arm, h.z])
		for leg: String in ["leg_l", "leg_r"]:
			assert_true(r.lowest_y(r.posed(a, leg, t)) > -0.03, "%s above the floor" % leg)
	var nb := _aabb_posed(r, "notebook", a, a.length * 0.25)
	assert_true(nb.position.y > TABLE_TOP - 0.02 and nb.position.y < TABLE_TOP + 0.06, "the notebook lies on the table (%.3f)" % nb.position.y)


func test_write_notebook_and_wait_gate_and_tip_hat() -> void:
	var r := _rig(STRANGER)
	var w := r.animation(&"write_notebook")
	for arm: String in ["arm_l", "arm_r"]:
		var h := r.hand(w, arm, w.length * 0.3)
		assert_true(h.y > 1.0 and h.y < 1.35 and h.z > 0.3, "write_notebook: %s in front of the chest (%s)" % [arm, h])
	var g := r.animation(&"wait_gate")
	for k: int in 3:
		var t := g.length * k / 3.0
		var l := r.hand(g, "arm_l", t)
		var rr := r.hand(g, "arm_r", t)
		assert_true(l.z < -0.08 and rr.z < -0.08, "wait_gate: the hands behind his back (%s, %s)" % [l, rr])
		assert_true(l.distance_to(rr) < 0.25, "wait_gate: the hands together (%.2f)" % l.distance_to(rr))
	var tip := r.animation(&"tip_hat")
	var hand := r.hand(tip, "arm_r", tip.length * 0.5)
	var head := r.centroid(r.posed(tip, "head", tip.length * 0.5))
	assert_true(hand.y > head.y and hand.distance_to(head) < 0.45, "tip_hat: the hand up at the hat (%s, head %s)" % [hand, head])


# --- Johann's re-export ----------------------------------------------------------------------------------

func test_johann_reexport_keeps_body_and_old_clips() -> void:
	var r := _rig(JOHANN)
	assert_eq(P8._mesh_hash(r.mesh_instance), JOHANN_MESH, "Johann's body mesh unchanged")
	for clip: String in JOHANN_OLD:
		assert_eq(P8._anim_hash(r.animation(clip)), String(JOHANN_OLD[clip]), "Johann/%s unchanged" % clip)
	var want: Array = JOHANN_OLD.keys()
	want.append_array(JOHANN_NEW)
	assert_eq(_clips(JOHANN), _sorted(want), "Phase-8 clips + the Phase-9 clips")
	_check_clips(JOHANN, JOHANN_NEW)
	_check_children(r, JOHANN, JOHANN_CHILDREN)
	var tris := 0
	for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
		tris += _mesh_tris((n as MeshInstance3D).mesh)
	assert_true(tris <= JOHANN_TRIS, "Johann %d tris (<= %d)" % [tris, JOHANN_TRIS])
	var head := _show_with(_child(r, "hat_head"))
	for c: String in JOHANN_NEW:
		assert_has(head, c, "Johann keeps his hat on in " + c)
	assert_eq(Array(_show_with(_child(r, "bundle"))), ["walk_bundle"], "the bundle in his hand when he leaves")
	assert_eq(Array(_show_with(_child(r, "bundle_down"))), ["sit_cart"], "the bundle beside him on the cart")


func test_johann_sits_with_the_stick_planted() -> void:
	var r := _rig(JOHANN)
	for c: String in ["sit_bench", "sit_cart"]:
		var a := r.animation(c)
		var drop := r.centroid(r.posed(null, "hips", 0.0)).y - r.centroid(r.posed(a, "hips", a.length * 0.3)).y
		assert_true(drop > 0.2 and drop < 0.36, "%s: seated, the hips %.2f m lower" % [c, drop])
		for k: int in 4:
			var t := a.length * k / 4.0
			var tip := r.lowest_y(r.posed(a, "arm_l", t))
			assert_true(tip > -0.03 and tip < 0.08, "%s: the stick's tip on the ground (%.3f)" % [c, tip])
			for leg: String in ["leg_l", "leg_r"]:
				assert_true(r.lowest_y(r.posed(a, leg, t)) > -0.03, "%s/%s above the ground" % [c, leg])
	var down := _aabb_of(_child(r, "bundle_down"), r.scene)
	assert_true(down.position.y > 0.4 and down.position.y < 0.52 and down.position.x < -0.3, "the bundle beside him on the bed (%s)" % down)
	var w := r.animation(&"walk_bundle")
	for k: int in 4:
		var t := w.length * k / 4.0
		var b := _aabb_posed(r, "bundle", w, t)
		assert_true(b.position.y > 0.3, "walk_bundle: the bundle carried (%.2f)" % b.position.y)
		assert_true(b.end.x < -0.17, "walk_bundle: the bundle clears the coat (%.2f)" % b.end.x)
	var s := r.animation(&"show_mark")
	var rest_head := r.centroid(r.posed(null, "head", 0.0))
	var hd := r.centroid(r.posed(s, "head", s.length * 0.5))
	assert_true(hd.distance_to(rest_head) > 0.03, "show_mark: he looks down and away")
	var hand := r.hand(s, "arm_r", s.length * 0.5)
	assert_true(hand.x < r.hand(null, "arm_r", 0.0).x - 0.08, "show_mark: the hand draws the coat open to the side")


# --- the gravekeeper ---------------------------------------------------------------------------------------

func test_gravekeeper_keeps_body_and_every_older_clip() -> void:
	var r := _rig(GRAVEKEEPER)
	assert_eq(P8._mesh_hash(r.mesh_instance), P8.GRAVEKEEPER_MESH, "gravekeeper body unchanged")
	for clip: String in GRAVEKEEPER_OLD:
		assert_eq(P8._anim_hash(r.animation(clip)), String(GRAVEKEEPER_OLD[clip]), "gravekeeper/%s unchanged" % clip)
	var want: Array = GRAVEKEEPER_OLD.keys()
	want.append_array(GRAVEKEEPER_NEW)
	assert_eq(_clips(GRAVEKEEPER), _sorted(want), "the older clips + the Phase-9 clips")
	_check_clips(GRAVEKEEPER, GRAVEKEEPER_NEW)


func test_gravekeeper_new_clips_leave_the_shovel_on_the_back() -> void:
	var r := _rig(GRAVEKEEPER)
	var tool := r.skeleton.find_bone("tool")
	var rest := r.skeleton.get_bone_rest(tool)
	for c: String in GRAVEKEEPER_NEW:
		var a := r.animation(c)
		for k: int in 4:
			assert_true(_close(r.local_pose(a, tool, a.length * k / 3.0), rest), "%s: the shovel stays on the back" % c)
	for m: String in HOLD_MARKERS:
		var n := r.scene.find_child(m, true, false) as Node3D
		assert_not_null(n, "marker " + m)
		if n != null:
			var att := n.get_parent() as BoneAttachment3D
			assert_true(att != null and att.bone_name == HOLD_MARKERS[m], "%s on %s" % [m, HOLD_MARKERS[m]])
			var fist := r.hand(null, HOLD_MARKERS[m], 0.0)
			assert_true(_xf(n, r.scene).origin.distance_to(fist) < 0.06, "%s at the fist (%s / %s)" % [m, _xf(n, r.scene).origin, fist])


func test_gravekeeper_phase9_poses() -> void:
	var r := _rig(GRAVEKEEPER)
	var rest_hips := r.centroid(r.posed(null, "hips", 0.0)).y
	for c: String in ["kneel_read", "read_aloud_grave", "take_soil"]:
		var a := r.animation(c)
		var drop := rest_hips - r.centroid(r.posed(a, "hips", a.length * 0.5)).y
		assert_true(drop > 0.2 and drop < 0.4, "%s: kneeling (the hips %.2f m lower)" % [c, drop])
		for leg: String in ["leg_l", "leg_r"]:
			assert_true(r.lowest_y(r.posed(a, leg, a.length * 0.5)) > -0.03, "%s/%s above the ground" % [c, leg])
	var rl := r.animation(&"read_letter")
	var lr := r.hand(rl, "arm_r", 0.0)
	var ll := r.hand(rl, "arm_l", 0.0)
	assert_true(lr.y > 0.95 and ll.y > 0.95 and lr.z > 0.3 and ll.z > 0.3, "read_letter: the letter in front of the chest (%s, %s)" % [lr, ll])
	assert_true(lr.distance_to(ll) > 0.12 and lr.distance_to(ll) < 0.3, "read_letter: held between both hands (%.2f)" % lr.distance_to(ll))
	for c: String in ["read_book", "write_letter"]:
		var a := r.animation(c)
		var h := r.hand(a, "arm_l", 0.0)
		assert_true(h.y > 0.74 and h.y < 0.92 and h.z > 0.3, "%s: the left hand on the desk (%s)" % [c, h])
	var sl := r.animation(&"slip_letter")
	var at := r.hand(sl, "arm_r", sl.length * 0.6)
	assert_true(at.y > 0.85 and at.y < 1.15 and at.z > 0.35, "slip_letter: the hand at the door's gap (%s)" % at)
	var kn := r.animation(&"knock")
	assert_true(r.hand(kn, "arm_r", kn.length * 0.42).y > 1.0, "knock: the hand up at the door")
	var ts := r.animation(&"take_soil")
	assert_true(r.hand(ts, "arm_r", ts.length * 0.3).y < 0.45, "take_soil: the right hand down at the mound")
	var bl := r.animation(&"burn_letter")
	var b := r.hand(bl, "arm_r", 0.0)
	assert_true(b.z > 0.35 and b.y < 0.9, "burn_letter: the hand forward into the stove (%s)" % b)


func test_gravekeeper_hand_props() -> void:
	for p: String in HAND_PROPS:
		var path := MODEL_DIR + "props/" + p + ".glb"
		assert_true(ResourceLoader.exists(path), "missing " + path)
		if not ResourceLoader.exists(path):
			continue
		var inst := _load_free(path)
		var tris := _triangles(inst)
		assert_true(tris <= int(HAND_PROPS[p]) and tris >= 20, "%s: %d tris (<= %d)" % [p, tris, HAND_PROPS[p]])
		var box := _aabb(inst)
		assert_true(box.grow(0.03).has_point(Vector3.ZERO), "%s: held at its origin (the fist) %s" % [p, box])
		for m: String in _materials(inst):
			assert_true(m.begins_with(MATERIAL_DIR), "%s: shared material %s" % [p, m])
	# the case hangs below the fist and stays clear of the ground while he walks
	var r := _rig(GRAVEKEEPER)
	var cc := r.animation(&"carry_case")
	var case_box := _aabb(_load_free(MODEL_DIR + "props/ph_tool_case.glb"))
	for k: int in 4:
		var t := cc.length * k / 4.0
		var fist := r.hand(cc, "arm_r", t)
		assert_true(fist.y + case_box.position.y > 0.15, "carry_case: the case off the ground (%.2f)" % (fist.y + case_box.position.y))
	var src := FileAccess.get_file_as_string("res://tools/blender/asset_character.py")
	for p: String in HAND_PROPS:
		assert_true(src.contains("\"%s\"" % p), "%s is named in asset_character.HOLD_PROPS" % p)


# --- props and items -------------------------------------------------------------------------------------

func test_props_exist_with_budgets_sizes_and_markers() -> void:
	for p: String in PROPS:
		var path := MODEL_DIR + "props/" + p + ".glb"
		assert_true(ResourceLoader.exists(path), "missing " + path)
		if not ResourceLoader.exists(path):
			continue
		var inst := _load_free(path)
		var tris := _triangles(inst)
		assert_true(tris <= int(PROPS[p][2]) and tris >= 40, "%s: %d tris (<= %d)" % [p, tris, PROPS[p][2]])
		var box := _aabb(inst)
		var lo: Vector3 = PROPS[p][0]
		var hi: Vector3 = PROPS[p][1]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis], "%s size %s outside %s..%s" % [p, box.size, lo, hi])
		assert_true(absf(box.position.y) <= 0.01, "%s rests on the ground (%.3f)" % [p, box.position.y])
		assert_true(box.end.y <= PROP_HEIGHT_MAX, "%s: %.2f m <= %.1f m" % [p, box.end.y, PROP_HEIGHT_MAX])
		for m: String in PROPS[p][3]:
			var mk := inst.find_child(m, true, false) as Node3D
			assert_not_null(mk, "%s: marker %s" % [p, m])
			if mk != null:
				assert_true(box.grow(0.02).has_point(_xf(mk, inst).origin), "%s: %s inside the model" % [p, m])
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Light3D", "Camera3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [p, cls])
	var lan := _load_free(MODEL_DIR + "props/ph_prop_watch_lantern.glb")
	var light := _xf(lan.find_child("light_lantern", true, false) as Node3D, lan).origin
	assert_true(light.y > 0.8 and light.y < 1.3, "the lantern hangs at the staff's hook (light %.2f m)" % light.y)


func test_shared_materials_and_glow() -> void:
	var names: Array[String] = []
	for p: String in PROPS:
		names.append("props/" + p)
	for it: String in ITEMS:
		names.append("items/ph_item_" + it)
	for n: String in names:
		var mats := _materials(_load_free(MODEL_DIR + n + ".glb"))
		for m: String in mats:
			assert_true(m.begins_with(MATERIAL_DIR) and m.ends_with(".tres"), "%s uses a shared material (%s)" % [n, m])
		assert_eq(EMISSIVE in mats, n.get_file() in MAY_GLOW, "%s glows only if it is the watchman's lantern" % n)
	for c: String in [STRANGER, JOHANN]:
		var r := _rig(c)
		for m: String in _materials(r.mesh_instance):
			assert_true(m.begins_with(MATERIAL_DIR), "%s: shared material %s" % [c, m])
		for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
			if n.name != "lantern_prop":
				assert_false(EMISSIVE in _materials(n), "%s/%s does not glow" % [c, n.name])


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
		assert_true(box.size.y >= ITEM_MIN.y and box.size.y <= ITEM_MAX.y, "ph_item_%s height %.3f" % [it, box.size.y])
		assert_true(maxf(box.size.x, box.size.z) >= ITEM_MIN.x and box.size.x <= ITEM_MAX.x and box.size.z <= ITEM_MAX.z,
				"ph_item_%s size %s" % [it, box.size])
	var src := FileAccess.get_file_as_string("res://tools/blender/asset_items.py")
	assert_true(src.contains("PHASE9_ITEMS"), "asset_items lists the Phase-9 items")


func test_no_index_array_shared_between_meshes() -> void:
	# glTF exporters share equal index arrays between meshes; lib_faces._stable_glb reorders each mesh's
	# vertices and would then rewrite a shared array twice (G9 P7: the stranger's two hats came out torn).
	var paths: Array[String] = [MODEL_DIR + "characters/%s.glb" % STRANGER, MODEL_DIR + "characters/%s.glb" % JOHANN]
	for p: String in PROPS:
		paths.append(MODEL_DIR + "props/" + p + ".glb")
	for it: String in ITEMS:
		paths.append(MODEL_DIR + "items/ph_item_%s.glb" % it)
	for path: String in paths:
		var doc := _gltf_json(path)
		var seen := {}
		for m: Variant in doc.get("meshes", []):
			for prim: Variant in (m as Dictionary).get("primitives", []):
				var idx: Variant = (prim as Dictionary).get("indices")
				if idx == null:
					continue
				assert_false(seen.has(int(idx)), "%s: index accessor %d shared (%s, %s)" % [path.get_file(), int(idx),
						seen.get(int(idx), ""), m.get("name", "")])
				seen[int(idx)] = m.get("name", "")


func test_sources_generators_and_determinism() -> void:
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		var src := FileAccess.get_file_as_string(script)
		assert_true(src.contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")
		assert_true(src.contains("finish_stable") or src.contains("export_figure("), module + " exports deterministically")
	assert_true(FileAccess.file_exists(BLEND_DIR + "characters/%s.blend" % STRANGER), "source of the stranger")
	for p: String in PROPS:
		assert_true(FileAccess.file_exists(BLEND_DIR + "props/" + p + ".blend"), "source " + p)
	var rig := FileAccess.get_file_as_string("res://tools/blender/rig.py")
	assert_true(rig.contains("def deform(") and rig.contains("def seated(") and rig.contains("def behind_back("),
			"rig.py: the Phase-9 pose helpers")
	assert_true(rig.contains("BONES = (\"root\", \"hips\", \"spine\", \"head\", \"arm_l\", \"arm_r\", \"leg_l\", \"leg_r\")"),
			"rig.py: still the eight bones")


func test_placeholders_listed() -> void:
	var doc := FileAccess.get_file_as_string("res://docs/QUALITY_GATE_STATUS.md")
	var names: Array[String] = [STRANGER]
	names.append_array(PROPS.keys())
	for it: String in ITEMS:
		names.append("ph_item_" + it)
	for n: String in names:
		assert_true(doc.contains(n), n + " is in the placeholder list")


# --- helpers ---------------------------------------------------------------------------------------------

func _check_children(r: Chars.Rig, c: String, kids: Dictionary) -> void:
	var clips := _clips(c)
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
	var found := 0
	for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
		if n != r.mesh_instance:
			found += 1
	assert_eq(found, kids.size(), c + ": child mesh count")


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
		var names: Array[String] = []
		names.append_array(BONES)
		if r.skeleton.find_bone("tool") >= 0:
			names.append("tool")
		for b: String in names:
			var bi := r.skeleton.find_bone(b)
			var p0 := r.local_pose(anim, bi, 0.0)
			var p1 := r.local_pose(anim, bi, anim.length)
			var rest := r.skeleton.get_bone_rest(bi)
			if not one:
				assert_true(_close(p0, p1), "%s/%s seamless (%s)" % [c, a, b])
			else:
				assert_true(_close(p0, rest), "%s/%s starts at rest (%s)" % [c, a, b])
				assert_true(_close(p1, rest), "%s/%s ends at rest (%s)" % [c, a, b])


func _close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.003 and a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()) < 0.012


## AABB of a child mesh in the figure's space while `anim` plays at t (it rides on its bone).
func _aabb_posed(r: Chars.Rig, kid: String, anim: Animation, t: float) -> AABB:
	var m := _child(r, kid)
	var att := m.get_parent() as BoneAttachment3D
	var bi := r.skeleton.find_bone(att.bone_name)
	var xf := r.global_pose(anim, bi, t) * r.global_rest(bi).affine_inverse() * _xf(m, r.scene)
	var box := AABB()
	var first := true
	for s: int in m.mesh.get_surface_count():
		for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var p := xf * v
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


func _aabb_of(m: MeshInstance3D, root: Node) -> AABB:
	return _xf(m, root) * m.get_aabb()


func _gltf_json(path: String) -> Dictionary:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.READ)
	if f == null:
		fail("cannot read " + path)
		return {}
	f.seek(12)
	var jlen := f.get_32()
	f.seek(20)
	var js := f.get_buffer(jlen).get_string_from_utf8()
	return JSON.parse_string(js) as Dictionary


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


func _xf(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
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
