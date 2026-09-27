class_name Stove
extends Node3D
## The hut's iron stove (docs §11). Its fire light (built at the model's light_fire marker)
## is a flickering warm light: group warm_lights, base energy = InteriorConfig.stove_night_energy,
## meta min_scale = day / night energy, so it keeps burning by day. [E] is flavour only.

const PROMPT_WARM := "[E] Am Ofen wärmen"
const TEXT_WARM := "Das Feuer knistert. Die Kälte weicht aus den Knochen."

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy()


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT_WARM


func interact(player: Player) -> void:
	if can_interact(player):
		EventBus.notification_requested.emit(TEXT_WARM, &"info")


## The fire light (null before the builder added it).
func fire_light() -> OmniLight3D:
	return find_child("Light_fire", true, false) as OmniLight3D
