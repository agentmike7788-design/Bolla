class_name RegionConfig
extends Resource
## One outdoor region (docs/PHASE7_DESIGN.md §3.4, §4.1): data/config/regions/<region_id>.tres.
## Graveyard: origin (0, 0, 0); Village Hollerbrück: origin (0, 0, 400). Bounds are region-local
## camera focus limits (RegionRoot.camera_profile adds the origin).

@export var region_id: StringName
@export var display_name: String = ""
## HUD place name for 3 s on arrival („Hollerbrück · Anger").
@export var arrive_text: String = ""
@export var origin: Vector3 = Vector3.ZERO
@export var camera_distance: float = 22.0
@export var camera_zoom_min: float = 12.0
@export var camera_zoom_max: float = 24.0
## W-Welt (Phase 7): own camera pitch of the region in degrees; <= 0 = the rig's (45°).
@export var camera_pitch: float = 0.0
## Focus bounds, region-local.
@export var bounds_min: Vector2
@export var bounds_max: Vector2
## Game minutes of the way between the regions (§1.3: 30) and the fade (§4.1: 0.8 s).
@export var travel_minutes: int = 30
@export var fade_seconds: float = 0.8
## Paths relative to the region's parent node (Graveyard: WorldRoot → ["Decor", "Lights", "Grass"]);
## Village: ["."] (its own scene).
@export var managed_paths: PackedStringArray = []
