class_name VillageBoard
extends Node3D
## The parish board at the linden (docs/PHASE7_DESIGN.md §2.5, §3.4, §4.2): „[E] Gemeindetafel lesen"
## → panel &"orders" {board: true, orders (today's board offers), header (the gravekeeper's
## reputation), inventory, player}. Usable once the village is open; the offers themselves come from
## Orders (apply_morning, two per day).

const PANEL := &"orders"
const PROMPT := "[E] Gemeindetafel lesen"
## Header line of the board (§2.4).
const HEADER := "Totengräber auf dem Hügel – Ruf: %s"
const TEXT_EMPTY := "Heute hängt nichts an der Tafel."

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return GameState.flag_on(&"village_open")


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT if GameState.flag_on(&"village_open") else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, panel_context(player))


## {board: true, orders, header, empty_text, inventory, player}.
func panel_context(player: Player) -> Dictionary:
	var orders := get_tree().get_first_node_in_group(&"orders") if is_inside_tree() else null
	var ids: Array[StringName] = []
	if orders != null and orders.has_method(&"board"):
		ids = orders.call(&"board")
	var ctx := {"board": true, "orders": ids, "header": header_text(), "empty_text": TEXT_EMPTY, "player": player}
	if player != null and is_instance_valid(player):
		ctx["inventory"] = player.inventory
	return ctx


## „Totengräber auf dem Hügel – Ruf: Geachtet".
static func header_text() -> String:
	return HEADER % GameState.reputation_label()
