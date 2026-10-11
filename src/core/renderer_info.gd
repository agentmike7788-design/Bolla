class_name RendererInfo
extends RefCounted
## G8 Runde 2 (Licht): which renderer draws the game – Forward+ (desktop) or Compatibility (the browser build,
## OpenGL ES 3 / WebGL 2). A few looks need their own values there (no volumetric fog, no SSAO, its own light
## passes): AtmospherePreset.compat_*, LanternLightConfig.*_compat. Tests force a renderer with `force`.

## -1 = ask the RenderingServer, 0 = Forward+ (or Mobile), 1 = Compatibility.
static var force: int = -1


static func is_compat() -> bool:
	if force >= 0:
		return force == 1
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"
