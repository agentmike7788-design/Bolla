class_name Stove
extends Node3D
## The hut's iron stove (docs §11). Its fire light (built at the model's light_fire marker)
## is a flickering warm light: group warm_lights, base energy = InteriorConfig.stove_night_energy,
## meta min_scale = day / night energy, so it keeps burning by day. [E] is flavour only.
## Phase 9 (docs/PHASE9_DESIGN.md §1.3, §2.4.2, §7.5; P3): with a letter in the bag that may be burned, „[E] Brief
## verbrennen (2 Min)" (the first such letter; Letters.decide burn with place stove, clip burn_letter).

const PROMPT_WARM := "[E] Am Ofen wärmen"
const TEXT_WARM := "Das Feuer knistert. Die Kälte weicht aus den Knochen."
const LETTERS_GROUP := &"letters"
const PLACE := &"stove"
const PROMPT_BURN := "[E] Brief verbrennen (%d Min)"
const LABEL_BURN := "Brief verbrennen"
const ANIM_BURN := &"burn_letter"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy()


func get_interaction_prompt(player: Player) -> String:
	if burnable_letter(player) != "":
		return PROMPT_BURN % _letters().get_config().burn_minutes
	return PROMPT_WARM


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	var uid := burnable_letter(player)
	if uid != "":
		player.start_timed_action(LABEL_BURN, _letters().get_config().burn_minutes, _finish_burn.bind(uid, player), false,
				ToolAnimConfig.clip_for(&"stove_burn_letter", ANIM_BURN))
		return
	EventBus.notification_requested.emit(TEXT_WARM, &"info")


## The first letter in the player's bag that may be burned here ("" = none / no Letters).
func burnable_letter(player: Player) -> String:
	var letters := _letters()
	if letters == null or player == null or player.inventory == null:
		return ""
	return letters.first_for(&"burn", player.inventory, {"place": PLACE})


func _finish_burn(uid: String, player: Player) -> void:
	var letters := _letters()
	if letters != null and is_instance_valid(player):
		letters.decide(uid, &"burn", {"inventory": player.inventory, "place": PLACE})


func _letters() -> Letters:
	return get_tree().get_first_node_in_group(LETTERS_GROUP) as Letters if is_inside_tree() else null


## The fire light (null before the builder added it).
func fire_light() -> OmniLight3D:
	return find_child("Light_fire", true, false) as OmniLight3D
