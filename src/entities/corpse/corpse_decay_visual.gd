class_name CorpseDecayVisual
extends Node3D
## Painted decay of one corpse (docs/PHASE4_DESIGN.md §2.5, §8, §9) – child "DecayVisual" of
## corpse.tscn. Pure presentation: Corpse passes the record's values into apply(); nothing here
## changes game state. No gore: a tint overlay, flies, smell wisps, juniper smoke.
## - Overlay: mat_decay_overlay (decay_overlay.gdshader) as material_overlay of every
##   MeshInstance3D under `target`, with the instance uniform `amount`. Continuous over the
##   freshness (piecewise linear, see overlay_for), minus washed_reduction when washed. At 0 the
##   overlay is removed (no extra draw call for fresh corpses).
## - Particles (CPUParticles3D, billboard, unshaded, no shadows): Flies (flies_by_stage),
##   Wisps (wisps_by_stage; none while a balm window runs) and Smoke (smoke_particles while
##   balm is active). At most DecayVisualConfig.max_emitting corpses emit at once (the rest
##   wait and take over when one stops); beyond visibility_range from the camera the emitters
##   are hidden and not processed.
## - QA (W3, G4): a subtle fly cloud (FlyCloud: one billboard quad of painted ink specks, no
##   particle) hovers over the body with the flies, so the flies read at the gameplay camera
##   distance (22 m) where the single flies are below a pixel; it fades with the fly count.

const OVERLAY_MATERIAL := preload("res://assets/materials/mat_decay_overlay.tres")
const FLY_MATERIAL := preload("res://assets/materials/mat_vfx_fly.tres")
const WISP_MATERIAL := preload("res://assets/materials/mat_vfx_wisp.tres")
const SMOKE_MATERIAL := preload("res://assets/materials/mat_vfx_smoke.tres")
## Painted textures of P5 (§8); used instead of the soft gradient stand-ins once they exist.
const FLY_ATLAS := "res://assets/vfx/ph_vfx_fly_atlas.png"
const WISP_TEXTURE := "res://assets/vfx/ph_vfx_stench_wisp.png"
const SMOKE_TEXTURE := "res://assets/vfx/ph_vfx_smoke_wisp.png"
const FLY_ATLAS_FRAMES := 4
const AMOUNT_PARAM := &"amount"
const STAGES: Array[StringName] = [&"fresh", &"wilted", &"decaying", &"rotten"]
## Seconds between the camera-distance checks.
const RANGE_CHECK_SECONDS := 0.5
## Fly cloud (QA W3): size (m), height over the body, ink colour, opacity at 10 flies, bobbing.
const CLOUD_SIZE := Vector2(1.25, 0.6)
const CLOUD_HEIGHT := 0.5
const CLOUD_COLOR := Color("1F2A3A")
const CLOUD_ALPHA := 0.6
const CLOUD_FULL_FLIES := 10
const CLOUD_BOB := 0.05
## QA (W3, G4): P5's wisp / smoke are painted in a mid olive / grey as dark as the lawn; their
## colours are lifted this far towards white (alpha and brush strokes kept) so the tint of
## wisp_color / smoke_color reads on grass at the gameplay distance.
const WISP_LIFT := 0.55

## null = Database (data/config/decay_visual_config.tres) → class defaults.
var config: DecayVisualConfig
## Stage thresholds of the overlay curve; null = EconomyConfig.resolve().
var economy: EconomyConfig
## Model whose meshes get the overlay (Corpse sets its model; null = none).
var target: Node3D

var flies_node: CPUParticles3D
var wisps_node: CPUParticles3D
var smoke_node: CPUParticles3D
var cloud_node: MeshInstance3D

## Visuals that currently emit / wait for a free emitter slot (max_emitting).
static var _emitting: Array[CorpseDecayVisual] = []
static var _waiting: Array[CorpseDecayVisual] = []
static var _textures: Dictionary = {}

var _amount: float = 0.0
var _flies: int = 0
var _wisps: int = 0
var _smoke: bool = false
var _in_range: bool = true
var _range_left: float = 0.0
var _colours_for: DecayVisualConfig
var _cloud_time: float = 0.0
static var _cloud_material: StandardMaterial3D


func _init() -> void:
	name = "DecayVisual"
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_waiting.erase(self)
		if _emitting.has(self):
			_emitting.erase(self)
			_promote(_config().max_emitting)
	elif what == NOTIFICATION_EXIT_TREE:
		_release()
	elif what == NOTIFICATION_ENTER_TREE:
		_claim()


func _process(delta: float) -> void:
	if not is_emitting():
		return
	if cloud_node.visible:
		_cloud_time += delta
		cloud_node.position = Vector3(sin(_cloud_time * 0.7) * 0.06, CLOUD_HEIGHT + sin(_cloud_time * 1.9) * CLOUD_BOB, 0.0)
	_range_left -= delta
	if _range_left > 0.0:
		return
	_range_left = RANGE_CHECK_SECONDS
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var in_range := camera == null or camera.global_position.distance_to(global_position) <= _config().visibility_range
	if in_range != _in_range:
		_in_range = in_range
		_sync_particles()


## Presentation of the record's decay (Corpse: on corpse_updated and hour_changed).
func apply(freshness: float, stage: StringName, balm_active: bool, washed: bool) -> void:
	var cfg := _config()
	var st := stage if stage in STAGES else STAGES[0]
	var amount := overlay_for(freshness, cfg, _economy())
	if washed:
		amount -= cfg.washed_reduction
	_amount = clampf(amount, 0.0, 1.0)
	_flies = maxi(0, int(cfg.flies_by_stage.get(st, 0)))
	_wisps = 0 if balm_active else maxi(0, int(cfg.wisps_by_stage.get(st, 0)))
	_smoke = balm_active and cfg.smoke_particles > 0
	if _colours_for != cfg:
		_apply_colours()
	_apply_overlay()
	if wants_to_emit():
		_claim()
	else:
		_release()
	_sync_particles()


func overlay_amount() -> float:
	return _amount


func flies() -> int:
	return _flies


func wisps() -> int:
	return _wisps


func smoke_on() -> bool:
	return _smoke


# --- helpers (public, not part of the contract) ------------------------------------------

## Flies, wisps or smoke wanted (whether or not an emitter slot is free).
func wants_to_emit() -> bool:
	return _flies > 0 or _wisps > 0 or _smoke


## Holds one of the max_emitting slots.
func is_emitting() -> bool:
	return _emitting.has(self)


## Particles currently shown (0 while waiting for a slot or out of range).
func live_particles() -> int:
	var n := 0
	for p: CPUParticles3D in [flies_node, wisps_node, smoke_node]:
		if p.emitting:
			n += p.amount
	return n


## Sets the model whose meshes carry the overlay (the previous one loses it).
func set_target(model: Node3D) -> void:
	if target != null and is_instance_valid(target) and target != model:
		_set_overlay(target, null, 0.0)
	target = model
	_apply_overlay()


## Overlay strength at `freshness`, continuous and monotone: 0 while fresh; each stage's
## overlay_by_stage value is reached in the middle of its freshness range (wilted 0.3…0.6 →
## 0.45, decaying 0.1…0.3 → 0.2, rotten below 0.1 → 0.05), linear in between, clamped below.
static func overlay_for(freshness: float, cfg: DecayVisualConfig, economy: EconomyConfig) -> float:
	var e := EconomyConfig.resolve(economy)
	var good := e.fresh_good_threshold
	var bad := e.fresh_bad_threshold
	var rot := e.rot_threshold
	var points: Array[Vector2] = [
		Vector2(good, float(cfg.overlay_by_stage.get(&"fresh", 0.0))),
		Vector2((good + bad) * 0.5, float(cfg.overlay_by_stage.get(&"wilted", 0.0))),
		Vector2((bad + rot) * 0.5, float(cfg.overlay_by_stage.get(&"decaying", 0.0))),
		Vector2(rot * 0.5, float(cfg.overlay_by_stage.get(&"rotten", 0.0))),
	]
	if freshness >= points[0].x:
		return points[0].y
	for i: int in range(1, points.size()):
		if freshness >= points[i].x:
			var a := points[i - 1]
			var b := points[i]
			return lerpf(b.y, a.y, (freshness - b.x) / maxf(a.x - b.x, 0.000001))
	return points[points.size() - 1].y


## Particles of all visuals right now (§9 budget ≤ 60).
static func total_live_particles() -> int:
	var n := 0
	for v: CorpseDecayVisual in _emitting:
		if is_instance_valid(v):
			n += v.live_particles()
	return n


# --- internals ---------------------------------------------------------------------------

func _build() -> void:
	flies_node = _make_emitter("Flies", FLY_MATERIAL, FLY_ATLAS, Vector2(0.1, 0.1))
	wisps_node = _make_emitter("Wisps", WISP_MATERIAL, WISP_TEXTURE, Vector2(0.59, 0.59))
	smoke_node = _make_emitter("Smoke", SMOKE_MATERIAL, SMOKE_TEXTURE, Vector2(0.36, 0.59))
	cloud_node = _make_cloud()
	# Flies: dart around above the body (the corpses lie along local X, ~1.8 × 0.6 m).
	flies_node.position = Vector3(0.0, 0.35, 0.0)
	flies_node.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies_node.emission_box_extents = Vector3(0.7, 0.18, 0.25)
	flies_node.lifetime = 1.4
	flies_node.preprocess = 2.0
	flies_node.direction = Vector3(1, 0.2, 0)
	flies_node.spread = 180.0
	flies_node.initial_velocity_min = 0.25
	flies_node.initial_velocity_max = 0.6
	flies_node.angular_velocity_min = 0.0
	flies_node.tangential_accel_min = -1.2
	flies_node.tangential_accel_max = 1.2
	flies_node.radial_accel_min = -0.9
	flies_node.radial_accel_max = -0.4
	flies_node.damping_min = 0.2
	flies_node.damping_max = 0.6
	flies_node.scale_amount_min = 0.7
	flies_node.scale_amount_max = 1.0
	flies_node.color_ramp = _ramp(Color(1, 1, 1, 0), Color(1, 1, 1, 1), 0.15)
	if _uses_texture(FLY_ATLAS):
		flies_node.anim_speed_min = 6.0
		flies_node.anim_speed_max = 9.0
	# Wisps: slow, curling rise from the body, fading out.
	wisps_node.position = Vector3(0.0, 0.3, 0.0)
	wisps_node.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps_node.emission_box_extents = Vector3(0.55, 0.05, 0.15)
	wisps_node.lifetime = 6.0
	wisps_node.preprocess = 6.0
	wisps_node.direction = Vector3(0, 1, 0)
	wisps_node.spread = 20.0
	wisps_node.initial_velocity_min = 0.09
	wisps_node.initial_velocity_max = 0.15
	wisps_node.tangential_accel_min = -0.05
	wisps_node.tangential_accel_max = 0.05
	wisps_node.angle_min = -40.0
	wisps_node.angle_max = 40.0
	wisps_node.angular_velocity_min = -12.0
	wisps_node.angular_velocity_max = 12.0
	wisps_node.scale_amount_min = 0.8
	wisps_node.scale_amount_max = 1.0
	wisps_node.scale_amount_curve = _grow_curve(0.55)
	# Smoke: a thin juniper thread rising at the table edge (smoke bowl, W-Welt) and drifting
	# over the body.
	smoke_node.position = Vector3(0.55, 0.12, -0.38)
	smoke_node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke_node.emission_sphere_radius = 0.04
	smoke_node.lifetime = 5.0
	smoke_node.preprocess = 5.0
	smoke_node.direction = Vector3(-0.15, 1, -0.2)
	smoke_node.spread = 12.0
	smoke_node.initial_velocity_min = 0.1
	smoke_node.initial_velocity_max = 0.16
	smoke_node.angle_min = -25.0
	smoke_node.angle_max = 25.0
	smoke_node.angular_velocity_min = -8.0
	smoke_node.angular_velocity_max = 8.0
	smoke_node.scale_amount_min = 0.85
	smoke_node.scale_amount_max = 1.0
	smoke_node.scale_amount_curve = _grow_curve(0.35)
	_apply_colours()


func _make_emitter(node_name: String, base: StandardMaterial3D, texture_path: String, size: Vector2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.emitting = false
	p.visible = false
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.amount = 1
	p.local_coords = true
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.fixed_fps = 30
	p.draw_order = CPUParticles3D.DRAW_ORDER_INDEX
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = _material(base, texture_path)
	p.mesh = quad
	add_child(p)
	return p


## The fly cloud: one billboard quad (unshaded, transparent, no shadow), hidden until flies come.
func _make_cloud() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "FlyCloud"
	var quad := QuadMesh.new()
	quad.size = CLOUD_SIZE
	if _cloud_material == null:
		_cloud_material = StandardMaterial3D.new()
		_cloud_material.resource_name = "mat_vfx_fly_cloud"
		_cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_cloud_material.billboard_keep_scale = true
		_cloud_material.albedo_color = CLOUD_COLOR
		_cloud_material.albedo_texture = cloud_texture()
		_cloud_material.disable_receive_shadows = true
	quad.material = _cloud_material
	m.mesh = quad
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	m.position = Vector3(0.0, CLOUD_HEIGHT, 0.0)
	m.visible = false
	add_child(m)
	return m


## ph_vfx_fly_cloud: ~46 soft ink specks in a loose oval (white, alpha only; the material tints
## them), denser towards the middle. Deterministic, 128 × 64, mipmapped – from afar the specks
## melt into a faint dark shimmer, close up they are single flies.
static func cloud_texture() -> ImageTexture:
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	for i: int in 46:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.9
		var cx := w * 0.5 + cos(ang) * r * w * 0.46
		var cy := h * 0.5 + sin(ang) * r * h * 0.4
		var rad := rng.randf_range(1.2, 2.1)
		for y: int in range(maxi(0, floori(cy - 3.0)), mini(h, ceili(cy + 3.0))):
			for x: int in range(maxi(0, floori(cx - 3.0)), mini(w, ceili(cx + 3.0))):
				var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
				var a := clampf(1.0 - (d - rad * 0.5) / rad, 0.0, 1.0)
				if a > img.get_pixel(x, y).a:
					img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## The base material with P5's painted texture once it exists; until then wisps and smoke get
## a brushed curl stroke painted in code (ph_ stand-in), flies keep the soft speck of the .tres.
static func _material(base: StandardMaterial3D, texture_path: String) -> StandardMaterial3D:
	var has_png := _uses_texture(texture_path)
	if not has_png and texture_path == FLY_ATLAS:
		return base
	var key := base.resource_path + "|" + texture_path + ("" if has_png else "|ph")
	if not _textures.has(key):
		var mat := base.duplicate() as StandardMaterial3D
		if has_png and texture_path in [WISP_TEXTURE, SMOKE_TEXTURE]:
			mat.albedo_texture = lifted_texture(load(texture_path) as Texture2D, WISP_LIFT)
		elif has_png:
			mat.albedo_texture = load(texture_path) as Texture2D
		else:
			mat.albedo_texture = curl_texture(texture_path == SMOKE_TEXTURE)
		if has_png and texture_path == FLY_ATLAS:
			mat.particles_anim_h_frames = FLY_ATLAS_FRAMES
			mat.particles_anim_loop = true
		_textures[key] = mat
	return _textures[key]


## A copy of `tex` with its colours lifted `amount` towards white (alpha unchanged), mipmapped.
static func lifted_texture(tex: Texture2D, amount: float) -> Texture2D:
	var img := tex.get_image() if tex != null else null
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.clear_mipmaps()
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(lerpf(c.r, 1.0, amount), lerpf(c.g, 1.0, amount), lerpf(c.b, 1.0, amount), c.a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## ph_vfx_curl: a soft, brushed curl stroke (white, alpha only) – smell wisp (two loose
## S-strokes) or juniper smoke (tall wavy thread). Deterministic, 64 × 64.
static func curl_texture(thread: bool) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7 if thread else 3
	noise.frequency = 0.09
	for y: int in n:
		for x: int in n:
			var u := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var v := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var t := (1.0 - v) * 0.5
			var d: float
			var width: float
			if thread:
				# Thread rising from the bottom, swaying, widening and fading towards the top.
				var cx := sin(t * 5.5) * 0.25 * t
				d = absf(u - cx)
				width = lerpf(0.12, 0.3, t)
			else:
				# A loose, curling breath: two soft S-strokes side by side.
				var c1 := sin(t * 4.2 + 0.6) * 0.3 - 0.12
				var c2 := sin(t * 3.4 + 2.2) * 0.26 + 0.18
				d = minf(absf(u - c1), absf(u - c2) * 1.3)
				width = lerpf(0.2, 0.34, t)
			var edge := clampf(1.0 - Vector2(u * 0.9, v).length(), 0.0, 1.0)
			var brush := 0.75 + 0.25 * noise.get_noise_2d(float(x), float(y))
			var a := exp(-(d * d) / (width * width)) * smoothstep(0.0, 0.5, edge) * brush * 0.85
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _uses_texture(path: String) -> bool:
	return ResourceLoader.exists(path)


func _apply_colours() -> void:
	var cfg := _config()
	_colours_for = cfg
	wisps_node.color_ramp = _ramp(Color(cfg.wisp_color, 0.0), cfg.wisp_color, 0.3)
	smoke_node.color_ramp = _ramp(Color(cfg.smoke_color, 0.0), cfg.smoke_color, 0.2)
	for node: Node in [wisps_node, smoke_node]:
		var p := node as CPUParticles3D
		p.visibility_range_end = cfg.visibility_range
	flies_node.visibility_range_end = cfg.visibility_range
	cloud_node.visibility_range_end = cfg.visibility_range


## Fade in over `rise`, hold, fade out over the last third.
static func _ramp(clear: Color, full: Color, rise: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, rise, 0.66, 1.0])
	g.colors = PackedColorArray([clear, full, full, clear])
	return g


static func _grow_curve(start: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, start))
	c.add_point(Vector2(1.0, 1.0))
	return c


func _sync_particles() -> void:
	var active := is_emitting() and _in_range
	_set_emitter(flies_node, _flies if active else 0)
	_set_emitter(wisps_node, _wisps if active else 0)
	_set_emitter(smoke_node, _config().smoke_particles if active and _smoke else 0)
	var cloud := active and _flies > 0
	cloud_node.visible = cloud
	if cloud:
		cloud_node.transparency = 1.0 - CLOUD_ALPHA * clampf(float(_flies) / CLOUD_FULL_FLIES, 0.0, 1.0)


func _set_emitter(p: CPUParticles3D, count: int) -> void:
	if count <= 0:
		if p.emitting or p.visible:
			p.emitting = false
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if p.amount != count:
		p.amount = count
	p.process_mode = Node.PROCESS_MODE_INHERIT
	p.visible = true
	if not p.emitting:
		p.emitting = true


func _claim() -> void:
	if not wants_to_emit() or _emitting.has(self):
		return
	if _emitting.size() < _config().max_emitting:
		_waiting.erase(self)
		_emitting.append(self)
	elif not _waiting.has(self):
		_waiting.append(self)


func _release() -> void:
	_waiting.erase(self)
	if not _emitting.has(self):
		return
	_emitting.erase(self)
	_sync_particles()
	_promote(_config().max_emitting)


## Waiting visuals take free emitter slots (first come, first served).
static func _promote(max_emitting: int) -> void:
	while not _waiting.is_empty() and _emitting.size() < max_emitting:
		var next: CorpseDecayVisual = _waiting.pop_front()
		if is_instance_valid(next) and next.wants_to_emit():
			_emitting.append(next)
			next._sync_particles()


func _apply_overlay() -> void:
	if target != null and is_instance_valid(target):
		_set_overlay(target, OVERLAY_MATERIAL if _amount > 0.0 else null, _amount)


static func _set_overlay(model: Node, material: Material, amount: float) -> void:
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_overlay = material
		if material != null:
			mesh.set_instance_shader_parameter(AMOUNT_PARAM, amount)


func _config() -> DecayVisualConfig:
	if config == null:
		config = Database.config(&"decay_visual_config") as DecayVisualConfig
		if config == null:
			config = DecayVisualConfig.new()
	return config


func _economy() -> EconomyConfig:
	if economy == null:
		economy = EconomyConfig.resolve()
	return economy
