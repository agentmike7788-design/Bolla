class_name GrassClearMask
extends Node
## STUB (P2) – docs/PHASE3_DESIGN.md §3.4, §3.6. Systems/GrassClearMask: writes the shader
## globals grass_clear_mask (R8 texture, 0.25 m texels over the BuildMask, 1 = hide grass under
## standing obstacles / decor) and grass_clear_rect (origin.xz, size.xz; (0,0,0,0) = off).

const GLOBAL_MASK := &"grass_clear_mask"
const GLOBAL_RECT := &"grass_clear_rect"


## On decor_changed, obstacle_cleared, section_unlocked, world_ready.
func repaint() -> void:
	pass
