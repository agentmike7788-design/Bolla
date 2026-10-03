class_name BuildingExterior
extends Node3D
## Outdoor dressing of a building site (docs/PHASE6_DESIGN.md §4.1, §4.2, §9), child "Exterior" of
## Entities/site_<id>: BuildingSite swaps its child "Model" at runtime (level 0…3), so the warm lights
## at the model's light_* markers are attached here (group warm_lights, never a shadow – the
## outdoor shadow budget stays at 4). Which lights burn:
## - crypt: the portal lantern (marker light_lantern, level 3 only) – like every lantern, the
##   atmosphere dims it by day;
## - chapel: the two window lights only while a service or devotion runs (ChapelAltar.rite_active)
##   and from level 3 at night; the soul lantern (child "SoulLantern", level 3) at night. From level
##   2 the bell mesh ("bell" in the model) swings for a few seconds when a rite starts and ends
##   (GDScript, no shader TIME – PERF-01; no sound, §13).
## Presentation only: the node reads the levels, the clock and the altar, it changes no game state.
## Gated lights keep base_energy 0 while off (the AtmosphereController derives energy and
## visibility from it every time it applies a preset).

const WARM_LIGHTS := &"warm_lights"
const BUILDINGS_GROUP := &"buildings"
const ALTAR_GROUP := &"chapel_altar"
const MODEL_NAME := "Model"
const BELL_NAME := "bell"
const SOUL_NAME := "SoulLantern"
const META_BASE := &"base_energy"
const META_ON := &"energy_on"
const FLICKER := preload("res://src/world/atmosphere/flicker_light.gd")
## Bell swing: amplitude (degrees), frequency (Hz) and duration (s) after a rite starts or ends.
const BELL_AMPLITUDE := 14.0
const BELL_HZ := 0.8
const BELL_SECONDS := 6.0
## Window lights sit this far outside the wall (m).
const WINDOW_OUT := 0.7

@export var building_id: StringName
## Marker name → light config {color, energy, range, flicker} (layout "lights", baked by the builder).
@export var lights: Dictionary = {}
## "always" (from the level that has the marker), "rite_or_night3" (chapel windows).
@export var light_rule: Dictionary = {}
## Level from which the soul lantern stands (0 = none).
@export var soul_level: int = 0

var _model_id: int = 0
var _was_rite: bool = false
var _swing_left: float = 0.0
var _swing_t: float = 0.0
var _bell: Node3D
var _bell_rest: Basis = Basis.IDENTITY


func _ready() -> void:
	EventBus.building_upgraded.connect(_on_changed.unbind(2))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	EventBus.world_ready.connect(_on_changed.unbind(1))
	EventBus.time_tick.connect(_on_time_tick.unbind(2))
	set_process(building_id == &"chapel")
	refresh.call_deferred()


## Re-attaches the marker lights when the site shows another model; applies the light rules.
func refresh() -> void:
	if not is_inside_tree():
		return
	var model := get_parent().get_node_or_null(NodePath(MODEL_NAME)) as Node3D
	var id := model.get_instance_id() if model != null else 0
	if id != _model_id:
		_model_id = id
		_bell = null
		if model != null:
			_attach(model)
			_bell = model.find_child(BELL_NAME, true, false) as Node3D
			if _bell != null:
				_bell_rest = _bell.basis
	var soul := get_node_or_null(NodePath(SOUL_NAME)) as Node3D
	if soul != null:
		var on := soul_level > 0 and level() >= soul_level and _site_visible()
		soul.visible = on
		soul.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_apply_rules()


## Buildings.level(building_id) (0 without a Buildings node).
func level() -> int:
	var b := get_tree().get_first_node_in_group(BUILDINGS_GROUP) if is_inside_tree() else null
	return int(b.call(&"level", building_id)) if b != null and b.has_method(&"level") else 0


## True while a service or devotion runs at the chapel altar.
func rite_active() -> bool:
	var altar := get_tree().get_first_node_in_group(ALTAR_GROUP) if is_inside_tree() else null
	return altar != null and bool(altar.get(&"rite_active"))


## The warm lights this node attached (current model + soul lantern).
func attached_lights() -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for node: Node in get_parent().find_children("Light_*", "OmniLight3D", true, false):
		if node.has_meta(META_ON):
			out.append(node as OmniLight3D)
	return out


## Seconds of bell swing left (tests / screenshots).
func bell_swinging() -> bool:
	return _swing_left > 0.0


func _process(delta: float) -> void:
	var rite := rite_active()
	if rite != _was_rite:
		_was_rite = rite
		_swing_left = BELL_SECONDS
		_apply_rules()
	if _bell == null or not is_instance_valid(_bell):
		return
	if _swing_left > 0.0:
		_swing_left = maxf(_swing_left - delta, 0.0)
		_swing_t += delta
		var fade := clampf(_swing_left / 1.5, 0.0, 1.0)
		var angle := deg_to_rad(BELL_AMPLITUDE) * sin(TAU * BELL_HZ * _swing_t) * fade
		_bell.basis = _bell_rest * Basis(Vector3.RIGHT, angle)
	elif _swing_t != 0.0:
		_swing_t = 0.0
		_bell.basis = _bell_rest


func _attach(model: Node3D) -> void:
	for marker: Node in model.find_children("light_*", "", true, false):
		var cfg: Dictionary = lights.get(String(marker.name), {})
		if cfg.is_empty():
			continue
		var xf := _rel(marker as Node3D, model)
		if String(marker.name).begins_with("light_window"):
			# The window markers sit in the wall plane: the glow goes outside onto the ground.
			xf.origin.x += signf(xf.origin.x) * WINDOW_OUT
		model.add_child(_make_light(String(marker.name), cfg, xf))


func _make_light(marker_name: String, cfg: Dictionary, xform: Transform3D) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "Light_" + marker_name.trim_prefix("light_")
	light.transform = xform
	light.light_color = Color(str(cfg.get("color", "#ffae55")))
	light.omni_range = float(cfg.get("range", 2.5))
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.set_meta(META_ON, float(cfg.get("energy", 1.0)))
	light.set_meta(META_BASE, 0.0)
	light.set_meta(&"marker", marker_name)
	light.light_energy = 0.0
	light.visible = false
	if bool(cfg.get("flicker", false)):
		light.set_script(FLICKER)
	light.add_to_group(WARM_LIGHTS, true)
	return light


func _apply_rules() -> void:
	var lvl := level()
	var night := TimeManager.is_night()
	var shown := _site_visible()
	for light: OmniLight3D in attached_lights():
		var rule := String(light_rule.get(String(light.get_meta(&"marker", "")), "always"))
		var on := shown and lvl >= 1
		match rule:
			"rite_or_night3":
				on = on and (rite_active() or (lvl >= 3 and night))
			"night":
				on = on and night
		var base := float(light.get_meta(META_ON)) if on else 0.0
		light.set_meta(META_BASE, base)
		var scale := float(light.get_meta(&"scale", 1.0))
		light.light_energy = base * scale
		light.visible = light.light_energy > 0.01


func _site_visible() -> bool:
	var site := get_parent() as Node3D
	return site != null and site.visible


func _on_changed() -> void:
	if is_inside_tree():
		refresh.call_deferred()


## Deferred: BuildingSite (the parent) refreshes on the same tick and connected after this child.
func _on_time_tick() -> void:
	if is_inside_tree():
		refresh.call_deferred()


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
