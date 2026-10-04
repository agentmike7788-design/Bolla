extends TestCase
## M6a: rigged characters (docs/VERTICAL_SLICE_DESIGN.md §8, docs/ASSET_GUIDELINES.md).
## Poses are evaluated offline from the imported Animation tracks + Skin binds
## (same maths as Godot's skinning), so no rendering or real-time playback is needed.

const DIR := "res://assets/models/characters/"
const MATERIAL_DIR := "res://assets/materials/"
const BONES: PackedStringArray = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const PARENTS := {"root": "", "hips": "root", "spine": "hips", "head": "spine", "arm_l": "spine",
		"arm_r": "spine", "leg_l": "hips", "leg_r": "hips"}
const TRI_MAX := 12000  # ASSET_GUIDELINES: Charakter 5 000 – 12 000 (upper bound enforced, see known issues)
const TRI_MIN := 1500   # sanity: a real character, not a stub
## name -> height range (m), animation -> allowed length range (s), one-shot animations
const CHARACTERS := {
	"ph_chr_gravekeeper": {
		"height": [1.72, 1.88],
		"animations": {"idle": [1.6, 2.6], "walk": [0.4, 0.8], "carry_idle": [1.6, 2.6], "carry_walk": [0.5, 1.0],
				"dig": [1.0, 1.4], "dig_bare": [1.0, 1.4], "interact": [0.6, 1.0],
				"shovel_draw": [0.4, 0.6], "shovel_stow": [0.35, 0.5], "shovel_stow_walk": [0.45, 0.6]},
		"one_shot": ["interact", "shovel_draw", "shovel_stow", "shovel_stow_walk"],
	},
	"ph_chr_carter": {
		"height": [1.6, 1.7],
		"animations": {"idle": [1.6, 3.0], "walk": [0.4, 0.9], "push_cart": [0.5, 1.0], "talk": [1.6, 3.0]},
		"one_shot": [],
	},
	# Phase 4 (docs/PHASE4_DESIGN.md §8): Ilse Kranich, the night trader
	"ph_chr_kranich": {
		"height": [1.78, 1.86],
		"animations": {"idle": [1.6, 3.0], "walk": [0.6, 1.0], "talk": [1.6, 3.0], "offer": [0.8, 1.2]},
		"one_shot": ["offer"],
	},
}
const KRANICH_TRI_MAX := 9000
## G7 Runde 2: additive non-deforming bones (name -> parent) - the gravekeeper's shovel bone.
const EXTRA_BONES := {"ph_chr_gravekeeper": {"tool": "spine"}}
## Rest-model points of the shovel on the tool bone (Godot axes): the shaft ends at the D-grip and
## at the blade socket (tools/blender/asset_character.py SHOVEL_G0 / SHOVEL_G1).
const SHOVEL_G0 := Vector3(0.25, 0.49, -0.2)
const SHOVEL_G1 := Vector3(-0.34, 1.3, -0.31)  # PHASE4_DESIGN §8 budget (stricter than TRI_MAX)


## Offline pose evaluator for one imported character.
class Rig:
	var scene: Node
	var skeleton: Skeleton3D
	var player: AnimationPlayer
	var mesh_instance: MeshInstance3D
	var skin: Skin
	var verts: PackedVector3Array = []
	var vert_bone: PackedInt32Array = []   # skeleton bone index per vertex (rigid)
	var bind_bone: PackedInt32Array = []   # skin bind index -> skeleton bone index
	var bone_bind: Dictionary = {}         # skeleton bone index -> skin bind index
	var rigid_ok: bool = true

	func _init(path: String) -> void:
		scene = (load(path) as PackedScene).instantiate()
		skeleton = scene.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
		player = scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if skeleton == null:
			return
		for n: Node in skeleton.get_children():
			if n is MeshInstance3D:
				mesh_instance = n as MeshInstance3D
		if mesh_instance == null:
			return
		skin = mesh_instance.skin
		if skin == null:
			return
		for b: int in skin.get_bind_count():
			var bname := skin.get_bind_name(b)
			bind_bone.append(skeleton.find_bone(bname) if bname != "" else skin.get_bind_bone(b))
			bone_bind[bind_bone[b]] = b
		var mesh := mesh_instance.mesh
		for s: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := 8 if mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
			for i: int in pos.size():
				var bone := -1
				var used := 0
				for k: int in stride:
					var w := weights[i * stride + k]
					if w > 0.001:
						used += 1
						bone = bind_bone[bones[i * stride + k]]
						if absf(w - 1.0) > 0.001:
							rigid_ok = false
				if used != 1:
					rigid_ok = false
				verts.append(pos[i])
				vert_bone.append(bone)

	func free_scene() -> void:
		scene.free()

	func animation(anim_name: StringName) -> Animation:
		return player.get_animation(anim_name) if player and player.has_animation(anim_name) else null

	## Local bone transform at time t (missing track = rest, like the deterministic mixer).
	func local_pose(anim: Animation, bone: int, t: float) -> Transform3D:
		var rest := skeleton.get_bone_rest(bone)
		if anim == null:
			return rest
		var path := NodePath("Armature/Skeleton3D:" + skeleton.get_bone_name(bone))
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var pt := anim.find_track(path, Animation.TYPE_POSITION_3D)
		if pt >= 0:
			pos = anim.position_track_interpolate(pt, t)
		var rt := anim.find_track(path, Animation.TYPE_ROTATION_3D)
		if rt >= 0:
			rot = anim.rotation_track_interpolate(rt, t)
		return Transform3D(Basis(rot), pos)

	func global_pose(anim: Animation, bone: int, t: float) -> Transform3D:
		var xf := local_pose(anim, bone, t)
		var p := skeleton.get_bone_parent(bone)
		while p >= 0:
			xf = local_pose(anim, p, t) * xf
			p = skeleton.get_bone_parent(p)
		return xf

	func global_rest(bone: int) -> Transform3D:
		return global_pose(null, bone, 0.0)

	## Skinning matrix of a bone: skeleton-space pose * skin bind pose (as Godot skins).
	func deform(anim: Animation, bone: int, t: float) -> Transform3D:
		return global_pose(anim, bone, t) * skin.get_bind_pose(bone_bind[bone])

	## Skinned positions of all vertices bound to `bone_name` at time t (anim null = rest).
	func posed(anim: Animation, bone_name: String, t: float) -> PackedVector3Array:
		var bone := skeleton.find_bone(bone_name)
		var m := deform(anim, bone, t)
		var out: PackedVector3Array = []
		for i: int in verts.size():
			if vert_bone[i] == bone:
				out.append(m * verts[i])
		return out

	func lowest_y(points: PackedVector3Array) -> float:
		var y := INF
		for p: Vector3 in points:
			y = minf(y, p.y)
		return y

	func centroid(points: PackedVector3Array) -> Vector3:
		var c := Vector3.ZERO
		for p: Vector3 in points:
			c += p
		return c / maxf(1.0, points.size())

	## The lowest 25 cm of a leg (boot) – for ground contact and stride checks.
	func boot(anim: Animation, leg: String, t: float) -> PackedVector3Array:
		var rest := posed(null, leg, 0.0)
		var cut := lowest_y(rest) + 0.25
		var all := posed(anim, leg, t)
		var out: PackedVector3Array = []
		for i: int in rest.size():
			if rest[i].y < cut:
				out.append(all[i])
		return out

	func hand(anim: Animation, arm: String, t: float) -> Vector3:
		var pts := posed(anim, arm, t)
		var rest := posed(null, arm, 0.0)
		# the hand = the arm's lowest rest vertices (below the cuff)
		var cut := lowest_y(rest) + 0.08
		var sel: PackedVector3Array = []
		for i: int in rest.size():
			if rest[i].y < cut:
				sel.append(pts[i])
		return centroid(sel)


var _rigs: Dictionary = {}


func after_each() -> void:
	for r: Rig in _rigs.values():
		r.free_scene()
	_rigs.clear()


func _rig(char_name: String) -> Rig:
	if not _rigs.has(char_name):
		_rigs[char_name] = Rig.new(DIR + char_name + ".glb")
	return _rigs[char_name]


func _bones(c: String) -> PackedStringArray:
	var out := BONES.duplicate()
	for b: String in EXTRA_BONES.get(c, {}):
		out.append(b)
	return out


func _tris(mesh: Mesh) -> int:
	var tris := 0
	for s: int in mesh.get_surface_count():
		var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3 if idx.size() > 0 else (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _rest_aabb(r: Rig) -> AABB:
	var box := AABB(r.verts[0], Vector3.ZERO)
	for v: Vector3 in r.verts:
		box = box.expand(v)
	return box


# --- structure --------------------------------------------------------------------

func test_models_exist_and_load() -> void:
	for c: String in CHARACTERS:
		assert_true(ResourceLoader.exists(DIR + c + ".glb"), c + ".glb exists")
		assert_true(load(DIR + c + ".glb") is PackedScene, c + " imports as scene")


func test_scene_structure() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		assert_not_null(r.player, c + ": <glb>/AnimationPlayer")
		assert_not_null(r.skeleton, c + ": <glb>/Armature/Skeleton3D")
		assert_not_null(r.mesh_instance, c + ": skinned mesh below the skeleton")
		assert_not_null(r.skin, c + ": mesh has a skin")
		if r.mesh_instance:
			assert_eq(r.mesh_instance.get_node_or_null(r.mesh_instance.skeleton), r.skeleton, c + ": mesh bound to skeleton")
		assert_eq(r.player.autoplay if r.player else "x", "", c + ": no autoplay (the owner picks the animation)")


func test_skeleton_has_the_eight_bones_and_hierarchy() -> void:
	for c: String in CHARACTERS:
		var sk := _rig(c).skeleton
		if sk == null:
			fail(c + ": no skeleton")
			continue
		var extra: Dictionary = EXTRA_BONES.get(c, {})
		assert_eq(sk.get_bone_count(), BONES.size() + extra.size(), c + ": bone count")
		for b: String in extra:
			var e := sk.find_bone(b)
			assert_true(e >= 0 and sk.get_bone_name(sk.get_bone_parent(e)) == extra[b], "%s: extra bone %s on %s" % [c, b, extra[b]])
		for b: String in BONES:
			var idx := sk.find_bone(b)
			assert_true(idx >= 0, "%s: bone %s" % [c, b])
			if idx < 0:
				continue
			var p := sk.get_bone_parent(idx)
			assert_eq(sk.get_bone_name(p) if p >= 0 else "", PARENTS[b], "%s: parent of %s" % [c, b])


func test_skin_binds_all_bones() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		assert_eq(r.bind_bone.size(), BONES.size() + (EXTRA_BONES.get(c, {}) as Dictionary).size(), c + ": skin binds")
		assert_false(-1 in r.bind_bone, c + ": every bind resolves to a skeleton bone")


# --- skinning -----------------------------------------------------------------------

func test_rigid_skinning() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		assert_true(r.verts.size() > 0, c + ": has vertices")
		assert_true(r.rigid_ok, c + ": every vertex 100 % on exactly one bone")
		var used := {}
		for b: int in r.vert_bone:
			used[r.skeleton.get_bone_name(b)] = true
		for b: String in BONES:
			if b == "root":
				assert_false(used.has(b), c + ": root carries no geometry")
			else:
				assert_true(used.has(b), "%s: bone %s carries geometry" % [c, b])


func test_rest_pose_is_the_modelled_pose() -> void:
	# ART STYLE LOCK: without animation the skinned mesh must look exactly like the approved model
	for c: String in CHARACTERS:
		var r := _rig(c)
		for b: String in BONES:
			if r.skin == null:
				break
			var bi := r.skeleton.find_bone(b)
			assert_true(r.deform(null, bi, 0.0).is_equal_approx(Transform3D.IDENTITY), "%s: %s bind == rest" % [c, b])


func test_body_parts_on_sensible_bones() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var top := 0
		var bottom := 0
		for i: int in r.verts.size():
			if r.verts[i].y > r.verts[top].y:
				top = i
			if r.verts[i].y < r.verts[bottom].y:
				bottom = i
		assert_eq(r.skeleton.get_bone_name(r.vert_bone[top]), "head", c + ": hat/cap on the head bone")
		assert_has(["leg_l", "leg_r"], r.skeleton.get_bone_name(r.vert_bone[bottom]), c + ": boots on the legs")
		# _l = the character's left = +X (model faces +Z)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			assert_true(r.centroid(r.posed(null, "leg_" + side, 0.0)).x * sign > 0.05, "%s: leg_%s on its side" % [c, side])
			assert_true(r.centroid(r.posed(null, "arm_" + side, 0.0)).x * sign > 0.15, "%s: arm_%s on its side" % [c, side])
		var head := r.centroid(r.posed(null, "head", 0.0))
		var spine := r.centroid(r.posed(null, "spine", 0.0))
		var hips := r.centroid(r.posed(null, "hips", 0.0))
		assert_true(head.y > spine.y and spine.y > hips.y, c + ": head above spine above hips")


func test_lantern_marker_follows_hips() -> void:
	var r := _rig("ph_chr_gravekeeper")
	var marker := r.scene.find_child("light_lantern", true, false) as Node3D
	assert_not_null(marker, "light_lantern marker kept (prototype light layout)")
	if marker == null:
		return
	var att := marker.get_parent() as BoneAttachment3D
	assert_not_null(att, "marker sits on a BoneAttachment3D")
	if att:
		assert_eq(att.bone_name, "hips", "lantern follows the hips")
	var xf := Transform3D.IDENTITY
	var n: Node = marker
	while n != r.scene:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	# approved Phase-1 position (player_proto.tscn Light_lantern)
	assert_true(xf.origin.distance_to(Vector3(0.31, 0.727772, 0.097)) < 0.005, "lantern at %s" % xf.origin)


# --- materials, scale, budget -----------------------------------------------------

func test_all_surfaces_use_shared_materials() -> void:
	for c: String in CHARACTERS:
		var scene := (load(DIR + c + ".glb") as PackedScene).instantiate()
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() > 0, c + ": has meshes")
		for n: Node in meshes:
			var mesh := (n as MeshInstance3D).mesh
			for i: int in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				assert_true(mat != null and mat.resource_path.begins_with(MATERIAL_DIR) and mat.resource_path.ends_with(".tres"),
						"%s surface %d: %s" % [c, i, mat.resource_path if mat else "null"])
		scene.free()


func test_height_pivot_and_silhouette_contrast() -> void:
	var heights := {}
	for c: String in CHARACTERS:
		var box := _rest_aabb(_rig(c))
		var range_h: Array = CHARACTERS[c].height
		heights[c] = box.size.y
		assert_true(box.size.y >= range_h[0] and box.size.y <= range_h[1], "%s height %.3f m" % [c, box.size.y])
		assert_almost(box.position.y, 0.0, 0.01, c + ": feet on the ground (pivot)")
		var r := _rig(c)
		var feet := (r.centroid(r.boot(null, "leg_l", 0.0)) + r.centroid(r.boot(null, "leg_r", 0.0))) * 0.5
		assert_almost(feet.x, 0.0, 0.01, c + ": pivot between the feet (x)")
		assert_almost(feet.z, 0.0, 0.08, c + ": pivot between the feet (z)")
	assert_true(heights.ph_chr_gravekeeper - heights.ph_chr_carter >= 0.08, "carter clearly shorter than the gravekeeper")
	var gk := _rig("ph_chr_gravekeeper")
	var ct := _rig("ph_chr_carter")
	# wide floppy hat vs. flat cap
	var hat := _width(gk.posed(null, "head", 0.0))
	var cap := _width(ct.posed(null, "head", 0.0))
	assert_true(hat > cap * 1.8, "hat %.2f m vs cap %.2f m" % [hat, cap])
	# stout carter: broad belly (shirt + apron at belly height) relative to his height
	var belly: PackedVector3Array = ct.posed(null, "spine", 0.0)
	belly.append_array(ct.posed(null, "hips", 0.0))
	var band: PackedVector3Array = []
	for p: Vector3 in belly:
		if p.y > 0.75 and p.y < 1.05:
			band.append(p)
	assert_true(_width(band) / heights.ph_chr_carter > 0.36, "carter belly %.2f m wide" % _width(band))


func _width(points: PackedVector3Array) -> float:
	var lo := INF
	var hi := -INF
	for p: Vector3 in points:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return hi - lo


func test_model_faces_plus_z() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		for leg: String in ["leg_l", "leg_r"]:
			var front := -INF
			var back := INF
			for p: Vector3 in r.boot(null, leg, 0.0):
				front = maxf(front, p.z)
				back = minf(back, p.z)
			assert_true(front > -back + 0.05, "%s: %s toes point to +Z (MODEL_FRONT)" % [c, leg])


func test_triangle_budget() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var tris := 0  # every mesh of the figure (the gravekeeper's shovel is its own node)
		for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
			tris += _tris((n as MeshInstance3D).mesh)
		assert_true(tris <= TRI_MAX, "%s: %d tris <= %d" % [c, tris, TRI_MAX])
		assert_true(tris >= TRI_MIN, "%s: %d tris >= %d" % [c, tris, TRI_MIN])


# --- animations ---------------------------------------------------------------------

func test_animations_present_without_loop_suffix() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var expected: Array = (CHARACTERS[c].animations as Dictionary).keys()
		var names: Array = []
		for n: StringName in r.player.get_animation_list():
			names.append(String(n))
			assert_false(String(n).ends_with("loop"), "%s: suffix stripped from %s" % [c, n])
		names.sort()
		expected.sort()
		assert_eq(names, expected, c + ": animation set")


func test_loop_modes() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		for a: String in CHARACTERS[c].animations:
			var anim := r.animation(a)
			if anim == null:
				fail("%s: missing %s" % [c, a])
				continue
			if a in CHARACTERS[c].one_shot:
				assert_eq(anim.loop_mode, Animation.LOOP_NONE, "%s/%s is one-shot" % [c, a])
			else:
				assert_ne(anim.loop_mode, Animation.LOOP_NONE, "%s/%s loops" % [c, a])


func test_animation_lengths() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		for a: String in CHARACTERS[c].animations:
			var anim := r.animation(a)
			var lim: Array = CHARACTERS[c].animations[a]
			if anim == null:
				fail("%s: missing %s" % [c, a])
				continue
			assert_true(anim.length >= lim[0] and anim.length <= lim[1], "%s/%s length %.3f s" % [c, a, anim.length])


func test_tracks_target_the_skeleton_only() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var root_node := r.player.get_node(r.player.root_node)
		for a: String in CHARACTERS[c].animations:
			var anim := r.animation(a)
			assert_true(anim.get_track_count() > 0, "%s/%s has tracks" % [c, a])
			for i: int in anim.get_track_count():
				var path := anim.track_get_path(i)
				assert_eq(root_node.get_node_or_null(NodePath(String(path.get_concatenated_names()))), r.skeleton,
						"%s/%s track %s targets the skeleton" % [c, a, path])
				assert_has(_bones(c), String(path.get_concatenated_subnames()), "%s/%s bone of %s" % [c, a, path])
				assert_has([Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D],
						anim.track_get_type(i), "%s/%s track type" % [c, a])


func test_loops_are_seamless() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		for a: String in CHARACTERS[c].animations:
			var anim := r.animation(a)
			if anim == null or anim.loop_mode == Animation.LOOP_NONE:
				continue
			for b: String in _bones(c):
				var bi := r.skeleton.find_bone(b)
				var p0 := r.local_pose(anim, bi, 0.0)
				var p1 := r.local_pose(anim, bi, anim.length)
				assert_true(p0.origin.distance_to(p1.origin) < 0.002 and
						p0.basis.get_rotation_quaternion().angle_to(p1.basis.get_rotation_quaternion()) < 0.01,
						"%s/%s: %s first == last frame" % [c, a, b])


func test_root_motion_off() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var root := r.skeleton.find_bone("root")
		var hips := r.skeleton.find_bone("hips")
		for a: String in CHARACTERS[c].animations:
			var anim := r.animation(a)
			for k: int in 9:
				var t := anim.length * k / 8.0
				assert_true(r.local_pose(anim, root, t).is_equal_approx(r.skeleton.get_bone_rest(root)),
						"%s/%s: root stays at rest (t=%.2f)" % [c, a, t])
				var drift := r.global_pose(anim, hips, t).origin - r.global_rest(hips).origin
				assert_true(Vector2(drift.x, drift.z).length() < 0.06, "%s/%s: hips stay over the root" % [c, a])


func test_one_shot_starts_and_ends_at_rest() -> void:
	var r := _rig("ph_chr_gravekeeper")
	var anim := r.animation(&"interact")
	for b: String in BONES:
		var bi := r.skeleton.find_bone(b)
		for t: float in [0.0, anim.length]:
			var p := r.local_pose(anim, bi, t)
			var rest := r.skeleton.get_bone_rest(bi)
			assert_true(p.origin.distance_to(rest.origin) < 0.002 and
					p.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()) < 0.01,
					"interact: %s at rest at t=%.2f" % [b, t])


# --- motion checks (does each animation do what its name says?) ----------------------

func _check_walk(c: String, a: String, min_swing: float, speed_range: Array) -> void:
	var r := _rig(c)
	var anim := r.animation(a)
	var cycle := anim.length
	var rest_l := r.centroid(r.boot(null, "leg_l", 0.0))
	var rest_r := r.centroid(r.boot(null, "leg_r", 0.0))
	var l_fwd := r.centroid(r.boot(anim, "leg_l", cycle * 0.25))
	var r_back := r.centroid(r.boot(anim, "leg_r", cycle * 0.25))
	assert_true(l_fwd.z - rest_l.z > min_swing, "%s/%s: left foot forward at 1/4 (%.2f)" % [c, a, l_fwd.z - rest_l.z])
	assert_true(rest_r.z - r_back.z > min_swing, "%s/%s: right foot back at 1/4" % [c, a])
	var l_back := r.centroid(r.boot(anim, "leg_l", cycle * 0.75))
	assert_true(rest_l.z - l_back.z > min_swing, "%s/%s: left foot back at 3/4" % [c, a])
	# stride: the left foot is planted from 1/4 (heel strike) to 3/4 (toe off) -> ground speed
	var speed := (l_fwd.z - l_back.z) / (cycle * 0.5)
	assert_true(speed >= speed_range[0] and speed <= speed_range[1], "%s/%s: stride speed %.2f m/s" % [c, a, speed])
	# feet: one foot always on the ground, never below it
	for k: int in 16:
		var t := cycle * k / 16.0
		var yl := r.lowest_y(r.boot(anim, "leg_l", t))
		var yr := r.lowest_y(r.boot(anim, "leg_r", t))
		assert_almost(minf(yl, yr), 0.0, 0.012, "%s/%s: ground contact at t=%.2f" % [c, a, t])
		assert_true(maxf(yl, yr) < 0.15, "%s/%s: swing foot stays low at t=%.2f" % [c, a, t])


func test_gravekeeper_walk_swings_legs_and_arms() -> void:
	_check_walk("ph_chr_gravekeeper", "walk", 0.15, [2.6, 3.8])  # PlayerConfig walk speed ~3.2 m/s
	var r := _rig("ph_chr_gravekeeper")
	var anim := r.animation(&"walk")
	var rest_hand := r.hand(null, "arm_l", 0.0)
	assert_true(r.hand(anim, "arm_l", anim.length * 0.25).z < rest_hand.z - 0.1, "left arm swings back with left leg forward")
	assert_true(r.hand(anim, "arm_l", anim.length * 0.75).z > rest_hand.z + 0.1, "left arm swings forward")


func test_gravekeeper_carry_walk_is_slower() -> void:
	_check_walk("ph_chr_gravekeeper", "carry_walk", 0.1, [1.5, 2.6])  # carry speed ~2.0 m/s
	var r := _rig("ph_chr_gravekeeper")
	assert_true(r.animation(&"carry_walk").length > r.animation(&"walk").length, "heavier, slower cycle")


func test_carter_walks() -> void:
	_check_walk("ph_chr_carter", "walk", 0.15, [1.3, 2.2])       # calm walk ~1.6 m/s
	_check_walk("ph_chr_carter", "push_cart", 0.1, [0.9, 1.6])   # slow push ~1.1 m/s


func test_carry_holds_arms_forward() -> void:
	var r := _rig("ph_chr_gravekeeper")
	for a: StringName in [&"carry_idle", &"carry_walk"]:
		var anim := r.animation(a)
		for k: int in 4:
			var t := anim.length * k / 4.0
			for arm: String in ["arm_l", "arm_r"]:
				var rest := r.hand(null, arm, 0.0)
				var h := r.hand(anim, arm, t)
				assert_true(h.z > rest.z + 0.25, "%s: %s hand forward (%.2f)" % [a, arm, h.z - rest.z])
				assert_true(h.y > 0.75 and h.y < 1.2, "%s: %s hand at carrying height (%.2f)" % [a, arm, h.y])
				assert_true(absf(h.x) < absf(rest.x), "%s: %s hand drawn in towards the body" % [a, arm])


func test_dig_bare_bends_and_reaches_down() -> void:
	# the old empty-handed dig (G7 Runde 2: axe / pickaxe / bare-handed work)
	var r := _rig("ph_chr_gravekeeper")
	var anim := r.animation(&"dig_bare")
	var rest_head := r.centroid(r.posed(null, "head", 0.0))
	var max_fwd := -INF
	var min_hand := INF
	var max_hand := -INF
	for k: int in 24:
		var t := anim.length * k / 24.0
		max_fwd = maxf(max_fwd, r.centroid(r.posed(anim, "head", t)).z - rest_head.z)
		var h := r.hand(anim, "arm_l", t)
		min_hand = minf(min_hand, h.y)
		max_hand = maxf(max_hand, h.y)
	assert_true(max_fwd > 0.2, "dig_bare: upper body bends forward (%.2f m)" % max_fwd)
	assert_true(min_hand < 0.8, "dig_bare: hands go down to the blade (%.2f m)" % min_hand)
	assert_true(max_hand - min_hand > 0.3, "dig_bare: hands lift the earth (%.2f m)" % (max_hand - min_hand))
	for k: int in 12:
		var t := anim.length * k / 12.0
		for leg: String in ["leg_l", "leg_r"]:
			assert_almost(r.lowest_y(r.boot(anim, leg, t)), 0.0, 0.012, "dig_bare: %s planted at t=%.2f" % [leg, t])


## G7 Runde 2: skeleton-space point carried by the tool bone (rest-model coordinates).
func _shovel_point(r: Rig, anim: Animation, t: float, p: Vector3) -> Vector3:
	var b := r.skeleton.find_bone("tool")
	return r.global_pose(anim, b, t) * (r.global_rest(b).affine_inverse() * p)


func _blade_tip(r: Rig, anim: Animation, t: float) -> Vector3:
	var a := _shovel_point(r, anim, t, SHOVEL_G0)
	var d := (_shovel_point(r, anim, t, SHOVEL_G1) - a).normalized()
	return a + d * (SHOVEL_G0.distance_to(SHOVEL_G1) + 0.34)


func test_dig_with_the_shovel() -> void:
	var r := _rig("ph_chr_gravekeeper")
	var anim := r.animation(&"dig")
	var rest_head := r.centroid(r.posed(null, "head", 0.0))
	var lowest := INF
	var highest := -INF
	var max_fwd := -INF
	var tread := -INF
	for k: int in 26:
		var t := anim.length * k / 26.0
		var tip := _blade_tip(r, anim, t)
		lowest = minf(lowest, tip.y)
		highest = maxf(highest, tip.y)
		max_fwd = maxf(max_fwd, r.centroid(r.posed(anim, "head", t)).z - rest_head.z)
		tread = maxf(tread, r.lowest_y(r.boot(anim, "leg_l", t)))
		assert_true(tip.z > 0.2, "dig: blade in front of him at t=%.2f (%.2f)" % [t, tip.z])
		assert_almost(r.lowest_y(r.boot(anim, "leg_r", t)), 0.0, 0.012, "dig: right foot planted at t=%.2f" % t)
		assert_true(r.lowest_y(r.boot(anim, "leg_l", t)) > -0.012, "dig: left foot never in the ground")
	assert_true(lowest < -0.1, "dig: the blade bites into the earth (%.2f m)" % lowest)
	assert_true(highest > 0.6, "dig: the earth is lifted and thrown (%.2f m)" % highest)
	assert_true(max_fwd > 0.08, "dig: leans over the blade (%.2f m)" % max_fwd)
	assert_true(tread > 0.06, "dig: the left foot treads the blade in (%.2f m)" % tread)


func test_shovel_on_the_back_in_the_other_clips() -> void:
	var r := _rig("ph_chr_gravekeeper")
	var tool := r.skeleton.find_bone("tool")
	var rest := r.skeleton.get_bone_rest(tool)
	for a: StringName in [&"idle", &"walk", &"carry_idle", &"carry_walk", &"dig_bare", &"interact"]:
		var anim := r.animation(a)
		for k: int in 5:
			var p := r.local_pose(anim, tool, anim.length * k / 4.0)
			assert_true(p.origin.distance_to(rest.origin) < 0.002 and
					p.basis.get_rotation_quaternion().angle_to(rest.basis.get_rotation_quaternion()) < 0.01,
					"%s: shovel on the back" % a)
	# draw starts and the stows end on the back; draw ends / stow starts in the first dig frame
	var dig := r.animation(&"dig")
	for pair: Array in [[&"shovel_draw", 0.0, null], [&"shovel_stow", 1.0, null], [&"shovel_stow_walk", 1.0, null],
			[&"shovel_draw", 1.0, dig], [&"shovel_stow", 0.0, dig]]:
		var anim := r.animation(pair[0])
		var p := r.local_pose(anim, tool, anim.length * float(pair[1]))
		var want: Transform3D = rest if pair[2] == null else r.local_pose(pair[2], tool, 0.0)
		assert_true(p.origin.distance_to(want.origin) < 0.005 and
				p.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion()) < 0.02,
				"%s at %d %%: shovel where it belongs" % [pair[0], int(float(pair[1]) * 100)])


func test_interact_reaches_forward() -> void:
	var r := _rig("ph_chr_gravekeeper")
	var anim := r.animation(&"interact")
	var rest := r.hand(null, "arm_r", 0.0)
	var reach := -INF
	for k: int in 16:
		reach = maxf(reach, r.hand(anim, "arm_r", anim.length * k / 16.0).z - rest.z)
	assert_true(reach > 0.3, "interact: right hand reaches forward (%.2f m)" % reach)


func test_idle_is_subtle() -> void:
	for c: String in CHARACTERS:
		var r := _rig(c)
		var anim := r.animation(&"idle")
		var rest := r.centroid(r.posed(null, "head", 0.0))
		var max_d := 0.0
		for k: int in 16:
			max_d = maxf(max_d, r.centroid(r.posed(anim, "head", anim.length * k / 16.0)).distance_to(rest))
		assert_true(max_d > 0.003 and max_d < 0.06, "%s/idle: breathing moves the head %.3f m" % [c, max_d])
		for leg: String in ["leg_l", "leg_r"]:
			assert_almost(r.lowest_y(r.boot(anim, leg, anim.length * 0.5)), 0.0, 0.012, "%s/idle: %s planted" % [c, leg])


func test_push_cart_leans_with_hands_on_handles() -> void:
	var r := _rig("ph_chr_carter")
	var anim := r.animation(&"push_cart")
	var rest_head := r.centroid(r.posed(null, "head", 0.0))
	for k: int in 4:
		var t := anim.length * k / 4.0
		assert_true(r.centroid(r.posed(anim, "head", t)).z - rest_head.z > 0.1, "push_cart: leaning into the cart")
		for arm: String in ["arm_l", "arm_r"]:
			var h := r.hand(anim, arm, t)
			var rest := r.hand(null, arm, 0.0)
			assert_true(h.z > rest.z + 0.25, "push_cart: %s hand forward (%.2f)" % [arm, h.z - rest.z])
			assert_true(h.y > 0.6 and h.y < 1.05, "push_cart: %s hand low on the handle (%.2f)" % [arm, h.y])


func test_talk_gestures_with_one_hand() -> void:
	var r := _rig("ph_chr_carter")
	var anim := r.animation(&"talk")
	var moves := {}
	for arm: String in ["arm_l", "arm_r"]:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for k: int in 24:
			var h := r.hand(anim, arm, anim.length * k / 24.0)
			lo = lo.min(h)
			hi = hi.max(h)
		moves[arm] = (hi - lo).length()
	assert_true(moves.arm_r > 0.15, "talk: right hand gestures (%.2f m)" % moves.arm_r)
	assert_true(moves.arm_l < moves.arm_r * 0.5, "talk: left hand mostly still")


func test_animations_play_in_engine() -> void:
	for c: String in CHARACTERS:
		var inst := (load(DIR + c + ".glb") as PackedScene).instantiate() as Node3D
		tree.root.add_child(inst)
		var ap := inst.get_node("AnimationPlayer") as AnimationPlayer
		var sk := inst.get_node("Armature/Skeleton3D") as Skeleton3D
		var leg := sk.find_bone("leg_l")
		ap.play(&"walk")
		ap.seek(ap.current_animation_length * 0.25, true)
		var q := sk.get_bone_pose_rotation(leg)
		assert_true(q.angle_to(sk.get_bone_rest(leg).basis.get_rotation_quaternion()) > deg_to_rad(10.0),
				c + ": AnimationPlayer drives the skeleton")
		for a: StringName in ap.get_animation_list():
			ap.play(a)
			await tree.process_frame
		inst.queue_free()


# --- Ilse Kranich (Phase 4, P5) ---------------------------------------------------------

func test_kranich_budget_and_silhouette() -> void:
	var k := _rig("ph_chr_kranich")
	var tris := _tris(k.mesh_instance.mesh)
	assert_true(tris <= KRANICH_TRI_MAX, "kranich: %d tris <= %d" % [tris, KRANICH_TRI_MAX])
	var hk := _rest_aabb(k).size.y
	var hc := _rest_aabb(_rig("ph_chr_carter")).size.y
	assert_true(hk - hc >= 0.12, "Ilse clearly taller than Osric (%.2f vs %.2f m)" % [hk, hc])
	# gaunt: at belly height (0.75 .. 1.05 m) far narrower than the stout carter
	var band: PackedVector3Array = []
	for bone: String in ["hips", "spine"]:
		for p: Vector3 in k.posed(null, bone, 0.0):
			if p.y > 0.75 and p.y < 1.05 and p.z > -0.2:
				band.append(p)
	assert_true(_width(band) / hk < 0.26, "Ilse is narrow at the belly (%.2f m)" % _width(band))
	# the wicker basket sits on her back (behind the spine, -Z), below the top of the hood
	var back := -INF
	for p: Vector3 in k.posed(null, "spine", 0.0):
		back = maxf(back, -p.z)
	assert_true(back > 0.35, "back-basket reaches %.2f m behind her" % back)


func test_kranich_lantern_in_the_left_hand() -> void:
	var r := _rig("ph_chr_kranich")
	var marker := r.scene.find_child("light_lantern", true, false) as Node3D
	assert_not_null(marker, "light_lantern marker")
	if marker == null:
		return
	var att := marker.get_parent() as BoneAttachment3D
	assert_not_null(att, "marker sits on a BoneAttachment3D")
	if att:
		assert_eq(att.bone_name, "arm_l", "the lantern swings with her left arm")
	var p := _scene_pos(marker, r.scene)
	assert_true(p.x > 0.2 and p.x < 0.4, "lantern on her left, clear of the coat (x %.2f)" % p.x)
	assert_true(p.y > 0.5 and p.y < 0.8, "lantern hangs below the fist (y %.2f)" % p.y)
	assert_true(p.y < r.hand(null, "arm_l", 0.0).y + 0.05, "light inside the lantern, under the hand")


func test_kranich_coins_marker_in_the_right_hand() -> void:
	var r := _rig("ph_chr_kranich")
	var marker := r.scene.find_child("coins", true, false) as Node3D
	assert_not_null(marker, "coins marker")
	if marker == null:
		return
	var att := marker.get_parent() as BoneAttachment3D
	assert_not_null(att, "coins marker on a BoneAttachment3D")
	if att:
		assert_eq(att.bone_name, "arm_r", "coins follow the right hand")
	var p := _scene_pos(marker, r.scene)
	assert_true(p.distance_to(r.hand(null, "arm_r", 0.0)) < 0.12, "coins at the right palm (%s)" % p)


func test_kranich_walks_calmly() -> void:
	_check_walk("ph_chr_kranich", "walk", 0.12, [1.1, 1.5])   # calm stride ~1.3 m/s (§8)


func test_kranich_offer_hands_over_coins() -> void:
	var r := _rig("ph_chr_kranich")
	var anim := r.animation(&"offer")
	var rest := r.hand(null, "arm_r", 0.0)
	var reach := -INF
	for k: int in 16:
		reach = maxf(reach, r.hand(anim, "arm_r", anim.length * k / 16.0).z - rest.z)
	assert_true(reach > 0.3, "offer: right hand reaches forward (%.2f m)" % reach)
	for b: String in BONES:
		var bi := r.skeleton.find_bone(b)
		for t: float in [0.0, anim.length]:
			var p := r.local_pose(anim, bi, t)
			var rb := r.skeleton.get_bone_rest(bi)
			assert_true(p.origin.distance_to(rb.origin) < 0.002 and
					p.basis.get_rotation_quaternion().angle_to(rb.basis.get_rotation_quaternion()) < 0.01,
					"offer: %s at rest at t=%.2f" % [b, t])
	for leg: String in ["leg_l", "leg_r"]:
		assert_almost(r.lowest_y(r.boot(anim, leg, anim.length * 0.5)), 0.0, 0.012, "offer: %s planted" % leg)


func test_kranich_talks_with_the_free_hand() -> void:
	var r := _rig("ph_chr_kranich")
	var anim := r.animation(&"talk")
	var moves := {}
	for arm: String in ["arm_l", "arm_r"]:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for k: int in 24:
			var h := r.hand(anim, arm, anim.length * k / 24.0)
			lo = lo.min(h)
			hi = hi.max(h)
		moves[arm] = (hi - lo).length()
	assert_true(moves.arm_r > 0.12, "talk: right hand gestures (%.2f m)" % moves.arm_r)
	assert_true(moves.arm_l < moves.arm_r * 0.3, "talk: the lantern hand stays still")


func _scene_pos(node: Node, scene: Node) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != scene:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.origin
