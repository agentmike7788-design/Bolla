extends TestCase
## G8 Runde 4 (user: „ja die sollen eigene arbeitsbewegungen bekommen"): the villagers' own work clips at their work
## places (tools/blender/asset_villager_work.py, Osric's pipe in asset_carter.py), wired through the data
## (ScheduleEntry.animation in data/npc/*_schedule.tres, NpcWorkConfig in data/config/npc_work_config.tres):
## the clips exist on the rigs and loop seamlessly, the props sit in the fist on their bone and show only with
## their clip, the budgets hold, every entry at a work place has an own clip instead of idle / talk, the work
## places face the counter, altar, desk or stones, and the generators stay deterministic.
## Body mesh and the older clips stay hash-equal: test_assets_phase8 (REEXPORT, + WORK_R4) and
## test_cart_delivery (Osric).

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const MODEL_DIR := "res://assets/models/characters/"
const BONES: Array[String] = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
## Phase 7 (test_assets_phase7 VILLAGER_TRI_MAX): body + every child mesh of a villager stays inside it.
const VILLAGER_TRI_MAX := 9000
const PROP_TRI_MAX := 150
## model -> work clips (all loops, 3 s) and props (child mesh -> [bone, the clips it shows with, the moment of the
## first clip (fraction) the hand is checked at])
const WORK := {
	"ph_chr_v_innkeeper": {"clips": ["polish_mug"], "props": {"prop_mug": ["arm_l", ["polish_mug"], 0.2],
			"prop_rag": ["arm_r", ["polish_mug"], 0.2]}},
	"ph_chr_v_priest": {"clips": ["pray_altar", "read_breviary"], "props": {}},
	"ph_chr_v_mayor": {"clips": ["desk_files", "proclaim"], "props": {"prop_stamp": ["arm_r", ["desk_files"], 0.7],
			"prop_notice": ["arm_l", ["proclaim"], 0.2]}},
	"ph_chr_v_surgeon": {"clips": ["desk_write", "mix_vial"], "props": {"prop_quill": ["arm_r", ["desk_write"], 0.3],
			"prop_vial": ["arm_r", ["mix_vial"], 0.5]}},
	"ph_chr_v_washer": {"clips": ["wash_brook", "wash_body"], "props": {"prop_washcloth": ["arm_r", ["wash_brook", "wash_body"], 0.0]}},
	"ph_chr_carter": {"clips": ["smoke"], "props": {}},
}
const VILLAGER_MODEL := {&"innkeeper": "ph_chr_v_innkeeper", &"smith": "ph_chr_v_smith", &"grocer": "ph_chr_v_grocer",
		&"priest": "ph_chr_v_priest", &"mayor": "ph_chr_v_mayor", &"surgeon": "ph_chr_v_surgeon", &"washer": "ph_chr_v_washer",
		&"carter": "ph_chr_carter", &"apprentice": "ph_chr_apprentice"}
## The work places of the data schedules (npc_id -> waypoints): every entry standing there works. Found by the
## audit of round 4 (docs/reviews/phase8_round4/dorf_arbeit.md); the smith, the grocer and Liesel at her door had
## their work clips since Phase 7.
const WORK_PLACES := {
	&"innkeeper": ["v_in_inn_bar"], &"priest": ["v_in_church_altar", "v_church_door"],
	&"mayor": ["v_in_office_desk", "v_board"], &"surgeon": ["v_in_surgery_desk"], &"washer": ["v_wash", "v_dorn_door"],
	&"smith": ["v_anvil"], &"grocer": ["v_shop_window"], &"carter": ["evening_spot"],
}
## Jakob helping Rosine of an evening (not on his day off: those entries have today_flag apprentice_off_day).
const JAKOB_WORK_MINUTE := 1020
const NOT_WORK: Array[StringName] = [&"idle", &"talk", &"idle_low"]
## The expected clip per work place (npc_id/waypoint -> clip).
const CLIP_AT := {
	"innkeeper/v_in_inn_bar": &"polish_mug", "priest/v_in_church_altar": &"pray_altar", "priest/v_church_door": &"read_breviary",
	"mayor/v_in_office_desk": &"desk_files", "mayor/v_board": &"proclaim", "washer/v_wash": &"wash_brook",
	"carter/evening_spot": &"smoke",
}
## Interior work places: layout, waypoint, the furniture the figure works at (it faces it).
const ROOM_SPOTS := [
	["res://data/world/interiors/inn_layout.json", "v_in_inn_bar", "Bar"],
	["res://data/world/interiors/office_layout.json", "v_in_office_desk", "Desk"],
	["res://data/world/interiors/surgery_layout.json", "v_in_surgery_desk", "Desk"],
	["res://data/world/interiors/church_layout.json", "v_in_church_altar", "Altar"],
]
## Village work places (village_layout.json waypoints / waypoint_facing): waypoint -> the prop or entity it faces.
const VILLAGE_SPOTS := {"v_anvil": "counter_smith", "v_wash": "wash_stones"}
const MAX_OFF_DEG := 50.0

var _rigs: Dictionary = {}


func after_each() -> void:
	for r: Variant in _rigs.values():
		r.free_scene()
	_rigs.clear()


# --- data ----------------------------------------------------------------------------------------------

func test_work_config_in_data() -> void:
	var cfg := _cfg()
	assert_true(cfg.pause_range > 1.0 and cfg.pause_range < 3.5, "the work pauses within %.1f m (closer than the 3.5 m the figures turn at)"
			% cfg.pause_range)
	assert_eq([cfg.pause_clip, cfg.talk_clip], [&"idle", &"talk"])
	for model: String in WORK:
		for clip: String in WORK[model].clips:
			assert_true(cfg.is_work(StringName(clip)), "%s is a work clip (it pauses for the gravekeeper)" % clip)
	for old: StringName in [&"work", &"sweep"]:
		assert_true(cfg.is_work(old), "the older work clip %s pauses as well" % old)
	assert_false(cfg.is_work(&"idle") or cfg.is_work(&"talk") or cfg.is_work(&"sit_beg"), "idle, talk, begging are no work")
	assert_eq(cfg.clip_for(&"apprentice_inn", &"idle"), &"sweep", "Jakob sweeps the inn of an evening")
	assert_eq(cfg.clip_for(&"washer_table", &"work"), &"wash_body", "Liesel washes the dead at the table")
	assert_eq(cfg.clip_for(&"nothing", &"idle"), &"idle", "unknown key → fallback")
	assert_eq(cfg.spot_for(&"apprentice_inn", &"v_in_inn_jakob"), &"v_in_inn_sweep", "G8 Runde 5: Jakob sweeps where the camera sees it")
	assert_eq(cfg.spot_for(&"washer_table", &"x"), &"x", "no spot → fallback")
	assert_eq(NpcWorkConfig.runtime_spot(&"apprentice_inn", &""), &"v_in_inn_sweep", "static lookup through the Database")
	assert_false(cfg.work_facing.has(&"v_in_church_altar") or cfg.work_facing.has(&"v_in_inn_jakob"),
			"G8 Runde 5: Lenz and Jakob work with their spot's own facing (no back to the camera)")
	assert_eq(NpcWorkConfig.runtime_clip(&"apprentice_inn", &"idle"), &"sweep", "static lookup through the Database")
	var puffs := cfg.puffs(&"smoke")
	assert_false(puffs.is_empty(), "Osric's pipe puffs")
	for m: float in puffs:
		assert_true(m > 0.0 and m < 1.0, "puff moment %.2f in the cycle" % m)
	assert_true(cfg.puff_amount >= 3 and cfg.puff_lifetime > 1.0 and cfg.puff_size > 0.02 and cfg.puff_size < 0.15, "a small soft puff")
	assert_true(cfg.puff_color.a > 0.2 and cfg.puff_color.a < 0.9, "half transparent")


func test_every_work_entry_has_its_own_clip() -> void:
	var cfg := _cfg()
	for npc_id: StringName in WORK_PLACES:
		var sched := Database.schedule(npc_id) as NpcSchedule
		assert_not_null(sched, "schedule %s" % npc_id)
		if sched == null:
			continue
		var clips := _clips(String(VILLAGER_MODEL[npc_id]))
		var found := 0
		for e: ScheduleEntry in sched.entries:
			if e == null or not e.visible or e.travel_minutes > 0 or e.path.is_empty():
				continue
			var at := e.path[e.path.size() - 1]
			if not at in WORK_PLACES[npc_id]:
				continue
			found += 1
			var where := "%s %02d:%02d at %s" % [npc_id, e.start_minute / 60, e.start_minute % 60, at]
			assert_false(e.animation in NOT_WORK, where + ": an own work clip, not " + String(e.animation))
			assert_true(cfg.is_work(e.animation), where + ": %s is a work clip" % e.animation)
			assert_has(clips, String(e.animation), where + ": the model has " + String(e.animation))
			var key := "%s/%s" % [npc_id, at]
			if CLIP_AT.has(key):
				assert_eq(e.animation, CLIP_AT[key], where)
		assert_true(found > 0, "%s works somewhere" % npc_id)
	# Quast: writing in the morning, the vials in the afternoon
	var quast := _entries_at(&"surgeon", "v_in_surgery_desk")
	assert_eq(quast.map(func(e: ScheduleEntry) -> StringName: return e.animation), [&"desk_write", &"mix_vial"], "Quast at his desk")
	# Jakob: helping in the inn of an evening (data fallback schedule) – G8 Runde 5 at his sweeping spot – talking on
	# his day off at his usual place
	var sweeps := _entries_at(&"apprentice", String(cfg.spot_for(&"apprentice_inn", &"")))
	assert_eq(sweeps.map(func(e: ScheduleEntry) -> Array: return [e.start_minute, e.animation, e.today_flag]),
			[[JAKOB_WORK_MINUTE, &"sweep", &""]], "Jakob sweeps at v_in_inn_sweep from 17:00")
	for e: ScheduleEntry in _entries_at(&"apprentice", "v_in_inn_jakob"):
		if e.start_minute == JAKOB_WORK_MINUTE:
			assert_eq([e.animation, e.today_flag], [&"talk", &"apprentice_off_day"], "Jakob 17:00 on his day off")
	# every shop entry of a villager works (the peddler offers, a shop entry never just stands)
	for npc_id: StringName in VILLAGER_MODEL:
		var sched := Database.schedule(npc_id) as NpcSchedule
		if sched == null:
			continue
		for e: ScheduleEntry in sched.entries:
			if e != null and e.activity == &"shop":
				assert_false(e.animation in NOT_WORK, "%s %d shop: %s" % [npc_id, e.start_minute, e.animation])


func test_runtime_work_clips_are_on_the_models() -> void:
	assert_has(_clips("ph_chr_apprentice"), String(_cfg().clip_for(&"apprentice_inn", &"")), "Jakob's inn clip")
	assert_has(_clips("ph_chr_v_washer"), String(_cfg().clip_for(&"washer_table", &"")), "Liesel's table clip")
	var src := FileAccess.get_file_as_string("res://src/systems/friendship/friendship.gd")
	assert_true(src.contains("NpcWorkConfig.runtime_clip(WASH_WORK_KEY"), "Friendship takes the wash clip from the data")
	var app := FileAccess.get_file_as_string("res://src/systems/apprentice/apprentice.gd")
	assert_true(app.contains("NpcWorkConfig.runtime_clip(V_WORK_KEY"), "Apprentice takes the inn clip from the data")
	assert_true(app.contains("NpcWorkConfig.runtime_spot(V_WORK_KEY"), "… and the sweeping spot")


func test_work_places_face_the_work() -> void:
	for spec: Array in ROOM_SPOTS:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(spec[0])))
		var wp: Array = d.waypoints[spec[1]]
		var item: Dictionary = {}
		for it: Dictionary in d.items:
			if it.get("id", "") == spec[2]:
				item = it
		assert_false(item.is_empty(), "%s: %s" % [spec[0].get_file(), spec[2]])
		if item.is_empty():
			continue
		var to := Vector2(float(item.pos[0]) - float(wp[0]), float(item.pos[1]) - float(wp[1]))
		var off := _angle_off(_work_facing(String(spec[1]), float(wp[2])), to)
		assert_true(off < MAX_OFF_DEG, "%s faces the %s (%.0f° off)" % [spec[1], spec[2], off])
		assert_true(to.length() < 1.6, "%s close to the %s (%.2f m)" % [spec[1], spec[2], to.length()])
	var v: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/village_layout.json"))
	for wp_id: String in VILLAGE_SPOTS:
		var at: Array = v.waypoints[wp_id]
		var target := Vector2.INF
		for list: String in ["props", "entities"]:
			for it: Dictionary in v[list]:
				if it.get("id", "") == VILLAGE_SPOTS[wp_id]:
					target = Vector2(float(it.pos[0]), float(it.pos[1]))
		assert_true(target != Vector2.INF, "village: " + String(VILLAGE_SPOTS[wp_id]))
		var to := target - Vector2(float(at[0]), float(at[1]))
		var off := _angle_off(_work_facing(wp_id, float(v.waypoint_facing[wp_id])), to)
		assert_true(off < MAX_OFF_DEG, "%s faces %s (%.0f° off)" % [wp_id, VILLAGE_SPOTS[wp_id], off])


# --- the clips on the rigs ---------------------------------------------------------------------------------

func test_work_clips_exist_and_loop() -> void:
	for model: String in WORK:
		var r := _rig(model)
		for clip: String in WORK[model].clips:
			var anim := r.animation(StringName(clip))
			assert_not_null(anim, "%s: clip %s" % [model, clip])
			if anim == null:
				continue
			assert_ne(anim.loop_mode, Animation.LOOP_NONE, "%s/%s loops" % [model, clip])
			assert_true(anim.length > 2.9 and anim.length < 3.1, "%s/%s 3 s (%.2f)" % [model, clip, anim.length])
			var root := r.skeleton.find_bone("root")
			for k: int in 5:
				assert_true(r.local_pose(anim, root, anim.length * k / 4.0).is_equal_approx(r.skeleton.get_bone_rest(root)),
						"%s/%s: root at rest" % [model, clip])
			for b: String in BONES:
				var bi := r.skeleton.find_bone(b)
				var p0 := r.local_pose(anim, bi, 0.0)
				var p1 := r.local_pose(anim, bi, anim.length)
				assert_true(p0.origin.distance_to(p1.origin) < 0.002 and
						p0.basis.get_rotation_quaternion().angle_to(p1.basis.get_rotation_quaternion()) < 0.01,
						"%s/%s seamless (%s)" % [model, clip, b])
			# the feet stay on the ground (kneeling too: the legs slide into the skirt)
			for k: int in 6:
				var t := anim.length * k / 6.0
				for leg: String in ["leg_l", "leg_r"]:
					var low := r.lowest_y(r.boot(anim, leg, t))
					assert_true(absf(low) < 0.03, "%s/%s: %s on the ground at %.1f s (%.3f)" % [model, clip, leg, t, low])
			# it is not standing still: the hands move through the cycle
			var travel := 0.0
			for arm: String in ["arm_l", "arm_r"]:
				var prev := r.hand(anim, arm, 0.0)
				for k: int in range(1, 13):
					var h := r.hand(anim, arm, anim.length * k / 12.0)
					travel += h.distance_to(prev)
					prev = h
			assert_true(travel > (0.15 if clip == "smoke" else 0.4), "%s/%s: the hands work (%.2f m)" % [model, clip, travel])


func test_work_clips_read_as_work() -> void:
	# Rosine holds the mug in front over the counter (~1 m), Quast's quill over his desk (0.85 m), Fenner stamps
	# low onto the desk (0.8 m) and holds the notice at the chest, Liesel kneels at the brook (the hips low), the
	# priest's arms rise before the altar
	var inn := _rig("ph_chr_v_innkeeper")
	var mug := inn.hand(inn.animation(&"polish_mug"), "arm_l", 0.5)
	assert_true(mug.y > 1.0 and mug.z > 0.35, "the mug above the counter, in front (%s)" % mug)
	var su := _rig("ph_chr_v_surgeon")
	var quill := su.hand(su.animation(&"desk_write"), "arm_r", 0.9)
	assert_true(quill.y > 0.85 and quill.y < 1.0 and quill.z > 0.38, "the quill over the desk (%s)" % quill)
	var vial := su.hand(su.animation(&"mix_vial"), "arm_r", 1.5)
	assert_true(vial.y > 1.3, "the vial up at the eye (%s)" % vial)
	var bag := su.hand(su.animation(&"desk_write"), "arm_l", 0.9)
	assert_true(absf(bag.z) < 0.25, "the case hangs plumb while he leans (%s)" % bag)
	# G8 Runde 5: Fenner reaches well over his desk (its edge 0.24 m in front, the middle 0.6 m): the left hand on the
	# file stack, the right brings the stamp down onto the sheet and up again
	var my := _rig("ph_chr_v_mayor")
	var files := my.animation(&"desk_files")
	var low := INF
	var high := -INF
	var reach := {"arm_l": INF, "arm_r": INF}
	for k: int in 30:
		var h := my.hand(files, "arm_r", files.length * k / 30.0)
		low = minf(low, h.y)
		high = maxf(high, h.y)
		for arm: String in reach:
			reach[arm] = minf(reach[arm], my.hand(files, arm, files.length * k / 30.0).z)
	assert_true(low < 0.9 and low > 0.84 and high > 1.12, "the stamp comes down onto the desk and up again (%.2f … %.2f)" % [low, high])
	for arm: String in reach:
		assert_true(reach[arm] > 0.4, "%s always over the desk, not at its edge (%.2f m in front)" % [arm, reach[arm]])
	var notice := my.hand(my.animation(&"proclaim"), "arm_l", 0.3)
	assert_true(notice.y > 1.05 and notice.y < 1.3 and notice.z > 0.4, "the notice held at the chest (%s)" % notice)
	var wa := _rig("ph_chr_v_washer")
	var brook := wa.animation(&"wash_brook")
	var hips := wa.global_pose(brook, wa.skeleton.find_bone("hips"), 0.3).origin.y
	assert_true(hips < wa.global_rest(wa.skeleton.find_bone("hips")).origin.y - 0.3, "kneeling at the brook (hips %.2f)" % hips)
	assert_true(wa.hand(brook, "arm_r", 0.3).y < 0.5, "the cloth down on the stone")
	var pr := _rig("ph_chr_v_priest")
	var pray := pr.animation(&"pray_altar")
	assert_true(pr.hand(pray, "arm_r", pray.length * 0.4).y > 1.4 and pr.hand(pray, "arm_l", pray.length * 0.4).y > 1.4,
			"the arms rise above the altar (he faces the nave behind it)")
	assert_true(pr.hand(pray, "arm_l", pray.length * 0.4).x - pr.hand(pray, "arm_r", pray.length * 0.4).x > 0.8,
			"… spread wide: a gesture that reads from the front")
	assert_true(pr.global_pose(pray, pr.skeleton.find_bone("head"), pray.length * 0.8).basis.y.z > 0.25, "he bows deeply")


func test_props_on_their_bones_show_with_their_clip_and_sit_in_the_fist() -> void:
	for model: String in WORK:
		var r := _rig(model)
		var props: Dictionary = WORK[model].props
		for prop: String in props:
			var spec: Array = props[prop]
			var m := r.scene.find_child(prop, true, false) as MeshInstance3D
			assert_not_null(m, "%s: %s" % [model, prop])
			if m == null:
				continue
			var att := m.get_parent() as BoneAttachment3D
			assert_true(att != null and att.bone_name == spec[0], "%s/%s on %s" % [model, prop, spec[0]])
			assert_null(m.skin, "%s/%s is not skinned into the body" % [model, prop])
			assert_eq(Array(_show_with(m)), spec[1], "%s/%s shows with %s only" % [model, prop, spec[1]])
			assert_true(_tris(m.mesh) <= PROP_TRI_MAX, "%s/%s: %d tris" % [model, prop, _tris(m.mesh)])
			var anim := r.animation(StringName(spec[1][0]))
			var t := anim.length * float(spec[2])
			var bone := r.skeleton.find_bone(String(spec[0]))
			var c := Vector3.ZERO
			var verts: PackedVector3Array = m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				c += v
			c /= maxf(1.0, verts.size())
			var posed := r.global_pose(anim, bone, t) * m.transform * c
			var hand := r.hand(anim, String(spec[0]), t)
			assert_true(posed.distance_to(hand) < 0.16, "%s/%s in the fist (%.2f m)" % [model, prop, posed.distance_to(hand)])
	var osric := _rig("ph_chr_carter")
	var pipe := osric.scene.find_child("pipe_smoke", true, false) as Node3D
	assert_not_null(pipe, "Osric: marker pipe_smoke")
	if pipe != null:
		var att := pipe.get_parent() as BoneAttachment3D
		assert_true(att != null and att.bone_name == "head", "pipe_smoke follows the head")
		var p := osric.skeleton.get_bone_global_rest(osric.skeleton.find_bone("head")) * pipe.transform.origin
		assert_true(p.y > 1.2 and p.y < 1.5 and p.z > 0.15, "at the pipe bowl in front of his beard (%s)" % p)


## G8 Runde 5: Fenner's staff is the child mesh prop_staff in his right fist (every clip but desk_files: hide_with),
## while he works it leans against the end of his desk (prop_staff_rest on the root, show_with desk_files): the
## ferrule on the floor beyond the desk end (0.7 m to his right), the shaft over the edge of the top (0.79 m).
func test_fenner_leans_his_staff_against_the_desk() -> void:
	var r := _rig("ph_chr_v_mayor")
	var staff := r.scene.find_child("prop_staff", true, false) as MeshInstance3D
	var rest := r.scene.find_child("prop_staff_rest", true, false) as MeshInstance3D
	assert_not_null(staff, "prop_staff")
	assert_not_null(rest, "prop_staff_rest")
	if staff == null or rest == null:
		return
	assert_eq((staff.get_parent() as BoneAttachment3D).bone_name, "arm_r", "the staff in the right fist")
	assert_eq(String((staff.get_meta("extras") as Dictionary).get("hide_with", "")), "desk_files", "laid aside at the desk only")
	assert_false((staff.get_meta("extras") as Dictionary).has("show_with"), "shown in every other clip")
	assert_eq((rest.get_parent() as BoneAttachment3D).bone_name, "root", "the leaning staff stays where it is")
	assert_eq(Array(_show_with(rest)), ["desk_files"], "… shown while he works at the desk")
	var hand := r.hand(r.animation(&"idle"), "arm_r", 0.0)
	var xf := r.global_rest(r.skeleton.find_bone("arm_r")) * staff.transform
	var verts: PackedVector3Array = staff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v: Vector3 in verts:
		lo = lo.min(xf * v)
		hi = hi.max(xf * v)
	assert_true(lo.y < 0.03 and hi.y > 1.3, "the staff from the floor up to the knob (%.2f … %.2f)" % [lo.y, hi.y])
	assert_true(Vector2(hand.x, hand.z).distance_to(Vector2((lo.x + hi.x) * 0.5, (lo.z + hi.z) * 0.5)) < 0.08, "in the right hand")
	xf = r.global_rest(r.skeleton.find_bone("root")) * rest.transform
	verts = rest.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	lo = Vector3.INF
	hi = -Vector3.INF
	for v: Vector3 in verts:
		lo = lo.min(xf * v)
		hi = hi.max(xf * v)
	assert_true(absf(lo.y) < 0.03 and hi.y > 1.2, "it stands on the floor (%.2f … %.2f)" % [lo.y, hi.y])
	assert_true(lo.x < -0.9 and hi.x > -0.6 and hi.x < -0.45, "beside the desk end, leaning over its top (x %.2f … %.2f)" % [lo.x, hi.x])
	assert_true(lo.z > 0.55 and hi.z < 0.8, "at the desk, beside it (z %.2f … %.2f)" % [lo.z, hi.z])


## G8 Runde 5: the village church's altar (ph_int_altar_church) – Lenz stands behind it facing the nave: its cross
## stands at the front edge (towards the people; before, at the back, it covered his face from the game camera),
## the book lies open towards him; the chapel keeps ph_int_altar unchanged (cross at the back).
func test_church_altar_faces_the_nave() -> void:
	var tops := {}
	for name: String in ["ph_int_altar", "ph_int_altar_church"]:
		var scene := (load("res://assets/models/interior/%s.glb" % name) as PackedScene).instantiate() as Node3D
		var z := 0.0
		var n := 0
		for m: Node in scene.find_children("*", "MeshInstance3D", true, false):
			if String(m.name).begins_with("flame"):
				continue
			var xf := Transform3D.IDENTITY
			var up: Node = m
			while up != scene and up is Node3D:
				xf = (up as Node3D).transform * xf
				up = up.get_parent()
			var verts: PackedVector3Array = (m as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var w := xf * v
				if w.y > 1.65:     # only the top of the cross reaches this high (the candles end at 1.61 m)
					z += w.z
					n += 1
		tops[name] = z / maxf(1.0, n)
		assert_true(n > 0, name + ": the cross")
		scene.free()
	assert_true(tops["ph_int_altar"] < -0.2, "the chapel altar: cross at the back (z %.2f)" % tops["ph_int_altar"])
	assert_true(tops["ph_int_altar_church"] > 0.1, "the church altar: cross at the front edge (z %.2f)" % tops["ph_int_altar_church"])
	var church: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/interiors/church_layout.json"))
	for it: Dictionary in church.items:
		if it.get("id", "") == "Altar":
			assert_eq(it.asset, "ph_int_altar_church", "the church uses it")
	var wp: Array = church.waypoints.v_in_church_altar
	assert_eq(wp.size(), 4, "Lenz's spot carries the floor height of the chancel")
	assert_almost(float(wp[3]), 0.18, 0.001, "on the chancel")


func test_budgets() -> void:
	for model: String in WORK:
		if not model.begins_with("ph_chr_v_"):
			continue
		var r := _rig(model)
		var tris := 0
		for n: Node in r.scene.find_children("*", "MeshInstance3D", true, false):
			tris += _tris((n as MeshInstance3D).mesh)
		assert_true(tris <= VILLAGER_TRI_MAX, "%s: %d tris with the props (<= %d)" % [model, tris, VILLAGER_TRI_MAX])


func test_generators_are_deterministic() -> void:
	var work := FileAccess.get_file_as_string("res://tools/blender/asset_villager_work.py")
	assert_false(work.is_empty(), "tools/blender/asset_villager_work.py")
	assert_false(work.contains("import random") or work.contains("random."), "no randomness in the work clips")
	for model: String in WORK:
		if model.begins_with("ph_chr_v_"):
			assert_true(work.contains("\"%s\"" % model), "%s has its work clips in asset_villager_work.WORK" % model)
		for clip: String in WORK[model].clips:
			assert_true(work.contains("\"%s-loop\"" % clip) or FileAccess.get_file_as_string("res://tools/blender/asset_carter.py")
					.contains("\"%s-loop\"" % clip), clip + ": a -loop action")
	var vil := FileAccess.get_file_as_string("res://tools/blender/asset_villagers.py")
	assert_true(vil.contains("VW.build_for(name, arm, mesh)"), "asset_villagers adds the work clips after the older ones")
	assert_true(vil.contains("tuple(actions) + tuple(extra) + tuple(work)"), "… in that order (old clips first, keys unchanged)")
	assert_true(vil.contains("_stable_glb(path)"), "the re-export stays byte-stable")
	var carter := FileAccess.get_file_as_string("res://tools/blender/asset_carter.py")
	assert_true(carter.contains("rig.bone_marker(arm, \"head\", \"pipe_smoke\""), "Osric's smoke marker")
	assert_true(carter.contains("F._stable_glb("), "Osric's export stays byte-stable")


# --- helpers -----------------------------------------------------------------------------------------------

func _cfg() -> NpcWorkConfig:
	var cfg := Database.config(&"npc_work_config") as NpcWorkConfig
	assert_not_null(cfg, "data/config/npc_work_config.tres")
	return cfg if cfg != null else NpcWorkConfig.new()


func _entries_at(npc_id: StringName, wp: String) -> Array:
	var out: Array = []
	var sched := Database.schedule(npc_id) as NpcSchedule
	if sched == null:
		return out
	for e: ScheduleEntry in sched.entries:
		if e != null and e.visible and e.travel_minutes == 0 and not e.path.is_empty() and e.path[e.path.size() - 1] == wp:
			out.append(e)
	out.sort_custom(func(a: ScheduleEntry, b: ScheduleEntry) -> bool: return a.start_minute < b.start_minute)
	return out


## The heading a figure works in at `wp` (NpcWorkConfig.work_facing, else the layout facing `layout_deg`).
func _work_facing(wp: String, layout_deg: float) -> float:
	var cfg := _cfg()
	return float(cfg.work_facing[StringName(wp)]) if cfg.work_facing.has(StringName(wp)) else layout_deg


## Degrees between a layout facing (0 = +Z, as rot_y) and the direction `to` (x, z).
static func _angle_off(facing_deg: float, to: Vector2) -> float:
	var f := Vector2(sin(deg_to_rad(facing_deg)), cos(deg_to_rad(facing_deg)))
	return absf(rad_to_deg(f.angle_to(to.normalized()))) if to.length() > 0.001 else 0.0


func _rig(model: String) -> Chars.Rig:
	if not _rigs.has(model):
		_rigs[model] = Chars.Rig.new(MODEL_DIR + model + ".glb")
	return _rigs[model]


func _clips(model: String) -> Array:
	var out: Array = []
	var r := _rig(model)
	if r.player != null:
		for n: StringName in r.player.get_animation_list():
			out.append(String(n))
	return out


static func _show_with(m: Node) -> PackedStringArray:
	if m == null or not m.has_meta("extras"):
		return PackedStringArray()
	var ex: Dictionary = m.get_meta("extras")
	return String(ex.get("show_with", "")).split(",", false)


static func _tris(mesh: Mesh) -> int:
	var tris := 0
	for s: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris
