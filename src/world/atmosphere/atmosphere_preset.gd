class_name AtmospherePreset
extends Resource
## One lighting mood (e.g. day, night). Applied by AtmosphereController.
## All look-defining values live in .tres files under res://data/atmosphere/.

@export var display_name: String = ""
@export_group("Sun / Moon")
@export var sun_color: Color = Color(1, 0.9, 0.75)
@export var sun_energy: float = 1.5
@export var sun_rotation_deg: Vector3 = Vector3(-35, -40, 0)
@export var sun_shadow_opacity: float = 1.0
@export_group("Ambient")
@export var background_color: Color = Color(0.5, 0.6, 0.7)
@export var ambient_color: Color = Color(0.6, 0.7, 0.8)
@export var ambient_energy: float = 0.5
@export_group("Fog")
@export var fog_color: Color = Color(0.72, 0.76, 0.69)
@export var fog_density: float = 0.004
@export var volumetric_fog_density: float = 0.01
@export var volumetric_fog_albedo: Color = Color(0.8, 0.85, 0.8)
@export var volumetric_fog_emission: Color = Color(0, 0, 0)
@export_group("Grading")
@export var exposure: float = 1.0
@export var glow_intensity: float = 0.4
@export var saturation: float = 1.0
@export_group("Warm lights")
## Multiplier for every light in group "warm_lights" (lanterns, candles, windows).
@export var warm_light_scale: float = 1.0
