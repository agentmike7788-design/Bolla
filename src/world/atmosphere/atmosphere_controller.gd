class_name AtmosphereController
extends Node
## Applies AtmospherePreset resources to the scene's sun, environment and warm lights.

signal preset_changed(preset: AtmospherePreset)

@export var presets: Array[AtmospherePreset] = []
@export var world_environment: WorldEnvironment
@export var sun: DirectionalLight3D

var current_index: int = 0


func _ready() -> void:
	if not presets.is_empty():
		apply(0)


func cycle() -> void:
	apply((current_index + 1) % presets.size())


func current() -> AtmospherePreset:
	return presets[current_index]


func apply(index: int) -> void:
	current_index = index
	var p := presets[index]
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	sun.rotation_degrees = p.sun_rotation_deg
	sun.shadow_opacity = p.sun_shadow_opacity
	var env := world_environment.environment
	env.background_color = p.background_color
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.fog_light_color = p.fog_color
	env.fog_density = p.fog_density
	env.volumetric_fog_density = p.volumetric_fog_density
	env.volumetric_fog_albedo = p.volumetric_fog_albedo
	env.volumetric_fog_emission = p.volumetric_fog_emission
	env.tonemap_exposure = p.exposure
	env.glow_intensity = p.glow_intensity
	env.adjustment_saturation = p.saturation
	for node: Node in get_tree().get_nodes_in_group("warm_lights"):
		var light := node as Light3D
		light.set_meta("scale", p.warm_light_scale)
		light.light_energy = float(light.get_meta("base_energy", 1.0)) * p.warm_light_scale
		light.visible = light.light_energy > 0.01
	preset_changed.emit(p)
