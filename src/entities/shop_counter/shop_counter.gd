class_name ShopCounter
extends Node3D
## STUB (P2) – the grocer's shop window, the smith's anvil (docs/PHASE7_DESIGN.md §3.4, §4.2):
## „[E] Kaufen und verkaufen" while VillageShops.is_open(shop_id) → panel &"shop"
## {shop_id, speaker, inventory, player}. W1 (P2) fills the bodies; the signatures are the contract.

const PANEL := &"shop"
const PROMPT := "[E] Kaufen und verkaufen"

@export var shop_id: StringName

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
