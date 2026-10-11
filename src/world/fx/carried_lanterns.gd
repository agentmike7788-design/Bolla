class_name CarriedLanterns
extends Node3D
## G8 Runde 2 (Lichtgang, user critique „die Laternen beim Lichtgang sind nur Leuchtpunkte"): the light of every
## lantern a figure carries (Npc child meshes lantern_prop / Jakob's lantern, shown with lantern_walk /
## lantern_idle; Npc puts them into GROUP). WorldRoot adds one of these at runtime (not saved, no state).
##   · Pool: the `pool_size` lanterns nearest the camera focus get a real OmniLight3D without shadow (ranked every
##     rank_interval s, the lights follow every frame and fade over fade_seconds when they change lantern). The
##     grave candles (GraveCare) give up one pool light per lantern light in use (candle_pool_min stay) – the scene
##     keeps its light budget (§9: ~13 lights in view, 2 with shadow).
##   · Fake light: every visible carried lantern lays a soft warm spot on the ground (one MultiMesh, additive,
##     lantern_spot.gdshader) – weaker under a lantern that has a pool light.
##   · Flicker: one FlickerProfile value per lantern and frame drives the flame (mat_emissive_warm), the glass
##     (mat_lantern_glass; every carried lantern gets its own copies of the two), the pool light and the spot – all
##     in step.
##   · Swing: walking, the lantern swings like a pendulum about its bail (two swings per gait cycle); standing it
##     sways a little. Only the mesh node turns (its rest transform is kept), no bone.
## Values: data/config/fx/carried_lanterns.tres (LanternLightConfig; *_compat for the browser renderer).

const GROUP := &"carried_lantern"
const POOL_GROUP := &"carried_lanterns"
const CONFIG_PATH := "res://data/config/fx/carried_lanterns.tres"
const PROFILE_PATH := "res://data/config/fx/%s.tres"
const SPOT_SHADER := "res://assets/shaders/lantern_spot.gdshader"
const FLAME_MATERIAL := "res://assets/materials/mat_emissive_warm.tres"
const GLASS_MATERIAL := "res://assets/materials/mat_lantern_glass.tres"
const ATMOSPHERE := ^"Atmosphere"
const PLAYER_GROUP := &"player"
## The spots of at most this many lanterns (more stay without a spot – the Lichtgang has ≤ 16 figures).
const MAX_SPOTS := 24

@export var config: LanternLightConfig

var _lights: Array[OmniLight3D] = []
## instance id → lantern state (see _track).
var _lanterns: Dictionary = {}
## The visible lanterns, nearest the focus first (re-ranked every rank_interval).
var _ranked: Array = []
var _rank_left: float = 0.0
var _t: float = 0.0
var _profile: FlickerProfile
var _spots: MultiMeshInstance3D
var _compat: bool = false


func _init() -> void:
	name = "CarriedLanterns"
	add_to_group(POOL_GROUP, true)


func _ready() -> void:
	if config == null:
		config = load(CONFIG_PATH) as LanternLightConfig if ResourceLoader.exists(CONFIG_PATH) else LanternLightConfig.new()
	_compat = RendererInfo.is_compat()
	var pp := PROFILE_PATH % config.flicker_profile
	_profile = load(pp) as FlickerProfile if ResourceLoader.exists(pp) else FlickerProfile.new()
	for i: int in config.pool_for(_compat):
		var light := OmniLight3D.new()
		light.name = "LanternLight%d" % i
		light.light_color = config.light_color
		light.light_energy = 0.0
		light.omni_range = config.light_range
		light.omni_attenuation = config.light_attenuation
		light.shadow_enabled = false
		light.light_specular = 0.2
		light.visible = false
		light.set_meta(&"lantern", 0)
		add_child(light)
		_lights.append(light)
	_spots = _make_spots()
	add_child(_spots)


func _process(delta: float) -> void:
	_t += delta
	_rank_left -= delta
	if _rank_left <= 0.0:
		_rank_left = config.rank_interval
		rank()
	_update(delta)


# --- public (GraveCare, tests, shots) ------------------------------------------------------------------------

## Pool lights giving light now (GraveCare leaves out as many candle lights).
func lights_in_use() -> int:
	var n := 0
	for light: OmniLight3D in _lights:
		if light.visible:
			n += 1
	return n


func pool_size() -> int:
	return _lights.size()


## The visible carried lanterns this frame (ranked, nearest first).
func visible_lanterns() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for st: Dictionary in _ranked:
		out.append(st.node)
	return out


## Spots drawn now (the visible instances of the MultiMesh).
func spot_count() -> int:
	return _spots.multimesh.visible_instance_count if _spots != null else 0


## World point of the glass centre of `lantern` (the light's place).
func lantern_center(lantern: Node3D) -> Vector3:
	var st := _track(lantern)
	return lantern.global_transform * (st.center as Vector3)


## The pool light of `lantern` (null = none).
func light_of(lantern: Node3D) -> OmniLight3D:
	for light: OmniLight3D in _lights:
		if light.visible and int(light.get_meta(&"lantern", 0)) == lantern.get_instance_id():
			return light
	return null


## Re-rank now and settle the fades (shots, tests: no waiting for the 2 Hz tick and the fade).
func settle() -> void:
	rank()
	for st: Dictionary in _ranked:
		st.real = 1.0 if st.wanted else 0.0
	_update(0.0)


## Ranks the visible carried lanterns by distance to the camera focus; the first pool_size want a light.
func rank() -> void:
	if not is_inside_tree():
		return
	var focus := _focus()
	var seen := {}
	var ranked: Array = []
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var lantern := node as Node3D
		if lantern == null or not lantern.is_visible_in_tree():
			continue
		var st := _track(lantern)
		var p := lantern.global_transform * (st.center as Vector3)
		st.dist = Vector2(p.x - focus.x, p.z - focus.z).length_squared()
		ranked.append(st)
		seen[lantern.get_instance_id()] = true
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.dist) < float(b.dist) or (float(a.dist) == float(b.dist) and int(a.id) < int(b.id)))
	for i: int in ranked.size():
		(ranked[i] as Dictionary).wanted = i < _lights.size()
	# gone lanterns: back to rest (their light fades out by itself – it is free again)
	for id: int in _lanterns.keys():
		if not seen.has(id):
			var st: Dictionary = _lanterns[id]
			st.real = 0.0
			st.wanted = false
			if not is_instance_valid(st.node):
				_lanterns.erase(id)
			else:
				_rest(st)
	_ranked = ranked


# --- per frame -----------------------------------------------------------------------------------------------

func _update(delta: float) -> void:
	var scale := _warm_scale()
	var fade := delta / maxf(config.fade_seconds, 0.001) if delta > 0.0 else 0.0
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var cam_pos := cam.global_position if cam != null else Vector3.ZERO
	var spot_e := config.spot_energy_for(_compat) * scale
	var light_e := config.light_energy_for(_compat) * scale
	var glass_e := config.glass_energy_for(_compat)
	var flame_e := config.flame_energy_for(_compat)
	# which lantern holds which light: keep the lights where they are, give free ones to new wanted lanterns
	var holder := {}
	for light: OmniLight3D in _lights:
		var id := int(light.get_meta(&"lantern", 0))
		if id == 0:
			continue
		# a light whose lantern no longer wants it and has faded out is free for the next one
		var held: Variant = _lanterns.get(id)
		if held != null and not bool((held as Dictionary).wanted) and float((held as Dictionary).real) <= 0.0:
			light.visible = false
			light.set_meta(&"lantern", 0)
			continue
		holder[id] = light
	var mm := _spots.multimesh
	var n := 0
	for st: Dictionary in _ranked:
		var lantern: Node3D = st.node
		if not is_instance_valid(lantern) or not lantern.is_visible_in_tree():
			continue
		var k := _profile.factor(int(st.seed), _t)
		var wanted := bool(st.wanted)
		var real := float(st.real)
		real = minf(real + fade, 1.0) if wanted else maxf(real - fade, 0.0)
		if delta < 0.0:
			real = 1.0 if wanted else 0.0
		st.real = real
		_swing(st, lantern, cam_pos)
		var center := lantern.global_transform * (st.center as Vector3)
		var mats: Array = st.mats
		if mats.size() == 2:
			if mats[0] != null:
				(mats[0] as ShaderMaterial).set_shader_parameter(&"glow_energy", flame_e * k)
			if mats[1] != null:
				(mats[1] as ShaderMaterial).set_shader_parameter(&"glow_energy", glass_e * k)
		# the pool light
		var light: OmniLight3D = holder.get(int(st.id))
		if light == null and wanted:
			light = _free_light()
			if light != null:
				light.set_meta(&"lantern", int(st.id))
				holder[int(st.id)] = light
		if light != null:
			if real <= 0.0 and not wanted:
				light.visible = false
				light.set_meta(&"lantern", 0)
				holder.erase(int(st.id))
			else:
				light.global_position = center
				light.light_energy = light_e * k * real
				light.visible = light.light_energy > 0.001
		# the fake spot on the ground under the lantern
		if n < MAX_SPOTS and spot_e > 0.001:
			var feet := float(st.ground)
			var r := config.spot_radius
			var basis := (st.tilt as Basis).scaled(Vector3(r, 1.0, r))
			mm.set_instance_transform(n, Transform3D(basis, Vector3(center.x, feet + config.spot_lift, center.z)))
			var w := spot_e * k * lerpf(1.0, config.spot_under_light_compat if _compat else config.spot_under_light, real)
			var c := config.spot_color
			mm.set_instance_color(n, Color(c.r * w, c.g * w, c.b * w, 1.0))
			n += 1
	# lights whose lantern is gone
	for light: OmniLight3D in _lights:
		var id := int(light.get_meta(&"lantern", 0))
		if id != 0 and not _visible_id(id):
			light.light_energy = maxf(light.light_energy - fade * light_e, 0.0)
			if light.light_energy <= 0.001 or delta <= 0.0:
				light.visible = false
				light.set_meta(&"lantern", 0)
	mm.visible_instance_count = n


func _visible_id(id: int) -> bool:
	var st: Variant = _lanterns.get(id)
	return st != null and is_instance_valid((st as Dictionary).node) and ((st as Dictionary).node as Node3D).is_visible_in_tree()


func _free_light() -> OmniLight3D:
	for light: OmniLight3D in _lights:
		if int(light.get_meta(&"lantern", 0)) == 0:
			return light
	return null


## Pendulum about the bail (walking) / a slow sway (standing); only near the camera.
func _swing(st: Dictionary, lantern: Node3D, cam_pos: Vector3) -> void:
	var parent := lantern.get_parent() as Node3D
	if parent == null:
		return
	var rest: Transform3D = st.rest
	if lantern.global_position.distance_squared_to(cam_pos) > config.swing_distance * config.swing_distance:
		if lantern.transform != rest:
			lantern.transform = rest
		return
	var deg := config.sway_degrees * sin(TAU * config.sway_frequency * _t + float(st.seed % 97))
	var anim := st.anim as AnimationPlayer
	if anim != null and is_instance_valid(anim) and anim.is_playing() and String(anim.current_animation).ends_with("_walk"):
		var length := anim.current_animation_length
		if length > 0.0:
			var phase := anim.current_animation_position / length
			deg = config.swing_degrees * sin(TAU * config.swings_per_cycle * phase)
	# the figure's side axis, in the lantern's rest space
	var carrier := st.carrier as Node3D
	var side_world := carrier.global_basis.x if carrier != null and is_instance_valid(carrier) else Vector3.RIGHT
	var rest_global := parent.global_transform * rest
	var axis := (rest_global.basis.inverse() * side_world).normalized()
	if axis.length_squared() < 0.5:
		return
	var pivot: Vector3 = st.pivot
	var turn := Transform3D(Basis(axis, deg_to_rad(deg)), Vector3.ZERO)
	lantern.transform = rest * Transform3D(Basis.IDENTITY, pivot) * turn * Transform3D(Basis.IDENTITY, -pivot)


func _rest(st: Dictionary) -> void:
	var lantern := st.node as Node3D
	if is_instance_valid(lantern):
		lantern.transform = st.rest


# --- bookkeeping ---------------------------------------------------------------------------------------------

## The state of a carried lantern: {id, node, seed, rest, pivot (bail top), center (glass), mats [flame, glass],
## anim, carrier, ground (feet height), tilt (ground basis), dist, wanted, real}.
func _track(lantern: Node3D) -> Dictionary:
	var id := lantern.get_instance_id()
	if _lanterns.has(id):
		var known: Dictionary = _lanterns[id]
		_ground(known)
		return known
	var aabb := AABB()
	var mi := lantern as MeshInstance3D
	if mi != null and mi.mesh != null:
		aabb = mi.mesh.get_aabb()
	var top := aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y, aabb.size.z * 0.5)
	var bottom := aabb.position + Vector3(aabb.size.x * 0.5, 0.0, aabb.size.z * 0.5)
	var st := {"id": id, "node": lantern, "seed": absi(hash(String(lantern.get_path()))) % 1000003,
		"rest": lantern.transform, "pivot": top, "center": bottom.lerp(top, 0.3), "mats": _own_materials(mi),
		"anim": null, "carrier": null, "ground": 0.0, "tilt": Basis.IDENTITY, "dist": 0.0, "wanted": false, "real": 0.0}
	var n: Node = lantern.get_parent()
	while n != null:
		if n.is_in_group(&"npc") or n.has_method(&"animation_player"):
			st.carrier = n as Node3D
			if n.has_method(&"animation_player"):
				st.anim = n.call(&"animation_player")
			break
		n = n.get_parent()
	_lanterns[id] = st
	_ground(st)
	return st


## Feet height and ground tilt under the lantern (the carrier's feet; the world's ground for the slope).
func _ground(st: Dictionary) -> void:
	var lantern := st.node as Node3D
	var carrier := st.carrier as Node3D
	var c := lantern.global_transform * (st.center as Vector3)
	var feet := carrier.global_position.y if carrier != null and is_instance_valid(carrier) else c.y - 0.55
	var world := get_parent()
	if world != null and world.has_method(&"ground_height"):
		var h0 := float(world.call(&"ground_height", Vector2(c.x, c.z)))
		var hx := float(world.call(&"ground_height", Vector2(c.x + 0.8, c.z)))
		var hz := float(world.call(&"ground_height", Vector2(c.x, c.z + 0.8)))
		if absf(h0 - feet) < 0.6:
			feet = h0
			var nx := Vector3(0.8, hx - h0, 0.0)
			var nz := Vector3(0.0, hz - h0, 0.8)
			var up := nz.cross(nx).normalized()
			if up.y > 0.8:
				var x := Vector3.RIGHT - up * up.dot(Vector3.RIGHT)
				x = x.normalized()
				st.tilt = Basis(x, up, x.cross(up).normalized())
	st.ground = feet


## Own copies of the flame and glass materials of `mi` (surface overrides) – [flame, glass] (null if absent).
func _own_materials(mi: MeshInstance3D) -> Array:
	var out: Array = [null, null]
	if mi == null or mi.mesh == null:
		return out
	for i: int in mi.mesh.get_surface_count():
		var mat := mi.mesh.surface_get_material(i)
		if mat == null:
			continue
		var slot := -1
		if mat.resource_path == FLAME_MATERIAL or mat.resource_name == "mat_emissive_warm":
			slot = 0
		elif mat.resource_path == GLASS_MATERIAL or mat.resource_name == "mat_lantern_glass":
			slot = 1
		if slot < 0 or not (mat is ShaderMaterial):
			continue
		var own := (mat as ShaderMaterial).duplicate() as ShaderMaterial
		own.set_shader_parameter(&"flicker_amount", 0.0)
		mi.set_surface_override_material(i, own)
		out[slot] = own
	return out


func _make_spots() -> MultiMeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = load(SPOT_SHADER) as Shader
	mat.resource_name = "mat_lantern_spot"
	# drawn before the other transparent surfaces (the grass blades are alpha-blended and lie over the spot)
	mat.render_priority = -10
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX_SPOTS
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-200.0, -50.0, -200.0), Vector3(400.0, 100.0, 400.0))
	var inst := MultiMeshInstance3D.new()
	inst.name = "LanternSpots"
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _focus() -> Vector3:
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D
	if player != null and player.is_inside_tree():
		return player.global_position
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## The atmosphere's warm light scale now (dusk 0.7, night 1.0, day 0.25); 1 without an atmosphere.
func _warm_scale() -> float:
	var world := get_parent()
	var atmo := world.get_node_or_null(ATMOSPHERE) if world != null else null
	if atmo != null and atmo.has_method(&"current"):
		var p := atmo.call(&"current") as AtmospherePreset
		if p != null:
			return p.warm_light_scale
	return 1.0
