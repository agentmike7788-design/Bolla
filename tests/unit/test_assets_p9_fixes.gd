extends TestCase
## Phase 9 W3 „Restbedarf“ (docs/reviews/phase9_round1/fixes/fixes.md):
## 3 – Lenz and Liesel sit with Johann on the bench (sit_bench on ph_chr_v_priest / ph_chr_v_washer, added after every
##     older clip – body and old clips: test_assets_phase8 REEXPORT);
## 4 – the night watchman ph_chr_watchman (asset_mourners, the builder of Johann Sieber): long coat, cap, stick, the
##     lantern in the right hand with the marker light_lantern, clips idle / walk / talk / stand_watch, ≤ 9000 tris,
##     face by lib_faces, deterministic export.

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const DIR := "res://assets/models/characters/"
const WATCH := "ph_chr_watchman"
const WATCH_CLIPS: Array[String] = ["idle", "stand_watch", "talk", "walk"]

var _rigs: Dictionary = {}


func after_each() -> void:
	for r: Variant in _rigs.values():
		r.free_scene()
	_rigs.clear()


func _rig(n: String) -> Chars.Rig:
	if not _rigs.has(n):
		_rigs[n] = Chars.Rig.new(DIR + n + ".glb")
	return _rigs[n]


func _xf(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func test_lenz_and_liesel_sit_on_the_bench() -> void:
	for c: String in ["ph_chr_v_priest", "ph_chr_v_washer"]:
		var r := _rig(c)
		var a := r.animation(&"sit_bench")
		assert_not_null(a, c + ": sit_bench")
		if a == null:
			continue
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR, c + ": sit_bench loops")
		var drop := r.centroid(r.posed(null, "hips", 0.0)).y - r.centroid(r.posed(a, "hips", a.length * 0.3)).y
		assert_true(drop > 0.2 and drop < 0.36, "%s: the hips %.2f m lower (seat 0.45 m like Johann)" % [c, drop])
		for leg: String in ["leg_l", "leg_r"]:
			assert_true(r.lowest_y(r.posed(a, leg, a.length * 0.3)) > -0.03, "%s: %s above the ground" % [c, leg])
	var j := _rig("ph_chr_mourner_m_b")
	var ja := j.animation(&"sit_bench")
	var jdrop := j.centroid(j.posed(null, "hips", 0.0)).y - j.centroid(j.posed(ja, "hips", ja.length * 0.3)).y
	var p := _rig("ph_chr_v_priest")
	var pa := p.animation(&"sit_bench")
	var pdrop := p.centroid(p.posed(null, "hips", 0.0)).y - p.centroid(p.posed(pa, "hips", pa.length * 0.3)).y
	assert_true(absf(pdrop - jdrop) < 0.05, "the same seat height as Johann (%.2f / %.2f)" % [pdrop, jdrop])


func test_watchman_figure() -> void:
	var r := _rig(WATCH)
	assert_not_null(r.skeleton, "skeleton")
	if r.skeleton == null:
		return
	assert_true(r.rigid_ok, "rigid skinning")
	assert_eq(r.skeleton.get_bone_count(), 8, "the shared 8-bone rig")
	var clips: Array[String] = []
	for n: StringName in r.player.get_animation_list():
		clips.append(String(n))
	clips.sort()
	assert_eq(clips, WATCH_CLIPS)
	for c: String in WATCH_CLIPS:
		assert_eq(r.animation(StringName(c)).loop_mode, Animation.LOOP_LINEAR, c + " loops")
	var tris := 0
	for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).mesh
		for s: int in m.get_surface_count():
			var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
	assert_true(tris >= 3000 and tris <= 9000, "%d tris (≤ 9000, body + cap + lantern)" % tris)
	var box := AABB(r.verts[0], Vector3.ZERO)
	for v: Vector3 in r.verts:
		box = box.expand(v)
	assert_true(box.end.y > 1.6 and box.end.y < 1.85, "height %.2f" % box.end.y)
	assert_true(absf(box.position.y) < 0.012, "feet on the ground")
	for child: String in ["cap", "watch_lantern"]:
		var m := r.scene.find_child(child, true, false) as MeshInstance3D
		assert_not_null(m, child)
		if m == null:
			continue
		var ex: Dictionary = m.get_meta("extras", {})
		var shown := String(ex.get("show_with", "")).split(",", false)
		shown.sort()
		assert_eq(Array(shown), Array(WATCH_CLIPS), child + " in every clip")
	var face := r.scene.find_child("face", true, false) as Node3D
	assert_true(face != null and (face.get_parent() as BoneAttachment3D).bone_name == "head", "face marker (lib_faces)")
	# the light hangs in the lantern: the marker on arm_r inside the lantern's box
	var marker := r.scene.find_child("light_lantern", true, false) as Node3D
	var lantern := r.scene.find_child("watch_lantern", true, false) as MeshInstance3D
	assert_true(marker != null and lantern != null, "light_lantern + watch_lantern")
	if marker == null or lantern == null:
		return
	assert_eq((marker.get_parent() as BoneAttachment3D).bone_name, "arm_r", "the light follows the lantern arm")
	var at := _xf(marker, r.scene).origin
	var lbox := _xf(lantern, r.scene) * lantern.get_aabb()
	assert_true(lbox.grow(0.01).has_point(at), "light_lantern %s inside the lantern %s" % [at, lbox])
	assert_true(lbox.size.y > 0.15 and lbox.size.y < 0.35, "a hand lantern (%.2f m)" % lbox.size.y)


func test_watchman_sources() -> void:
	assert_true(FileAccess.file_exists("res://art_source/blender/characters/%s.blend" % WATCH), "source .blend")
	var src := FileAccess.get_file_as_string("res://tools/blender/asset_mourners.py")
	assert_true(src.contains("\"ph_chr_watchman\": dict(") and src.contains("def watchman():"), "built by asset_mourners")
	assert_true(src.contains("from lib_faces import"), "lib_faces is only used")
	var ph := FileAccess.get_file_as_string("res://docs/ASSET_GUIDELINES.md") + FileAccess.get_file_as_string("res://docs/QUALITY_GATE_STATUS.md")
	assert_true(ph.contains(WATCH), "in the placeholder list")
