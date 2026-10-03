class_name ShopCounter
extends Node3D
## The grocer's shop window, the smith's anvil (docs/PHASE7_DESIGN.md §3.4, §4.2):
## „[E] Kaufen und verkaufen" while VillageShops.is_open(shop_id) → panel &"shop"
## {shop_id, speaker (the shopkeeper's Npc or null), inventory, player}. Closed: no prompt.

const PANEL := &"shop"
const PROMPT := "[E] Kaufen und verkaufen"

@export var shop_id: StringName

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and is_open()


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT if is_open() else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var shops := _shops()
	EventBus.ui_panel_requested.emit(PANEL, {"shop_id": shop_id, "speaker": shops.npc_node(shop_id),
			"inventory": player.inventory, "player": player})


## The shopkeeper stands at this counter.
func is_open() -> bool:
	var shops := _shops()
	return shops != null and shops.is_open(shop_id)


func _shops() -> VillageShops:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(VillageShops.GROUP) as VillageShops
