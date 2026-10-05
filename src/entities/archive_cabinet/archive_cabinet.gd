class_name ArchiveCabinet
extends Node3D
## STUB (P4) – the parish archive in the church (docs/PHASE8_DESIGN.md §2.4 Lenz 2 / Fenner 2, §3.4, §4.6 D7):
## „[E] Im Archiv helfen (60 Min)" with Lenz step 2 (beside him, 16:00–18:00) or the parish key (alone,
## 08:00–18:00) → Orders.note_task(&"archive_help") → item lorenz_ledger_2; without either:
## „Das Archiv ist verschlossen."
## W1 (P4) fills the bodies; the signatures are the contract.

const PROMPT := "[E] Im Archiv helfen (60 Min)"
const TEXT_LOCKED := "Das Archiv ist verschlossen."
const TASK_ID := &"archive_help"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
