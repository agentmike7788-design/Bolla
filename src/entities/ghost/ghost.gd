class_name Ghost
extends Node3D
## STUB (P4) – docs/PHASE3_DESIGN.md §2.8, §3.4. Pooled ghost (max 6): model ph_chr_ghost +
## mat_ghost, OmniLight "soul light" (no shadow), Interactable (priority 15), Label3D bubble.
## "[E] Zuhören – <Name> wirkt zufrieden/gleichmütig/unruhig".

var grave_id: String = ""
var mood: StringName = &""


func bind(_grave_id: String, _anchor: Transform3D, _display_name: String) -> void:
	pass


func set_mood(_m: StringName) -> void:
	pass


## 0..1
func set_fade(_alpha: float) -> void:
	pass


func say(_text: String, _seconds: float) -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
