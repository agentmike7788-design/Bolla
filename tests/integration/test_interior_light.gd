extends TestCase
## G7 round 1 (light, user critique "in den Häusern im Dorf ist es zu dunkel drinnen", "die Gruft ist
## auch zu dunkel"): every walk-in room keeps a minimum light by day and by night. Measured without a
## renderer: each room scene standalone, InteriorLighting.apply_daylight(t), then at probe points
## over the room floor (camera bounds centre and the four bound corners, 1.2 m high – faces and
## table tops) the illumination ambient (energy × luma) + Σ visible omni lights energy × luma ×
## (1 − d / range)^attenuation must reach the room's floor value; ≤ 8 visible omni lights per room
## (§9, also the Compatibility renderer's default limit per object), ≤ 2 with shadow, and every
## room has its soft fill light (role fill).

const ROOMS := ["inn", "surgery", "office", "church", "crypt", "chapel", "shed"]
const NEW_ROOMS := ["inn", "surgery", "office", "church", "crypt"]
const SCENE := "res://src/world/interiors/%s_interior.tscn"
## Minimum illumination (see the class comment) at night (t 0) and by day (t 1) – the values of the
## Phase-6 chapel and hut that the user approved lie above, the old village rooms below
## (before G7 round 1: office night 0.30, inn night 0.36).
const MIN_NIGHT := 0.55
const MIN_DAY := 0.9
const MAX_VISIBLE := 8


func _room(id: String) -> InteriorRoom:
	var room := (load(SCENE % id) as PackedScene).instantiate() as InteriorRoom
	tree.root.add_child(room)
	await tree.process_frame
	room.apply_room(StringName(id))
	if id in ["crypt", "chapel", "shed"]:
		room.apply_level(3)
	return room


func _lighting(room: InteriorRoom) -> InteriorLighting:
	for node: Node in room.get_children():
		if node is InteriorLighting:
			(node as InteriorLighting).set_process(false)
			return node as InteriorLighting
	return null


## The weakest illumination over the probe points of `room`.
static func min_illumination(room: InteriorRoom, env: Environment) -> float:
	var amb := env.ambient_light_energy * _luma(env.ambient_light_color)
	var lo := INF
	var c := (room.bounds_min + room.bounds_max) * 0.5
	var points: Array[Vector2] = [c, room.bounds_min, room.bounds_max, Vector2(room.bounds_min.x, room.bounds_max.y),
			Vector2(room.bounds_max.x, room.bounds_min.y)]
	for p2: Vector2 in points:
		var p := room.global_transform * Vector3(p2.x, 1.2, p2.y)
		var sum := amb
		for node: Node in room.find_children("*", "OmniLight3D", true, false):
			var l := node as OmniLight3D
			if not l.is_visible_in_tree() or l.light_energy <= 0.01:
				continue
			var d := l.global_position.distance_to(p)
			if d >= l.omni_range:
				continue
			sum += l.light_energy * _luma(l.light_color) * pow(1.0 - d / l.omni_range, l.omni_attenuation)
		lo = minf(lo, sum)
	return lo


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func test_rooms_keep_a_minimum_light_day_and_night() -> void:
	for id: String in ROOMS:
		var room: InteriorRoom = await _room(id)
		var lighting := _lighting(room)
		assert_not_null(lighting, id + ": InteriorLighting")
		if lighting == null:
			room.free()
			continue
		for t: float in [0.0, 1.0]:
			lighting.apply_daylight(t)
			var e := min_illumination(room, room.environment)
			print("[light] %s t=%.0f min illumination %.2f" % [id, t, e])
			if id in NEW_ROOMS:
				assert_true(e >= (MIN_NIGHT if t < 0.5 else MIN_DAY), "%s t=%.0f: illumination %.2f ≥ %.2f" % [id, t, e,
						MIN_NIGHT if t < 0.5 else MIN_DAY])
			var visible := 0
			var shadows := 0
			for node: Node in room.find_children("*", "Light3D", true, false):
				var l := node as Light3D
				if l is DirectionalLight3D or not l.is_visible_in_tree():
					continue
				visible += 1
				if l.shadow_enabled:
					shadows += 1
			assert_true(visible <= MAX_VISIBLE, "%s t=%.0f: ≤ %d visible lights (%d)" % [id, t, MAX_VISIBLE, visible])
			assert_true(shadows <= 2, "%s t=%.0f: ≤ 2 shadow lights (%d)" % [id, t, shadows])
		room.free()


func test_village_rooms_and_crypt_have_a_fill_light() -> void:
	for id: String in NEW_ROOMS:
		var room: InteriorRoom = await _room(id)
		var fills := room.find_children("*", "OmniLight3D", true, false).filter(
				func(n: Node) -> bool: return n.get_meta(&"interior_role", &"") == &"fill")
		assert_true(fills.size() >= 1, id + ": a soft fill light")
		for l: OmniLight3D in fills:
			assert_false(l.shadow_enabled, id + ": the fill light casts no shadow")
		var cfg := room.room_config()
		assert_true(cfg.fill_night_energy > 0.0 and cfg.fill_day_energy > 0.0, id + ": fill energies from data")
		room.free()
