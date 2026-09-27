class_name CorpseDecayVisual
extends Node3D
## STUB (P4) – docs/PHASE4_DESIGN.md §2.5, §8, §9. Child "DecayVisual" of corpse.tscn: overlay
## material per MeshInstance (decay_overlay.gdshader), CPUParticles3D Flies / Wisps / Smoke.
## Pure presentation – reads the record, never changes it.


func apply(_freshness: float, _stage: StringName, _balm_active: bool, _washed: bool) -> void:
	pass


func overlay_amount() -> float:
	return 0.0


func flies() -> int:
	return 0


func wisps() -> int:
	return 0


func smoke_on() -> bool:
	return false
