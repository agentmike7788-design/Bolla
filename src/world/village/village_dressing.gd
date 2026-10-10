extends Node
## Runtime dressing of Hollerbrück (docs/PHASE7_DESIGN.md §4.7, §9), child "Dressing" of the village
## RegionRoot (village.tscn). Presentation only – it changes no game state:
## - the ground mesh only receives shadows and the foliage (painted_foliage: linden, oaks, birches,
##   elder) goes to FOLIAGE_LAYER (= WorldRoot.FOLIAGE_LAYER; the village's warm lights leave that
##   layer out of their shadow casters) – the same as WorldRoot does for the graveyard, set at
##   runtime because an override inside an imported .glb instance would embed the mesh;
## - the warm window lights with a meta "until" (cottages till 22:00, houses and the Amtshaus till
##   21:00) are dark from that minute until 06:00: their base_energy goes to 0 (the
##   AtmosphereController derives energy and visibility from it whenever it applies a preset);
## - Phase 8 (docs/PHASE8_DESIGN.md §4.6 D3, §4.9): the window light of a sick house (meta "house" in
##   NightPaths.sick_houses) stays on all night – no new light, the candle is SickLight's.

const META_BASE := &"base_energy"
const META_ON := &"energy_on"
const META_UNTIL := &"until"
const META_SCALE := &"scale"
## Windows light up again at dawn.
const DAWN := 360
const META_HOUSE := &"house"
const NIGHT_PATHS_GROUP := &"night_paths"
const FOLIAGE_LAYER := 1 << 1
const FOLIAGE_SHADER := "res://assets/shaders/painted_foliage.gdshader"
## W3 (G8 p8_18 / p8_19, E8-1): the sick house's window is the light of the night in Hollerbrück – brighter and wider
## while it burns all night (the same light, no new one): energy × SICK_ENERGY, range at least SICK_RANGE.
const SICK_ENERGY := 2.2
const SICK_RANGE := 6.0
const META_RANGE := &"range_on"

var _windows: Array[Light3D] = []


func _ready() -> void:
	var root := get_parent()
	var ground := root.get_node_or_null(^"Ground")
	if ground != null:
		for mesh: Node in ground.find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for path: NodePath in [^"Decor", ^"Buildings", ^"Entities"]:
		var parent := root.get_node_or_null(path)
		if parent == null:
			continue
		for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if _has_foliage(mesh):
				mesh.layers = FOLIAGE_LAYER
	for node: Node in root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		light.shadow_caster_mask = light.shadow_caster_mask & ~FOLIAGE_LAYER
		if light.has_meta(META_UNTIL):
			_windows.append(light)
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.game_loaded.connect(_on_loaded.unbind(1))
	EventBus.new_game_started.connect(_on_loaded)
	apply_minute(TimeManager.minute_of_day)


## Window lights with a meta "until" are dark in [until, 06:00).
func apply_minute(minute: int) -> void:
	for light: Light3D in _windows:
		if not is_instance_valid(light):
			continue
		var sick := _sick(light, minute)
		var on := window_lit(light, minute) or sick
		var energy := float(light.get_meta(META_ON, 1.0)) * (SICK_ENERGY if sick else 1.0)
		if light is OmniLight3D:
			var omni := light as OmniLight3D
			if not omni.has_meta(META_RANGE):
				omni.set_meta(META_RANGE, omni.omni_range)
			omni.omni_range = maxf(float(omni.get_meta(META_RANGE)), SICK_RANGE) if sick else float(omni.get_meta(META_RANGE))
		light.set_meta(META_BASE, energy if on else 0.0)
		light.light_energy = energy * float(light.get_meta(META_SCALE, 1.0)) if on else 0.0
		light.visible = light.light_energy > 0.01


## Whether the window light `light` burns at `minute` (tests, shots).
static func window_lit(light: Light3D, minute: int) -> bool:
	if not light.has_meta(META_UNTIL):
		return true
	return not (minute >= int(light.get_meta(META_UNTIL)) or minute < DAWN)


## The light's house has the sick light tonight (NightPaths.sick_houses).
func _sick(light: Light3D, minute: int) -> bool:
	if not light.has_meta(META_HOUSE) or not is_inside_tree():
		return false
	var paths := get_tree().get_first_node_in_group(NIGHT_PATHS_GROUP)
	if paths == null or not paths.has_method(&"sick_houses"):
		return false
	var houses: PackedStringArray = paths.call(&"sick_houses", TimeManager.day, minute)
	return houses.has(String(light.get_meta(META_HOUSE)))


func _on_time_tick(_day: int, minute: int) -> void:
	apply_minute(minute)


func _on_loaded() -> void:
	apply_minute(TimeManager.minute_of_day)


static func _has_foliage(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null:
		return false
	for i: int in mesh.mesh.get_surface_count():
		var mat := mesh.get_active_material(i) as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path == FOLIAGE_SHADER:
			return true
	return false
