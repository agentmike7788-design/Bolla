class_name Ghost
extends Node3D
## One pooled ghost (docs/PHASE3_DESIGN.md §2.8, §3.4; at most GhostConfig.max_active exist).
## Model ph_chr_ghost (placeholder shroud mesh until P5's asset exists) with mat_ghost, an
## OmniLight "soul light" (cold, no shadow, glows in the volumetric fog), an Interactable
## (priority 15, "[E] Zuhören – <Name> wirkt zufrieden/gleichmütig/unruhig") and a Label3D
## speech bubble. GhostManager binds it to a grave and drives mood and fade; the ghost only
## moves itself: hovers 0.3–0.6 m over the mound (bob 0.08 m / 3 s) – content: still at the
## head end, soul light held up · calm: drifts slowly within wander_radius · restless: circles
## the grave and flickers (shader `unrest`). Within face_radius it turns to the player.
## No collision, no following beyond its grave.

const MODEL_PATH := "res://assets/models/characters/ph_chr_ghost.glb"
const MATERIAL_PATH := "res://assets/materials/mat_ghost.tres"
const MANAGER_GROUP := &"ghosts"
const PLAYER_GROUP := &"player"
const SOUL_MARKER := "light_soul"
const PROMPT := "[E] Zuhören – %s wirkt %s"
const NAME_FALLBACK := "Der Geist"
## Interaction needs at least this much fade (a ghost that has barely appeared is not addressable).
const MIN_INTERACT_FADE := 0.5

## Hover over the mound (m) and its bob.
@export var hover_min: float = 0.3
@export var hover_max: float = 0.6
@export var bob_amplitude: float = 0.08
@export var bob_period: float = 3.0
## Plot-local spot of a content ghost (head end, −Z) and the centre of calm / restless motion.
@export var head_offset: Vector3 = Vector3(0, 0, -1.45)
@export var centre_offset: Vector3 = Vector3(0, 0, 0)
## Radius of the restless circle (m).
@export var circle_radius: float = 1.5
@export var turn_speed: float = 3.0
## Soul light (§2.8): #6FE3D2, 0.5, 2.5 m, no shadow, lights the volumetric fog.
@export var light_color: Color = Color("#6FE3D2")
@export var light_energy: float = 0.5
@export var light_range: float = 2.5
@export var light_fog_energy: float = 1.0
## Soul light local position (without model marker) and its lift when content.
@export var soul_offset: Vector3 = Vector3(0, 0.95, 0.4)
@export var soul_lift: float = 0.22
## The small glowing orb of the soul light.
@export var orb_color: Color = Color(0.82, 1.0, 0.95, 0.9)
## Speech bubble above the ghost's hood (body-local).
@export var bubble_height: float = 1.95

var grave_id: String = ""
var mood: StringName = &""
var display_name: String = ""
var fade: float = 0.0
## Set by GhostManager (else looked up in group "ghosts").
var manager: Node
var config: GhostConfig

var _anchor: Transform3D = Transform3D.IDENTITY
var _time: float = 0.0
var _phase: float = 0.0
var _angle: float = 0.0
var _bubble_left: float = 0.0
var _geometry: Array[GeometryInstance3D] = []
var _soul_base: Vector3 = Vector3.ZERO
var _orb: MeshInstance3D
var _orb_material: StandardMaterial3D

@onready var body: Node3D = $Body
@onready var soul_light: OmniLight3D = $Body/SoulLight
@onready var bubble: Label3D = $Body/Bubble
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	_build_model()
	soul_light.light_color = light_color
	soul_light.omni_range = light_range
	soul_light.shadow_enabled = false
	soul_light.light_volumetric_fog_energy = light_fog_energy
	bubble.visible = false
	bubble.position = Vector3(0, bubble_height, 0)
	set_mood(mood if mood != &"" else GhostMood.CALM)
	set_fade(fade)


func _process(delta: float) -> void:
	_time += delta
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			bubble.visible = false
	if not visible or grave_id == "":
		return
	for g: GeometryInstance3D in _geometry:
		g.set_instance_shader_parameter(&"anim_time", _time)
	_move(delta)


## Places the ghost at its grave (anchor = the plot's global transform; −Z = head end).
func bind(p_grave_id: String, anchor: Transform3D, p_display_name: String) -> void:
	grave_id = p_grave_id
	display_name = p_display_name
	_anchor = anchor
	_phase = float(absi(hash(p_grave_id)) % 1000) / 1000.0 * TAU
	_angle = _phase
	_time = 0.0
	for g: GeometryInstance3D in _geometry:
		g.set_instance_shader_parameter(&"phase", _phase)
	global_transform = Transform3D(anchor.basis.orthonormalized(), anchor.origin) if is_inside_tree() else anchor
	if body != null:
		body.position = _local_target(0.0)
		interactable.position = Vector3(body.position.x, 0.0, body.position.z)
	bubble_hide()


func set_mood(m: StringName) -> void:
	mood = m
	var unrest := 1.0 if m == GhostMood.RESTLESS else (0.15 if m == GhostMood.CALM else 0.0)
	for g: GeometryInstance3D in _geometry:
		g.set_instance_shader_parameter(&"unrest", unrest)
	var soul := _soul_base + Vector3(0, soul_lift if m == GhostMood.CONTENT else 0.0, 0)
	if soul_light != null:
		soul_light.position = soul
	if _orb != null:
		_orb.position = soul


## 0..1 – shader fade, light energy, visibility; addressable from MIN_INTERACT_FADE.
func set_fade(alpha: float) -> void:
	fade = clampf(alpha, 0.0, 1.0)
	visible = fade > 0.001
	for g: GeometryInstance3D in _geometry:
		g.set_instance_shader_parameter(&"fade", fade)
	if soul_light != null:
		soul_light.light_energy = light_energy * fade
		soul_light.visible = fade > 0.001
	if _orb_material != null:
		_orb_material.albedo_color.a = orb_color.a * fade
	if interactable != null:
		interactable.enabled = fade >= MIN_INTERACT_FADE
		interactable.monitorable = fade >= MIN_INTERACT_FADE
	if not visible:
		bubble_hide()


func say(text: String, seconds: float) -> void:
	if text == "":
		return
	bubble.text = text
	bubble.visible = true
	_bubble_left = maxf(seconds, 0.1)


func bubble_hide() -> void:
	_bubble_left = 0.0
	if bubble != null:
		bubble.visible = false


func is_speaking() -> bool:
	return bubble != null and bubble.visible


func can_interact(player: Player) -> bool:
	return grave_id != "" and fade >= MIN_INTERACT_FADE and player != null and not player.is_busy()


func get_interaction_prompt(_player: Player) -> String:
	if grave_id == "" or fade < MIN_INTERACT_FADE:
		return ""
	var who := display_name if display_name != "" else NAME_FALLBACK
	return PROMPT % [who, GhostMood.label(mood)]


## Instant (no timed action, the clock keeps running): the manager picks the line (and the
## one-time gift), the bubble shows it for bubble_seconds.
func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var m := _manager()
	if m == null:
		return
	var text := String(m.call(&"listen", grave_id, player))
	var cfg := _config()
	say(text, cfg.bubble_seconds)


## World position of the ghost's body (for nearest-selection and tests).
func body_position() -> Vector3:
	return body.global_position if body != null and body.is_inside_tree() else global_position


# --- motion -----------------------------------------------------------------------------

func _move(delta: float) -> void:
	var target := _local_target(delta)
	body.position = target
	interactable.position = Vector3(target.x, 0.0, target.z)
	var desired_yaw := body.rotation.y
	var player := _player()
	var cfg := _config()
	if player != null and player.global_position.distance_to(body.global_position) <= cfg.face_radius:
		var to_player := global_transform.affine_inverse() * player.global_position - body.position
		desired_yaw = atan2(to_player.x, to_player.z)
	elif mood == GhostMood.RESTLESS:
		desired_yaw = atan2(-sin(_angle), cos(_angle) * 0.8)  # along the circle
	elif mood == GhostMood.CONTENT:
		desired_yaw = 0.0
	body.rotation.y = lerp_angle(body.rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))


## Plot-local body position after advancing the motion by `delta`.
func _local_target(delta: float) -> Vector3:
	var cfg := _config()
	var h := (hover_min + hover_max) * 0.5 + sin(TAU * _time / maxf(bob_period, 0.1) + _phase) * bob_amplitude
	h = clampf(h, hover_min - bob_amplitude, hover_max + bob_amplitude)
	var speed: float = cfg.speeds.get(mood, 0.0)
	match mood:
		GhostMood.RESTLESS:
			var r := maxf(circle_radius, 0.1)
			_angle += speed / r * delta
			return centre_offset + Vector3(cos(_angle) * r, h, sin(_angle) * r * 0.8)
		GhostMood.CALM:
			var r := minf(cfg.wander_radius, 2.0) * 0.6
			var w := speed / maxf(r, 0.1)
			var t := _time * w + _phase
			return centre_offset + Vector3(sin(t) * r, h, sin(t * 0.73 + 1.1) * r * 0.8)
	return head_offset + Vector3(0, h, 0)


# --- model ------------------------------------------------------------------------------

func _build_model() -> void:
	var holder := body.get_node_or_null(^"Model") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Model"
		body.add_child(holder)
	for child: Node in holder.get_children():
		child.queue_free()
	var mat := load(MATERIAL_PATH) as Material
	var soul_marker: Node3D = null
	if ResourceLoader.exists(MODEL_PATH):
		var scene := load(MODEL_PATH) as PackedScene
		if scene != null:
			var model := scene.instantiate() as Node3D
			holder.add_child(model)
			soul_marker = model.find_child(SOUL_MARKER, true, false) as Node3D
	if holder.get_child_count() == 0:
		var mesh := MeshInstance3D.new()
		mesh.name = "ph_ghost_placeholder"
		mesh.mesh = GhostPlaceholderMesh.build()
		holder.add_child(mesh)
	_geometry.clear()
	for node: Node in holder.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.material_override = mat
		g.set_instance_shader_parameter(&"phase", _phase)
		_geometry.append(g)
	_soul_base = body.to_local(soul_marker.global_position) if soul_marker != null and soul_marker.is_inside_tree() else soul_offset
	_orb = body.get_node_or_null(^"SoulOrb") as MeshInstance3D
	if _orb != null:
		_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_orb_material = StandardMaterial3D.new()
		_orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_orb_material.albedo_color = orb_color
		_orb.material_override = _orb_material
	soul_light.position = _soul_base


func _manager() -> Node:
	if is_instance_valid(manager):
		return manager
	return get_tree().get_first_node_in_group(MANAGER_GROUP) if is_inside_tree() else null


func _player() -> Player:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Player if is_inside_tree() else null


func _config() -> GhostConfig:
	if config == null:
		config = Database.config(&"ghost_config") as GhostConfig
		if config == null:
			config = GhostConfig.new()
	return config
