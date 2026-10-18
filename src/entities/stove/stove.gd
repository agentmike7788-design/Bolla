class_name Stove
extends Node3D
## The hut's iron stove (docs §11). Its fire light (built at the model's light_fire marker)
## is a flickering warm light: group warm_lights, base energy = InteriorConfig.stove_night_energy,
## meta min_scale = day / night energy, so it keeps burning by day. [E] is flavour only.
## Phase 9 (docs/PHASE9_DESIGN.md §1.3, §2.4.2, §7.5; P3): with a letter in the bag that may be burned here the prompt
## names both („[E] Am Ofen: wärmen oder einen Brief verbrennen") and [E] opens a short choice (&"action_choice",
## LetterBurning): „Am Ofen wärmen" first, then one row per such letter – the chosen one burns (2 Min, clip
## burn_letter, Letters.decide burn with place stove). W3 QA-Fix QA9-03: before, [E] burned the *first* letter at once
## and warming was out of reach while one was in the bag.

const PROMPT_WARM := "[E] Am Ofen wärmen"
const TEXT_WARM := "Das Feuer knistert. Die Kälte weicht aus den Knochen."
const LETTERS_GROUP := &"letters"
const PLACE := &"stove"
const PROMPT_CHOICE := "[E] Am Ofen: wärmen oder einen Brief verbrennen"
const TITLE_CHOICE := "Am Ofen"
const LABEL_WARM := "Am Ofen wärmen"
const OPTION_WARM := &"warm"
const LABEL_BURN := LetterBurning.LABEL
const ANIM_BURN := LetterBurning.ANIM

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable

## The player of the last [E] (the choice runs for them).
var _player: Player


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy()


func get_interaction_prompt(player: Player) -> String:
	if burnable_letter(player) != "":
		return PROMPT_CHOICE
	return PROMPT_WARM


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if burnable_letter(player) == "":
		_warm()
		return
	_player = player
	EventBus.ui_panel_requested.emit(LetterBurning.PANEL, choice_context(player))


## The context of the choice at the stove: warming first, then the letters that may be burned here.
func choice_context(player: Player) -> Dictionary:
	var options: Array[Dictionary] = [{"id": OPTION_WARM, "label": LABEL_WARM}]
	options.append_array(LetterBurning.options(_letters(), player.inventory if player != null else null, PLACE))
	return {"title": TITLE_CHOICE, "question": LetterBurning.QUESTION, "options": options, "target": self, "player": player}


## The choice's answer: &"warm" or burn:<uid> (that letter, if it may still be burned here).
func request_action(id: StringName) -> void:
	var player := _player if is_instance_valid(_player) else null
	if id == OPTION_WARM:
		_warm()
		return
	if player == null or not LetterBurning.start(_letters(), player, LetterBurning.uid_of(id), PLACE):
		EventBus.notification_requested.emit(GravePlot.TEXT_CARE_FAILED, &"warning")


## The first letter in the player's bag that may be burned here ("" = none / no Letters).
func burnable_letter(player: Player) -> String:
	if player == null:
		return ""
	var all := LetterBurning.burnable(_letters(), player.inventory, PLACE)
	return all[0] if not all.is_empty() else ""


func _warm() -> void:
	EventBus.notification_requested.emit(TEXT_WARM, &"info")


func _letters() -> Letters:
	return get_tree().get_first_node_in_group(LETTERS_GROUP) as Letters if is_inside_tree() else null


## The fire light (null before the builder added it).
func fire_light() -> OmniLight3D:
	return find_child("Light_fire", true, false) as OmniLight3D
