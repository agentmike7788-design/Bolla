class_name LanternLightConfig
extends Resource
## G8 Runde 2 (Lichtgang, user critique „die Laternen beim Lichtgang sind nur Leuchtpunkte"): how the lanterns the
## figures carry light the night (CarriedLanterns, data/config/fx/carried_lanterns.tres). A few real omni lights
## without shadow go to the lanterns nearest the camera focus (a pool like the grave candles', and taken from the
## candles' share so the scene keeps its light budget, docs/PHASE8_DESIGN.md §9); every other carried lantern lays
## a cheap fake light spot on the ground (one MultiMesh, additive, soft fall-off). Flame, glass, light and spot
## flicker in step (one FlickerProfile value per lantern). *_compat = the Compatibility renderer (browser).

@export_group("Pool lights")
## Real lights for the nearest carried lanterns (Forward+ / Compatibility).
@export_range(0, 8) var pool_size: int = 4
@export_range(0, 8) var pool_size_compat: int = 4
## The grave candles' pool (GraveCare, 6) gives up one light per lantern light in use, down to this many.
@export_range(0, 6) var candle_pool_min: int = 2
@export var light_color: Color = Color("#F2A85A")
@export var light_energy: float = 1.15
@export var light_energy_compat: float = 1.15
@export var light_range: float = 3.6
@export var light_attenuation: float = 1.3
## Seconds a pool light takes to fade in / out when it moves to another lantern (no popping).
@export var fade_seconds: float = 0.45
## Seconds between the re-rankings of the lanterns by distance (the positions follow every frame).
@export var rank_interval: float = 0.5

@export_group("Fake light spot")
## Radius (m) of the warm spot on the ground under a lantern, its strength and colour (additive, × flicker × the
## atmosphere's warm light scale). Under a lantern with a pool light the spot fades to spot_under_light of it.
@export var spot_radius: float = 1.6
@export var spot_energy: float = 0.1
@export var spot_energy_compat: float = 0.1
@export var spot_color: Color = Color(1.0, 0.62, 0.3)
@export_range(0.0, 1.0) var spot_under_light: float = 0.25
## Height of the spot over the feet of the carrier (just above the short grass).
@export var spot_lift: float = 0.05

@export_group("Lantern")
## Brightness of the glass (mat_lantern_glass) and of the flame (mat_emissive_warm) of a carried lantern.
@export var glass_energy: float = 0.75
@export var glass_energy_compat: float = 0.75
@export var flame_energy: float = 1.3
@export var flame_energy_compat: float = 1.3
## The flicker of flame, glass, light and spot (data/config/fx/<id>.tres).
@export var flicker_profile: StringName = &"carried_lantern"
## Pendulum while walking: degrees each way, swings per gait cycle (two steps); a slow sway standing.
@export var swing_degrees: float = 7.0
@export var swings_per_cycle: float = 2.0
@export var sway_degrees: float = 1.2
@export var sway_frequency: float = 0.35
## Beyond this distance to the camera a lantern keeps its spot but no per-frame swing.
@export var swing_distance: float = 30.0


func pool_for(compat: bool) -> int:
	return pool_size_compat if compat else pool_size


func light_energy_for(compat: bool) -> float:
	return light_energy_compat if compat else light_energy


func spot_energy_for(compat: bool) -> float:
	return spot_energy_compat if compat else spot_energy


func glass_energy_for(compat: bool) -> float:
	return glass_energy_compat if compat else glass_energy


func flame_energy_for(compat: bool) -> float:
	return flame_energy_compat if compat else flame_energy
