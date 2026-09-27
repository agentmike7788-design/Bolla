class_name Chest
extends Node3D
## Storage chest in the hut (docs §11; groups saveable, save_id "hut_chest"). Its own
## Inventory "Storage" (InteriorConfig.chest_slots, 16) – [E] opens the &"chest" panel with
## {storage, inventory (the player's), chest}. The panel moves the items (ChestTransfer).

const PANEL := &"chest"
const PROMPT_OPEN := "[E] Truhe öffnen"

@export var save_id: String = "hut_chest"
@export var save_order: int = 60

@onready var storage: Inventory = $Storage
@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func _ready() -> void:
	storage.slot_count = InteriorConfig.resolve().chest_slots


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and not is_instance_valid(player.carried)


func get_interaction_prompt(player: Player) -> String:
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	return PROMPT_OPEN


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, {"storage": storage, "inventory": player.inventory, "chest": self})


## {storage: Inventory.save_state()}.
func save_state() -> Dictionary:
	return {"storage": storage.save_state()}


func load_state(data: Dictionary) -> void:
	var saved: Variant = data.get("storage")
	storage.load_state(saved if saved is Dictionary else {})
