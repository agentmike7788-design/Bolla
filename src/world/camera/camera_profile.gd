class_name CameraProfile
extends Resource
## Framing of the CameraRig for one place (e.g. the hut interior, docs §11): distance, zoom
## range, focus bounds on XZ and an optional own Environment / CameraAttributes for the
## camera (null = the scene's WorldEnvironment). The angles (pitch, yaw, FOV) stay the rig's.

@export var distance: float = 22.0
@export var zoom_min: float = 10.0
@export var zoom_max: float = 34.0
@export var bounds_enabled: bool = false
@export var bounds_min: Vector2 = Vector2(-10.0, -10.0)
@export var bounds_max: Vector2 = Vector2(10.0, 10.0)
## Phase 7 (W-Welt, village): own pitch in degrees; <= 0 = the rig's own pitch (bit-identical).
@export var pitch_deg: float = 0.0
@export var environment: Environment
@export var attributes: CameraAttributes
